/**
 * DSA_Avalon_Wrapper.sv
 * 
 * VERSIÓN OPTIMIZADA: Sin arrays internos, escrituras directas
 */

module DSA_Avalon_Wrapper #(
    parameter int N = 4
)(
    input  logic        clk,
    input  logic        reset_n,
    
    input  logic [3:0]  avs_ctrl_address,
    input  logic        avs_ctrl_read,
    input  logic        avs_ctrl_write,
    input  logic [31:0] avs_ctrl_writedata,
    output logic [31:0] avs_ctrl_readdata,
    output logic        avs_ctrl_waitrequest,
    
    output logic [31:0] avm_mem_address,
    output logic        avm_mem_read,
    output logic        avm_mem_write,
    output logic [31:0] avm_mem_writedata,
    output logic [3:0]  avm_mem_byteenable,
    input  logic        avm_mem_waitrequest,
    input  logic [31:0] avm_mem_readdata,
    input  logic        avm_mem_readdatavalid
);

    logic        dsa_start;
    logic        dsa_reset_counters;
    logic        dsa_mode;
    logic [31:0] dsa_img_width_in;
    logic [31:0] dsa_img_height_in;
    logic [31:0] dsa_scale_factor;    // Q8.8: 128-256 = 0.5-1.0
    logic [31:0] dsa_img_width_out;   // Calculado = width_in * scale_factor >> 8
    logic [31:0] dsa_img_height_out;  // Calculado = height_in * scale_factor >> 8
    logic [31:0] dsa_input_base;
    logic [31:0] dsa_output_base;
    
    logic        dsa_busy;
    logic        dsa_done;
    logic        dsa_error;
    logic [31:0] dsa_perf_cycles;
    logic [31:0] dsa_perf_reads;
    logic [31:0] dsa_perf_writes;
    logic [31:0] dsa_perf_flops;

    DSA_Control_Registers u_control_regs (
        .clk                (clk),
        .reset_n            (reset_n),
        .avs_address        (avs_ctrl_address),
        .avs_read           (avs_ctrl_read),
        .avs_write          (avs_ctrl_write),
        .avs_writedata      (avs_ctrl_writedata),
        .avs_readdata       (avs_ctrl_readdata),
        .avs_waitrequest    (avs_ctrl_waitrequest),
        .dsa_start          (dsa_start),
        .dsa_reset_counters (dsa_reset_counters),
        .dsa_mode           (dsa_mode),
        .dsa_img_width_in   (dsa_img_width_in),
        .dsa_img_height_in  (dsa_img_height_in),
        .dsa_scale_factor   (dsa_scale_factor),
        .dsa_input_base     (dsa_input_base),
        .dsa_output_base    (dsa_output_base),
        .dsa_busy           (dsa_busy),
        .dsa_done           (dsa_done),
        .dsa_error          (dsa_error),
        .dsa_perf_cycles    (dsa_perf_cycles),
        .dsa_perf_reads     (dsa_perf_reads),
        .dsa_perf_writes    (dsa_perf_writes),
        .dsa_perf_flops     (dsa_perf_flops)
    );
	 
 
    // ========== Calcular dimensiones de salida desde scale_factor ==========
    always_comb begin
        dsa_img_width_out  = (dsa_img_width_in * dsa_scale_factor) >> 8;
        dsa_img_height_out = (dsa_img_height_in * dsa_scale_factor) >> 8;
    end

    // ========== CAMBIO: Señales de escritura SIMD ==========
    logic        simd_mem_rd_req   [N];
    logic [31:0] simd_mem_rd_addr  [N];
    logic        simd_mem_rd_valid [N];
    logic [7:0]  simd_mem_rd_data  [N];
    logic        simd_out_mem_we;
    logic [31:0] simd_out_mem_addr;
    logic [7:0]  simd_out_mem_data;
    logic        simd_done;
    
    logic        seq_mem_rd_req;
    logic [31:0] seq_mem_rd_addr;
    logic        seq_mem_rd_valid;
    logic [7:0]  seq_mem_rd_data;
    logic        seq_out_mem_we;
    logic [31:0] seq_out_mem_addr;
    logic [7:0]  seq_out_mem_data;
    logic        seq_done;
    
    logic        adapter_busy;
    logic [31:0] adapter_perf_reads;
    logic [31:0] adapter_perf_writes;

    // ========== Downscale_SIMD con dimensiones dinámicas ==========
    Downscale_SIMD #(
        .N          (N)
    ) u_downscale_simd (
        .clk            (clk),
        .rst            (!reset_n),
        .start          (dsa_start && dsa_mode == 1'b1),
        .img_width_in   (dsa_img_width_in),
        .img_height_in  (dsa_img_height_in),
        .img_width_out  (dsa_img_width_out),
        .img_height_out (dsa_img_height_out),
        .mem_rd_req     (simd_mem_rd_req),
        .mem_rd_addr    (simd_mem_rd_addr),
        .mem_rd_valid   (simd_mem_rd_valid),
        .mem_rd_data    (simd_mem_rd_data),
        .out_mem_we     (simd_out_mem_we),
        .out_mem_addr   (simd_out_mem_addr),
        .out_mem_data   (simd_out_mem_data),
        .done           (simd_done)
    );

    Downscale_Secuencial u_downscale_seq (
        .clk            (clk),
        .rst            (!reset_n),
        .start          (dsa_start && dsa_mode == 1'b0),
        .img_width_in   (dsa_img_width_in),
        .img_height_in  (dsa_img_height_in),
        .img_width_out  (dsa_img_width_out),
        .img_height_out (dsa_img_height_out),
        .mem_rd_req     (seq_mem_rd_req),
        .mem_rd_addr    (seq_mem_rd_addr),
        .mem_rd_valid   (seq_mem_rd_valid),
        .mem_rd_data    (seq_mem_rd_data),
        .out_mem_we     (seq_out_mem_we),
        .out_mem_addr   (seq_out_mem_addr),
        .out_mem_data   (seq_out_mem_data),
        .done           (seq_done)
    );

    // ========== Adaptador de memoria ==========
    DSA_Memory_Adapter #(
        .N              (N),
        .MAX_WIDTH      (512),
        .MAX_HEIGHT     (512)
    ) u_memory_adapter (
        .clk                (clk),
        .reset_n            (reset_n),
        .dsa_mode           (dsa_mode),
        .input_base_addr    (dsa_input_base),
        .output_base_addr   (dsa_output_base),
        .img_width_out      (dsa_img_width_out),
        .img_height_out     (dsa_img_height_out),
        .dsa_core_done      (dsa_mode ? simd_done : seq_done),
        .adapter_busy       (adapter_busy),
        .simd_mem_rd_req    (simd_mem_rd_req),
        .simd_mem_rd_addr   (simd_mem_rd_addr),
        .simd_mem_rd_valid  (simd_mem_rd_valid),
        .simd_mem_rd_data   (simd_mem_rd_data),
        .simd_wr_req        (simd_out_mem_we),
        .simd_wr_addr       (simd_out_mem_addr),
        .simd_wr_data       (simd_out_mem_data),
        .seq_mem_rd_req     (seq_mem_rd_req),
        .seq_mem_rd_addr    (seq_mem_rd_addr),
        .seq_mem_rd_valid   (seq_mem_rd_valid),
        .seq_mem_rd_data    (seq_mem_rd_data),
        .seq_wr_req         (seq_out_mem_we),
        .seq_wr_addr        (seq_out_mem_addr),
        .seq_wr_data        (seq_out_mem_data),
        .avm_address        (avm_mem_address),
        .avm_read           (avm_mem_read),
        .avm_write          (avm_mem_write),
        .avm_writedata      (avm_mem_writedata),
        .avm_byteenable     (avm_mem_byteenable),
        .avm_waitrequest    (avm_mem_waitrequest),
        .avm_readdata       (avm_mem_readdata),
        .avm_readdatavalid  (avm_mem_readdatavalid),
        .perf_mem_reads     (adapter_perf_reads),
        .perf_mem_writes    (adapter_perf_writes)
    );

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
    
    // ========== CAMBIO: Done inmediato (sin writeback) ==========
    always_comb begin
        dsa_busy = dsa_core_running;
        dsa_done = (dsa_mode ? simd_done : seq_done);
    end
    
    assign dsa_error = 1'b0;

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            dsa_perf_cycles <= 32'd0;
        end else if (dsa_reset_counters) begin
            dsa_perf_cycles <= 32'd0;
        end else if (dsa_busy) begin
            dsa_perf_cycles <= dsa_perf_cycles + 1;
        end
    end

    assign dsa_perf_reads  = adapter_perf_reads;
    assign dsa_perf_writes = adapter_perf_writes;

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
            dsa_perf_flops <= total_pixels_processed * 32'd10;
            flops_counted  <= 1'b1;
        end
    end

endmodule 