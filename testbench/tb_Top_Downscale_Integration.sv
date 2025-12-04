`timescale 1ns/1ps

module tb_Top_Downscale_Integration;

    // ==================================================
    // Parámetros
    // ==================================================
    localparam SRC_H = 512;
    localparam SRC_W = 512;
    localparam DST_H = 256;
    localparam DST_W = 256;
    localparam N = 4;
    localparam CLK_PERIOD = 10;

    // ==================================================
    // Señales
    // ==================================================
    reg clk, rst, start;
    wire done;
    reg wr_en;
    reg [17:0] wr_addr;
    reg [7:0] wr_data;
    reg [3:0] scale_factor;  // Factor de escala configurable
    // ELIMINADO: wire [7:0] image_out [0:DST_H-1][0:DST_W-1];
    // Accedemos directamente a dut.output_memory_flat

    // Performance counters
    wire [31:0] perf_flops;
    wire [31:0] perf_mem_reads;
    wire [31:0] perf_mem_writes;

    // ==================================================
    // DUT
    // ==================================================
    Top_Downscale_SIMD #(
        .SRC_H(SRC_H), .SRC_W(SRC_W),
        .DST_H(DST_H), .DST_W(DST_W), .N(N)
    ) dut (
        .clk(clk), .rst(rst), .start(start), .done(done),
        .wr_en(wr_en), .wr_addr(wr_addr), .wr_data(wr_data),
        .scale_factor(scale_factor),
        // .image_out(image_out),  // ELIMINADO: Puerto removido del Top
        .dbg_data(),
        .perf_flops(perf_flops),
        .perf_mem_reads(perf_mem_reads),
        .perf_mem_writes(perf_mem_writes)
    );

    // ==================================================
    // Reloj
    // ==================================================
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // ==================================================
    // Mostrar parámetros del diseño
    // ==================================================
    initial begin
        #1;
        $display("\n=== PARÁMETROS DEL DISEÑO (SIMD N=%0d) ===", N);
        $display("SRC_H = %0d, SRC_W = %0d", SRC_H, SRC_W);
        $display("Scale Factor = %0d (Factor real = %.2f)", scale_factor, 0.50 + scale_factor * 0.05);
        $display("DST dinámico calculado en RTL según scale_factor");
        $display("================================\n");
    end

    // ==================================================
    // Monitorear primeros batches
    // ==================================================
    initial begin
        @(negedge rst);
        @(posedge start);
        
        // Monitorear primeros batches
        for (int watch = 0; watch < 5; watch++) begin
            @(posedge clk);
            if (dut.u_downscale.state == dut.u_downscale.S_CALC_COORDS) begin
                $display("\n--- BATCH base_idx=%0d ---", dut.u_downscale.base_idx);
                for (int k = 0; k < N; k++) begin
                    $display("  Lane %0d: idx=%0d → i_dst=%0d, j_dst=%0d (valid=%b)",
                             k,
                             dut.u_downscale.idx[k],
                             dut.u_downscale.i_dst[k],
                             dut.u_downscale.j_dst[k],
                             dut.u_downscale.valid_lane[k]);
                end
            end
        end
    end

    // ==================================================
    // Imagen 512x512
    // ==================================================
    reg [7:0] test_image [0:SRC_H-1][0:SRC_W-1];
    integer file, code, i, j;

    initial begin
        $display("\n=== TEST 512x512 con DEBUG ===\n");
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
        $display("[%0t] ✓ Archivo leído", $time);
        
        // DEBUG: Mostrar primeros valores leídos
        $display("\nPrimeros 8 píxeles del archivo:");
        for (j = 0; j < 8; j = j + 1)
            $display("  test_image[0][%0d] = %0d", j, test_image[0][j]);
    end
	 
			 // Agregar este bloque al testbench
		integer coord_log;

		initial begin
			 coord_log = $fopen("coordinate_trace.txt", "w");
			 
			 @(negedge rst);
			 @(posedge start);
			 
			 // Monitorear primeros 100 píxeles
			 for (int watch = 0; watch < 100; watch++) begin
				  @(posedge clk);
				  if (dut.u_downscale.state == dut.u_downscale.S_CALC_COORDS) begin
						$fwrite(coord_log, "\n=== BATCH base_idx=%0d ===\n", dut.u_downscale.base_idx);
						for (int k = 0; k < N; k++) begin
							 if (dut.u_downscale.valid_lane[k]) begin
								  $fwrite(coord_log, "Lane %0d: idx=%5d → DST[%3d,%3d] reads SRC x_l=%3d, y_l=%3d, x_h=%3d, y_h=%3d\n",
											 k,
											 dut.u_downscale.idx[k],
											 dut.u_downscale.i_dst[k],
											 dut.u_downscale.j_dst[k],
											 dut.u_downscale.x_l[k],
											 dut.u_downscale.y_l[k],
											 dut.u_downscale.x_h[k],
											 dut.u_downscale.y_h[k]);
							 end
						end
				  end
			 end
			 
			 $fclose(coord_log);
		end
		
					// Agregar este bloque al testbench para ver las coordenadas de lectura
			initial begin
				 @(negedge rst);
				 @(posedge start);
				 
				 // Esperar al primer batch que escribe [128,128]
				 forever begin
					  @(posedge clk);
					  if (dut.u_downscale.state == dut.u_downscale.S_CALC_COORDS) begin
							for (int k = 0; k < N; k++) begin
								 // Buscar cuando estamos calculando el píxel [128,128]
								 if (dut.u_downscale.i_dst[k] == 128 && dut.u_downscale.j_dst[k] == 128) begin
									  $display("\n🎯 ENCONTRADO PÍXEL DE SALIDA [128,128]:");
									  $display("  idx = %0d", dut.u_downscale.idx[k]);
									  $display("  i_dst = %0d, j_dst = %0d", dut.u_downscale.i_dst[k], dut.u_downscale.j_dst[k]);
									  $display("  x_src_fp = %0d (0x%h)", dut.u_downscale.x_src_fp[k], dut.u_downscale.x_src_fp[k]);
									  $display("  y_src_fp = %0d (0x%h)", dut.u_downscale.y_src_fp[k], dut.u_downscale.y_src_fp[k]);
									  $display("  x_l = %0d, y_l = %0d", dut.u_downscale.x_l[k], dut.u_downscale.y_l[k]);
									  $display("  x_h = %0d, y_h = %0d", dut.u_downscale.x_h[k], dut.u_downscale.y_h[k]);
									  $display("  Memoria entrada [%0d,%0d] = %0d", 
												  dut.u_downscale.y_l[k], 
												  dut.u_downscale.x_l[k],
												  dut.memory[dut.u_downscale.y_l[k] * 512 + dut.u_downscale.x_l[k]]);
									  $display("  ESPERADO: debería leer de [256,256] = %0d", 
												  dut.memory[256 * 512 + 256]);
								 end
								 
								 // También mostrar el píxel [0,128]
								 if (dut.u_downscale.i_dst[k] == 0 && dut.u_downscale.j_dst[k] == 128) begin
									  $display("\n🎯 ENCONTRADO PÍXEL DE SALIDA [0,128]:");
									  $display("  idx = %0d", dut.u_downscale.idx[k]);
									  $display("  i_dst = %0d, j_dst = %0d", dut.u_downscale.i_dst[k], dut.u_downscale.j_dst[k]);
									  $display("  x_src_fp = %0d (0x%h)", dut.u_downscale.x_src_fp[k], dut.u_downscale.x_src_fp[k]);
									  $display("  y_src_fp = %0d (0x%h)", dut.u_downscale.y_src_fp[k], dut.u_downscale.y_src_fp[k]);
									  $display("  x_l = %0d, y_l = %0d", dut.u_downscale.x_l[k], dut.u_downscale.y_l[k]);
									  $display("  x_h = %0d, y_h = %0d", dut.u_downscale.x_h[k], dut.u_downscale.y_h[k]);
									  $display("  Memoria entrada [%0d,%0d] = %0d", 
												  dut.u_downscale.y_l[k], 
												  dut.u_downscale.x_l[k],
												  dut.memory[dut.u_downscale.y_l[k] * 512 + dut.u_downscale.x_l[k]]);
									  $display("  ESPERADO: debería leer de [0,256] = %0d", 
												  dut.memory[0 * 512 + 256]);
								 end
							end
					  end
				 end
			end


    // ==================================================
    // Verificar memoria después de cargar
    // ==================================================
    task verify_memory_load;
        begin
            $display("\n[%0t] Verificando BRAM...", $time);

            // Acceder directamente a la memoria interna del DUT
            $display("  Primeros 8 valores en BRAM:");
            for (i = 0; i < 8; i = i + 1) begin
                $display("    memory[%0d] = %0d", i, dut.memory[i]);
            end

            // Verificar si hay 'x'
            if (dut.memory[0] === 8'bxxxxxxxx) begin
                $display("  ✗ ERROR: Memoria contiene valores indefinidos!");
            end else begin
                $display("  ✓ Memoria inicializada correctamente");
            end
        end
    endtask

    // ==================================================
    // Verificar imagen de entrada
    // ==================================================
    task verify_input_image;
        begin
            $display("\n=== VERIFICANDO IMAGEN DE ENTRADA ===");

            // Verificar esquinas y centro
            $display("Esquina superior izquierda [0,0] = %0d", dut.memory[0]);
            $display("Esquina superior derecha [0,511] = %0d", dut.memory[511]);
            $display("Centro [256,256] = %0d", dut.memory[256*512 + 256]);
            $display("Esquina inferior izquierda [511,0] = %0d", dut.memory[511*512]);
            $display("Esquina inferior derecha [511,511] = %0d", dut.memory[512*512-1]);

            // Verificar que no son todos iguales
            if (dut.memory[0] == dut.memory[511] &&
                dut.memory[0] == dut.memory[256*512 + 256]) begin
                $display("⚠ WARNING: Primeros valores son iguales, posible problema de carga");
            end else begin
                $display("✓ Valores diferentes en distintas posiciones");
            end
        end
    endtask

    // ==================================================
    // Cargar imagen con verificación
    // ==================================================
    task load_image;
        integer errors;
        begin
            $display("\n[%0t] Cargando imagen en BRAM...", $time);
            errors = 0;
            wr_en = 0;
            @(posedge clk);

            for (i = 0; i < SRC_H; i = i + 1) begin
                for (j = 0; j < SRC_W; j = j + 1) begin
                    wr_en = 1;
                    wr_addr = i * SRC_W + j;
                    wr_data = test_image[i][j];
                    
                    // Verificar que no estamos escribiendo 'x'
                    if (test_image[i][j] === 8'bxxxxxxxx) begin
                        $display("  ✗ WARNING: Escribiendo 'x' en [%0d,%0d]", i, j);
                        errors = errors + 1;
                        if (errors > 10) begin
                            $display("  ✗ Demasiados errores, abortando...");
                            $finish;
                        end
                    end
                    
                    @(posedge clk);
                    
                    // Progreso cada 10%
                    if ((i * SRC_W + j) % (SRC_H * SRC_W / 10) == 0) begin
                        $display("  Progreso: %0d%%", 
                                 ((i * SRC_W + j) * 100) / (SRC_H * SRC_W));
                    end
                end
            end

            wr_en = 0;
            @(posedge clk);
            $display("[%0t] ✓ Carga completada", $time);
            
            // Verificar que se escribió correctamente
            verify_memory_load();
        end
    endtask

    // ==================================================
    // Ejecutar downscale con monitoring
    // ==================================================
    task run_downscale;
        integer timeout;
        integer last_progress;
        begin
            $display("\n[%0t] Iniciando downscale...", $time);
            
            start = 1;
            @(posedge clk);
            start = 0;

            timeout = 0;
            last_progress = 0;
            
            while (!done && timeout < 10000000) begin
                @(posedge clk);
                timeout = timeout + 1;
                
                // Mostrar progreso cada 100k ciclos
                if (timeout % 100000 == 0) begin
                    $display("  Ciclos: %0d", timeout);
                end
            end

            if (!done) begin
                $display("[%0t] ✗ TIMEOUT después de %0d ciclos", $time, timeout);
                $finish;
            end

            $display("[%0t] ✓ Downscale completado en %0d ciclos", $time, timeout);
        end
    endtask
	 
	 

    // ==================================================
    // Verificar mapeo de píxeles
    // ==================================================
    task verify_pixel_mapping;
        integer errors;
        integer expected_i, expected_j;
        integer pix, ii, jj;
        begin
            $display("\n=== VERIFICACIÓN DE MAPEO DE PÍXELES ===");
            errors = 0;
            
            // Verificar primeros 20 píxeles
            $display("\n--- Primeros 20 píxeles ---");
            for (pix = 0; pix < 20; pix = pix + 1) begin
                expected_i = pix / DST_W;
                expected_j = pix % DST_W;
                $display("pix=%3d → esperado[%3d,%3d], valor=%3d",
                         pix, expected_i, expected_j, dut.output_memory_flat[expected_i * DST_W + expected_j]);
            end
            
            // Verificar píxeles clave
            $display("\n--- Píxeles clave ---");
            $display("[0,0]     = %3d", dut.output_memory_flat[0 * DST_W + 0]);
            $display("[0,128]   = %3d", dut.output_memory_flat[0 * DST_W + 128]);
            $display("[128,0]   = %3d", dut.output_memory_flat[128 * DST_W + 0]);
            $display("[128,128] = %3d", dut.output_memory_flat[128 * DST_W + 128]);
            $display("[255,255] = %3d", dut.output_memory_flat[255 * DST_W + 255]);
            
            // Verificar patrón repetido
            $display("\n--- Detección de repetición ---");
            if (dut.output_memory_flat[0 * DST_W + 0] == dut.output_memory_flat[0 * DST_W + 128] &&
                dut.output_memory_flat[0 * DST_W + 0] == dut.output_memory_flat[128 * DST_W + 0] &&
                dut.output_memory_flat[0 * DST_W + 0] == dut.output_memory_flat[128 * DST_W + 128]) begin
                $display("⚠ PATRÓN REPETIDO DETECTADO en esquinas de cuadrantes");
                errors = errors + 1;
            end
            
            // Comparar cuadrante 1 vs cuadrante 2
            for (ii = 0; ii < 10; ii = ii + 1) begin
                for (jj = 0; jj < 10; jj = jj + 1) begin
                    if (dut.output_memory_flat[ii * DST_W + jj] != dut.output_memory_flat[ii * DST_W + jj+128]) begin
                        // OK, son diferentes
                    end else begin
                        errors = errors + 1;
                        if (errors < 5) // Mostrar solo primeros errores
                            $display("Repetición: [%0d,%0d]==[%0d,%0d] = %0d", 
                                     ii, jj, ii, jj+128, dut.output_memory_flat[ii * DST_W + jj]);
                    end
                end
            end
            
            if (errors > 50)
                $display("\n⚠ PROBLEMA CRÍTICO: %0d píxeles repetidos detectados", errors);
            else if (errors > 0)
                $display("\n⚠ %0d píxeles repetidos (puede ser normal en bordes)", errors);
            else
                $display("\n✓ No se detectó patrón repetido");
        end
    endtask

    // ==================================================
    // Verificar salida
    // ==================================================
    task verify_output;
        integer undefined_count;
        integer zero_count;
        begin
            $display("\n[%0t] Verificando salida...", $time);
            
            undefined_count = 0;
            zero_count = 0;
            
            // Contar problemas
            for (i = 0; i < DST_H; i = i + 1) begin
                for (j = 0; j < DST_W; j = j + 1) begin
                    if (dut.output_memory_flat[i * DST_W + j] === 8'bxxxxxxxx)
                        undefined_count = undefined_count + 1;
                    if (dut.output_memory_flat[i * DST_W + j] == 8'd0)
                        zero_count = zero_count + 1;
                end
            end
            
            $display("  Total píxeles: %0d", DST_H * DST_W);
            $display("  Indefinidos (x): %0d", undefined_count);
            $display("  Ceros: %0d", zero_count);
            
            if (undefined_count > 0) begin
                $display("  ✗ ERROR: Hay valores indefinidos en la salida");
                $display("\nPrimeros píxeles indefinidos:");
                for (i = 0; i < DST_H && i < 5; i = i + 1) begin
                    for (j = 0; j < DST_W && j < 5; j = j + 1) begin
                        if (dut.output_memory_flat[i * DST_W + j] === 8'bxxxxxxxx)
                            $display("    [%0d,%0d] = x", i, j);
                    end
                end
            end else begin
                $display("  ✓ No hay valores indefinidos");
            end
        end
    endtask

    // ==================================================
    // Mostrar muestra de salida
    // ==================================================
    task display_sample;
        begin
            $display("\n=== MUESTRA DE SALIDA (primeras 8x16) ===");
            for (i = 0; i < 8; i = i + 1) begin
                $write("Row %3d: ", i);
                for (j = 0; j < 16; j = j + 1) begin
                    if (dut.output_memory_flat[i * DST_W + j] === 8'bxxxxxxxx)
                        $write("  x ");
                    else
                        $write("%3d ", dut.output_memory_flat[i * DST_W + j]);
                end
                $write("\n");
            end
            $display("==========================================\n");
        end
    endtask

    // ==================================================
    // Guardar imagen de salida a archivo
    // ==================================================
    task save_output_image;
        integer outfile;
        begin
            $display("\n[%0t] Guardando imagen de salida...", $time);
            
            outfile = $fopen("C:/Users/gabri/OneDrive/Desktop/PrograProyectoArqui/Arqui2-Proyecto/imagen_output.txt", "w");
            
            if (outfile == 0) begin
                $display("  ✗ ERROR: No se pudo crear imagen_output.txt");
                return;
            end
            
            // Escribir dimensiones como encabezado
            $fwrite(outfile, "%0d %0d\n", DST_H, DST_W);
            
            // Escribir todos los píxeles
            for (i = 0; i < DST_H; i = i + 1) begin
                for (j = 0; j < DST_W; j = j + 1) begin
                    $fwrite(outfile, "%0d", dut.output_memory_flat[i * DST_W + j]);
                    
                    // Espacio entre píxeles, salto de línea al final de fila
                    if (j < DST_W - 1)
                        $fwrite(outfile, " ");
                    else
                        $fwrite(outfile, "\n");
                end
                
                // Mostrar progreso cada 10%
                if (i % (DST_H / 10) == 0)
                    $display("  Progreso: %0d%%", (i * 100) / DST_H);
            end
            
            $fclose(outfile);
            $display("[%0t] ✓ Imagen guardada en imagen_output.txt", $time);
            $display("  Formato: %0d filas x %0d columnas", DST_H, DST_W);
        end
    endtask

    // ==================================================
    // Mostrar Performance Counters
    // ==================================================
    task display_performance_counters;
        real arithmetic_intensity;
        integer total_mem_accesses;
        begin
            $display("\n=== PERFORMANCE COUNTERS (SIMD) ===");
            $display("FLOPs (Operaciones aritméticas): %0d", perf_flops);
            $display("Lecturas de memoria:             %0d", perf_mem_reads);
            $display("Escrituras de memoria:           %0d", perf_mem_writes);

            total_mem_accesses = perf_mem_reads + perf_mem_writes;
            $display("Total accesos a memoria:         %0d", total_mem_accesses);

            if (total_mem_accesses > 0) begin
                arithmetic_intensity = real'(perf_flops) / real'(total_mem_accesses);
                $display("Intensidad aritmética (FLOPs/acceso): %.3f", arithmetic_intensity);
            end else begin
                $display("Intensidad aritmética: N/A (sin accesos a memoria)");
            end

            // Análisis adicional
            $display("\n--- Análisis ---");
            $display("Píxeles procesados:              %0d", perf_mem_writes);
            if (perf_mem_writes > 0) begin
                $display("Lecturas por píxel:              %.2f", real'(perf_mem_reads) / real'(perf_mem_writes));
                $display("FLOPs por píxel:                 %.2f", real'(perf_flops) / real'(perf_mem_writes));
            end
            $display("SIMD lanes:                      %0d", N);
            $display("================================\n");
        end
    endtask

    // ==================================================
    // Secuencia principal
    // ==================================================
    initial begin
        rst = 1;
        start = 0;
        wr_en = 0;
        wr_addr = 0;
        wr_data = 0;
        scale_factor = 4'd0;  // Default: 0.5 (256x256)

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
        display_performance_counters();

        save_output_image();

        $display("\n=== TEST COMPLETADO ===\n");
        $stop;
    end

    // ==================================================
    // Timeout global
    // ==================================================
    initial begin
        #(CLK_PERIOD * 20000000);
        $display("\n✗ TIMEOUT GLOBAL");
        $finish;
    end

endmodule
