#!/usr/bin/env python3
"""
Convierte imagen en formato matriz (píxeles separados por espacios)
a formato columna (un píxel por línea) para el DSA.
"""

import sys

def convert_matrix_to_column(input_file, output_file):
    """Convierte formato matriz a columna"""
    
    print(f"Convirtiendo {input_file} -> {output_file}")
    
    pixels = []
    line_count = 0
    
    # Leer archivo
    with open(input_file, 'r') as f:
        for line in f:
            line = line.strip()
            if line:
                # Dividir por espacios y agregar a la lista
                values = line.split()
                for val in values:
                    try:
                        pixel = int(val)
                        if 0 <= pixel <= 255:
                            pixels.append(pixel)
                        else:
                            print(f"⚠ Advertencia: Píxel fuera de rango: {pixel}")
                            pixels.append(max(0, min(255, pixel)))
                    except ValueError:
                        print(f"⚠ Advertencia: Valor inválido: {val}")
                line_count += 1
    
    print(f"Líneas leídas: {line_count}")
    print(f"Píxeles extraídos: {len(pixels)}")
    
    # Calcular dimensiones
    width = len(pixels) // line_count
    height = line_count
    
    print(f"Dimensiones detectadas: {width} × {height}")
    
    # Guardar en formato columna
    with open(output_file, 'w') as f:
        for pixel in pixels:
            f.write(f"{pixel}\n")
    
    print(f"✓ Archivo guardado: {output_file}")
    print(f"✓ Total píxeles: {len(pixels)}")
    
    return width, height

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Uso: python convert_image_format.py <input.txt> <output.txt>")
        print("Ejemplo: python convert_image_format.py imagen_grayscale.txt imagen_columna.txt")
        sys.exit(1)
    
    input_file = sys.argv[1]
    output_file = sys.argv[2]
    
    try:
        width, height = convert_matrix_to_column(input_file, output_file)
        print(f"\n✓ Conversión exitosa")
        print(f"Usa el archivo: {output_file}")
        print(f"Dimensiones: {width} × {height}")
    except FileNotFoundError:
        print(f"✗ Error: Archivo {input_file} no encontrado")
    except Exception as e:
        print(f"✗ Error: {e}")


