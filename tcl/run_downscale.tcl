# ==============================================================================
# run_downscale.tcl
# ==============================================================================
# Script para configurar y ejecutar el procesamiento de downscale
# Soporta modo Secuencial y SIMD
# ==============================================================================

# ==============================================================================
# CONFIGURACIÓN DE DIRECCIONES
# ==============================================================================
set DSA_BASE     0x05000000
set SDRAM_BASE   0x00000000

# Offsets de registros
set REG_CTRL           0x00
set REG_STATUS         0x04
set REG_IMG_WIDTH_IN   0x08
set REG_IMG_HEIGHT_IN  0x0C
set REG_IMG_WIDTH_OUT  0x10
set REG_IMG_HEIGHT_OUT 0x14
set REG_INPUT_BASE     0x18
set REG_OUTPUT_BASE    0x1C
set REG_PERF_CYCLES    0x20
set REG_PERF_READS     0x24
set REG_PERF_WRITES    0x28
set REG_PERF_FLOPS     0x2C

# ==============================================================================
# FUNCIÓN PRINCIPAL: run_downscale
# ==============================================================================
# Parámetros:
#   width_in, height_in:   dimensiones de entrada
#   width_out, height_out: dimensiones de salida
#   mode:                  0=Secuencial, 1=SIMD (default: 0)
#   input_addr:            dirección base entrada (default: 0x00000000)
#   output_addr:           dirección base salida (default: calculada automáticamente)
# ==============================================================================
proc run_downscale {width_in height_in width_out height_out {mode 0} {input_addr 0x00000000} {output_addr -1}} {
    global jtag DSA_BASE
    global REG_CTRL REG_STATUS REG_IMG_WIDTH_IN REG_IMG_HEIGHT_IN
    global REG_IMG_WIDTH_OUT REG_IMG_HEIGHT_OUT REG_INPUT_BASE REG_OUTPUT_BASE
    global REG_PERF_CYCLES REG_PERF_READS REG_PERF_WRITES REG_PERF_FLOPS
    
    puts "\n=========================================="
    puts "  EJECUTANDO DOWNSCALE"
    puts "==========================================\n"
    
    # ==============================================================================
    # 1. VERIFICAR CONEXIÓN JTAG
    # ==============================================================================
    if {![info exists jtag]} {
        puts "ERROR: Variable 'jtag' no está definida"
        puts "Primero ejecuta: source test_dsa_basic.tcl"
        return -1
    }
    
    # ==============================================================================
    # 2. VALIDAR PARÁMETROS
    # ==============================================================================
    puts "1. Validando parámetros..."
    
    if {$width_out > $width_in || $height_out > $height_in} {
        puts "   ✗ ERROR: Dimensiones de salida mayores que entrada"
        puts "     Input:  $width_in × $height_in"
        puts "     Output: $width_out × $height_out"
        return -1
    }
    
    if {$width_in <= 0 || $height_in <= 0 || $width_out <= 0 || $height_out <= 0} {
        puts "   ✗ ERROR: Dimensiones deben ser > 0"
        return -1
    }
    
    if {$mode != 0 && $mode != 1} {
        puts "   ✗ ERROR: Modo debe ser 0 (Secuencial) o 1 (SIMD)"
        return -1
    }
    
    # Calcular dirección de salida si no se especificó
    if {$output_addr == -1} {
        set input_size [expr {$width_in * $height_in}]
        # Alinear a 4 bytes
        set output_addr [expr {$input_addr + (($input_size + 3) & ~3)}]
    }
    
    set mode_str [expr {$mode == 0 ? "Secuencial" : "SIMD"}]
    
    puts "   Input:  $width_in × $height_in"
    puts "   Output: $width_out × $height_out"
    puts "   Modo:   $mode_str"
    puts "   Input addr:  0x[format %08X $input_addr]"
    puts "   Output addr: 0x[format %08X $output_addr]"
    puts "   ✓ Parámetros válidos\n"
    
    # ==============================================================================
    # 3. VERIFICAR QUE DSA ESTÁ IDLE
    # ==============================================================================
    puts "2. Verificando estado del DSA..."
    
    set status [master_read_32 $jtag [expr {$DSA_BASE + $REG_STATUS}] 1]
    set busy [expr {$status & 0x01}]
    
    if {$busy} {
        puts "   ⚠ ADVERTENCIA: DSA está ocupado (busy=1)"
        puts "   Esperando a que termine..."
        
        set timeout 0
        while {$busy && $timeout < 100} {
            after 100
            set status [master_read_32 $jtag [expr {$DSA_BASE + $REG_STATUS}] 1]
            set busy [expr {$status & 0x01}]
            incr timeout
        }
        
        if {$busy} {
            puts "   ✗ ERROR: Timeout esperando a que DSA termine"
            return -1
        }
    }
    
    puts "   ✓ DSA está idle (listo)\n"
    
    # ==============================================================================
    # 4. RESETEAR PERFORMANCE COUNTERS
    # ==============================================================================
    puts "3. Reseteando performance counters..."
    
    # Escribir bit reset_counters (bit 1)
    master_write_32 $jtag [expr {$DSA_BASE + $REG_CTRL}] 0x00000002
    after 10
    
    puts "   ✓ Counters reseteados\n"
    
    # ==============================================================================
    # 5. CONFIGURAR DIMENSIONES Y DIRECCIONES
    # ==============================================================================
    puts "4. Configurando registros..."
    
    master_write_32 $jtag [expr {$DSA_BASE + $REG_IMG_WIDTH_IN}]   $width_in
    master_write_32 $jtag [expr {$DSA_BASE + $REG_IMG_HEIGHT_IN}]  $height_in
    master_write_32 $jtag [expr {$DSA_BASE + $REG_IMG_WIDTH_OUT}]  $width_out
    master_write_32 $jtag [expr {$DSA_BASE + $REG_IMG_HEIGHT_OUT}] $height_out
    master_write_32 $jtag [expr {$DSA_BASE + $REG_INPUT_BASE}]     $input_addr
    master_write_32 $jtag [expr {$DSA_BASE + $REG_OUTPUT_BASE}]    $output_addr
    
    puts "   ✓ Registros configurados\n"
    
    # ==============================================================================
    # 6. INICIAR PROCESAMIENTO
    # ==============================================================================
    puts "5. Iniciando procesamiento..."
    puts "   Modo: $mode_str"
    
    # Escribir bit start (bit 0) + bit mode (bit 2)
    set ctrl_value [expr {0x01 | ($mode << 2)}]
    
    # Guardar timestamp de inicio
    set start_time [clock milliseconds]
    
    master_write_32 $jtag [expr {$DSA_BASE + $REG_CTRL}] $ctrl_value
    
    puts "   ✓ Comando START enviado\n"
    
    # ==============================================================================
    # 7. MONITOREAR PROGRESO
    # ==============================================================================
    puts "6. Monitoreando progreso..."
    puts "   (Esperando señal DONE...)\n"
    
    set done 0
    set timeout 0
    set max_timeout 1000  ;# 100 segundos
    
    while {!$done && $timeout < $max_timeout} {
        after 100
        
        set status [master_read_32 $jtag [expr {$DSA_BASE + $REG_STATUS}] 1]
        set busy  [expr {$status & 0x01}]
        set done  [expr {($status >> 1) & 0x01}]
        set error [expr {($status >> 2) & 0x01}]
        
        incr timeout
        
        # Mostrar progreso cada segundo
        if {$timeout % 10 == 0} {
            set elapsed [expr {$timeout / 10}]
            puts "   \[$elapsed s\] Busy=$busy, Done=$done"
        }
        
        if {$error} {
            puts "   ✗ ERROR: DSA reportó error (bit error=1)"
            return -1
        }
        
        if {$done} {
            break
        }
    }
    
    if {!$done} {
        puts "   ✗ ERROR: Timeout esperando DONE"
        puts "     Tiempo transcurrido: [expr {$timeout / 10}] segundos"
        return -1
    }
    
    set end_time [clock milliseconds]
    set elapsed_ms [expr {$end_time - $start_time}]
    
    puts "\n   ✓ Procesamiento completado"
    puts "   Tiempo real: $elapsed_ms ms\n"
    
    # ==============================================================================
    # 8. LEER PERFORMANCE COUNTERS
    # ==============================================================================
    puts "7. Leyendo performance counters...\n"
    
    set perf_cycles [master_read_32 $jtag [expr {$DSA_BASE + $REG_PERF_CYCLES}] 1]
    set perf_reads  [master_read_32 $jtag [expr {$DSA_BASE + $REG_PERF_READS}] 1]
    set perf_writes [master_read_32 $jtag [expr {$DSA_BASE + $REG_PERF_WRITES}] 1]
    set perf_flops  [master_read_32 $jtag [expr {$DSA_BASE + $REG_PERF_FLOPS}] 1]
    
    # Calcular métricas
    set clock_freq 50000000.0  ;# 50 MHz
    set time_seconds [expr {$perf_cycles / $clock_freq}]
    set time_ms [expr {$time_seconds * 1000}]
    
    set output_pixels [expr {$width_out * $height_out}]
    set throughput [expr {$output_pixels / $time_seconds}]
    
    puts "=========================================="
    puts "  RESULTADOS"
    puts "==========================================\n"
    
    puts "Performance Counters:"
    puts "  Ciclos de reloj:  $perf_cycles"
    puts "  Lecturas memoria: $perf_reads"
    puts "  Escrituras mem:   $perf_writes"
    puts "  Operaciones FP:   $perf_flops"
    
    puts "\nTiempos:"
    puts "  Ciclos @ 50MHz:   [format "%.2f" $time_ms] ms"
    puts "  Tiempo real:      $elapsed_ms ms"
    
    puts "\nThroughput:"
    puts "  Píxeles salida:   $output_pixels"
    puts "  Píxeles/segundo:  [format "%.0f" $throughput]"
    puts "  Ciclos/píxel:     [format "%.1f" [expr {double($perf_cycles) / $output_pixels}]]"
    
    # Comparar secuencial vs SIMD
    if {$mode == 1} {
        set theoretical_speedup 4.0
        puts "\nModo SIMD (N=4):"
        puts "  Speedup teórico:  ${theoretical_speedup}×"
    } else {
        puts "\nModo Secuencial:"
        puts "  1 píxel por ciclo (teórico)"
    }
    
    puts "\nImagen de salida:"
    puts "  Dirección: 0x[format %08X $output_addr]"
    puts "  Tamaño:    $output_pixels bytes"
    puts "  Rango:     0x[format %08X $output_addr] - 0x[format %08X [expr {$output_addr + $output_pixels - 1}]]"
    
    puts "\nSiguiente paso:"
    puts "  source read_result.tcl"
    puts "  read_result_from_sdram \"output.txt\" $width_out $height_out $output_addr"
    
    puts "\n==========================================\n"
    
    return 0
}

