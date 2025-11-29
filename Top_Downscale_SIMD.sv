// ======================================================
// Top_Downscale_SIMD.sv (FIX para Quartus 20.1.1)
// Conecta memoria SIMD con Downscale_SIMD
// ======================================================

module Top_Downscale_SIMD #(
    parameter int SRC_W = 32,
    parameter int SRC_H = 32,
    parameter int DST_W = 16,
    parameter int DST_H = 16,
    parameter int N     = 4
)(
    input  logic clk,
    input  logic rst,

    input  logic        cfg_we,
    input  logic [31:0] cfg_addr,    // Aumentado a 32 bits para soportar imagenes grandes
    input  logic [7:0]  cfg_data,

    input  logic        start_req,

    output logic        done,
    output logic [7:0]  dbg_data
);

    localparam int SRC_DEPTH = SRC_W * SRC_H;
    localparam int ADDR_BITS = $clog2(SRC_DEPTH);

    // ==================================================
    // Señales de interfaz de memoria SIMD
    // ==================================================
    logic                   mem_rd_req   [N];
    logic [ADDR_BITS-1:0]   mem_rd_addr  [N];
    logic                   mem_rd_valid [N];
    logic [7:0]             mem_rd_data  [N];

    // ==================================================
    // Memoria con puertos SIMD
    // ==================================================
    ImageMemory_SIMDPort #(
        .WIDTH  (SRC_W),
        .HEIGHT (SRC_H),
        .N      (N)
    ) mem (
        .clk     (clk),
        .rst     (rst),
        .rd_req  (mem_rd_req),
        .rd_addr (mem_rd_addr),
        .rd_valid(mem_rd_valid),
        .rd_data (mem_rd_data),
        .wr_en   (cfg_we),
        .wr_addr (cfg_addr[ADDR_BITS-1:0]),
        .wr_data (cfg_data)
    );

    // ==================================================
    // Buffer de salida
    // ==================================================
    logic [7:0] image_out [0:DST_H-1][0:DST_W-1];

    // ==================================================
    // Downscale SIMD (usa interfaz de memoria)
    // ==================================================
    Downscale_SIMD #(
        .SRC_H(SRC_H),
        .SRC_W(SRC_W),
        .DST_H(DST_H),
        .DST_W(DST_W),
        .N(N)
    ) u_downscale (
        .clk          (clk),
        .rst          (rst),
        .start        (start_req),
        
        // Interfaz de memoria
        .mem_rd_req   (mem_rd_req),
        .mem_rd_addr  (mem_rd_addr),
        .mem_rd_valid (mem_rd_valid),
        .mem_rd_data  (mem_rd_data),
        
        // Salidas
        .done         (done),
        .image_out    (image_out)
    );

    // ==================================================
    // Debug output (usa primer pixel de salida para evitar warning)
    // ==================================================
    assign dbg_data = image_out[0][0];

endmodule
