#!/usr/bin/env python3
# ============================================================================
# downscale_client.py
# Cliente Python para control de sistema de downscaling via JTAG
# Arquitectura de Computadores 2 - FASE 6
# ============================================================================

import socket
import sys
import time
import numpy as np
from pathlib import Path
from typing import List, Tuple, Optional

# ============================================================================
# Configuración
# ============================================================================
SERVER_HOST = "127.0.0.1"
SERVER_PORT = 2540

INPUT_WIDTH = 64
INPUT_HEIGHT = 64
OUTPUT_WIDTH = 32
OUTPUT_HEIGHT = 32

# ============================================================================
# Clase cliente JTAG
# ============================================================================

class JTAGDownscaleClient:
    """Cliente para comunicarse con el servidor JTAG de downscaling"""

    def __init__(self, host: str = SERVER_HOST, port: int = SERVER_PORT):
        self.host = host
        self.port = port
        self.sock = None

    def connect(self):
        """Conectar al servidor TCL"""
        print(f"Conectando a {self.host}:{self.port}...")
        try:
            self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.sock.connect((self.host, self.port))
            print("Conectado exitosamente")
        except ConnectionRefusedError:
            print(f"ERROR: No se pudo conectar al servidor en {self.host}:{self.port}")
            print("Asegúrate de que el servidor TCL esté ejecutándose")
            sys.exit(1)
        except Exception as e:
            print(f"ERROR de conexión: {e}")
            sys.exit(1)

    def disconnect(self):
        """Desconectar del servidor"""
        if self.sock:
            try:
                self.send_command("CLOSE")
                self.sock.close()
                print("Desconectado del servidor")
            except:
                pass
            finally:
                self.sock = None

    def send_command(self, command: str) -> str:
        """Enviar comando al servidor y recibir respuesta"""
        if not self.sock:
            raise RuntimeError("No conectado al servidor")

        try:
            # Enviar comando
            self.sock.sendall((command + "\n").encode())

            # Recibir respuesta
            response = self.sock.recv(65536).decode().strip()

            return response
        except Exception as e:
            print(f"ERROR en comunicación: {e}")
            raise

    def get_status(self) -> Tuple[int, int, int, int]:
        """Obtener estado del sistema"""
        response = self.send_command("STATUS")

        if not response.startswith("OK"):
            raise RuntimeError(f"Error obteniendo estado: {response}")

        # Parsear respuesta: OK <busy> <done> <fsm_state> <pixel_count>
        parts = response.split()
        busy = int(parts[1])
        done = int(parts[2])
        fsm_state = int(parts[3])
        pixel_count = int(parts[4])

        return (busy, done, fsm_state, pixel_count)

    def print_status(self):
        """Imprimir estado del sistema"""
        busy, done, fsm_state, pixel_count = self.get_status()

        print("=" * 50)
        print("Estado del Sistema")
        print("=" * 50)
        print(f"BUSY:        {busy}")
        print(f"DONE:        {done}")
        print(f"FSM State:   {fsm_state}")
        print(f"Pixels:      {pixel_count} / 1024")
        print("=" * 50)

    def start_processing(self):
        """Iniciar procesamiento de downscaling"""
        print("Enviando comando START...")
        response = self.send_command("START")

        if not response.startswith("OK"):
            raise RuntimeError(f"Error iniciando procesamiento: {response}")

        print("Comando START enviado exitosamente")

    def reset_system(self):
        """Resetear sistema"""
        print("Enviando comando RESET...")
        response = self.send_command("RESET")

        if not response.startswith("OK"):
            raise RuntimeError(f"Error reseteando sistema: {response}")

        print("Sistema reseteado")

    def upload_image(self, image_data: np.ndarray):
        """
        Subir imagen al FPGA

        Args:
            image_data: Array de NumPy de tamaño (64, 64) con valores 0-255
        """
        if image_data.shape != (INPUT_HEIGHT, INPUT_WIDTH):
            raise ValueError(f"Tamaño de imagen incorrecto: {image_data.shape}. Esperado: ({INPUT_HEIGHT}, {INPUT_WIDTH})")

        # Convertir a lista plana de enteros
        pixels = image_data.flatten().astype(int).tolist()

        # Validar rango
        if any(p < 0 or p > 255 for p in pixels):
            raise ValueError("Valores de píxeles deben estar en rango 0-255")

        print(f"Subiendo imagen de {INPUT_WIDTH}x{INPUT_HEIGHT}...")

        # Construir comando: UPLOAD <num_pixels> <pixel1> <pixel2> ... <pixelN>
        pixels_str = " ".join(map(str, pixels))
        command = f"UPLOAD {len(pixels)} {pixels_str}"

        response = self.send_command(command)

        if not response.startswith("OK"):
            raise RuntimeError(f"Error subiendo imagen: {response}")

        print(f"Imagen subida exitosamente: {len(pixels)} píxeles")

    def download_image(self) -> np.ndarray:
        """
        Descargar imagen procesada del FPGA

        Returns:
            Array de NumPy de tamaño (32, 32) con valores 0-255
        """
        print(f"Descargando imagen de {OUTPUT_WIDTH}x{OUTPUT_HEIGHT}...")

        response = self.send_command("DOWNLOAD")

        if not response.startswith("OK"):
            raise RuntimeError(f"Error descargando imagen: {response}")

        # Parsear respuesta: OK <num_pixels> <pixel1> <pixel2> ... <pixelN>
        parts = response.split()
        num_pixels = int(parts[1])
        pixels = [int(p) for p in parts[2:]]

        if len(pixels) != num_pixels:
            raise RuntimeError(f"Número de píxeles incorrecto: esperado {num_pixels}, recibido {len(pixels)}")

        expected_pixels = OUTPUT_WIDTH * OUTPUT_HEIGHT
        if num_pixels != expected_pixels:
            raise RuntimeError(f"Tamaño de imagen incorrecto: esperado {expected_pixels}, recibido {num_pixels}")

        print(f"Imagen descargada exitosamente: {num_pixels} píxeles")

        # Convertir a array 2D
        image_data = np.array(pixels, dtype=np.uint8).reshape((OUTPUT_HEIGHT, OUTPUT_WIDTH))

        return image_data

    def process_image(self, image_data: np.ndarray) -> np.ndarray:
        """
        Procesar imagen completa (upload + start + wait + download)

        Args:
            image_data: Array de NumPy de tamaño (64, 64) con valores 0-255

        Returns:
            Array de NumPy de tamaño (32, 32) con valores 0-255
        """
        print("\n" + "=" * 50)
        print("Procesamiento de Imagen - Downscaling")
        print("=" * 50)

        # 1. Subir imagen
        self.upload_image(image_data)

        # 2. Verificar estado inicial
        self.print_status()

        # 3. Iniciar procesamiento
        self.start_processing()

        # 4. Esperar a que termine (polling)
        print("\nEsperando que termine el procesamiento...")
        timeout = 30  # segundos
        start_time = time.time()

        while True:
            busy, done, fsm_state, pixel_count = self.get_status()

            if done == 1 and busy == 0:
                print(f"Procesamiento completado: {pixel_count} píxeles procesados")
                break

            elapsed = time.time() - start_time
            if elapsed > timeout:
                raise TimeoutError(f"El procesamiento no terminó en {timeout} segundos")

            # Mostrar progreso
            progress = (pixel_count / 1024.0) * 100
            print(f"Progreso: {progress:.1f}% ({pixel_count}/1024 píxeles)", end="\r")

            time.sleep(0.2)

        # 5. Descargar resultado
        output_image = self.download_image()

        print("=" * 50)
        print("Procesamiento completado exitosamente")
        print("=" * 50)

        return output_image

