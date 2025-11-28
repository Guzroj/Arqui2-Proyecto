`timescale 1ns/1ps

module Top_Downscale_Integration #(
    parameter int SRCH = 32,
    parameter int SRCW = 32,
    parameter int DSTH = 16,
    parameter int DSTW = 16,
    parameter int N    = 4           // SIMD width
)(
    input  logic        clk,
    input  logic        rst,

    // Control principal
    input  logic        start,
    output logic        done,

    // Interfaz de carga de imagen desde PC/JTAG
    input  logic        wren,
    input  logic [16:0] wraddr,      // dirección lineal (hasta 131072)
    input  logic [7:0]  wrdata,

    // Salida de imagen reducida
    output logic [7:0]  imageout [0:DSTH-1][0:DSTW-1],

    // Debug
    output logic [7:0]  dbgdata
);

    // Parámetros locales
    localparam int SRCDEPTH = SRCW * SRCH;
    localparam int ADDRBITS = $clog2(SRCDEPTH);

    // Señales de memoria SIMD
    logic                 memrdreq   [N];
    logic [ADDRBITS-1:0]  memrdaddr  [N];
    logic                 memrdvalid [N];
    logic [7:0]           memrddata  [N];

    // ============================================================
    // Memoria con puertos SIMD
    // ============================================================
    ImageMemory_SIMDPort #(
        .WIDTH  (SRCW),
        .HEIGHT (SRCH),
        .N      (N)
    ) uimagememory (
        .clk     (clk),
        .rst     (rst),

        // Escritura desde PC/JTAG
        .wr_en   (wren),
        .wr_addr (wraddr[ADDRBITS-1:0]),
        .wr_data (wrdata),

        // Lectura SIMD
        .rd_req   (memrdreq),
        .rd_addr  (memrdaddr),
        .rd_valid (memrdvalid),
        .rd_data  (memrddata)
    );

    // ============================================================
    // Downscale SIMD
    // ============================================================
    Downscale_SIMD #(
        .SRC_H (SRCH),
        .SRC_W (SRCW),
        .DST_H (DSTH),
        .DST_W (DSTW),
        .N     (N)
    ) udownscale (
        .clk         (clk),
        .rst         (rst),
        .start       (start),

        .mem_rd_req   (memrdreq),
        .mem_rd_addr  (memrdaddr),
        .mem_rd_valid (memrdvalid),
        .mem_rd_data  (memrddata),

        .done        (done),
        .image_out   (imageout)
    );

    // ============================================================
    // Debug: dato leído por el lane 0
    // ============================================================
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            dbgdata <= 8'd0;
        end else begin
            if (memrdvalid[0])
                dbgdata <= memrddata[0];
        end
    end

endmodule
