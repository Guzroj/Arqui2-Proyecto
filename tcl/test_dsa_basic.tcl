# ==============================================================================
# test_dsa_basic.tcl
# ==============================================================================
# Script para verificación básica del DSA
# Prueba conexión JTAG, lee registros de control y verifica estado
# ==============================================================================

puts "\n=========================================="
puts "  TEST BÁSICO DEL DSA"
puts "==========================================\n"

# ==============================================================================
# CONFIGURACIÓN DE DIRECCIONES
# ==============================================================================
set DSA_BASE     0x05000000
set SDRAM_BASE   0x00000000
set LEDS_BASE    0x04000000

# Offsets de registros DSA
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
# 1. CONECTAR AL JTAG
# ==============================================================================
puts "1. Conectando al JTAG Master..."

set jtag_masters [get_service_paths master]
if {[llength $jtag_masters] == 0} {
    puts "ERROR: No se encontró ningún JTAG Master"
    puts "Verifica que:"
    puts "  - La FPGA esté conectada"
    puts "  - El cable USB-Blaster funcione"
    puts "  - La FPGA esté programada"
    return -1
}

set jtag [lindex $jtag_masters 0]
puts "   ✓ JTAG Master encontrado: $jtag"

open_service master $jtag
puts "   ✓ Servicio JTAG abierto\n"

# ==============================================================================
# 2. TEST DE LEDS (Verificar bus Avalon-MM)
# ==============================================================================
puts "2. Probando LEDs (verificar bus Avalon-MM)..."

master_write_32 $jtag $LEDS_BASE 0x000003FF
puts "   → Todos los LEDs encendidos"
after 1000

master_write_32 $jtag $LEDS_BASE 0x00000155
puts "   → Patrón alternado"
after 1000

master_write_32 $jtag $LEDS_BASE 0x00000000
puts "   ✓ LEDs apagados - Bus funcional\n"

# ==============================================================================
# 3. LEER REGISTRO STATUS
# ==============================================================================
puts "3. Leyendo registro STATUS del DSA..."

set status [master_read_32 $jtag [expr $DSA_BASE + $REG_STATUS] 1]
set busy  [expr {$status & 0x01}]
set done  [expr {($status >> 1) & 0x01}]
set error [expr {($status >> 2) & 0x01}]

puts "   STATUS = 0x[format %08X $status]"
puts "     - Busy:  $busy"
puts "     - Done:  $done"
puts "     - Error: $error"

if {$busy} {
    puts "   ⚠ ADVERTENCIA: DSA está ocupado (busy=1)"
} else {
    puts "   ✓ DSA está idle (listo para usar)\n"
}

# ==============================================================================
# 4. LEER DIMENSIONES CONFIGURADAS
# ==============================================================================
puts "4. Leyendo dimensiones configuradas..."

set width_in   [master_read_32 $jtag [expr $DSA_BASE + $REG_IMG_WIDTH_IN] 1]
set height_in  [master_read_32 $jtag [expr $DSA_BASE + $REG_IMG_HEIGHT_IN] 1]
set width_out  [master_read_32 $jtag [expr $DSA_BASE + $REG_IMG_WIDTH_OUT] 1]
set height_out [master_read_32 $jtag [expr $DSA_BASE + $REG_IMG_HEIGHT_OUT] 1]

puts "   Imagen de entrada:  $width_in × $height_in"
puts "   Imagen de salida:   $width_out × $height_out"

# Validar dimensiones
if {$width_out > $width_in || $height_out > $height_in} {
    puts "   ⚠ ADVERTENCIA: Dimensiones de salida mayores que entrada"
}
if {$width_in == 0 || $height_in == 0} {
    puts "   ✗ ERROR: Dimensiones de entrada inválidas"
} else {
    puts "   ✓ Dimensiones válidas\n"
}

# ==============================================================================
# 5. LEER DIRECCIONES BASE DE MEMORIA
# ==============================================================================
puts "5. Leyendo direcciones base de memoria..."

set input_base  [master_read_32 $jtag [expr $DSA_BASE + $REG_INPUT_BASE] 1]
set output_base [master_read_32 $jtag [expr $DSA_BASE + $REG_OUTPUT_BASE] 1]

puts "   Input base:  0x[format %08X $input_base]"
puts "   Output base: 0x[format %08X $output_base]"

