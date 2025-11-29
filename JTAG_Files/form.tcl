#!/usr/bin/env tclsh
# ================================================================
# form.tcl
# Script TCL para comunicación JTAG con el proyecto Downscale
# Basado en: https://github.com/Abner2111/GuiaJtag
# 
# Ejecutar con: quartus_stp -t form.tcl
# ================================================================

package require Tk

# ============================================================
# Variables globales
# ============================================================
set hardware_name ""
set device_name ""
set connected 0

# Direcciones de registros
set ADDR_CONTROL   0x00
set ADDR_XRATIO    0x01
set ADDR_YRATIO    0x02
set ADDR_WRITEADDR 0x03
set ADDR_WRITEDATA 0x04
set ADDR_READDATA  0x05
set ADDR_DONEFLAG  0x06
set ADDR_PERFCOUNT 0x07
set ADDR_IMGWIDTH  0x08
set ADDR_IMGHEIGHT 0x09

# Instrucciones JTAG (2 bits)
set IR_BYPASS    0
set IR_SET_ADDR  1
set IR_WRITE_REG 2
set IR_READ_REG  3

# Parámetros de imagen (modificables desde GUI)
set IMG_W 64
set IMG_H 64

# Archivo de imagen cargado
set loaded_image_file ""

# ============================================================
# Procedimientos de comunicación JTAG
# ============================================================

proc conectar {} {
    global hardware_name device_name connected
    
    # Buscar hardware JTAG
    foreach hardware [get_hardware_names] {
        if {[string match "USB-Blaster*" $hardware] || 
            [string match "*DE-10*" $hardware] ||
            [string match "*USB*" $hardware]} {
            set hardware_name $hardware
            break
        }
    }
    
    if {$hardware_name == ""} {
        set hardware_name [lindex [get_hardware_names] 0]
    }
    
    if {$hardware_name == ""} {
        puts "ERROR: No se encontro hardware JTAG"
        return 0
    }
    
    puts "Hardware: $hardware_name"
    
    # Buscar dispositivo
    foreach device [get_device_names -hardware_name $hardware_name] {
        if {[string match "@1*" $device] || [string match "*5C*" $device]} {
            set device_name $device
            break
        }
    }
    
    if {$device_name == ""} {
        set device_name [lindex [get_device_names -hardware_name $hardware_name] 0]
    }
    
    puts "Dispositivo: $device_name"
    
    # Abrir dispositivo
    open_device -hardware_name $hardware_name -device_name $device_name
    
    # Bloquear el dispositivo para uso exclusivo
    device_lock -timeout 5000
    puts "Dispositivo bloqueado"
    
    # Esperar a que el JTAG se estabilice
    after 500
    
    # Verificar si hay instancias Virtual JTAG
    puts "Buscando instancias Virtual JTAG..."
    
    # Intentar acceder a la instancia 0
    if {[catch {device_virtual_ir_shift -instance_index 0 -ir_value 0 -no_captured_ir_value} err]} {
        puts "ERROR: No se encontro instancia Virtual JTAG"
        puts "Detalle: $err"
        puts ""
        puts "Verifica que:"
        puts "  1. Programaste la FPGA con el .sof correcto"
        puts "  2. El diseno tiene Top_VJTAG como top-level"
        puts "  3. No hay errores de compilacion"
        device_unlock
        close_device
        return 0
    }
    
    puts "Virtual JTAG encontrado en instancia 0"
    puts "Conexion exitosa!"
    
    set connected 1
    return 1
}

proc desconectar {} {
    global connected
    catch {device_unlock}
    catch {close_device}
    set connected 0
    puts "Desconectado"
}

# Establecer dirección de registro
proc set_addr {addr} {
    global IR_SET_ADDR
    
    # Cambiar a instrucción SET_ADDR
    device_virtual_ir_shift -instance_index 0 -ir_value $IR_SET_ADDR -no_captured_ir_value
    
    # Enviar dirección (8 bits)
    set addr_hex [format "%02X" $addr]
    device_virtual_dr_shift -instance_index 0 -length 8 -dr_value $addr_hex -value_in_hex -no_captured_dr_value
}

