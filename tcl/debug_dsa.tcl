# ==============================================================================
# debug_dsa.tcl
# ==============================================================================
# Script para debugging del DSA - lee registros y contadores en tiempo real
# ==============================================================================

set DSA_BASE          0x05000000
set INPUT_MEMORY_BASE 0x00000000
set OUTPUT_MEMORY_BASE 0x00040000

# Offsets de registros (deben coincidir con DSA_Control_Registers.sv)
set REG_CTRL           0x00
set REG_STATUS         0x04
set REG_IMG_WIDTH_IN   0x08
set REG_IMG_HEIGHT_IN  0x0C
set REG_SCALE_FACTOR   0x10
set REG_INPUT_BASE     0x18
set REG_OUTPUT_BASE    0x1C
set REG_PERF_CYCLES    0x20
set REG_PERF_READS     0x24
set REG_PERF_WRITES    0x28
set REG_PERF_FLOPS     0x2C

# ==============================================================================
# FUNCIÓN: Leer y decodificar STATUS
# ==============================================================================
proc read_status {} {
    global jtag DSA_BASE REG_STATUS

    set status [master_read_32 $jtag [expr {$DSA_BASE + $REG_STATUS}] 1]

    set busy  [expr {$status & 0x01}]
    set done  [expr {($status >> 1) & 0x01}]
    set error [expr {($status >> 2) & 0x01}]

    puts "STATUS (0x[format %08X $status]):"
    puts "  busy  = $busy"
    puts "  done  = $done"
    puts "  error = $error"

    return [list $busy $done $error]
}

# ==============================================================================
# FUNCIÓN: Leer configuración
# ==============================================================================
proc read_config {} {
    global jtag DSA_BASE
    global REG_IMG_WIDTH_IN REG_IMG_HEIGHT_IN
    global REG_IMG_WIDTH_OUT REG_IMG_HEIGHT_OUT
    global REG_INPUT_BASE REG_OUTPUT_BASE
    global REG_SCALE_FACTOR

    set w_in  [master_read_32 $jtag [expr {$DSA_BASE + $REG_IMG_WIDTH_IN}] 1]
    set h_in  [master_read_32 $jtag [expr {$DSA_BASE + $REG_IMG_HEIGHT_IN}] 1]
    set w_out [master_read_32 $jtag [expr {$DSA_BASE + $REG_IMG_WIDTH_OUT}] 1]
    set h_out [master_read_32 $jtag [expr {$DSA_BASE + $REG_IMG_HEIGHT_OUT}] 1]
    set in_base  [master_read_32 $jtag [expr {$DSA_BASE + $REG_INPUT_BASE}] 1]
    set out_base [master_read_32 $jtag [expr {$DSA_BASE + $REG_OUTPUT_BASE}] 1]
    set scale_factor [master_read_32 $jtag [expr {$DSA_BASE + $REG_SCALE_FACTOR}] 1]

    # Convertir scale_factor Q8.8 a decimal
    set scale_float [expr {$scale_factor / 256.0}]

    puts "\nCONFIGURACIÓN:"
    puts "  Input:  $w_in × $h_in"
    puts "  Output: $w_out × $h_out (calculadas desde scale_factor)"
    puts "  Scale Factor (Q8.8): $scale_factor (0x[format %04X $scale_factor]) = [format "%.3f" $scale_float]"
    puts "  Input base:  0x[format %08X $in_base]"
    puts "  Output base: 0x[format %08X $out_base]"
}

# ==============================================================================
# FUNCIÓN: Leer performance counters
# ==============================================================================
proc read_counters {} {
    global jtag DSA_BASE
    global REG_PERF_CYCLES REG_PERF_READS REG_PERF_WRITES REG_PERF_FLOPS

    set cycles [master_read_32 $jtag [expr {$DSA_BASE + $REG_PERF_CYCLES}] 1]
    set reads  [master_read_32 $jtag [expr {$DSA_BASE + $REG_PERF_READS}] 1]
    set writes [master_read_32 $jtag [expr {$DSA_BASE + $REG_PERF_WRITES}] 1]
    set flops  [master_read_32 $jtag [expr {$DSA_BASE + $REG_PERF_FLOPS}] 1]

    puts "\nPERFORMANCE COUNTERS:"
    puts "  Cycles: $cycles"
    puts "  Reads:  $reads"
    puts "  Writes: $writes"
    puts "  FLOPs:  $flops"

    return [list $cycles $reads $writes $flops]
}

