// ============================================================================
// bilinear_downscale.cpp
// ============================================================================
// Implementación del modelo de referencia
// Replica BIT A BIT el comportamiento del hardware DSA
// ============================================================================

#include "bilinear_downscale.h"
#include <fstream>
#include <iostream>
#include <sstream>
#include <algorithm>
#include <iomanip>

// ============================================================================
// BilinearInterpolator::process()
// ============================================================================
// Replica ModoSecuencial.sv líneas 22-99
// Usa formato Q0.16 para cálculos internos, igual que el hardware
// ============================================================================
void BilinearInterpolator::process(uint8_t I00, uint8_t I10, uint8_t I01, uint8_t I11,
                                    uint8_t alpha, uint8_t beta) {
    // Calcular complementos (1 - alpha) y (1 - beta)
    // Líneas 22-25 del ModoSecuencial.sv
    uint16_t one_minus_alpha = 256 - alpha;
    uint16_t one_minus_beta  = 256 - beta;
    
    // Calcular 4 términos (Q0.16)
    // Líneas 33-49 del ModoSecuencial.sv
    uint32_t term1 = (uint32_t)I00 * (uint32_t)(one_minus_alpha & 0xFF) * (uint32_t)(one_minus_beta & 0xFF);
    uint32_t term2 = (uint32_t)I10 * (uint32_t)alpha * (uint32_t)(one_minus_beta & 0xFF);
    uint32_t term3 = (uint32_t)I01 * (uint32_t)(one_minus_alpha & 0xFF) * (uint32_t)beta;
    uint32_t term4 = (uint32_t)I11 * (uint32_t)alpha * (uint32_t)beta;
    
    // Sumar términos (34 bits para evitar overflow)
    // Líneas 55-59
    uint64_t sum = (uint64_t)term1 + (uint64_t)term2 + (uint64_t)term3 + (uint64_t)term4;
    
    // Redondeo: sumar 0.5 en Q0.16 (0x8000)
    // Líneas 70-83
    uint64_t sum_rounded = sum + Q16_ROUND;
    
    // Shift >> 16 para convertir Q0.16 → uint8
    uint32_t result_shifted = (sum_rounded >> 16) & 0x3FFFF;  // 18 bits
    
    // Saturar a [0, 255]
    if (result_shifted > 255)
        pixel_out_ = 255;
    else
        pixel_out_ = (uint8_t)result_shifted;
    
    // Pipeline de 1 ciclo: valid_out se activa en el próximo ciclo
    // Líneas 89-99
    // En C++, simulamos esto activando inmediatamente (sin ciclos de reloj)
    valid_out_ = true;
}

// ============================================================================
// DownscaleSequential::DownscaleSequential()
// ============================================================================
DownscaleSequential::DownscaleSequential() 
    : width_in_(0), height_in_(0), width_out_(0), height_out_(0),
      x_ratio_fp_(0), y_ratio_fp_(0) {
    stats_ = {0, 0, 0, 0};
}

// ============================================================================
// DownscaleSequential::configure()
// ============================================================================
void DownscaleSequential::configure(uint32_t width_in, uint32_t height_in,
                                    uint32_t width_out, uint32_t height_out) {
    width_in_ = width_in;
    height_in_ = height_in;
    width_out_ = width_out;
    height_out_ = height_out;
    
    calculate_ratios();
}

// ============================================================================
// DownscaleSequential::calculate_ratios()
// ============================================================================
// Replica Downscale_Secuencial.sv líneas 128-129
// Calcula ratios en formato Q0.8 fixed point
// ============================================================================
void DownscaleSequential::calculate_ratios() {
    // x_ratio_fp = ((width_in - 1) << FRAC) / (width_out - 1)
    // y_ratio_fp = ((height_in - 1) << FRAC) / (height_out - 1)
    if (width_out_ > 1)
        x_ratio_fp_ = ((width_in_ - 1) << FRAC_BITS) / (width_out_ - 1);
    else
        x_ratio_fp_ = 0;
        
    if (height_out_ > 1)
        y_ratio_fp_ = ((height_in_ - 1) << FRAC_BITS) / (height_out_ - 1);
    else
        y_ratio_fp_ = 0;
}

