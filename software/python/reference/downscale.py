#!/usr/bin/env python3
"""
downscale.py
Downscaling de imágenes usando interpolación bilineal con Q8.8

Este módulo implementa el algoritmo completo de reducción de imágenes
que será implementado en hardware.
"""

import numpy as np
import math
from bilinear_interpolation import bilinear_interpolate_pixel


def downscale_image(src_image, src_w, src_h, dst_w, dst_h):
    """
    Reduce una imagen usando interpolación bilineal

    Args:
        src_image: numpy array (H x W) con píxeles uint8
        src_w: Ancho de imagen origen
        src_h: Alto de imagen origen
        dst_w: Ancho de imagen destino
        dst_h: Alto de imagen destino

    Returns:
        numpy array (dst_h x dst_w) con imagen reducida
    """
    # Verificar dimensiones
    assert src_image.shape == (src_h, src_w), \
        f"Dimensiones incorrectas: esperado ({src_h},{src_w}), recibido {src_image.shape}"

    # Crear imagen de salida
    dst_image = np.zeros((dst_h, dst_w), dtype=np.uint8)

    # Calcular ratios
    x_ratio = float(src_w) / float(dst_w)
    y_ratio = float(src_h) / float(dst_h)

    print(f"Downscaling {src_w}x{src_h} -> {dst_w}x{dst_h}")
    print(f"  Ratios: x={x_ratio:.3f}, y={y_ratio:.3f}")

    # Para cada píxel de salida
    for y_dst in range(dst_h):
        for x_dst in range(dst_w):
            # Calcular posición en imagen origen
            x_src_f = x_dst * x_ratio
            y_src_f = y_dst * y_ratio

            # Extraer parte entera (coordenadas de esquina superior izquierda)
            x0 = int(math.floor(x_src_f))
            y0 = int(math.floor(y_src_f))

            # Calcular esquina opuesta (con límites)
            x1 = min(x0 + 1, src_w - 1)
            y1 = min(y0 + 1, src_h - 1)

            # Calcular pesos fraccionarios
            fx = x_src_f - x0
            fy = y_src_f - y0

            # Obtener 4 píxeles vecinos
            p00 = src_image[y0, x0]
            p01 = src_image[y0, x1]
            p10 = src_image[y1, x0]
            p11 = src_image[y1, x1]

            # Interpolar usando Q8.8
            pixel_out = bilinear_interpolate_pixel(p00, p01, p10, p11, fx, fy)

            # Guardar en imagen de salida
            dst_image[y_dst, x_dst] = pixel_out

        # Progress indicator (cada 10%)
        if (y_dst + 1) % max(1, dst_h // 10) == 0:
            progress = (y_dst + 1) / dst_h * 100
            print(f"  Progress: {progress:.0f}%")

    print(f"  Completado: {dst_w * dst_h} píxeles procesados")

    return dst_image


def load_image_from_txt(filename):
    """
    Carga imagen desde archivo de texto

    Formato esperado:
      - Línea 1: altura ancho
      - Resto: píxeles (0-255), uno por línea o separados por espacios

    Returns:
        tuple: (image, width, height)
    """
    print(f"Cargando imagen desde {filename}...")

    with open(filename, 'r') as f:
        # Leer primera línea (dimensiones)
        first_line = f.readline().strip()

        # Intentar parsear dimensiones
        try:
            parts = first_line.split()
            if len(parts) == 2:
                height = int(parts[0])
                width = int(parts[1])
            else:
                raise ValueError("Primera línea debe ser: altura ancho")
        except:
            raise ValueError(f"No se pudo parsear dimensiones de: {first_line}")

        print(f"  Dimensiones: {height}x{width}")

        # Leer píxeles
        pixels = []
        for line in f:
            line = line.strip()
            if line:  # Ignorar líneas vacías
                # Intentar múltiples píxeles por línea o uno solo
                values = line.split()
                for val in values:
                    pixels.append(int(val))

        # Verificar cantidad de píxeles
        expected_pixels = width * height
        if len(pixels) != expected_pixels:
            print(f"  ADVERTENCIA: Se esperaban {expected_pixels} pixeles, "
                  f"se leyeron {len(pixels)}")

        # Convertir a numpy array y reshape
        image = np.array(pixels[:expected_pixels], dtype=np.uint8)
        image = image.reshape((height, width))

        print(f"  OK Imagen cargada: min={np.min(image)}, max={np.max(image)}, "
              f"mean={np.mean(image):.1f}")

    return image, width, height


def save_image_to_txt(filename, image):
    """
    Guarda imagen a archivo de texto

    Formato:
      - Línea 1: altura ancho
      - Resto: píxeles (0-255), separados por espacios (múltiples por línea)
    """
    height, width = image.shape

    print(f"Guardando imagen a {filename}...")
    print(f"  Dimensiones: {height}x{width}")

    with open(filename, 'w') as f:
        # Escribir dimensiones
        f.write(f"{height} {width}\n")

        # Escribir píxeles (16 por línea para legibilidad)
        pixels_per_line = 16

        for y in range(height):
            for x in range(width):
                f.write(f"{image[y, x]:3d} ")

                # Nueva línea cada pixels_per_line píxeles
                if (x + 1) % pixels_per_line == 0 and x < width - 1:
                    f.write("\n")

            f.write("\n")  # Nueva línea al final de cada fila

    print(f"  OK Imagen guardada: {width * height} pixeles")


# Programa principal
if __name__ == "__main__":
    import sys

    print("="*60)
    print("MODELO DE REFERENCIA: Downscaling con Interpolación Bilineal")
    print("="*60)
    print()

    # Parsear argumentos
    if len(sys.argv) < 7:
        print("Uso: python downscale.py input.txt output.txt src_w src_h dst_w dst_h")
        print()
        print("Ejemplo:")
        print("  python downscale.py imagen_64x64.txt salida_32x32.txt 64 64 32 32")
        print()

        # Ejecutar test por defecto si no hay argumentos
        print("Ejecutando test por defecto con imagen sintética...")
        print()

        # Crear imagen de prueba (gradiente)
        src_w, src_h = 64, 64
        dst_w, dst_h = 32, 32

        print(f"Generando imagen de prueba {src_w}x{src_h} (gradiente horizontal)...")
        src_image = np.zeros((src_h, src_w), dtype=np.uint8)
        for y in range(src_h):
            for x in range(src_w):
                src_image[y, x] = int((x / (src_w - 1)) * 255)

        # Guardar imagen origen
        save_image_to_txt("test_input_64x64.txt", src_image)

        # Procesar
        dst_image = downscale_image(src_image, src_w, src_h, dst_w, dst_h)

        # Guardar resultado
        save_image_to_txt("test_output_32x32.txt", dst_image)

        print()
        print("="*60)
        print("OK Test completado")
        print("  Archivos generados:")
        print("    - test_input_64x64.txt")
        print("    - test_output_32x32.txt")
        print("="*60)

    else:
        # Modo normal con argumentos
        input_file = sys.argv[1]
        output_file = sys.argv[2]
        src_w = int(sys.argv[3])
        src_h = int(sys.argv[4])
        dst_w = int(sys.argv[5])
        dst_h = int(sys.argv[6])

        # Cargar imagen
        src_image, _, _ = load_image_from_txt(input_file)

        # Verificar dimensiones
        if src_image.shape != (src_h, src_w):
            print(f"ERROR: Dimensiones no coinciden")
            print(f"  Esperado: {src_h}x{src_w}")
            print(f"  Recibido: {src_image.shape[0]}x{src_image.shape[1]}")
            sys.exit(1)

        # Procesar
        print()
        dst_image = downscale_image(src_image, src_w, src_h, dst_w, dst_h)

        # Guardar
        print()
        save_image_to_txt(output_file, dst_image)

        print()
        print("="*60)
        print("OK Procesamiento completado exitosamente")
        print("="*60)