# Escribir a un registro
proc write_reg {addr data} {
    global IR_WRITE_REG
    
    # Primero establecer dirección
    set_addr $addr
    
    # Cambiar a instrucción WRITE_REG
    device_virtual_ir_shift -instance_index 0 -ir_value $IR_WRITE_REG -no_captured_ir_value
    
    # Enviar datos (32 bits)
    set data_hex [format "%08X" $data]
    device_virtual_dr_shift -instance_index 0 -length 32 -dr_value $data_hex -value_in_hex -no_captured_dr_value
    
    puts "WRITE: addr=0x[format %02X $addr] data=0x[format %08X $data]"
}

# Leer de un registro
proc read_reg {addr} {
    global IR_READ_REG
    
    # Primero establecer dirección
    set_addr $addr
    
    # Cambiar a instrucción READ_REG
    device_virtual_ir_shift -instance_index 0 -ir_value $IR_READ_REG -no_captured_ir_value
    
    # Leer datos (32 bits)
    set result [device_virtual_dr_shift -instance_index 0 -length 32 -value_in_hex]
    set data [expr 0x$result]
    
    puts "READ:  addr=0x[format %02X $addr] data=0x[format %08X $data]"
    return $data
}

# ============================================================
# Funciones de alto nivel
# ============================================================

proc leer_todos_registros {} {
    global ADDR_CONTROL ADDR_XRATIO ADDR_YRATIO
    global ADDR_WRITEADDR ADDR_WRITEDATA
    global ADDR_READDATA ADDR_DONEFLAG ADDR_PERFCOUNT
    global ADDR_IMGWIDTH ADDR_IMGHEIGHT
    
    puts "\n========== ESTADO DE REGISTROS =========="
    puts "CONTROL:    0x[format %08X [read_reg $ADDR_CONTROL]]"
    puts "XRATIO:     0x[format %08X [read_reg $ADDR_XRATIO]]"
    puts "YRATIO:     0x[format %08X [read_reg $ADDR_YRATIO]]"
    puts "WRITEADDR:  0x[format %08X [read_reg $ADDR_WRITEADDR]]"
    puts "WRITEDATA:  0x[format %08X [read_reg $ADDR_WRITEDATA]]"
    puts "READDATA:   0x[format %08X [read_reg $ADDR_READDATA]]"
    puts "DONEFLAG:   0x[format %08X [read_reg $ADDR_DONEFLAG]]"
    puts "PERFCOUNT:  0x[format %08X [read_reg $ADDR_PERFCOUNT]]"
    puts "IMGWIDTH:   [read_reg $ADDR_IMGWIDTH]"
    puts "IMGHEIGHT:  [read_reg $ADDR_IMGHEIGHT]"
    puts "=========================================\n"
}

proc escribir_pixel {addr pixel} {
    global ADDR_WRITEADDR ADDR_WRITEDATA
    write_reg $ADDR_WRITEADDR $addr
    write_reg $ADDR_WRITEDATA $pixel
}

# ============================================================
# Configurar dimensiones de imagen en la FPGA
# ============================================================
proc configurar_dimensiones {} {
    global IMG_W IMG_H ADDR_IMGWIDTH ADDR_IMGHEIGHT
    
    puts "Configurando dimensiones: ${IMG_W}x${IMG_H}"
    write_reg $ADDR_IMGWIDTH $IMG_W
    write_reg $ADDR_IMGHEIGHT $IMG_H
    puts "Dimensiones configuradas en FPGA"
}

proc cargar_imagen_gradiente {} {
    global IMG_W IMG_H ADDR_CONTROL
    
    # Primero configurar dimensiones
    configurar_dimensiones
    
    puts "Configurando modo SIMD..."
    write_reg $ADDR_CONTROL 0x04
    
    puts "Cargando imagen gradiente ${IMG_W}x${IMG_H}..."
    
    for {set row 0} {$row < $IMG_H} {incr row} {
        for {set col 0} {$col < $IMG_W} {incr col} {
            set addr [expr {$row * $IMG_W + $col}]
            set pixel [expr {($row + $col) & 0xFF}]
            escribir_pixel $addr $pixel
        }
        if {[expr {$row % 16}] == 0} {
            puts "  Fila $row/$IMG_H"
            update
        }
    }
    puts "Imagen cargada!"
}