// ============================================================================
// DownscaleSequential::get_neighbor_pixels()
// ============================================================================
// Replica Downscale_Secuencial.sv líneas 142-168
// Obtiene los 4 píxeles vecinos y calcula alpha/beta
// ============================================================================
void DownscaleSequential::get_neighbor_pixels(
    const std::vector<uint8_t>& input,
    uint32_t i_dst, uint32_t j_dst,
    uint8_t& I00, uint8_t& I10, uint8_t& I01, uint8_t& I11,
    uint8_t& alpha, uint8_t& beta) {
    
    // Calcular coordenadas fuente en punto fijo
    uint32_t x_src_fp = j_dst * x_ratio_fp_;
    uint32_t y_src_fp = i_dst * y_ratio_fp_;
    
    // Extraer parte entera (coordenadas píxel)
    uint32_t x_l = x_src_fp >> FRAC_BITS;
    uint32_t y_l = y_src_fp >> FRAC_BITS;
    
    // Calcular x_h, y_h con clamp (líneas 154-159)
    uint32_t x_h = (x_l < width_in_ - 1) ? (x_l + 1) : x_l;
    uint32_t y_h = (y_l < height_in_ - 1) ? (y_l + 1) : y_l;
    
    // Extraer parte fraccionaria (alpha y beta en Q0.8)
    // Líneas 162-163
    alpha = (uint8_t)(x_src_fp & 0xFF);
    beta  = (uint8_t)(y_src_fp & 0xFF);
    
    // Leer 4 píxeles vecinos de la imagen de entrada
    // Líneas 166-214 (requests a memoria)
    I00 = input[y_l * width_in_ + x_l];
    I10 = input[y_l * width_in_ + x_h];
    I01 = input[y_h * width_in_ + x_l];
    I11 = input[y_h * width_in_ + x_h];
    
    // Actualizar estadísticas (4 lecturas de memoria)
    stats_.memory_reads += 4;
}

// ============================================================================
// DownscaleSequential::process()
// ============================================================================
// Replica la FSM completa del Downscale_Secuencial.sv
// Procesa pixel por pixel, bit a bit idéntico al hardware
// ============================================================================
void DownscaleSequential::process(const std::vector<uint8_t>& input,
                                   std::vector<uint8_t>& output) {
    // Resetear estadísticas
    stats_ = {0, 0, 0, 0};
    
    // Validación de entrada
    if (input.size() != width_in_ * height_in_) {
        std::cerr << "ERROR: Tamaño de entrada inválido" << std::endl;
        return;
    }
    
    // Reservar espacio para salida
    uint32_t total_pixels = width_out_ * height_out_;
    output.resize(total_pixels);
    
    // Procesar cada píxel de salida (modo secuencial)
    // Replica la FSM: S_IDLE → S_CALC_COORDS → ... → S_WRITE_OUT
    for (uint32_t pixel_idx = 0; pixel_idx < total_pixels; pixel_idx++) {
        // S_CALC_COORDS (líneas 135-139)
        uint32_t i_dst = pixel_idx / width_out_;
        uint32_t j_dst = pixel_idx % width_out_;
        
        // S_CALC_SRC, S_REQ_I00-I11, S_WAIT_I00-I11 (líneas 142-222)
        uint8_t I00, I10, I01, I11, alpha, beta;
        get_neighbor_pixels(input, i_dst, j_dst, I00, I10, I01, I11, alpha, beta);
        
        // S_START_INTERP, S_WAIT_INTERP (líneas 225-234)
        interpolator_.process(I00, I10, I01, I11, alpha, beta);
        
        // S_WRITE_OUT (líneas 237-250)
        output[pixel_idx] = interpolator_.pixel_out();
        stats_.memory_writes++;
        
        // Aproximación de ciclos (4 lecturas + 1 interpolación + 1 escritura)
        stats_.cycles += 6;
    }
    
    // Aproximación de FLOPs (10 operaciones por píxel según hardware)
    stats_.flops = total_pixels * 10;
}

