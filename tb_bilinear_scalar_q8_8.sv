`timescale 1ns/1ps

module tb_bilinear_scalar_q8_8();
    // =========================
    // Señales del DUT
    // =========================
    logic              clk;
    logic              rst;
    logic              valid_in;
    logic [7:0]        I00, I10, I01, I11;
    logic [7:0]        alpha, beta;
    logic              valid_out;
    logic [7:0]        pixel_out;
    
    // =========================
    // Instancia del DUT
    // =========================
    ModoSecuencial dut (
        .clk(clk),
        .rst(rst),
        .valid_in(valid_in),
        .I00(I00),
        .I10(I10),
        .I01(I01),
        .I11(I11),
        .alpha(alpha),
        .beta(beta),
        .valid_out(valid_out),
        .pixel_out(pixel_out)
    );
    
    // =========================
    // Generación de reloj (100 MHz -> 10ns periodo)
    // =========================
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // =========================
    // Variables para verificación
    // =========================
    int test_num;
    int passed_tests;
    int failed_tests;
    logic [7:0] expected_result;
    
    // =========================
    // Task para aplicar un test
    // =========================
    task automatic apply_test(
        input string test_name,
        input logic [7:0] i00, i10, i01, i11,
        input logic [7:0] a, b,
        input logic [7:0] expected
    );
        test_num++;
        $display("\n[TEST %0d] %s", test_num, test_name);
        $display("  Inputs: I00=%0d, I10=%0d, I01=%0d, I11=%0d", i00, i10, i01, i11);
        $display("  Coeffs: alpha=0x%02h (%.3f), beta=0x%02h (%.3f)", 
                 a, real'(a)/256.0, b, real'(b)/256.0);
        
        // Aplicar entradas
        @(posedge clk);
        valid_in = 1'b1;
        I00 = i00;
        I10 = i10;
        I01 = i01;
        I11 = i11;
        alpha = a;
        beta = b;
        expected_result = expected;
        
        // Esperar 1 ciclo (latencia del módulo)
        @(posedge clk);
        valid_in = 1'b0;
        
        // Esperar valid_out
        @(posedge clk);
        
        // Verificar resultado
        if (valid_out) begin
            int error = (pixel_out > expected) ? (pixel_out - expected) : (expected - pixel_out);
            if (error <= 1) begin  // Tolerancia de ±1 por redondeo
                $display("  ✓ PASS: Output=%0d, Expected=%0d (error=%0d)", 
                         pixel_out, expected, error);
                passed_tests++;
            end else begin
                $display("  ✗ FAIL: Output=%0d, Expected=%0d (error=%0d)", 
                         pixel_out, expected, error);
                failed_tests++;
            end
        end else begin
            $display("  ✗ FAIL: valid_out no se activó");
            failed_tests++;
        end
    endtask
    
    // =========================
    // Función de referencia en SystemVerilog
    // Calcula interpolación bilineal en Q8.8
    // =========================
    function automatic logic [7:0] bilinear_reference(
        input logic [7:0] i00, i10, i01, i11,
        input logic [7:0] a, b
    );
        logic signed [15:0] i00_q, i10_q, i01_q, i11_q;
        logic signed [15:0] alpha_q, beta_q;
        logic signed [31:0] mult_ax, mult_bx, mult_by;
        logic signed [15:0] term_ax, term_bx, term_by;
        logic signed [15:0] a_q, b_q, diff_y, v_q;
        logic signed [16:0] v_rounded;
        logic signed [8:0] pixel_int;
        
        // Conversión a Q8.8
        i00_q = {i00, 8'b0};
        i10_q = {i10, 8'b0};
        i01_q = {i01, 8'b0};
        i11_q = {i11, 8'b0};
        alpha_q = {8'b0, a};
        beta_q = {8'b0, b};
        
        // Interpolación horizontal
        mult_ax = (i10_q - i00_q) * alpha_q;
        term_ax = mult_ax[23:8];
        a_q = i00_q + term_ax;
        
        mult_bx = (i11_q - i01_q) * alpha_q;
        term_bx = mult_bx[23:8];
        b_q = i01_q + term_bx;
        
        // Interpolación vertical
        diff_y = b_q - a_q;
        mult_by = diff_y * beta_q;
        term_by = mult_by[23:8];
        v_q = a_q + term_by;
        
        // Redondeo
        v_rounded = {v_q[15], v_q} + 17'sd128;
        pixel_int = v_rounded[16:8];
        
        // Saturación
        if (pixel_int[8])
            return 8'd0;
        else if (pixel_int > 9'd255)
            return 8'd255;
        else
            return pixel_int[7:0];
    endfunction
    
    // =========================
    // Secuencia de pruebas
    // =========================
    initial begin
        $display("======================================");
        $display("  Testbench: bilinear_scalar_q8_8");
        $display("======================================");
        
        test_num = 0;
        passed_tests = 0;
        failed_tests = 0;
        
        // Reset inicial
        rst = 1;
        valid_in = 0;
        I00 = 0; I10 = 0; I01 = 0; I11 = 0;
        alpha = 0; beta = 0;
        
        repeat(3) @(posedge clk);
        rst = 0;
        @(posedge clk);
        
        // =========================
        // TESTS BÁSICOS
        // =========================
        
        // Test 1: Centro del cuadrado (0.5, 0.5) - Promedio perfecto
        apply_test(
            "Centro (0.5, 0.5) - Cuadrado uniforme",
            100, 100, 100, 100,  // Todos iguales
            128, 128,            // alpha=0.5, beta=0.5
            100                  // Esperado: 100
        );
        
        // Test 2: Centro (0.5, 0.5) - Gradiente horizontal
        apply_test(
            "Centro (0.5, 0.5) - Gradiente horizontal",
            0, 255, 0, 255,      // Izquierda negro, derecha blanco
            128, 128,            // alpha=0.5, beta=0.5
            128                  // Esperado: ~128 (promedio)
        );
        
        // Test 3: Esquina superior izquierda (0, 0)
        apply_test(
            "Esquina (0.0, 0.0) - Debe retornar I00",
            50, 100, 150, 200,
            0, 0,                // alpha=0, beta=0
            50                   // Esperado: I00
        );
        
        // Test 4: Esquina superior derecha (1, 0)
        apply_test(
            "Esquina (1.0, 0.0) - Debe retornar I10",
            50, 100, 150, 200,
            255, 0,              // alpha≈1, beta=0
            100                  // Esperado: I10
        );
        
        // Test 5: Esquina inferior izquierda (0, 1)
        apply_test(
            "Esquina (0.0, 1.0) - Debe retornar I01",
            50, 100, 150, 200,
            0, 255,              // alpha=0, beta≈1
            150                  // Esperado: I01
        );
        
        // Test 6: Esquina inferior derecha (1, 1)
        apply_test(
            "Esquina (1.0, 1.0) - Debe retornar I11",
            50, 100, 150, 200,
            255, 255,            // alpha≈1, beta≈1
            200                  // Esperado: I11
        );
        
        // =========================
        // TESTS DE CASOS EXTREMOS
        // =========================
        
        // Test 7: Todos píxeles en negro
        apply_test(
            "Imagen completamente negra",
            0, 0, 0, 0,
            128, 128,
            0
        );
        
        // Test 8: Todos píxeles en blanco
        apply_test(
            "Imagen completamente blanca",
            255, 255, 255, 255,
            128, 128,
            255
        );
        
        // Test 9: Máximo contraste
        apply_test(
            "Máximo contraste (tablero)",
            0, 255, 255, 0,
            128, 128,
            128                  // Esperado: promedio
        );
        
        // Test 10: Cuarto de posición (0.25, 0.25)
        apply_test(
            "Posición (0.25, 0.25)",
            0, 100, 100, 200,
            64, 64,              // alpha=0.25, beta=0.25
            bilinear_reference(0, 100, 100, 200, 64, 64)
        );
        
        // Test 11: Tres cuartos (0.75, 0.75)
        apply_test(
            "Posición (0.75, 0.75)",
            0, 100, 100, 200,
            192, 192,            // alpha=0.75, beta=0.75
            bilinear_reference(0, 100, 100, 200, 192, 192)
        );
        
        // =========================
        // TESTS CON VALORES REALES
        // =========================
        
        // Test 12: Caso realista 1
        apply_test(
            "Caso realista - Cielo azul",
            120, 125, 118, 123,
            77, 102,             // alpha≈0.3, beta≈0.4
            bilinear_reference(120, 125, 118, 123, 77, 102)
        );
        
        // Test 13: Caso realista 2
        apply_test(
            "Caso realista - Transición sombra",
            45, 67, 89, 111,
            140, 180,            // alpha≈0.55, beta≈0.7
            bilinear_reference(45, 67, 89, 111, 140, 180)
        );
        
        // =========================
        // TEST DE MÚLTIPLES CICLOS
        // =========================
        $display("\n[TEST SECUENCIAL] Procesando 3 píxeles consecutivos...");
        
        @(posedge clk);
        valid_in = 1'b1;
        I00 = 100; I10 = 110; I01 = 120; I11 = 130;
        alpha = 128; beta = 128;
        
        @(posedge clk);
        I00 = 50; I10 = 60; I01 = 70; I11 = 80;
        alpha = 64; beta = 192;
        
        @(posedge clk);
        I00 = 200; I10 = 210; I01 = 220; I11 = 230;
        alpha = 192; beta = 64;
        valid_in = 1'b0;
        
        repeat(5) @(posedge clk);
        $display("  ✓ Secuencia completada (verificación manual en waveform)");
        
        // =========================
        // RESUMEN FINAL
        // =========================
        repeat(2) @(posedge clk);
        
        $display("\n======================================");
        $display("  RESUMEN DE PRUEBAS");
        $display("======================================");
        $display("  Tests ejecutados: %0d", test_num);
        $display("  Tests exitosos:   %0d", passed_tests);
        $display("  Tests fallidos:   %0d", failed_tests);
        
        if (failed_tests == 0) begin
            $display("\n  ✓✓✓ TODOS LOS TESTS PASARON ✓✓✓");
        end else begin
            $display("\n  ✗✗✗ ALGUNOS TESTS FALLARON ✗✗✗");
        end
        $display("======================================\n");
        
        $finish;
    end
    
    // =========================
    // Timeout de seguridad
    // =========================
    initial begin
        #10000;  // 10 microsegundos
        $display("\n✗ ERROR: Timeout - El testbench no terminó a tiempo");
        $finish;
    end
    
    // =========================
    // Dump de waveforms (para GTKWave o ModelSim)
    // =========================
    initial begin
        $dumpfile("tb_bilinear_scalar.vcd");
        $dumpvars(0, tb_bilinear_scalar_q8_8);
    end

endmodule