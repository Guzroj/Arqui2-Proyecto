`timescale 1ns/1ps

module tb_Top_SIMD;

    localparam int SRC_H = 4;
    localparam int SRC_W = 4;
    localparam int DST_H = 3;
    localparam int DST_W = 3;
    localparam int N     = 4;

    logic clk, rst, start;

    // Vectores de entrada al TOP
    logic [7:0] I00_vec [N];
    logic [7:0] I10_vec [N];
    logic [7:0] I01_vec [N];
    logic [7:0] I11_vec [N];
    logic [7:0] alpha_vec[N];
    logic [7:0] beta_vec [N];

    // Salidas
    logic done;
    logic [7:0] pixel_out_vec[N];

    // Imagen
    logic [7:0] image[0:SRC_H-1][0:SRC_W-1];

    int pass_count = 0;
    int fail_count = 0;

    // Instancia del TOP
    Top_SIMD #(.N(N)) dut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .I00_vec(I00_vec),
        .I10_vec(I10_vec),
        .I01_vec(I01_vec),
        .I11_vec(I11_vec),
        .alpha_vec(alpha_vec),
        .beta_vec(beta_vec),
        .done(done),
        .pixel_out_vec(pixel_out_vec)
    );

    // Clock
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Referencia flotante
    function automatic int bilinear_ref_pixel(
        input int a, b, c, d,
        input real xw, yw
    );
        real w00 = (1-xw)*(1-yw);
        real w10 =  xw   *(1-yw);
        real w01 = (1-xw)* yw;
        real w11 =  xw   * yw;
        real r   = a*w00 + b*w10 + c*w01 + d*w11;
        int  pix = $rtoi(r + 0.5);

        if (pix < 0) pix = 0;
        else if (pix > 255) pix = 255;

        return pix;
    endfunction

    // Cargar batch
    task automatic cargar_batch(
        input  int  batch_id,
        input  real xr,
        input  real yr,
        output int  expected[N]
    );
        int k, idx;
        int i_dst, j_dst;
        real xs, ys;
        int xl,xh,yl,yh;
        real xw, yw;
        int a,b,c,d;

        for (k = 0; k < N; k++) begin
            idx = batch_id*N + k;

            if (idx >= DST_H*DST_W) begin
                I00_vec[k]=0; I10_vec[k]=0; I01_vec[k]=0; I11_vec[k]=0;
                alpha_vec[k]=0; beta_vec[k]=0;
                expected[k] = -1;
                continue;
            end

            i_dst = idx / DST_W;
            j_dst = idx % DST_W;

            xs = xr * j_dst;
            ys = yr * i_dst;

            xl = int'($floor(xs));
            yl = int'($floor(ys));
            xh = int'($ceil(xs));
            yh = int'($ceil(ys));

            if (xh>SRC_W-1) xh = SRC_W-1;
            if (yh>SRC_H-1) yh = SRC_H-1;

            xw = xs - xl;
            yw = ys - yl;

            a = image[yl][xl];
            b = image[yl][xh];
            c = image[yh][xl];
            d = image[yh][xh];

            expected[k] = bilinear_ref_pixel(a,b,c,d,xw,yw);

            I00_vec[k] = a;
            I10_vec[k] = b;
            I01_vec[k] = c;
            I11_vec[k] = d;

            alpha_vec[k] = int'(xw*256.0+0.5);
            beta_vec[k]  = int'(yw*256.0+0.5);
        end
    endtask

    // MAIN TEST
    initial begin
        int total_pixels  = DST_H*DST_W;
        int total_batches = (total_pixels + N - 1) / N; // 3
        int b, k;
        int expected[N];
        int diff;

        real xr = real'(SRC_W-1)/real'(DST_W-1);
        real yr = real'(SRC_H-1)/real'(DST_H-1);

        // Imagen
        image[0] = '{10,30,50,70};
        image[1] = '{90,110,130,150};
        image[2] = '{170,190,210,230};
        image[3] = '{240,245,250,255};

        rst = 1;
        start = 0;
        repeat(4) @(posedge clk);
        rst = 0;

        $display("\n======== INICIO TEST INTEGRADO (Top_SIMD) =========");

        // ----------------------------------
        //  EJECUTAR TODOS LOS BATCHES
        // ----------------------------------
        for (b = 0; b < total_batches; b++) begin

            $display("\n=======================================");
            $display("===  BATCH %0d  ===", b);
            $display("=======================================");

            cargar_batch(b, xr, yr, expected);

            // ⚠️ *** IMPORTANTE ***
            // Esperar 1 ciclo antes de start → así la FSM ve los valores correctos
            @(posedge clk);

            // Activar FSM
            start = 1;
            @(posedge clk);
            start = 0;

            // Esperar hasta que el batch termine
            wait(done == 1);

            // Comparar resultados
            for (k = 0; k < N; k++) begin
                if (expected[k] < 0) continue;

                diff = pixel_out_vec[k] - expected[k];
                if (diff < 0) diff = -diff;

                $display("  HW[%0d] = %0d  REF=%0d  diff=%0d",
                         k, pixel_out_vec[k], expected[k], diff);

                if (diff <= 1) begin
                    pass_count++;
                    $display("   ✓ PASS");
                end else begin
                    fail_count++;
                    $display("   ✗ FAIL");
                end
            end
        end

        $display("\n==== FIN INTEGRACIÓN (Top_SIMD) ====");
        $display("PASS=%0d  FAIL=%0d", pass_count, fail_count);

        if (fail_count == 0)
            $display("TODO OK — INTEGRACIÓN COMPLETA FUNCIONA!");
        else
            $display("ERRORES PRESENTES EN LA INTEGRACIÓN");

        $finish;
    end

endmodule
