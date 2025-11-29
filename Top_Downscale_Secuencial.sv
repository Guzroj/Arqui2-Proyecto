// ======================================================
// Top_Downscale_Secuencial.sv
//  · Incluye: memoria + downscale secuencial + control
// ======================================================

module Top_Downscale_Secuencial #(
    parameter int SRC_W = 32,
    parameter int SRC_H = 32,
    parameter int DST_W = 16,
    parameter int DST_H = 16
)(
    input  logic clk,
    input  logic rst,

    // ======== interfaz tipo JTAG (simulada) ========
    input  logic        cfg_we,      // escribir en BRAM
    input  logic [31:0] cfg_addr,    // Aumentado a 32 bits
    input  logic [7:0]  cfg_data,

    input  logic        start_req,   // iniciar procesamiento

    output logic        done,
    output logic [7:0]  dbg_data
);

    localparam int DEPTH = SRC_W * SRC_H;
    localparam int ADDR_BITS = $clog2(DEPTH);

    // ==================================================
    // Memoria BRAM
    // ==================================================
    logic bram_we;
    logic [7:0] bram_wr_data;
    logic [ADDR_BITS-1:0] bram_addr;
    logic [7:0] bram_rd_data;

    ImageMemory #(
        .IMG_W(SRC_W),
        .IMG_H(SRC_H)
    ) mem (
        .clk(clk),
        .we(bram_we),
        .addr(bram_addr),
        .wr_data(bram_wr_data),
        .rd_data(bram_rd_data)
    );

    // ==================================================
    // FSM secuencial
    // ==================================================
    logic [7:0] image_in  [0:SRC_H-1][0:SRC_W-1];
    logic [7:0] image_out [0:DST_H-1][0:DST_W-1];

    Downscale_Secuencial #(
        .SRC_W(SRC_W), .SRC_H(SRC_H),
        .DST_W(DST_W), .DST_H(DST_H)
    ) u_seq (
        .clk(clk),
        .rst(rst),
        .start(start_req),
        .image_in(image_in),
        .image_out(image_out),
        .done(done)
    );

    // ==================================================
    // Cargar BRAM desde cfg_we
    // ==================================================
    always_ff @(posedge clk) begin
        bram_we      <= cfg_we;
        bram_addr    <= cfg_addr[ADDR_BITS-1:0];
        bram_wr_data <= cfg_data;
    end

    // Debug: usar primer pixel de salida
    assign dbg_data = image_out[0][0];

endmodule
