# ============================================================================
# jtag_downscale_server.tcl
# Servidor TCL para control de sistema de downscaling via JTAG
# Para ejecutar en System Console de Quartus
# Arquitectura de Computadores 2 - FASE 6
# ============================================================================

package require Tcl 8.5

# ============================================================================
# Configuración
# ============================================================================
set SERVER_PORT 2540

# Mapa de registros (debe coincidir con jtag_register_map.sv)
set REG_CONTROL     0x00
set REG_STATUS      0x01
set REG_IMG_WR_ADDR 0x02
set REG_IMG_WR_DATA 0x03
set REG_IMG_RD_ADDR 0x04
set REG_IMG_RD_DATA 0x05
set REG_PIXEL_COUNT 0x06

# Dimensiones de imágenes
set INPUT_WIDTH  64
set INPUT_HEIGHT 64
set OUTPUT_WIDTH 32
set OUTPUT_HEIGHT 32

# ============================================================================
# Variables globales
# ============================================================================
set jtag_master ""
set socket_server ""

# ============================================================================
# Funciones de bajo nivel JTAG (System Console)
# ============================================================================

proc openport {} {
    global jtag_master

    if {$jtag_master == ""} {
        # Obtener el primer JTAG master disponible
        set masters [get_service_paths master]

        if {[llength $masters] == 0} {
            error "No se encontró ningún JTAG master. Verifica que la FPGA esté conectada y programada."
        }

        set jtag_master [lindex $masters 0]
        puts "JTAG Master encontrado: $jtag_master"

        # Abrir el servicio
        open_service master $jtag_master
        puts "Servicio JTAG abierto correctamente"
    }
}

proc closeport {} {
    global jtag_master

    if {$jtag_master != ""} {
        catch {close_service master $jtag_master}
        set jtag_master ""
    }
}

proc jtag_shift_40bit {rw_bit addr_byte data_word} {
    global jtag_master

    # Formato de comando de 40 bits:
    # [39] = R/W (1=Write, 0=Read)
    # [38:31] = Address (8 bits)
    # [31:0] = Data (32 bits)

    # Construir el valor de 40 bits como entero
    # Formato: [RW(1)][ADDR(8)][DATA(32)] pero en little-endian para shift

    set cmd_value [expr {($rw_bit << 39) | ($addr_byte << 31) | ($data_word & 0xFFFFFFFF)}]

    # Convertir a hexadecimal de 10 dígitos (40 bits / 4 = 10 hex digits)
    set cmd_hex [format "0x%010X" $cmd_value]

    # Ejecutar JTAG shift usando master_write_32
    # El Virtual JTAG aparece como un endpoint accesible via master

    if {[catch {
        # Escribir comando (esto varía según la implementación)
        # Para Virtual JTAG, típicamente se usa un índice base 0
        set result [master_write_32 $jtag_master 0x0 $data_word]

        # Para lectura, también se hace write y luego read
        if {$rw_bit == 0} {
            set result [master_read_32 $jtag_master 0x0 1]
            return [lindex $result 0]
        } else {
            return 0
        }
    } error_msg]} {
        error "Error en JTAG shift: $error_msg"
    }
}

# ============================================================================
# Funciones de lectura/escritura de registros (SIMPLIFICADAS)
# ============================================================================

proc write_register {addr data} {
    global jtag_master

    if {[catch {
        openport
        # Escribir directamente usando el offset de dirección
        set offset [expr {$addr * 4}]
        master_write_32 $jtag_master $offset $data
        return "OK"
    } error_msg]} {
        closeport
        error $error_msg
    }
}

proc read_register {addr} {
    global jtag_master

    if {[catch {
        openport
        # Leer directamente usando el offset de dirección
        set offset [expr {$addr * 4}]
        set result [master_read_32 $jtag_master $offset 1]
        return [lindex $result 0]
    } error_msg]} {
        closeport
        error $error_msg
    }
}

# ============================================================================
# Funciones de alto nivel para control del sistema
# ============================================================================

