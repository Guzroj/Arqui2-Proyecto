`timescale 1ns/1ps

module tb_downscale_ModoSIMD;

    // Parámetros
    localparam int SRC_H = 4;
    localparam int SRC_W = 4;
    localparam int DST_H = 3;
    localparam int DST_W = 3;
    localparam int N = 4; // 4 píxeles por batch SIMD

    // Imagen fuente
    logic [7:0] image [0:SRC_H-1][0:SRC_W-1];

    // Señales del DUT SIMD
    logic clk, rst, valid_in, valid_out;

    logic [7:0] I00_vec  [N];
    logic [7:0] I10_vec  [N];
    logic [7:0] I01_vec  [N];
    logic [7:0] I11_vec  [N];
    logic [7:0] alpha_vec[N];
    logic [7:0] beta_vec [N];

    logic [7:0] pixel_out_vec[N];

    int pass_count = 0;
    int fail_count = 0;

    // Instancia SIMD
    ModoSIMD #(N) dut (
        .clk(clk),
        .rst(rst),
        .valid_in(valid_in),
        .I00_vec(I00_vec),
        .I10_vec(I10_vec),
        .I01_vec(I01_vec),
        .I11_vec(I11_vec),
        .alpha_vec(alpha_vec),
        .beta_vec(beta_vec),
        .valid_out(valid_out),
        .pixel_out_vec(pixel_out_vec)
    );

    // Clock
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Referencia flotante (igual que tu secuencial)
    function automatic int bilinear_ref_pixel(
        input int a, b, c, d,
        input real xw, yw
    );
        real w00 = (1-xw)*(1-yw);
        real w10 = (xw)*(1-yw);
        real w01 = (1-xw)*(yw);
        real w11 = (xw)*(yw);
        real pix_r = a*w00 + b*w10 + c*w01 + d*w11;
        int pix_i = $rtoi(pix_r + 0.5);
        if (pix_i < 0) pix_i = 0;
        else if (pix_i > 255) pix_i = 255;
        return pix_i;
    endfunction

    // Task: procesa un batch SIMD de hasta 4 píxeles
    task automatic run_batch(
        input int batch_id,
        input real x_ratio, 
        input real y_ratio
    );
        int k;
        int idx;
        int i_dst, j_dst;

        real x_src, y_src;
        int x_l, x_h, y_l, y_h;
        real x_w, y_w;
        int a,b,c,d;
        int expected[4];
        int diff;

        // Calcular 4 píxeles del batch
        for (k = 0; k < N; k++) begin
            idx = batch_id*N + k;
            if (idx >= DST_H*DST_W) begin
                I00_vec[k] = 0;
                I10_vec[k] = 0;
                I01_vec[k] = 0;
                I11_vec[k] = 0;
                alpha_vec[k] = 0;
                beta_vec[k] = 0;
                expected[k] = -1;
                continue;
            end

            // Coordenadas destino
            i_dst = idx / DST_W;
            j_dst = idx % DST_W;

            x_src = x_ratio * j_dst;
            y_src = y_ratio * i_dst;

            x_l = int'($floor(x_src));
            x_h = int'($ceil (x_src));
            y_l = int'($floor(y_src));
            y_h = int'($ceil (y_src));

            if (x_l < 0) x_l = 0;
            if (y_l < 0) y_l = 0;
            if (x_h > SRC_W-1) x_h = SRC_W-1;
            if (y_h > SRC_H-1) y_h = SRC_H-1;

            x_w = x_src - x_l;
            y_w = y_src - y_l;

            a = image[y_l][x_l];
            b = image[y_l][x_h];
            c = image[y_h][x_l];
            d = image[y_h][x_h];

            expected[k] = bilinear_ref_pixel(a,b,c,d,x_w,y_w);

            I00_vec[k] = a;
            I10_vec[k] = b;
            I01_vec[k] = c;
            I11_vec[k] = d;

            alpha_vec[k] = int'(x_w*256.0 + 0.5);
            beta_vec[k]  = int'(y_w*256.0 + 0.5);
        end

        @(posedge clk);
        valid_in <= 1;

        @(posedge clk);
        valid_in <= 0;

        wait(valid_out == 1);

        // Comparar 4 píxeles
        for (k = 0; k < N; k++) begin
            if (expected[k] < 0) continue;

            diff = pixel_out_vec[k] - expected[k];
            if (diff < 0) diff = -diff;

            if (diff <= 1)
                pass_count++;
            else begin
                fail_count++;
                $display("FAIL SIMD: idx=%0d  HW=%0d REF=%0d", batch_id*N+k, pixel_out_vec[k], expected[k]);
            end
        end

    endtask

    // Main
    initial begin
        int total_pixels = DST_H*DST_W;
        int total_batches = (total_pixels + N - 1) / N;
        int b;
        real x_ratio = real'(SRC_W - 1) / real'(DST_W - 1);
        real y_ratio = real'(SRC_H - 1) / real'(DST_H - 1);

        // Imagen fuente
        image[0] = '{10,30,50,70};
        image[1] = '{90,110,130,150};
        image[2] = '{170,190,210,230};
        image[3] = '{240,245,250,255};

        rst = 1;
        valid_in = 0;

        repeat(4) @(posedge clk);
        rst = 0;

        for (b = 0; b < total_batches; b++) begin
            run_batch(b, x_ratio, y_ratio);
        end

        $display("\n--- FIN SIMD ---");
        $display("PASS=%0d, FAIL=%0d", pass_count, fail_count);

        if (fail_count == 0)
            $display("SIMD CORRECTO");
        else
            $display("ERRORES EN SIMD");

        $finish;
    end

    // Dump
    initial begin
        $dumpfile("tb_downscale_ModoSIMD.vcd");
        $dumpvars(0, tb_downscale_ModoSIMD);
    end

endmodule
