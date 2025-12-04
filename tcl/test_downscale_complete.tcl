# ============================================================================
# test_downscale_complete.tcl
# ============================================================================
# Script completo que:
#   1. Carga imagen desde archivo .txt
#   2. Configura DSA (modo Secuencial)
#   3. Inicia procesamiento
#   4. Monitorea progreso en tiempo real
#   5. Lee resultado y lo guarda
#
# Uso:
#   source test_downscale_complete.tcl
#   test_downscale_complete "../imagen_grayscale.txt" 512 512 256 256
#
# Autor: DSA Project Team
# Fecha: Diciembre 2025
# ============================================================================

source [file join [file dirname [info script]] test_basic_jtag.tcl]
source [file join [file dirname [info script]] load_image_txt.tcl]
source [file join [file dirname [info script]] diagnose_busy.tcl]

# ============================================================================
# Función: Test completo de downscaling con monitoreo
# ============================================================================
proc test_downscale_complete {image_file width_in height_in width_out height_out} {
    global DSA_BASE_ADDR
    global REG_STATUS REG_PERF_CYCLES REG_PERF_READS REG_PERF_WRITES
    global REG_IMG_WIDTH_IN REG_IMG_HEIGHT_IN REG_IMG_WIDTH_OUT REG_IMG_HEIGHT_OUT
    global REG_CTRL REG_INPUT_BASE REG_OUTPUT_BASE
    global INPUT_MEM_BASE OUTPUT_MEM_BASE

    puts "\n"
    puts "================================================================"
    puts "  TEST COMPLETO DE DOWNSCALING - MODO SECUENCIAL"
    puts "================================================================"
    puts "  Entrada:  ${width_in}x${height_in}"
    puts "  Salida:   ${width_out}x${height_out}"
    puts "  Archivo:  $image_file"
    puts "================================================================"

    # ========================================================================
    # PASO 1: Conectar a JTAG
    # ========================================================================
    puts "\nPASO 1/6: Conectando a JTAG..."
    if {[connect_jtag] != 0} {
        puts "ERROR: No se pudo conectar a JTAG"
        return -1
    }
    puts "Conexion establecida"

    # ========================================================================
    # PASO 2: Verificar estado inicial
    # ========================================================================
    puts "\nPASO 2/6: Verificando estado inicial..."
    set status [read_reg $DSA_BASE_ADDR $REG_STATUS]
    set busy [expr {($status >> 0) & 0x1}]
    set done [expr {($status >> 1) & 0x1}]

    if {$busy} {
        puts "ADVERTENCIA: Sistema ya esta en busy"
        puts "   Esperando a que termine o limpie el sistema..."
        
        # Esperar un poco
        set timeout 5000
        set start_time [clock milliseconds]
        
        while {$busy && $timeout > 0} {
            after 100
            set status [read_reg $DSA_BASE_ADDR $REG_STATUS]
            set busy [expr {($status >> 0) & 0x1}]
            set elapsed [expr {[clock milliseconds] - $start_time}]
            set timeout [expr {$timeout - $elapsed}]
        }
        
        if {$busy} {
            puts "ERROR: Sistema sigue en busy despues de 5 segundos"
            puts "   Puede necesitar reset del sistema"
            return -2
        } else {
            puts "Sistema ahora esta idle"
        }
    } else {
        puts "Sistema esta idle y listo"
    }

    # ========================================================================
    # PASO 3: Cargar imagen de entrada
    # ========================================================================
    puts "\nPASO 3/6: Cargando imagen de entrada..."
    
    if {[file exists $image_file]} {
        if {[load_image_from_txt $image_file $width_in $height_in] != 0} {
            puts "ERROR: No se pudo cargar la imagen"
            return -3
        }
        puts "Imagen cargada"
        
        # Verificar primeros píxeles
        verify_loaded_image $width_in $height_in 16
    } else {
        puts "ADVERTENCIA: Archivo no encontrado: $image_file"
        puts "   Generando imagen de prueba (gradiente)..."
        
        # Generar imagen de prueba
        set test_pixels {}
        for {set y 0} {$y < $height_in} {incr y} {
            for {set x 0} {$x < $width_in} {incr x} {
                set value [expr {($x + $y) * 255 / ($width_in + $height_in - 2)}]
                lappend test_pixels $value
            }
        }
        
        # Escribir imagen de prueba
        set words {}
        set word 0
        set byte_idx 0
        
        foreach pixel $test_pixels {
            set word [expr {$word | (($pixel & 0xFF) << ($byte_idx * 8))}]
            incr byte_idx
            
            if {$byte_idx == 4} {
                lappend words $word
                set word 0
                set byte_idx 0
            }
        }
        
        if {$byte_idx > 0} {
            lappend words $word
        }
        
        master_write_32 $::jtag_master $INPUT_MEM_BASE $words
        puts "Imagen de prueba generada y cargada"
    }

    # ========================================================================
    # PASO 4: Configurar DSA
    # ========================================================================
    puts "\nPASO 4/6: Configurando DSA..."
    
    # Configurar dimensiones
    write_reg $DSA_BASE_ADDR $REG_IMG_WIDTH_IN $width_in
    write_reg $DSA_BASE_ADDR $REG_IMG_HEIGHT_IN $height_in
    write_reg $DSA_BASE_ADDR $REG_IMG_WIDTH_OUT $width_out
    write_reg $DSA_BASE_ADDR $REG_IMG_HEIGHT_OUT $height_out
    
    # Configurar direcciones base (BRAM)
    write_reg $DSA_BASE_ADDR $REG_INPUT_BASE $INPUT_MEM_BASE
    write_reg $DSA_BASE_ADDR $REG_OUTPUT_BASE $OUTPUT_MEM_BASE
    
    # Configurar modo: Secuencial (mode=0), manual dimensions (bit 8=1)
    write_reg $DSA_BASE_ADDR $REG_CTRL 0x00000100  ;# bit 8 = manual dimensions
    
    # Verificar configuración
    set w_in_verify [read_reg $DSA_BASE_ADDR $REG_IMG_WIDTH_IN]
    set h_in_verify [read_reg $DSA_BASE_ADDR $REG_IMG_HEIGHT_IN]
    set w_out_verify [read_reg $DSA_BASE_ADDR $REG_IMG_WIDTH_OUT]
    set h_out_verify [read_reg $DSA_BASE_ADDR $REG_IMG_HEIGHT_OUT]
    
    if {$w_in_verify != $width_in || $h_in_verify != $height_in || 
        $w_out_verify != $width_out || $h_out_verify != $height_out} {
        puts "ERROR: Configuracion no coincide"
        puts "   Esperado: ${width_in}x${height_in} -> ${width_out}x${height_out}"
        puts "   Leido:    ${w_in_verify}x${h_in_verify} -> ${w_out_verify}x${h_out_verify}"
        return -4
    }
    
    puts "Configuracion aplicada:"
    puts "   Entrada:  ${w_in_verify}x${h_in_verify}"
    puts "   Salida:   ${w_out_verify}x${h_out_verify}"
    puts "   Modo:     Secuencial"

    # ========================================================================
    # PASO 5: Resetear contadores e iniciar procesamiento
    # ========================================================================
    puts "\nPASO 5/6: Iniciando procesamiento..."
    
    # Resetear contadores
    reset_perf_counters
    
    # Leer CTRL actual
    set ctrl [read_reg $DSA_BASE_ADDR $REG_CTRL]
    
    # Activar start (bit 0) manteniendo configuración
    set ctrl [expr {$ctrl | 0x1}]
    write_reg $DSA_BASE_ADDR $REG_CTRL $ctrl
    
    puts "Start signal enviado"
    
    # Verificar que busy se activó
    after 50
    set status [read_reg $DSA_BASE_ADDR $REG_STATUS]
    set busy [expr {($status >> 0) & 0x1}]
    
    if {!$busy} {
        puts "ERROR: busy NO se activo despues de start"
        puts "   El sistema no inició el procesamiento"
        return -5
    }
    
    puts "Sistema inicio procesamiento (busy=1)"

    # ========================================================================
    # PASO 6: Monitorear progreso y esperar finalización
    # ========================================================================
    puts "\nPASO 6/6: Monitoreando progreso..."
    puts ""
    
    set start_time [clock milliseconds]
    set prev_cycles 0
    set prev_reads 0
    set prev_writes 0
    set sample_count 0
    set max_timeout_seconds 300  ;# 5 minutos máximo
    
    puts [format "%-8s %-6s %-6s %-12s %-12s %-12s %-10s %-10s" \
              "Tiempo" "busy" "done" "CYCLES" "READS" "WRITES" "ΔREADS" "Progreso"]
    puts [string repeat "-" 85]
    
    while {1} {
        # Leer estado y contadores
        set status [read_reg $DSA_BASE_ADDR $REG_STATUS]
        set cycles [read_reg $DSA_BASE_ADDR $REG_PERF_CYCLES]
        set reads [read_reg $DSA_BASE_ADDR $REG_PERF_READS]
        set writes [read_reg $DSA_BASE_ADDR $REG_PERF_WRITES]
        
        set busy [expr {($status >> 0) & 0x1}]
        set done [expr {($status >> 1) & 0x1}]
        
        set elapsed_ms [expr {[clock milliseconds] - $start_time}]
        set elapsed_sec [expr {$elapsed_ms / 1000.0}]
        
        set cycles_delta [expr {$cycles - $prev_cycles}]
        set reads_delta [expr {$reads - $prev_reads}]
        set writes_delta [expr {$writes - $prev_writes}]
        
        # Calcular progreso estimado
        set total_pixels [expr {$width_out * $height_out}]
        set expected_reads [expr {$total_pixels * 4}]  ;# 4 lecturas por píxel
        
        set progress_percent 0
        if {$expected_reads > 0} {
            set progress_percent [expr {($reads * 100.0) / $expected_reads}]
            if {$progress_percent > 100} {
                set progress_percent 100
            }
        }
        
        # Mostrar estado cada segundo
        if {$sample_count % 2 == 0} {
            puts [format "%-8.1f %-6s %-6s %-12d %-12d %-12d %-10d %-9.1f%%" \
                      $elapsed_sec $busy $done $cycles $reads $writes $reads_delta $progress_percent]
        }
        
        # Verificar si terminó
        if {$done} {
            puts ""
            puts "Procesamiento completado!"
            break
        }
        
        # Verificar timeout
        if {$elapsed_sec > $max_timeout_seconds} {
            puts ""
            puts "ERROR: Timeout despues de ${max_timeout_seconds} segundos"
            puts "   Sistema aún en busy - ejecutando diagnóstico..."
            
            # Ejecutar diagnóstico
            diagnose_busy_stuck
            return -6
        }
        
        # Detectar si está bloqueado (no hay progreso)
        if {$sample_count > 10 && $reads_delta == 0 && $cycles_delta > 50000} {
            puts ""
            puts "ADVERTENCIA: Lecturas no aumentan aunque ciclos si"
            puts "   Posible bloqueo en lectura de memoria"
            puts "   Ejecutando diagnóstico..."
            
            diagnose_busy_stuck
            return -7
        }
        
        set prev_cycles $cycles
        set prev_reads $reads
        set prev_writes $writes
        
        incr sample_count
        after 500  ;# Monitoreo cada 500ms
    }
    
    # Leer contadores finales
    set final_cycles [read_reg $DSA_BASE_ADDR $REG_PERF_CYCLES]
    set final_reads [read_reg $DSA_BASE_ADDR $REG_PERF_READS]
    set final_writes [read_reg $DSA_BASE_ADDR $REG_PERF_WRITES]
    
    set total_time_sec [expr {$elapsed_ms / 1000.0}]
    set freq_mhz [expr {double($final_cycles) / ($total_time_sec * 1000000.0)}]
    
    puts ""
    puts "================================================================"
    puts "  RESULTADOS DE PERFORMANCE"
    puts "================================================================"
    puts "  Tiempo total:        [format %.2f $total_time_sec] segundos"
    puts "  Ciclos totales:      $final_cycles"
    puts "  Frecuencia efectiva: [format %.2f $freq_mhz] MHz"
    puts "  Lecturas:            $final_reads"
    puts "  Escrituras:          $final_writes"
    puts "  Throughput:          [format %.2f [expr {$total_pixels / $total_time_sec}]] pixeles/seg"
    puts "================================================================"

    # ========================================================================
    # PASO 7: Leer y guardar resultado
    # ========================================================================
    puts "\nEXTRA: Guardando imagen de salida..."
    
    set output_file "../imagen_output_complete.txt"
    save_output_image $output_file $width_out $height_out
    
    puts "Imagen guardada en: $output_file"
    
    # Mostrar primeros píxeles del resultado
    puts "\nPrimeros píxeles del resultado:"
    verify_loaded_image $width_out $height_out 16 $OUTPUT_MEM_BASE
    
    puts "\n"
    puts "================================================================"
    puts "  TEST COMPLETADO EXITOSAMENTE"
    puts "================================================================"
    
    return 0
}

