#!/usr/bin/env python3
"""
Visualizador de imagen de salida del downscaler
Lee imagen_output.txt y la muestra/guarda
"""

import numpy as np
import matplotlib.pyplot as plt
from PIL import Image

def load_output_image(filename):
    """
    Carga imagen desde archivo de texto
    Formato: primera línea = dimensiones (H W)
             resto = píxeles separados por espacios
    """
    print(f"Cargando {filename}...")
    
    with open(filename, 'r') as f:
        # Leer dimensiones
        first_line = f.readline().strip().split()
        height = int(first_line[0])
        width = int(first_line[1])
        
        print(f"  Dimensiones: {height}x{width}")
        
        # Leer píxeles
        image = np.zeros((height, width), dtype=np.uint8)
        
        for i in range(height):
            line = f.readline().strip().split()
            if len(line) != width:
                print(f"  ⚠ Advertencia: Fila {i} tiene {len(line)} valores (esperado {width})")
            
            for j in range(min(len(line), width)):
                image[i, j] = int(line[j])
    
    print(f"  ✓ Imagen cargada: min={np.min(image)}, max={np.max(image)}, mean={np.mean(image):.1f}")
    return image


def display_image(image, title="Imagen Downscaled", show_grid=True):
    """Muestra la imagen usando matplotlib con grid opcional"""
    plt.figure(figsize=(12, 10))
    plt.imshow(image, cmap='gray', vmin=0, vmax=255)
    plt.title(title, fontsize=14, fontweight='bold')
    plt.colorbar(label='Intensidad (0-255)', fraction=0.046)

    if show_grid:
        # Activar el eje para mostrar grid
        plt.axis('on')

        # Configurar grid principal cada 64 píxeles
        height, width = image.shape
        major_ticks_x = np.arange(0, width, 64)
        major_ticks_y = np.arange(0, height, 64)

        # Grid secundario cada 32 píxeles
        minor_ticks_x = np.arange(0, width, 32)
        minor_ticks_y = np.arange(0, height, 32)

        ax = plt.gca()
        ax.set_xticks(major_ticks_x)
        ax.set_yticks(major_ticks_y)
        ax.set_xticks(minor_ticks_x, minor=True)
        ax.set_yticks(minor_ticks_y, minor=True)

        # Estilo del grid
        ax.grid(which='major', color='red', linestyle='-', linewidth=1.0, alpha=0.6)
        ax.grid(which='minor', color='yellow', linestyle=':', linewidth=0.5, alpha=0.4)

        # Labels de ejes
        ax.set_xlabel('Columna (píxeles)', fontsize=11)
        ax.set_ylabel('Fila (píxeles)', fontsize=11)

        # Añadir dimensiones como texto
        textstr = f'Dimensiones: {height} × {width}\nGrid mayor: 64px\nGrid menor: 32px'
        props = dict(boxstyle='round', facecolor='wheat', alpha=0.8)
        ax.text(0.02, 0.98, textstr, transform=ax.transAxes, fontsize=10,
                verticalalignment='top', bbox=props)
    else:
        plt.axis('off')

    plt.tight_layout()
    plt.show()


def save_image_png(image, output_filename):
    """Guarda la imagen como PNG"""
    img = Image.fromarray(image, mode='L')
    img.save(output_filename)
    print(f"✓ Imagen guardada en {output_filename}")


def compare_with_input(input_file, output_image):
    """Compara entrada vs salida (opcional)"""
    try:
        print("\nComparando con imagen de entrada...")
        
        # Leer imagen de entrada
        input_data = np.loadtxt(input_file, dtype=np.uint8)
        
        if len(input_data.shape) == 1:
            # Asumir 512x512
            input_image = input_data.reshape(512, 512)
        else:
            input_image = input_data
        
        print(f"  Entrada: {input_image.shape}")
        print(f"  Salida:  {output_image.shape}")
        
        # Mostrar lado a lado
        fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(15, 7))
        
        ax1.imshow(input_image, cmap='gray', vmin=0, vmax=255)
        ax1.set_title(f'Entrada {input_image.shape[0]}x{input_image.shape[1]}')
        ax1.axis('off')
        
        ax2.imshow(output_image, cmap='gray', vmin=0, vmax=255)
        ax2.set_title(f'Salida {output_image.shape[0]}x{output_image.shape[1]}')
        ax2.axis('off')
        
        plt.tight_layout()
        plt.show()
        
    except Exception as e:
        print(f"  No se pudo comparar: {e}")


