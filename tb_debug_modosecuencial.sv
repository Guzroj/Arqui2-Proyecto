`timescale 1ns/1ps

module tb_debug_modosecuencial();

    // =======================
    // Señales del testbench
    // =======================
    logic              clk;
    logic              rst;
    logic              valid_in;
    logic [7:0]        I00, I10, I01, I11;
    logic [7:0]        alpha, beta;
    logic              valid_out;
    logic [7:0]        pixel_out;

    // Señales para cálculo manual (debug)
    logic signed [15:0] I00_q_tb, I10_q_tb, alpha_q_tb;
    logic signed [31:0] mult_ax_tb;
    logic signed [15:0] term_ax_tb, a_q_tb;
    real                a_q_real_tb;
    
    // Instancia del DUT
    // Asegúrate de que el nombre coincida con tu módulo real
    ModoSecuencial dut (.*);
    // o si es bilinear_scalar_q8_8:
    // bilinear_scalar_q8_8 dut (.*);

    // =======================
    // Reloj
    // =======================
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // =======================
    // Bloque de prueba
    // =======================
    initial begin
        $display("\n=== TEST DE DIAGNÓSTICO ===\n");
        
        // Reset
        rst      = 1;
        valid_in = 0;
        I00 = 0; I10 = 0; I01 = 0; I11 = 0;
        alpha = 0; beta = 0;
        repeat(3) @(posedge clk);
        rst = 0;
        @(posedge clk);
        
        // Test que falla: Gradiente horizontal
        $display("Test: Gradiente horizontal (0→255)");
        $display("Inputs: I00=0, I10=255, I01=0, I11=255");
        $display("Coeffs: alpha=128 (0.5), beta=128 (0.5)");
        $display("Esperado: ~128\n");
        
        @(posedge clk);
        valid_in = 1'b1;
        I00 = 8'd0;
        I10 = 8'd255;
        I01 = 8'd0;
        I11 = 8'd255;
        alpha = 8'd128;  // 0.5
        beta  = 8'd128;  // 0.5
        
        @(posedge clk);
        valid_in = 1'b0;
        
        // Esperar salida (tienes 1 ciclo de latencia + seguridad)
        @(posedge clk);
        @(posedge clk);
        
        $display("=== RESULTADOS ===");
        $display("pixel_out = %0d", pixel_out);
        $display("valid_out = %0b", valid_out);
        
        // ===========================
        // Cálculo manual equivalente
        // ===========================
        $display("\n=== CÁLCULO MANUAL ===");

        I00_q_tb   = {8'd0,   8'b0};     // 0 en Q8.8
        I10_q_tb   = {8'd255, 8'b0};     // 65280 en Q8.8
        alpha_q_tb = {8'b0, 8'd128};     // 128 en Q8.8 (~0.5)

        $display("I00_q   = %0d (0x%04h)", $signed(I00_q_tb), I00_q_tb);
        $display("I10_q   = %0d (0x%04h)", $signed(I10_q_tb), I10_q_tb);
        $display("alpha_q = %0d (0x%04h)", $signed(alpha_q_tb), alpha_q_tb);
        
        mult_ax_tb = (I10_q_tb - I00_q_tb) * alpha_q_tb;
        $display("mult_ax = %0d (0x%08h)", $signed(mult_ax_tb), mult_ax_tb);
        
        term_ax_tb = mult_ax_tb[23:8];
        $display("term_ax = %0d (0x%04h)", $signed(term_ax_tb), term_ax_tb);
        
        a_q_tb = I00_q_tb + term_ax_tb;
        $display("a_q     = %0d (0x%04h)", $signed(a_q_tb), a_q_tb);

        a_q_real_tb = $itor($signed(a_q_tb)) / 256.0;
        $display("a_q en float ≈ %0f", a_q_real_tb);
        $display("Esperado ~127.5\n");

        // TEST 2: Imagen blanca
        repeat(5) @(posedge clk);
        
        $display("\n=== TEST 2: Imagen blanca ===");
        @(posedge clk);
        valid_in = 1'b1;
        I00 = 255;
        I10 = 255;
        I01 = 255;
        I11 = 255;
        alpha = 128;
        beta  = 128;
        
        @(posedge clk);
        valid_in = 1'b0;
        
        repeat(3) @(posedge clk);
        $display("pixel_out = %0d (esperado: 255)", pixel_out);
        
        repeat(2) @(posedge clk);
        $finish;
    end
    
    // Dump para GTKWave / visor de ondas
    initial begin
        $dumpfile("debug.vcd");
        $dumpvars(0, tb_debug_modosecuencial);
    end
    
endmodule
