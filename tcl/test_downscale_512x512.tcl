# ============================================================================
# test_downscale_512x512.tcl
# ============================================================================
# Script para probar downscaling de imagen real 512×512
#
# Este script realiza un test completo:
#   1. Carga imagen_grayscale.txt (512×512)
#   2. Configura DSA para downscale a dimensión especificada
#   3. Ejecuta procesamiento (Secuencial o SIMD)
#   4. Mide performance
#   5. Guarda resultado
#
# Uso:
#   source test_downscale_512x512.tcl
#   test_512x512_to_256x256_simd
#   test_512x512_to_256x256_seq
#
# Autor: DSA Project Team
# Fecha: Diciembre 2025
# ============================================================================

source [file join [file dirname [info script]] test_basic_jtag.tcl]
source [file join [file dirname [info script]] load_image_txt.tcl]
source [file join [file dirname [info script]] test_downscale_simple.tcl]

# ============================================================================
# TEST: 512×512 → 256×256 (Modo SIMD)
# ============================================================================
proc test_512x512_to_256x256_simd {} {
    puts "\n=========================================="
    puts "TEST: Downscale 512×512 → 256×256 (SIMD)"
    puts "=========================================="

    # Conectar
    if {[connect_jtag] != 0} {
        return
    }

    # Cargar imagen de entrada
    if {[load_image_from_txt "../imagen_grayscale.txt" 512 512] != 0} {
        puts "ERROR: No se pudo cargar la imagen"
        return
    }

    # Verificar primeros píxeles
    verify_loaded_image 512 512 32

    # Configurar DSA (modo SIMD = 1)
    configure_dsa 512 512 256 256 1

    # Leer configuración
    read_dsa_registers

    # Iniciar procesamiento
    start_processing

    # Esperar finalización (timeout 30 segundos)
    puts "\nEsperando finalización del procesamiento..."
    set start_time [clock milliseconds]

    if {[wait_for_completion 30000] != 0} {
        puts "\nTest FALLÓ ✗"
        return
    }

    set elapsed [expr {[clock milliseconds] - $start_time}]

    # Leer performance counters
    puts "\n=========================================="
    puts "Resultados de Performance"
    puts "=========================================="

    read_dsa_registers

    global DSA_BASE_ADDR
    set cycles [read_reg $DSA_BASE_ADDR 0x20]
    set reads [read_reg $DSA_BASE_ADDR 0x24]
    set writes [read_reg $DSA_BASE_ADDR 0x28]
    set flops [read_reg $DSA_BASE_ADDR 0x2C]

    set freq_mhz 50.0
    set time_ms [expr {$cycles / ($freq_mhz * 1000.0)}]
    set throughput_mpix_s [expr {65536.0 / $time_ms}]

    puts "\nMétricas Calculadas:"
    puts "  Tiempo real:      ${elapsed} ms"
    puts "  Tiempo (ciclos):  [format %.2f $time_ms] ms"
    puts "  Throughput:       [format %.2f $throughput_mpix_s] MPix/s"
    puts "  FLOPs totales:    $flops"
    puts "  GFLOPS:           [format %.2f [expr {$flops / ($time_ms * 1000.0)}]]"

    # Guardar imagen de salida
    save_output_image "../imagen_output_256x256_simd.txt" 256 256

    puts "\n=========================================="
    puts "Test completado exitosamente ✓"
    puts "=========================================="
}

