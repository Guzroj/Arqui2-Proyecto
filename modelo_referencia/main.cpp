// ============================================================================
// main.cpp
// ============================================================================
// Programa principal para modelo de referencia DSA
// Permite probar downscaling y comparar con resultados de hardware
// ============================================================================

#include "bilinear_downscale.h"
#include <iostream>
#include <iomanip>
#include <chrono>

void print_usage(const char* program_name) {
    std::cout << "\n=============================================" << std::endl;
    std::cout << "  Modelo de Referencia DSA Downscaler" << std::endl;
    std::cout << "  CE4302 - Arquitectura de Computadores II" << std::endl;
    std::cout << "=============================================" << std::endl;
    std::cout << "\nUso:" << std::endl;
    std::cout << "  " << program_name << " <modo> <input.txt> <w_in> <h_in> <w_out> <h_out> <output.txt>" << std::endl;
    std::cout << "\nModos:" << std::endl;
    std::cout << "  seq   - Modo secuencial (1 píxel/iteración)" << std::endl;
    std::cout << "  simd  - Modo SIMD (N=4 píxeles/iteración)" << std::endl;
    std::cout << "  both  - Ambos modos + comparación" << std::endl;
    std::cout << "\nEjemplos:" << std::endl;
    std::cout << "  " << program_name << " seq  input.txt 512 512 256 256 output.txt" << std::endl;
    std::cout << "  " << program_name << " simd input.txt 128 128 64 64 output.txt" << std::endl;
    std::cout << "  " << program_name << " both input.txt 256 256 128 128 output.txt" << std::endl;
    std::cout << "=============================================" << std::endl;
}