def analyze_image(image):
    """Análisis estadístico de la imagen"""
    print("\n=== ANÁLISIS DE IMAGEN ===")
    print(f"Dimensiones: {image.shape[0]}x{image.shape[1]}")
    print(f"Total píxeles: {image.size}")
    print(f"Rango: [{np.min(image)}, {np.max(image)}]")
    print(f"Media: {np.mean(image):.2f}")
    print(f"Desv. estándar: {np.std(image):.2f}")
    
    # Histograma
    print("\nDistribución de valores:")
    hist, bins = np.histogram(image, bins=16, range=(0, 256))
    for i in range(len(hist)):
        bar = '█' * int(hist[i] / np.max(hist) * 40)
        print(f"  {bins[i]:3.0f}-{bins[i+1]:3.0f}: {bar} ({hist[i]})")

def display_image(image, title="Imagen Downscaled", show_axes=True):
    """Muestra la imagen con ejes visibles (ticks) sin grid."""
    
    height, width = image.shape

    plt.figure(figsize=(12, 10))
    plt.imshow(image, cmap='gray', vmin=0, vmax=255, interpolation='nearest')
    plt.title(title, fontsize=14, fontweight='bold')
    plt.colorbar(label='Intensidad (0-255)', fraction=0.046)

    ax = plt.gca()

    if show_axes:
        # Mostrar ejes normalmente
        plt.axis('on')

        # Ticks cada 32 o 64 píxeles (ajusta si quieres)
        step_x = max(1, width // 8)
        step_y = max(1, height // 8)

        ax.set_xticks(np.arange(0, width + 1, step_x))
        ax.set_yticks(np.arange(0, height + 1, step_y))

        # Etiquetas
        ax.set_xlabel("Columna (píxeles)")
        ax.set_ylabel("Fila (píxeles)")

        # No mostrar ninguna línea de grid
        ax.grid(False)

    else:
        plt.axis('off')

    plt.tight_layout()
    plt.show()

def main():
    print("="*60)
    print("VISUALIZADOR DE IMAGEN DOWNSCALED")
    print("="*60)
    print()
    
    # Rutas de archivos
    output_file = "C:/Users/gabri/OneDrive/Desktop/PrograProyectoArqui/Arqui2-Proyecto/imagen_output.txt"
    input_file = "C:/Users/gabri/OneDrive/Desktop/PrograProyectoArqui/Arqui2-Proyecto/imagen_grayscale.txt"
    png_file = "C:/Users/gabri/OneDrive/Desktop/PrograProyectoArqui/Arqui2-Proyecto/imagen_output.png"
    
    # Cargar imagen de salida
    try:
        output_image = load_output_image(output_file)
    except FileNotFoundError:
        print(f"✗ ERROR: No se encontró {output_file}")
        print("  Asegúrate de ejecutar el testbench primero.")
        return
    except Exception as e:
        print(f"✗ ERROR al cargar: {e}")
        return
    
    # Análisis
    analyze_image(output_image)
    
    # Guardar como PNG
    save_image_png(output_image, png_file)
    
    # Mostrar
    print("\nMostrando imagen...")
    display_image(output_image, f"Downscaled {output_image.shape[0]}x{output_image.shape[1]}")
    
    # Comparar con entrada (opcional)
    try:
        compare_with_input(input_file, output_image)
    except:
        pass
    
    print("\n" + "="*60)
    print("PROCESO COMPLETADO")
    print("="*60)


if __name__ == "__main__":
    main()