# ==============================================================================
# FUNCIÓN: Snapshot completo del DSA
# ==============================================================================
proc dsa_snapshot {} {
    puts "\n=========================================="
    puts "  DSA SNAPSHOT"
    puts "=========================================="

    read_status
    read_config
    read_counters

    puts "==========================================\n"
}

# ==============================================================================
# FUNCIÓN: Monitoreo continuo
# ==============================================================================
proc monitor_dsa {{iterations 10} {delay_ms 500}} {
    puts "\n=========================================="
    puts "  MONITOREANDO DSA"
    puts "  Iteraciones: $iterations"
    puts "  Delay: $delay_ms ms"
    puts "==========================================\n"

    for {set i 0} {$i < $iterations} {incr i} {
        puts "--- Iteración [expr {$i + 1}]/$iterations ---"

        set status_info [read_status]
        set busy  [lindex $status_info 0]
        set done  [lindex $status_info 1]
        set error [lindex $status_info 2]

        set counters [read_counters]
        set cycles [lindex $counters 0]
        set reads  [lindex $counters 1]
        set writes [lindex $counters 2]

        # Detección de cambios
        if {$i > 0} {
            global last_cycles last_reads last_writes

            set delta_cycles [expr {$cycles - $last_cycles}]
            set delta_reads  [expr {$reads - $last_reads}]
            set delta_writes [expr {$writes - $last_writes}]

            puts "\nΔ desde última iteración:"
            puts "  Δ Cycles: $delta_cycles"
            puts "  Δ Reads:  $delta_reads"
            puts "  Δ Writes: $delta_writes"

            # Diagnóstico
            if {$busy && $delta_cycles == 0} {
                puts "\n⚠️  ADVERTENCIA: busy=1 pero cycles no incrementa (posible deadlock)"
            }

            if {$busy && $delta_reads == 0 && $delta_writes == 0} {
                puts "\n⚠️  ADVERTENCIA: busy=1 pero sin actividad de memoria"
            }
        }

        set last_cycles $cycles
        set last_reads  $reads
        set last_writes $writes

        if {$done} {
            puts "\n✓ DONE detectado!"
            break
        }

        if {$error} {
            puts "\n✗ ERROR detectado!"
            break
        }

        puts ""
        after $delay_ms
    }

    puts "==========================================\n"
}

# ==============================================================================
# FUNCIÓN: Test rápido con START
# ==============================================================================
proc quick_test {} {
    global jtag DSA_BASE REG_CTRL

    puts "\n=========================================="
    puts "  QUICK TEST"
    puts "==========================================\n"

    puts "1. Estado inicial:"
    dsa_snapshot

    puts "2. Enviando START (modo secuencial)..."
    master_write_32 $jtag [expr {$DSA_BASE + $REG_CTRL}] 0x00000001
    after 100

    puts "3. Monitoreando por 5 segundos..."
    monitor_dsa 10 500

    puts "Test completado.\n"
}

# ==============================================================================
# FUNCIÓN: Leer primeros bytes de SDRAM
# ==============================================================================
proc read_sdram_sample {{addr 0x00000000} {count 16}} {
    global jtag

    puts "\nLeyendo SDRAM @ 0x[format %08X $addr] ($count bytes):"

    for {set i 0} {$i < $count} {incr i 4} {
        set word_addr [expr {$addr + $i}]
        set data [master_read_32 $jtag $word_addr 1]

        set b0 [expr {$data & 0xFF}]
        set b1 [expr {($data >> 8) & 0xFF}]
        set b2 [expr {($data >> 16) & 0xFF}]
        set b3 [expr {($data >> 24) & 0xFF}]

        puts "  0x[format %08X $word_addr]: 0x[format %02X $b0] 0x[format %02X $b1] 0x[format %02X $b2] 0x[format %02X $b3]"
    }
}

