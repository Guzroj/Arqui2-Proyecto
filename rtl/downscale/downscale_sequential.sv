// ============================================================================
// downscale_sequential.sv
// Módulo top integrado para downscaling secuencial 64x64 → 32x32
// Procesa 1 píxel de salida por ciclo (después de latencia del pipeline)
// Arquitectura de Computadores 2 - FASE 5
// ============================================================================

module downscale_sequential (
    input  logic        clk,
    input  logic        rst_n,

    // Control
    input  logic        start,          // Iniciar downscaling
    output logic        busy,           // Procesando
    output logic        done,           // Completado

    // Interfaz con memoria de entrada (64x64)
    output logic        mem_in_rd_en,
    output logic [11:0] mem_in_rd_addr,
    input  logic [7:0]  mem_in_rd_data,

    // Interfaz con memoria de salida (32x32)
    output logic        mem_out_wr_en,
    output logic [9:0]  mem_out_wr_addr,
    output logic [7:0]  mem_out_wr_data
);

    // ========================================================================
    // Señales internas
    // ========================================================================

    // Señales de la FSM
    logic        interp_start;
    logic        interp_valid;
    logic [4:0]  out_x, out_y;

    // Buffer para los 4 píxeles leídos
    logic [7:0]  pixel_buffer [0:3];  // p00, p01, p10, p11
    logic [1:0]  buffer_index;

    // Pesos de interpolación Q8.8
    logic [15:0] weight_x, weight_y;

    // Resultado de interpolación
    logic [7:0]  interp_result;

    // Coordenadas Q8.8 de la FSM
    logic [15:0] in_x_q8, in_y_q8;

    // ========================================================================
    // Instancia de FSM
    // ========================================================================

    downscale_fsm u_fsm (
        .clk            (clk),
        .rst_n          (rst_n),
        .start          (start),
        .busy           (busy),
        .done           (done),
        .interp_start   (interp_start),
        .interp_valid   (interp_valid),
        .mem_in_rd_en   (mem_in_rd_en),
        .mem_in_rd_addr (mem_in_rd_addr),
        .mem_out_wr_en  (mem_out_wr_en),
        .mem_out_wr_addr(mem_out_wr_addr),
        .out_x          (out_x),
        .out_y          (out_y)
    );

    // ========================================================================
    // Buffer de píxeles leídos
    // ========================================================================
    // Almacena los 4 píxeles vecinos conforme se leen
    // Con latencia de 1 ciclo de la memoria

    // Señal retrasada para sincronizar con latencia de memoria
    logic mem_in_rd_en_d1;
    logic [1:0] buffer_wr_index;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_in_rd_en_d1 <= 1'b0;
            buffer_wr_index <= 2'd0;
        end else begin
            mem_in_rd_en_d1 <= mem_in_rd_en;

            // Sincronizar índice con la latencia de memoria
            if (mem_in_rd_en) begin
                buffer_wr_index <= buffer_index;
            end
        end
    end

    // Escribir en buffer cuando los datos estén disponibles (1 ciclo después)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pixel_buffer[0] <= 8'd0;
            pixel_buffer[1] <= 8'd0;
            pixel_buffer[2] <= 8'd0;
            pixel_buffer[3] <= 8'd0;
        end else begin
            // Almacenar píxeles con latencia de 1 ciclo
            if (mem_in_rd_en_d1) begin
                pixel_buffer[buffer_wr_index] <= mem_in_rd_data;
            end
        end
    end

    // Contador de buffer sincronizado con FSM
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            buffer_index <= 2'd0;
        end else begin
            if (mem_in_rd_en) begin
                if (buffer_index < 2'd3) begin
                    buffer_index <= buffer_index + 2'd1;
                end else begin
                    buffer_index <= 2'd0;
                end
            end
        end
    end

    // ========================================================================
    // Cálculo de pesos de interpolación
    // ========================================================================
    // Los pesos son las partes fraccionarias de las coordenadas Q8.8
    //
    // Coordenadas en imagen de entrada (de la FSM):
    // in_x_q8 = (out_x * 2 + 0.5) en Q8.8
    // in_y_q8 = (out_y * 2 + 0.5) en Q8.8
    //
    // Pesos = parte fraccionaria
    // weight_x = in_x_q8[7:0] (8 bits fraccionarios)
    // weight_y = in_y_q8[7:0] (8 bits fraccionarios)
    //
    // Pero necesitamos en formato Q8.8 completo (16 bits)
    // weight_x = {8'd0, in_x_q8[7:0]}

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            weight_x <= 16'd0;
            weight_y <= 16'd0;
            in_x_q8 <= 16'd0;
            in_y_q8 <= 16'd0;
        end else if (interp_start) begin
            // Calcular coordenadas en imagen de entrada
            in_x_q8 <= {out_x, 9'd0} + 16'd128;  // x*2 + 0.5
            in_y_q8 <= {out_y, 9'd0} + 16'd128;  // y*2 + 0.5

            // Extraer pesos (parte fraccionaria)
            weight_x <= {8'd0, in_x_q8[7:0]};
            weight_y <= {8'd0, in_y_q8[7:0]};
        end
    end

    // ========================================================================
    // Instancia de interpolador bilineal
    // ========================================================================

    bilinear_interpolator u_interpolator (
        .clk      (clk),
        .rst_n    (rst_n),
        .start    (interp_start),
        .valid    (interp_valid),
        .p00      (pixel_buffer[0]),
        .p01      (pixel_buffer[1]),
        .p10      (pixel_buffer[2]),
        .p11      (pixel_buffer[3]),
        .weight_x (weight_x),
        .weight_y (weight_y),
        .result   (interp_result)
    );

    // ========================================================================
    // Salida de datos
    // ========================================================================

    assign mem_out_wr_data = interp_result;

    // ========================================================================
    // Debug y monitoreo (opcional)
    // ========================================================================

    `ifdef SIMULATION
        // Contador de píxeles procesados
        logic [9:0] pixels_processed;

        always_ff @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                pixels_processed <= 10'd0;
            end else begin
                if (start && !busy) begin
                    pixels_processed <= 10'd0;
                end else if (mem_out_wr_en) begin
                    pixels_processed <= pixels_processed + 10'd1;
                end
            end
        end

        // Reportar progreso cada 256 píxeles
        always_ff @(posedge clk) begin
            if (mem_out_wr_en && (pixels_processed[7:0] == 8'd0)) begin
                $display("[DOWNSCALE] Procesados %0d/1024 píxeles (%.1f%%)",
                         pixels_processed,
                         (pixels_processed * 100.0) / 1024.0);
            end
            if (done) begin
                $display("[DOWNSCALE] Completado: 1024 píxeles procesados");
            end
        end
    `endif

endmodule
