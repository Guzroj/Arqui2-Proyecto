#!/usr/bin/env python3
"""
fixed_point.py
Aritmética de punto fijo Q8.8 para interpolación bilineal

Formato Q8.8:
- 16 bits totales
- 8 bits parte entera (rango 0-255)
- 8 bits parte fraccionaria (precisión 1/256)

Ejemplo: 100.5 → (100 * 256 + 128) = 25728 en Q8.8
"""

class Q8_8:
    """Clase para representar números en formato Q8.8"""

    FRACTIONAL_BITS = 8
    SCALE_FACTOR = 1 << FRACTIONAL_BITS  # 2^8 = 256

    def __init__(self, value=0, raw=False):
        """
        Constructor

        Args:
            value: Valor inicial (float o int)
            raw: Si True, value ya está en formato Q8.8 (no convertir)
        """
        if raw:
            self.raw_value = int(value)
        else:
            self.raw_value = self.float_to_fixed(value)

    @classmethod
    def float_to_fixed(cls, f):
        """
        Convierte float a Q8.8

        Args:
            f: Número en punto flotante

        Returns:
            int: Representación en Q8.8 (16 bits)
        """
        # Multiplicar por 256 y redondear
        fixed = int(f * cls.SCALE_FACTOR + 0.5)

        # Clamp a rango válido de 16 bits con signo
        # (aunque usamos principalmente sin signo)
        fixed = max(-32768, min(32767, fixed))

        return fixed

    @classmethod
    def fixed_to_float(cls, fixed):
        """
        Convierte Q8.8 a float

        Args:
            fixed: Número en Q8.8 (int de 16 bits)

        Returns:
            float: Valor en punto flotante
        """
        return float(fixed) / cls.SCALE_FACTOR

    def to_float(self):
        """Convierte esta instancia a float"""
        return self.fixed_to_float(self.raw_value)

    def to_int(self):
        """Extrae la parte entera"""
        return self.raw_value >> self.FRACTIONAL_BITS

    def to_uint8(self):
        """
        Convierte a uint8 (0-255) con saturación
        Usado para convertir resultado final a píxel
        """
        # Extraer parte entera
        integer_part = self.raw_value >> self.FRACTIONAL_BITS

        # Saturar a rango 0-255
        return max(0, min(255, integer_part))

    def __mul__(self, other):
        """
        Multiplicación Q8.8 × Q8.8 → Q8.8

        Algoritmo:
        1. Multiplicar valores raw → resultado de 32 bits (Q16.16)
        2. Shift right 8 bits → Q8.8
        """
        if isinstance(other, Q8_8):
            # Q8.8 * Q8.8 = Q16.16, shift >> 8 para Q8.8
            result_raw = (self.raw_value * other.raw_value) >> self.FRACTIONAL_BITS
        elif isinstance(other, (int, float)):
            # Multiplicar por escalar
            other_fixed = self.float_to_fixed(other)
            result_raw = (self.raw_value * other_fixed) >> self.FRACTIONAL_BITS
        else:
            raise TypeError(f"No se puede multiplicar Q8_8 con {type(other)}")

        return Q8_8(result_raw, raw=True)

    def __rmul__(self, other):
        """Multiplicación conmutativa"""
        return self.__mul__(other)

    def __add__(self, other):
        """Suma Q8.8 + Q8.8 → Q8.8"""
        if isinstance(other, Q8_8):
            result_raw = self.raw_value + other.raw_value
        elif isinstance(other, (int, float)):
            other_fixed = self.float_to_fixed(other)
            result_raw = self.raw_value + other_fixed
        else:
            raise TypeError(f"No se puede sumar Q8_8 con {type(other)}")

        return Q8_8(result_raw, raw=True)

    def __radd__(self, other):
        """Suma conmutativa"""
        return self.__add__(other)

    def __sub__(self, other):
        """Resta Q8.8 - Q8.8 → Q8.8"""
        if isinstance(other, Q8_8):
            result_raw = self.raw_value - other.raw_value
        elif isinstance(other, (int, float)):
            other_fixed = self.float_to_fixed(other)
            result_raw = self.raw_value - other_fixed
        else:
            raise TypeError(f"No se puede restar Q8_8 con {type(other)}")

        return Q8_8(result_raw, raw=True)

    def __repr__(self):
        return f"Q8_8({self.to_float():.4f}, raw=0x{self.raw_value:04X})"

    def __str__(self):
        return f"{self.to_float():.4f}"


