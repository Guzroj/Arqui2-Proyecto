# ==============================================================================
# dsa_interface.tcl - Interfaz Interactiva para DSA
# ==============================================================================
# Menú amigable para controlar el DSA desde System Console
# ==============================================================================

# Cargar scripts base
set script_dir [file dirname [info script]]
source [file join $script_dir "test_dsa_basic.tcl"]
source [file join $script_dir "load_image.tcl"]
source [file join $script_dir "run_downscale.tcl"]
source [file join $script_dir "read_result.tcl"]
source [file join $script_dir "debug_dsa.tcl"]

# Variables globales de estado
set gui_connected 0
set gui_image_loaded 0
set gui_last_result ""

# ==============================================================================
# FUNCIÓN: Dibujar encabezado
# ==============================================================================
proc draw_header {} {
    global gui_connected gui_image_loaded
    
    puts "\n"
    puts "╔══════════════════════════════════════════════════════════════════╗"
    puts "║                  DSA DOWNSCALER - INTERFAZ                       ║"
    puts "║                  Intel DE1-SoC FPGA Control                      ║"
    puts "╚══════════════════════════════════════════════════════════════════╝"
    
    # Estado del sistema
    if {$gui_connected} {
        puts "  🟢 JTAG: CONECTADO"
    } else {
        puts "  🔴 JTAG: DESCONECTADO"
    }
    
    if {$gui_image_loaded} {
        puts "  🟢 Imagen: CARGADA"
    } else {
        puts "  ⚪ Imagen: NO CARGADA"
    }
    
    # Leer estado del DSA si está conectado
    if {$gui_connected} {
        catch {
            global jtag DSA_BASE REG_STATUS
            set status [master_read_32 $jtag [expr {$DSA_BASE + $REG_STATUS}] 1]
            set busy [expr {$status & 0x01}]
            set done [expr {($status >> 1) & 0x01}]
            
            if {$busy} {
                puts "  🟡 DSA: PROCESANDO..."
            } elseif {$done} {
                puts "  🟢 DSA: COMPLETADO"
            } else {
                puts "  ⚪ DSA: IDLE"
            }
        }
    }
    puts ""
}

# ==============================================================================
# FUNCIÓN: Menú principal
# ==============================================================================
proc show_menu {} {
    puts "══════════════════════════════════════════════════════════════════"
    puts "  MENÚ PRINCIPAL"
    puts "══════════════════════════════════════════════════════════════════"
    puts ""
    puts "  [1] 🔌 Conectar al JTAG"
    puts "  [2] 📊 Ver estado del DSA"
    puts "  [3] 📷 Cargar imagen a memoria"
    puts "  [4] ⚙️  Ejecutar downscale"
    puts "  [5] 💾 Leer resultado"
    puts "  [6] 🔍 Monitor en tiempo real"
    puts "  [7] 🧪 Test completo automático"
    puts "  [8] 📋 Ver configuración"
    puts "  [0] ❌ Salir"
    puts ""
    puts "══════════════════════════════════════════════════════════════════"
    puts -nonewline "Selecciona una opción: "
    flush stdout
}

# ==============================================================================
# FUNCIÓN: Conectar JTAG
# ==============================================================================
proc menu_connect {} {
    global gui_connected jtag
    
    puts "\n╔══════════════════════════════════════════════════════════════════╗"
    puts "║  🔌 CONECTANDO AL JTAG...                                        ║"
    puts "╚══════════════════════════════════════════════════════════════════╝\n"
    
    if {[catch {
        set jtag_masters [get_service_paths master]
        if {[llength $jtag_masters] == 0} {
            puts "❌ ERROR: No se encontró ningún JTAG Master"
            puts "   Verifica que la FPGA esté conectada y programada."
            return
        }
        
        set jtag [lindex $jtag_masters 0]
        open_service master $jtag
        
        puts "✅ JTAG Master encontrado:"
        puts "   $jtag"
        puts ""
        
        set gui_connected 1
        
        # Probar conexión leyendo STATUS
        global DSA_BASE REG_STATUS
        set status [master_read_32 $jtag [expr {$DSA_BASE + $REG_STATUS}] 1]
        puts "✅ Conexión exitosa - STATUS: 0x[format %08X $status]"
        
    } err]} {
        puts "❌ ERROR: $err"
        set gui_connected 0
    }
    
    puts "\nPresiona ENTER para continuar..."
    gets stdin
}

# ==============================================================================
# FUNCIÓN: Ver estado
# ==============================================================================
proc menu_status {} {
    global gui_connected
    
    puts "\n╔══════════════════════════════════════════════════════════════════╗"
    puts "║  📊 ESTADO DEL DSA                                               ║"
    puts "╚══════════════════════════════════════════════════════════════════╝\n"
    
    if {!$gui_connected} {
        puts "❌ ERROR: Primero debes conectar al JTAG (opción 1)"
        puts "\nPresiona ENTER para continuar..."
        gets stdin
        return
    }
    
    dsa_snapshot
    
    puts "\nPresiona ENTER para continuar..."
    gets stdin
}

