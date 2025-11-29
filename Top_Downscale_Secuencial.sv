module Top_Downscale_Secuencial #(
    parameter int SRC_W = 512,
    parameter int SRC_H = 512,
    parameter int DST_W = 256,
    parameter int DST_H = 256
)(
    input  logic clk,
    input  logic rst,
    
    input  logic        cfg_we,
    input  logic [17:0] cfg_addr,
    input  logic [7:0]  cfg_data,
    
    input  logic        start_req,
    output logic        done,
    
    output logic [7:0]  dbg_data
);
    
    // Señales de lectura
    logic                           mem_rd_req;
    logic [$clog2(SRC_W*SRC_H)-1:0] mem_rd_addr;
    logic                           mem_rd_valid;
    logic [7:0]                     mem_rd_data;
    
    // Memoria de entrada con handshake
    ImageMemory_SeqPort #(
        .WIDTH(SRC_W),
        .HEIGHT(SRC_H)
    ) mem (
        .clk(clk),
        .rst(rst),
        .wr_en(cfg_we),
        .wr_addr(cfg_addr),
        .wr_data(cfg_data),
        .rd_req(mem_rd_req),
        .rd_addr(mem_rd_addr),
        .rd_valid(mem_rd_valid),
        .rd_data(mem_rd_data)
    );
    
    // Memoria BRAM de salida
    logic                           out_mem_we;
    logic [$clog2(DST_W*DST_H)-1:0] out_mem_addr;
    logic [7:0]                     out_mem_data;
    
    logic [7:0] output_memory [0:DST_H*DST_W-1];
    
    always_ff @(posedge clk) begin
        if (out_mem_we)
            output_memory[out_mem_addr] <= out_mem_data;
    end
    
    // Downscale
    Downscale_Secuencial #(
        .SRC_W(SRC_W), .SRC_H(SRC_H),
        .DST_W(DST_W), .DST_H(DST_H)
    ) u_seq (
        .clk(clk),
        .rst(rst),
        .start(start_req),
        .mem_rd_req(mem_rd_req),
        .mem_rd_addr(mem_rd_addr),
        .mem_rd_valid(mem_rd_valid),
        .mem_rd_data(mem_rd_data),
        .out_mem_we(out_mem_we),
        .out_mem_addr(out_mem_addr),
        .out_mem_data(out_mem_data),
        .done(done)
    );
    
    assign dbg_data = mem_rd_data;

endmodule 