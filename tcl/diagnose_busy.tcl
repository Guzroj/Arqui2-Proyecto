# ============================================================================
# diagnose_busy.tcl
# ============================================================================
# Script de diagnóstico para analizar por qué busy nunca termina
#
# Este script monitorea en tiempo real:
#   - Estado de busy/done
#   - Performance counters (cycles, reads, writes)
#   - Verifica si los contadores están aumentando
#   - Detecta si el sistema está bloqueado
#
# Uso:
#   source test_basic_jtag.tcl
#   source diagnose_busy.tcl
#   diagnose_busy_stuck
#   monitor_busy_status
#
# Autor: DSA Project Team
# Fecha: Diciembre 2025
# ============================================================================

source [file join [file dirname [info script]] test_basic_jtag.tcl]

# ============================================================================
# Función: Diagnóstico completo de sistema bloqueado
# ============================================================================
proc diagnose_busy_stuck {} {
    global DSA_BASE_ADDR
    global REG_STATUS REG_PERF_CYCLES REG_PERF_READS REG_PERF_WRITES
    global REG_IMG_WIDTH_IN REG_IMG_HEIGHT_IN REG_IMG_WIDTH_OUT REG_IMG_HEIGHT_OUT
    global REG_INPUT_BASE REG_OUTPUT_BASE

    puts "\n=========================================="
    puts "DIAGNÓSTICO: Sistema Bloqueado (busy=1)"
    puts "=========================================="

    # Leer estado actual
    set status [read_reg $DSA_BASE_ADDR $REG_STATUS]
    set busy [expr {($status >> 0) & 0x1}]
    set done [expr {($status >> 1) & 0x1}]
    set error [expr {($status >> 2) & 0x1}]

    puts "\n1. ESTADO ACTUAL:"
    puts "   STATUS: 0x[format %08X $status]"
    puts "   - busy:  $busy"
    puts "   - done:  $done"
    puts "   - error: $error"

    if {!$busy} {
        puts "\n⚠️  ADVERTENCIA: Sistema NO está en busy"
        puts "   Si esperabas que estuviera procesando, puede que:"
        puts "   - El start nunca se activó"
        puts "   - El procesamiento ya terminó"
        puts "   - El sistema nunca inició"
        return 0
    }

    puts "\n2. CONFIGURACIÓN ACTUAL:"
    set w_in [read_reg $DSA_BASE_ADDR $REG_IMG_WIDTH_IN]
    set h_in [read_reg $DSA_BASE_ADDR $REG_IMG_HEIGHT_IN]
    set w_out [read_reg $DSA_BASE_ADDR $REG_IMG_WIDTH_OUT]
    set h_out [read_reg $DSA_BASE_ADDR $REG_IMG_HEIGHT_OUT]
    set in_base [read_reg $DSA_BASE_ADDR $REG_INPUT_BASE]
    set out_base [read_reg $DSA_BASE_ADDR $REG_OUTPUT_BASE]

    puts "   Imagen entrada:  ${w_in} × ${h_in}"
    puts "   Imagen salida:   ${w_out} × ${h_out}"
    puts "   INPUT_BASE:      0x[format %08X $in_base]"
    puts "   OUTPUT_BASE:     0x[format %08X $out_base]"

    # Verificar direcciones
    if {$in_base != 0x00000000} {
        puts "\n⚠️  ADVERTENCIA: INPUT_BASE no es 0x00000000"
        puts "   Valor actual: 0x[format %08X $in_base]"
    }

    if {$out_base != 0x00040000} {
        puts "\n⚠️  ADVERTENCIA: OUTPUT_BASE no es 0x00040000"
        puts "   Valor actual: 0x[format %08X $out_base]"
    }

    puts "\n3. PERFORMANCE COUNTERS (Primera lectura):"
    set cycles1 [read_reg $DSA_BASE_ADDR $REG_PERF_CYCLES]
    set reads1 [read_reg $DSA_BASE_ADDR $REG_PERF_READS]
    set writes1 [read_reg $DSA_BASE_ADDR $REG_PERF_WRITES]

    puts "   PERF_CYCLES:  $cycles1"
    puts "   PERF_READS:   $reads1"
    puts "   PERF_WRITES:  $writes1"

    puts "\n4. ESPERANDO 1 SEGUNDO Y RELEYENDO..."
    after 1000

    set cycles2 [read_reg $DSA_BASE_ADDR $REG_PERF_CYCLES]
    set reads2 [read_reg $DSA_BASE_ADDR $REG_PERF_READS]
    set writes2 [read_reg $DSA_BASE_ADDR $REG_PERF_WRITES]

    puts "\n   PERF_CYCLES:  $cycles2  (incremento: [expr {$cycles2 - $cycles1}])"
    puts "   PERF_READS:   $reads2   (incremento: [expr {$reads2 - $reads1}])"
    puts "   PERF_WRITES:  $writes2  (incremento: [expr {$writes2 - $writes1}])"

    puts "\n5. ANÁLISIS:"
    
    set cycles_delta [expr {$cycles2 - $cycles1}]
    set reads_delta [expr {$reads2 - $reads1}]
    set writes_delta [expr {$writes2 - $writes1}]

    # Calcular tiempo esperado
    set total_pixels [expr {$w_out * $h_out}]
    set expected_cycles [expr {$total_pixels * 65}]
    set expected_reads [expr {$total_pixels * 4}]

    puts "   Total pixeles a procesar: $total_pixels"
    puts "   Ciclos esperados totales: ~$expected_cycles"
    puts "   Lecturas esperadas totales: ~$expected_reads"

    if {$cycles_delta == 0} {
        puts "\n❌ PROBLEMA CRÍTICO: PERF_CYCLES NO está incrementando"
        puts "   Esto significa que:"
        puts "   - El contador de ciclos no está funcionando, O"
        puts "   - El sistema está completamente bloqueado (ni siquiera el contador corre)"
        return -1
    } elseif {$cycles_delta < 1000} {
        puts "\n⚠️  ADVERTENCIA: PERF_CYCLES incrementa muy lento"
        puts "   Solo [expr {$cycles_delta}] ciclos en 1 segundo (~[expr {$cycles_delta / 1000.0}] kHz)"
        puts "   Esperado: ~50,000 ciclos/segundo (50 MHz)"
    } else {
        set freq_khz [expr {$cycles_delta / 1000.0}]
        puts "\n✓ PERF_CYCLES está incrementando normalmente"
        puts "   Frecuencia estimada: ~${freq_khz} kHz"
        
        if {$freq_khz < 48000 || $freq_khz > 52000} {
            puts "   ⚠️  ADVERTENCIA: Frecuencia fuera del rango esperado (50 MHz)"
        }
    }

    if {$reads_delta == 0 && $cycles_delta > 10000} {
        puts "\n❌ PROBLEMA CRÍTICO: PERF_READS NO está incrementando"
        puts "   PERF_CYCLES aumenta pero PERF_READS NO"
        puts "   Esto indica que:"
        puts "   - Las lecturas de memoria NO se están ejecutando"
        puts "   - El DSA_Memory_Adapter está bloqueado"
        puts "   - La FSM está esperando mem_rd_valid que nunca llega"
        puts "\n   DIAGNÓSTICO: FSM bloqueada en estado S_WAIT_*"
        return -2
    } elseif {$reads_delta > 0} {
        puts "\n✓ PERF_READS está incrementando"
        puts "   [expr {$reads_delta}] lecturas en 1 segundo"
        
        set reads_per_cycle [expr {double($reads_delta) / double($cycles_delta)}]
        if {$reads_per_cycle < 0.0001} {
            puts "   ⚠️  ADVERTENCIA: Muy pocas lecturas por ciclo"
            puts "   Ratio: 1 lectura cada [expr {int(1.0 / $reads_per_cycle)}] ciclos"
        }
    }

    if {$writes_delta == 0 && $reads_delta > 10} {
        puts "\n⚠️  ADVERTENCIA: PERF_WRITES NO está incrementando"
        puts "   PERF_READS aumenta pero PERF_WRITES NO"
        puts "   Esto indica que:"
        puts "   - Las lecturas funcionan pero las escrituras NO"
        puts "   - El procesamiento está leyendo pero nunca escribe resultados"
        puts "   - Puede estar bloqueado después de la interpolación"
    } elseif {$writes_delta > 0} {
        puts "\n✓ PERF_WRITES está incrementando"
        puts "   [expr {$writes_delta}] escrituras en 1 segundo"
        
        set ratio [expr {double($writes_delta) / double($reads_delta)}]
        puts "   Ratio lecturas/escrituras: [format %.2f $ratio]"
        puts "   (Esperado: ~0.25, porque hay 4 lecturas por escritura)"
    }

    # Calcular progreso estimado
    if {$reads_delta > 0} {
        set progress_percent [expr {($reads2 * 100.0) / $expected_reads}]
        if {$progress_percent > 100} {
            set progress_percent 100
        }
        
        set remaining_reads [expr {$expected_reads - $reads2}]
        set estimated_seconds [expr {$remaining_reads / double($reads_delta)}]
        
        puts "\n6. PROGRESO ESTIMADO:"
        puts "   Lecturas completadas: $reads2 / $expected_reads"
        puts "   Progreso: [format %.1f $progress_percent]%"
        puts "   Tiempo restante estimado: [format %.1f $estimated_seconds] segundos"
        
        if {$reads2 >= $expected_reads && $done == 0} {
            puts "\n❌ PROBLEMA: Todas las lecturas deberían estar completas"
            puts "   pero done NO se activó"
            puts "   Posible problema en la lógica de finalización"
        }
    }

    puts "\n=========================================="
    return 0
}

