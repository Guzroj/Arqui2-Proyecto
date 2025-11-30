# ==============================================================================
# full_test.tcl
# ==============================================================================
# Script completo para test automatizado del DSA
# Carga imagen, ejecuta downscale, lee resultado y compara
# ==============================================================================

# Cargar scripts auxiliares
puts "Cargando scripts..."
source test_dsa_basic.tcl
source load_image.tcl
source run_downscale.tcl
source read_result.tcl

# ==============================================================================
# FUNCIÓN PRINCIPAL: Test completo
# ==============================================================================
proc full_test {input_file width_in height_in width_out height_out {mode 0} {expected_file ""}} {
    puts "\n=========================================="
    puts "  TEST COMPLETO DEL DSA"
    puts "==========================================\n"
    
    puts "Configuración:"
    puts "  Input:  $input_file ($width_in × $height_in)"
    puts "  Output: $width_out × $height_out"
    puts "  Modo:   [expr {$mode == 0 ? "Secuencial" : "SIMD"}]"
    if {$expected_file != ""} {
        puts "  Esperado: $expected_file"
    }
    puts ""
    
    # ==============================================================================
    # 1. CARGAR IMAGEN
    # ==============================================================================
    puts "=========================================="
    puts "  PASO 1/4: Cargando imagen..."
    puts "==========================================\n"
    
    if {[load_image_to_sdram $input_file $width_in $height_in 0x00000000] != 0} {
        puts "ERROR: Fallo al cargar imagen"
        return -1
    }
    
    # ==============================================================================
    # 2. EJECUTAR DOWNSCALE
    # ==============================================================================
    puts "\n=========================================="
    puts "  PASO 2/4: Ejecutando downscale..."
    puts "==========================================\n"
    
    set output_addr 0x00100000  ;# Dirección después de la imagen de entrada
    
    if {[run_downscale $width_in $height_in $width_out $height_out $mode 0x00000000 $output_addr] != 0} {
        puts "ERROR: Fallo al ejecutar downscale"
        return -1
    }
    
    # ==============================================================================
    # 3. LEER RESULTADO
    # ==============================================================================
    puts "\n=========================================="
    puts "  PASO 3/4: Leyendo resultado..."
    puts "==========================================\n"
    
    set output_file "result_${width_out}x${height_out}_mode${mode}.txt"
    
    if {[read_result_from_sdram $output_file $width_out $height_out $output_addr] != 0} {
        puts "ERROR: Fallo al leer resultado"
        return -1
    }
    
    # ==============================================================================
    # 4. COMPARAR CON ESPERADO (opcional)
    # ==============================================================================
    if {$expected_file != ""} {
        puts "\n=========================================="
        puts "  PASO 4/4: Comparando con esperado..."
        puts "==========================================\n"
        
        compare_images $expected_file $output_file
    }
    
    # ==============================================================================
    # RESUMEN FINAL
    # ==============================================================================
    puts "\n=========================================="
    puts "  TEST COMPLETADO"
    puts "==========================================\n"
    
    puts "Archivos generados:"
    puts "  $output_file"
    
    puts "\n✓ Test finalizado exitosamente\n"
    
    return 0
}

# ==============================================================================
# TESTS PREDEFINIDOS
# ==============================================================================
proc test_512_to_256_sequential {input_file {expected ""}} {
    full_test $input_file 512 512 256 256 0 $expected
}

proc test_512_to_256_simd {input_file {expected ""}} {
    full_test $input_file 512 512 256 256 1 $expected
}

proc test_256_to_128_sequential {input_file {expected ""}} {
    full_test $input_file 256 256 128 128 0 $expected
}

proc test_256_to_128_simd {input_file {expected ""}} {
    full_test $input_file 256 256 128 128 1 $expected
}

# ==============================================================================
# BENCHMARK: Comparar Secuencial vs SIMD
# ==============================================================================
proc benchmark_seq_vs_simd {input_file width_in height_in width_out height_out} {
    global DSA_BASE REG_PERF_CYCLES jtag
    
    puts "\n=========================================="
    puts "  BENCHMARK: Secuencial vs SIMD"
    puts "==========================================\n"
    
    puts "Configuración:"
    puts "  Input:  $width_in × $height_in"
    puts "  Output: $width_out × $height_out\n"
    
    # ==============================================================================
    # Test Secuencial
    # ==============================================================================
    puts "=========================================="
    puts "  MODO SECUENCIAL"
    puts "==========================================\n"
    
    load_image_to_sdram $input_file $width_in $height_in 0x00000000
    run_downscale $width_in $height_in $width_out $height_out 0
    
    set cycles_seq [master_read_32 $jtag [expr {$DSA_BASE + $REG_PERF_CYCLES}] 1]
    set time_seq_ms [expr {($cycles_seq / 50000000.0) * 1000}]
    
    # ==============================================================================
    # Test SIMD
    # ==============================================================================
    puts "\n=========================================="
    puts "  MODO SIMD"
    puts "==========================================\n"
    
    load_image_to_sdram $input_file $width_in $height_in 0x00000000
    run_downscale $width_in $height_in $width_out $height_out 1
    
    set cycles_simd [master_read_32 $jtag [expr {$DSA_BASE + $REG_PERF_CYCLES}] 1]
    set time_simd_ms [expr {($cycles_simd / 50000000.0) * 1000}]
    
    # ==============================================================================
    # Comparar
    # ==============================================================================
    puts "\n=========================================="
    puts "  COMPARACIÓN"
    puts "==========================================\n"
    
    set speedup [expr {double($cycles_seq) / $cycles_simd}]
    
    puts "Modo Secuencial:"
    puts "  Ciclos: $cycles_seq"
    puts "  Tiempo: [format "%.2f" $time_seq_ms] ms\n"
    
    puts "Modo SIMD (N=4):"
    puts "  Ciclos: $cycles_simd"
    puts "  Tiempo: [format "%.2f" $time_simd_ms] ms\n"
    
    puts "Speedup: [format "%.2f" $speedup]×"
    
    if {$speedup >= 3.5} {
        puts "✓ Excelente speedup (cercano a 4×)"
    } elseif {$speedup >= 2.0} {
        puts "✓ Buen speedup"
    } elseif {$speedup >= 1.5} {
        puts "⚠ Speedup moderado"
    } else {
        puts "⚠ Speedup bajo (verificar implementación)"
    }
    
    puts "\n==========================================\n"
}

# ==============================================================================
# INSTRUCCIONES DE USO
# ==============================================================================
puts "\n=========================================="
puts "  full_test.tcl cargado"
puts "==========================================\n"
puts "Funciones disponibles:"
puts "  full_test <input> <w_in> <h_in> <w_out> <h_out> \[mode\] \[expected\]"
puts "\nTests predefinidos:"
puts "  test_512_to_256_sequential <input> \[expected\]"
puts "  test_512_to_256_simd <input> \[expected\]"
puts "  test_256_to_128_sequential <input> \[expected\]"
puts "  test_256_to_128_simd <input> \[expected\]"
puts "\nBenchmark:"
puts "  benchmark_seq_vs_simd <input> <w_in> <h_in> <w_out> <h_out>"
puts "\nEjemplo:"
puts "  test_512_to_256_sequential \"input.txt\""
puts "  test_512_to_256_simd \"input.txt\" \"expected.txt\""
puts "  benchmark_seq_vs_simd \"input.txt\" 512 512 256 256"
puts "==========================================\n"