# ==============================================================================
# FUNCIÓN: Cargar imagen
# ==============================================================================
proc menu_load_image {} {
    global gui_connected gui_image_loaded
    
    puts "\n╔══════════════════════════════════════════════════════════════════╗"
    puts "║  📷 CARGAR IMAGEN                                                ║"
    puts "╚══════════════════════════════════════════════════════════════════╝\n"
    
    if {!$gui_connected} {
        puts "❌ ERROR: Primero debes conectar al JTAG (opción 1)"
        puts "\nPresiona ENTER para continuar..."
        gets stdin
        return
    }
    
    puts "Imágenes disponibles:"
    puts "  [1] imagen_128x128_gradient.txt (128×128)"
    puts "  [2] imagen_256x256.txt (256×256)"
    puts "  [3] imagen_512x512.txt (512×512)"
    puts "  [4] Ruta personalizada"
    puts ""
    puts -nonewline "Selecciona: "
    flush stdout
    gets stdin choice
    
    set base_path "C:/Users/gabri/OneDrive/Desktop/PrograProyectoArqui/Arqui2-Proyecto"
    
    switch $choice {
        1 {
            set file "$base_path/imagen_128x128_gradient.txt"
            set w 128
            set h 128
        }
        2 {
            set file "$base_path/imagen_256x256.txt"
            set w 256
            set h 256
        }
        3 {
            set file "$base_path/imagen_512x512.txt"
            set w 512
            set h 512
        }
        4 {
            puts -nonewline "Ruta completa: "
            flush stdout
            gets stdin file
            puts -nonewline "Ancho: "
            flush stdout
            gets stdin w
            puts -nonewline "Alto: "
            flush stdout
            gets stdin h
        }
        default {
            puts "❌ Opción inválida"
            puts "\nPresiona ENTER para continuar..."
            gets stdin
            return
        }
    }
    
    if {[catch {
        load_image_to_sdram $file $w $h
        set gui_image_loaded 1
    } err]} {
        puts "❌ ERROR: $err"
        set gui_image_loaded 0
    }
    
    puts "\nPresiona ENTER para continuar..."
    gets stdin
}

# ==============================================================================
# FUNCIÓN: Ejecutar downscale
# ==============================================================================
proc menu_downscale {} {
    global gui_connected gui_image_loaded
    
    puts "\n╔══════════════════════════════════════════════════════════════════╗"
    puts "║  ⚙️  EJECUTAR DOWNSCALE                                          ║"
    puts "╚══════════════════════════════════════════════════════════════════╝\n"
    
    if {!$gui_connected} {
        puts "❌ ERROR: Primero debes conectar al JTAG (opción 1)"
        puts "\nPresiona ENTER para continuar..."
        gets stdin
        return
    }
    
    if {!$gui_image_loaded} {
        puts "⚠️  ADVERTENCIA: No has cargado una imagen"
        puts -nonewline "   ¿Continuar de todas formas? (s/n): "
        flush stdout
        gets stdin confirm
        if {$confirm ne "s" && $confirm ne "S"} {
            return
        }
    }
    
    puts -nonewline "Ancho entrada: "
    flush stdout
    gets stdin w_in
    
    puts -nonewline "Alto entrada: "
    flush stdout
    gets stdin h_in
    
    puts -nonewline "Ancho salida: "
    flush stdout
    gets stdin w_out
    
    puts -nonewline "Alto salida: "
    flush stdout
    gets stdin h_out
    
    puts "Modo:"
    puts "  [0] Secuencial (1 píxel/ciclo)"
    puts "  [1] SIMD (4 píxeles paralelos)"
    puts -nonewline "Selecciona: "
    flush stdout
    gets stdin mode
    
    puts ""
    
    if {[catch {
        run_downscale $w_in $h_in $w_out $h_out $mode
    } err]} {
        puts "❌ ERROR: $err"
    }
    
    puts "\nPresiona ENTER para continuar..."
    gets stdin
}

# ==============================================================================
# FUNCIÓN: Leer resultado
# ==============================================================================
proc menu_read_result {} {
    global gui_connected
    
    puts "\n╔══════════════════════════════════════════════════════════════════╗"
    puts "║  💾 LEER RESULTADO                                               ║"
    puts "╚══════════════════════════════════════════════════════════════════╝\n"
    
    if {!$gui_connected} {
        puts "❌ ERROR: Primero debes conectar al JTAG (opción 1)"
        puts "\nPresiona ENTER para continuar..."
        gets stdin
        return
    }
    
    puts -nonewline "Archivo de salida: "
    flush stdout
    gets stdin outfile
    
    puts -nonewline "Ancho: "
    flush stdout
    gets stdin w
    
    puts -nonewline "Alto: "
    flush stdout
    gets stdin h
    
    puts -nonewline "Dirección base (hex, default 0x00040000): "
    flush stdout
    gets stdin addr_str
    
    if {$addr_str eq ""} {
        set addr 0x00040000
    } else {
        set addr $addr_str
    }
    
    puts ""
    
    if {[catch {
        read_result_from_sdram $outfile $w $h $addr
    } err]} {
        puts "❌ ERROR: $err"
    }
    
    puts "\nPresiona ENTER para continuar..."
    gets stdin
}

