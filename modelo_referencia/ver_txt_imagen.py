#!/usr/bin/env python3
# ============================================================================
# ver_txt_imagen.py
# ============================================================================
# Script sencillo para visualizar archivos .txt de imágenes en escala de grises
# Formato esperado:
#   - Valores 0–255
#   - Separados por espacios y/o saltos de línea
#   - Una imagen de tamaño width × height
# Uso:
#   python ver_txt_imagen.py <input.txt> <width> <height> [output.png]
# ============================================================================

import sys
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np


def main():
    if len(sys.argv) < 4:
        print("Uso: python ver_txt_imagen.py <input.txt> <width> <height> [output.png]")
        sys.exit(1)

    txt_path = Path(sys.argv[1])
    try:
        width = int(sys.argv[2])
        height = int(sys.argv[3])
    except ValueError:
        print("Error: width y height deben ser enteros.")
        sys.exit(1)

    out_path = Path(sys.argv[4]) if len(sys.argv) >= 5 else txt_path.with_suffix(".png")

    if not txt_path.exists():
        print(f"Error: archivo no encontrado: {txt_path}")
        sys.exit(1)

    # Leer todos los valores del txt (separados por espacios o saltos de línea)
    values = []
    with txt_path.open("r") as f:
        for line in f:
            parts = line.strip().split()
            for p in parts:
                if p:
                    try:
                        values.append(int(p))
                    except ValueError:
                        print(f"Valor no numérico encontrado: '{p}'")
                        sys.exit(1)

    expected = width * height
    if len(values) != expected:
        print(f"Error: se esperaban {expected} píxeles y hay {len(values)} en {txt_path}")
        sys.exit(1)

    img = np.array(values, dtype=np.uint8).reshape((height, width))

    # Guardar como imagen en escala de grises
    plt.imsave(out_path, img, cmap="gray", vmin=0, vmax=255)
    print(f"Imagen guardada en: {out_path}")


if __name__ == "__main__":
    main()