# ============================================================
# Cargar imagen desde archivo .txt
# ============================================================
proc cargar_imagen_desde_archivo {} {
    global IMG_W IMG_H ADDR_CONTROL loaded_image_file
    
    # Abrir diálogo para seleccionar archivo
    set filename [tk_getOpenFile -filetypes {
        {"Archivos de texto" {.txt}}
        {"Todos los archivos" *}
    } -title "Seleccionar archivo de imagen"]
    
    if {$filename == ""} {
        puts "No se selecciono archivo"
        return
    }
    
    set loaded_image_file $filename
    puts "Cargando archivo: $filename"
    
    # Leer archivo
    if {[catch {open $filename r} fp]} {
        puts "ERROR: No se pudo abrir el archivo"
        return
    }
    
    # Leer todos los valores
    set content [read $fp]
    close $fp
    
    # Parsear valores (separados por espacios o saltos de línea)
    set pixels [regexp -all -inline {\d+} $content]
    set total_pixels [llength $pixels]
    
    puts "Total de pixeles leidos: $total_pixels"
    puts "Esperados: [expr {$IMG_W * $IMG_H}]"
    
    if {$total_pixels < [expr {$IMG_W * $IMG_H}]} {
        puts "ADVERTENCIA: Menos pixeles de los esperados"
    }
    
    # Configurar dimensiones en FPGA
    configurar_dimensiones
    
    # Cargar a FPGA
    puts "Enviando imagen a FPGA..."
    
    set idx 0
    for {set row 0} {$row < $IMG_H} {incr row} {
        for {set col 0} {$col < $IMG_W} {incr col} {
            if {$idx < $total_pixels} {
                set pixel [lindex $pixels $idx]
                set addr [expr {$row * $IMG_W + $col}]
                escribir_pixel $addr [expr {$pixel & 0xFF}]
                incr idx
            }
        }
        if {[expr {$row % 16}] == 0} {
            puts "  Fila $row/$IMG_H"
            update
        }
    }
    
    puts "Imagen cargada desde archivo!"
    puts "Pixeles cargados: $idx"
}

proc iniciar_simd {} {
    global ADDR_CONTROL
    
    # Configurar dimensiones antes de iniciar
    configurar_dimensiones
    
    puts "Iniciando procesamiento SIMD..."
    write_reg $ADDR_CONTROL 0x05
}

proc iniciar_secuencial {} {
    global ADDR_CONTROL
    
    # Configurar dimensiones antes de iniciar
    configurar_dimensiones
    
    puts "Iniciando procesamiento Secuencial..."
    write_reg $ADDR_CONTROL 0x01
}

proc detener {} {
    global ADDR_CONTROL
    write_reg $ADDR_CONTROL 0x00
    puts "Detenido"
}

proc leer_done {} {
    global ADDR_DONEFLAG
    set done [read_reg $ADDR_DONEFLAG]
    if {$done & 0x01} {
        puts "Estado: COMPLETADO"
    } else {
        puts "Estado: EN PROCESO"
    }
    return [expr {$done & 0x01}]
}

proc leer_ciclos {} {
    global ADDR_PERFCOUNT
    set ciclos [read_reg $ADDR_PERFCOUNT]
    puts "Ciclos: $ciclos"
    return $ciclos
}

# ============================================================
# Esperar hasta que done sea 1
# ============================================================
proc esperar_done {} {
    global ADDR_DONEFLAG
    
    puts "Esperando finalizacion..."
    set intentos 0
    set max_intentos 1000
    
    while {$intentos < $max_intentos} {
        set done [read_reg $ADDR_DONEFLAG]
        if {$done & 0x01} {
            puts "Proceso completado!"
            leer_ciclos
            return 1
        }
        incr intentos
        after 100
        update
    }
    
    puts "TIMEOUT esperando done"
    return 0
}

# ============================================================
# Presets de tamaño de imagen
# ============================================================
proc preset_32x32 {} {
    global IMG_W IMG_H
    set IMG_W 32
    set IMG_H 32
    puts "Preset: 32x32"
}

