# ============================================================================
# jtag_downscale_server_sld.tcl
# Servidor TCL usando SLD (System Level Debug) para Virtual JTAG
# Para ejecutar en System Console de Quartus
# Arquitectura de Computadores 2 - FASE 6
# ============================================================================

package require Tcl 8.5

# ============================================================================
# Configuración
# ============================================================================
set SERVER_PORT 2540

# Mapa de registros
set REG_CONTROL     0x00
set REG_STATUS      0x01
set REG_IMG_WR_ADDR 0x02
set REG_IMG_WR_DATA 0x03
set REG_IMG_RD_ADDR 0x04
set REG_IMG_RD_DATA 0x05
set REG_PIXEL_COUNT 0x06

# Dimensiones
set INPUT_WIDTH  64
set INPUT_HEIGHT 64
set OUTPUT_WIDTH 32
set OUTPUT_HEIGHT 32

# ============================================================================
# Variables globales
# ============================================================================
set device_name ""
set sld_node ""
set socket_server ""

# ============================================================================
# Funciones JTAG usando comandos de Quartus Programmer
# ============================================================================

proc openport {} {
    global device_name hardware_name sld_node

    if {$device_name == ""} {
        puts "Buscando dispositivo JTAG..."

        # Obtener lista de dispositivos JTAG
        set hardware_list [get_hardware_names]

        if {[llength $hardware_list] == 0} {
            error "No se encontró ningún hardware JTAG conectado"
        }

        # Usar el primer hardware disponible
        set hardware_name [lindex $hardware_list 0]
        puts "Hardware encontrado: $hardware_name"

        # Obtener dispositivos en el hardware
        set device_list [get_device_names -hardware_name $hardware_name]

        if {[llength $device_list] == 0} {
            error "No se encontró dispositivo en el hardware"
        }

        # Buscar el dispositivo FPGA (no el HPS)
        set device_name ""
        foreach dev $device_list {
            if {[string match "*5CSE*" $dev] || [string match "*5CSEMA5F31C6*" $dev]} {
                set device_name $dev
                break
            }
        }

        # Si no encontramos el FPGA, usar el segundo dispositivo (normalmente es el FPGA)
        if {$device_name == "" && [llength $device_list] > 1} {
            set device_name [lindex $device_list 1]
        } elseif {$device_name == ""} {
            set device_name [lindex $device_list 0]
        }

        puts "Dispositivo seleccionado: $device_name"

        # Seleccionar dispositivo usando start_insystem_source_probe (compatible con quartus_stp)
        if {[catch {
            start_insystem_source_probe -device_name $device_name -hardware_name $hardware_name
            puts "Dispositivo abierto correctamente"
        } error_msg]} {
            puts "ADVERTENCIA: No se pudo abrir dispositivo: $error_msg"
            puts "Se intentará usar Virtual JTAG directamente..."
        }

        # El Virtual JTAG se accede vía device_virtual_ir_shift y device_virtual_dr_shift
        # No necesitamos buscar un "node" específico, usamos instance_index 0
        set sld_node 0
    }
}

proc closeport {} {
    global device_name hardware_name

    if {$device_name != ""} {
        # No necesitamos cerrar explícitamente con quartus_stp
        # El dispositivo se mantiene abierto mientras quartus_stp está corriendo
        set device_name ""
    }
}

# ============================================================================
# Lectura/Escritura de registros vía Virtual JTAG
# ============================================================================

proc jtag_transaction {is_write addr data} {
    global device_name hardware_name
    
    # Formato: 40 bits = [39:R/W][38:31:ADDR][31:0:DATA]
    # Construir comando
    set rw_bit [expr {$is_write ? 1 : 0}]

    # Crear valor de 40 bits como entero
    # Nota: TCL maneja enteros de 64 bits, así que podemos usar valores grandes
    set cmd_value [expr {($rw_bit << 39) | (($addr & 0xFF) << 31) | ($data & 0xFFFFFFFF)}]

    # Ejecutar shift JTAG
    if {[catch {
        # Intentar obtener lock del dispositivo
        if {[catch {device_lock -timeout 10000} lock_error]} {
            error "No se pudo obtener lock del dispositivo JTAG. Asegúrate de que el diseño esté programado."
        }

        # Cargar IR = 1 (USER1) - modo de acceso a registros
        if {[catch {
            device_virtual_ir_shift -instance_index 0 -ir_value 1 -no_captured_ir_value
        } ir_error]} {
            device_unlock
            error "Error cargando IR: $ir_error. Verifica que el diseño con Virtual JTAG esté programado en el FPGA."
        }

        # Shift DR de 40 bits usando el valor numérico directamente
        # device_virtual_dr_shift acepta valores numéricos (decimal, hex, etc.)
        if {[catch {
            set result_value [device_virtual_dr_shift -instance_index 0 -dr_value $cmd_value -length 40]
        } dr_error]} {
            device_unlock
            error "Error en shift DR: $dr_error. Verifica que el diseño con Virtual JTAG esté programado."
        }

        # Restaurar IR = 0 (bypass)
        if {[catch {
            device_virtual_ir_shift -instance_index 0 -ir_value 0 -no_captured_ir_value
        } ir2_error]} {
            # Intentar unlock aunque falle
            catch {device_unlock}
            error "Error restaurando IR: $ir2_error"
        }

        device_unlock

        # El resultado es un valor numérico, extraer los primeros 32 bits
        set result_data [expr {$result_value & 0xFFFFFFFF}]
        
        return $result_data
    } error_msg]} {
        catch {device_unlock}
        error "Error en transacción JTAG: $error_msg"
    }
}

proc write_register {addr data} {
    if {[catch {
        openport
        jtag_transaction 1 $addr $data
        return "OK"
    } error_msg]} {
        closeport
        error $error_msg
    }
}