# Funciones de utilidad standalone
def fixed_multiply(a_raw, b_raw):
    """
    Multiplicación Q8.8 standalone (sin usar clase)

    Args:
        a_raw: int en formato Q8.8
        b_raw: int en formato Q8.8

    Returns:
        int: Resultado en formato Q8.8
    """
    # Forzar conversión a int para evitar overflow con numpy uint8
    a_raw = int(a_raw)
    b_raw = int(b_raw)

    # 32-bit producto
    product = a_raw * b_raw
    # Shift para mantener Q8.8
    result = product >> 8
    return result


def pixel_to_fixed(pixel):
    """
    Convierte píxel (0-255) a Q8.8

    Args:
        pixel: int (0-255)

    Returns:
        int: Valor en Q8.8
    """
    # Forzar conversión a int para evitar overflow con numpy uint8
    pixel = int(pixel)
    # Píxel ya es entero, solo shift left
    return pixel << 8


def fixed_to_pixel(fixed):
    """
    Convierte Q8.8 a píxel (0-255) con saturación

    Args:
        fixed: int en formato Q8.8

    Returns:
        int: Píxel (0-255)
    """
    # Forzar conversión a int
    fixed = int(fixed)
    # Extraer parte entera (shift right 8)
    pixel = fixed >> 8
    # Saturar
    return max(0, min(255, pixel))


# Tests unitarios
if __name__ == "__main__":
    print("="*60)
    print("TESTS: Aritmética Q8.8")
    print("="*60)

    # Test 1: Conversión float → Q8.8 → float
    print("\nTest 1: Conversión float ↔ Q8.8")
    test_values = [0.0, 0.5, 1.0, 2.5, 100.25, 255.0]
    for val in test_values:
        q = Q8_8(val)
        recovered = q.to_float()
        print(f"  {val:7.2f} → {q.raw_value:5d} (0x{q.raw_value:04X}) → {recovered:7.4f}  "
              f"[Error: {abs(val - recovered):.6f}]")

    # Test 2: Multiplicación
    print("\nTest 2: Multiplicación Q8.8")
    tests = [
        (0.5, 0.5, 0.25),
        (1.0, 1.0, 1.0),
        (2.0, 3.0, 6.0),
        (0.75, 0.5, 0.375),
        (255.0, 1.0, 255.0)
    ]
    for a, b, expected in tests:
        qa = Q8_8(a)
        qb = Q8_8(b)
        result = qa * qb
        print(f"  {a:6.2f} × {b:6.2f} = {result.to_float():8.4f}  "
              f"(esperado: {expected:6.3f}, error: {abs(result.to_float() - expected):.6f})")

    # Test 3: Suma
    print("\nTest 3: Suma Q8.8")
    tests = [
        (0.5, 0.5, 1.0),
        (100.25, 50.75, 151.0),
        (255.0, 0.5, 255.5)
    ]
    for a, b, expected in tests:
        qa = Q8_8(a)
        qb = Q8_8(b)
        result = qa + qb
        print(f"  {a:6.2f} + {b:6.2f} = {result.to_float():8.4f}  "
              f"(esperado: {expected:6.2f}, error: {abs(result.to_float() - expected):.6f})")

    # Test 4: Píxel → Q8.8 → Píxel
    print("\nTest 4: Conversión píxel ↔ Q8.8")
    pixels = [0, 128, 255]
    for p in pixels:
        fixed = pixel_to_fixed(p)
        recovered = fixed_to_pixel(fixed)
        print(f"  Píxel {p:3d} → Q8.8: {fixed:5d} (0x{fixed:04X}) → Píxel {recovered:3d}")

    # Test 5: Multiplicación de píxel por peso
    print("\nTest 5: Píxel × Peso (caso típico de interpolación)")
    pixel = 200
    weight = 0.75

    p_fixed = pixel_to_fixed(pixel)
    w_fixed = Q8_8.float_to_fixed(weight)
    result_fixed = fixed_multiply(p_fixed, w_fixed)
    result_pixel = fixed_to_pixel(result_fixed)

    expected = int(pixel * weight)

    print(f"  Píxel: {pixel}")
    print(f"  Peso:  {weight}")
    print(f"  Resultado: {result_pixel} (esperado: {expected})")
    print(f"  Error: {abs(result_pixel - expected)}")

    print("\n" + "="*60)
    print("✓ Todos los tests de Q8.8 completados")
    print("="*60)