// ============================================================================
// DownscaleSIMD::DownscaleSIMD()
// ============================================================================
template<int N>
DownscaleSIMD<N>::DownscaleSIMD()
    : width_in_(0), height_in_(0), width_out_(0), height_out_(0),
      x_ratio_fp_(0), y_ratio_fp_(0) {
    stats_ = {0, 0, 0, 0};
}

// ============================================================================
// DownscaleSIMD::configure()
// ============================================================================
template<int N>
void DownscaleSIMD<N>::configure(uint32_t width_in, uint32_t height_in,
                                 uint32_t width_out, uint32_t height_out) {
    width_in_ = width_in;
    height_in_ = height_in;
    width_out_ = width_out;
    height_out_ = height_out;
    
    calculate_ratios();
}

// ============================================================================
// DownscaleSIMD::calculate_ratios()
// ============================================================================
template<int N>
void DownscaleSIMD<N>::calculate_ratios() {
    // Replica Downscale_SIMD.sv líneas 165-166
    if (width_out_ > 1)
        x_ratio_fp_ = ((width_in_ - 1) << FRAC_BITS) / (width_out_ - 1);
    else
        x_ratio_fp_ = 0;
        
    if (height_out_ > 1)
        y_ratio_fp_ = ((height_in_ - 1) << FRAC_BITS) / (height_out_ - 1);
    else
        y_ratio_fp_ = 0;
}

// ============================================================================
// DownscaleSIMD::process_batch()
// ============================================================================
// Replica el procesamiento de un batch de N píxeles en paralelo
// Downscale_SIMD.sv líneas 172-367
// ============================================================================
template<int N>
void DownscaleSIMD<N>::process_batch(const std::vector<uint8_t>& input,
                                     std::vector<uint8_t>& output,
                                     uint32_t base_idx) {
    uint32_t total_pixels = width_out_ * height_out_;
    
    // Arrays para N píxeles (SIMD lanes)
    uint8_t I00_vec[N], I10_vec[N], I01_vec[N], I11_vec[N];
    uint8_t alpha_vec[N], beta_vec[N];
    bool valid_lane[N];
    uint32_t i_dst[N], j_dst[N];
    
    // S_CALC_COORDS (líneas 172-183)
    for (int k = 0; k < N; k++) {
        uint32_t idx = base_idx + k;
        valid_lane[k] = (idx < total_pixels);
        
        if (valid_lane[k]) {
            i_dst[k] = idx / width_out_;
            j_dst[k] = idx % width_out_;
        }
    }
    
    // S_CALC_SRC, S_REQ_I00-I11, S_WAIT_I00-I11 (líneas 186-333)
    for (int k = 0; k < N; k++) {
        if (valid_lane[k]) {
            // Calcular coordenadas fuente
            uint32_t x_src_fp = j_dst[k] * x_ratio_fp_;
            uint32_t y_src_fp = i_dst[k] * y_ratio_fp_;
            
            uint32_t x_l = x_src_fp >> FRAC_BITS;
            uint32_t y_l = y_src_fp >> FRAC_BITS;
            uint32_t x_h = (x_l < width_in_ - 1) ? (x_l + 1) : x_l;
            uint32_t y_h = (y_l < height_in_ - 1) ? (y_l + 1) : y_l;
            
            alpha_vec[k] = (uint8_t)(x_src_fp & 0xFF);
            beta_vec[k]  = (uint8_t)(y_src_fp & 0xFF);
            
            // Leer 4 píxeles vecinos (N lanes en paralelo)
            I00_vec[k] = input[y_l * width_in_ + x_l];
            I10_vec[k] = input[y_l * width_in_ + x_h];
            I01_vec[k] = input[y_h * width_in_ + x_l];
            I11_vec[k] = input[y_h * width_in_ + x_h];
            
            // 4 lecturas por lane
            stats_.memory_reads += 4;
        }
    }
    
    // S_START_TOP, S_WAIT_TOP (líneas 336-347)
    // Procesar N interpolaciones en paralelo
    for (int k = 0; k < N; k++) {
        if (valid_lane[k]) {
            interpolators_[k].process(I00_vec[k], I10_vec[k], I01_vec[k], I11_vec[k],
                                     alpha_vec[k], beta_vec[k]);
        }
    }
    
    // S_WRITE_BATCH (líneas 350-367)
    // Escribir resultados secuencialmente
    for (int k = 0; k < N; k++) {
        if (valid_lane[k]) {
            uint32_t out_idx = base_idx + k;
            output[out_idx] = interpolators_[k].pixel_out();
            stats_.memory_writes++;
        }
    }
    
    // Aproximación de ciclos (similar al hardware)
    stats_.cycles += 20;  // ~20 ciclos por batch de N píxeles
}

