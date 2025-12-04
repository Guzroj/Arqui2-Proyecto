// ============================================================================
// tb_downscale_sequential.sv
// Testbench completo para downscaling secuencial con pipeline
// Arquitectura de Computadores 2 - FASE 5
// ============================================================================

`timescale 1ns / 1ps

module tb_downscale_sequential;

    // ========================================================================
    // Señales del testbench
    // ========================================================================

    logic        clk;
    logic        rst_n;
    logic        start;
    logic        busy;
    logic        done;

    // Memoria de entrada (64x64)
    logic        mem_in_rd_en;
    logic [11:0] mem_in_rd_addr;
    logic [7:0]  mem_in_rd_data;

    // Memoria de salida (32x32)
    logic        mem_out_wr_en;
    logic [9:0]  mem_out_wr_addr;
    logic [7:0]  mem_out_wr_data;

    // Constantes
    localparam CLK_PERIOD = 20;  // 50 MHz
    localparam IN_SIZE = 64 * 64;   // 4096
    localparam OUT_SIZE = 32 * 32;  // 1024

    // ========================================================================
    // Generación de reloj
    // ========================================================================

    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // ========================================================================
    // Instancia de memorias
    // ========================================================================

    image_memory_input u_mem_input (
        .clk        (clk),
        .rst_n      (rst_n),
        .wr_en_a    (1'b0),           // No escribimos en el test
        .wr_addr_a  (12'd0),
        .wr_data_a  (8'd0),
        .rd_en_b    (mem_in_rd_en),
        .rd_addr_b  (mem_in_rd_addr),
        .rd_data_b  (mem_in_rd_data)
    );

    image_memory_output u_mem_output (
        .clk            (clk),
        .rst_n          (rst_n),
        .wr_en_a        (mem_out_wr_en),
        .wr_addr_a      (mem_out_wr_addr),
        .wr_data_a      (mem_out_wr_data),
        .rd_en_b        (1'b0),
        .rd_addr_b      (10'd0),
        .rd_data_b      (),
        .pixels_written ()
    );

    // ========================================================================
    // Instancia del DUT
    // ========================================================================

    downscale_sequential u_dut (
        .clk            (clk),
        .rst_n          (rst_n),
        .start          (start),
        .busy           (busy),
        .done           (done),
        .mem_in_rd_en   (mem_in_rd_en),
        .mem_in_rd_addr (mem_in_rd_addr),
        .mem_in_rd_data (mem_in_rd_data),
        .mem_out_wr_en  (mem_out_wr_en),
        .mem_out_wr_addr(mem_out_wr_addr),
        .mem_out_wr_data(mem_out_wr_data)
    );

    // ========================================================================
    // Variables del testbench
    // ========================================================================

    integer i, j, addr;
    integer errors;
    logic [7:0] expected_value;
    real expected_float;

    // ========================================================================
    // Tareas de utilidad
    // ========================================================================

    // Inicializar memoria de entrada con patrón
    task init_input_memory(input logic [7:0] pattern_type);
        $display("Inicializando memoria de entrada (64x64)...");

        for (int y = 0; y < 64; y++) begin
            for (int x = 0; x < 64; x++) begin
                addr = y * 64 + x;

                case (pattern_type)
                    8'd0: begin // Patrón de gradiente horizontal
                        u_mem_input.mem[addr] = x * 4;
                    end
                    8'd1: begin // Patrón de gradiente vertical
                        u_mem_input.mem[addr] = y * 4;
                    end
                    8'd2: begin // Patrón de tablero de ajedrez
                        u_mem_input.mem[addr] = ((x[0] ^ y[0]) ? 8'd255 : 8'd0);
                    end
                    8'd3: begin // Patrón constante
                        u_mem_input.mem[addr] = 8'd128;
                    end
                    8'd4: begin // Patrón aleatorio
                        u_mem_input.mem[addr] = $urandom_range(0, 255);
                    end
                    default: begin // Incremento lineal
                        u_mem_input.mem[addr] = addr[7:0];
                    end
                endcase
            end
        end

        $display("Memoria de entrada inicializada con patrón %0d", pattern_type);
    endtask

    // Verificar resultado en memoria de salida
    task verify_output_memory();
        automatic integer pixel_errors = 0;
        automatic integer write_count = 0;

        $display("\n========================================");
        $display("Verificando memoria de salida (32x32)");
        $display("========================================");

        // Contar cuántos píxeles tienen valor distinto de 0
        // (esto es solo para debug, el test real usa pixels_written)
        for (int y = 0; y < 32; y++) begin
            for (int x = 0; x < 32; x++) begin
                addr = y * 32 + x;
                if (u_mem_output.mem[addr] != 8'd0) begin
                    write_count++;
                end
            end
        end

        $display("Píxeles no-cero en memoria: %0d/1024", write_count);
        $display("Contador pixels_written: %0d", u_mem_output.pixels_written);

        // El test real: verificar el contador de píxeles escritos
        if (u_mem_output.pixels_written != 11'd1024) begin
            $display("[ERROR] Solo se escribieron %0d/1024 píxeles según contador",
                     u_mem_output.pixels_written);
            errors++;
        end else begin
            $display("[OK] Se escribieron los 1024 píxeles correctamente");
        end

        // Mostrar muestra de valores para debug
        $display("Muestra de píxeles:");
        $display("  (0,0) = %0d, (1,0) = %0d, (0,1) = %0d, (31,31) = %0d",
                 u_mem_output.mem[0], u_mem_output.mem[1],
                 u_mem_output.mem[32], u_mem_output.mem[1023]);
    endtask

    // Reset del sistema
    task reset_system();
        rst_n = 0;
        start = 0;
        repeat (5) @(posedge clk);
        rst_n = 1;
        repeat (2) @(posedge clk);
    endtask

    // Ejecutar downscaling
    task run_downscale();
        $display("\n========================================");
        $display("Iniciando downscaling");
        $display("========================================");

        start = 1;
        @(posedge clk);
        start = 0;

        // Esperar a que termine
        wait(done);
        $display("[OK] Downscaling completado");

        repeat (5) @(posedge clk);
    endtask

    // ========================================================================
    // Tests
    // ========================================================================

    initial begin
        $display("\n========================================");
        $display("Testbench: Downscale Sequential (Pipeline)");
        $display("========================================");
        $display("Input:  64x64 = 4096 píxeles");
        $display("Output: 32x32 = 1024 píxeles");
        $display("Pipeline: 3 etapas");
        $display("========================================\n");

        errors = 0;

        // ====================================================================
        // TEST 1: Patrón de gradiente horizontal
        // ====================================================================
        $display("\n========================================");
        $display("TEST 1: Gradiente horizontal");
        $display("========================================");

        reset_system();
        init_input_memory(8'd0);  // Gradiente horizontal
        run_downscale();
        verify_output_memory();

        $display("Test 1 completado\n");

        // ====================================================================
        // TEST 2: Patrón de gradiente vertical
        // ====================================================================
        $display("\n========================================");
        $display("TEST 2: Gradiente vertical");
        $display("========================================");

        reset_system();
        init_input_memory(8'd1);  // Gradiente vertical
        run_downscale();
        verify_output_memory();

        $display("Test 2 completado\n");

        // ====================================================================
        // TEST 3: Patrón de tablero de ajedrez
        // ====================================================================
        $display("\n========================================");
        $display("TEST 3: Tablero de ajedrez");
        $display("========================================");

        reset_system();
        init_input_memory(8'd2);  // Tablero de ajedrez
        run_downscale();
        verify_output_memory();

        $display("Test 3 completado\n");

        // ====================================================================
        // TEST 4: Patrón constante (test de interpolación perfecta)
        // ====================================================================
        $display("\n========================================");
        $display("TEST 4: Patrón constante");
        $display("========================================");

        reset_system();
        init_input_memory(8'd3);  // Constante = 128
        run_downscale();

        // Verificar que todos los píxeles sean 128
        for (int addr_check = 0; addr_check < OUT_SIZE; addr_check++) begin
            if (u_mem_output.mem[addr_check] != 8'd128) begin
                $display("[ERROR] Píxel %0d = %0d (esperado 128)",
                         addr_check, u_mem_output.mem[addr_check]);
                errors++;
            end
        end

        if (errors == 0) begin
            $display("[OK] Todos los píxeles = 128 (interpolación correcta)");
        end

        $display("Test 4 completado\n");

        // ====================================================================
        // Resumen de tests
        // ====================================================================
        $display("\n========================================");
        $display("Resumen de Tests");
        $display("========================================");

        if (errors == 0) begin
            $display("✓ TODOS LOS TESTS PASARON");
        end else begin
            $display("✗ %0d ERRORES ENCONTRADOS", errors);
        end

        $display("========================================\n");

        $finish;
    end

    // ========================================================================
    // Timeout de seguridad
    // ========================================================================

    initial begin
        #(CLK_PERIOD * 1000000);  // Timeout después de 1M ciclos
        $display("\n[ERROR] Timeout del testbench");
        $finish;
    end

    // ========================================================================
    // Generación de waveforms
    // ========================================================================

    initial begin
        $dumpfile("downscale_sequential.vcd");
        $dumpvars(0, tb_downscale_sequential);
    end

endmodule
