// ============================================================================
// DSA_Avalon_Wrapper.sv
// ============================================================================
// Descripción:
//   Wrapper principal que integra todos los componentes del DSA:
//   - Control Registers (configuración vía Avalon-MM)
//   - Memory Adapter (convierte byte-wise a Avalon-MM)
//   - Downscale_Secuencial (core secuencial)
//   - Downscale_SIMD (core paralelo N=4)
//
// Interfaces Avalon-MM:
//   - Slave: Registros de control/estado
//   - Master: Acceso a memorias (input/output)
//
// Modos de Operación:
//   - Modo 0 (Secuencial): Procesa 1 píxel por ciclo
//   - Modo 1 (SIMD): Procesa N píxeles por ciclo (N=4)
//
// Performance Counters:
//   - Ciclos: Tiempo total de procesamiento
//   - Reads/Writes: Accesos a memoria
//   - FLOPs: Operaciones de punto flotante estimadas
//
// Autor: DSA Project Team
// Fecha: Noviembre 2025
// ============================================================================

`timescale 1ns/1ps

module DSA_Avalon_Wrapper #(
    parameter int N = 4  // SIMD lanes
)(
    input  logic        clk,
    input  logic        rst,

    // ========== Avalon-MM Slave (Registros de Control) ==========
    input  logic [3:0]  avs_ctrl_address,
    input  logic        avs_ctrl_read,
    input  logic        avs_ctrl_write,
    input  logic [31:0] avs_ctrl_writedata,
    output logic [31:0] avs_ctrl_readdata,
    output logic        avs_ctrl_waitrequest,

    // ========== Avalon-MM Master (Acceso a Memorias) ==========
    output logic [31:0] avm_mem_address,
    output logic        avm_mem_read,
    output logic        avm_mem_write,
    output logic [31:0] avm_mem_writedata,
    output logic [3:0]  avm_mem_byteenable,
    input  logic        avm_mem_waitrequest,
    input  logic [31:0] avm_mem_readdata,
    input  logic        avm_mem_readdatavalid
);

    // ========================================================================
    // Señales de Control (desde Control Registers)
    // ========================================================================
    logic        dsa_start;
    logic        dsa_reset_counters;
    logic        dsa_mode;  // 0=Seq, 1=SIMD
    logic [31:0] dsa_img_width_in;
    logic [31:0] dsa_img_height_in;
    logic [31:0] dsa_img_width_out;
    logic [31:0] dsa_img_height_out;
    logic [31:0] dsa_input_base;
    logic [31:0] dsa_output_base;

    // ========================================================================
    // Señales de Estado (hacia Control Registers)
    // ========================================================================
    logic        dsa_busy;
    logic        dsa_done;
    logic        dsa_error;
    logic [31:0] dsa_perf_cycles;
    logic [31:0] dsa_perf_reads;
    logic [31:0] dsa_perf_writes;
    logic [31:0] dsa_perf_flops;

    // ========================================================================
    // Instancia: DSA_Control_Registers
    // ========================================================================
    DSA_Control_Registers u_control_regs (
        .clk                  (clk),
        .rst                  (rst),

        // Avalon-MM Slave
        .avs_address          (avs_ctrl_address),
        .avs_read             (avs_ctrl_read),
        .avs_write            (avs_ctrl_write),
        .avs_writedata        (avs_ctrl_writedata),
        .avs_readdata         (avs_ctrl_readdata),
        .avs_waitrequest      (avs_ctrl_waitrequest),

        // Control hacia DSA
        .dsa_start            (dsa_start),
        .dsa_reset_counters   (dsa_reset_counters),
        .dsa_mode             (dsa_mode),
        .dsa_img_width_in     (dsa_img_width_in),
        .dsa_img_height_in    (dsa_img_height_in),
        .dsa_img_width_out    (dsa_img_width_out),
        .dsa_img_height_out   (dsa_img_height_out),
        .dsa_input_base       (dsa_input_base),
        .dsa_output_base      (dsa_output_base),

        // Estado desde DSA
        .dsa_busy             (dsa_busy),
        .dsa_done             (dsa_done),
        .dsa_error            (dsa_error),
        .dsa_perf_cycles      (dsa_perf_cycles),
        .dsa_perf_reads       (dsa_perf_reads),
        .dsa_perf_writes      (dsa_perf_writes),
        .dsa_perf_flops       (dsa_perf_flops)
    );

    // ========================================================================
    // Señales del Core Secuencial
    // ========================================================================
    logic        seq_start;
    logic        seq_done;
    logic        seq_mem_rd_req;
    logic [31:0] seq_mem_rd_addr;
    logic        seq_mem_rd_valid;
    logic [7:0]  seq_mem_rd_data;
    logic        seq_out_mem_we;
    logic [31:0] seq_out_mem_addr;
    logic [7:0]  seq_out_mem_data;

    // ========================================================================
    // Señales del Core SIMD
    // ========================================================================
    logic        simd_start;
    logic        simd_done;
    logic        simd_mem_rd_req   [N];
    logic [31:0] simd_mem_rd_addr  [N];
    logic        simd_mem_rd_valid [N];
    logic [7:0]  simd_mem_rd_data  [N];
    logic        simd_out_mem_we;
    logic [31:0] simd_out_mem_addr;
    logic [7:0]  simd_out_mem_data;

    // ========================================================================
    // Lógica de Selección de Modo
    // ========================================================================
    logic dsa_core_running;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            dsa_core_running <= 1'b0;
        end else begin
            if (dsa_start)
                dsa_core_running <= 1'b1;
            else if (dsa_done)
                dsa_core_running <= 1'b0;
        end
    end

    assign seq_start  = dsa_start && (dsa_mode == 1'b0);
    assign simd_start = dsa_start && (dsa_mode == 1'b1);

    assign dsa_busy  = dsa_core_running;
    assign dsa_done  = dsa_mode ? simd_done : seq_done;
    assign dsa_error = 1'b0;  // Por ahora sin manejo de errores

    // ========================================================================
    // Instancia: Downscale_Secuencial
    // ========================================================================
    Downscale_Secuencial u_downscale_seq (
        .clk             (clk),
        .rst             (rst),
        .start           (seq_start),

        // Dimensiones dinámicas
        .img_width_in    (dsa_img_width_in),
        .img_height_in   (dsa_img_height_in),
        .img_width_out   (dsa_img_width_out),
        .img_height_out  (dsa_img_height_out),

        // Interfaz de memoria - Lecturas
        .mem_rd_req      (seq_mem_rd_req),
        .mem_rd_addr     (seq_mem_rd_addr),
        .mem_rd_valid    (seq_mem_rd_valid),
        .mem_rd_data     (seq_mem_rd_data),

        // Interfaz de memoria - Escrituras
        .out_mem_we      (seq_out_mem_we),
        .out_mem_addr    (seq_out_mem_addr),
        .out_mem_data    (seq_out_mem_data),

        .done            (seq_done)
    );

    // ========================================================================
    // Instancia: Downscale_SIMD
    // ========================================================================
    Downscale_SIMD #(.N(N)) u_downscale_simd (
        .clk             (clk),
        .rst             (rst),
        .start           (simd_start),

        // Dimensiones dinámicas
        .img_width_in    (dsa_img_width_in),
        .img_height_in   (dsa_img_height_in),
        .img_width_out   (dsa_img_width_out),
        .img_height_out  (dsa_img_height_out),

        // Interfaz de memoria - Lecturas (N puertos)
        .mem_rd_req      (simd_mem_rd_req),
        .mem_rd_addr     (simd_mem_rd_addr),
        .mem_rd_valid    (simd_mem_rd_valid),
        .mem_rd_data     (simd_mem_rd_data),

        // Interfaz de memoria - Escrituras
        .out_mem_we      (simd_out_mem_we),
        .out_mem_addr    (simd_out_mem_addr),
        .out_mem_data    (simd_out_mem_data),

        .done            (simd_done)
    );

    // ========================================================================
    // Instancia: DSA_Memory_Adapter
    // ========================================================================
    DSA_Memory_Adapter #(.N(N)) u_memory_adapter (
        .clk                  (clk),
        .rst                  (rst),

        // Base addresses
        .input_base_addr      (dsa_input_base),
        .output_base_addr     (dsa_output_base),

        // SIMD - Lecturas
        .simd_mem_rd_req      (simd_mem_rd_req),
        .simd_mem_rd_addr     (simd_mem_rd_addr),
        .simd_mem_rd_valid    (simd_mem_rd_valid),
        .simd_mem_rd_data     (simd_mem_rd_data),

        // SIMD - Escrituras
        .simd_wr_req          (simd_out_mem_we),
        .simd_wr_addr         (simd_out_mem_addr),
        .simd_wr_data         (simd_out_mem_data),

        // Secuencial - Lecturas
        .seq_mem_rd_req       (seq_mem_rd_req),
        .seq_mem_rd_addr      (seq_mem_rd_addr),
        .seq_mem_rd_valid     (seq_mem_rd_valid),
        .seq_mem_rd_data      (seq_mem_rd_data),

        // Secuencial - Escrituras
        .seq_wr_req           (seq_out_mem_we),
        .seq_wr_addr          (seq_out_mem_addr),
        .seq_wr_data          (seq_out_mem_data),

        // Avalon-MM Master
        .avm_address          (avm_mem_address),
        .avm_read             (avm_mem_read),
        .avm_write            (avm_mem_write),
        .avm_writedata        (avm_mem_writedata),
        .avm_byteenable       (avm_mem_byteenable),
        .avm_waitrequest      (avm_mem_waitrequest),
        .avm_readdata         (avm_mem_readdata),
        .avm_readdatavalid    (avm_mem_readdatavalid),

        // Performance counters
        .perf_mem_reads       (dsa_perf_reads),
        .perf_mem_writes      (dsa_perf_writes)
    );

    // ========================================================================
    // Performance Counter: Ciclos
    // ========================================================================
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            dsa_perf_cycles <= 32'd0;
        end else begin
            if (dsa_reset_counters) begin
                dsa_perf_cycles <= 32'd0;
            end else if (dsa_busy) begin
                dsa_perf_cycles <= dsa_perf_cycles + 32'd1;
            end
        end
    end

    // ========================================================================
    // Performance Counter: FLOPs (estimado)
    // ========================================================================
    logic [31:0] total_output_pixels;
    logic        flops_counted;

    assign total_output_pixels = dsa_img_width_out * dsa_img_height_out;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            dsa_perf_flops <= 32'd0;
            flops_counted  <= 1'b0;
        end else begin
            if (dsa_reset_counters) begin
                dsa_perf_flops <= 32'd0;
                flops_counted  <= 1'b0;
            end else if (dsa_done && !flops_counted) begin
                // ~10 operaciones por píxel interpolado
                dsa_perf_flops <= total_output_pixels * 32'd10;
                flops_counted  <= 1'b1;
            end else if (dsa_start) begin
                flops_counted <= 1'b0;
            end
        end
    end

endmodule
