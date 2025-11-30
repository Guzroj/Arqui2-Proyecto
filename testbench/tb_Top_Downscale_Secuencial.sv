`timescale 1ns/1ps

module tb_Top_Downscale_Secuencial;

    localparam int SRC_W = 512;
    localparam int SRC_H = 512;
    localparam int DST_W = 256;
    localparam int DST_H = 256;
    localparam int CLK_PERIOD = 10;

    logic clk, rst;
    logic        cfg_we;
    logic [17:0] cfg_addr;
    logic [7:0]  cfg_data;
    logic        start_req;
    logic        done;
    logic [7:0]  dbg_data;

    // DUT
    Top_Downscale_Secuencial #(
        .SRC_W(SRC_W),
        .SRC_H(SRC_H),
        .DST_W(DST_W),
        .DST_H(DST_H)
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
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Imagen de entrada
    reg [7:0] test_image [0:SRC_H-1][0:SRC_W-1];
    integer file, code, i, j;

    // Mostrar parámetros
    initial begin
        #1;
        $display("\n=== PARÁMETROS DEL DISEÑO ===");
        $display("SRC_H = %0d, SRC_W = %0d", SRC_H, SRC_W);
        $display("DST_H = %0d, DST_W = %0d", DST_H, DST_W);
        $display("================================\n");
    end

    // Leer imagen desde archivo
    initial begin
        $display("\n=== TEST 512x512 → 256x256 SECUENCIAL ===\n");
        $display("[%0t] Leyendo archivo...", $time);

        file = $fopen("C:/Users/gabri/OneDrive/Desktop/PrograProyectoArqui/Arqui2-Proyecto/imagen_grayscale.txt", "r");

        if (file == 0) begin
            $display("ERROR: No se pudo abrir imagen_grayscale.txt");
            $finish;
        end

        for (i = 0; i < SRC_H; i = i + 1) begin
            for (j = 0; j < SRC_W; j = j + 1) begin
                code = $fscanf(file, "%d", test_image[i][j]);
                if (code != 1) begin
                    $display("ERROR leyendo [%0d,%0d]", i, j);
                    $finish;
                end
            end
        end

        $fclose(file);
        $display("[%0t] ✓ Archivo leído\n", $time);
        
        // Mostrar primeros píxeles
        $display("Primeros 8 píxeles del archivo:");
        for (j = 0; j < 8; j = j + 1)
            $display("  test_image[0][%0d] = %0d", j, test_image[0][j]);
        $display("");
    end

    // Verificar memoria después de cargar
    task verify_memory_load;
        begin
            $display("\n[%0t] Verificando BRAM...", $time);
            $display("  Primeros 8 valores en BRAM:");
            for (i = 0; i < 8; i = i + 1) begin
                $display("    memory[%0d] = %0d", i, dut.mem.memory[i]);
            end
            
            if (dut.mem.memory[0] === 8'bxxxxxxxx)
                $display("  ✗ ERROR: Memoria contiene valores indefinidos!");
            else
                $display("  ✓ Memoria inicializada correctamente");
        end
    endtask

    // Verificar imagen de entrada
    task verify_input_image;
        begin
            $display("\n=== VERIFICANDO IMAGEN DE ENTRADA ===");
            $display("Esquina superior izquierda [0,0] = %0d", dut.mem.memory[0]);
            $display("Esquina superior derecha [0,511] = %0d", dut.mem.memory[511]);
            $display("Centro [256,256] = %0d", dut.mem.memory[256*512 + 256]);
            $display("Esquina inferior izquierda [511,0] = %0d", dut.mem.memory[511*512]);
            $display("Esquina inferior derecha [511,511] = %0d", dut.mem.memory[512*512-1]);
            
            if (dut.mem.memory[0] == dut.mem.memory[511] &&
                dut.mem.memory[0] == dut.mem.memory[256*512 + 256])
                $display("⚠ WARNING: Primeros valores son iguales");
            else
                $display("✓ Valores diferentes en distintas posiciones");
        end
    endtask

    // Cargar imagen
    task load_image;
        integer errors;
        begin
            $display("\n[%0t] Cargando imagen en BRAM...", $time);
            errors = 0;
            cfg_we = 0;
            @(posedge clk);

            for (i = 0; i < SRC_H; i = i + 1) begin
                for (j = 0; j < SRC_W; j = j + 1) begin
                    cfg_we = 1;
                    cfg_addr = i * SRC_W + j;
                    cfg_data = test_image[i][j];
                    
                    if (test_image[i][j] === 8'bxxxxxxxx) begin
                        $display("  ✗ WARNING: Escribiendo 'x' en [%0d,%0d]", i, j);
                        errors = errors + 1;
                        if (errors > 10) begin
                            $display("  ✗ Demasiados errores, abortando...");
                            $finish;
                        end
                    end
                    
                    @(posedge clk);
                    
                    if ((i * SRC_W + j) % (SRC_H * SRC_W / 10) == 0)
                        $display("  Progreso: %0d%%", ((i * SRC_W + j) * 100) / (SRC_H * SRC_W));
                end
            end

            cfg_we = 0;
            @(posedge clk);
            $display("[%0t] ✓ Carga completada\n", $time);
            
            verify_memory_load();
        end
    endtask

    // Ejecutar downscale
    task run_downscale;
        integer timeout;
        begin
            $display("\n[%0t] Iniciando downscale...", $time);
            
            start_req = 1;
            @(posedge clk);
            start_req = 0;

            timeout = 0;
            while (!done && timeout < 2000000) begin
                @(posedge clk);
                timeout = timeout + 1;
                
                // ⭐ CAMBIO: pixel_idx en vez de fetch_cnt
                if (timeout % 100000 == 0) begin
                    $display("  Ciclos: %0d, state=%0d, pixel_idx=%0d", 
                             timeout, dut.u_seq.state, dut.u_seq.pixel_idx);
                    $display("    mem_rd_req=%0b, mem_rd_valid=%0b, i_dst=%0d, j_dst=%0d",
                             dut.mem_rd_req, dut.mem_rd_valid, dut.u_seq.i_dst, dut.u_seq.j_dst);
                end
            end

            if (!done) begin
                $display("[%0t] ✗ TIMEOUT después de %0d ciclos", $time, timeout);
                $display("  state=%0d, pixel_idx=%0d", dut.u_seq.state, dut.u_seq.pixel_idx);
                $display("  mem_rd_req=%0b, mem_rd_valid=%0b", dut.mem_rd_req, dut.mem_rd_valid);
                $finish;
            end

            $display("[%0t] ✓ Downscale completado en %0d ciclos\n", $time, timeout);
        end
    endtask

    // Verificar salida
    task verify_output;
        integer undefined_count, zero_count;
        begin
            $display("\n[%0t] Verificando salida...", $time);
            
            undefined_count = 0;
            zero_count = 0;
            
            for (i = 0; i < DST_H; i = i + 1) begin
                for (j = 0; j < DST_W; j = j + 1) begin
                    if (dut.output_memory[i * DST_W + j] === 8'bxxxxxxxx)
                        undefined_count = undefined_count + 1;
                    if (dut.output_memory[i * DST_W + j] == 8'd0)
                        zero_count = zero_count + 1;
                end
            end
            
            $display("  Total píxeles: %0d", DST_H * DST_W);
            $display("  Indefinidos (x): %0d", undefined_count);
            $display("  Ceros: %0d", zero_count);
            
            if (undefined_count > 0)
                $display("  ✗ ERROR: Hay valores indefinidos");
            else
                $display("  ✓ No hay valores indefinidos");
        end
    endtask

    // Verificar mapeo
    task verify_pixel_mapping;
        integer expected_i, expected_j, pix;
        begin
            $display("\n=== VERIFICACIÓN DE MAPEO DE PÍXELES ===");
            
            $display("\n--- Primeros 20 píxeles ---");
            for (pix = 0; pix < 20; pix = pix + 1) begin
                expected_i = pix / DST_W;
                expected_j = pix % DST_W;
                $display("pix=%3d → esperado[%3d,%3d], valor=%3d", 
                         pix, expected_i, expected_j, 
                         dut.output_memory[expected_i * DST_W + expected_j]);
            end
            
            $display("\n--- Píxeles clave ---");
            $display("[0,0]     = %3d", dut.output_memory[0]);
            $display("[0,128]   = %3d", dut.output_memory[128]);
            $display("[128,0]   = %3d", dut.output_memory[128 * DST_W]);
            $display("[128,128] = %3d", dut.output_memory[128 * DST_W + 128]);
            $display("[255,255] = %3d", dut.output_memory[255 * DST_W + 255]);
        end
    endtask

    // Mostrar muestra
    task display_sample;
        begin
            $display("\n=== MUESTRA DE SALIDA (primeras 8x16) ===");
            for (i = 0; i < 8; i = i + 1) begin
                $write("Row %3d: ", i);
                for (j = 0; j < 16; j = j + 1) begin
                    if (dut.output_memory[i * DST_W + j] === 8'bxxxxxxxx)
                        $write("  x ");
                    else
                        $write("%3d ", dut.output_memory[i * DST_W + j]);
                end
                $write("\n");
            end
            $display("==========================================\n");
        end
    endtask

    // Guardar imagen
    task save_output_image;
        integer outfile;
        begin
            $display("\n[%0t] Guardando imagen de salida...", $time);
            
            outfile = $fopen("C:/Users/gabri/OneDrive/Desktop/PrograProyectoArqui/Arqui2-Proyecto/imagen_output_secuencial.txt", "w");
            
            if (outfile == 0) begin
                $display("  ✗ ERROR: No se pudo crear archivo");
                return;
            end
            
            // Escribir dimensiones primero
            $fwrite(outfile, "%0d %0d\n", DST_H, DST_W);
            
            for (i = 0; i < DST_H; i = i + 1) begin
                for (j = 0; j < DST_W; j = j + 1) begin
                    $fwrite(outfile, "%0d", dut.output_memory[i * DST_W + j]);
                    if (j < DST_W - 1)
                        $fwrite(outfile, " ");
                    else
                        $fwrite(outfile, "\n");
                end
                
                if (i % (DST_H / 10) == 0)
                    $display("  Progreso: %0d%%", (i * 100) / DST_H);
            end
            
            $fclose(outfile);
            $display("[%0t] ✓ Imagen guardada en imagen_output_secuencial.txt", $time);
            $display("  Formato: %0d filas x %0d columnas\n", DST_H, DST_W);
        end
    endtask

    // Secuencia principal
    initial begin
        rst = 1;
        start_req = 0;
        cfg_we = 0;
        cfg_addr = 0;
        cfg_data = 0;

        repeat(10) @(posedge clk);
        rst = 0;
        repeat(5) @(posedge clk);

        load_image();
        verify_input_image();
        repeat(10) @(posedge clk);
        
        run_downscale();
        repeat(10) @(posedge clk);
        
        verify_output();
        verify_pixel_mapping();
        display_sample();
        
        save_output_image();

        $display("\n=== TEST COMPLETADO ===\n");
        $stop;
    end

    // Timeout global
    initial begin
        #(CLK_PERIOD * 20000000);
        $display("\n✗ TIMEOUT GLOBAL");
        $finish;
    end

endmodule