proc start_downscaling {} {
    global REG_CONTROL

    puts "Iniciando downscaling..."

    # Escribir bit 0 = 1 en registro CONTROL
    write_register $REG_CONTROL 0x00000001

    # Esperar un ciclo y limpiar
    after 10
    write_register $REG_CONTROL 0x00000000

    puts "Comando START enviado"
}

proc reset_system {} {
    global REG_CONTROL

    puts "Reseteando memorias..."

    # Escribir bit 1 = 1 en registro CONTROL
    write_register $REG_CONTROL 0x00000002

    # Esperar y limpiar
    after 10
    write_register $REG_CONTROL 0x00000000

    puts "Reset completado"
}

proc get_status {} {
    global REG_STATUS REG_CONTROL REG_PIXEL_COUNT

    set status_reg [read_register $REG_STATUS]
    set control_reg [read_register $REG_CONTROL]
    set pixel_count [read_register $REG_PIXEL_COUNT]

    set done [expr {$status_reg & 0x01}]
    set busy [expr {($control_reg >> 7) & 0x01}]
    set fsm_state [expr {($status_reg >> 8) & 0x07}]

    puts "========================================="
    puts "Estado del Sistema"
    puts "========================================="
    puts "BUSY:        $busy"
    puts "DONE:        $done"
    puts "FSM State:   $fsm_state"
    puts "Pixels:      $pixel_count / 1024"
    puts "========================================="

    return [list $busy $done $fsm_state $pixel_count]
}

proc wait_for_completion {{timeout_ms 10000}} {
    set start_time [clock milliseconds]

    puts "Esperando que termine el procesamiento..."

    while {1} {
        set status [get_status]
        set busy [lindex $status 0]
        set done [lindex $status 1]
        set pixels [lindex $status 3]

        if {$done == 1 && $busy == 0} {
            puts "Procesamiento completado: $pixels píxeles procesados"
            return 1
        }

        set elapsed [expr {[clock milliseconds] - $start_time}]
        if {$elapsed > $timeout_ms} {
            puts "TIMEOUT: El procesamiento no terminó en ${timeout_ms}ms"
            return 0
        }

        after 100
    }
}

# ============================================================================
# Funciones de transferencia de imágenes
# ============================================================================

proc upload_image {image_data} {
    global REG_IMG_WR_ADDR REG_IMG_WR_DATA INPUT_WIDTH INPUT_HEIGHT

    set total_pixels [expr {$INPUT_WIDTH * $INPUT_HEIGHT}]

    if {[llength $image_data] != $total_pixels} {
        error "Tamaño de imagen incorrecto. Esperado: $total_pixels, Recibido: [llength $image_data]"
    }

    puts "Subiendo imagen de ${INPUT_WIDTH}x${INPUT_HEIGHT}..."

    # Inicializar dirección de escritura en 0
    write_register $REG_IMG_WR_ADDR 0x00000000

    # Escribir píxeles uno por uno (con auto-incremento)
    set progress 0
    for {set i 0} {$i < $total_pixels} {incr i} {
        set pixel [lindex $image_data $i]

        # Validar rango de píxel
        if {$pixel < 0 || $pixel > 255} {
            error "Valor de píxel fuera de rango en posición $i: $pixel"
        }

        write_register $REG_IMG_WR_DATA $pixel

        # Mostrar progreso cada 512 píxeles
        if {($i % 512) == 0} {
            set progress [expr {($i * 100) / $total_pixels}]
            puts "Progreso: ${progress}% ($i/$total_pixels píxeles)"
        }
    }

    puts "Imagen subida completamente: $total_pixels píxeles"
}

proc download_image {} {
    global REG_IMG_RD_ADDR REG_IMG_RD_DATA OUTPUT_WIDTH OUTPUT_HEIGHT

    set total_pixels [expr {$OUTPUT_WIDTH * $OUTPUT_HEIGHT}]
    set image_data [list]

    puts "Descargando imagen de ${OUTPUT_WIDTH}x${OUTPUT_HEIGHT}..."

    # Inicializar dirección de lectura en 0
    write_register $REG_IMG_RD_ADDR 0x00000000

    # Leer píxeles uno por uno (con auto-incremento)
    set progress 0
    for {set i 0} {$i < $total_pixels} {incr i} {
        set pixel [read_register $REG_IMG_RD_DATA]

        # Extraer solo los 8 bits LSB
        set pixel [expr {$pixel & 0xFF}]

        lappend image_data $pixel

        # Mostrar progreso cada 256 píxeles
        if {($i % 256) == 0} {
            set progress [expr {($i * 100) / $total_pixels}]
            puts "Progreso: ${progress}% ($i/$total_pixels píxeles)"
        }
    }

    puts "Imagen descargada completamente: $total_pixels píxeles"

    return $image_data
}

