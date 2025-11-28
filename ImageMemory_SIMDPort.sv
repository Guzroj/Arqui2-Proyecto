`timescale 1ns/1ps

module ImageMemory_SIMDPort #(
    parameter int WIDTH  = 32,
    parameter int HEIGHT = 32,
    parameter int N      = 4          // Número de puertos de lectura SIMD
)(
    input  logic clk,
    input  logic rst,

    // Puerto de escritura (para carga desde PC/JTAG)
    input  logic                           wr_en,
    input  logic [$clog2(WIDTH*HEIGHT)-1:0] wr_addr,
    input  logic [7:0]                     wr_data,

    // N puertos de lectura SIMD (request/valid handshake)
    input  logic                           rd_req   [N],
    input  logic [$clog2(WIDTH*HEIGHT)-1:0] rd_addr  [N],
    output logic                           rd_valid [N],
    output logic [7:0]                     rd_data  [N]
);

    // ===============================================
    // Memoria interna
    // ===============================================
    localparam int MEM_SIZE = WIDTH * HEIGHT;
    logic [7:0] memory [0:MEM_SIZE-1];

    // ===============================================
    // Puerto de escritura
    // ===============================================
    always_ff @(posedge clk) begin
        if (wr_en && wr_addr < MEM_SIZE) begin
            memory[wr_addr] <= wr_data;
        end
    end

    // ===============================================
    // N puertos de lectura SIMD
    // ===============================================
    genvar i;
    generate
        for (i = 0; i < N; i++) begin : gen_read_ports
            always_ff @(posedge clk or posedge rst) begin
                if (rst) begin
                    rd_valid[i] <= 1'b0;
                    rd_data[i]  <= 8'd0;
                end else begin
                    // Handshake: válido en el ciclo siguiente al request
                    rd_valid[i] <= rd_req[i];
                    
                    if (rd_req[i]) begin
                        // Leer dato (con protección de bounds)
                        if (rd_addr[i] < MEM_SIZE)
                            rd_data[i] <= memory[rd_addr[i]];
                        else
                            rd_data[i] <= 8'd0;  // Default si fuera de rango
                    end
                end
            end
        end
    endgenerate


endmodule