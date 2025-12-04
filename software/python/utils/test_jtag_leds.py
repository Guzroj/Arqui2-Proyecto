#!/usr/bin/env python3
# ============================================================================
# test_jtag_leds.py
# Cliente de prueba para JTAG LED Server
# Basado en: https://idlelogiclabs.com/2012/04/15/talking-to-the-de0-nano-using-the-virtual-jtag-interface/
# Adaptado para DE1-SoC con 8 LEDs
# ============================================================================

import socket
import time
import sys

# ============================================================================
# Configuracion
# ============================================================================
HOST = 'localhost'
PORT = 2540
LED_WIDTH = 8  # 8 bits para 8 LEDs

# ============================================================================
# Funciones de comunicacion
# ============================================================================

def connect_to_server(host, port):
    """Conecta al servidor JTAG TCL"""
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.connect((host, port))
        print(f"[OK] Conectado al servidor JTAG en {host}:{port}")

        # Recibir mensaje de bienvenida
        welcome = s.recv(1024).decode('utf-8').strip()
        print(f"[OK] Servidor: {welcome}\n")

        return s
    except Exception as e:
        print(f"[X] Error al conectar al servidor: {e}")
        sys.exit(1)

def set_leds(conn, value):
    """Envia comando para configurar LEDs"""
    try:
        cmd = f"set_leds {value}\n"
        conn.send(cmd.encode('utf-8'))

        # Esperar respuesta
        response = conn.recv(1024).decode('utf-8').strip()
        if response != "OK":
            print(f"[X] Error: {response}")
            return False
        return True
    except Exception as e:
        print(f"[X] Error al enviar comando: {e}")
        return False

def close_connection(conn):
    """Cierra la conexion con el servidor"""
    try:
        conn.send(b"quit\n")
        conn.close()
        print("\n[OK] Conexion cerrada")
    except:
        pass

# ============================================================================
# Tests
# ============================================================================

def test_binary_counter(conn):
    """Test 1: Contador binario 0-255"""
    print("==========================================")
    print("TEST 1: Contador binario (0-255)")
    print("==========================================")

    for val in range(256):
        print(f"LEDs = {val:3d} (0b{val:08b})", end='\r')
        if not set_leds(conn, val):
            print("\n[X] Test fallido")
            return False
        time.sleep(0.05)  # 50ms delay

    print("\n[OK] Test completado correctamente\n")
    return True

def test_walking_ones(conn):
    """Test 2: Walking ones (1 bit encendido a la vez)"""
    print("==========================================")
    print("TEST 2: Walking Ones")
    print("==========================================")

    for i in range(8):
        val = 1 << i
        print(f"LED[{i}] = 1 (0b{val:08b})")
        if not set_leds(conn, val):
            print("\n[X] Test fallido")
            return False
        time.sleep(0.3)  # 300ms delay

    print("[OK] Test completado correctamente\n")
    return True

def test_walking_zeros(conn):
    """Test 3: Walking zeros (1 bit apagado a la vez)"""
    print("==========================================")
    print("TEST 3: Walking Zeros")
    print("==========================================")

    for i in range(8):
        val = 0xFF ^ (1 << i)
        print(f"LED[{i}] = 0 (0b{val:08b})")
        if not set_leds(conn, val):
            print("\n[X] Test fallido")
            return False
        time.sleep(0.3)  # 300ms delay

    print("[OK] Test completado correctamente\n")
    return True

def test_patterns(conn):
    """Test 4: Patrones especificos"""
    print("==========================================")
    print("TEST 4: Patrones")
    print("==========================================")

    patterns = [
        (0x00, "Todos apagados"),
        (0xFF, "Todos encendidos"),
        (0xAA, "Patron 10101010"),
        (0x55, "Patron 01010101"),
        (0x0F, "Nibble bajo"),
        (0xF0, "Nibble alto"),
        (0x81, "Extremos (10000001)"),
        (0x42, "Centro (01000010)")
    ]

    for val, desc in patterns:
        print(f"{desc}: 0b{val:08b} (0x{val:02X})")
        if not set_leds(conn, val):
            print("\n[X] Test fallido")
            return False
        time.sleep(0.5)  # 500ms delay

    print("[OK] Test completado correctamente\n")
    return True

def test_custom_value(conn, value):
    """Test personalizado con valor especifico"""
    print("==========================================")
    print(f"TEST: Valor personalizado = {value}")
    print("==========================================")

    if value < 0 or value > 255:
        print(f"[X] Error: Valor debe estar entre 0 y 255")
        return False

    print(f"LEDs = {value} (0b{value:08b}, 0x{value:02X})")
    if not set_leds(conn, value):
        print("\n[X] Test fallido")
        return False

    print("[OK] Test completado correctamente\n")
    return True

# ============================================================================
# Main
# ============================================================================

def main():
    print("\n==========================================")
    print("JTAG LED Test Client - FASE 3")
    print("==========================================\n")

    # Menu de tests
    if len(sys.argv) > 1:
        if sys.argv[1] == "counter":
            test_func = test_binary_counter
        elif sys.argv[1] == "walking1":
            test_func = test_walking_ones
        elif sys.argv[1] == "walking0":
            test_func = test_walking_zeros
        elif sys.argv[1] == "patterns":
            test_func = test_patterns
        elif sys.argv[1] == "custom" and len(sys.argv) > 2:
            try:
                value = int(sys.argv[2], 0)  # Soporta 0x, 0b, decimal
                test_func = lambda conn: test_custom_value(conn, value)
            except ValueError:
                print(f"[X] Error: Valor invalido '{sys.argv[2]}'")
                sys.exit(1)
        else:
            print("Uso: python test_jtag_leds.py [test]")
            print("\nTests disponibles:")
            print("  counter   - Contador binario 0-255")
            print("  walking1  - Walking ones")
            print("  walking0  - Walking zeros")
            print("  patterns  - Patrones especificos")
            print("  custom <value> - Valor personalizado (decimal, 0x, 0b)")
            print("\nEjemplos:")
            print("  python test_jtag_leds.py counter")
            print("  python test_jtag_leds.py custom 170")
            print("  python test_jtag_leds.py custom 0xAA")
            print("  python test_jtag_leds.py custom 0b10101010")
            sys.exit(1)
    else:
        # Por defecto, ejecutar todos los tests
        test_func = None

    # Conectar al servidor
    conn = connect_to_server(HOST, PORT)

    try:
        if test_func:
            # Ejecutar test especifico
            test_func(conn)
        else:
            # Ejecutar todos los tests
            test_binary_counter(conn)
            test_walking_ones(conn)
            test_walking_zeros(conn)
            test_patterns(conn)

        # Apagar todos los LEDs al final
        print("Apagando todos los LEDs...")
        set_leds(conn, 0x00)

    finally:
        close_connection(conn)

if __name__ == "__main__":
    main()
