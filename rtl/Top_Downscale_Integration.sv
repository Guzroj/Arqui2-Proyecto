`timescale 1ns/1ps

module Top_Downscale_Integration #(
    parameter int SRC_H = 32,
    parameter int SRC_W = 32,
    parameter int DST_H = 16,
    parameter int DST_W = 16,
    parameter int N     = 4          // SIMD width
)(
    input  logic clk,
    input  logic rst,
    
    // Control principal
    input  logic start,
    output logic done,
    
    // Interfaz de carga de imagen (desde PC/JTAG)
    input  logic        wr_en,
    input  logic [17:0] wr_addr,    // Dirección lineal para escritura
    input  logic [7:0]  wr_data,
    
    // Salida de imagen reducida
    output logic [7:0]  image_out[0:DST_H-1][0:DST_W-1]
);

    // ===============================================
    // Parámetros locales
    // ===============================================
    localparam int ADDR_BITS = $clog2(SRC_W * SRC_H);
    localparam int MEM_SIZE  = SRC_W * SRC_H;

    // ===============================================
    // Señales de memoria SIMD
    // ===============================================
    logic                  mem_rd_req   [N];
    logic [ADDR_BITS-1:0]  mem_rd_addr  [N];
    logic                  mem_rd_valid [N];
    logic [7:0]            mem_rd_data  [N];

    // ===============================================
    // Instancia: Memoria con puertos SIMD
    // ===============================================
    ImageMemory_SIMDPort #(
        .WIDTH      (SRC_W),
        .HEIGHT     (SRC_H),
        .N          (N)
    ) u_image_memory (
        .clk        (clk),
        .rst        (rst),
        
        // Puerto de escritura (carga desde PC)
        .wr_en      (wr_en),
        .wr_addr    (wr_addr[ADDR_BITS-1:0]),
        .wr_data    (wr_data),
        
        // Puertos de lectura SIMD
        .rd_req     (mem_rd_req),
        .rd_addr    (mem_rd_addr),
        .rd_valid   (mem_rd_valid),
        .rd_data    (mem_rd_data)
    );

    // ===============================================
    // Instancia: Downscale_SIMD con interfaz de memoria
    // ===============================================
    Downscale_SIMD #(
        .SRC_H      (SRC_H),
        .SRC_W      (SRC_W),
        .DST_H      (DST_H),
        .DST_W      (DST_W),
        .N          (N)
    ) u_downscale (
        .clk           (clk),
        .rst           (rst),
        .start         (start),
        
        // Interfaz de memoria
        .mem_rd_req    (mem_rd_req),
        .mem_rd_addr   (mem_rd_addr),
        .mem_rd_valid  (mem_rd_valid),
        .mem_rd_data   (mem_rd_data),
        
        // Salida
        .done          (done),
        .image_out     (image_out)
    );

endmodule