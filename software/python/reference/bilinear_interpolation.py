#!/usr/bin/env python3
"""
bilinear_interpolation.py
Interpolación bilineal usando aritmética de punto fijo Q8.8

La interpolación bilineal calcula un píxel de salida basándose en los
4 píxeles vecinos más cercanos de la imagen de entrada.

Fórmula:
    result = p00*(1-fx)*(1-fy) + p01*fx*(1-fy) + p10*(1-fx)*fy + p11*fx*fy

Donde:
    p00, p01, p10, p11 = 4 píxeles vecinos (uint8)
    fx, fy = pesos fraccionarios (0.0 - 1.0)
"""

import numpy as np
from fixed_point import Q8_8, pixel_to_fixed, fixed_to_pixel, fixed_multiply


def bilinear_interpolate_pixel(p00, p01, p10, p11, fx, fy):
    """
    Interpola un píxel usando interpolación bilineal con aritmética Q8.8

    Args:
        p00: Píxel superior izquierdo (uint8, 0-255)
        p01: Píxel superior derecho (uint8, 0-255)
        p10: Píxel inferior izquierdo (uint8, 0-255)
        p11: Píxel inferior derecho (uint8, 0-255)
        fx: Peso horizontal (float, 0.0-1.0)
        fy: Peso vertical (float, 0.0-1.0)

    Returns:
        uint8: Píxel interpolado (0-255)
    """
    # Convertir píxeles a Q8.8 (shift left 8)
    p00_fixed = pixel_to_fixed(p00)
    p01_fixed = pixel_to_fixed(p01)
    p10_fixed = pixel_to_fixed(p10)
    p11_fixed = pixel_to_fixed(p11)

    # Convertir pesos a Q8.8
    fx_fixed = Q8_8.float_to_fixed(fx)
    fy_fixed = Q8_8.float_to_fixed(fy)

    # Calcular (1 - fx) y (1 - fy)
    one_fixed = Q8_8.float_to_fixed(1.0)  # 1.0 en Q8.8 = 256
    one_minus_fx = one_fixed - fx_fixed
    one_minus_fy = one_fixed - fy_fixed

    # Calcular los 4 pesos
    w00 = fixed_multiply(one_minus_fx, one_minus_fy)  # (1-fx) * (1-fy)
    w01 = fixed_multiply(fx_fixed, one_minus_fy)      # fx * (1-fy)
    w10 = fixed_multiply(one_minus_fx, fy_fixed)      # (1-fx) * fy
    w11 = fixed_multiply(fx_fixed, fy_fixed)          # fx * fy

    # Multiplicar píxeles por sus pesos
    term00 = fixed_multiply(p00_fixed, w00)
    term01 = fixed_multiply(p01_fixed, w01)
    term10 = fixed_multiply(p10_fixed, w10)
    term11 = fixed_multiply(p11_fixed, w11)

    # Sumar todos los términos
    result_fixed = term00 + term01 + term10 + term11

    # Convertir de vuelta a uint8
    result_pixel = fixed_to_pixel(result_fixed)

    return result_pixel


def bilinear_interpolate_pixel_float(p00, p01, p10, p11, fx, fy):
    """
    Versión en punto flotante para comparación (NO usar en hardware)

    Esta función NO debe usarse en el diseño final, solo para validar
    que la versión Q8.8 da resultados similares.
    """
    result = (
        p00 * (1 - fx) * (1 - fy) +
        p01 * fx * (1 - fy) +
        p10 * (1 - fx) * fy +
        p11 * fx * fy
    )
    return int(result + 0.5)  # Redondear


