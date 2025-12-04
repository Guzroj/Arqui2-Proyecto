/**
 * image.cpp
 * Implementación de la clase Image y downscaling
 */

#include "image.h"
#include "bilinear.h"
#include "fixed_point.h"
#include <fstream>
#include <iostream>
#include <sstream>
#include <cmath>
#include <algorithm>

// Constructor
Image::Image(int w, int h) : width(w), height(h) {
    data.resize(height);
    for (int y = 0; y < height; y++) {
        data[y].resize(width, 0);
    }
}

// Cargar desde archivo de texto
bool Image::load_from_txt(const std::string& filename) {
    std::ifstream file(filename);
    if (!file.is_open()) {
        std::cerr << "Error: No se pudo abrir " << filename << std::endl;
        return false;
    }

    std::cout << "Cargando imagen desde " << filename << "..." << std::endl;

    // Leer primera línea (dimensiones)
    std::string line;
    if (!std::getline(file, line)) {
        std::cerr << "Error: Archivo vacío" << std::endl;
        return false;
    }

    std::istringstream iss(line);
    if (!(iss >> width >> height)) {
        std::cerr << "Error: No se pudo parsear dimensiones" << std::endl;
        return false;
    }

    std::cout << "  Dimensiones: " << width << "x" << height << std::endl;

    // Redimensionar data
    data.resize(height);
    for (int y = 0; y < height; y++) {
        data[y].resize(width);
    }

    // Leer píxeles
    int pixels_read = 0;
    int value;

    while (file >> value) {
        int y = pixels_read / width;
        int x = pixels_read % width;

        if (y >= height) break;  // Ya leímos suficientes píxeles

        data[y][x] = static_cast<uint8_t>(value);
        pixels_read++;
    }

    file.close();

    if (pixels_read != width * height) {
        std::cerr << "  Advertencia: Se esperaban " << (width * height)
                  << " píxeles, se leyeron " << pixels_read << std::endl;
    }

    std::cout << "  ✓ Imagen cargada: " << pixels_read << " píxeles" << std::endl;

    return true;
}

// Guardar a archivo de texto
bool Image::save_to_txt(const std::string& filename) const {
    std::ofstream file(filename);
    if (!file.is_open()) {
        std::cerr << "Error: No se pudo crear " << filename << std::endl;
        return false;
    }

    std::cout << "Guardando imagen a " << filename << "..." << std::endl;
    std::cout << "  Dimensiones: " << width << "x" << height << std::endl;

    // Escribir dimensiones
    file << width << " " << height << "\n";

    // Escribir píxeles (16 por línea para legibilidad)
    const int pixels_per_line = 16;

    for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
            file << static_cast<int>(data[y][x]) << " ";

            if ((x + 1) % pixels_per_line == 0 && x < width - 1) {
                file << "\n";
            }
        }
        file << "\n";
    }

    file.close();

    std::cout << "  ✓ Imagen guardada: " << (width * height) << " píxeles" << std::endl;

    return true;
}

// Acceso a píxeles
uint8_t Image::get_pixel(int x, int y) const {
    if (x < 0 || x >= width || y < 0 || y >= height) {
        return 0;  // Retornar negro si fuera de límites
    }
    return data[y][x];
}

void Image::set_pixel(int x, int y, uint8_t value) {
    if (x >= 0 && x < width && y >= 0 && y < height) {
        data[y][x] = value;
    }
}

// Estadísticas
void Image::print_stats() const {
    if (width == 0 || height == 0) {
        std::cout << "  Imagen vacía" << std::endl;
        return;
    }

    int min_val = 255;
    int max_val = 0;
    long long sum = 0;

    for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
            uint8_t val = data[y][x];
            min_val = std::min(min_val, (int)val);
            max_val = std::max(max_val, (int)val);
            sum += val;
        }
    }

    double mean = (double)sum / (width * height);

    std::cout << "  min=" << min_val
              << ", max=" << max_val
              << ", mean=" << mean << std::endl;
}

// Downscaling con interpolación bilineal
Image downscale_image(const Image& src, int dst_w, int dst_h) {
    std::cout << "\nDownscaling " << src.width << "x" << src.height
              << " → " << dst_w << "x" << dst_h << std::endl;

    // Crear imagen de salida
    Image dst(dst_w, dst_h);

    // Calcular ratios
    float x_ratio = (float)src.width / (float)dst_w;
    float y_ratio = (float)src.height / (float)dst_h;

    std::cout << "  Ratios: x=" << x_ratio << ", y=" << y_ratio << std::endl;

    // Para cada píxel de salida
    for (int y_dst = 0; y_dst < dst_h; y_dst++) {
        for (int x_dst = 0; x_dst < dst_w; x_dst++) {
            // Calcular posición en imagen origen
            float x_src_f = x_dst * x_ratio;
            float y_src_f = y_dst * y_ratio;

            // Extraer parte entera
            int x0 = (int)std::floor(x_src_f);
            int y0 = (int)std::floor(y_src_f);

            // Calcular esquina opuesta (con límites)
            int x1 = std::min(x0 + 1, src.width - 1);
            int y1 = std::min(y0 + 1, src.height - 1);

            // Calcular pesos fraccionarios
            float fx_float = x_src_f - x0;
            float fy_float = y_src_f - y0;

            // Convertir pesos a Q8.8
            fixed_t fx = float_to_fixed(fx_float);
            fixed_t fy = float_to_fixed(fy_float);

            // Obtener 4 píxeles vecinos
            uint8_t p00 = src.get_pixel(x0, y0);
            uint8_t p01 = src.get_pixel(x1, y0);
            uint8_t p10 = src.get_pixel(x0, y1);
            uint8_t p11 = src.get_pixel(x1, y1);

            // Interpolar usando Q8.8
            uint8_t pixel_out = bilinear_interpolate(p00, p01, p10, p11, fx, fy);

            // Guardar en imagen de salida
            dst.set_pixel(x_dst, y_dst, pixel_out);
        }

        // Progress indicator (cada 10%)
        if ((y_dst + 1) % std::max(1, dst_h / 10) == 0) {
            float progress = ((float)(y_dst + 1) / dst_h) * 100;
            std::cout << "  Progress: " << (int)progress << "%" << std::endl;
        }
    }

    std::cout << "  Completado: " << (dst_w * dst_h) << " píxeles procesados" << std::endl;

    return dst;
}
