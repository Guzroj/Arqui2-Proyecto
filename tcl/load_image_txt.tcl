# ============================================================================
# load_image_txt.tcl
# ============================================================================
# Script para cargar imagen desde archivo .txt (formato espacio-separado)
# y enviarla a la FPGA vía JTAG
#
# Uso:
#   source test_basic_jtag.tcl
#   source load_image_txt.tcl
#   load_image_from_txt "../imagen_grayscale.txt" 512 512
#
# Autor: DSA Project Team
# Fecha: Diciembre 2025
# ============================================================================

source [file join [file dirname [info script]] test_basic_jtag.tcl]

# ============================================================================
# Función: Cargar imagen desde archivo .txt
# ============================================================================
proc load_image_from_txt {filename width height} {
    global INPUT_MEM_BASE jtag_master

    puts "\n=========================================="
    puts "Cargando imagen desde archivo TXT"
    puts "=========================================="
    puts "Archivo: $filename"
    puts "Dimensiones: ${width}×${height}"

    # Verificar que el archivo existe
    if {![file exists $filename]} {
        puts "ERROR: Archivo no encontrado: $filename"
        return -1
    }

    # Leer archivo
    set fp [open $filename r]
    set file_data [read $fp]
    close $fp

    # Convertir a lista de píxeles
    set pixels {}
    foreach line [split $file_data "\n"] {
        if {[string trim $line] != ""} {
            foreach pixel [split $line] {
                if {[string trim $pixel] != ""} {
                    lappend pixels [expr {int($pixel) & 0xFF}]
                }
            }
        }
    }

    set total_pixels [llength $pixels]
    set expected_pixels [expr {$width * $height}]

    puts "Píxeles leídos: $total_pixels"
    puts "Píxeles esperados: $expected_pixels"

    if {$total_pixels != $expected_pixels} {
        puts "ADVERTENCIA: Número de píxeles no coincide"
    }

    # Convertir píxeles a words de 32 bits (little-endian)
    puts "Convirtiendo a formato de 32 bits..."
    set words {}
    set word 0
    set byte_idx 0

    foreach pixel $pixels {
        # Construir word (little-endian)
        set word [expr {$word | (($pixel & 0xFF) << ($byte_idx * 8))}]
        incr byte_idx

        if {$byte_idx == 4} {
            lappend words $word
            set word 0
            set byte_idx 0
        }
    }

    # Si quedaron bytes sin completar word
    if {$byte_idx > 0} {
        lappend words $word
    }

    set num_words [llength $words]
    set size_bytes [expr {$num_words * 4}]

    puts "Total: $num_words words ([expr {$size_bytes / 1024}] KB)"

    # Escribir a memoria en bloques (para evitar timeout)
    puts "Escribiendo a BRAM en 0x[format %08X $INPUT_MEM_BASE]..."

    set block_size 1024  ;# 1024 words = 4 KB por bloque
    set blocks [expr {($num_words + $block_size - 1) / $block_size}]

    for {set i 0} {$i < $blocks} {incr i} {
        set offset [expr {$i * $block_size}]
        set addr [expr {$INPUT_MEM_BASE + ($offset * 4)}]
        set remaining [expr {$num_words - $offset}]
        set count [expr {$remaining < $block_size ? $remaining : $block_size}]

        set block [lrange $words $offset [expr {$offset + $count - 1}]]
        master_write_32 $jtag_master $addr $block

        # Progreso
        set progress [expr {($i + 1) * 100 / $blocks}]
        puts -nonewline "\rProgreso: $progress% ([expr {$i + 1}]/$blocks bloques)"
        flush stdout
    }

    puts "\n\nImagen cargada exitosamente ✓"
    puts "  - $total_pixels píxeles"
    puts "  - $num_words words (32-bit)"
    puts "  - [expr {$size_bytes / 1024}] KB"

    return 0
}

