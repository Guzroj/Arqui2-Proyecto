// ================================================================
// Top_Downscale_Secuencial.sv
// Integración de:
//  - ImageMemory (memoria lineal simple)
//  - Downscale_Secuencial (interpolación secuencial)
//  - Carga por JTAG/Avalon
// ================================================================

`timescale 1ns/1ps

module Top_Downscale_Secuencial #(
    parameter int SRCW = 32,
    parameter int SRCH = 32,
    parameter int DSTW = 16,
    parameter int DSTH = 16
)(
    input  logic        clk,
    input  logic        rst,

    // Interfaz desde JTAG / CPU para cargar imagen fuente
    input  logic        cfgwe,
    input  logic [15:0] cfgaddr,
    input  logic [7:0]  cfgdata,

    // Control
    input  logic        startreq,
    output logic        done,

    // Debug
    output logic [7:0]  dbgdata
);

    // Cantidad total de píxeles
    localparam int DEPTH = SRCW * SRCH;

    // ------------------------------------------------------------
    // Señales a la memoria (si luego se usa realmente)
    // ------------------------------------------------------------
    logic        bramwe;
    logic [15:0] bramaddr;
    logic [7:0]  bramwrdata;
    logic [7:0]  bramrddata;

    // ============================================================
    // MEMORIA LINEAL (Aún no utilizada por Downscale_Secuencial,
    // pero se deja para lecturas futuras)
    // ============================================================
    ImageMemory #(
        .WIDTH  (SRCW),
        .HEIGHT (SRCH)
    ) mem (
        .clk    (clk),
        .we     (bramwe),
        .addr   (bramaddr),
        .wrdata (bramwrdata),
        .rddata (bramrddata)
    );

    // ============================================================
    // Buffers internos 2D para el interpolador secuencial
    // ============================================================
    logic [7:0] imagein  [0:SRCH-1][0:SRCW-1];
    logic [7:0] imageout [0:DSTH-1][0:DSTW-1];

    // ============================================================
    // INSTANCIA DEL DOWNSCALE SECUENCIAL
    // ============================================================
    Downscale_Secuencial #(
        .SRC_H (SRCH),
        .SRC_W (SRCW),
        .DST_H (DSTH),
        .DST_W (DSTW)
    ) useq (
        .clk       (clk),
        .rst       (rst),
        .start     (startreq),
        .image_in  (imagein),
        .done      (done),
        .image_out (imageout)
    );

    // ============================================================
    // Lógica de escritura de memoria externa (si se usa)
    // ============================================================
    always_ff @(posedge clk) begin
        bramwe     <= cfgwe;
        bramaddr   <= cfgaddr;
        bramwrdata <= cfgdata;
    end

    // ============================================================
    // Carga sintetizable de la imagen 2D
    // ============================================================
    always_ff @(posedge clk) begin
        if (cfgwe) begin
            if (cfgaddr < SRCW * SRCH) begin
                // El mapeo HxW a memoria lineal está permitido y sintetiza
                imagein[cfgaddr / SRCW][cfgaddr % SRCW] <= cfgdata;
            end
        end
    end

    // ============================================================
    // Señal de debug: pixel (0,0)
    // ============================================================
    assign dbgdata = imagein[0][0];

endmodule
