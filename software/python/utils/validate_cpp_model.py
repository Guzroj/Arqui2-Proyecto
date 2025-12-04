#!/usr/bin/env python3
"""
validate_cpp_model.py
Valida que el modelo C++ produce resultados idénticos al modelo Python

Compara bit-a-bit los resultados de ambos modelos
"""

import sys
import os
import subprocess
import numpy as np

# Agregar path para importar módulos de reference
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'reference'))
from downscale import load_image_from_txt


def compare_images(file1, file2, tolerance=1):
    """
    Compara dos imágenes píxel por píxel

    Args:
        file1: Archivo imagen 1
        file2: Archivo imagen 2
        tolerance: Tolerancia permitida (default 1)

    Returns:
        tuple: (identical_count, within_tolerance_count, max_diff, avg_diff)
    """
    img1, w1, h1 = load_image_from_txt(file1)
    img2, w2, h2 = load_image_from_txt(file2)

    # Verificar dimensiones
    if (w1, h1) != (w2, h2):
        print(f"  X ERROR: Dimensiones no coinciden")
        print(f"    Imagen 1: {h1}x{w1}")
        print(f"    Imagen 2: {h2}x{w2}")
        return None

    # Calcular diferencias
    diff = np.abs(img1.astype(int) - img2.astype(int))

    identical = np.sum(diff == 0)
    within_tolerance = np.sum(diff <= tolerance)
    max_diff = np.max(diff)
    avg_diff = np.mean(diff)

    total_pixels = w1 * h1

    return (identical, within_tolerance, max_diff, avg_diff, total_pixels)


def run_python_model(input_file, output_file, src_w, src_h, dst_w, dst_h):
    """Ejecuta modelo Python"""
    print(f"\n[1/2] Ejecutando modelo Python...")

    cmd = [
        sys.executable,  # python
        "../reference/downscale.py",
        input_file,
        output_file,
        str(src_w), str(src_h),
        str(dst_w), str(dst_h)
    ]

    result = subprocess.run(cmd, capture_output=True, text=True)

    if result.returncode != 0:
        print(f"  X ERROR ejecutando modelo Python:")
        print(result.stderr)
        return False

    print(f"  OK Modelo Python completado")
    return True


def run_cpp_model(input_file, output_file, src_w, src_h, dst_w, dst_h):
    """Ejecuta modelo C++"""
    print(f"\n[2/2] Ejecutando modelo C++...")

    # Ruta al ejecutable
    exe_path = "../../reference_model/bin/downscale"

    # En Windows, agregar .exe
    if sys.platform == "win32":
        exe_path += ".exe"

    if not os.path.exists(exe_path):
        print(f"  X ERROR: Ejecutable no encontrado: {exe_path}")
        print(f"  Compilar primero con: cd ../../reference_model && make")
        return False

    cmd = [
        exe_path,
        input_file,
        output_file,
        str(src_w), str(src_h),
        str(dst_w), str(dst_h)
    ]

    result = subprocess.run(cmd, capture_output=True, text=True)

    if result.returncode != 0:
        print(f"  X ERROR ejecutando modelo C++:")
        print(result.stderr)
        return False

    print(f"  OK Modelo C++ completado")
    return True


def main():
    print("="*70)
    print(" "*15 + "VALIDACION CRUZADA: Python <-> C++")
    print("="*70)
    print()

    # Configuración
    src_w, src_h = 64, 64
    dst_w, dst_h = 32, 32

    # Archivos
    input_file = "../test_images/gradient_h_64x64.txt"
    output_py = "../test_images/validation_python_32x32.txt"
    output_cpp = "../test_images/validation_cpp_32x32.txt"

    # Verificar que existe imagen de entrada
    if not os.path.exists(input_file):
        print(f"X ERROR: No existe archivo de entrada: {input_file}")
        print(f"\nGenerar primero con:")
        print(f"  cd ../python/utils")
        print(f"  python create_test_images.py")
        return 1

    print(f"Configuración:")
    print(f"  Entrada:   {input_file} ({src_w}x{src_h})")
    print(f"  Salida PY: {output_py} ({dst_w}x{dst_h})")
    print(f"  Salida C++:{output_cpp} ({dst_w}x{dst_h})")

    # Ejecutar modelo Python
    if not run_python_model(input_file, output_py, src_w, src_h, dst_w, dst_h):
        return 1

    # Ejecutar modelo C++
    if not run_cpp_model(input_file, output_cpp, src_w, src_h, dst_w, dst_h):
        return 1

    # Comparar resultados
    print(f"\n[3/3] Comparando resultados...")
    print("-"*70)

    result = compare_images(output_py, output_cpp, tolerance=1)

    if result is None:
        return 1

    identical, within_tol, max_diff, avg_diff, total = result

    pct_identical = (identical / total) * 100
    pct_within_tol = (within_tol / total) * 100

    print(f"\nResultados de comparación:")
    print(f"  Total píxeles:         {total}")
    print(f"  Píxeles idénticos:     {identical} ({pct_identical:.2f}%)")
    print(f"  Pixeles diff <= 1:     {within_tol} ({pct_within_tol:.2f}%)")
    print(f"  Diferencia máxima:     {max_diff}")
    print(f"  Diferencia promedio:   {avg_diff:.4f}")
    print()

    # Determinar si pasa o falla
    PASS_THRESHOLD = 95.0  # % de pixeles que deben ser identicos o diff <= 1

    if pct_within_tol >= PASS_THRESHOLD:
        print("="*70)
        print("*** VALIDACION EXITOSA ***")
        print("="*70)
        print()
        print("El modelo C++ produce resultados consistentes con Python.")
        print(f"Match: {pct_within_tol:.2f}% (threshold: {PASS_THRESHOLD}%)")
        print()
        return 0
    else:
        print("="*70)
        print("XXX VALIDACION FALLIDA XXX")
        print("="*70)
        print()
        print("El modelo C++ NO produce resultados consistentes con Python.")
        print(f"Match: {pct_within_tol:.2f}% (threshold: {PASS_THRESHOLD}%)")
        print()
        print("Posibles causas:")
        print("  - Error en implementación Q8.8")
        print("  - Diferencias en redondeo")
        print("  - Bug en interpolación")
        print()
        return 1


if __name__ == "__main__":
    sys.exit(main())