# ==============================================================================
# FUNCIONES AUXILIARES: Casos comunes
# ==============================================================================
proc downscale_512_to_256_seq {} {
    run_downscale 512 512 256 256 0
}

proc downscale_512_to_256_simd {} {
    run_downscale 512 512 256 256 1
}

proc downscale_256_to_128_seq {} {
    run_downscale 256 256 128 128 0
}

proc downscale_256_to_128_simd {} {
    run_downscale 256 256 128 128 1
}

# ==============================================================================
# INSTRUCCIONES DE USO
# ==============================================================================
puts "\n=========================================="
puts "  run_downscale.tcl cargado"
puts "==========================================\n"
puts "Funciones disponibles:"
puts "  run_downscale <w_in> <h_in> <w_out> <h_out> \[mode\] \[in_addr\] \[out_addr\]"
puts "    mode: 0=Secuencial (default), 1=SIMD"
puts "\nAtajos:"
puts "  downscale_512_to_256_seq"
puts "  downscale_512_to_256_simd"
puts "  downscale_256_to_128_seq"
puts "  downscale_256_to_128_simd"
puts "\nEjemplo:"
puts "  run_downscale 512 512 256 256 0      ;# Secuencial"
puts "  run_downscale 512 512 256 256 1      ;# SIMD"
puts "  downscale_512_to_256_simd            ;# Atajo"
puts "==========================================\n"