# ============================================================================
# Función principal: procesar imagen completa
# ============================================================================

proc process_image {input_image} {
    puts "\n========================================="
    puts "Procesamiento de Imagen - Downscaling"
    puts "========================================="

    # 1. Subir imagen de entrada
    upload_image $input_image

    # 2. Verificar status inicial
    get_status

    # 3. Iniciar downscaling
    start_downscaling

    # 4. Esperar a que termine
    if {![wait_for_completion 30000]} {
        error "El procesamiento no se completó"
    }

    # 5. Descargar imagen de salida
    set output_image [download_image]

    puts "========================================="
    puts "Procesamiento completado exitosamente"
    puts "========================================="

    return $output_image
}

# ============================================================================
# Servidor de sockets TCP
# ============================================================================

proc handle_client {sock addr port} {
    puts "Cliente conectado desde ${addr}:${port}"

    fconfigure $sock -buffering line -translation auto

    if {[catch {
        # Leer comando del cliente
        gets $sock command
        puts "Comando recibido: $command"

        switch -glob $command {
            "STATUS" {
                set status [get_status]
                puts $sock "OK [lindex $status 0] [lindex $status 1] [lindex $status 2] [lindex $status 3]"
            }

            "START" {
                start_downscaling
                puts $sock "OK"
            }

            "RESET" {
                reset_system
                puts $sock "OK"
            }

            "UPLOAD *" {
                # Formato: UPLOAD <num_pixels> <pixel1> <pixel2> ... <pixelN>
                set parts [split $command]
                set num_pixels [lindex $parts 1]
                set pixels [lrange $parts 2 end]

                if {[llength $pixels] != $num_pixels} {
                    puts $sock "ERROR Número de píxeles incorrecto"
                } else {
                    upload_image $pixels
                    puts $sock "OK"
                }
            }

            "DOWNLOAD" {
                set image [download_image]
                puts $sock "OK [llength $image] $image"
            }

            "PROCESS *" {
                # Formato: PROCESS <num_pixels> <pixel1> <pixel2> ... <pixelN>
                set parts [split $command]
                set num_pixels [lindex $parts 1]
                set pixels [lrange $parts 2 end]

                if {[llength $pixels] != $num_pixels} {
                    puts $sock "ERROR Número de píxeles incorrecto"
                } else {
                    set result [process_image $pixels]
                    puts $sock "OK [llength $result] $result"
                }
            }

            "CLOSE" {
                puts $sock "OK"
                closeport
                close $sock
                return
            }

            default {
                puts $sock "ERROR Comando desconocido: $command"
            }
        }
    } error_msg]} {
        puts $sock "ERROR $error_msg"
        puts "Error procesando comando: $error_msg"
    }

    close $sock
    puts "Cliente desconectado"
}

proc start_server {} {
    global SERVER_PORT socket_server

    puts "========================================="
    puts "Servidor JTAG Downscaling"
    puts "========================================="
    puts "Puerto: $SERVER_PORT"

    # Intentar abrir JTAG al inicio
    puts "Verificando conexión JTAG..."
    if {[catch {
        openport
        puts "JTAG conectado correctamente"
    } error_msg]} {
        puts "ADVERTENCIA: No se pudo conectar JTAG inicialmente: $error_msg"
        puts "Se intentará conectar cuando lleguen comandos..."
    }

    puts "Esperando conexiones..."
    puts "========================================="

    set socket_server [socket -server handle_client $SERVER_PORT]

    vwait forever
}

# ============================================================================
# Punto de entrada
# ============================================================================

if {[catch {
    start_server
} error_msg]} {
    puts "Error iniciando servidor: $error_msg"
    closeport
    exit 1
}