# ============================================================================
# Función: Monitorear estado de busy en tiempo real
# ============================================================================
proc monitor_busy_status {{interval_ms 500} {max_samples 20}} {
    global DSA_BASE_ADDR
    global REG_STATUS REG_PERF_CYCLES REG_PERF_READS REG_PERF_WRITES

    puts "\n=========================================="
    puts "MONITOREO EN TIEMPO REAL"
    puts "Intervalo: ${interval_ms}ms, Máximo: ${max_samples} muestras"
    puts "=========================================="
    puts ""
    puts [format "%-8s %-6s %-6s %-12s %-12s %-12s %-10s" "Tiempo" "busy" "done" "CYCLES" "READS" "WRITES" "ΔREADS"]
    puts [string repeat "-" 75]

    set prev_reads 0
    set sample_count 0

    while {$sample_count < $max_samples} {
        set status [read_reg $DSA_BASE_ADDR $REG_STATUS]
        set cycles [read_reg $DSA_BASE_ADDR $REG_PERF_CYCLES]
        set reads [read_reg $DSA_BASE_ADDR $REG_PERF_READS]
        set writes [read_reg $DSA_BASE_ADDR $REG_PERF_WRITES]

        set busy [expr {($status >> 0) & 0x1}]
        set done [expr {($status >> 1) & 0x1}]
        
        set reads_delta [expr {$reads - $prev_reads}]
        set prev_reads $reads

        set time_str [format "%.1fs" [expr {$sample_count * $interval_ms / 1000.0}]]
        puts [format "%-8s %-6s %-6s %-12d %-12d %-12d %-10d" \
                  $time_str $busy $done $cycles $reads $writes $reads_delta]

        if {$done} {
            puts "\n✓ done se activó - Procesamiento completado"
            break
        }

        if {!$busy} {
            puts "\n⚠️  busy se desactivó inesperadamente"
            break
        }

        incr sample_count
        after $interval_ms
    }

    puts ""
    puts "=========================================="
}