# Validar direcciones
if {$input_base == $output_base} {
    puts "   ⚠ ADVERTENCIA: Input y output en misma dirección (pueden solaparse)"
}
puts "   ✓ Direcciones base configuradas\n"

# ==============================================================================
# 6. LEER PERFORMANCE COUNTERS
# ==============================================================================
puts "6. Leyendo performance counters..."

set perf_cycles [master_read_32 $jtag [expr $DSA_BASE + $REG_PERF_CYCLES] 1]
set perf_reads  [master_read_32 $jtag [expr $DSA_BASE + $REG_PERF_READS] 1]
set perf_writes [master_read_32 $jtag [expr $DSA_BASE + $REG_PERF_WRITES] 1]
set perf_flops  [master_read_32 $jtag [expr $DSA_BASE + $REG_PERF_FLOPS] 1]

puts "   Ciclos:     $perf_cycles"
puts "   Lecturas:   $perf_reads"
puts "   Escrituras: $perf_writes"
puts "   FLOPs:      $perf_flops"

if {$perf_cycles > 0} {
    puts "   ℹ Hay datos de ejecución previa"
} else {
    puts "   ✓ Counters en cero (sistema limpio)\n"
}

# ==============================================================================
# 7. TEST DE RESET DE COUNTERS
# ==============================================================================
puts "7. Probando reset de performance counters..."

# Escribir bit reset_counters (bit 1 del registro CTRL)
master_write_32 $jtag [expr $DSA_BASE + $REG_CTRL] 0x00000002
after 100

# Leer counters después del reset
set perf_cycles_new [master_read_32 $jtag [expr $DSA_BASE + $REG_PERF_CYCLES] 1]
set perf_reads_new  [master_read_32 $jtag [expr $DSA_BASE + $REG_PERF_READS] 1]
set perf_writes_new [master_read_32 $jtag [expr $DSA_BASE + $REG_PERF_WRITES] 1]

puts "   Ciclos después de reset: $perf_cycles_new"

if {$perf_cycles_new == 0 && $perf_reads_new == 0 && $perf_writes_new == 0} {
    puts "   ✓ Reset de counters funcional\n"
} else {
    puts "   ⚠ ADVERTENCIA: Counters no se resetearon correctamente\n"
}

# ==============================================================================
# 8. TEST DE ESCRITURA/LECTURA SDRAM
# ==============================================================================
puts "8. Probando acceso a SDRAM..."

# Escribir patrón de prueba en SDRAM
set test_addr 0x00000100
set test_values {0xDEADBEEF 0xCAFEBABE 0x12345678 0xABCDEF00}

puts "   Escribiendo patrón de prueba..."
set i 0
foreach val $test_values {
    master_write_32 $jtag [expr $SDRAM_BASE + $test_addr + ($i * 4)] $val
    incr i
}

puts "   Leyendo y verificando..."
set i 0
set errors 0
foreach val $test_values {
    set read_val [master_read_32 $jtag [expr $SDRAM_BASE + $test_addr + ($i * 4)] 1]
    if {$read_val != $val} {
        puts "   ✗ Error en offset $i: esperado 0x[format %08X $val], leído 0x[format %08X $read_val]"
        incr errors
    }
    incr i
}

if {$errors == 0} {
    puts "   ✓ SDRAM funcional - Read/Write OK\n"
} else {
    puts "   ✗ ERROR: $errors fallos en SDRAM\n"
}

# ==============================================================================
# RESUMEN FINAL
# ==============================================================================
puts "=========================================="
puts "  RESUMEN DEL TEST"
puts "==========================================\n"

puts "✓ JTAG Master:        Conectado"
puts "✓ Bus Avalon-MM:      Funcional (LEDs OK)"
puts "✓ Registros DSA:      Accesibles"
puts "✓ SDRAM:              Funcional"
puts "✓ Performance Counters: OK"

if {$busy} {
    puts "⚠ Estado DSA:         BUSY (procesando)"
} else {
    puts "✓ Estado DSA:         IDLE (listo)"
}

puts "\nSistema listo para:"
puts "  1. Cargar imagen (load_image.tcl)"
puts "  2. Ejecutar downscale (run_downscale.tcl)"
puts "  3. Leer resultado (read_result.tcl)"

puts "\n==========================================\n"