proc read_register {addr} {
    if {[catch {
        openport
        set result [jtag_transaction 0 $addr 0]
        return $result
    } error_msg]} {
        closeport
        error $error_msg
    }
}

# ============================================================================
# Funciones de alto nivel
# ============================================================================

proc start_downscaling {} {
    global REG_CONTROL
    puts "Iniciando downscaling..."
    write_register $REG_CONTROL 0x00000001
    after 10
    write_register $REG_CONTROL 0x00000000
    puts "Comando START enviado"
}

proc reset_system {} {
    global REG_CONTROL
    puts "Reseteando memorias..."
    write_register $REG_CONTROL 0x00000002
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

proc upload_image {image_data} {
    global REG_IMG_WR_ADDR REG_IMG_WR_DATA INPUT_WIDTH INPUT_HEIGHT

    set total_pixels [expr {$INPUT_WIDTH * $INPUT_HEIGHT}]

    if {[llength $image_data] != $total_pixels} {
        error "Tamaño incorrecto. Esperado: $total_pixels, Recibido: [llength $image_data]"
    }

    puts "Subiendo imagen de ${INPUT_WIDTH}x${INPUT_HEIGHT}..."
    write_register $REG_IMG_WR_ADDR 0x00000000

    for {set i 0} {$i < $total_pixels} {incr i} {
        set pixel [lindex $image_data $i]

        if {$pixel < 0 || $pixel > 255} {
            error "Valor fuera de rango en posición $i: $pixel"
        }

        write_register $REG_IMG_WR_DATA $pixel

        if {($i % 512) == 0} {
            set progress [expr {($i * 100) / $total_pixels}]
            puts "Progreso: ${progress}% ($i/$total_pixels píxeles)"
        }
    }

    puts "Imagen subida: $total_pixels píxeles"
}

proc download_image {} {
    global REG_IMG_RD_ADDR REG_IMG_RD_DATA OUTPUT_WIDTH OUTPUT_HEIGHT

    set total_pixels [expr {$OUTPUT_WIDTH * $OUTPUT_HEIGHT}]
    set image_data [list]

    puts "Descargando imagen de ${OUTPUT_WIDTH}x${OUTPUT_HEIGHT}..."
    write_register $REG_IMG_RD_ADDR 0x00000000

    for {set i 0} {$i < $total_pixels} {incr i} {
        set pixel [read_register $REG_IMG_RD_DATA]
        set pixel [expr {$pixel & 0xFF}]
        lappend image_data $pixel

        if {($i % 256) == 0} {
            set progress [expr {($i * 100) / $total_pixels}]
            puts "Progreso: ${progress}% ($i/$total_pixels píxeles)"
        }
    }

    puts "Imagen descargada: $total_pixels píxeles"
    return $image_data
}

proc process_image {input_image} {
    puts "\n========================================="
    puts "Procesamiento de Imagen - Downscaling"
    puts "========================================="

    upload_image $input_image
    get_status
    start_downscaling

    if {![wait_for_completion 30000]} {
        error "El procesamiento no se completó"
    }

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

    # Enviar mensaje de bienvenida
    puts $sock "JTAG Downscaling Server - Listo"
    flush $sock

    # Manejar múltiples comandos
    while {[eof $sock] == 0} {
        if {[catch {gets $sock command} result] || $result < 0} {
            if {[eof $sock]} {
                break
            }
            continue
        }

        set command [string trim $command]
        if {$command == ""} {
            continue
        }

        puts "Comando recibido: '$command'"

        if {[catch {
            switch -glob $command {
                "STATUS" {
                    set status [get_status]
                    puts $sock "OK [lindex $status 0] [lindex $status 1] [lindex $status 2] [lindex $status 3]"
                    flush $sock
                }

                "START" {
                    start_downscaling
                    puts $sock "OK"
                    flush $sock
                }

                "RESET" {
                    reset_system
                    puts $sock "OK"
                    flush $sock
                }

                "UPLOAD *" {
                    set parts [split $command]
                    set num_pixels [lindex $parts 1]
                    set pixels [lrange $parts 2 end]

                    if {[llength $pixels] != $num_pixels} {
                        puts $sock "ERROR Número de píxeles incorrecto"
                    } else {
                        upload_image $pixels
                        puts $sock "OK"
                    }
                    flush $sock
                }

                "DOWNLOAD" {
                    set image [download_image]
                    puts $sock "OK [llength $image] $image"
                    flush $sock
                }

                "PROCESS *" {
                    set parts [split $command]
                    set num_pixels [lindex $parts 1]
                    set pixels [lrange $parts 2 end]

                    if {[llength $pixels] != $num_pixels} {
                        puts $sock "ERROR Número de píxeles incorrecto"
                    } else {
                        set result [process_image $pixels]
                        puts $sock "OK [llength $result] $result"
                    }
                    flush $sock
                }

                "CLOSE" {
                    puts $sock "OK"
                    flush $sock
                    closeport
                    close $sock
                    return
                }

                default {
                    puts $sock "ERROR Comando desconocido: $command"
                    flush $sock
                }
            }
        } error_msg]} {
            puts $sock "ERROR $error_msg"
            flush $sock
            puts "Error procesando comando: $error_msg"
        }
    }

    close $sock
    puts "Cliente desconectado: ${addr}:${port}"
}

proc start_server {} {
    global SERVER_PORT socket_server

    puts "========================================="
    puts "Servidor JTAG Downscaling (SLD Mode)"
    puts "========================================="
    puts "Puerto: $SERVER_PORT"

    puts "Verificando conexión JTAG..."
    if {[catch {
        openport
        puts "JTAG conectado correctamente"
    } error_msg]} {
        puts "ADVERTENCIA: $error_msg"
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
