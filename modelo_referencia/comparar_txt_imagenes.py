#!/usr/bin/env python3
# ============================================================================
# comparar_txt_imagenes.py
# ============================================================================
# Compara una imagen original y una imagen de salida (ambas en formato .txt)
# - Muestra dimensiones y factores de escala
# - Visualiza ambas imágenes lado a lado
#
# Formato de los .txt:
#   - Valores 0–255
#   - Separados por espacios y/o saltos de línea
#   - Una imagen de tamaño width × height
#
# Uso:
#   python comparar_txt_imagenes.py \
#       <input_orig.txt> <w_in> <h_in> \
#       <input_out.txt>  <w_out> <h_out>
#
# Ejemplo:
#   python comparar_txt_imagenes.py \
#       ../imagen_grayscale.txt 512 512 \
#       output.txt 256 256
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
    if len(sys.argv) != 7:
        print(
            "Uso: python comparar_txt_imagenes.py "
            "<input_orig.txt> <w_in> <h_in> <input_out.txt> <w_out> <h_out>"
        )
        sys.exit(1)

    orig_path = Path(sys.argv[1])
    out_path = Path(sys.argv[4])

    try:
        w_in = int(sys.argv[2])
        h_in = int(sys.argv[3])
        w_out = int(sys.argv[5])
        h_out = int(sys.argv[6])
    except ValueError:
        print("Error: w_in, h_in, w_out, h_out deben ser enteros.")
        sys.exit(1)

    # Cargar imágenes
    img_in = load_txt_image(orig_path, w_in, h_in)
    img_out = load_txt_image(out_path, w_out, h_out)

    # Imprimir info básica
    print("\n=============================================")
    print("  Comparación de Imágenes (TXT)")
    print("=============================================")
    print(f"Original : {orig_path}")
    print(f"  Tamaño : {w_in} × {h_in}")
    print(f"Salida   : {out_path}")
    print(f"  Tamaño : {w_out} × {h_out}")

    scale_x = w_out / w_in
    scale_y = h_out / h_in
    print("---------------------------------------------")
    print(f"Factor escala width : {scale_x:.3f}")
    print(f"Factor escala height: {scale_y:.3f}")
    print("=============================================\n")

    # Visualizar lado a lado
    fig, axes = plt.subplots(1, 2, figsize=(10, 5))

    axes[0].imshow(img_in, cmap="gray", vmin=0, vmax=255)
    axes[0].set_title(f"Original ({w_in}×{h_in})")
    axes[0].axis("off")

    axes[1].imshow(img_out, cmap="gray", vmin=0, vmax=255)
    axes[1].set_title(f"Salida ({w_out}×{h_out})")
    axes[1].axis("off")

    plt.tight_layout()
    plt.show()


if __name__ == "__main__":
    main()


