#!/usr/bin/env python3
# ============================================================================
# test_dsa_downscale.py
# ============================================================================
# Script Python para generar imágenes de prueba y analizar resultados
# del DSA Downscaler
#
# Características:
#   - Genera imágenes de prueba en formato .mif para BRAM
#   - Calcula downscaling esperado (referencia) con interpolación bilineal
#   - Compara resultados del DSA vs referencia
#   - Visualiza imágenes (requiere matplotlib)
#
# Uso:
#   python test_dsa_downscale.py --generate --input 512 512 --output 256 256
#   python test_dsa_downscale.py --analyze resultado.txt
#
# Autor: DSA Project Team
# Fecha: Diciembre 2025
# ============================================================================

import numpy as np
import argparse
from pathlib import Path

# ============================================================================
# Interpolación Bilineal (Referencia)
# ============================================================================
def bilinear_downscale(img_in, width_out, height_out):
    """
    Downscaling con interpolación bilineal (referencia).

    Args:
        img_in: Imagen de entrada (numpy array 2D, uint8)
        width_out: Ancho de salida
        height_out: Alto de salida

    Returns:
        Imagen de salida (numpy array 2D, uint8)
    """
    height_in, width_in = img_in.shape
    img_out = np.zeros((height_out, width_out), dtype=np.uint8)

    # Ratios de escala
    x_ratio = (width_in - 1) / (width_out - 1) if width_out > 1 else 0
    y_ratio = (height_in - 1) / (height_out - 1) if height_out > 1 else 0

    for y_out in range(height_out):
        for x_out in range(width_out):
            # Posición en imagen de entrada (punto flotante)
            x_in = x_out * x_ratio
            y_in = y_out * y_ratio

            # Coordenadas enteras
            x0 = int(x_in)
            y0 = int(y_in)
            x1 = min(x0 + 1, width_in - 1)
            y1 = min(y0 + 1, height_in - 1)

            # Coeficientes de interpolación (Q0.8 compatible con DSA)
            alpha = int((x_in - x0) * 256) & 0xFF
            beta = int((y_in - y0) * 256) & 0xFF

            # Obtener 4 píxeles vecinos
            p00 = int(img_in[y0, x0])
            p01 = int(img_in[y0, x1])
            p10 = int(img_in[y1, x0])
            p11 = int(img_in[y1, x1])

            # Interpolación bilineal (Q0.16 interno, como el DSA)
            top = ((256 - alpha) * p00 + alpha * p01)
            bottom = ((256 - alpha) * p10 + alpha * p11)
            result = ((256 - beta) * top + beta * bottom) >> 16

            img_out[y_out, x_out] = np.clip(result, 0, 255)

    return img_out

# ============================================================================
# Generación de Patrones de Prueba
# ============================================================================
def generate_gradient(width, height):
    """Genera gradiente diagonal"""
    img = np.zeros((height, width), dtype=np.uint8)
    for y in range(height):
        for x in range(width):
            img[y, x] = int(((x + y) / (width + height - 2)) * 255)
    return img

