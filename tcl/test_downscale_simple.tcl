# ============================================================================
# test_downscale_simple.tcl
# ============================================================================
# Script para ejecutar un test simple de downscaling con patrón conocido
#
# Test: Downscale de 4×4 → 2×2 (factor 0.5) con patrón gradiente
#
# Uso:
#   source test_basic_jtag.tcl
#   source test_downscale_simple.tcl
#   test_downscale_4x4_to_2x2
#
# Autor: DSA Project Team
# Fecha: Diciembre 2025
# ============================================================================

source [file join [file dirname [info script]] test_basic_jtag.tcl]

# ============================================================================
# Función: Escribir imagen de entrada (byte por byte)
# ============================================================================
proc write_input_image {width height pixel_data} {
    global INPUT_MEM_BASE jtag_master

    puts "\nEscribiendo imagen de entrada (${width}×${height})..."

    set total_pixels [expr $width * $height]

    if {[llength $pixel_data] != $total_pixels} {
        puts "ERROR: Se esperaban $total_pixels píxeles, pero se recibieron [llength $pixel_data]"
        return -1
    }

    # Convertir bytes a words de 32 bits (4 bytes por word)
    set words {}
    set word 0
    set byte_idx 0

    foreach pixel $pixel_data {
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

    # Escribir a memoria
    master_write_32 $jtag_master $INPUT_MEM_BASE $words

    puts "Imagen escrita ✓ ($total_pixels píxeles = [llength $words] words)"
    return 0
}

# ============================================================================
# Función: Leer imagen de salida (byte por byte)
# ============================================================================
proc read_output_image {width height} {
    global OUTPUT_MEM_BASE jtag_master

    puts "\nLeyendo imagen de salida (${width}×${height})..."

    set total_pixels [expr $width * $height]
    set num_words [expr {($total_pixels + 3) / 4}]  ;# Redondear hacia arriba

    # Leer words
    set words [master_read_32 $jtag_master $OUTPUT_MEM_BASE $num_words]

    # Convertir words a bytes
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

    puts "Imagen leída ✓ ($total_pixels píxeles)"
    return $pixels
}

# ============================================================================
# Función: Configurar DSA para downscaling
# ============================================================================
proc configure_dsa {width_in height_in width_out height_out mode} {
    global DSA_BASE_ADDR
    global REG_IMG_WIDTH_IN REG_IMG_HEIGHT_IN
    global REG_IMG_WIDTH_OUT REG_IMG_HEIGHT_OUT
    global REG_CTRL

    puts "\nConfigurando DSA..."
    puts "  Entrada:  ${width_in}×${height_in}"
    puts "  Salida:   ${width_out}×${height_out}"
    puts "  Modo:     [expr {$mode ? "SIMD" : "Secuencial"}]"

    # Escribir dimensiones
    write_reg $DSA_BASE_ADDR $REG_IMG_WIDTH_IN $width_in
    write_reg $DSA_BASE_ADDR $REG_IMG_HEIGHT_IN $height_in
    write_reg $DSA_BASE_ADDR $REG_IMG_WIDTH_OUT $width_out
    write_reg $DSA_BASE_ADDR $REG_IMG_HEIGHT_OUT $height_out

    # Control: bit [8]=1 (manual dimensions), bit [2]=mode
    set ctrl_val [expr {0x100 | ($mode << 2)}]
    write_reg $DSA_BASE_ADDR $REG_CTRL $ctrl_val

    puts "DSA configurado ✓"
}

# ============================================================================
# Función: Iniciar procesamiento
# ============================================================================
proc start_processing {} {
    global DSA_BASE_ADDR REG_CTRL REG_STATUS

    puts "\nIniciando procesamiento..."

    # Resetear contadores primero
    reset_perf_counters

    # Leer control actual
    set ctrl [read_reg $DSA_BASE_ADDR $REG_CTRL]

    # Setear bit start (bit 0)
    set ctrl [expr {$ctrl | 0x1}]
    write_reg $DSA_BASE_ADDR $REG_CTRL $ctrl

    puts "Start signal enviado ✓"
}

# ============================================================================
# Función: Esperar a que termine
# ============================================================================
proc wait_for_completion {timeout_ms} {
    global DSA_BASE_ADDR REG_STATUS

    puts "\nEsperando finalización (timeout: ${timeout_ms}ms)..."

    set start_time [clock milliseconds]

    while {1} {
        set status [read_reg $DSA_BASE_ADDR $REG_STATUS]
        set busy [expr {($status >> 0) & 0x1}]
        set done [expr {($status >> 1) & 0x1}]
        set error [expr {($status >> 2) & 0x1}]

        if {$done} {
            puts "Procesamiento completado ✓"
            return 0
        }

        if {$error} {
            puts "ERROR: DSA reportó error"
            return -1
        }

        set elapsed [expr {[clock milliseconds] - $start_time}]
        if {$elapsed > $timeout_ms} {
            puts "ERROR: Timeout (busy=$busy, done=$done)"
            return -1
        }

        after 10
    }
}

# ============================================================================
# Función: Mostrar imagen en formato ASCII
# ============================================================================
proc display_image {width height pixels {label "Imagen"}} {
    puts "\n$label (${width}×${height}):"
    puts "┌[string repeat ─ [expr $width * 4 + 1]]┐"

    for {set y 0} {$y < $height} {incr y} {
        puts -nonewline "│ "
        for {set x 0} {$x < $width} {incr x} {
            set idx [expr {$y * $width + $x}]
            set pixel [lindex $pixels $idx]
            puts -nonewline [format "%3d " $pixel]
        }
        puts "│"
    }

    puts "└[string repeat ─ [expr $width * 4 + 1]]┘"
}

# ============================================================================
# TEST: Downscale 4×4 → 2×2
# ============================================================================
proc test_downscale_4x4_to_2x2 {} {
    puts "\n=========================================="
    puts "TEST: Downscale 4×4 → 2×2 (Secuencial)"
    puts "=========================================="

    # Conectar
    if {[connect_jtag] != 0} {
        return
    }

    # Imagen de entrada 4×4 (gradiente)
    set input_pixels {
        0   64  128 192
        32  96  160 224
        64  128 192 255
        96  160 224 255
    }

    # Escribir imagen de entrada
    if {[write_input_image 4 4 $input_pixels] != 0} {
        return
    }

    display_image 4 4 $input_pixels "Imagen de Entrada"

    # Configurar DSA (modo secuencial = 0)
    configure_dsa 4 4 2 2 0

    # Iniciar procesamiento
    start_processing

    # Esperar finalización
    if {[wait_for_completion 5000] != 0} {
        puts "\nTest FALLÓ ✗"
        return
    }

    # Leer imagen de salida
    set output_pixels [read_output_image 2 2]

    display_image 2 2 $output_pixels "Imagen de Salida"

    # Leer performance counters
    read_dsa_registers

    puts "\n=========================================="
    puts "Test completado"
    puts "=========================================="

    # Valores esperados aproximados (interpolación bilineal)
    # output[0,0] ≈ (0+64+32+96)/4 = 48
    # output[0,1] ≈ (128+192+160+224)/4 = 176
    # output[1,0] ≈ (64+128+96+160)/4 = 112
    # output[1,1] ≈ (192+255+224+255)/4 = 231.5

    puts "\nNOTA: Valores esperados (aproximados):"
    puts "  [0,0] ≈ 48   (promedio esquina superior izquierda)"
    puts "  [0,1] ≈ 176  (promedio esquina superior derecha)"
    puts "  [1,0] ≈ 112  (promedio esquina inferior izquierda)"
    puts "  [1,1] ≈ 232  (promedio esquina inferior derecha)"
}

# ============================================================================
# TEST: Downscale 8×8 → 4×4
# ============================================================================
proc test_downscale_8x8_to_4x4 {} {
    puts "\n=========================================="
    puts "TEST: Downscale 8×8 → 4×4 (SIMD)"
    puts "=========================================="

    # Conectar
    if {[connect_jtag] != 0} {
        return
    }

    # Imagen de entrada 8×8 (patrón checkerboard)
    set input_pixels {}
    for {set y 0} {$y < 8} {incr y} {
        for {set x 0} {$x < 8} {incr x} {
            if {($x + $y) % 2 == 0} {
                lappend input_pixels 0
            } else {
                lappend input_pixels 255
            }
        }
    }

    # Escribir imagen de entrada
    if {[write_input_image 8 8 $input_pixels] != 0} {
        return
    }

    display_image 8 8 $input_pixels "Imagen de Entrada"

    # Configurar DSA (modo SIMD = 1)
    configure_dsa 8 8 4 4 1

    # Iniciar procesamiento
    start_processing

    # Esperar finalización
    if {[wait_for_completion 10000] != 0} {
        puts "\nTest FALLÓ ✗"
        return
    }

    # Leer imagen de salida
    set output_pixels [read_output_image 4 4]

    display_image 4 4 $output_pixels "Imagen de Salida"

    # Leer performance counters
    read_dsa_registers

    puts "\n=========================================="
    puts "Test completado"
    puts "=========================================="

    puts "\nNOTA: Para patrón checkerboard, valores esperados ≈ 127-128 (promedio de 0 y 255)"
}

# ============================================================================
# Mensajes de ayuda
# ============================================================================
puts "\n=============================================="
puts "DSA Downscaler - Tests de Downscaling"
puts "=============================================="
puts "Comandos disponibles:"
puts "  test_downscale_4x4_to_2x2  - Test simple 4×4 → 2×2 (Secuencial)"
puts "  test_downscale_8x8_to_4x4  - Test 8×8 → 4×4 (SIMD)"
puts "  configure_dsa <w_in> <h_in> <w_out> <h_out> <mode>"
puts "  write_input_image <w> <h> <pixels>"
puts "  read_output_image <w> <h>"
puts "  start_processing"
puts "  wait_for_completion <timeout_ms>"
puts "\nEjemplo:"
puts "  test_downscale_4x4_to_2x2"
puts "=============================================="
