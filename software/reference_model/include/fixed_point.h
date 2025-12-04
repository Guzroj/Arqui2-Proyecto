/**
 * fixed_point.h
 * Aritmética de punto fijo Q8.8 para interpolación bilineal
 *
 * Formato Q8.8:
 * - 16 bits totales
 * - 8 bits parte entera (0-255)
 * - 8 bits parte fraccionaria (precisión 1/256)
 */

#ifndef FIXED_POINT_H
#define FIXED_POINT_H

#include <cstdint>
#include <algorithm>

// Tipo para representar números Q8.8
typedef int16_t fixed_t;

// Constantes
const int FRACTIONAL_BITS = 8;
const int SCALE_FACTOR = 1 << FRACTIONAL_BITS;  // 2^8 = 256

/**
 * Convierte float a Q8.8
 *
 * @param f Número en punto flotante
 * @return Representación en Q8.8 (16 bits)
 */
inline fixed_t float_to_fixed(float f) {
    // Multiplicar por 256 y redondear
    int32_t fixed = static_cast<int32_t>(f * SCALE_FACTOR + 0.5f);

    // Clamp a rango válido de 16 bits con signo
    fixed = std::max(-32768, std::min(32767, fixed));

    return static_cast<fixed_t>(fixed);
}

/**
 * Convierte Q8.8 a float
 *
 * @param fixed Número en Q8.8 (16 bits)
 * @return Valor en punto flotante
 */
inline float fixed_to_float(fixed_t fixed) {
    return static_cast<float>(fixed) / SCALE_FACTOR;
}

/**
 * Multiplicación Q8.8 × Q8.8 → Q8.8
 *
 * Algoritmo:
 * 1. Multiplicar valores → resultado de 32 bits (Q16.16)
 * 2. Shift right 8 bits → Q8.8
 *
 * @param a Primer operando Q8.8
 * @param b Segundo operando Q8.8
 * @return Resultado en Q8.8
 */
inline fixed_t fixed_mul(fixed_t a, fixed_t b) {
    // Multiplicación 16x16 → 32 bits
    int32_t product = static_cast<int32_t>(a) * static_cast<int32_t>(b);

    // Shift para mantener formato Q8.8
    fixed_t result = static_cast<fixed_t>(product >> FRACTIONAL_BITS);

    return result;
}

/**
 * Suma Q8.8 + Q8.8 → Q8.8
 *
 * @param a Primer operando Q8.8
 * @param b Segundo operando Q8.8
 * @return Resultado en Q8.8
 */
inline fixed_t fixed_add(fixed_t a, fixed_t b) {
    return a + b;
}

/**
 * Convierte píxel (0-255) a Q8.8
 *
 * @param pixel Valor del píxel (uint8, 0-255)
 * @return Valor en Q8.8
 */
inline fixed_t pixel_to_fixed(uint8_t pixel) {
    // Píxel es entero, solo shift left
    return static_cast<fixed_t>(pixel) << FRACTIONAL_BITS;
}

/**
 * Convierte Q8.8 a píxel (0-255) con saturación
 *
 * @param fixed Valor en Q8.8
 * @return Píxel (uint8, 0-255)
 */
inline uint8_t fixed_to_pixel(fixed_t fixed) {
    // Extraer parte entera (shift right 8)
    int pixel = fixed >> FRACTIONAL_BITS;

    // Saturar a rango 0-255
    if (pixel < 0) pixel = 0;
    if (pixel > 255) pixel = 255;

    return static_cast<uint8_t>(pixel);
}

#endif // FIXED_POINT_H
