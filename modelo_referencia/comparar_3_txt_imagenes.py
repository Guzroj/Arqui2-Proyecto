#!/usr/bin/env python3
# ============================================================================
# comparar_3_txt_imagenes.py
# ============================================================================
# Compara 3 imágenes en formato .txt:
#   - Original
#   - Salida Secuencial
#   - Salida SIMD
#
# Muestra:
#   - Dimensiones y factores de escala respecto a la original
#   - Visualización en un grid 1x3: [Original | Secuencial | SIMD]
#
# Formato de los .txt:
#   - Valores 0–255
#   - Separados por espacios y/o saltos de línea
#   - Imagen de tamaño width × height
#
# Uso:
#   python3 comparar_3_txt_imagenes.py \
#     <orig.txt> <w_in> <h_in> \
#     <seq.txt>  <w_seq> <h_seq> \
#     <simd.txt> <w_simd> <h_simd>
#
# Ejemplo (512x512 -> 256x256):
#   python3 comparar_3_txt_imagenes.py \
#     ../imagen_grayscale.txt 512 512 \
#     output_seq.txt 256 256 \
#     output_simd.txt 256 256
# ============================================================================

import sys
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np


def load_txt_image(path: Path, width: int, height: int) -> np.ndarray:
    """Carga una imagen desde un .txt (valores 0–255) y la devuelve como array 2D."""
    if not path.exists():
        print(f"Error: archivo no encontrado: {path}")
        sys.exit(1)

    values = []
    with path.open("r") as f:
        for line in f:
            parts = line.strip().split()
            for p in parts:
                if p:
                    try:
                        values.append(int(p))
                    except ValueError:
                        print(f"Valor no numérico encontrado en {path}: '{p}'")
                        sys.exit(1)

    expected = width * height
    if len(values) != expected:
        print(f"Error en {path}: se esperaban {expected} píxeles y hay {len(values)}")
        sys.exit(1)

    return np.array(values, dtype=np.uint8).reshape((height, width))


def main():
    # sys.argv[0] = nombre del script
    # Luego esperamos 9 argumentos:
    #   orig.txt w_in h_in seq.txt w_seq h_seq simd.txt w_simd h_simd
    if len(sys.argv) != 10:
        print(
            "Uso: python3 comparar_3_txt_imagenes.py "
            "<orig.txt> <w_in> <h_in> "
            "<seq.txt> <w_seq> <h_seq> "
            "<simd.txt> <w_simd> <h_simd>"
        )
        sys.exit(1)

    orig_path = Path(sys.argv[1])
    seq_path = Path(sys.argv[4])
    simd_path = Path(sys.argv[7])

    try:
        w_in = int(sys.argv[2])
        h_in = int(sys.argv[3])
        w_seq = int(sys.argv[5])
        h_seq = int(sys.argv[6])
        w_simd = int(sys.argv[8])
        h_simd = int(sys.argv[9])
    except ValueError:
        print("Error: todas las dimensiones deben ser enteros.")
        sys.exit(1)

    # Cargar imágenes
    img_in = load_txt_image(orig_path, w_in, h_in)
    img_seq = load_txt_image(seq_path, w_seq, h_seq)
    img_simd = load_txt_image(simd_path, w_simd, h_simd)

    # Info en consola
    print("\n=============================================")
    print("  Comparación de Imágenes (Original / Sec / SIMD)")
    print("=============================================")

    print(f"Original  : {orig_path}")
    print(f"  Tamaño  : {w_in} × {h_in}")

    print(f"Secuencial: {seq_path}")
    print(f"  Tamaño  : {w_seq} × {h_seq}")
    print(
        f"  Escala  : width {w_seq / w_in:.3f}, height {h_seq / h_in:.3f} "
        "(vs original)"
    )

    print(f"SIMD      : {simd_path}")
    print(f"  Tamaño  : {w_simd} × {h_simd}")
    print(
        f"  Escala  : width {w_simd / w_in:.3f}, height {h_simd / h_in:.3f} "
        "(vs original)"
    )
    print("=============================================\n")

    # Visualizar en grid 1x3
    fig, axes = plt.subplots(1, 3, figsize=(15, 5))

    axes[0].imshow(img_in, cmap="gray", vmin=0, vmax=255)
    axes[0].set_title(f"Original\n{w_in}×{h_in}")
    axes[0].axis("off")

    axes[1].imshow(img_seq, cmap="gray", vmin=0, vmax=255)
    axes[1].set_title(f"Secuencial\n{w_seq}×{h_seq}")
    axes[1].axis("off")

    axes[2].imshow(img_simd, cmap="gray", vmin=0, vmax=255)
    axes[2].set_title(f"SIMD\n{w_simd}×{h_simd}")
    axes[2].axis("off")

    plt.tight_layout()
    plt.show()


if __name__ == "__main__":
    main()


