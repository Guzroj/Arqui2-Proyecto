# ==============================================================================
# read_result.tcl
# ==============================================================================
# Script para leer imagen procesada desde SDRAM y guardarla a archivo .txt
# ==============================================================================

# ==============================================================================
# FUNCIÓN PRINCIPAL: read_result_from_sdram
# ==============================================================================
# Parámetros:
#   output_file: nombre del archivo .txt de salida
#   width:       ancho de la imagen
#   height:      alto de la imagen
#   base_addr:   dirección base en SDRAM donde está la imagen
# ==============================================================================
proc read_result_from_sdram {output_file width height {base_addr 0x00100000}} {
    global jtag
    
    puts "\n=========================================="
    puts "  LEYENDO RESULTADO DESDE SDRAM"
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
    
    if {$width <= 0 || $height <= 0} {
        puts "   ✗ ERROR: Dimensiones deben ser > 0"
        return -1
    }
    
    set total_pixels [expr {$width * $height}]
    
    puts "   Dimensiones: $width × $height"
    puts "   Total píxeles: $total_pixels"
    puts "   Dirección base: 0x[format %08X $base_addr]"
    puts "   Archivo salida: $output_file"
    puts "   ✓ Parámetros válidos\n"
    
    # ==============================================================================
    # 3. LEER DATOS DESDE SDRAM
    # ==============================================================================
    puts "2. Leyendo datos desde SDRAM..."
    puts "   Progreso: "
    
    set pixels [list]
    set progress_step [expr {$total_pixels / 20}]
    if {$progress_step == 0} {set progress_step 1}
    
    # Leer de 4 en 4 bytes (más eficiente)
    for {set i 0} {$i < $total_pixels} {incr i 4} {
        # Leer word de 32 bits
        set word [master_read_32 $jtag [expr {$base_addr + $i}] 1]
        
        # Extraer 4 bytes (little-endian)
        set byte0 [expr {$word & 0xFF}]
        set byte1 [expr {($word >> 8) & 0xFF}]
        set byte2 [expr {($word >> 16) & 0xFF}]
        set byte3 [expr {($word >> 24) & 0xFF}]
        
        lappend pixels $byte0
        if {$i + 1 < $total_pixels} {lappend pixels $byte1}
        if {$i + 2 < $total_pixels} {lappend pixels $byte2}
        if {$i + 3 < $total_pixels} {lappend pixels $byte3}
        
        # Mostrar progreso
        if {$i % $progress_step == 0} {
            set percent [expr {($i * 100) / $total_pixels}]
            puts -nonewline "   \[$percent%\]"
            flush stdout
        }
    }
    
    puts " \[100%\]"
    puts "   ✓ $total_pixels píxeles leídos\n"
    
    # ==============================================================================
    # 4. CALCULAR ESTADÍSTICAS
    # ==============================================================================
    puts "3. Calculando estadísticas..."
    
    set min_val 255
    set max_val 0
    set sum 0
    
    foreach pixel $pixels {
        if {$pixel < $min_val} {set min_val $pixel}
        if {$pixel > $max_val} {set max_val $pixel}
        set sum [expr {$sum + $pixel}]
    }
    
    set avg [expr {double($sum) / $total_pixels}]
    
    puts "   Valor mínimo: $min_val"
    puts "   Valor máximo: $max_val"
    puts "   Promedio:     [format "%.2f" $avg]"
    puts "   ✓ Estadísticas calculadas\n"
    
    # ==============================================================================
    # 5. GUARDAR A ARCHIVO
    # ==============================================================================
    puts "4. Guardando a archivo..."
    
    set fp [open $output_file w]
    
    foreach pixel $pixels {
        puts $fp $pixel
    }
    
    close $fp
    
    set filesize [file size $output_file]
    puts "   ✓ Archivo guardado: $output_file"
    puts "   Tamaño: $filesize bytes\n"
    
    # ==============================================================================
    # RESUMEN
    # ==============================================================================
    puts "=========================================="
    puts "  RESULTADO LEÍDO EXITOSAMENTE"
    puts "==========================================\n"
    
    puts "Detalles:"
    puts "  Archivo:     $output_file"
    puts "  Dimensiones: $width × $height"
    puts "  Píxeles:     $total_pixels"
    puts "  Rango:       \[$min_val, $max_val\]"
    puts "  Promedio:    [format "%.2f" $avg]"
    
    puts "\nPuedes visualizar la imagen con:"
    puts "  - Herramienta externa (ImageJ, MATLAB, etc.)"
    puts "  - Script Python para convertir a PNG"
    
    puts "\n==========================================\n"
    
    return 0
}

