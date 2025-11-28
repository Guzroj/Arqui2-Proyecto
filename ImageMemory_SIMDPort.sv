// ==============================================================
// ImageMemory_SIMDPort.sv
// Memoria para lectura SIMD (N lanes)
// Escritura sincrónica, lectura combinacional por lane
// ==============================================================

module ImageMemory_SIMDPort #(
    parameter int WIDTH  = 32,
    parameter int HEIGHT = 32,
    parameter int N      = 4
)(
    input  logic                          clk,
    input  logic                          rst,

    // Escritura lineal desde JTAG / CPU
    input  logic                          wr_en,
    input  logic [$clog2(WIDTH*HEIGHT)-1:0] wr_addr,
    input  logic [7:0]                    wr_data,

    // Lectura SIMD (N lanes)
    input  logic        rd_req   [N],
    input  logic [$clog2(WIDTH*HEIGHT)-1:0] rd_addr  [N],
    output logic        rd_valid [N],
    output logic [7:0]  rd_data  [N]
);

    // Tamaño total de memoria
    localparam int DEPTH = WIDTH * HEIGHT;

    // Memoria interna lineal
    logic [7:0] mem [0:DEPTH-1];

    // --------------------------------------------------------------
    // Escritura sincrónica
    // --------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (wr_en)
            mem[wr_addr] <= wr_data;
    end

    // --------------------------------------------------------------
    // Lectura combinacional por lane
    // --------------------------------------------------------------
    always_comb begin
        for (int i = 0; i < N; i++) begin
            rd_data[i]  = mem[ rd_addr[i] ];   // lectura directa
            rd_valid[i] = rd_req[i];           // valido = request
        end
    end

endmodule
