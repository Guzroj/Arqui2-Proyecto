// ============================================================================
// Proyecto2Arqui.sv
// Top-level module para sistema de downscaling de imágenes
// Arquitectura de Computadores 2 - FASE 4
// ============================================================================

module Proyecto2Arqui (
    // Clock y Reset
    input  logic        CLOCK_50,       // Clock de 50 MHz de la DE1-SoC
    input  logic        KEY0,           // Reset (activo bajo)

    // LEDs de debug (opcional)
    output logic [9:0]  LEDR            // 10 LEDs rojos
);

    // ========================================================================
    // Señales internas
    // ========================================================================

    logic rst_n;
    assign rst_n = KEY0;  // KEY0 como reset activo bajo

    // Señales para memoria de entrada (64x64)
    logic        input_mem_wr_en_a;
    logic [11:0] input_mem_wr_addr_a;
    logic [7:0]  input_mem_wr_data_a;
    logic        input_mem_rd_en_b;
    logic [11:0] input_mem_rd_addr_b;
    logic [7:0]  input_mem_rd_data_b;

    // Señales para memoria de salida (32x32)
    logic        output_mem_wr_en_a;
    logic [9:0]  output_mem_wr_addr_a;
    logic [7:0]  output_mem_wr_data_a;
    logic        output_mem_rd_en_b;
    logic [9:0]  output_mem_rd_addr_b;
    logic [7:0]  output_mem_rd_data_b;
    logic [10:0] output_mem_pixels_written;

    // ========================================================================
    // Instancia de memoria de entrada (64x64)
    // ========================================================================

    image_memory_input u_input_memory (
        .clk        (CLOCK_50),
        .rst_n      (rst_n),

        // Puerto A: Escritura (desde JTAG - por ahora deshabilitado)
        .wr_en_a    (input_mem_wr_en_a),
        .wr_addr_a  (input_mem_wr_addr_a),
        .wr_data_a  (input_mem_wr_data_a),

        // Puerto B: Lectura (hacia downscaler - por ahora deshabilitado)
        .rd_en_b    (input_mem_rd_en_b),
        .rd_addr_b  (input_mem_rd_addr_b),
        .rd_data_b  (input_mem_rd_data_b)
    );

    // ========================================================================
    // Instancia de memoria de salida (32x32)
    // ========================================================================

    image_memory_output u_output_memory (
        .clk            (CLOCK_50),
        .rst_n          (rst_n),

        // Puerto A: Escritura (desde downscaler - por ahora deshabilitado)
        .wr_en_a        (output_mem_wr_en_a),
        .wr_addr_a      (output_mem_wr_addr_a),
        .wr_data_a      (output_mem_wr_data_a),

        // Puerto B: Lectura (hacia JTAG - por ahora deshabilitado)
        .rd_en_b        (output_mem_rd_en_b),
        .rd_addr_b      (output_mem_rd_addr_b),
        .rd_data_b      (output_mem_rd_data_b),

        // Contador de píxeles escritos
        .pixels_written (output_mem_pixels_written)
    );

    // ========================================================================
    // Lógica temporal (PLACEHOLDER - se reemplazará en fases posteriores)
    // ========================================================================

    // Por ahora, deshabilitar todas las escrituras/lecturas
    assign input_mem_wr_en_a = 1'b0;
    assign input_mem_wr_addr_a = 12'd0;
    assign input_mem_wr_data_a = 8'd0;
    assign input_mem_rd_en_b = 1'b0;
    assign input_mem_rd_addr_b = 12'd0;

    assign output_mem_wr_en_a = 1'b0;
    assign output_mem_wr_addr_a = 10'd0;
    assign output_mem_wr_data_a = 8'd0;
    assign output_mem_rd_en_b = 1'b0;
    assign output_mem_rd_addr_b = 10'd0;

    // Debug: Mostrar contador de píxeles en los LEDs
    assign LEDR[9:0] = output_mem_pixels_written[9:0];

    // ========================================================================
    // TODO FASE 5: Instanciar módulo de downscaling
    // TODO FASE 6: Instanciar interfaz JTAG
    // ========================================================================

endmodule