# ==============================================================================
# FUNCIÓN AUXILIAR: Comparar dos imágenes
# ==============================================================================
proc compare_images {file1 file2} {
    puts "\n=========================================="
    puts "  COMPARANDO IMÁGENES"
    puts "==========================================\n"
    
    # Leer archivo 1
    if {![file exists $file1]} {
        puts "ERROR: Archivo $file1 no encontrado"
        return -1
    }
    
    if {![file exists $file2]} {
        puts "ERROR: Archivo $file2 no encontrado"
        return -1
    }
    
    puts "Leyendo archivos..."
    
    set fp1 [open $file1 r]
    set pixels1 [list]
    while {[gets $fp1 line] >= 0} {
        set line [string trim $line]
        if {$line != ""} {
            lappend pixels1 [expr {int($line)}]
        }
    }
    close $fp1
    
    set fp2 [open $file2 r]
    set pixels2 [list]
    while {[gets $fp2 line] >= 0} {
        set line [string trim $line]
        if {$line != ""} {
            lappend pixels2 [expr {int($line)}]
        }
    }
    close $fp2
    
    set count1 [llength $pixels1]
    set count2 [llength $pixels2]
    
    puts "  Archivo 1: $count1 píxeles"
    puts "  Archivo 2: $count2 píxeles"
    
    if {$count1 != $count2} {
        puts "\n✗ ERROR: Archivos tienen diferente número de píxeles"
        return -1
    }
    
    # Comparar píxel por píxel
    set differences 0
    set max_diff 0
    set sum_diff 0
    
    for {set i 0} {$i < $count1} {incr i} {
        set p1 [lindex $pixels1 $i]
        set p2 [lindex $pixels2 $i]
        set diff [expr {abs($p1 - $p2)}]
        
        if {$diff > 0} {
            incr differences
            set sum_diff [expr {$sum_diff + $diff}]
            if {$diff > $max_diff} {
                set max_diff $diff
            }
        }
    }
    
    puts "\nResultados:"
    puts "  Píxeles diferentes: $differences / $count1"
    puts "  Porcentaje error:   [format "%.2f" [expr {($differences * 100.0) / $count1}]]%"
    
    if {$differences > 0} {
        set avg_diff [expr {double($sum_diff) / $differences}]
        puts "  Diferencia máxima:  $max_diff"
        puts "  Diferencia promedio: [format "%.2f" $avg_diff]"
    }
    
    if {$differences == 0} {
        puts "\n✓ IMÁGENES IDÉNTICAS"
    } elseif {$differences < ($count1 * 0.01)} {
        puts "\n✓ IMÁGENES MUY SIMILARES (< 1% diferencia)"
    } elseif {$differences < ($count1 * 0.05)} {
        puts "\n⚠ IMÁGENES SIMILARES (< 5% diferencia)"
    } else {
        puts "\n✗ IMÁGENES DIFERENTES (≥ 5% diferencia)"
    }
    
    puts "==========================================\n"
    
    return 0
}

# ==============================================================================
# FUNCIONES AUXILIARES: Lectura rápida con tamaños comunes
# ==============================================================================
proc quick_read_256x256 {filename {addr 0x00100000}} {
    read_result_from_sdram $filename 256 256 $addr
}

proc quick_read_128x128 {filename {addr 0x00100000}} {
    read_result_from_sdram $filename 128 128 $addr
}

proc quick_read_64x64 {filename {addr 0x00100000}} {
    read_result_from_sdram $filename 64 64 $addr
}

# ==============================================================================
# INSTRUCCIONES DE USO
# ==============================================================================
puts "\n=========================================="
puts "  read_result.tcl cargado"
puts "==========================================\n"
puts "Funciones disponibles:"
puts "  read_result_from_sdram <archivo> <width> <height> \[base_addr\]"
puts "  compare_images <archivo1> <archivo2>"
puts "\nAtajos:"
puts "  quick_read_256x256 <archivo> \[addr\]"
puts "  quick_read_128x128 <archivo> \[addr\]"
puts "  quick_read_64x64 <archivo> \[addr\]"
puts "\nEjemplo:"
puts "  read_result_from_sdram \"output.txt\" 256 256 0x00100000"
puts "  quick_read_256x256 \"output.txt\""
puts "  compare_images \"expected.txt\" \"output.txt\""
puts "==========================================\n"