// ============================================================================
// DownscaleSIMD::process()
// ============================================================================
// Procesa la imagen completa en batches de N píxeles
// ============================================================================
template<int N>
void DownscaleSIMD<N>::process(const std::vector<uint8_t>& input,
                               std::vector<uint8_t>& output) {
    // Resetear estadísticas
    stats_ = {0, 0, 0, 0};
    
    // Validación
    if (input.size() != width_in_ * height_in_) {
        std::cerr << "ERROR: Tamaño de entrada inválido" << std::endl;
        return;
    }
    
    uint32_t total_pixels = width_out_ * height_out_;
    output.resize(total_pixels);
    
    // Procesar en batches de N píxeles (SIMD)
    // Replica la FSM del Downscale_SIMD.sv
    for (uint32_t base_idx = 0; base_idx < total_pixels; base_idx += N) {
        process_batch(input, output, base_idx);
    }
    
    // FLOPs estimados
    stats_.flops = total_pixels * 10;
}

// ============================================================================
// Funciones auxiliares
// ============================================================================

bool load_image_txt(const std::string& filename,
                    std::vector<uint8_t>& image,
                    uint32_t& width, uint32_t& height) {
    std::ifstream file(filename);
    if (!file.is_open()) {
        std::cerr << "ERROR: No se pudo abrir " << filename << std::endl;
        return false;
    }
    
    image.clear();
    std::string line;
    
    // Leer archivo línea por línea
    // Formato: valores separados por espacios, una fila por línea
    std::vector<std::vector<uint8_t>> rows;
    
    while (std::getline(file, line)) {
        if (line.empty()) continue;
        
        std::istringstream iss(line);
        std::vector<uint8_t> row;
        int pixel;
        
        while (iss >> pixel) {
            // Saturar a rango [0, 255]
            if (pixel < 0) pixel = 0;
            if (pixel > 255) pixel = 255;
            row.push_back((uint8_t)pixel);
        }
        
        if (!row.empty())
            rows.push_back(row);
    }
    
    file.close();
    
    // Determinar dimensiones
    height = rows.size();
    width = (height > 0) ? rows[0].size() : 0;
    
    // Convertir a vector plano
    for (const auto& row : rows) {
        for (uint8_t pixel : row) {
            image.push_back(pixel);
        }
    }
    
    std::cout << "Imagen cargada: " << width << " × " << height 
              << " (" << image.size() << " píxeles)" << std::endl;
    
    return true;
}

bool save_image_txt(const std::string& filename,
                    const std::vector<uint8_t>& image,
                    uint32_t width, uint32_t height) {
    std::ofstream file(filename);
    if (!file.is_open()) {
        std::cerr << "ERROR: No se pudo crear " << filename << std::endl;
        return false;
    }
    
    // Escribir píxeles fila por fila (formato: valores separados por espacios)
    for (uint32_t y = 0; y < height; y++) {
        for (uint32_t x = 0; x < width; x++) {
            file << (int)image[y * width + x];
            if (x < width - 1)
                file << " ";
        }
        file << "\n";
    }
    
    file.close();
    std::cout << "Imagen guardada: " << filename << std::endl;
    return true;
}

