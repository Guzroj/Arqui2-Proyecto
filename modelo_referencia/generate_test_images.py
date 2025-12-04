#!/usr/bin/env python3
# ============================================================================
# generate_test_images.py
# ============================================================================
# Script para generar imágenes de prueba para validación
# Genera patrones conocidos para verificar el DSA
# ============================================================================

import numpy as np
import argparse

def generate_gradient(width, height, direction='horizontal'):
    """Genera una imagen con gradiente"""
    image = np.zeros((height, width), dtype=np.uint8)
    
    if direction == 'horizontal':
        for x in range(width):
            value = int(255 * x / (width - 1))
            image[:, x] = value
    elif direction == 'vertical':
        for y in range(height):
            value = int(255 * y / (height - 1))
            image[y, :] = value
    elif direction == 'diagonal':
        for y in range(height):
            for x in range(width):
                value = int(255 * (x + y) / (width + height - 2))
                image[y, x] = value
    
    return image

def generate_checkerboard(width, height, block_size=8):
    """Genera un patrón de tablero de ajedrez"""
    image = np.zeros((height, width), dtype=np.uint8)
    
    for y in range(height):
        for x in range(width):
            if ((x // block_size) + (y // block_size)) % 2 == 0:
                image[y, x] = 255
            else:
                image[y, x] = 0
    
    return image

def generate_circles(width, height):
    """Genera círculos concéntricos"""
    image = np.zeros((height, width), dtype=np.uint8)
    center_x = width // 2
    center_y = height // 2
    max_radius = min(center_x, center_y)
    
    for y in range(height):
        for x in range(width):
            dx = x - center_x
            dy = y - center_y
            radius = np.sqrt(dx*dx + dy*dy)
            value = int(255 * (1 - min(radius / max_radius, 1.0)))
            image[y, x] = value
    
    return image

def generate_uniform(width, height, value=128):
    """Genera imagen uniforme (útil para test básico)"""
    return np.full((height, width), value, dtype=np.uint8)

def save_image_txt(filename, image):
    """Guarda imagen en formato txt (espacios, una fila por línea)"""
    height, width = image.shape
    
    with open(filename, 'w') as f:
        for y in range(height):
            for x in range(width):
                f.write(str(image[y, x]))
                if x < width - 1:
                    f.write(' ')
            f.write('\n')
    
    print(f"✓ Guardado: {filename} ({width}×{height})")

def main():
    parser = argparse.ArgumentParser(description='Generar imágenes de prueba para DSA')
    parser.add_argument('--type', choices=['gradient', 'checkerboard', 'circles', 'uniform', 'all'],
                        default='all', help='Tipo de imagen')
    parser.add_argument('--width', type=int, default=128, help='Ancho de la imagen')
    parser.add_argument('--height', type=int, default=128, help='Alto de la imagen')
    parser.add_argument('--output-dir', default='.', help='Directorio de salida')
    
    args = parser.parse_args()
    
    print("\n=============================================")
    print("  Generador de Imágenes de Prueba")
    print("=============================================")
    print(f"Tamaño: {args.width} × {args.height}")
    print(f"Tipo: {args.type}")
    print("=============================================\n")
    
    if args.type == 'all' or args.type == 'gradient':
        # Gradiente horizontal
        img = generate_gradient(args.width, args.height, 'horizontal')
        save_image_txt(f'{args.output_dir}/test_{args.width}x{args.height}_gradient_h.txt', img)
        
        # Gradiente vertical
        img = generate_gradient(args.width, args.height, 'vertical')
        save_image_txt(f'{args.output_dir}/test_{args.width}x{args.height}_gradient_v.txt', img)
        
        # Gradiente diagonal
        img = generate_gradient(args.width, args.height, 'diagonal')
        save_image_txt(f'{args.output_dir}/test_{args.width}x{args.height}_gradient_d.txt', img)
    
    if args.type == 'all' or args.type == 'checkerboard':
        img = generate_checkerboard(args.width, args.height, block_size=8)
        save_image_txt(f'{args.output_dir}/test_{args.width}x{args.height}_checkerboard.txt', img)
    
    if args.type == 'all' or args.type == 'circles':
        img = generate_circles(args.width, args.height)
        save_image_txt(f'{args.output_dir}/test_{args.width}x{args.height}_circles.txt', img)
    
    if args.type == 'all' or args.type == 'uniform':
        img = generate_uniform(args.width, args.height, value=128)
        save_image_txt(f'{args.output_dir}/test_{args.width}x{args.height}_uniform.txt', img)
    
    print("\n✓ Generación completa\n")

if __name__ == '__main__':
    main()

