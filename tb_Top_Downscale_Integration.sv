`timescale 1ns/1ps

module tb_Top_Downscale_Integration;

    // ------------------------------------------------------------
    // Parámetros (ajustables según tu diseño)
    // ------------------------------------------------------------
    localparam int SRCW = 32;
    localparam int SRCH = 32;
    localparam int DSTW = 16;
    localparam int DSTH = 16;
    localparam int N    = 4;

    localparam int SRC_DEPTH = SRCW * SRCH;
    localparam int ADDRBITS  = $clog2(SRC_DEPTH);

    // ------------------------------------------------------------
    // Señales del DUT
    // ------------------------------------------------------------
    logic clk;
    logic rst;
    logic start;
    logic done;

    logic        wren;
    logic [16:0] wraddr;
    logic [7:0]  wrdata;

    // Imagen de salida del DUT
    logic [7:0] image_out [0:DSTH-1][0:DSTW-1];

    logic [7:0] dbg;

    // ------------------------------------------------------------
    // Instancia del DUT (correcta)
    // ------------------------------------------------------------
    Top_Downscale_Integration #(
        .SRCH(SRCH),
        .SRCW(SRCW),
        .DSTH(DSTH),
        .DSTW(DSTW),
        .N(N)
    ) dut (
        .clk      (clk),
        .rst      (rst),
        .start    (start),
        .done     (done),
        .wren     (wren),
        .wraddr   (wraddr),
        .wrdata   (wrdata),
        .imageout (image_out),     // <-- CORRECTO
        .dbgdata  (dbg)
    );

    // ------------------------------------------------------------
    // Generador de reloj
    // ------------------------------------------------------------
    always #5 clk = ~clk;   // 100 MHz

    // ------------------------------------------------------------
    // Inicialización
    // ------------------------------------------------------------
    initial begin
        clk   = 0;
        rst   = 1;
        start = 0;
        wren  = 0;
        wraddr = 0;
        wrdata = 0;

        #50;
        rst = 0;
        #20;

        // ------------------------------------------------------------
        // Cargar imagen de prueba en memoria
        // Ejemplo: gradiente simple 0..255
        // ------------------------------------------------------------
        $display("Cargando imagen fuente de %0d pixeles...", SRC_DEPTH);

        for (int addr = 0; addr < SRC_DEPTH; addr++) begin
            wren   = 1;
            wraddr = addr;
            wrdata = addr % 256;
            #10;
        end

        wren = 0;
        #30;

        // ------------------------------------------------------------
        // Pulso de start
        // ------------------------------------------------------------
        $display("Iniciando downscale SIMD...");
        start = 1;
        #20;
        start = 0;

        // ------------------------------------------------------------
        // Esperar done
        // ------------------------------------------------------------
        wait (done == 1);
        #50;

        $display("Downscale terminado!");

        // ------------------------------------------------------------
        // Mostrar la imagen reducida
        // ------------------------------------------------------------
        $display("Imagen downscale %0dx%0d:", DSTW, DSTH);

        for (int r = 0; r < DSTH; r++) begin
            for (int c = 0; c < DSTW; c++) begin
                $write("%3d ", image_out[r][c]);
            end
            $write("\n");
        end

        $display("Simulación terminada.");
        #50;
        $finish;
    end

endmodule