# ============================================================================
# Función: Test rápido con imagen pequeña (para pruebas)
# ============================================================================
proc test_downscale_quick {} {
    puts "\n=========================================="
    puts "TEST RAPIDO: Downscale 4x4 -> 2x2"
    puts "=========================================="
    
    # Generar imagen simple de prueba
    set test_pixels {
        0   64  128 192
        32  96  160 224
        64  128 192 255
        96  160 224 255
    }
    
    # Cargar scripts necesarios
    source [file join [file dirname [info script]] test_basic_jtag.tcl]
    
    # Conectar
    if {[connect_jtag] != 0} {
        return -1
    }
    
    # Escribir imagen de prueba
    set words {}
    set word 0
    set byte_idx 0
    
    foreach pixel $test_pixels {
        set word [expr {$word | (($pixel & 0xFF) << ($byte_idx * 8))}]
        incr byte_idx
        
        if {$byte_idx == 4} {
            lappend words $word
            set word 0
            set byte_idx 0
        }
    }
    
    master_write_32 $::jtag_master $INPUT_MEM_BASE $words
    
    # Ejecutar test completo
    return [test_downscale_complete "" 4 4 2 2]
}

# ============================================================================
# Función: Verificar imagen desde memoria (override para output)
# ============================================================================
proc verify_loaded_image {width height {num_pixels 16} {base_addr 0x00000000}} {
    global jtag_master

    # Leer primeras words
    set num_words [expr {($num_pixels + 3) / 4}]
    set words [master_read_32 $jtag_master $base_addr $num_words]

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

    puts "Primeros $num_pixels píxeles (desde 0x[format %08X $base_addr]):"
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
# Mensajes de ayuda
# ============================================================================
puts "\n=============================================="
puts "DSA Downscaler - Test Completo"
puts "=============================================="
puts "Comandos disponibles:"
puts "  test_downscale_complete <file> <w_in> <h_in> <w_out> <h_out>"
puts "  test_downscale_quick    - Test rapido 4x4 -> 2x2 (sin archivo)"
puts ""
puts "Ejemplos:"
puts "  test_downscale_complete \"../imagen_grayscale.txt\" 512 512 256 256"
puts "  test_downscale_complete \"../imagen_grayscale.txt\" 256 256 128 128"
puts "  test_downscale_quick"
puts ""
puts "El script:"
puts "  1. Conecta a JTAG"
puts "  2. Carga imagen desde archivo (o genera prueba si no existe)"
puts "  3. Configura DSA (modo Secuencial)"
puts "  4. Inicia procesamiento"
puts "  5. Monitorea progreso en tiempo real"
puts "  6. Guarda resultado en ../imagen_output_complete.txt"
puts "=============================================="

