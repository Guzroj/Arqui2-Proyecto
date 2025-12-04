/**
 * bilinear.h
 * Interpolación bilineal usando aritmética Q8.8
 */

#ifndef BILINEAR_H
#define BILINEAR_H

#include <cstdint>
#include "fixed_point.h"

/**
 * Interpola un píxel usando interpolación bilineal con aritmética Q8.8
 *
 * Fórmula:
 *   result = p00*(1-fx)*(1-fy) + p01*fx*(1-fy) + p10*(1-fx)*fy + p11*fx*fy
 *
 * @param p00 Píxel superior izquierdo (0-255)
 * @param p01 Píxel superior derecho (0-255)
 * @param p10 Píxel inferior izquierdo (0-255)
 * @param p11 Píxel inferior derecho (0-255)
 * @param fx Peso horizontal (Q8.8, 0.0-1.0)
 * @param fy Peso vertical (Q8.8, 0.0-1.0)
 * @return Píxel interpolado (0-255)
 */
uint8_t bilinear_interpolate(
    uint8_t p00, uint8_t p01,
    uint8_t p10, uint8_t p11,
    fixed_t fx, fixed_t fy
);

#endif // BILINEAR_H
