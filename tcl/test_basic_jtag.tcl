# ============================================================================
# test_basic_jtag.tcl
# ============================================================================
# Script básico para verificar conexión JTAG y acceso a componentes
#
# Uso en JTAG System Console:
#   1. Tools → System Console
#   2. Tcl Console: source test_basic_jtag.tcl
#   3. Ejecutar: test_basic_connection
#
# Autor: DSA Project Team
# Fecha: Diciembre 2025
# ============================================================================

# ============================================================================
# Configuración de Direcciones
# ============================================================================
set DSA_BASE_ADDR     0x00500000
set INPUT_MEM_BASE    0x00000000
set OUTPUT_MEM_BASE   0x00040000
set LEDS_BASE         0x00050000

# Offsets de registros DSA
set REG_CTRL          0x00
set REG_STATUS        0x04
set REG_IMG_WIDTH_IN  0x08
set REG_IMG_HEIGHT_IN 0x0C
set REG_IMG_WIDTH_OUT 0x10
set REG_IMG_HEIGHT_OUT 0x14
set REG_INPUT_BASE    0x18
set REG_OUTPUT_BASE   0x1C
set REG_PERF_CYCLES   0x20
set REG_PERF_READS    0x24
set REG_PERF_WRITES   0x28
set REG_PERF_FLOPS    0x2C

# ============================================================================
# Función: Conectar a JTAG Master
# ============================================================================
proc connect_jtag {} {
    global jtag_master

    puts "\n=========================================="
    puts "Conectando a JTAG Master..."
    puts "=========================================="

    # Obtener servicios disponibles
    set services [get_service_paths master]

    if {[llength $services] == 0} {
        puts "ERROR: No se encontró ningún JTAG Master"
        puts "Verificar que:"
        puts "  1. La FPGA esté programada"
        puts "  2. El cable USB Blaster esté conectado"
        puts "  3. Los drivers estén instalados"
        return -1
    }

    # Mostrar servicios disponibles
    puts "\nServicios JTAG disponibles:"
    set idx 0
    foreach service $services {
        puts "  \[$idx\] $service"
        incr idx
    }

    # Usar el primero por defecto
    set jtag_master [lindex $services 0]
    puts "\nUsando: $jtag_master"

    # Abrir el servicio
    open_service master $jtag_master
    puts "Conexión establecida ✓"

    return 0
}

# ============================================================================
# Función: Leer registro de 32 bits
# ============================================================================
proc read_reg {base offset} {
    global jtag_master
    set addr [expr $base + $offset]
    set data [master_read_32 $jtag_master $addr 1]
    return [lindex $data 0]
}

# ============================================================================
# Función: Escribir registro de 32 bits
# ============================================================================
proc write_reg {base offset value} {
    global jtag_master
    set addr [expr $base + $offset]
    master_write_32 $jtag_master $addr $value
}

# ============================================================================
# Función: Test de LEDs
# ============================================================================
proc test_leds {} {
    global LEDS_BASE

    puts "\n=========================================="
    puts "Test de LEDs"
    puts "=========================================="

    # Patrón de prueba
    set patterns [list 0x000 0x3FF 0x155 0x2AA 0x0FF 0x300]

    foreach pattern $patterns {
        puts "Escribiendo patrón: 0x[format %03X $pattern]"
        write_reg $LEDS_BASE 0 $pattern
        after 500
    }

    # Apagar LEDs
    write_reg $LEDS_BASE 0 0x000
    puts "LEDs apagados ✓"
}

# ============================================================================
# Función: Leer todos los registros DSA
# ============================================================================
proc read_dsa_registers {} {
    global DSA_BASE_ADDR
    global REG_CTRL REG_STATUS REG_IMG_WIDTH_IN REG_IMG_HEIGHT_IN
    global REG_IMG_WIDTH_OUT REG_IMG_HEIGHT_OUT
    global REG_INPUT_BASE REG_OUTPUT_BASE
    global REG_PERF_CYCLES REG_PERF_READS REG_PERF_WRITES REG_PERF_FLOPS

    puts "\n=========================================="
    puts "Registros DSA (Base: 0x[format %08X $DSA_BASE_ADDR])"
    puts "=========================================="

    set ctrl [read_reg $DSA_BASE_ADDR $REG_CTRL]
    puts "CTRL (0x00):          0x[format %08X $ctrl]"
    puts "  - start:            [expr ($ctrl >> 0) & 0x1]"
    puts "  - reset_counters:   [expr ($ctrl >> 1) & 0x1]"
    puts "  - mode:             [expr ($ctrl >> 2) & 0x1] ([expr {($ctrl >> 2) & 0x1 ? "SIMD" : "Secuencial"}])"
    puts "  - scale_factor_idx: [expr ($ctrl >> 3) & 0x1F] (factor: [expr {0.5 + ([expr ($ctrl >> 3) & 0x1F] * 0.05)}])"
    puts "  - manual_dims:      [expr ($ctrl >> 8) & 0x1]"

    set status [read_reg $DSA_BASE_ADDR $REG_STATUS]
    puts "\nSTATUS (0x04):        0x[format %08X $status]"
    puts "  - busy:             [expr ($status >> 0) & 0x1]"
    puts "  - done:             [expr ($status >> 1) & 0x1]"
    puts "  - error:            [expr ($status >> 2) & 0x1]"

    set w_in [read_reg $DSA_BASE_ADDR $REG_IMG_WIDTH_IN]
    set h_in [read_reg $DSA_BASE_ADDR $REG_IMG_HEIGHT_IN]
    puts "\nIMG_IN (0x08-0x0C):   ${w_in} x ${h_in}"

    set w_out [read_reg $DSA_BASE_ADDR $REG_IMG_WIDTH_OUT]
    set h_out [read_reg $DSA_BASE_ADDR $REG_IMG_HEIGHT_OUT]
    puts "IMG_OUT (0x10-0x14):  ${w_out} x ${h_out}"

    set in_base [read_reg $DSA_BASE_ADDR $REG_INPUT_BASE]
    set out_base [read_reg $DSA_BASE_ADDR $REG_OUTPUT_BASE]
    puts "\nINPUT_BASE (0x18):    0x[format %08X $in_base]"
    puts "OUTPUT_BASE (0x1C):   0x[format %08X $out_base]"

    set cycles [read_reg $DSA_BASE_ADDR $REG_PERF_CYCLES]
    set reads [read_reg $DSA_BASE_ADDR $REG_PERF_READS]
    set writes [read_reg $DSA_BASE_ADDR $REG_PERF_WRITES]
    set flops [read_reg $DSA_BASE_ADDR $REG_PERF_FLOPS]
    puts "\nPERF_CYCLES (0x20):   $cycles"
    puts "PERF_READS (0x24):    $reads"
    puts "PERF_WRITES (0x28):   $writes"
    puts "PERF_FLOPS (0x2C):    $flops"
}