bool compare_images(const std::vector<uint8_t>& img1,
                    const std::vector<uint8_t>& img2,
                    uint32_t& diff_count) {
    diff_count = 0;
    
    if (img1.size() != img2.size()) {
        std::cerr << "ERROR: Tamaños diferentes (" << img1.size() 
                  << " vs " << img2.size() << ")" << std::endl;
        return false;
    }
    
    for (size_t i = 0; i < img1.size(); i++) {
        if (img1[i] != img2[i]) {
            diff_count++;
            
            // Mostrar primeras 10 diferencias
            if (diff_count <= 10) {
                std::cout << "  Diff @" << i << ": " 
                         << (int)img1[i] << " vs " << (int)img2[i] << std::endl;
            }
        }
    }
    
    return (diff_count == 0);
}

void print_stats(const DownscaleSequential::Stats& stats,
                 uint32_t width_out, uint32_t height_out,
                 const char* mode_name) {
    uint32_t total_pixels = width_out * height_out;

    std::cout << "\n=========================================" << std::endl;
    std::cout << "  ESTADÍSTICAS - " << mode_name << std::endl;
    std::cout << "=========================================" << std::endl;
    std::cout << "Ciclos:           " << stats.cycles << std::endl;
    std::cout << "Lecturas memoria: " << stats.memory_reads << std::endl;
    std::cout << "Escrituras mem:   " << stats.memory_writes << std::endl;
    std::cout << "FLOPs:            " << stats.flops << std::endl;
    std::cout << "\nPíxeles de salida: " << total_pixels << std::endl;

    if (stats.cycles > 0 && total_pixels > 0) {
        // Ciclos por píxel: indica cuántos ciclos tarda en promedio cada píxel de salida
        float cycles_per_pixel = static_cast<float>(stats.cycles) / total_pixels;
        std::cout << "Ciclos/píxel:      " << std::fixed << std::setprecision(2)
                  << cycles_per_pixel << std::endl;

        // Asumimos una frecuencia de reloj de 50 MHz (igual que la FPGA del proyecto)
        // Tiempo total (segundos) = ciclos / frecuencia
        constexpr double F_CLK_HZ = 50e6;
        double time_seconds = static_cast<double>(stats.cycles) / F_CLK_HZ;

        // Throughput en MPix/s: (píxeles de salida / tiempo) / 1e6
        double throughput_mpix = (static_cast<double>(total_pixels) / time_seconds) / 1e6;

        // GFLOPS efectivos: (FLOPs / tiempo) / 1e9
        double gflops = 0.0;
        if (stats.flops > 0) {
            gflops = (static_cast<double>(stats.flops) / time_seconds) / 1e9;
        }

        // Intensidad aritmética aproximada: FLOPs / (lecturas + escrituras de memoria)
        uint64_t mem_ops = static_cast<uint64_t>(stats.memory_reads) +
                           static_cast<uint64_t>(stats.memory_writes);
        double intensity = 0.0;
        if (mem_ops > 0 && stats.flops > 0) {
            intensity = static_cast<double>(stats.flops) / static_cast<double>(mem_ops);
        }

        std::cout << "\n-- Métricas derivadas (asumiendo 50 MHz) --" << std::endl;
        std::cout << "Tiempo estimado:   " << std::setprecision(3)
                  << (time_seconds * 1e3) << " ms  "
                  << "(time = ciclos / 50e6)" << std::endl;
        std::cout << "Throughput:        " << std::setprecision(3)
                  << throughput_mpix << " MPix/s  "
                  << "(píxeles_salida / tiempo)" << std::endl;
        if (stats.flops > 0) {
            std::cout << "GFLOPS efectivos:  " << std::setprecision(3)
                      << gflops << " GFLOPS  "
                      << "(FLOPs / tiempo)" << std::endl;
        }
        if (mem_ops > 0 && stats.flops > 0) {
            std::cout << "Intensidad aritm.: " << std::setprecision(3)
                      << intensity << " FLOPs/op_mem  "
                      << "(FLOPs / (lecturas+escrituras))" << std::endl;
        }
    }
    std::cout << "=========================================" << std::endl;
}

// Instanciación explícita de templates (para compilación separada)
template class DownscaleSIMD<4>;
template class DownscaleSIMD<8>;
template class DownscaleSIMD<16>;

