// ============================================================================
// bilinear_downscale.h
// ============================================================================
// Modelo de referencia en C++ para DSA Downscaler con Interpolación Bilineal
// Replica BIT A BIT el comportamiento del hardware en SystemVerilog
//
// Formatos numéricos:
// - Q0.8: 8 bits fraccionarios para alpha/beta (0-255 representa 0.0-1.0)
// - Q0.16: 16 bits fraccionarios para cálculos internos
//
// Autor: Proyecto DSA - CE4302
// Fecha: Diciembre 2025
// ============================================================================

#ifndef BILINEAR_DOWNSCALE_H
#define BILINEAR_DOWNSCALE_H

#include <cstdint>
#include <vector>
#include <string>

// ============================================================================
// Constantes
// ============================================================================
constexpr int FRAC_BITS = 8;  // Punto fijo Q0.8 para alpha/beta
constexpr int Q16_ROUND = 32768; // 0.5 en Q0.16 para redondeo

// ============================================================================
// Clase: BilinearInterpolator
// ============================================================================
// Replica el módulo ModoSecuencial.sv
// Pipeline de 1 ciclo, formato Q0.16 interno
// ============================================================================
class BilinearInterpolator {
public:
    // Constructor
    BilinearInterpolator() : valid_out_(false), pixel_out_(0) {}
    
    // Procesar interpolación bilineal (replica ModoSecuencial.sv líneas 22-83)
    void process(uint8_t I00, uint8_t I10, uint8_t I01, uint8_t I11,
                 uint8_t alpha, uint8_t beta);
    
    // Getters (representan las salidas del módulo)
    bool valid_out() const { return valid_out_; }
    uint8_t pixel_out() const { return pixel_out_; }
    
private:
    bool valid_out_;
    uint8_t pixel_out_;
    
    // Funciones internas (replican la lógica combinacional)
    uint32_t calculate_term(uint8_t pixel, uint8_t coef1, uint8_t coef2);
    uint8_t clamp_result(uint32_t result);
};

// ============================================================================
// Clase: DownscaleSequential
// ============================================================================
// Replica el módulo Downscale_Secuencial.sv
// Procesa 1 píxel por iteración
// ============================================================================
class DownscaleSequential {
public:
    DownscaleSequential();
    
    // Configurar dimensiones (dinámicas, como en hardware)
    void configure(uint32_t width_in, uint32_t height_in,
                   uint32_t width_out, uint32_t height_out);
    
    // Procesar downscale completo
    // input: imagen de entrada (width_in × height_in píxeles)
    // output: imagen de salida (width_out × height_out píxeles)
    void process(const std::vector<uint8_t>& input,
                 std::vector<uint8_t>& output);
    
    // Obtener estadísticas (para validación)
    struct Stats {
        uint32_t cycles;
        uint32_t memory_reads;
        uint32_t memory_writes;
        uint32_t flops;  // Operaciones de punto flotante (aprox)
    };
    Stats get_stats() const { return stats_; }
    
private:
    // Dimensiones (configurables en runtime, como en hardware)
    uint32_t width_in_;
    uint32_t height_in_;
    uint32_t width_out_;
    uint32_t height_out_;
    
    // Ratios pre-calculados (Q0.8 fixed point)
    uint32_t x_ratio_fp_;
    uint32_t y_ratio_fp_;
    
    // Interpolador (instancia del ModoSecuencial)
    BilinearInterpolator interpolator_;
    
    // Estadísticas
    Stats stats_;
    
    // Funciones auxiliares
    void calculate_ratios();
    void get_neighbor_pixels(const std::vector<uint8_t>& input,
                            uint32_t i_dst, uint32_t j_dst,
                            uint8_t& I00, uint8_t& I10, 
                            uint8_t& I01, uint8_t& I11,
                            uint8_t& alpha, uint8_t& beta);
};

// ============================================================================
// Clase: DownscaleSIMD
// ============================================================================
// Replica el módulo Downscale_SIMD.sv
// Procesa N píxeles en paralelo
// ============================================================================
template<int N = 4>
class DownscaleSIMD {
public:
    DownscaleSIMD();
    
    // Configurar dimensiones
    void configure(uint32_t width_in, uint32_t height_in,
                   uint32_t width_out, uint32_t height_out);
    
    // Procesar downscale completo (N píxeles en paralelo)
    void process(const std::vector<uint8_t>& input,
                 std::vector<uint8_t>& output);
    
    // Obtener estadísticas
    using Stats = DownscaleSequential::Stats;
    Stats get_stats() const { return stats_; }
    
private:
    // Dimensiones
    uint32_t width_in_;
    uint32_t height_in_;
    uint32_t width_out_;
    uint32_t height_out_;
    
    // Ratios
    uint32_t x_ratio_fp_;
    uint32_t y_ratio_fp_;
    
    // N interpoladores paralelos (SIMD lanes)
    BilinearInterpolator interpolators_[N];
    
    // Estadísticas
    Stats stats_;
    
    // Funciones auxiliares
    void calculate_ratios();
    void process_batch(const std::vector<uint8_t>& input,
                      std::vector<uint8_t>& output,
                      uint32_t base_idx);
};

// ============================================================================
// Funciones auxiliares globales
// ============================================================================

// Cargar imagen desde archivo .txt (formato: un píxel por línea)
bool load_image_txt(const std::string& filename,
                    std::vector<uint8_t>& image,
                    uint32_t& width, uint32_t& height);

// Guardar imagen a archivo .txt
bool save_image_txt(const std::string& filename,
                    const std::vector<uint8_t>& image,
                    uint32_t width, uint32_t height);

// Comparar dos imágenes bit a bit
bool compare_images(const std::vector<uint8_t>& img1,
                    const std::vector<uint8_t>& img2,
                    uint32_t& diff_count);

// Imprimir estadísticas
void print_stats(const DownscaleSequential::Stats& stats,
                 uint32_t width_out, uint32_t height_out,
                 const char* mode_name);

#endif // BILINEAR_DOWNSCALE_H