# ============================================================================
# Función: Verificar estado de memoria (primeros bytes)
# ============================================================================
proc verify_memory_state {} {
    global INPUT_MEM_BASE OUTPUT_MEM_BASE

    puts "\n=========================================="
    puts "VERIFICACIÓN DE MEMORIA"
    puts "=========================================="

    puts "\nPrimeros 32 bytes de INPUT_MEMORY (0x[format %08X $INPUT_MEM_BASE]):"
    set input_data [master_read_32 $::jtag_master $INPUT_MEM_BASE 8]
    for {set i 0} {$i < [llength $input_data]} {incr i} {
        set word [lindex $input_data $i]
        puts [format "  [%2d]: 0x%08X" $i $word]
    }

    puts "\nPrimeros 32 bytes de OUTPUT_MEMORY (0x[format %08X $OUTPUT_MEM_BASE]):"
    set output_data [master_read_32 $::jtag_master $OUTPUT_MEM_BASE 8]
    for {set i 0} {$i < [llength $output_data]} {incr i} {
        set word [lindex $output_data $i]
        puts [format "  [%2d]: 0x%08X" $i $word]
    }

    puts "\n=========================================="
}

# ============================================================================
# Función: Test rápido - Verificar si start funciona
# ============================================================================
proc test_start_signal {} {
    global DSA_BASE_ADDR
    global REG_CTRL REG_STATUS

    puts "\n=========================================="
    puts "TEST: Señal START"
    puts "=========================================="

    # Leer estado inicial
    set status_before [read_reg $DSA_BASE_ADDR $REG_STATUS]
    set busy_before [expr {($status_before >> 0) & 0x1}]
    
    puts "Estado ANTES de start:"
    puts "  busy = $busy_before"

    if {$busy_before} {
        puts "\n⚠️  ADVERTENCIA: Sistema YA está en busy"
        puts "   No se puede hacer start si ya está procesando"
        return -1
    }

    # Leer CTRL actual
    set ctrl [read_reg $DSA_BASE_ADDR $REG_CTRL]
    puts "  CTRL = 0x[format %08X $ctrl]"

    # Activar start
    puts "\nActivando start (bit 0)..."
    set ctrl [expr {$ctrl | 0x1}]
    write_reg $DSA_BASE_ADDR $REG_CTRL $ctrl

    # Esperar un poco
    after 50

    # Verificar que start se activó y luego se limpió
    set ctrl_after [read_reg $DSA_BASE_ADDR $REG_CTRL]
    set start_bit [expr {($ctrl_after >> 0) & 0x1}]

    puts "CTRL DESPUÉS de start: 0x[format %08X $ctrl_after]"
    puts "  start bit = $start_bit (debería ser 0 - auto-clear)"

    # Verificar que busy se activó
    set status_after [read_reg $DSA_BASE_ADDR $REG_STATUS]
    set busy_after [expr {($status_after >> 0) & 0x1}]
    set done_after [expr {($status_after >> 1) & 0x1}]

    puts "\nEstado DESPUÉS de start:"
    puts "  busy = $busy_after"
    puts "  done = $done_after"

    if {$busy_after} {
        puts "\n✓ start funcionó - busy se activó correctamente"
        return 0
    } else {
        puts "\n❌ PROBLEMA: start NO activó busy"
        puts "   Posibles causas:"
        puts "   - El pulso start fue muy corto y no se capturó"
        puts "   - Problema en la lógica de dsa_core_running"
        return -2
    }
}