# ============================================================================
# Función: Test de memoria (escribir/leer patrón)
# ============================================================================
proc test_memory {base size_bytes} {
    puts "\n=========================================="
    puts "Test de Memoria (Base: 0x[format %08X $base], Size: $size_bytes bytes)"
    puts "=========================================="

    # Escribir patrón incremental (primeros 64 bytes)
    puts "Escribiendo patrón incremental..."
    set test_size 64
    set pattern {}
    for {set i 0} {$i < $test_size} {incr i 4} {
        lappend pattern [expr $i / 4]
    }

    master_write_32 $::jtag_master $base $pattern

    # Leer de vuelta
    puts "Leyendo de vuelta..."
    set readback [master_read_32 $::jtag_master $base [expr $test_size / 4]]

    # Verificar
    set errors 0
    for {set i 0} {$i < [llength $pattern]} {incr i} {
        set expected [lindex $pattern $i]
        set actual [lindex $readback $i]
        if {$expected != $actual} {
            puts "ERROR en offset [expr $i * 4]: esperado 0x[format %08X $expected], leído 0x[format %08X $actual]"
            incr errors
        }
    }

    if {$errors == 0} {
        puts "Test de memoria PASADO ✓ ($test_size bytes verificados)"
    } else {
        puts "Test de memoria FALLÓ ✗ ($errors errores)"
    }

    return $errors
}

# ============================================================================
# Función: Test de conexión completo
# ============================================================================
proc test_basic_connection {} {
    global INPUT_MEM_BASE OUTPUT_MEM_BASE

    # Conectar
    if {[connect_jtag] != 0} {
        return
    }

    # Test de LEDs
    test_leds

    # Leer registros DSA
    read_dsa_registers

    # Test de memoria de entrada
    test_memory $INPUT_MEM_BASE 256

    # Test de memoria de salida
    test_memory $OUTPUT_MEM_BASE 256

    puts "\n=========================================="
    puts "Test básico completado"
    puts "=========================================="
}

# ============================================================================
# Función: Resetear contadores de performance
# ============================================================================
proc reset_perf_counters {} {
    global DSA_BASE_ADDR REG_CTRL

    puts "Reseteando contadores de performance..."

    # Escribir bit reset_counters (bit 1)
    write_reg $DSA_BASE_ADDR $REG_CTRL 0x00000002

    # El auto-clear lo pone en 0 automáticamente
    after 10

    # Verificar
    set cycles [read_reg $DSA_BASE_ADDR 0x20]
    set reads [read_reg $DSA_BASE_ADDR 0x24]
    set writes [read_reg $DSA_BASE_ADDR 0x28]

    if {$cycles == 0 && $reads == 0 && $writes == 0} {
        puts "Contadores reseteados ✓"
    } else {
        puts "ADVERTENCIA: Contadores no están en cero"
    }
}

# ============================================================================
# Mensajes de ayuda
# ============================================================================
puts "\n=============================================="
puts "DSA Downscaler - Scripts de Test JTAG"
puts "=============================================="
puts "Comandos disponibles:"
puts "  test_basic_connection  - Test completo de conexión"
puts "  connect_jtag           - Conectar a JTAG Master"
puts "  test_leds              - Test de LEDs"
puts "  read_dsa_registers     - Leer todos los registros DSA"
puts "  test_memory <base> <size> - Test de memoria"
puts "  reset_perf_counters    - Resetear contadores"
puts "  read_reg <base> <offset> - Leer registro"
puts "  write_reg <base> <offset> <value> - Escribir registro"
puts "\nEjemplo:"
puts "  test_basic_connection"
puts "=============================================="
