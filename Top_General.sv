// ================================================================
// Top_General.sv
// TOP GENERAL DEL PROYECTO – Integración JTAG + Secuencial + SIMD
// Basado en GuiaJtag
// ================================================================

module Top_General #(
    parameter IMGW = 512,
    parameter IMGH = 512,
    parameter N    = 4
)(
    input  logic        clk,
    input  logic        rst,

    // Interfaz JTAG / Avalon-MM
    input  logic        avsread,
    input  logic        avswrite,
    input  logic [7:0]  avsaddress,
    input  logic [31:0] avswritedata,
    output logic [31:0] avsreaddata
);

    // ------------------------------------------------------------
    // Señales entre JTAGInterface y lógica de procesamiento
    // ------------------------------------------------------------
    logic        start;
    logic        step;
    logic        modereg;          // 0 Secuencial, 1 SIMD/Integración
    logic [31:0] xratioreg;
    logic [31:0] yratioreg;
    logic [31:0] wraddrreg;
    logic [31:0] wrdatareg;
    logic [31:0] rddatareg;
    logic [31:0] perfcounter;
    logic        doneflag;

    // ------------------------------------------------------------
    // Banco de registros JTAG / Avalon-MM
    // ------------------------------------------------------------
    JTAG_Interface u_jtag (
        .clk          (clk),
        .rst          (rst),
        .start        (start),
        .step         (step),
        .mode         (modereg),
        .paramxratio  (xratioreg),
        .paramyratio  (yratioreg),
        .imgwriteaddr (wraddrreg),
        .imgwritedata (wrdatareg),
        .imgreaddata  (rddatareg),
        .doneflag     (doneflag),
        .perfcounter  (perfcounter),
        .avsread      (avsread),
        .avswrite     (avswrite),
        .avsaddress   (avsaddress),
        .avswritedata (avswritedata),
        .avsreaddata  (avsreaddata)
    );

    // ------------------------------------------------------------
    // Top Secuencial
    // ------------------------------------------------------------
    logic        doneseq;
    logic [7:0]  dbgseq;

    Top_Downscale_Secuencial #(
        .SRCW (IMGW),
        .SRCH (IMGH),
        .DSTW (IMGW/2),
        .DSTH (IMGH/2)
    ) u_top_seq (
        .clk      (clk),
        .rst      (rst),
        .cfgwe    (avswrite & (modereg == 1'b0)),
        .cfgaddr  (wraddrreg[15:0]),
        .cfgdata  (wrdatareg[7:0]),
        .startreq (start & (modereg == 1'b0)),
        .done     (doneseq),
        .dbgdata  (dbgseq)
    );

    // ------------------------------------------------------------
    // Top Integración SIMD
    // ------------------------------------------------------------
    logic        doneint;
    logic [7:0]  dbginteg;

    // Imagen de salida calculada por el modo SIMD
    logic [7:0] imgout_int [0:(IMGH/2)-1][0:(IMGW/2)-1];

    Top_Downscale_Integration #(
        .SRCH (IMGH),
        .SRCW (IMGW),
        .DSTH (IMGH/2),
        .DSTW (IMGW/2),
        .N    (N)
    ) u_top_integ (
        .clk      (clk),
        .rst      (rst),
        .start    (start & (modereg == 1'b1)),
        .done     (doneint),
        .wren     (avswrite & (modereg == 1'b1)),
        .wraddr   (wraddrreg[16:0]),
        .wrdata   (wrdatareg[7:0]),
        .imageout (imgout_int),
        .dbgdata  (dbginteg)
    );

    // ------------------------------------------------------------
    // Multiplexado global de estado y debug hacia JTAGInterface
    // ------------------------------------------------------------
    assign doneflag  = (modereg == 1'b1) ? doneint : doneseq;

    // Se regresa un byte de debug empaquetado
    assign rddatareg = {24'd0, (modereg == 1'b1 ? dbginteg : dbgseq)};

    // ------------------------------------------------------------
    // Performance Counter
    // ------------------------------------------------------------
    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            perfcounter <= 32'd0;
        else
            perfcounter <= perfcounter + 32'd1;
    end

endmodule
