/**
 * main.cpp
 * Programa principal para downscaling de imágenes
 *
 * Uso:
 *   ./downscale input.txt output.txt src_w src_h dst_w dst_h
 */

#include <iostream>
#include <cstdlib>
#include "image.h"

void print_usage(const char* program_name) {
    std::cout << "Uso: " << program_name << " input.txt output.txt src_w src_h dst_w dst_h" << std::endl;
    std::cout << std::endl;
    std::cout << "Ejemplo:" << std::endl;
    std::cout << "  " << program_name << " imagen_64x64.txt salida_32x32.txt 64 64 32 32" << std::endl;
    std::cout << std::endl;
}

int main(int argc, char* argv[]) {
    std::cout << "========================================" << std::endl;
    std::cout << "MODELO DE REFERENCIA C++ - Downscaling" << std::endl;
    std::cout << "Interpolación Bilineal Q8.8" << std::endl;
    std::cout << "========================================" << std::endl;
    std::cout << std::endl;

    // Verificar argumentos
    if (argc != 7) {
        std::cerr << "Error: Número incorrecto de argumentos" << std::endl;
        std::cout << std::endl;
        print_usage(argv[0]);
        return 1;
    }

    // Parsear argumentos
    const char* input_file = argv[1];
    const char* output_file = argv[2];
    int src_w = std::atoi(argv[3]);
    int src_h = std::atoi(argv[4]);
    int dst_w = std::atoi(argv[5]);
    int dst_h = std::atoi(argv[6]);

    // Validar parámetros
    if (src_w <= 0 || src_h <= 0 || dst_w <= 0 || dst_h <= 0) {
        std::cerr << "Error: Dimensiones inválidas" << std::endl;
        return 1;
    }

    if (dst_w > src_w || dst_h > src_h) {
        std::cerr << "Error: Dimensión de salida mayor que entrada (no es downscaling)" << std::endl;
        return 1;
    }

    std::cout << "Parámetros:" << std::endl;
    std::cout << "  Entrada:  " << input_file << " (" << src_w << "x" << src_h << ")" << std::endl;
    std::cout << "  Salida:   " << output_file << " (" << dst_w << "x" << dst_h << ")" << std::endl;
    std::cout << std::endl;

    // Cargar imagen de entrada
    Image src_image(src_w, src_h);
    if (!src_image.load_from_txt(input_file)) {
        std::cerr << "Error: No se pudo cargar imagen de entrada" << std::endl;
        return 1;
    }

    // Verificar dimensiones
    if (src_image.width != src_w || src_image.height != src_h) {
        std::cerr << "Error: Dimensiones de imagen no coinciden" << std::endl;
        std::cerr << "  Esperado: " << src_h << "x" << src_w << std::endl;
        std::cerr << "  Recibido: " << src_image.height << "x" << src_image.width << std::endl;
        return 1;
    }

    src_image.print_stats();
    std::cout << std::endl;

    // Procesar downscaling
    Image dst_image = downscale_image(src_image, dst_w, dst_h);

    std::cout << std::endl;
    dst_image.print_stats();
    std::cout << std::endl;

    // Guardar resultado
    if (!dst_image.save_to_txt(output_file)) {
        std::cerr << "Error: No se pudo guardar imagen de salida" << std::endl;
        return 1;
    }

    std::cout << std::endl;
    std::cout << "========================================" << std::endl;
    std::cout << "✓ Procesamiento completado exitosamente" << std::endl;
    std::cout << "========================================" << std::endl;

    return 0;
}