# ============================================================================
# Función: Verificar imagen cargada (leer primeros píxeles)
# ============================================================================
proc verify_loaded_image {width height {num_pixels 16}} {
    global INPUT_MEM_BASE jtag_master

    puts "\n=========================================="
    puts "Verificando imagen cargada"
    puts "=========================================="

    # Leer primeras words
    set num_words [expr {($num_pixels + 3) / 4}]
    set words [master_read_32 $jtag_master $INPUT_MEM_BASE $num_words]

    # Convertir words a bytes
    set pixels {}
    foreach word $words {
        for {set i 0} {$i < 4} {incr i} {
            set byte [expr {($word >> ($i * 8)) & 0xFF}]
            lappend pixels $byte
            if {[llength $pixels] == $num_pixels} {
                break
            }
        }
    }

    puts "Primeros $num_pixels píxeles:"
    set idx 0
    foreach pixel $pixels {
        puts -nonewline "[format %3d $pixel] "
        incr idx
        if {$idx % 16 == 0} {
            puts ""
        }
    }
    puts "\n"
}

# ============================================================================
# Función: Guardar imagen de salida a archivo
# ============================================================================
proc save_output_image {filename width height} {
    global OUTPUT_MEM_BASE jtag_master

    puts "\n=========================================="
    puts "Guardando imagen de salida"
    puts "=========================================="
    puts "Archivo: $filename"
    puts "Dimensiones: ${width}×${height}"

    set total_pixels [expr {$width * $height}]
    set num_words [expr {($total_pixels + 3) / 4}]

    puts "Leyendo $total_pixels píxeles de BRAM..."

    # Leer en bloques
    set words {}
    set block_size 1024
    set blocks [expr {($num_words + $block_size - 1) / $block_size}]

    for {set i 0} {$i < $blocks} {incr i} {
        set offset [expr {$i * $block_size}]
        set addr [expr {$OUTPUT_MEM_BASE + ($offset * 4)}]
        set remaining [expr {$num_words - $offset}]
        set count [expr {$remaining < $block_size ? $remaining : $block_size}]

        set block [master_read_32 $jtag_master $addr $count]
        set words [concat $words $block]

        set progress [expr {($i + 1) * 100 / $blocks}]
        puts -nonewline "\rProgreso: $progress% ([expr {$i + 1}]/$blocks bloques)"
        flush stdout
    }

    puts "\n"

    # Convertir words a píxeles
    set pixels {}
    foreach word $words {
        for {set i 0} {$i < 4} {incr i} {
            set byte [expr {($word >> ($i * 8)) & 0xFF}]
            lappend pixels $byte
            if {[llength $pixels] == $total_pixels} {
                break
            }
        }
    }

    # Guardar a archivo (formato espacio-separado, como original)
    set fp [open $filename w]
    for {set y 0} {$y < $height} {incr y} {
        for {set x 0} {$x < $width} {incr x} {
            set idx [expr {$y * $width + $x}]
            set pixel [lindex $pixels $idx]
            puts -nonewline $fp "$pixel"
            if {$x < $width - 1} {
                puts -nonewline $fp " "
            }
        }
        puts $fp ""
    }
    close $fp

    puts "Imagen guardada ✓"
    puts "  - $total_pixels píxeles"
    puts "  - $filename"
}

# ============================================================================
# Mensajes de ayuda
# ============================================================================
puts "\n=============================================="
puts "DSA Downscaler - Cargador de Imágenes TXT"
puts "=============================================="
puts "Comandos disponibles:"
puts "  load_image_from_txt <file> <width> <height>"
puts "  verify_loaded_image <width> <height> \[num_pixels\]"
puts "  save_output_image <file> <width> <height>"
puts "\nEjemplo:"
puts "  load_image_from_txt \"../imagen_grayscale.txt\" 512 512"
puts "  verify_loaded_image 512 512 16"
puts "  save_output_image \"output.txt\" 256 256"
puts "=============================================="
