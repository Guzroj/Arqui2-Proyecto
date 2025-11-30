#!/usr/bin/env python3
"""
Genera una imagen de prueba 128x128 con patrón de gradiente
"""

from PIL import Image
import numpy as np

def create_gradient_128x128(output_png):
    """Crea imagen de gradiente 128x128"""
    
    print("Creando imagen de prueba 128×128...")
    
    # Crear array 128x128
    img_array = np.zeros((128, 128), dtype=np.uint8)
    
    # Patrón de gradiente
    for i in range(128):
        for j in range(128):
            # Gradiente horizontal + vertical
            value = int((i + j) * 255 / 256)
            img_array[i, j] = value
    
    # Guardar como PNG
    img = Image.fromarray(img_array, mode='L')
    img.save(output_png)
    
    print(f"✓ Imagen guardada: {output_png}")
    print(f"  Dimensiones: 128 × 128")
    print(f"  Formato: Grayscale (8-bit)")
    
    return img_array

def create_test_pattern_128x128(output_png):
    """Crea imagen con patrón de prueba (círculos concéntricos)"""
    
    print("Creando imagen de prueba 128×128 (círculos)...")
    
    img_array = np.zeros((128, 128), dtype=np.uint8)
    
    center_y, center_x = 64, 64
    
    for i in range(128):
        for j in range(128):
            # Distancia al centro
            dist = np.sqrt((i - center_y)**2 + (j - center_x)**2)
            # Patrón circular
            value = int((np.sin(dist / 10) + 1) * 127)
            img_array[i, j] = value
    
    img = Image.fromarray(img_array, mode='L')
    img.save(output_png)
    
    print(f"✓ Imagen guardada: {output_png}")
    
    return img_array

if __name__ == "__main__":
    # Crear imagen de gradiente
    create_gradient_128x128("imagen_128x128_gradient.png")
    
    # Crear imagen de círculos
    create_test_pattern_128x128("imagen_128x128_circles.png")
    
    print("\n✓ Imágenes de prueba creadas")
    print("Ahora usa: python png_to_txt.py imagen_128x128_gradient.png")


