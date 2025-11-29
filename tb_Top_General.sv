`timescale 1ns/1ps

// ================================================================
// tb_Top_General.sv
// Testbench para Top_General con interfaz JTAG-like
// Simula la comunicacion que vendria desde connect.sv
// Carga imagen desde archivo .txt
// ================================================================

module tb_Top_General;

    // ==================================================
    // Parámetros
    // ==================================================
    localparam IMGW = 32;
    localparam IMGH = 32;
    localparam N = 4;
    localparam CLK_PERIOD = 10;

    // Direcciones de registros JTAG (del mapa en JTAG_Interface)
    localparam ADDR_CONTROL   = 8'h00;
    localparam ADDR_XRATIO    = 8'h01;
    localparam ADDR_YRATIO    = 8'h02;
    localparam ADDR_WRITEADDR = 8'h03;
    localparam ADDR_WRITEDATA = 8'h04;
    localparam ADDR_READDATA  = 8'h05;
    localparam ADDR_DONEFLAG  = 8'h06;
    localparam ADDR_PERFCOUNT = 8'h07;

    // Bits de control
    localparam CTRL_START = 32'h00000001;
    localparam CTRL_STEP  = 32'h00000002;
    localparam CTRL_MODE  = 32'h00000004;  // 0=Secuencial, 1=SIMD

    // ==================================================
    // Señales
    // ==================================================
    logic clk, rst;
    
    // Interfaz Avalon-like (simula lo que vendria de connect.sv)
    logic        avsread;
    logic        avswrite;
    logic [7:0]  avsaddress;
    logic [31:0] avswritedata;
    logic [31:0] avsreaddata;

    // ==================================================
    // Variables para testbench
    // ==================================================
    integer i, j;
    integer file;
    integer code;
    integer test_image [0:IMGH-1][0:IMGW-1];
    integer read_value;

    // ==================================================
    // DUT: Top_General
    // ==================================================
    Top_General #(
        .IMGW(IMGW),
        .IMGH(IMGH),
        .N(N)
    ) dut (
        .clk(clk),
        .rst(rst),
        .avsread(avsread),
        .avswrite(avswrite),
        .avsaddress(avsaddress),
        .avswritedata(avswritedata),
        .avsreaddata(avsreaddata)
    );

    // ==================================================
    // Generador de reloj
    // ==================================================
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // ==================================================
    // Tarea: Escribir un registro via JTAG-like
    // ==================================================
    task jtag_write(input [7:0] addr, input [31:0] data);
        begin
            @(posedge clk);
            avsaddress   = addr;
            avswritedata = data;
            avswrite     = 1;
            avsread      = 0;
            @(posedge clk);
            avswrite     = 0;
            @(posedge clk);
        end
    endtask

    // ==================================================
    // Tarea: Leer un registro via JTAG-like
    // ==================================================
    task jtag_read(input [7:0] addr, output [31:0] data);
        begin
            @(posedge clk);
            avsaddress = addr;
            avswrite   = 0;
            avsread    = 1;
            @(posedge clk);
            avsread    = 0;
            @(posedge clk);
            data = avsreaddata;
        end
    endtask

    // ==================================================
    // Tarea: Escribir un pixel en la memoria de imagen
    // ==================================================
    task write_pixel(input [31:0] addr, input [7:0] pixel);
        begin
            jtag_write(ADDR_WRITEADDR, addr);
            jtag_write(ADDR_WRITEDATA, {24'h000000, pixel});
        end
    endtask

    // ==================================================
    // Tarea: Cargar imagen desde archivo .txt
    // ==================================================
    task load_image_from_file(input string filename);
        begin
            $display("[%0t] Abriendo archivo: %s", $time, filename);
            
            file = $fopen(filename, "r");
            if (file == 0) begin
                $display("ERROR: No se pudo abrir el archivo %s", filename);
                $finish;
            end

            $display("[%0t] Leyendo imagen %0dx%0d...", $time, IMGH, IMGW);
            
            for (i = 0; i < IMGH; i = i + 1) begin
                for (j = 0; j < IMGW; j = j + 1) begin
                    code = $fscanf(file, "%d", test_image[i][j]);
                    if (code != 1) begin
                        $display("ERROR leyendo pixel [%0d,%0d]", i, j);
                        $fclose(file);
                        $finish;
                    end
                end
            end

            $fclose(file);
            $display("[%0t] Archivo leido correctamente", $time);
            
            // Mostrar primeros valores
            $display("Primeros 8 pixeles del archivo:");
            for (j = 0; j < 8; j = j + 1)
                $display("  test_image[0][%0d] = %0d", j, test_image[0][j]);
        end
    endtask

    // ==================================================
    // Tarea: Cargar imagen a la memoria via JTAG
    // ==================================================
    task upload_image_via_jtag();
        integer addr;
        begin
            $display("[%0t] Cargando imagen en memoria via JTAG...", $time);
            
            for (i = 0; i < IMGH; i = i + 1) begin
                for (j = 0; j < IMGW; j = j + 1) begin
                    addr = i * IMGW + j;
                    write_pixel(addr, test_image[i][j]);
                    
                    // Mostrar progreso cada 25%
                    if (addr % (IMGH * IMGW / 4) == 0 && addr > 0) begin
                        $display("  Progreso: %0d%%", (addr * 100) / (IMGH * IMGW));
                    end
                end
            end
            
            $display("[%0t] Imagen cargada completamente", $time);
        end
    endtask

    // ==================================================
    // Tarea: Esperar a que done_flag sea 1
    // ==================================================
    task wait_for_done(input integer timeout_cycles);
        integer cycles;
        logic [31:0] status;
        begin
            cycles = 0;
            status = 0;
            
            while ((status & 1) == 0 && cycles < timeout_cycles) begin
                jtag_read(ADDR_DONEFLAG, status);
                cycles = cycles + 1;
                
                if (cycles % 1000 == 0)
                    $display("  Esperando done... ciclos=%0d", cycles);
            end
            
            if ((status & 1) == 0) begin
                $display("TIMEOUT: Proceso no completo despues de %0d ciclos", timeout_cycles);
            end else begin
                $display("[%0t] Proceso completado en %0d lecturas", $time, cycles);
            end
        end
    endtask

    // ==================================================
    // Tarea: Leer performance counter
    // ==================================================
    task read_performance();
        logic [31:0] perf;
        begin
            jtag_read(ADDR_PERFCOUNT, perf);
            $display("Performance Counter: %0d ciclos", perf);
        end
    endtask

    // ==================================================
    // Tarea: Test modo Secuencial
    // ==================================================
    task test_modo_secuencial();
        begin
            $display("\n========================================");
            $display("TEST: Modo Secuencial");
            $display("========================================\n");
            
            // Configurar modo secuencial (bit 2 = 0)
            jtag_write(ADDR_CONTROL, 32'h00000000);
            
            // Cargar imagen
            upload_image_via_jtag();
            
            // Iniciar procesamiento (bit 0 = 1, bit 2 = 0)
            $display("[%0t] Iniciando modo secuencial...", $time);
            jtag_write(ADDR_CONTROL, CTRL_START);  // start=1, mode=0
            
            // Esperar completado
            wait_for_done(100000);
            
            // Leer performance
            read_performance();
            
            // Detener
            jtag_write(ADDR_CONTROL, 32'h00000000);
            
            $display("\nModo Secuencial completado\n");
        end
    endtask

    // ==================================================
    // Tarea: Test modo SIMD
    // ==================================================
    task test_modo_simd();
        begin
            $display("\n========================================");
            $display("TEST: Modo SIMD");
            $display("========================================\n");
            
            // Configurar modo SIMD (bit 2 = 1)
            jtag_write(ADDR_CONTROL, CTRL_MODE);
            
            // Cargar imagen
            upload_image_via_jtag();
            
            // Iniciar procesamiento (bit 0 = 1, bit 2 = 1)
            $display("[%0t] Iniciando modo SIMD...", $time);
            jtag_write(ADDR_CONTROL, CTRL_START | CTRL_MODE);  // start=1, mode=1
            
            // Esperar completado
            wait_for_done(100000);
            
            // Leer performance
            read_performance();
            
            // Detener
            jtag_write(ADDR_CONTROL, 32'h00000000);
            
            $display("\nModo SIMD completado\n");
        end
    endtask

    // ==================================================
    // Tarea: Generar imagen de prueba gradiente
    // ==================================================
    task generate_gradient_image();
        begin
            $display("[%0t] Generando imagen gradiente %0dx%0d...", $time, IMGH, IMGW);
            
            for (i = 0; i < IMGH; i = i + 1) begin
                for (j = 0; j < IMGW; j = j + 1) begin
                    test_image[i][j] = (i * 4 + j * 2) & 255;
                end
            end
            
            $display("[%0t] Imagen generada", $time);
        end
    endtask

    // ==================================================
    // Secuencia principal
    // ==================================================
    initial begin
        $display("\n================================================================");
        $display("  Testbench Top_General con interfaz JTAG-like");
        $display("  Tamaño imagen: %0dx%0d, SIMD lanes: %0d", IMGW, IMGH, N);
        $display("================================================================\n");
        
        // Inicialización
        rst = 1;
        avsread = 0;
        avswrite = 0;
        avsaddress = 0;
        avswritedata = 0;
        
        repeat(10) @(posedge clk);
        rst = 0;
        repeat(5) @(posedge clk);
        
        // =============================================
        // Opción 1: Cargar desde archivo .txt
        // Descomenta la siguiente línea y comenta generate_gradient_image()
        // =============================================
        // load_image_from_file("imagen_grayscale.txt");
        
        // =============================================
        // Opción 2: Generar imagen gradiente de prueba
        // =============================================
        generate_gradient_image();
        
        // =============================================
        // Test modo SIMD
        // =============================================
        test_modo_simd();
        
        repeat(100) @(posedge clk);
        
        // =============================================
        // Test modo Secuencial (opcional)
        // Descomenta para probar ambos modos
        // =============================================
        // generate_gradient_image();  // Regenerar imagen
        // test_modo_secuencial();
        
        $display("\n================================================================");
        $display("  TEST COMPLETADO");
        $display("================================================================\n");
        
        $finish;
    end

    // ==================================================
    // Timeout global
    // ==================================================
    initial begin
        #(CLK_PERIOD * 500000);
        $display("\nTIMEOUT GLOBAL");
        $finish;
    end

endmodule

