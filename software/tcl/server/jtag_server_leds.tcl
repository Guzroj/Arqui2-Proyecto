# ============================================================================
# jtag_server_leds.tcl
# Servidor TCP/IP para comunicacion JTAG con FPGA
# BASADO EN: https://idlelogiclabs.com/2012/04/15/talking-to-the-de0-nano-using-the-virtual-jtag-interface/
# Adaptado para DE1-SoC con 8 LEDs
# ============================================================================

package require Tcl 8.5

# ============================================================================
# Configuracion
# ============================================================================
set PORT 2540
set IR_WIDTH 1
set DR_WIDTH 8

# ============================================================================
# Deteccion de Hardware JTAG
# ============================================================================

global usbblaster_name
global test_device

puts "\n=========================================="
puts "JTAG LED Server - FASE 3"
puts "==========================================="
puts ""

# Detectar hardware JTAG (USB-Blaster, DE-SoC, DE1-SoC-MTL2, etc.)
set hardware_list [get_hardware_names]

if {[llength $hardware_list] == 0} {
    puts "ERROR: No se encontro ningun hardware JTAG conectado"
    puts "Por favor, verifica que:"
    puts "  - La placa este conectada via USB"
    puts "  - La placa este encendida"
    puts "  - Los drivers USB-Blaster esten instalados"
    exit 1
}

# Usar el primer hardware disponible
set usbblaster_name [lindex $hardware_list 0]

puts "Hardware disponible:"
foreach hw $hardware_list {
    if {$hw == $usbblaster_name} {
        puts "  * $hw (seleccionado)"
    } else {
        puts "    $hw"
    }
}
puts ""

# Detectar dispositivo FPGA en cadena JTAG
# Para DE1-SoC, el FPGA es el segundo dispositivo (@2)
foreach device_name [get_device_names -hardware_name $usbblaster_name] {
    puts "Dispositivo encontrado: $device_name"
    if { [string match "@2*" $device_name] } {
        set test_device $device_name
    }
}

if {![info exists test_device]} {
    puts "\nERROR: No se encontro el dispositivo FPGA"
    puts "Dispositivos disponibles:"
    foreach device_name [get_device_names -hardware_name $usbblaster_name] {
        puts "  $device_name"
    }
    exit 1
}

puts "\nDispositivo seleccionado: $test_device\n"

# ============================================================================
# Funciones de comunicacion JTAG
# ============================================================================

# Abrir dispositivo FPGA
proc openport {} {
    global usbblaster_name
    global test_device
    open_device -hardware_name $usbblaster_name -device_name $test_device
}

# Cerrar dispositivo FPGA
proc closeport {} {
    catch {device_unlock}
    catch {close_device}
}

# Configurar LEDs via JTAG
proc set_LEDs {send_data} {
    # Convertir el valor decimal a binario de 8 bits
    set binary_value [format "%08s" [string map {0 {}} [format %b $send_data]]]
    set binary_value [string map {{ } 0} $binary_value]

    puts "Escribiendo LEDs: $send_data (0x[format "%02X" $send_data]) -> $binary_value"

    if {[catch {
        openport
        device_lock -timeout 10000

        # 1. Cambiar IR a 1 (modo de control de LEDs)
        device_virtual_ir_shift -instance_index 0 -ir_value 1 -no_captured_ir_value

        # 2. Escribir valor al DR (8 bits) usando la cadena binaria
        device_virtual_dr_shift -dr_value $binary_value -instance_index 0 -length 8 -no_captured_dr_value

        # 3. Regresar IR a 0 (modo bypass)
        device_virtual_ir_shift -instance_index 0 -ir_value 0 -no_captured_ir_value

        closeport
    } error_msg]} {
        # Si hay error, asegurar que el puerto se cierre
        closeport
        error $error_msg
    }

    puts "LEDs actualizados correctamente"
    return 1
}

# ============================================================================
# Servidor TCP/IP
# ============================================================================
# Basado en: http://www.tcl.tk/about/netserver.html

proc ConnAccept {sock addr port} {
    global conn

    puts "Cliente conectado desde $addr:$port"
    set conn(addr,$sock) [list $addr $port]

    fconfigure $sock -buffering line

    # Enviar mensaje de bienvenida
    puts $sock "JTAG LED Server - Listo"
    flush $sock

    fileevent $sock readable [list IncomingData $sock]
}

proc IncomingData {sock} {
    global conn

    if {[eof $sock] || [catch {gets $sock line}]} {
        close $sock
        puts "Cliente desconectado: $conn(addr,$sock)"
        unset conn(addr,$sock)
    } else {
        set data_len [string length $line]
        if {$data_len != 0} {
            set line [string trim $line]
            puts "Comando recibido: '$line'"

            # Parsear comando
            set parts [split $line " "]
            set cmd [lindex $parts 0]
            set args [lrange $parts 1 end]

            switch -exact $cmd {
                "set_leds" {
                    if {[llength $args] != 1} {
                        puts $sock "ERROR: Uso: set_leds <value>"
                        flush $sock
                    } else {
                        set value [lindex $args 0]
                        if {[catch {set_LEDs $value} result]} {
                            puts "ERROR en set_LEDs: $result"
                            puts $sock "ERROR: $result"
                            flush $sock
                        } else {
                            puts $sock "OK"
                            flush $sock
                        }
                    }
                }
                "quit" {
                    puts $sock "Cerrando conexion"
                    flush $sock
                    close $sock
                    return
                }
                default {
                    puts $sock "ERROR: Comando desconocido: $cmd"
                    puts $sock "Comandos disponibles: set_leds <value>, quit"
                    flush $sock
                }
            }
        }
    }
}

proc Start_Server {port} {
    set s [socket -server ConnAccept $port]
    puts "=========================================="
    puts "Servidor escuchando en puerto $port"
    puts "Esperando conexiones..."
    puts "Presiona Ctrl+C para detener el servidor"
    puts "==========================================\n"
    vwait forever
}

# ============================================================================
# Inicio del script
# ============================================================================

Start_Server $PORT