int main(int argc, char* argv[]) {
    // Validar argumentos
    if (argc != 8) {
        print_usage(argv[0]);
        return 1;
    }
    
    std::string mode = argv[1];
    std::string input_file = argv[2];
    uint32_t width_in = std::stoul(argv[3]);
    uint32_t height_in = std::stoul(argv[4]);
    uint32_t width_out = std::stoul(argv[5]);
    uint32_t height_out = std::stoul(argv[6]);
    std::string output_file = argv[7];
    
    // Validar modo
    if (mode != "seq" && mode != "simd" && mode != "both") {
        std::cerr << "ERROR: Modo inválido '" << mode << "'" << std::endl;
        std::cerr << "Modos válidos: seq, simd, both" << std::endl;
        return 1;
    }
    
    // Validar dimensiones
    if (width_out > width_in || height_out > height_in) {
        std::cerr << "ERROR: Dimensiones de salida mayores que entrada" << std::endl;
        return 1;
    }
    
    if (width_in == 0 || height_in == 0 || width_out == 0 || height_out == 0) {
        std::cerr << "ERROR: Dimensiones deben ser > 0" << std::endl;
        return 1;
    }
    
    // Mostrar configuración
    std::cout << "\n=============================================" << std::endl;
    std::cout << "  Configuración" << std::endl;
    std::cout << "=============================================" << std::endl;
    std::cout << "Modo:         " << mode << std::endl;
    std::cout << "Entrada:      " << width_in << " × " << height_in << " píxeles" << std::endl;
    std::cout << "Salida:       " << width_out << " × " << height_out << " píxeles" << std::endl;
    std::cout << "Archivo IN:   " << input_file << std::endl;
    std::cout << "Archivo OUT:  " << output_file << std::endl;
    
    // Calcular factor de escala
    float scale_x = (float)width_out / (float)width_in;
    float scale_y = (float)height_out / (float)height_in;
    std::cout << "Factor escala: " << std::fixed << std::setprecision(3) 
              << scale_x << " (width), " << scale_y << " (height)" << std::endl;
    std::cout << "=============================================" << std::endl;
    
    // Cargar imagen de entrada
    std::cout << "\nCargando imagen de entrada..." << std::endl;
    std::vector<uint8_t> input_image;
    uint32_t actual_w, actual_h;
    
    if (!load_image_txt(input_file, input_image, actual_w, actual_h)) {
        return 1;
    }
    
    // Verificar dimensiones
    if (actual_w != width_in || actual_h != height_in) {
        std::cerr << "ADVERTENCIA: Dimensiones del archivo (" << actual_w << "×" << actual_h 
                  << ") no coinciden con especificadas (" << width_in << "×" << height_in << ")" << std::endl;
        std::cerr << "Usando dimensiones del archivo..." << std::endl;
        width_in = actual_w;
        height_in = actual_h;
    }
    
    // Variables para resultados
    std::vector<uint8_t> output_seq, output_simd;
    DownscaleSequential::Stats stats_seq, stats_simd;
    
    // ========================================
    // MODO SECUENCIAL
    // ========================================
    if (mode == "seq" || mode == "both") {
        std::cout << "\n[Modo Secuencial]" << std::endl;
        std::cout << "Procesando..." << std::flush;
        
        auto start_time = std::chrono::high_resolution_clock::now();
        
        DownscaleSequential downscaler_seq;
        downscaler_seq.configure(width_in, height_in, width_out, height_out);
        downscaler_seq.process(input_image, output_seq);
        
        auto end_time = std::chrono::high_resolution_clock::now();
        auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(end_time - start_time);
        
        std::cout << " Completado en " << duration.count() << " ms" << std::endl;
        
        stats_seq = downscaler_seq.get_stats();
        print_stats(stats_seq, width_out, height_out, "Secuencial");
        
        // Guardar resultado
        if (mode == "seq") {
            save_image_txt(output_file, output_seq, width_out, height_out);
        } else {
            save_image_txt("output_seq.txt", output_seq, width_out, height_out);
        }
    }
    
    // ========================================
    // MODO SIMD
    // ========================================
    if (mode == "simd" || mode == "both") {
        std::cout << "\n[Modo SIMD (N=4)]" << std::endl;
        std::cout << "Procesando..." << std::flush;
        
        auto start_time = std::chrono::high_resolution_clock::now();
        
        DownscaleSIMD<4> downscaler_simd;
        downscaler_simd.configure(width_in, height_in, width_out, height_out);
        downscaler_simd.process(input_image, output_simd);
        
        auto end_time = std::chrono::high_resolution_clock::now();
        auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(end_time - start_time);
        
        std::cout << " Completado en " << duration.count() << " ms" << std::endl;
        
        stats_simd = downscaler_simd.get_stats();
        print_stats(stats_simd, width_out, height_out, "SIMD (N=4)");
        
        // Guardar resultado
        if (mode == "simd") {
            save_image_txt(output_file, output_simd, width_out, height_out);
        } else {
            save_image_txt("output_simd.txt", output_simd, width_out, height_out);
        }
    }
    
    // ========================================
    // COMPARACIÓN (modo "both")
    // ========================================
    if (mode == "both") {
        std::cout << "\n=============================================" << std::endl;
        std::cout << "  Comparación Secuencial vs SIMD" << std::endl;
        std::cout << "=============================================" << std::endl;
        
        uint32_t diff_count;
        bool identical = compare_images(output_seq, output_simd, diff_count);
        
        if (identical) {
            std::cout << "✓ IDÉNTICOS - Ambos modos producen el mismo resultado" << std::endl;
        } else {
            std::cout << "✗ DIFERENCIAS - " << diff_count << " píxeles diferentes" << std::endl;
        }
        
        // Speedup teórico
        if (stats_seq.cycles > 0) {
            float speedup = (float)stats_seq.cycles / (float)stats_simd.cycles;
            std::cout << "\nSpeedup SIMD: " << std::fixed << std::setprecision(2) 
                      << speedup << "×" << std::endl;
        }
        
        // Guardar resultado final (SIMD si son idénticos, secuencial si no)
        if (identical) {
            save_image_txt(output_file, output_simd, width_out, height_out);
        } else {
            save_image_txt(output_file, output_seq, width_out, height_out);
        }
        
        std::cout << "=============================================" << std::endl;
    }
    
    std::cout << "\n¡Proceso completado exitosamente!\n" << std::endl;
    return 0;
}

