// ============================================================================
// top_downscale_system.sv
// Sistema completo de downscaling con interfaz JTAG
// Integra: JTAG Virtual, Registro Map, Memorias, Downscaler
// Arquitectura de Computadores 2 - FASE 6
// ============================================================================

module top_downscale_system (
    input  logic        CLOCK_50,      // Reloj de 50 MHz
    input  logic        KEY0,          // Reset (activo bajo)
    output logic [9:0]  LEDR           // LEDs para debug
);

    // ========================================================================
    // Señales de reset
    // ========================================================================
    logic rst_n;
    assign rst_n = KEY0;

    // ========================================================================
    // Señales JTAG Virtual (desde IP de Quartus)
    // ========================================================================
    logic tdi;
    logic tdo;
    logic [0:0] ir_in;
    logic [0:0] ir_out;
    logic virtual_state_cdr;
    logic virtual_state_sdr;
    logic virtual_state_e1dr;
    logic virtual_state_pdr;
    logic virtual_state_e2dr;
    logic virtual_state_udr;
    logic virtual_state_cir;
    logic virtual_state_uir;
    logic tck;

    // ========================================================================
    // Señales del banco de registros JTAG
    // ========================================================================
    logic        reg_write;
    logic        reg_read;
    logic [7:0]  reg_addr;
    logic [31:0] reg_write_data;
    logic [31:0] reg_read_data;
    logic        reg_read_valid;

    // ========================================================================
    // Señales de control del sistema
    // ========================================================================
    logic        start_processing;
    logic        reset_memories;
    logic        busy;
    logic        done;
    logic [2:0]  fsm_state;

    // ========================================================================
    // Señales de memoria de entrada (64x64)
    // ========================================================================
    // Puerto A: escritura desde JTAG
    logic        mem_in_wr_en_a;
    logic [11:0] mem_in_wr_addr_a;
    logic [7:0]  mem_in_wr_data_a;

    // Puerto B: lectura desde downscaler
    logic        mem_in_rd_en_b;
    logic [11:0] mem_in_rd_addr_b;
    logic [7:0]  mem_in_rd_data_b;

    // ========================================================================
    // Señales de memoria de salida (32x32)
    // ========================================================================
    // Puerto A: escritura desde downscaler
    logic        mem_out_wr_en_a;
    logic [9:0]  mem_out_wr_addr_a;
    logic [7:0]  mem_out_wr_data_a;

    // Puerto B: lectura desde JTAG
    logic        mem_out_rd_en_b;
    logic [9:0]  mem_out_rd_addr_b;
    logic [7:0]  mem_out_rd_data_b;
    logic [10:0] pixels_written;

    // ========================================================================
    // Asignación del estado de la FSM del downscaler
    // ========================================================================
    // Para el registro de STATUS
    assign fsm_state = {busy, 1'b0, done};  // Aproximación del estado

    // ========================================================================
    // Instancia: JTAG Virtual (Wrapper generado por IP Core)
    // ========================================================================
    // El wrapper sld_virtual_jtag.v ya tiene los parámetros configurados:
    // - sld_auto_instance_index: "YES"
    // - sld_instance_index: 0
    // - sld_ir_width: 1
    // No se pueden pasar parámetros al wrapper, ya están fijos en el IP Core

    sld_virtual_jtag u_virtual_jtag (
        .tdi                    (tdi),
        .tdo                    (tdo),
        .ir_in                  (ir_in),
        .ir_out                 (ir_out),
        .virtual_state_cdr      (virtual_state_cdr),
        .virtual_state_sdr      (virtual_state_sdr),
        .virtual_state_e1dr     (virtual_state_e1dr),
        .virtual_state_pdr      (virtual_state_pdr),
        .virtual_state_e2dr     (virtual_state_e2dr),
        .virtual_state_udr      (virtual_state_udr),
        .virtual_state_cir      (virtual_state_cir),
        .virtual_state_uir      (virtual_state_uir),
        .tck                    (tck)
    );

    // ========================================================================
    // Instancia: JTAG Avalon Controller
    // ========================================================================
    // Señal intermedia para ir_out (el controlador genera, el wrapper recibe)
    logic ir_out_bit;
    assign ir_out[0] = ir_out_bit;

    jtag_avalon_controller u_jtag_controller (
        .clk                    (CLOCK_50),
        .rst_n                  (rst_n),
        .tdi                    (tdi),
        .tdo                    (tdo),
        .ir_in                  (ir_in[0]),      // El wrapper genera ir_in, el controlador lo recibe
        .ir_out                 (ir_out_bit),    // El controlador genera ir_out, el wrapper lo recibe
        .virtual_state_cdr      (virtual_state_cdr),
        .virtual_state_sdr      (virtual_state_sdr),
        .virtual_state_udr      (virtual_state_udr),
        .reg_write              (reg_write),
        .reg_read               (reg_read),
        .reg_addr               (reg_addr),
        .reg_write_data         (reg_write_data),
        .reg_read_data          (reg_read_data),
        .reg_read_valid         (reg_read_valid)
    );

    // ========================================================================
    // Instancia: JTAG Register Map
    // ========================================================================
    jtag_register_map u_register_map (
        .clk                    (CLOCK_50),
        .rst_n                  (rst_n),
        .reg_write              (reg_write),
        .reg_read               (reg_read),
        .reg_addr               (reg_addr),
        .reg_write_data         (reg_write_data),
        .reg_read_data          (reg_read_data),
        .reg_read_valid         (reg_read_valid),
        .start_processing       (start_processing),
        .reset_memories         (reset_memories),
        .busy                   (busy),
        .done                   (done),
        .fsm_state              (fsm_state),
        .mem_in_wr_en           (mem_in_wr_en_a),
        .mem_in_wr_addr         (mem_in_wr_addr_a),
        .mem_in_wr_data         (mem_in_wr_data_a),
        .mem_out_rd_en          (mem_out_rd_en_b),
        .mem_out_rd_addr        (mem_out_rd_addr_b),
        .mem_out_rd_data        (mem_out_rd_data_b),
        .pixels_written         (pixels_written)
    );

    // ========================================================================
    // Instancia: Memoria de entrada (64x64 = 4096 píxeles)
    // ========================================================================
    image_memory_input u_mem_input (
        .clk                    (CLOCK_50),
        .rst_n                  (rst_n),
        // Puerto A: escritura desde JTAG
        .wr_en_a                (mem_in_wr_en_a),
        .wr_addr_a              (mem_in_wr_addr_a),
        .wr_data_a              (mem_in_wr_data_a),
        // Puerto B: lectura desde downscaler
        .rd_en_b                (mem_in_rd_en_b),
        .rd_addr_b              (mem_in_rd_addr_b),
        .rd_data_b              (mem_in_rd_data_b)
    );

    // ========================================================================
    // Instancia: Memoria de salida (32x32 = 1024 píxeles)
    // ========================================================================
    image_memory_output u_mem_output (
        .clk                    (CLOCK_50),
        .rst_n                  (rst_n),
        // Puerto A: escritura desde downscaler
        .wr_en_a                (mem_out_wr_en_a),
        .wr_addr_a              (mem_out_wr_addr_a),
        .wr_data_a              (mem_out_wr_data_a),
        // Puerto B: lectura desde JTAG
        .rd_en_b                (mem_out_rd_en_b),
        .rd_addr_b              (mem_out_rd_addr_b),
        .rd_data_b              (mem_out_rd_data_b),
        .pixels_written         (pixels_written)
    );

    // ========================================================================
    // Instancia: Downscaler secuencial con pipeline
    // ========================================================================
    downscale_sequential u_downscaler (
        .clk                    (CLOCK_50),
        .rst_n                  (rst_n),
        .start                  (start_processing),
        .busy                   (busy),
        .done                   (done),
        // Lectura de memoria de entrada
        .mem_in_rd_en           (mem_in_rd_en_b),
        .mem_in_rd_addr         (mem_in_rd_addr_b),
        .mem_in_rd_data         (mem_in_rd_data_b),
        // Escritura en memoria de salida
        .mem_out_wr_en          (mem_out_wr_en_a),
        .mem_out_wr_addr        (mem_out_wr_addr_a),
        .mem_out_wr_data        (mem_out_wr_data_a)
    );

    // ========================================================================
    // LEDs de debug
    // ========================================================================
    // LEDR[0]: done
    // LEDR[1]: busy
    // LEDR[2]: start_processing
    // LEDR[3]: reset_memories
    // LEDR[9:4]: pixels_written[5:0] (LSBs del contador)

    assign LEDR[0] = done;
    assign LEDR[1] = busy;
    assign LEDR[2] = start_processing;
    assign LEDR[3] = reset_memories;
    assign LEDR[9:4] = pixels_written[5:0];

    // ========================================================================
    // Reset de memorias (opcional)
    // ========================================================================
    // Si se requiere reset de contenido de memorias via JTAG,
    // se puede implementar aquí con lógica adicional
    // Por ahora, reset_memories solo se reporta en STATUS

endmodule