# ==============================================================================
# FUNCIÓN: Verificar que las dimensiones son válidas
# ==============================================================================
proc check_dimensions {} {
    global jtag DSA_BASE
    global REG_IMG_WIDTH_IN REG_IMG_HEIGHT_IN
    global REG_IMG_WIDTH_OUT REG_IMG_HEIGHT_OUT
    global REG_SCALE_FACTOR

    set w_in  [master_read_32 $jtag [expr {$DSA_BASE + $REG_IMG_WIDTH_IN}] 1]
    set h_in  [master_read_32 $jtag [expr {$DSA_BASE + $REG_IMG_HEIGHT_IN}] 1]
    set w_out [master_read_32 $jtag [expr {$DSA_BASE + $REG_IMG_WIDTH_OUT}] 1]
    set h_out [master_read_32 $jtag [expr {$DSA_BASE + $REG_IMG_HEIGHT_OUT}] 1]
    set scale_factor [master_read_32 $jtag [expr {$DSA_BASE + $REG_SCALE_FACTOR}] 1]

    puts "\nVERIFICACIÓN DE DIMENSIONES:"
    puts "  Input:  $w_in × $h_in"
    puts "  Output: $w_out × $h_out"
    
    # Mostrar scale_factor
    set scale_float [expr {$scale_factor / 256.0}]
    puts "  Scale Factor (Q8.8): $scale_factor (0x[format %04X $scale_factor]) = [format "%.3f" $scale_float]"

    # Calcular dimensiones esperadas desde scale_factor
    set expected_w_out [expr {($w_in * $scale_factor) >> 8}]
    set expected_h_out [expr {($h_in * $scale_factor) >> 8}]
    
    puts "\nDimensiones calculadas desde scale_factor:"
    puts "  Expected Output: $expected_w_out × $expected_h_out"
    
    if {$expected_w_out != $w_out || $expected_h_out != $h_out} {
        puts "\n⚠️  NOTA: Las dimensiones de salida difieren de las calculadas"
        puts "     Esto es normal si fueron calculadas en hardware"
    }

    # Verificar límites
    if {$w_out > $w_in || $h_out > $h_in} {
        puts "\n✗ ERROR: Output mayor que Input (upscaling no soportado)"
        return 0
    }

    if {$w_in == 0 || $h_in == 0 || $w_out == 0 || $h_out == 0} {
        puts "\n✗ ERROR: Dimensión == 0"
        return 0
    }
    
    if {$scale_factor <= 0 || $scale_factor > 256} {
        puts "\n✗ ERROR: scale_factor fuera de rango (debe estar entre 1-256)"
        return 0
    }

    puts "\n✓ Dimensiones válidas"
    return 1
}

# ==============================================================================
# INSTRUCCIONES
# ==============================================================================
puts "\n=========================================="
puts "  debug_dsa.tcl cargado"
puts "==========================================\n"
puts "Funciones disponibles:"
puts "  dsa_snapshot                      - Snapshot completo del estado"
puts "  read_status                       - Solo registro STATUS"
puts "  read_config                       - Solo configuración"
puts "  read_counters                     - Solo performance counters"
puts "  check_dimensions                  - Verificar dimensiones y ratios"
puts "  monitor_dsa \[iters\] \[delay_ms\]  - Monitoreo continuo (default: 10, 500ms)"
puts "  quick_test                        - Test rápido con START"
puts "  read_sdram_sample \[addr\] \[cnt\]  - Leer primeros bytes de SDRAM"
puts "\nEjemplos:"
puts "  dsa_snapshot"
puts "  monitor_dsa 20 1000                ;# 20 iteraciones, 1 segundo entre cada una"
puts "  quick_test"
puts "  read_sdram_sample 0x00000000 32    ;# Leer 32 bytes desde dirección 0"
puts "==========================================\n"
