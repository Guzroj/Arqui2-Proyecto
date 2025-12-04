// ============================================================================
// fixed_point_mult.sv
// Multiplicador de punto fijo Q8.8 (8 bits enteros, 8 bits fraccionarios)
// Arquitectura de Computadores 2 - FASE 5
// ============================================================================

module fixed_point_mult (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        en,           // Enable del pipeline
    input  logic [15:0] a,            // Q8.8 multiplicando
    input  logic [15:0] b,            // Q8.8 multiplicador
    output logic [15:0] result        // Q8.8 resultado
);

    // ========================================================================
    // Pipeline de 2 etapas para multiplicación
    // ========================================================================

    // Stage 1: Multiplicación completa (produce 32 bits)
    logic [31:0] mult_result_s1;

    // Stage 2: Ajuste y redondeo
    logic [15:0] result_s2;

    // ========================================================================
    // Stage 1: Multiplicación
    // ========================================================================
    // a[15:0] = IIIIIIII.FFFFFFFF (8.8)
    // b[15:0] = IIIIIIII.FFFFFFFF (8.8)
    // a * b = IIIIIIIIIIIIIIII.FFFFFFFFFFFFFFFF (16.16)
    //         [31:16]            [15:0]

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mult_result_s1 <= 32'd0;
        end else if (en) begin
            mult_result_s1 <= a * b;
        end
    end

    // ========================================================================
    // Stage 2: Conversión de vuelta a Q8.8 con redondeo
    // ========================================================================
    // Tomamos bits [23:8] del resultado de 32 bits
    // Esto nos da Q8.8 con los bits fraccionarios correctos
    // Redondeo: si bit[7] = 1, sumar 1 al resultado

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result_s2 <= 16'd0;
        end else if (en) begin
            // Redondeo: agregar bit[7] para round-to-nearest
            result_s2 <= mult_result_s1[23:8] + {15'd0, mult_result_s1[7]};
        end
    end

    assign result = result_s2;

    // ========================================================================
    // Assertions (solo para simulación)
    // ========================================================================
    `ifdef SIMULATION
        // Verificar que no haya overflow en la parte entera
        always_ff @(posedge clk) begin
            if (en && rst_n) begin
                // Advertencia si hay bits significativos perdidos
                if (|mult_result_s1[31:24]) begin
                    $warning("Q8.8 multiplication overflow detected at time %t", $time);
                end
            end
        end
    `endif

endmodule
