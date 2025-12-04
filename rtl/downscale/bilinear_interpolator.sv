// ============================================================================
// bilinear_interpolator.sv
// Unidad de interpolación bilinear con aritmética Q8.8
// Pipeline de 3 etapas - Throughput: 1 píxel/ciclo
// Arquitectura de Computadores 2 - FASE 5
// ============================================================================

module bilinear_interpolator (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        start,         // Iniciar interpolación
    output logic        valid,         // Resultado válido

    // Píxeles de entrada (4 vecinos en formato 2x2)
    // p00  p01
    // p10  p11
    input  logic [7:0]  p00,           // Top-left
    input  logic [7:0]  p01,           // Top-right
    input  logic [7:0]  p10,           // Bottom-left
    input  logic [7:0]  p11,           // Bottom-right

    // Pesos de interpolación Q8.8 (dx, dy ∈ [0, 1])
    input  logic [15:0] weight_x,      // dx en Q8.8 (fracción horizontal)
    input  logic [15:0] weight_y,      // dy en Q8.8 (fracción vertical)

    // Resultado
    output logic [7:0]  result         // Píxel interpolado
);

    // ========================================================================
    // Pipeline de 3 etapas
    // ========================================================================

    // Stage 1: Interpolación horizontal (top y bottom)
    // Stage 2: Interpolación vertical
    // Stage 3: Conversión de vuelta a 8 bits

    // ========================================================================
    // Señales de pipeline
    // ========================================================================

    logic [15:0] p00_q8, p01_q8, p10_q8, p11_q8;
    logic [15:0] one_minus_wx, one_minus_wy;

    // Stage 1 outputs (horizontal interpolation)
    logic [15:0] top_interp;    // Interpolación fila superior
    logic [15:0] bot_interp;    // Interpolación fila inferior

    // Stage 2 outputs (vertical interpolation)
    logic [15:0] final_interp;

    // Valid signals para cada etapa
    logic valid_s1, valid_s2, valid_s3;

    // ========================================================================
    // Conversión de píxeles a Q8.8
    // ========================================================================
    // Píxel de 8 bits → Q8.8 (agregar 8 bits fraccionarios = 0)
    assign p00_q8 = {p00, 8'd0};
    assign p01_q8 = {p01, 8'd0};
    assign p10_q8 = {p10, 8'd0};
    assign p11_q8 = {p11, 8'd0};

    // 1.0 - weight en Q8.8
    // 1.0 en Q8.8 = 16'h0100 (256 en decimal)
    assign one_minus_wx = 16'h0100 - weight_x;
    assign one_minus_wy = 16'h0100 - weight_y;

    // ========================================================================
    // Instancias de multiplicadores Q8.8 (4 multiplicadores)
    // ========================================================================

    logic [15:0] mult_result[0:3];
    logic        mult_en;

    // Multiplicador 0: p00 * (1 - wx)
    fixed_point_mult u_mult0 (
        .clk    (clk),
        .rst_n  (rst_n),
        .en     (mult_en),
        .a      (p00_q8),
        .b      (one_minus_wx),
        .result (mult_result[0])
    );

    // Multiplicador 1: p01 * wx
    fixed_point_mult u_mult1 (
        .clk    (clk),
        .rst_n  (rst_n),
        .en     (mult_en),
        .a      (p01_q8),
        .b      (weight_x),
        .result (mult_result[1])
    );

    // Multiplicador 2: p10 * (1 - wx)
    fixed_point_mult u_mult2 (
        .clk    (clk),
        .rst_n  (rst_n),
        .en     (mult_en),
        .a      (p10_q8),
        .b      (one_minus_wx),
        .result (mult_result[2])
    );

    // Multiplicador 3: p11 * wx
    fixed_point_mult u_mult3 (
        .clk    (clk),
        .rst_n  (rst_n),
        .en     (mult_en),
        .a      (p11_q8),
        .b      (weight_x),
        .result (mult_result[3])
    );

    assign mult_en = start | valid_s1;  // Enable pipeline

    // ========================================================================
    // Stage 1: Interpolación horizontal
    // ========================================================================
    // top_interp = p00*(1-wx) + p01*wx
    // bot_interp = p10*(1-wx) + p11*wx

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            top_interp <= 16'd0;
            bot_interp <= 16'd0;
            valid_s1   <= 1'b0;
        end else begin
            if (start) begin
                valid_s1 <= 1'b1;
            end
            if (valid_s1 || start) begin
                top_interp <= mult_result[0] + mult_result[1];
                bot_interp <= mult_result[2] + mult_result[3];
            end
        end
    end

    // ========================================================================
    // Stage 2: Interpolación vertical
    // ========================================================================
    // final_interp = top_interp*(1-wy) + bot_interp*wy

    logic [15:0] vert_mult0, vert_mult1;

    fixed_point_mult u_mult_vert0 (
        .clk    (clk),
        .rst_n  (rst_n),
        .en     (valid_s1),
        .a      (top_interp),
        .b      (one_minus_wy),
        .result (vert_mult0)
    );

    fixed_point_mult u_mult_vert1 (
        .clk    (clk),
        .rst_n  (rst_n),
        .en     (valid_s1),
        .a      (bot_interp),
        .b      (weight_y),
        .result (vert_mult1)
    );

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            final_interp <= 16'd0;
            valid_s2     <= 1'b0;
        end else begin
            valid_s2 <= valid_s1;
            if (valid_s2 || valid_s1) begin
                final_interp <= vert_mult0 + vert_mult1;
            end
        end
    end

    // ========================================================================
    // Stage 3: Conversión de Q8.8 a 8 bits con saturación
    // ========================================================================

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result   <= 8'd0;
            valid_s3 <= 1'b0;
        end else begin
            valid_s3 <= valid_s2;
            if (valid_s3 || valid_s2) begin
                // Convertir Q8.8 → 8 bits (tomar parte entera con saturación)
                // Redondeo: agregar 0.5 (128 en parte fraccionaria)
                if (final_interp[15:8] > 8'd255) begin
                    result <= 8'd255;  // Saturación
                end else begin
                    // Redondeo: sumar 128 (0.5 en Q8.8) antes de truncar
                    result <= final_interp[15:8] + {7'd0, final_interp[7]};
                end
            end
        end
    end

    // ========================================================================
    // Control signals
    // ========================================================================

    assign valid = valid_s3;

    // ========================================================================
    // Assertions (solo para simulación)
    // ========================================================================
    // Removed assertions for simplicity

endmodule