# ==============================================================================
# FUNCIÓN: Monitor en tiempo real
# ==============================================================================
proc menu_monitor {} {
    global gui_connected
    
    puts "\n╔══════════════════════════════════════════════════════════════════╗"
    puts "║  🔍 MONITOR EN TIEMPO REAL                                       ║"
    puts "╚══════════════════════════════════════════════════════════════════╝\n"
    
    if {!$gui_connected} {
        puts "❌ ERROR: Primero debes conectar al JTAG (opción 1)"
        puts "\nPresiona ENTER para continuar..."
        gets stdin
        return
    }
    
    puts -nonewline "Iteraciones (default 10): "
    flush stdout
    gets stdin iters
    if {$iters eq ""} {set iters 10}
    
    puts -nonewline "Delay en ms (default 500): "
    flush stdout
    gets stdin delay
    if {$delay eq ""} {set delay 500}
    
    puts ""
    
    monitor_dsa $iters $delay
    
    puts "\nPresiona ENTER para continuar..."
    gets stdin
}

# ==============================================================================
# FUNCIÓN: Test completo automático
# ==============================================================================
proc menu_auto_test {} {
    global gui_connected gui_image_loaded
    
    puts "\n╔══════════════════════════════════════════════════════════════════╗"
    puts "║  🧪 TEST COMPLETO AUTOMÁTICO                                     ║"
    puts "╚══════════════════════════════════════════════════════════════════╝\n"
    
    puts "Este test ejecutará:"
    puts "  1. Conectar JTAG"
    puts "  2. Cargar imagen 128×128"
    puts "  3. Ejecutar downscale 128×128 → 64×64 (Secuencial)"
    puts "  4. Leer resultado"
    puts ""
    puts -nonewline "¿Continuar? (s/n): "
    flush stdout
    gets stdin confirm
    
    if {$confirm ne "s" && $confirm ne "S"} {
        return
    }
    
    puts "\n[1/4] Conectando..."
    menu_connect
    
    if {!$gui_connected} {
        puts "❌ Test abortado: No se pudo conectar"
        puts "\nPresiona ENTER para continuar..."
        gets stdin
        return
    }
    
    puts "\n[2/4] Cargando imagen..."
    set base_path "C:/Users/gabri/OneDrive/Desktop/PrograProyectoArqui/Arqui2-Proyecto"
    load_image_to_sdram "$base_path/imagen_128x128_gradient.txt" 128 128
    set gui_image_loaded 1
    
    puts "\n[3/4] Ejecutando downscale..."
    run_downscale 128 128 64 64 0
    
    puts "\n[4/4] Leyendo resultado..."
    read_result_from_sdram "resultado_auto_64x64.txt" 64 64
    
    puts "\n✅ TEST COMPLETADO"
    puts "\nPresiona ENTER para continuar..."
    gets stdin
}

# ==============================================================================
# FUNCIÓN: Ver configuración
# ==============================================================================
proc menu_config {} {
    global gui_connected
    
    puts "\n╔══════════════════════════════════════════════════════════════════╗"
    puts "║  📋 CONFIGURACIÓN ACTUAL                                         ║"
    puts "╚══════════════════════════════════════════════════════════════════╝\n"
    
    if {!$gui_connected} {
        puts "❌ ERROR: Primero debes conectar al JTAG (opción 1)"
        puts "\nPresiona ENTER para continuar..."
        gets stdin
        return
    }
    
    read_config
    check_dimensions
    
    puts "\nPresiona ENTER para continuar..."
    gets stdin
}

# ==============================================================================
# BUCLE PRINCIPAL
# ==============================================================================
proc main_loop {} {
    global gui_connected
    
    while {1} {
        # Limpiar pantalla (compatible con Windows)
        catch {exec cmd /c cls <@stdin >@stdout 2>@stderr}
        
        draw_header
        show_menu
        
        gets stdin choice
        
        switch $choice {
            1 {menu_connect}
            2 {menu_status}
            3 {menu_load_image}
            4 {menu_downscale}
            5 {menu_read_result}
            6 {menu_monitor}
            7 {menu_auto_test}
            8 {menu_config}
            0 {
                puts "\n👋 ¡Hasta luego!"
                if {$gui_connected} {
                    catch {close_service master $gui_connected}
                }
                break
            }
            default {
                puts "\n❌ Opción inválida"
                puts "Presiona ENTER para continuar..."
                gets stdin
            }
        }
    }
}

# ==============================================================================
# INICIO
# ==============================================================================
puts "\n╔══════════════════════════════════════════════════════════════════╗"
puts "║                   DSA INTERFAZ CARGADA                           ║"
puts "╚══════════════════════════════════════════════════════════════════╝"
puts ""
puts "Para iniciar la interfaz, ejecuta:"
puts "  main_loop"
puts ""
puts "O simplemente:"
puts ""

# Auto-iniciar
main_loop

