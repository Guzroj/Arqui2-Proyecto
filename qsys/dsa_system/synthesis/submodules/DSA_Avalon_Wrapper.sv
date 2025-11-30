/**
 * DSA_Avalon_Wrapper.sv
 * 
 * Wrapper principal del DSA Downscaler con interfaz Avalon-MM
 * Integra registros de control, adaptador de memoria, y cores DSA (SIMD + Secuencial)
 * 
 * Componentes:
 * - DSA_Control_Registers: Interfaz Avalon-MM Slave (registros de control/estado)
 * - DSA_Memory_Adapter: Interfaz Avalon-MM Master (acceso a memorias Qsys)
 * - Downscale_SIMD: Core de procesamiento SIMD (N lanes paralelos)
 * - Downscale_Secuencial: Core de procesamiento secuencial (1 lane)
 * - Performance Counters: Ciclos, lecturas, escrituras, FLOPs
 * 
 * Interfaz Avalon-MM:
 * - Slave: Registros de control @ 0x00050010
 * - Master: Memorias (input @ 0x00000000, output @ 0x00040000)
 */

module DSA_Avalon_Wrapper #(
    parameter int N = 4,                    // SIMD lanes
    parameter int MAX_SRC_W = 512,          // Máximo ancho entrada
    parameter int MAX_SRC_H = 512,          // Máximo alto entrada
    parameter int MAX_DST_W = 512,          // Máximo ancho salida
    parameter int MAX_DST_H = 512           // Máximo alto salida
)(
    // ========== Clock y Reset ==========
    input  logic        clk,
    input  logic        reset_n,
    
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

    // =========================================================================
    // Señales de Control desde Registros
    // =========================================================================
    logic        dsa_start;
    logic        dsa_reset_counters;
    logic        dsa_mode;              // 0=Secuencial, 1=SIMD
    logic [31:0] dsa_img_width_in;
    logic [31:0] dsa_img_height_in;
    logic [31:0] dsa_img_width_out;
    logic [31:0] dsa_img_height_out;
    logic [31:0] dsa_input_base;
    logic [31:0] dsa_output_base;
    
    // Señales de Estado hacia Registros
    logic        dsa_busy;
    logic        dsa_done;
    logic        dsa_error;
    logic [31:0] dsa_perf_cycles;
    logic [31:0] dsa_perf_reads;
    logic [31:0] dsa_perf_writes;
    logic [31:0] dsa_perf_flops;

    // =========================================================================
    // Instancia: DSA_Control_Registers (Avalon-MM Slave)
    // =========================================================================
    DSA_Control_Registers u_control_regs (
        .clk                (clk),
        .reset_n            (reset_n),
        
        // Avalon-MM Slave
        .avs_address        (avs_ctrl_address),
        .avs_read           (avs_ctrl_read),
        .avs_write          (avs_ctrl_write),
        .avs_writedata      (avs_ctrl_writedata),
        .avs_readdata       (avs_ctrl_readdata),
        .avs_waitrequest    (avs_ctrl_waitrequest),
        
        // Señales de Control hacia DSA
        .dsa_start          (dsa_start),
        .dsa_reset_counters (dsa_reset_counters),
        .dsa_mode           (dsa_mode),
        .dsa_img_width_in   (dsa_img_width_in),
        .dsa_img_height_in  (dsa_img_height_in),
        .dsa_img_width_out  (dsa_img_width_out),
        .dsa_img_height_out (dsa_img_height_out),
        .dsa_input_base     (dsa_input_base),
        .dsa_output_base    (dsa_output_base),
        
        // Señales de Estado desde DSA
        .dsa_busy           (dsa_busy),
        .dsa_done           (dsa_done),
        .dsa_error          (dsa_error),
        .dsa_perf_cycles    (dsa_perf_cycles),
        .dsa_perf_reads     (dsa_perf_reads),
        .dsa_perf_writes    (dsa_perf_writes),
        .dsa_perf_flops     (dsa_perf_flops)
    );

    // =========================================================================
    // Señales de Interfaz SIMD
    // =========================================================================
    logic        simd_mem_rd_req   [N];
    logic [31:0] simd_mem_rd_addr  [N];
    logic        simd_mem_rd_valid [N];
    logic [7:0]  simd_mem_rd_data  [N];
    logic        simd_done;
    logic [7:0]  simd_image_out    [0:MAX_DST_H-1][0:MAX_DST_W-1];
    
    // =========================================================================
    // Señales de Interfaz Secuencial
    // =========================================================================
    logic        seq_mem_rd_req;
    logic [31:0] seq_mem_rd_addr;
    logic        seq_mem_rd_valid;
    logic [7:0]  seq_mem_rd_data;
    logic        seq_out_mem_we;
    logic [31:0] seq_out_mem_addr;
    logic [7:0]  seq_out_mem_data;
    logic        seq_done;
    
    // =========================================================================
    // Señales del Adaptador de Memoria
    // =========================================================================
    logic        adapter_busy;
    logic [31:0] adapter_perf_reads;
    logic [31:0] adapter_perf_writes;

    // =========================================================================
    // Instancia: Downscale_SIMD
    // =========================================================================
    Downscale_SIMD #(
        .SRC_H      (MAX_SRC_H),
        .SRC_W      (MAX_SRC_W),
        .DST_H      (MAX_DST_H),
        .DST_W      (MAX_DST_W),
        .N          (N)
    ) u_downscale_simd (
        .clk           (clk),
        .rst           (!reset_n),
        .start         (dsa_start && dsa_mode == 1'b1),
        
        // Interfaz de memoria
        .mem_rd_req    (simd_mem_rd_req),
        .mem_rd_addr   (simd_mem_rd_addr),
        .mem_rd_valid  (simd_mem_rd_valid),
        .mem_rd_data   (simd_mem_rd_data),
        
        // Salida
        .done          (simd_done),
        .image_out     (simd_image_out)
    );

    // =========================================================================
    // Instancia: Downscale_Secuencial
    // =========================================================================
    Downscale_Secuencial #(
        .SRC_H      (MAX_SRC_H),
        .SRC_W      (MAX_SRC_W),
        .DST_H      (MAX_DST_H),
        .DST_W      (MAX_DST_W)
    ) u_downscale_seq (
        .clk           (clk),
        .rst           (!reset_n),
        .start         (dsa_start && dsa_mode == 1'b0),
        
        // Interfaz de lectura
        .mem_rd_req    (seq_mem_rd_req),
        .mem_rd_addr   (seq_mem_rd_addr),
        .mem_rd_valid  (seq_mem_rd_valid),
        .mem_rd_data   (seq_mem_rd_data),
        
        // Interfaz de escritura
        .out_mem_we    (seq_out_mem_we),
        .out_mem_addr  (seq_out_mem_addr),
        .out_mem_data  (seq_out_mem_data),
        
        // Control
        .done          (seq_done)
    );

    // =========================================================================
    // Instancia: DSA_Memory_Adapter (Avalon-MM Master)
    // =========================================================================
    DSA_Memory_Adapter #(
        .N              (N),
        .MAX_WIDTH      (MAX_DST_W),
        .MAX_HEIGHT     (MAX_DST_H)
    ) u_memory_adapter (
        .clk                (clk),
        .reset_n            (reset_n),
        
        // Control
        .dsa_mode           (dsa_mode),
        .input_base_addr    (dsa_input_base),
        .output_base_addr   (dsa_output_base),
        .img_width_out      (dsa_img_width_out),
        .img_height_out     (dsa_img_height_out),
        
        // Estado DSA
        .dsa_core_done      (dsa_mode ? simd_done : seq_done),
        .adapter_busy       (adapter_busy),
        
        // SIMD - Lecturas
        .simd_mem_rd_req    (simd_mem_rd_req),
        .simd_mem_rd_addr   (simd_mem_rd_addr),
        .simd_mem_rd_valid  (simd_mem_rd_valid),
        .simd_mem_rd_data   (simd_mem_rd_data),
        
        // SIMD - Salida
        .simd_image_out     (simd_image_out),
        
        // Secuencial - Lecturas
        .seq_mem_rd_req     (seq_mem_rd_req),
        .seq_mem_rd_addr    (seq_mem_rd_addr),
        .seq_mem_rd_valid   (seq_mem_rd_valid),
        .seq_mem_rd_data    (seq_mem_rd_data),
        
        // Secuencial - Escrituras
        .seq_wr_req         (seq_out_mem_we),
        .seq_wr_addr        (seq_out_mem_addr),
        .seq_wr_data        (seq_out_mem_data),
        
        // Avalon-MM Master
        .avm_address        (avm_mem_address),
        .avm_read           (avm_mem_read),
        .avm_write          (avm_mem_write),
        .avm_writedata      (avm_mem_writedata),
        .avm_byteenable     (avm_mem_byteenable),
        .avm_waitrequest    (avm_mem_waitrequest),
        .avm_readdata       (avm_mem_readdata),
        .avm_readdatavalid  (avm_mem_readdatavalid),
        
        // Performance
        .perf_mem_reads     (adapter_perf_reads),
        .perf_mem_writes    (adapter_perf_writes)
    );

    // =========================================================================
    // Lógica de Control y Estado
    // =========================================================================
    
    // Señal de busy: DSA procesando o adaptador escribiendo
    logic dsa_core_running;
    
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            dsa_core_running <= 1'b0;
        end else begin
            if (dsa_start) begin
                dsa_core_running <= 1'b1;
            end else if ((dsa_mode == 1'b1 && simd_done) || (dsa_mode == 1'b0 && seq_done)) begin
                dsa_core_running <= 1'b0;
            end
        end
    end
    
    always_comb begin
        // Busy cuando el core está corriendo o el adaptador está escribiendo
        dsa_busy = dsa_core_running || adapter_busy;
    end
    
    // Señal de done: pulso cuando completamente terminado
    logic adapter_busy_prev;
    
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            dsa_done         <= 1'b0;
            adapter_busy_prev <= 1'b0;
        end else begin
            adapter_busy_prev <= adapter_busy;
            
            // Done cuando adaptador termina writeback (flanco descendente de adapter_busy)
            if (adapter_busy_prev && !adapter_busy) begin
                dsa_done <= 1'b1;
            end else begin
                dsa_done <= 1'b0;
            end
        end
    end
    
    // Señal de error (por ahora sin implementar)
    assign dsa_error = 1'b0;

    // =========================================================================
    // Performance Counter: Ciclos de Reloj
    // =========================================================================
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            dsa_perf_cycles <= 32'd0;
        end else if (dsa_reset_counters) begin
            dsa_perf_cycles <= 32'd0;
        end else if (dsa_busy) begin
            dsa_perf_cycles <= dsa_perf_cycles + 1;
        end
    end

    // =========================================================================
    // Performance Counter: Lecturas y Escrituras (desde adaptador)
    // =========================================================================
    assign dsa_perf_reads  = adapter_perf_reads;
    assign dsa_perf_writes = adapter_perf_writes;

    // =========================================================================
    // Performance Counter: FLOPs (Operaciones de Punto Flotante)
    // =========================================================================
    // Aproximación: cada píxel interpolado = ~10 operaciones
    // (4 multiplicaciones de términos + 3 sumas + 1 shift + 1 redondeo + 1 saturación)
    
    logic [31:0] total_pixels_processed;
    logic        flops_counted;
    
    always_comb begin
        total_pixels_processed = dsa_img_width_out * dsa_img_height_out;
    end
    
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            dsa_perf_flops <= 32'd0;
            flops_counted  <= 1'b0;
        end else if (dsa_reset_counters) begin
            dsa_perf_flops <= 32'd0;
            flops_counted  <= 1'b0;
        end else if (dsa_start) begin
            flops_counted <= 1'b0;
        end else if (dsa_done && !flops_counted) begin
            // Al completar, contar 10 FLOPs por píxel (solo una vez)
            dsa_perf_flops <= total_pixels_processed * 32'd10;
            flops_counted  <= 1'b1;
        end
    end

endmodule