# ============================================================================
# TEST: 512×512 → 256×256 (Modo Secuencial)
# ============================================================================
proc test_512x512_to_256x256_seq {} {
    puts "\n=========================================="
    puts "TEST: Downscale 512×512 → 256×256 (Secuencial)"
    puts "=========================================="

    # Conectar
    if {[connect_jtag] != 0} {
        return
    }

    # Cargar imagen de entrada
    if {[load_image_from_txt "../imagen_grayscale.txt" 512 512] != 0} {
        puts "ERROR: No se pudo cargar la imagen"
        return
    }

    # Verificar primeros píxeles
    verify_loaded_image 512 512 32

    # Configurar DSA (modo Secuencial = 0)
    configure_dsa 512 512 256 256 0

    # Leer configuración
    read_dsa_registers

    # Iniciar procesamiento
    start_processing

    # Esperar finalización (timeout 60 segundos para modo secuencial)
    puts "\nEsperando finalización del procesamiento..."
    set start_time [clock milliseconds]

    if {[wait_for_completion 60000] != 0} {
        puts "\nTest FALLÓ ✗"
        return
    }

    set elapsed [expr {[clock milliseconds] - $start_time}]

    # Leer performance counters
    puts "\n=========================================="
    puts "Resultados de Performance"
    puts "=========================================="

    read_dsa_registers

    global DSA_BASE_ADDR
    set cycles [read_reg $DSA_BASE_ADDR 0x20]
    set reads [read_reg $DSA_BASE_ADDR 0x24]
    set writes [read_reg $DSA_BASE_ADDR 0x28]
    set flops [read_reg $DSA_BASE_ADDR 0x2C]

    set freq_mhz 50.0
    set time_ms [expr {$cycles / ($freq_mhz * 1000.0)}]
    set throughput_mpix_s [expr {65536.0 / $time_ms}]

    puts "\nMétricas Calculadas:"
    puts "  Tiempo real:      ${elapsed} ms"
    puts "  Tiempo (ciclos):  [format %.2f $time_ms] ms"
    puts "  Throughput:       [format %.2f $throughput_mpix_s] MPix/s"
    puts "  FLOPs totales:    $flops"
    puts "  GFLOPS:           [format %.2f [expr {$flops / ($time_ms * 1000.0)}]]"

    # Guardar imagen de salida
    save_output_image "../imagen_output_256x256_seq.txt" 256 256

    puts "\n=========================================="
    puts "Test completado exitosamente ✓"
    puts "=========================================="
}

# ============================================================================
# TEST: Comparación SIMD vs Secuencial
# ============================================================================
proc test_simd_vs_seq {} {
    puts "\n=========================================="
    puts "TEST: SIMD vs Secuencial"
    puts "=========================================="

    # Test Secuencial
    puts "\n>>> Ejecutando modo SECUENCIAL..."
    test_512x512_to_256x256_seq

    # Esperar un poco
    after 1000

    # Test SIMD
    puts "\n>>> Ejecutando modo SIMD..."
    test_512x512_to_256x256_simd

    puts "\n=========================================="
    puts "Comparación completada"
    puts "=========================================="
    puts "Archivos generados:"
    puts "  - imagen_output_256x256_seq.txt"
    puts "  - imagen_output_256x256_simd.txt"
    puts "\nPuedes comparar los resultados con Python"
}

# ============================================================================
# TEST: Diferentes factores de escala
# ============================================================================
proc test_multiple_scales {} {
    puts "\n=========================================="
    puts "TEST: Múltiples factores de escala"
    puts "=========================================="

    # Conectar
    if {[connect_jtag] != 0} {
        return
    }

    # Cargar imagen una vez
    if {[load_image_from_txt "../imagen_grayscale.txt" 512 512] != 0} {
        puts "ERROR: No se pudo cargar la imagen"
        return
    }

    # Escalas a probar: 0.5, 0.6, 0.7, 0.8, 0.9, 1.0
    set scales {
        {256 256 0.5}
        {307 307 0.6}
        {358 358 0.7}
        {410 410 0.8}
        {461 461 0.9}
        {512 512 1.0}
    }

    foreach scale_info $scales {
        lassign $scale_info w_out h_out factor

        puts "\n>>> Test: 512×512 → ${w_out}×${h_out} (factor $factor)"

        # Configurar DSA (modo SIMD)
        configure_dsa 512 512 $w_out $h_out 1

        # Iniciar
        start_processing

        # Esperar
        if {[wait_for_completion 30000] == 0} {
            # Leer performance
            global DSA_BASE_ADDR
            set cycles [read_reg $DSA_BASE_ADDR 0x20]
            set time_ms [expr {$cycles / 50000.0}]

            puts "  Ciclos: $cycles"
            puts "  Tiempo: [format %.2f $time_ms] ms"

            # Guardar
            set filename "../imagen_output_${w_out}x${h_out}.txt"
            save_output_image $filename $w_out $h_out
        } else {
            puts "  ERROR: Timeout"
        }

        after 500
    }

    puts "\n=========================================="
    puts "Tests de múltiples escalas completados"
    puts "=========================================="
}

# ============================================================================
# Mensajes de ayuda
# ============================================================================
puts "\n=============================================="
puts "DSA Downscaler - Tests con Imagen Real 512×512"
puts "=============================================="
puts "Comandos disponibles:"
puts "  test_512x512_to_256x256_simd   - Test SIMD 512→256"
puts "  test_512x512_to_256x256_seq    - Test Secuencial 512→256"
puts "  test_simd_vs_seq               - Comparar SIMD vs Sec"
puts "  test_multiple_scales           - Múltiples factores"
puts "\nEjemplo rápido:"
puts "  test_512x512_to_256x256_simd"
puts "=============================================="