proc preset_64x64 {} {
    global IMG_W IMG_H
    set IMG_W 64
    set IMG_H 64
    puts "Preset: 64x64"
}

proc preset_128x128 {} {
    global IMG_W IMG_H
    set IMG_W 128
    set IMG_H 128
    puts "Preset: 128x128"
}

proc preset_256x256 {} {
    global IMG_W IMG_H
    set IMG_W 256
    set IMG_H 256
    puts "Preset: 256x256"
}

proc preset_512x512 {} {
    global IMG_W IMG_H
    set IMG_W 512
    set IMG_H 512
    puts "Preset: 512x512"
}

# ============================================================
# Interfaz gráfica (GUI)
# ============================================================

proc crear_gui {} {
    global connected IMG_W IMG_H
    
    wm title . "Control JTAG - Downscale Project"
    wm geometry . 550x700
    
    # Frame de conexion
    labelframe .conn -text "Conexion" -padx 10 -pady 10
    pack .conn -fill x -padx 10 -pady 5
    
    button .conn.conectar -text "Conectar" -command {
        if {[conectar]} {
            .conn.status configure -text "Conectado" -fg green
        } else {
            .conn.status configure -text "Error" -fg red
        }
    }
    button .conn.desconectar -text "Desconectar" -command {
        desconectar
        .conn.status configure -text "Desconectado" -fg red
    }
    label .conn.status -text "Desconectado" -fg red
    
    pack .conn.conectar .conn.desconectar -side left -padx 5
    pack .conn.status -side right -padx 5
    
    # Frame de configuracion de imagen
    labelframe .imgcfg -text "Dimensiones de Imagen" -padx 10 -pady 10
    pack .imgcfg -fill x -padx 10 -pady 5
    
    # Fila 1: Entradas manuales
    frame .imgcfg.manual
    label .imgcfg.manual.lw -text "Ancho:"
    entry .imgcfg.manual.ew -width 6 -textvariable IMG_W
    label .imgcfg.manual.lh -text "Alto:"
    entry .imgcfg.manual.eh -width 6 -textvariable IMG_H
    button .imgcfg.manual.apply -text "Aplicar" -command configurar_dimensiones
    
    pack .imgcfg.manual.lw .imgcfg.manual.ew .imgcfg.manual.lh .imgcfg.manual.eh .imgcfg.manual.apply -side left -padx 3
    pack .imgcfg.manual -fill x -pady 2
    
    # Fila 2: Presets
    frame .imgcfg.presets
    label .imgcfg.presets.l -text "Presets:"
    button .imgcfg.presets.p32 -text "32x32" -command preset_32x32 -width 6
    button .imgcfg.presets.p64 -text "64x64" -command preset_64x64 -width 6
    button .imgcfg.presets.p128 -text "128x128" -command preset_128x128 -width 7
    button .imgcfg.presets.p256 -text "256x256" -command preset_256x256 -width 7
    button .imgcfg.presets.p512 -text "512x512" -command preset_512x512 -width 7
    
    pack .imgcfg.presets.l .imgcfg.presets.p32 .imgcfg.presets.p64 .imgcfg.presets.p128 .imgcfg.presets.p256 .imgcfg.presets.p512 -side left -padx 2
    pack .imgcfg.presets -fill x -pady 2
    
    # Frame de modo
    labelframe .modo -text "Modo de Operacion" -padx 10 -pady 10
    pack .modo -fill x -padx 10 -pady 5
    
    button .modo.simd -text "Modo SIMD" -command {write_reg 0x00 0x04}
    button .modo.seq -text "Modo Secuencial" -command {write_reg 0x00 0x00}
    
    pack .modo.simd .modo.seq -side left -padx 5
    
    # Frame de imagen
    labelframe .img -text "Cargar Imagen" -padx 10 -pady 10
    pack .img -fill x -padx 10 -pady 5
    
    button .img.cargar -text "Cargar Gradiente" -command cargar_imagen_gradiente
    button .img.archivo -text "Cargar desde .txt" -command cargar_imagen_desde_archivo
    
    pack .img.cargar .img.archivo -side left -padx 5
    
    # Frame de control
    labelframe .ctrl -text "Control" -padx 10 -pady 10
    pack .ctrl -fill x -padx 10 -pady 5
    
    button .ctrl.start_simd -text "Iniciar SIMD" -command iniciar_simd -bg lightgreen
    button .ctrl.start_seq -text "Iniciar Secuencial" -command iniciar_secuencial -bg lightblue
    button .ctrl.stop -text "Detener" -command detener -bg salmon
    
    pack .ctrl.start_simd .ctrl.start_seq .ctrl.stop -side left -padx 5
    
    # Frame de estado
    labelframe .estado -text "Estado" -padx 10 -pady 10
    pack .estado -fill x -padx 10 -pady 5
    
    button .estado.done -text "Leer Done" -command leer_done
    button .estado.ciclos -text "Leer Ciclos" -command leer_ciclos
    button .estado.todos -text "Leer Todos" -command leer_todos_registros
    button .estado.esperar -text "Esperar Done" -command esperar_done
    
    pack .estado.done .estado.ciclos .estado.todos .estado.esperar -side left -padx 5
    
    # Frame de registro manual
    labelframe .manual -text "Acceso Manual" -padx 10 -pady 10
    pack .manual -fill x -padx 10 -pady 5
    
    label .manual.laddr -text "Direccion:"
    entry .manual.addr -width 10
    .manual.addr insert 0 "0x00"
    
    label .manual.ldata -text "Dato:"
    entry .manual.data -width 15
    .manual.data insert 0 "0x00000000"
    
    button .manual.write -text "Escribir" -command {
        set addr [expr [.manual.addr get]]
        set data [expr [.manual.data get]]
        write_reg $addr $data
    }
    button .manual.read -text "Leer" -command {
        set addr [expr [.manual.addr get]]
        set data [read_reg $addr]
        .manual.data delete 0 end
        .manual.data insert 0 [format "0x%08X" $data]
    }
    
    grid .manual.laddr -row 0 -column 0 -sticky e
    grid .manual.addr -row 0 -column 1 -padx 5
    grid .manual.ldata -row 0 -column 2 -sticky e
    grid .manual.data -row 0 -column 3 -padx 5
    grid .manual.write -row 1 -column 1 -pady 5
    grid .manual.read -row 1 -column 3 -pady 5
    
    # Consola de salida
    labelframe .console -text "Consola" -padx 10 -pady 10
    pack .console -fill both -expand 1 -padx 10 -pady 5
    
    text .console.text -height 12 -width 60 -yscrollcommand {.console.scroll set}
    scrollbar .console.scroll -command {.console.text yview}
    
    pack .console.scroll -side right -fill y
    pack .console.text -side left -fill both -expand 1
}

