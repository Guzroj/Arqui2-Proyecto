#!/usr/bin/env python3
"""
TEST_FASE1.py
Script de prueba completo para validar la FASE 1

Ejecuta todos los tests de los módulos Python:
- fixed_point.py
- bilinear_interpolation.py
- downscale.py
- create_test_images.py
"""

import sys
import os

# Agregar paths necesarios
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'reference'))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'utils'))

print("="*70)
print(" "*20 + "TEST COMPLETO - FASE 1")
print(" "*15 + "Modelo de Referencia Python Q8.8")
print("="*70)
print()

# Test 1: Aritmética Q8.8
print("[1/4] Ejecutando tests de aritmética Q8.8...")
print("-"*70)
try:
    from fixed_point import Q8_8, pixel_to_fixed, fixed_to_pixel
    import reference.fixed_point as fp_module

    # Ejecutar los tests incluidos en el módulo
    exec(open('reference/fixed_point.py').read())

    print()
    print("✓ Tests de Q8.8 PASADOS")
except Exception as e:
    print(f"\n✗ ERROR en tests de Q8.8: {e}")
    sys.exit(1)

print()
input("Presiona Enter para continuar con interpolación bilineal...")
print()

# Test 2: Interpolación bilineal
print("[2/4] Ejecutando tests de interpolación bilineal...")
print("-"*70)
try:
    exec(open('reference/bilinear_interpolation.py').read())

    print()
    print("✓ Tests de interpolación PASADOS")
except Exception as e:
    print(f"\n✗ ERROR en tests de interpolación: {e}")
    sys.exit(1)

print()
input("Presiona Enter para continuar con downscaling...")
print()

# Test 3: Downscaling completo
print("[3/4] Ejecutando test de downscaling...")
print("-"*70)
try:
    from downscale import downscale_image, save_image_to_txt
    import numpy as np

    # Crear imagen de prueba simple
    src_w, src_h = 64, 64
    dst_w, dst_h = 32, 32

    print(f"Generando imagen de prueba {src_w}x{src_h}...")
    src_image = np.zeros((src_h, src_w), dtype=np.uint8)
    for y in range(src_h):
        for x in range(src_w):
            src_image[y, x] = int((x / (src_w - 1)) * 255)

    print(f"\nProcesando downscaling {src_w}x{src_h} → {dst_w}x{dst_h}...")
    dst_image = downscale_image(src_image, src_w, src_h, dst_w, dst_h)

    # Guardar resultado
    os.makedirs('test_images', exist_ok=True)
    save_image_to_txt('test_images/test_downscale_result.txt', dst_image)

    print()
    print("✓ Test de downscaling PASADO")
    print(f"  Resultado guardado en: test_images/test_downscale_result.txt")

except Exception as e:
    print(f"\n✗ ERROR en test de downscaling: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)

print()
input("Presiona Enter para generar suite completa de imágenes de prueba...")
print()

# Test 4: Generar suite de imágenes de prueba
print("[4/4] Generando suite de imágenes de prueba...")
print("-"*70)
try:
    import create_test_images
    create_test_images.main()

    print()
    print("✓ Suite de imágenes de prueba GENERADA")

except Exception as e:
    print(f"\n✗ ERROR generando imágenes de prueba: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)

# Resumen final
print()
print("="*70)
print(" "*25 + "RESUMEN FINAL")
print("="*70)
print()
print("✓ [1/4] Aritmética Q8.8              - PASADO")
print("✓ [2/4] Interpolación bilineal       - PASADO")
print("✓ [3/4] Downscaling completo         - PASADO")
print("✓ [4/4] Suite de imágenes de prueba  - PASADO")
print()
print("="*70)
print("✓✓✓ FASE 1 COMPLETADA EXITOSAMENTE ✓✓✓")
print("="*70)
print()
print("Archivos generados:")
print("  - software/python/reference/fixed_point.py")
print("  - software/python/reference/bilinear_interpolation.py")
print("  - software/python/reference/downscale.py")
print("  - software/python/utils/create_test_images.py")
print("  - software/python/test_images/*.txt (20 archivos)")
print()
print("Próximo paso:")
print("  → FASE 2: Implementar modelo de referencia en C++")
print()
print("="*70)
