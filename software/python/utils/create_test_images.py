#!/usr/bin/env python3
"""
create_test_images.py
Genera imágenes de prueba para validación del downscaling

Genera múltiples patrones de prueba para validar el algoritmo:
- Imágenes uniformes
- Gradientes
- Tablero de ajedrez
- Patrones aleatorios
"""

import numpy as np
import sys
import os

# Agregar path para importar módulos de reference
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'reference'))
from downscale import save_image_to_txt, downscale_image


def create_uniform_image(width, height, value=128):
    """Crea imagen uniforme (todos los píxeles iguales)"""
    return np.full((height, width), value, dtype=np.uint8)


def create_gradient_horizontal(width, height):
    """Crea gradiente horizontal (0 → 255)"""
    image = np.zeros((height, width), dtype=np.uint8)
    for y in range(height):
        for x in range(width):
            image[y, x] = int((x / (width - 1)) * 255)
    return image


def create_gradient_vertical(width, height):
    """Crea gradiente vertical (0 → 255)"""
    image = np.zeros((height, width), dtype=np.uint8)
    for y in range(height):
        for x in range(width):
            image[y, x] = int((y / (height - 1)) * 255)
    return image


def create_checkerboard(width, height, square_size=8):
    """Crea patrón de tablero de ajedrez"""
    image = np.zeros((height, width), dtype=np.uint8)
    for y in range(height):
        for x in range(width):
            # Alternar entre 0 y 255
            if ((x // square_size) + (y // square_size)) % 2 == 0:
                image[y, x] = 255
            else:
                image[y, x] = 0
    return image


def create_random_image(width, height, seed=42):
    """Crea imagen aleatoria con seed fijo (reproducible)"""
    np.random.seed(seed)
    return np.random.randint(0, 256, size=(height, width), dtype=np.uint8)


def create_diagonal_gradient(width, height):
    """Crea gradiente diagonal"""
    image = np.zeros((height, width), dtype=np.uint8)
    max_dist = np.sqrt(width**2 + height**2)
    for y in range(height):
        for x in range(width):
            dist = np.sqrt(x**2 + y**2)
            image[y, x] = int((dist / max_dist) * 255)
    return image


def create_center_gradient(width, height):
    """Crea gradiente radial desde el centro"""
    image = np.zeros((height, width), dtype=np.uint8)
    cx, cy = width / 2, height / 2
    max_dist = np.sqrt(cx**2 + cy**2)

    for y in range(height):
        for x in range(width):
            dist = np.sqrt((x - cx)**2 + (y - cy)**2)
            image[y, x] = int(min(255, (dist / max_dist) * 255))

    return image


def main():
    print("="*70)
    print("GENERADOR DE IMÁGENES DE PRUEBA")
    print("="*70)
    print()

    # Configuración de tamaños
    src_w, src_h = 64, 64
    dst_w, dst_h = 32, 32

    output_dir = "../test_images"

    # Crear directorio de salida si no existe
    os.makedirs(output_dir, exist_ok=True)

    # Lista de imágenes a generar
    test_images = [
        ("uniform_black", create_uniform_image(src_w, src_h, 0),
         "Imagen uniforme negra (todos = 0)"),

        ("uniform_gray", create_uniform_image(src_w, src_h, 128),
         "Imagen uniforme gris (todos = 128)"),

        ("uniform_white", create_uniform_image(src_w, src_h, 255),
         "Imagen uniforme blanca (todos = 255)"),

        ("gradient_h", create_gradient_horizontal(src_w, src_h),
         "Gradiente horizontal (0 -> 255)"),

        ("gradient_v", create_gradient_vertical(src_w, src_h),
         "Gradiente vertical (0 -> 255)"),

        ("gradient_diag", create_diagonal_gradient(src_w, src_h),
         "Gradiente diagonal"),

        ("gradient_center", create_center_gradient(src_w, src_h),
         "Gradiente radial desde centro"),

        ("checkerboard_8", create_checkerboard(src_w, src_h, 8),
         "Tablero de ajedrez (cuadros de 8x8)"),

        ("checkerboard_4", create_checkerboard(src_w, src_h, 4),
         "Tablero de ajedrez (cuadros de 4x4)"),

        ("random_seed42", create_random_image(src_w, src_h, 42),
         "Imagen aleatoria (seed=42)"),
    ]

    print(f"Generando {len(test_images)} imágenes de prueba...")
    print(f"  Tamaño entrada: {src_w}x{src_h}")
    print(f"  Tamaño salida:  {dst_w}x{dst_h}")
    print(f"  Directorio:     {output_dir}")
    print()

    for name, src_image, description in test_images:
        print(f"[{name}] {description}")

        # Guardar imagen de entrada
        input_filename = os.path.join(output_dir, f"{name}_{src_w}x{src_h}.txt")
        save_image_to_txt(input_filename, src_image)

        # Procesar downscaling
        dst_image = downscale_image(src_image, src_w, src_h, dst_w, dst_h)

        # Guardar imagen de referencia (salida esperada)
        output_filename = os.path.join(output_dir, f"{name}_{dst_w}x{dst_h}_ref.txt")
        save_image_to_txt(output_filename, dst_image)

        print()

    print("="*70)
    print("OK COMPLETADO")
    print(f"  {len(test_images) * 2} archivos generados en {output_dir}/")
    print()
    print("Archivos generados:")
    for name, _, _ in test_images:
        print(f"  - {name}_{src_w}x{src_h}.txt")
        print(f"  - {name}_{dst_w}x{dst_h}_ref.txt")
    print()
    print("Uso:")
    print(f"  1. Cargar *_{src_w}x{src_h}.txt a FPGA")
    print(f"  2. Procesar en hardware")
    print(f"  3. Comparar resultado con *_{dst_w}x{dst_h}_ref.txt")
    print("="*70)


if __name__ == "__main__":
    main()