# ============================================================
# Redirigir puts a la consola
# ============================================================
rename puts original_puts

proc puts {args} {
    if {[llength $args] == 1} {
        set msg [lindex $args 0]
        original_puts $msg
        if {[winfo exists .console.text]} {
            .console.text insert end "$msg\n"
            .console.text see end
            update
        }
    } else {
        eval original_puts $args
    }
}

# ============================================================
# Iniciar GUI
# ============================================================
puts "============================================================"
puts "  Control JTAG - Proyecto Downscale"
puts "  Basado en GuiaJtag"
puts "============================================================"
puts ""
puts "Mapa de registros:"
puts "  0x00: CONTROL (bit0=start, bit1=step, bit2=mode)"
puts "  0x03: WRITEADDR"
puts "  0x04: WRITEDATA"
puts "  0x06: DONEFLAG (read-only)"
puts "  0x07: PERFCOUNT (read-only)"
puts "  0x08: IMGWIDTH  (ancho de imagen)"
puts "  0x09: IMGHEIGHT (alto de imagen)"
puts ""
puts "Instrucciones:"
puts "  1. Click 'Conectar'"
puts "  2. Seleccionar dimensiones (preset o manual)"
puts "  3. Cargar imagen (gradiente o desde .txt)"
puts "  4. Seleccionar modo (SIMD o Secuencial)"
puts "  5. Click 'Iniciar SIMD' o 'Iniciar Secuencial'"
puts "  6. Click 'Esperar Done' para resultados"
puts ""

crear_gui

# Mantener la GUI abierta esperando eventos
vwait forever
