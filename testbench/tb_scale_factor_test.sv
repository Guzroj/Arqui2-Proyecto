`timescale 1ns/1ps

// ============================================================================
// Testbench para probar diferentes factores de escala
// ============================================================================

module tb_scale_factor_test;

    localparam int SRC_W = 512;
    localparam int SRC_H = 512;
    localparam int CLK_PERIOD = 10;

    logic clk, rst;
    logic        cfg_we;
    logic [17:0] cfg_addr;
    logic [7:0]  cfg_data;
    logic [3:0]  scale_factor;
    logic        start_req;
    logic        done;
    logic [7:0]  dbg_data;

    // Performance counters
    logic [31:0] perf_flops;
    logic [31:0] perf_mem_reads;
    logic [31:0] perf_mem_writes;

    // DUT
    Top_Downscale_Secuencial #(
        .SRC_W(SRC_W),
        .SRC_H(SRC_H),
        .DST_W(256),
        .DST_H(256)
    ) dut (
        .clk(clk),
        .rst(rst),
        .cfg_we(cfg_we),
        .cfg_addr(cfg_addr),
        .cfg_data(cfg_data),
        .scale_factor(scale_factor),
        .start_req(start_req),
        .done(done),
        .dbg_data(dbg_data),
        .perf_flops(perf_flops),
        .perf_mem_reads(perf_mem_reads),
        .perf_mem_writes(perf_mem_writes)
    );

    // Clock
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Variables
    reg [7:0] test_image [0:SRC_H-1][0:SRC_W-1];
    integer file, code, i, j, sf;
    integer expected_pixels;
    real scale_real, arithmetic_intensity;
    integer total_mem_accesses;

    // Cargar imagen
    task load_test_image;
        begin
            $display("[%0t] Cargando imagen 512x512...", $time);
            file = $fopen("C:/Users/gabri/OneDrive/Desktop/PrograProyectoArqui/Arqui2-Proyecto/imagen_grayscale.txt", "r");

            if (file == 0) begin
                $display("ERROR: No se pudo abrir imagen_grayscale.txt");
                $finish;
            end

            for (i = 0; i < SRC_H; i = i + 1) begin
                for (j = 0; j < SRC_W; j = j + 1) begin
                    code = $fscanf(file, "%d", test_image[i][j]);
                end
            end

            $fclose(file);
            $display("[%0t] ✓ Imagen cargada\n", $time);
        end
    endtask

    // Cargar imagen en BRAM
    task load_to_bram;
        begin
            cfg_we = 0;
            @(posedge clk);

            for (i = 0; i < SRC_H; i = i + 1) begin
                for (j = 0; j < SRC_W; j = j + 1) begin
                    cfg_we = 1;
                    cfg_addr = i * SRC_W + j;
                    cfg_data = test_image[i][j];
                    @(posedge clk);
                end
            end

            cfg_we = 0;
            @(posedge clk);
        end
    endtask

    // Ejecutar downscale
    task run_test(input [3:0] sf_value);
        integer timeout, dst_w, dst_h;
        begin
            scale_factor = sf_value;
            scale_real = 0.50 + sf_value * 0.05;

            case (sf_value)
                4'd0:  begin dst_w = 256; dst_h = 256; end
                4'd1:  begin dst_w = 281; dst_h = 281; end
                4'd2:  begin dst_w = 307; dst_h = 307; end
                4'd3:  begin dst_w = 332; dst_h = 332; end
                4'd4:  begin dst_w = 358; dst_h = 358; end
                4'd5:  begin dst_w = 384; dst_h = 384; end
                4'd6:  begin dst_w = 409; dst_h = 409; end
                4'd7:  begin dst_w = 435; dst_h = 435; end
                4'd8:  begin dst_w = 460; dst_h = 460; end
                4'd9:  begin dst_w = 486; dst_h = 486; end
                4'd10: begin dst_w = 512; dst_h = 512; end
                default: begin dst_w = 256; dst_h = 256; end
            endcase

            expected_pixels = dst_w * dst_h;

            $display("\n========================================");
            $display("TEST: Scale Factor = %0d (%.2f)", sf_value, scale_real);
            $display("Dimensiones esperadas: %0dx%0d", dst_w, dst_h);
            $display("Píxeles esperados: %0d", expected_pixels);
            $display("========================================");

            repeat(5) @(posedge clk);

            start_req = 1;
            @(posedge clk);
            start_req = 0;

            timeout = 0;
            while (!done && timeout < 5000000) begin
                @(posedge clk);
                timeout = timeout + 1;
            end

            if (!done) begin
                $display("✗ TIMEOUT después de %0d ciclos", timeout);
                $finish;
            end

            $display("✓ Completado en %0d ciclos", timeout);
            $display("  FLOPs: %0d", perf_flops);
            $display("  Mem Reads: %0d", perf_mem_reads);
            $display("  Mem Writes: %0d", perf_mem_writes);
            $display("  Píxeles procesados: %0d", perf_mem_writes);

            if (perf_mem_writes == expected_pixels)
                $display("  ✓ Número de píxeles CORRECTO");
            else
                $display("  ✗ ERROR: Esperado %0d, obtenido %0d", expected_pixels, perf_mem_writes);

            total_mem_accesses = perf_mem_reads + perf_mem_writes;
            arithmetic_intensity = real'(perf_flops) / real'(total_mem_accesses);
            $display("  Intensidad aritmética: %.3f", arithmetic_intensity);

            repeat(10) @(posedge clk);
        end
    endtask

    // Secuencia principal
    initial begin
        $display("\n=== TEST DE MÚLTIPLES FACTORES DE ESCALA ===\n");

        rst = 1;
        start_req = 0;
        cfg_we = 0;
        cfg_addr = 0;
        cfg_data = 0;
        scale_factor = 4'd0;

        repeat(10) @(posedge clk);
        rst = 0;
        repeat(5) @(posedge clk);

        load_test_image();
        load_to_bram();

        // Probar factores de escala seleccionados
        run_test(4'd0);   // 0.50 -> 256x256
        run_test(4'd2);   // 0.60 -> 307x307
        run_test(4'd5);   // 0.75 -> 384x384
        run_test(4'd10);  // 1.00 -> 512x512

        $display("\n=== TODOS LOS TESTS COMPLETADOS ===\n");
        $stop;
    end

    // Timeout global
    initial begin
        #(CLK_PERIOD * 50000000);
        $display("\n✗ TIMEOUT GLOBAL");
        $finish;
    end

endmodule