# ============================================================================
# Función: Diagnóstico completo (todas las pruebas)
# ============================================================================
proc full_diagnosis {} {
    puts "\n"
    puts "════════════════════════════════════════════════════════════"
    puts "  DIAGNÓSTICO COMPLETO - Sistema DSA"
    puts "════════════════════════════════════════════════════════════"

    # Verificar conexión
    if {[connect_jtag] != 0} {
        return
    }

    # Test 1: Verificar estado inicial
    puts "\n[TEST 1/5] Estado inicial del sistema"
    read_dsa_registers

    # Test 2: Verificar memoria
    puts "\n[TEST 2/5] Estado de memoria"
    verify_memory_state

    # Test 3: Test de señal start
    puts "\n[TEST 3/5] Test de señal START"
    test_start_signal

    # Test 4: Diagnóstico de busy bloqueado
    puts "\n[TEST 4/5] Diagnóstico de sistema bloqueado"
    diagnose_busy_stuck

    # Test 5: Monitoreo en tiempo real
    puts "\n[TEST 5/5] Monitoreo en tiempo real (10 segundos)"
    monitor_busy_status 500 20

    puts "\n"
    puts "════════════════════════════════════════════════════════════"
    puts "  DIAGNÓSTICO COMPLETADO"
    puts "════════════════════════════════════════════════════════════"
}

# ============================================================================
# Mensajes de ayuda
# ============================================================================
puts "\n=============================================="
puts "DSA Downscaler - Diagnóstico de Sistema"
puts "=============================================="
puts "Comandos disponibles:"
puts "  full_diagnosis            - Ejecutar todos los diagnósticos"
puts "  diagnose_busy_stuck       - Diagnosticar por qué busy no termina"
puts "  monitor_busy_status       - Monitorear busy en tiempo real"
puts "  verify_memory_state       - Verificar estado de memoria"
puts "  test_start_signal         - Verificar que start funciona"
puts "\nEjemplo rápido:"
puts "  diagnose_busy_stuck"
puts "=============================================="

