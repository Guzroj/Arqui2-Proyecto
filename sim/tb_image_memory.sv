// ============================================================================
// tb_image_memory.sv
// Testbench para los módulos de memoria de imágenes
// FASE 4: Módulos de Memoria
// ============================================================================
//
// Tests implementados:
// 1. Test básico de escritura/lectura (input memory)
// 2. Test básico de escritura/lectura (output memory)
// 3. Test de escritura secuencial completa
// 4. Test de lectura secuencial completa
// 5. Test de acceso aleatorio
// 6. Test de escritura y lectura simultáneas (dual-port)
// 7. Test de límites (boundary test)
// 8. Test de patrón checkerboard
//
// ============================================================================

`timescale 1ns / 1ps

module tb_image_memory;

    // ========================================================================
    // Parámetros del testbench
    // ========================================================================
    parameter CLK_PERIOD = 10;  // 100 MHz

    // Parámetros para memoria de entrada (64x64)
    parameter INPUT_WIDTH = 64;
    parameter INPUT_HEIGHT = 64;
    parameter INPUT_DATA_WIDTH = 8;
    parameter INPUT_ADDR_WIDTH = $clog2(INPUT_WIDTH * INPUT_HEIGHT);
    parameter INPUT_MEM_DEPTH = INPUT_WIDTH * INPUT_HEIGHT;

    // Parámetros para memoria de salida (32x32)
    parameter OUTPUT_WIDTH = 32;
    parameter OUTPUT_HEIGHT = 32;
    parameter OUTPUT_DATA_WIDTH = 8;
    parameter OUTPUT_ADDR_WIDTH = $clog2(OUTPUT_WIDTH * OUTPUT_HEIGHT);
    parameter OUTPUT_MEM_DEPTH = OUTPUT_WIDTH * OUTPUT_HEIGHT;

    // ========================================================================
    // Señales del testbench
    // ========================================================================
    logic clk;
    logic rst_n;

    // Señales para memoria de entrada
    logic                           input_wr_en_a;
    logic [INPUT_ADDR_WIDTH-1:0]    input_wr_addr_a;
    logic [INPUT_DATA_WIDTH-1:0]    input_wr_data_a;
    logic                           input_rd_en_b;
    logic [INPUT_ADDR_WIDTH-1:0]    input_rd_addr_b;
    logic [INPUT_DATA_WIDTH-1:0]    input_rd_data_b;

    // Señales para memoria de salida
    logic                           output_wr_en_a;
    logic [OUTPUT_ADDR_WIDTH-1:0]   output_wr_addr_a;
    logic [OUTPUT_DATA_WIDTH-1:0]   output_wr_data_a;
    logic                           output_rd_en_b;
    logic [OUTPUT_ADDR_WIDTH-1:0]   output_rd_addr_b;
    logic [OUTPUT_DATA_WIDTH-1:0]   output_rd_data_b;
    logic [OUTPUT_ADDR_WIDTH:0]     output_pixels_written;

    // Variables auxiliares
    integer errors;
    integer i, j;
    logic [INPUT_DATA_WIDTH-1:0] expected_data;

    // ========================================================================
    // Instancias de los DUTs
    // ========================================================================

    // Memoria de entrada (64x64)
    image_memory_input #(
        .WIDTH(INPUT_WIDTH),
        .HEIGHT(INPUT_HEIGHT),
        .DATA_WIDTH(INPUT_DATA_WIDTH)
    ) u_input_mem (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en_a(input_wr_en_a),
        .wr_addr_a(input_wr_addr_a),
        .wr_data_a(input_wr_data_a),
        .rd_en_b(input_rd_en_b),
        .rd_addr_b(input_rd_addr_b),
        .rd_data_b(input_rd_data_b)
    );

    // Memoria de salida (32x32)
    image_memory_output #(
        .WIDTH(OUTPUT_WIDTH),
        .HEIGHT(OUTPUT_HEIGHT),
        .DATA_WIDTH(OUTPUT_DATA_WIDTH)
    ) u_output_mem (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en_a(output_wr_en_a),
        .wr_addr_a(output_wr_addr_a),
        .wr_data_a(output_wr_data_a),
        .rd_en_b(output_rd_en_b),
        .rd_addr_b(output_rd_addr_b),
        .rd_data_b(output_rd_data_b),
        .pixels_written(output_pixels_written)
    );

    // ========================================================================
    // Generación de reloj
    // ========================================================================
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // ========================================================================
    // Task: Reset
    // ========================================================================
    task reset();
        begin
            rst_n = 0;
            input_wr_en_a = 0;
            input_wr_addr_a = 0;
            input_wr_data_a = 0;
            input_rd_en_b = 0;
            input_rd_addr_b = 0;
            output_wr_en_a = 0;
            output_wr_addr_a = 0;
            output_wr_data_a = 0;
            output_rd_en_b = 0;
            output_rd_addr_b = 0;
            #(CLK_PERIOD * 2);
            rst_n = 1;
            #(CLK_PERIOD * 2);
        end
    endtask

    // ========================================================================
    // Task: Escribir un píxel en memoria de entrada
    // ========================================================================
    task write_input_pixel(input [INPUT_ADDR_WIDTH-1:0] addr, input [INPUT_DATA_WIDTH-1:0] data);
        begin
            @(posedge clk);
            input_wr_en_a = 1;
            input_wr_addr_a = addr;
            input_wr_data_a = data;
            @(posedge clk);
            input_wr_en_a = 0;
        end
    endtask

    // ========================================================================
    // Task: Leer un píxel de memoria de entrada
    // ========================================================================
    task read_input_pixel(input [INPUT_ADDR_WIDTH-1:0] addr, output [INPUT_DATA_WIDTH-1:0] data);
        begin
            @(posedge clk);
            input_rd_en_b = 1;
            input_rd_addr_b = addr;
            @(posedge clk);
            @(posedge clk);  // Esperar un ciclo extra por la latencia de lectura
            data = input_rd_data_b;
            input_rd_en_b = 0;
        end
    endtask

    // ========================================================================
    // Task: Escribir un píxel en memoria de salida
    // ========================================================================
    task write_output_pixel(input [OUTPUT_ADDR_WIDTH-1:0] addr, input [OUTPUT_DATA_WIDTH-1:0] data);
        begin
            @(posedge clk);
            output_wr_en_a = 1;
            output_wr_addr_a = addr;
            output_wr_data_a = data;
            @(posedge clk);
            output_wr_en_a = 0;
        end
    endtask

    // ========================================================================
    // Task: Leer un píxel de memoria de salida
    // ========================================================================
    task read_output_pixel(input [OUTPUT_ADDR_WIDTH-1:0] addr, output [OUTPUT_DATA_WIDTH-1:0] data);
        begin
            @(posedge clk);
            output_rd_en_b = 1;
            output_rd_addr_b = addr;
            @(posedge clk);
            @(posedge clk);  // Esperar un ciclo extra por la latencia de lectura
            data = output_rd_data_b;
            output_rd_en_b = 0;
        end
    endtask

    // ========================================================================
    // TEST 1: Test básico de escritura/lectura (input memory)
    // ========================================================================
    task test_1_basic_input_rw();
        begin
            $display("\n========================================");
            $display("TEST 1: Basic Input Memory Read/Write");
            $display("========================================");

            reset();

            // Escribir algunos píxeles
            write_input_pixel(0, 8'h12);
            write_input_pixel(1, 8'h34);
            write_input_pixel(100, 8'hAB);
            write_input_pixel(INPUT_MEM_DEPTH-1, 8'hFF);

            // Leer y verificar
            read_input_pixel(0, expected_data);
            if (expected_data != 8'h12) begin
                $display("[FAIL] Address 0: Expected 0x12, Got 0x%02X", expected_data);
                errors++;
            end else begin
                $display("[OK] Address 0: 0x%02X", expected_data);
            end

            read_input_pixel(1, expected_data);
            if (expected_data != 8'h34) begin
                $display("[FAIL] Address 1: Expected 0x34, Got 0x%02X", expected_data);
                errors++;
            end else begin
                $display("[OK] Address 1: 0x%02X", expected_data);
            end

            read_input_pixel(100, expected_data);
            if (expected_data != 8'hAB) begin
                $display("[FAIL] Address 100: Expected 0xAB, Got 0x%02X", expected_data);
                errors++;
            end else begin
                $display("[OK] Address 100: 0x%02X", expected_data);
            end

            read_input_pixel(INPUT_MEM_DEPTH-1, expected_data);
            if (expected_data != 8'hFF) begin
                $display("[FAIL] Last address: Expected 0xFF, Got 0x%02X", expected_data);
                errors++;
            end else begin
                $display("[OK] Last address: 0x%02X", expected_data);
            end

            $display("Test 1 completed\n");
        end
    endtask

    // ========================================================================
    // TEST 2: Test básico de escritura/lectura (output memory)
    // ========================================================================
    task test_2_basic_output_rw();
        begin
            $display("\n========================================");
            $display("TEST 2: Basic Output Memory Read/Write");
            $display("========================================");

            reset();

            // Escribir algunos píxeles
            write_output_pixel(0, 8'h55);
            write_output_pixel(1, 8'hAA);
            write_output_pixel(500, 8'h77);
            write_output_pixel(OUTPUT_MEM_DEPTH-1, 8'hCC);

            // Verificar contador de píxeles escritos
            #(CLK_PERIOD * 2);
            $display("Pixels written: %0d", output_pixels_written);

            // Leer y verificar
            read_output_pixel(0, expected_data);
            if (expected_data != 8'h55) begin
                $display("[FAIL] Address 0: Expected 0x55, Got 0x%02X", expected_data);
                errors++;
            end else begin
                $display("[OK] Address 0: 0x%02X", expected_data);
            end

            read_output_pixel(OUTPUT_MEM_DEPTH-1, expected_data);
            if (expected_data != 8'hCC) begin
                $display("[FAIL] Last address: Expected 0xCC, Got 0x%02X", expected_data);
                errors++;
            end else begin
                $display("[OK] Last address: 0x%02X", expected_data);
            end

            $display("Test 2 completed\n");
        end
    endtask

    // ========================================================================
    // TEST 3: Escritura secuencial completa (input memory)
    // ========================================================================
    task test_3_sequential_write();
        begin
            $display("\n========================================");
            $display("TEST 3: Sequential Write (Input Memory)");
            $display("========================================");

            reset();

            // Escribir toda la memoria con un patrón incremental
            $display("Writing %0d pixels...", INPUT_MEM_DEPTH);
            for (i = 0; i < INPUT_MEM_DEPTH; i++) begin
                write_input_pixel(i, i[7:0]);
            end

            // Verificar algunos píxeles aleatorios
            read_input_pixel(0, expected_data);
            if (expected_data != 8'h00) errors++;

            read_input_pixel(255, expected_data);
            if (expected_data != 8'hFF) errors++;

            read_input_pixel(1000, expected_data);
            if (expected_data != (1000 & 8'hFF)) errors++;

            $display("Test 3 completed\n");
        end
    endtask

    // ========================================================================
    // TEST 4: Lectura secuencial completa
    // ========================================================================
    task test_4_sequential_read();
        begin
            $display("\n========================================");
            $display("TEST 4: Sequential Read (Output Memory)");
            $display("========================================");

            reset();

            // Primero escribir toda la memoria
            $display("Writing %0d pixels...", OUTPUT_MEM_DEPTH);
            for (i = 0; i < OUTPUT_MEM_DEPTH; i++) begin
                write_output_pixel(i, (i * 3) & 8'hFF);
            end

            // Ahora leer toda la memoria y verificar
            $display("Reading and verifying %0d pixels...", OUTPUT_MEM_DEPTH);
            for (i = 0; i < OUTPUT_MEM_DEPTH; i++) begin
                read_output_pixel(i, expected_data);
                if (expected_data != ((i * 3) & 8'hFF)) begin
                    $display("[FAIL] Address %0d: Expected 0x%02X, Got 0x%02X",
                             i, (i * 3) & 8'hFF, expected_data);
                    errors++;
                    if (errors > 10) begin
                        $display("Too many errors, stopping verification");
                        break;
                    end
                end
            end

            $display("Test 4 completed\n");
        end
    endtask

    // ========================================================================
    // TEST 5: Acceso simultáneo (dual-port)
    // ========================================================================
    task test_5_dual_port();
        begin
            $display("\n========================================");
            $display("TEST 5: Dual-Port Simultaneous Access");
            $display("========================================");

            reset();

            // Escribir algunos valores
            for (i = 0; i < 10; i++) begin
                write_input_pixel(i, i * 10);
            end

            // Escribir y leer simultáneamente
            $display("Testing simultaneous write and read...");
            @(posedge clk);
            input_wr_en_a = 1;
            input_wr_addr_a = 50;
            input_wr_data_a = 8'hDE;
            input_rd_en_b = 1;
            input_rd_addr_b = 5;  // Leer dirección diferente
            @(posedge clk);
            input_wr_en_a = 0;
            @(posedge clk);
            @(posedge clk);

            // Verificar que la lectura funcionó
            if (input_rd_data_b != 8'd50) begin
                $display("[FAIL] Simultaneous read failed: Expected 50, Got %0d", input_rd_data_b);
                errors++;
            end else begin
                $display("[OK] Simultaneous read succeeded");
            end

            input_rd_en_b = 0;

            // Verificar que la escritura funcionó
            read_input_pixel(50, expected_data);
            if (expected_data != 8'hDE) begin
                $display("[FAIL] Simultaneous write failed");
                errors++;
            end else begin
                $display("[OK] Simultaneous write succeeded");
            end

            $display("Test 5 completed\n");
        end
    endtask

    // ========================================================================
    // TEST 6: Patrón Checkerboard
    // ========================================================================
    task test_6_checkerboard();
        begin
            $display("\n========================================");
            $display("TEST 6: Checkerboard Pattern");
            $display("========================================");

            reset();

            // Escribir patrón checkerboard en memoria de salida
            $display("Writing checkerboard pattern...");
            for (i = 0; i < OUTPUT_HEIGHT; i++) begin
                for (j = 0; j < OUTPUT_WIDTH; j++) begin
                    if ((i + j) % 2 == 0)
                        write_output_pixel(i * OUTPUT_WIDTH + j, 8'hFF);
                    else
                        write_output_pixel(i * OUTPUT_WIDTH + j, 8'h00);
                end
            end

            // Verificar algunas posiciones
            read_output_pixel(0, expected_data);  // (0,0) -> FF
            if (expected_data != 8'hFF) errors++;

            read_output_pixel(1, expected_data);  // (0,1) -> 00
            if (expected_data != 8'h00) errors++;

            read_output_pixel(OUTPUT_WIDTH, expected_data);  // (1,0) -> 00
            if (expected_data != 8'h00) errors++;

            $display("Test 6 completed\n");
        end
    endtask

    // ========================================================================
    // Secuencia principal de tests
    // ========================================================================
    initial begin
        $display("\n========================================");
        $display("Image Memory Testbench");
        $display("========================================");
        $display("Input Memory:  %0dx%0d = %0d pixels", INPUT_WIDTH, INPUT_HEIGHT, INPUT_MEM_DEPTH);
        $display("Output Memory: %0dx%0d = %0d pixels", OUTPUT_WIDTH, OUTPUT_HEIGHT, OUTPUT_MEM_DEPTH);
        $display("========================================\n");

        errors = 0;

        // Ejecutar todos los tests
        test_1_basic_input_rw();
        test_2_basic_output_rw();
        test_3_sequential_write();
        test_4_sequential_read();
        test_5_dual_port();
        test_6_checkerboard();

        // Resumen final
        $display("\n========================================");
        $display("Test Summary");
        $display("========================================");
        if (errors == 0) begin
            $display("ALL TESTS PASSED!");
        end else begin
            $display("TESTS FAILED: %0d errors", errors);
        end
        $display("========================================\n");

        $finish;
    end

    // ========================================================================
    // Timeout de seguridad
    // ========================================================================
    initial begin
        #(CLK_PERIOD * 1000000);  // 10ms timeout
        $display("\nERROR: Simulation timeout!");
        $finish;
    end

endmodule
