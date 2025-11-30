#!/usr/bin/env python3
"""
Convierte imagen PNG/JPG a formato .txt (un píxel por línea)
"""

from PIL import Image
import sys
import os

def png_to_txt(input_png, output_txt):
    """Convierte PNG/JPG a formato columna .txt"""
    
    print(f"\nConvirtiendo {input_png} → {output_txt}")
    print("="*50)
    
    # Verificar archivo existe
    if not os.path.exists(input_png):
        print(f"✗ Error: Archivo {input_png} no encontrado")
        return False
    
    # Cargar imagen
    try:
        img = Image.open(input_png)
        print(f"✓ Imagen cargada: {input_png}")
    except Exception as e:
        print(f"✗ Error al cargar imagen: {e}")
        return False
    
    # Convertir a grayscale
    if img.mode != 'L':
        print(f"  Convirtiendo de {img.mode} a Grayscale...")
        img = img.convert('L')
    
    width, height = img.size
    print(f"  Dimensiones: {width} × {height}")
    print(f"  Total píxeles: {width * height}")
    
    # Convertir a array
    pixels = list(img.getdata())
    
    # Guardar como texto (un píxel por línea)
    with open(output_txt, 'w') as f:
        for pixel in pixels:
            f.write(f"{pixel}\n")
    
    filesize = os.path.getsize(output_txt)
    print(f"\n✓ Archivo guardado: {output_txt}")
    print(f"  Tamaño: {filesize:,} bytes")
    print(f"  Píxeles escritos: {len(pixels)}")
    
    # Estadísticas
    min_val = min(pixels)
    max_val = max(pixels)
    avg_val = sum(pixels) / len(pixels)
    
    print(f"\nEstadísticas:")
    print(f"  Mínimo: {min_val}")
    print(f"  Máximo: {max_val}")
    print(f"  Promedio: {avg_val:.2f}")
    
    print("\n" + "="*50)
    print(f"✓ Conversión exitosa")
    print(f"\nUsa en System Console:")
    print(f'  load_image_to_sdram "C:/Users/sebas/OneDrive/Escritorio/Arqui2-Proyecto1/{output_txt}" {width} {height}')
    
    return True

def txt_to_png(input_txt, output_png, width, height):
    """Convierte formato .txt a PNG para visualización"""
    
    print(f"\nConvirtiendo {input_txt} → {output_png}")
    print("="*50)
    
    # Leer píxeles
    pixels = []
    with open(input_txt, 'r') as f:
        for line in f:
            line = line.strip()
            if line:
                pixels.append(int(line))
    
    print(f"✓ Píxeles leídos: {len(pixels)}")
    
    # Verificar dimensiones
    expected = width * height
    if len(pixels) != expected:
        print(f"⚠ Advertencia: Esperados {expected} píxeles, leídos {len(pixels)}")
        # Ajustar
        if len(pixels) > expected:
            pixels = pixels[:expected]
        else:
            pixels.extend([0] * (expected - len(pixels)))
    
    # Crear imagen
    img_array = np.array(pixels, dtype=np.uint8).reshape((height, width))
    img = Image.fromarray(img_array, mode='L')
    img.save(output_png)
    
    print(f"✓ Imagen guardada: {output_png}")
    print(f"  Dimensiones: {width} × {height}")
    
    return True

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Uso:")
        print("  python png_to_txt.py <imagen.png>")
        print("  python png_to_txt.py <resultado.txt> <width> <height> --to-png")
        print("\nEjemplos:")
        print("  python png_to_txt.py imagen_128x128.png")
        print("  python png_to_txt.py output.txt 256 256 --to-png")
        sys.exit(1)
    
    input_file = sys.argv[1]
    
    # Modo txt → png
    if len(sys.argv) >= 5 and sys.argv[4] == "--to-png":
        width = int(sys.argv[2])
        height = int(sys.argv[3])
        output_png = input_file.replace('.txt', '.png')
        
        import numpy as np
        txt_to_png(input_file, output_png, width, height)
    
    # Modo png → txt
    else:
        output_txt = input_file.replace('.png', '.txt').replace('.jpg', '.txt')
        png_to_txt(input_file, output_txt)


