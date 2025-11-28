`timescale 1ns/1ps

module tb_Top_Downscale_SIMD;

    localparam int SRC_W = 32;
    localparam int SRC_H = 32;
    localparam int DST_W = 16;
    localparam int DST_H = 16;

    logic clk, rst;

    // BRAM load interface
    logic        cfg_we;
    logic [15:0] cfg_addr;
    logic [7:0]  cfg_data;

    // Control
    logic start_req;
    logic done;
    logic [7:0] dbg_data;

    // ================================
    // Variables (Quartus-friendly)
    // ================================
    integer i, j;
    integer pass, fail;

    integer img_in     [0:SRC_H-1][0:SRC_W-1];
    integer expected   [0:DST_H-1][0:DST_W-1];

    // Para cálculo bilineal
    real xr, yr;
    real xs, ys;
    real xw, yw;
    integer xl, yl, xh, yh;
    integer a, b, c, d;

    integer hw;

    // ================================
    // DUT
    // ================================
    Top_Downscale_SIMD #(
        .SRC_W(SRC_W),
        .SRC_H(SRC_H),
        .DST_W(DST_W),
        .DST_H(DST_H),
        .N(4)
    ) dut (
        .clk(clk),
        .rst(rst),
        .cfg_we(cfg_we),
        .cfg_addr(cfg_addr),
        .cfg_data(cfg_data),
        .start_req(start_req),
        .done(done),
        .dbg_data(dbg_data)
    );

    // Clock
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // ================================
    // Función bilinear
    // ================================
    function integer bilinear_ref(
        input integer a,b,c,d,
        input real xw, yw
    );
        real w00,w10,w01,w11;
        real r;
        integer pix;

        w00 = (1-xw)*(1-yw);
        w10 = xw*(1-yw);
        w01 = (1-xw)*yw;
        w11 = xw*yw;

        r = a*w00 + b*w10 + c*w01 + d*w11;

        pix = $rtoi(r + 0.5);
        if (pix < 0)   pix = 0;
        if (pix > 255) pix = 255;

        return pix;
    endfunction

    // ================================
    // MAIN TB
    // ================================
    initial begin
        
        xr = real'(SRC_W-1) / real'(DST_W-1);
        yr = real'(SRC_H-1) / real'(DST_H-1);

        rst      = 1;
        cfg_we   = 0;
        start_req = 0;

        repeat(5) @(posedge clk);
        rst = 0;

        // 1) Generar imagen 32×32
        for (i=0; i<SRC_H; i++)
        for (j=0; j<SRC_W; j++)
            img_in[i][j] = (i*4 + j*2) & 255;

        // 2) Cargar BRAM simulando JTAG
        $display("Cargando BRAM...");
        for (i=0; i<SRC_H; i++)
        for (j=0; j<SRC_W; j++) begin
            @(posedge clk);
            cfg_we   = 1;
            cfg_addr = i*SRC_W + j;
            cfg_data = img_in[i][j];
        end
        @(posedge clk);
        cfg_we = 0;

        // 3) Generar referencia software
        for (i=0; i<DST_H; i++)
        for (j=0; j<DST_W; j++) begin
            
            xs = xr * j;
            ys = yr * i;

            xl = $floor(xs);
            yl = $floor(ys);
            xh = (xl < SRC_W-1) ? xl + 1 : xl;
            yh = (yl < SRC_H-1) ? yl + 1 : yl;

            xw = xs - xl;
            yw = ys - yl;

            a = img_in[yl][xl];
            b = img_in[yl][xh];
            c = img_in[yh][xl];
            d = img_in[yh][xh];

            expected[i][j] = bilinear_ref(a,b,c,d,xw,yw);
        end

        // 4) Iniciar procesamiento
        @(posedge clk);
        start_req = 1;
        @(posedge clk);
        start_req = 0;

        // 5) Esperar resultado
        wait(done);
        $display("Procesamiento completado.");

        // 6) Comparar resultados
        pass = 0;
        fail = 0;

        for (i=0;i<DST_H;i++)
        for (j=0;j<DST_W;j++) begin

            hw = dut.image_out[i][j];   // << RUTA CORRECTA

            if ((hw - expected[i][j] <= 1) &&
                (expected[i][j] - hw <= 1))
                pass++;
            else begin
                fail++;
                $display("FAIL (%0d,%0d): HW=%0d  REF=%0d",
                          i,j, hw, expected[i][j]);
            end
        end

        $display("PASS=%0d  FAIL=%0d", pass, fail);
        $finish;
    end

endmodule