def generate_checkerboard(width, height, block_size=32):
    """Genera patrón checkerboard"""
    img = np.zeros((height, width), dtype=np.uint8)
    for y in range(height):
        for x in range(width):
            if ((x // block_size) + (y // block_size)) % 2 == 0:
                img[y, x] = 255
    return img

def generate_circles(width, height):
    """Genera círculos concéntricos"""
    img = np.zeros((height, width), dtype=np.uint8)
    cx, cy = width // 2, height // 2
    max_dist = np.sqrt(cx**2 + cy**2)

    for y in range(height):
        for x in range(width):
            dist = np.sqrt((x - cx)**2 + (y - cy)**2)
            img[y, x] = int((np.sin(dist / max_dist * 8 * np.pi) + 1) * 127.5)

    return img

# ============================================================================
# Exportar a MIF (Memory Initialization File)
# ============================================================================
def export_to_mif(img, filename):
    """
    Exporta imagen a formato .mif para inicializar BRAM.

    Args:
        img: Imagen (numpy array 2D, uint8)
        filename: Nombre del archivo .mif
    """
    height, width = img.shape
    total_bytes = width * height

    # Convertir a words de 32 bits (4 bytes por word)
    num_words = (total_bytes + 3) // 4

    with open(filename, 'w') as f:
        f.write(f"-- Memory Initialization File (.mif)\n")
        f.write(f"-- Generated for {width}x{height} image\n")
        f.write(f"-- Total: {total_bytes} bytes = {num_words} words\n\n")
        f.write(f"DEPTH = {num_words};\n")
        f.write(f"WIDTH = 32;\n")
        f.write(f"ADDRESS_RADIX = HEX;\n")
        f.write(f"DATA_RADIX = HEX;\n\n")
        f.write(f"CONTENT\n")
        f.write(f"BEGIN\n")

        # Escribir datos
        flat_img = img.flatten()
        addr = 0

        for i in range(0, total_bytes, 4):
            # Construir word de 32 bits (little-endian)
            word = 0
            for j in range(4):
                if i + j < total_bytes:
                    word |= (flat_img[i + j] << (j * 8))

            f.write(f"  {addr:04X} : {word:08X};\n")
            addr += 1

        f.write(f"END;\n")

    print(f"Archivo MIF generado: {filename}")

# ============================================================================
# Exportar a archivo binario (para TCL)
# ============================================================================
def export_to_bin(img, filename):
    """
    Exporta imagen a archivo binario.

    Args:
        img: Imagen (numpy array 2D, uint8)
        filename: Nombre del archivo .bin
    """
    img.flatten().tofile(filename)
    print(f"Archivo binario generado: {filename}")

# ============================================================================
# Exportar a archivo TCL (lista de bytes)
# ============================================================================
def export_to_tcl(img, filename):
    """
    Exporta imagen como lista TCL de bytes.

    Args:
        img: Imagen (numpy array 2D, uint8)
        filename: Nombre del archivo .tcl
    """
    height, width = img.shape
    flat_img = img.flatten()

    with open(filename, 'w') as f:
        f.write(f"# Imagen {width}x{height}\n")
        f.write(f"set image_data {{\n")

        for i, pixel in enumerate(flat_img):
            if i % 16 == 0:
                f.write("    ")
            f.write(f"{pixel:3d} ")
            if (i + 1) % 16 == 0:
                f.write("\n")

        if len(flat_img) % 16 != 0:
            f.write("\n")

        f.write(f"}}\n")

    print(f"Archivo TCL generado: {filename}")

# ============================================================================
# Comparación DSA vs Referencia
# ============================================================================
def compare_images(img_dsa, img_ref, tolerance=2):
    """
    Compara imagen del DSA vs referencia.

    Args:
        img_dsa: Imagen del DSA (numpy array 2D, uint8)
        img_ref: Imagen de referencia (numpy array 2D, uint8)
        tolerance: Tolerancia máxima de error (valor absoluto)

    Returns:
        dict con métricas de comparación
    """
    diff = np.abs(img_dsa.astype(int) - img_ref.astype(int))

    metrics = {
        'mean_error': np.mean(diff),
        'max_error': np.max(diff),
        'num_errors': np.sum(diff > tolerance),
        'error_rate': np.sum(diff > tolerance) / diff.size,
        'psnr': 10 * np.log10(255**2 / np.mean(diff**2)) if np.mean(diff**2) > 0 else float('inf')
    }

    return metrics

# ============================================================================
# Visualización (requiere matplotlib)
# ============================================================================
def visualize_images(img_in, img_out, img_ref=None):
    """
    Visualiza imágenes (requiere matplotlib).

    Args:
        img_in: Imagen de entrada
        img_out: Imagen de salida (DSA)
        img_ref: Imagen de referencia (opcional)
    """
    try:
        import matplotlib.pyplot as plt
    except ImportError:
        print("ADVERTENCIA: matplotlib no instalado, omitiendo visualización")
        return

    if img_ref is not None:
        fig, axes = plt.subplots(1, 4, figsize=(16, 4))
        axes[0].imshow(img_in, cmap='gray', vmin=0, vmax=255)
        axes[0].set_title('Entrada')
        axes[0].axis('off')

        axes[1].imshow(img_out, cmap='gray', vmin=0, vmax=255)
        axes[1].set_title('Salida DSA')
        axes[1].axis('off')

        axes[2].imshow(img_ref, cmap='gray', vmin=0, vmax=255)
        axes[2].set_title('Referencia')
        axes[2].axis('off')

        diff = np.abs(img_out.astype(int) - img_ref.astype(int))
        im = axes[3].imshow(diff, cmap='hot', vmin=0, vmax=10)
        axes[3].set_title('Diferencia (DSA - Ref)')
        axes[3].axis('off')
        plt.colorbar(im, ax=axes[3])
    else:
        fig, axes = plt.subplots(1, 2, figsize=(10, 5))
        axes[0].imshow(img_in, cmap='gray', vmin=0, vmax=255)
        axes[0].set_title('Entrada')
        axes[0].axis('off')

        axes[1].imshow(img_out, cmap='gray', vmin=0, vmax=255)
        axes[1].set_title('Salida DSA')
        axes[1].axis('off')

    plt.tight_layout()
    plt.show()

# ============================================================================
# Main
# ============================================================================
def main():
    parser = argparse.ArgumentParser(description='DSA Downscaler - Test Generator')
    parser.add_argument('--generate', action='store_true', help='Generar imagen de prueba')
    parser.add_argument('--pattern', choices=['gradient', 'checkerboard', 'circles'],
                        default='gradient', help='Tipo de patrón')
    parser.add_argument('--input', nargs=2, type=int, metavar=('WIDTH', 'HEIGHT'),
                        default=[512, 512], help='Dimensiones de entrada')
    parser.add_argument('--output', nargs=2, type=int, metavar=('WIDTH', 'HEIGHT'),
                        default=[256, 256], help='Dimensiones de salida')
    parser.add_argument('--format', choices=['mif', 'bin', 'tcl', 'all'],
                        default='all', help='Formato de salida')
    parser.add_argument('--visualize', action='store_true', help='Mostrar visualización')

    args = parser.parse_args()

    if args.generate:
        width_in, height_in = args.input
        width_out, height_out = args.output

        print(f"\nGenerando patrón '{args.pattern}' ({width_in}×{height_in})")

        # Generar imagen de entrada
        if args.pattern == 'gradient':
            img_in = generate_gradient(width_in, height_in)
        elif args.pattern == 'checkerboard':
            img_in = generate_checkerboard(width_in, height_in)
        elif args.pattern == 'circles':
            img_in = generate_circles(width_in, height_in)

        # Calcular referencia (downscale esperado)
        print(f"Calculando downscale de referencia ({width_out}×{height_out})")
        img_ref = bilinear_downscale(img_in, width_out, height_out)

        # Exportar archivos
        base_name = f"{args.pattern}_{width_in}x{height_in}_to_{width_out}x{height_out}"

        if args.format in ['mif', 'all']:
            export_to_mif(img_in, f"{base_name}_input.mif")

        if args.format in ['bin', 'all']:
            export_to_bin(img_in, f"{base_name}_input.bin")

        if args.format in ['tcl', 'all']:
            export_to_tcl(img_in, f"{base_name}_input.tcl")

        # Guardar referencia
        np.save(f"{base_name}_reference.npy", img_ref)
        print(f"Referencia guardada: {base_name}_reference.npy")

        # Visualizar
        if args.visualize:
            visualize_images(img_in, img_ref)

        print(f"\n✓ Generación completada")

    else:
        parser.print_help()

if __name__ == '__main__':
    main()