# Tests unitarios
if __name__ == "__main__":
    print("="*60)
    print("TESTS: Interpolación Bilineal Q8.8")
    print("="*60)

    # Test 1: Casos esquina (sin interpolación real)
    print("\nTest 1: Casos esquina (pesos 0.0 o 1.0)")

    test_cases = [
        # (p00, p01, p10, p11, fx, fy, expected)
        (100, 200, 150, 250, 0.0, 0.0, 100),  # Esquina superior izquierda
        (100, 200, 150, 250, 1.0, 0.0, 200),  # Esquina superior derecha
        (100, 200, 150, 250, 0.0, 1.0, 150),  # Esquina inferior izquierda
        (100, 200, 150, 250, 1.0, 1.0, 250),  # Esquina inferior derecha
    ]

    for p00, p01, p10, p11, fx, fy, expected in test_cases:
        result_q88 = bilinear_interpolate_pixel(p00, p01, p10, p11, fx, fy)
        result_float = bilinear_interpolate_pixel_float(p00, p01, p10, p11, fx, fy)

        print(f"  p=({p00:3d},{p01:3d},{p10:3d},{p11:3d}), f=({fx:.1f},{fy:.1f})")
        print(f"    Q8.8:  {result_q88:3d}")
        print(f"    Float: {result_float:3d}")
        print(f"    Esperado: {expected:3d}")
        print(f"    Match: {'✓' if result_q88 == expected else '✗ ERROR'}")

    # Test 2: Interpolación al centro (fx=0.5, fy=0.5)
    print("\nTest 2: Interpolación al centro (0.5, 0.5)")

    test_cases = [
        # Promedio simple
        (0, 0, 0, 0, 0.5, 0.5, 0),           # Todo negro
        (255, 255, 255, 255, 0.5, 0.5, 255), # Todo blanco
        (0, 100, 100, 200, 0.5, 0.5, 100),   # Promedio de 4
    ]

    for p00, p01, p10, p11, fx, fy, expected in test_cases:
        result_q88 = bilinear_interpolate_pixel(p00, p01, p10, p11, fx, fy)
        result_float = bilinear_interpolate_pixel_float(p00, p01, p10, p11, fx, fy)
        avg = (p00 + p01 + p10 + p11) / 4

        print(f"  p=({p00:3d},{p01:3d},{p10:3d},{p11:3d})")
        print(f"    Q8.8:  {result_q88:3d}")
        print(f"    Float: {result_float:3d}")
        print(f"    Promedio: {avg:.1f}")
        print(f"    Diff Q8.8 vs Float: {abs(result_q88 - result_float)}")

    # Test 3: Gradiente horizontal (fx varía, fy=0)
    print("\nTest 3: Gradiente horizontal (fy=0, fx varía)")

    p00, p01, p10, p11 = 0, 255, 0, 255
    fy = 0.0

    print(f"  Píxeles: p00={p00}, p01={p01}, p10={p10}, p11={p11}")
    print(f"  fx   | Q8.8 | Float | Diff")
    print(f"  -----|------|-------|-----")

    for fx in [0.0, 0.25, 0.5, 0.75, 1.0]:
        result_q88 = bilinear_interpolate_pixel(p00, p01, p10, p11, fx, fy)
        result_float = bilinear_interpolate_pixel_float(p00, p01, p10, p11, fx, fy)
        diff = abs(result_q88 - result_float)

        print(f"  {fx:4.2f} | {result_q88:4d} | {result_float:5d} | {diff:4d}")

    # Test 4: Gradiente vertical (fy varía, fx=0)
    print("\nTest 4: Gradiente vertical (fx=0, fy varía)")

    p00, p01, p10, p11 = 0, 0, 255, 255
    fx = 0.0

    print(f"  Píxeles: p00={p00}, p01={p01}, p10={p10}, p11={p11}")
    print(f"  fy   | Q8.8 | Float | Diff")
    print(f"  -----|------|-------|-----")

    for fy in [0.0, 0.25, 0.5, 0.75, 1.0]:
        result_q88 = bilinear_interpolate_pixel(p00, p01, p10, p11, fx, fy)
        result_float = bilinear_interpolate_pixel_float(p00, p01, p10, p11, fx, fy)
        diff = abs(result_q88 - result_float)

        print(f"  {fy:4.2f} | {result_q88:4d} | {result_float:5d} | {diff:4d}")

    # Test 5: Comparación sistemática Q8.8 vs Float
    print("\nTest 5: Comparación sistemática (100 casos aleatorios)")

    import random
    random.seed(42)  # Seed fijo para reproducibilidad

    max_diff = 0
    total_diff = 0
    num_tests = 100

    for _ in range(num_tests):
        p00 = random.randint(0, 255)
        p01 = random.randint(0, 255)
        p10 = random.randint(0, 255)
        p11 = random.randint(0, 255)
        fx = random.random()
        fy = random.random()

        result_q88 = bilinear_interpolate_pixel(p00, p01, p10, p11, fx, fy)
        result_float = bilinear_interpolate_pixel_float(p00, p01, p10, p11, fx, fy)

        diff = abs(result_q88 - result_float)
        max_diff = max(max_diff, diff)
        total_diff += diff

    avg_diff = total_diff / num_tests

    print(f"  Tests realizados: {num_tests}")
    print(f"  Diferencia máxima: {max_diff}")
    print(f"  Diferencia promedio: {avg_diff:.3f}")
    print(f"  Status: {'✓ PASS' if max_diff <= 1 else '✗ FAIL (diff > 1)'}")

    print("\n" + "="*60)
    print("✓ Todos los tests de interpolación completados")
    print("="*60)
