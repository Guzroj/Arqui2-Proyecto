/**
 * bilinear.cpp
 * Implementación de interpolación bilineal con Q8.8
 */

#include "bilinear.h"

uint8_t bilinear_interpolate(
    uint8_t p00, uint8_t p01,
    uint8_t p10, uint8_t p11,
    fixed_t fx, fixed_t fy
) {
    // Convertir píxeles a Q8.8 (shift left 8)
    fixed_t p00_fixed = pixel_to_fixed(p00);
    fixed_t p01_fixed = pixel_to_fixed(p01);
    fixed_t p10_fixed = pixel_to_fixed(p10);
    fixed_t p11_fixed = pixel_to_fixed(p11);

    // Calcular (1 - fx) y (1 - fy)
    fixed_t one = float_to_fixed(1.0f);  // 1.0 en Q8.8 = 256
    fixed_t one_minus_fx = one - fx;
    fixed_t one_minus_fy = one - fy;

    // Calcular los 4 pesos
    // w00 = (1-fx) * (1-fy)
    // w01 = fx * (1-fy)
    // w10 = (1-fx) * fy
    // w11 = fx * fy
    fixed_t w00 = fixed_mul(one_minus_fx, one_minus_fy);
    fixed_t w01 = fixed_mul(fx, one_minus_fy);
    fixed_t w10 = fixed_mul(one_minus_fx, fy);
    fixed_t w11 = fixed_mul(fx, fy);

    // Multiplicar píxeles por sus pesos
    fixed_t term00 = fixed_mul(p00_fixed, w00);
    fixed_t term01 = fixed_mul(p01_fixed, w01);
    fixed_t term10 = fixed_mul(p10_fixed, w10);
    fixed_t term11 = fixed_mul(p11_fixed, w11);

    // Sumar todos los términos
    fixed_t result_fixed = fixed_add(
        fixed_add(term00, term01),
        fixed_add(term10, term11)
    );

    // Convertir de vuelta a uint8
    uint8_t result_pixel = fixed_to_pixel(result_fixed);

    return result_pixel;
}