# ============================================================================
# Funciones de utilidad para imágenes
# ============================================================================

def create_test_pattern(pattern_type: str = "gradient") -> np.ndarray:
    """
    Crear patrón de prueba de 64x64

    Args:
        pattern_type: Tipo de patrón ("gradient", "checkerboard", "constant", "random")

    Returns:
        Array de NumPy de tamaño (64, 64)
    """
    if pattern_type == "gradient":
        # Gradiente horizontal
        image = np.tile(np.linspace(0, 255, INPUT_WIDTH, dtype=np.uint8), (INPUT_HEIGHT, 1))

    elif pattern_type == "checkerboard":
        # Tablero de ajedrez
        image = np.zeros((INPUT_HEIGHT, INPUT_WIDTH), dtype=np.uint8)
        for y in range(INPUT_HEIGHT):
            for x in range(INPUT_WIDTH):
                if (x // 8 + y // 8) % 2 == 0:
                    image[y, x] = 255

    elif pattern_type == "constant":
        # Valor constante
        image = np.full((INPUT_HEIGHT, INPUT_WIDTH), 128, dtype=np.uint8)

    elif pattern_type == "random":
        # Patrón aleatorio
        image = np.random.randint(0, 256, (INPUT_HEIGHT, INPUT_WIDTH), dtype=np.uint8)

    else:
        raise ValueError(f"Tipo de patrón desconocido: {pattern_type}")

    return image

def save_image_txt(image: np.ndarray, filename: str):
    """Guardar imagen como archivo de texto"""
    np.savetxt(filename, image, fmt='%3d')
    print(f"Imagen guardada en: {filename}")

def load_image_txt(filename: str) -> np.ndarray:
    """Cargar imagen desde archivo de texto"""
    image = np.loadtxt(filename, dtype=np.uint8)
    print(f"Imagen cargada desde: {filename}")
    return image

def print_image_ascii(image: np.ndarray):
    """Imprimir imagen como arte ASCII"""
    chars = " .:-=+*#%@"
    height, width = image.shape

    print(f"\nImagen ASCII ({width}x{height}):")
    print("=" * (width + 2))

    for y in range(height):
        line = "|"
        for x in range(width):
            val = image[y, x]
            char_idx = int((val / 255.0) * (len(chars) - 1))
            line += chars[char_idx]
        line += "|"
        print(line)

    print("=" * (width + 2))

# ============================================================================
# Función principal
# ============================================================================

def main():
    """Función principal de prueba"""
    print("=" * 50)
    print("Cliente JTAG - Downscaling 64x64 → 32x32")
    print("=" * 50)

    # Crear cliente
    client = JTAGDownscaleClient()

    try:
        # Conectar
        client.connect()

        # Verificar estado inicial
        client.print_status()

        # Crear imagen de prueba
        print("\nCreando patrón de prueba (gradiente)...")
        input_image = create_test_pattern("gradient")

        # Procesar imagen
        output_image = client.process_image(input_image)

        # Guardar resultados
        save_image_txt(input_image, "input_64x64.txt")
        save_image_txt(output_image, "output_32x32.txt")

        # Mostrar imágenes en ASCII
        print_image_ascii(output_image)

        # Verificar resultado
        print("\nEstadísticas de la imagen de salida:")
        print(f"Min:  {output_image.min()}")
        print(f"Max:  {output_image.max()}")
        print(f"Mean: {output_image.mean():.2f}")
        print(f"Std:  {output_image.std():.2f}")

        # Desconectar
        client.disconnect()

        print("\n¡Prueba completada exitosamente!")

    except Exception as e:
        print(f"\nERROR: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == "__main__":
    # Verificar que NumPy esté instalado
    try:
        import numpy as np
    except ImportError:
        print("ERROR: NumPy no está instalado")
        print("Instalar con: pip install numpy")
        sys.exit(1)

    main()
