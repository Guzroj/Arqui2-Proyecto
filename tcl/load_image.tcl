# ==============================================================================
# load_image.tcl
# ==============================================================================
# Script para cargar imagen desde archivo .txt a SDRAM
# Formato esperado: archivo .txt con valores de píxeles (0-255), uno por línea
# ==============================================================================

# ==============================================================================
# USO:
# ==============================================================================
# En System Console:
#   source load_image.tcl
#   load_image_to_sdram "ruta/imagen.txt" 512 512 0x00000000
#
# Parámetros:
#   - archivo: ruta al .txt con píxeles
#   - width:   ancho de la imagen
#   - height:  alto de la imagen  
#   - base_addr: dirección base en SDRAM (default 0x00000000)
# ==============================================================================

proc load_image_to_sdram {filename width height {base_addr 0x00000000}} {
    global jtag
    
    puts "\n=========================================="
    puts "  CARGANDO IMAGEN A SDRAM"
    puts "==========================================\n"
    
    # ==============================================================================
    # 1. VERIFICAR CONEXIÓN JTAG
    # ==============================================================================
    if {![info exists jtag]} {
        puts "ERROR: Variable 'jtag' no está definida"
        puts "Primero ejecuta: source test_dsa_basic.tcl"
        puts "O manualmente:"
        puts "  set jtag_masters \[get_service_paths master\]"
        puts "  set jtag \[lindex \$jtag_masters 0\]"
        puts "  open_service master \$jtag"
        return -1
    }
    
    # ==============================================================================
    # 2. VERIFICAR ARCHIVO
    # ==============================================================================
    puts "1. Verificando archivo..."
    puts "   Archivo: $filename"
    
    if {![file exists $filename]} {
        puts "   ✗ ERROR: Archivo no encontrado"
        return -1
    }
    
    set filesize [file size $filename]
    puts "   Tamaño: $filesize bytes"
    puts "   ✓ Archivo encontrado\n"
    
    # ==============================================================================
    # 3. LEER ARCHIVO
    # ==============================================================================
    puts "2. Leyendo píxeles desde archivo..."
    
    set fp [open $filename r]
    set pixels [list]
    set line_count 0
    
    while {[gets $fp line] >= 0} {
        set line [string trim $line]
        if {$line != ""} {
            # Convertir a entero y validar rango
            set pixel [expr {int($line)}]
            if {$pixel < 0 || $pixel > 255} {
                puts "   ⚠ ADVERTENCIA: Píxel fuera de rango en línea $line_count: $pixel (clampado a 0-255)"
                if {$pixel < 0} {set pixel 0}
                if {$pixel > 255} {set pixel 255}
            }
            lappend pixels $pixel
            incr line_count
        }
    }
    close $fp
    
    set num_pixels [llength $pixels]
    puts "   Píxeles leídos: $num_pixels"
    
    # ==============================================================================
    # 4. VALIDAR DIMENSIONES
    # ==============================================================================
    puts "\n3. Validando dimensiones..."
    
    set expected_pixels [expr {$width * $height}]
    puts "   Esperados: $expected_pixels ($width × $height)"
    puts "   Leídos:    $num_pixels"
    
    if {$num_pixels < $expected_pixels} {
        puts "   ✗ ERROR: Archivo tiene menos píxeles que los esperados"
        puts "     Faltan [expr {$expected_pixels - $num_pixels}] píxeles"
        return -1
    } elseif {$num_pixels > $expected_pixels} {
        puts "   ⚠ ADVERTENCIA: Archivo tiene más píxeles, se usarán solo los primeros $expected_pixels"
        set pixels [lrange $pixels 0 [expr {$expected_pixels - 1}]]
    } else {
        puts "   ✓ Dimensiones correctas\n"
    }
    
    # ==============================================================================
    # 5. ESCRIBIR A SDRAM (BYTE POR BYTE)
    # ==============================================================================
    puts "4. Escribiendo a SDRAM..."
    puts "   Dirección base: 0x[format %08X $base_addr]"
    puts "   Total bytes: $expected_pixels"
    puts "   Progreso: "
    
    set bytes_written 0
    set progress_step [expr {$expected_pixels / 20}]
    if {$progress_step == 0} {set progress_step 1}
    
    # Escribir de 4 en 4 bytes (más eficiente)
    for {set i 0} {$i < $expected_pixels} {incr i 4} {
        # Construir word de 32 bits (4 píxeles)
        set byte0 [lindex $pixels $i]
        set byte1 [expr {$i+1 < $expected_pixels ? [lindex $pixels [expr {$i+1}]] : 0}]
        set byte2 [expr {$i+2 < $expected_pixels ? [lindex $pixels [expr {$i+2}]] : 0}]
        set byte3 [expr {$i+3 < $expected_pixels ? [lindex $pixels [expr {$i+3}]] : 0}]
        
        # Empaquetar en formato little-endian
        set word [expr {($byte3 << 24) | ($byte2 << 16) | ($byte1 << 8) | $byte0}]
        
        # Escribir word
        master_write_32 $jtag [expr {$base_addr + $i}] $word
        
        set bytes_written [expr {$i + 4}]
        
        # Mostrar progreso
        if {$i % $progress_step == 0} {
            set percent [expr {($i * 100) / $expected_pixels}]
            puts -nonewline "   \[$percent%\]"
            flush stdout
        }
    }
    
    puts " \[100%\]"
    puts "   ✓ $bytes_written bytes escritos\n"
    
    # ==============================================================================
    # 6. VERIFICAR ESCRITURA (primeros y últimos bytes)
    # ==============================================================================
    puts "5. Verificando escritura..."
    
    # Verificar primer word (4 bytes)
    set first_word [master_read_32 $jtag $base_addr 1]
    set expected_first [expr {([lindex $pixels 3] << 24) | ([lindex $pixels 2] << 16) | ([lindex $pixels 1] << 8) | [lindex $pixels 0]}]
    
    if {$first_word == $expected_first} {
        puts "   ✓ Primeros 4 bytes: OK"
    } else {
        puts "   ✗ ERROR en primeros 4 bytes"
        puts "     Esperado: 0x[format %08X $expected_first]"
        puts "     Leído:    0x[format %08X $first_word]"
    }
    
    # Verificar último word
    set last_addr [expr {$base_addr + $expected_pixels - 4}]
    set last_word [master_read_32 $jtag $last_addr 1]
    set last_idx [expr {$expected_pixels - 4}]
    set expected_last [expr {([lindex $pixels [expr {$last_idx+3}]] << 24) | ([lindex $pixels [expr {$last_idx+2}]] << 16) | ([lindex $pixels [expr {$last_idx+1}]] << 8) | [lindex $pixels $last_idx]}]
    
    if {$last_word == $expected_last} {
        puts "   ✓ Últimos 4 bytes: OK\n"
    } else {
        puts "   ✗ ERROR en últimos 4 bytes"
        puts "     Esperado: 0x[format %08X $expected_last]"
        puts "     Leído:    0x[format %08X $last_word]\n"
    }
    
    # ==============================================================================
    # RESUMEN
    # ==============================================================================
    puts "=========================================="
    puts "  IMAGEN CARGADA EXITOSAMENTE"
    puts "==========================================\n"
    
    puts "Detalles:"
    puts "  Dimensiones: $width × $height"
    puts "  Píxeles:     $expected_pixels"
    puts "  Dirección:   0x[format %08X $base_addr] - 0x[format %08X [expr {$base_addr + $expected_pixels - 1}]]"
    puts "  Tamaño:      $expected_pixels bytes\n"
    
    puts "Siguiente paso:"
    puts "  source run_downscale.tcl"
    puts "  run_downscale $width $height <width_out> <height_out>\n"
    
    return 0
}

# ==============================================================================
# FUNCIÓN AUXILIAR: Cargar imagen rápida con dimensiones comunes
# ==============================================================================
proc quick_load_512x512 {filename} {
    load_image_to_sdram $filename 512 512 0x00000000
}

proc quick_load_256x256 {filename} {
    load_image_to_sdram $filename 256 256 0x00000000
}

proc quick_load_128x128 {filename} {
    load_image_to_sdram $filename 128 128 0x00000000
}

# ==============================================================================
# INSTRUCCIONES DE USO
# ==============================================================================
puts "\n=========================================="
puts "  load_image.tcl cargado"
puts "==========================================\n"
puts "Funciones disponibles:"
puts "  load_image_to_sdram <archivo> <width> <height> \[base_addr\]"
puts "  quick_load_512x512 <archivo>"
puts "  quick_load_256x256 <archivo>"
puts "  quick_load_128x128 <archivo>"
puts "\nEjemplo:"
puts "  load_image_to_sdram \"imagen.txt\" 512 512"
puts "  quick_load_512x512 \"imagen.txt\""
puts "==========================================\n"


