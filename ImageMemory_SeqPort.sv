`timescale 1ns/1ps

module ImageMemory_SeqPort #(
    parameter int WIDTH  = 512,
    parameter int HEIGHT = 512
)(
    input  logic clk,
    input  logic rst,
    
    // Puerto de escritura (para carga desde PC/JTAG)
    input  logic                            wr_en,
    input  logic [$clog2(WIDTH*HEIGHT)-1:0] wr_addr,
    input  logic [7:0]                      wr_data,
    
    // Puerto de lectura (request/valid handshake)
    input  logic                            rd_req,
    input  logic [$clog2(WIDTH*HEIGHT)-1:0] rd_addr,
    output logic                            rd_valid,
    output logic [7:0]                      rd_data
);

    localparam int MEM_SIZE = WIDTH * HEIGHT;
    
    // Memoria interna
    logic [7:0] memory [0:MEM_SIZE-1];
    
    // Puerto de escritura
    always_ff @(posedge clk) begin
        if (wr_en && wr_addr < MEM_SIZE) begin
            memory[wr_addr] <= wr_data;
        end
    end
    
    // Puerto de lectura con handshake
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            rd_valid <= 1'b0;
            rd_data  <= 8'd0;
        end else begin
            // Handshake: válido en el ciclo siguiente al request
            rd_valid <= rd_req;
            
            if (rd_req) begin
                if (rd_addr < MEM_SIZE)
                    rd_data <= memory[rd_addr];
                else
                    rd_data <= 8'd0;
            end
        end
    end

endmodule