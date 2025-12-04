# 🎯 Modelo de Referencia en C++ - DSA Downscaler

Modelo de referencia **bit a bit idéntico** al hardware DSA implementado en SystemVerilog.

---

## 📋 Descripción

Este modelo replica exactamente:
- ✅ Interpolación bilineal (módulo `ModoSecuencial.sv`)
- ✅ Modo secuencial (módulo `Downscale_Secuencial.sv`)
- ✅ Modo SIMD N=4 (módulo `Downscale_SIMD.sv`)
- ✅ Formato de punto fijo Q0.8 y Q0.16
- ✅ Mismo algoritmo de redondeo y saturación

---

## 🔧 Compilación

### Requisitos
- Compilador C++ con soporte C++17 o superior (g++, clang++)
- Sistema operativo: Linux, macOS, Windows (con MinGW/MSYS2)

### Compilar

```bash
cd modelo_referencia
make
```

Esto genera el ejecutable `dsa_downscale`.

---

## 🚀 Uso

### Sintaxis

```bash
./dsa_downscale <modo> <input.txt> <w_in> <h_in> <w_out> <h_out> <output.txt>
```

### Parámetros

| Parámetro | Descripción |
|-----------|-------------|
| `<modo>` | `seq` (secuencial), `simd` (SIMD N=4), o `both` (ambos + comparación) |
| `<input.txt>` | Archivo de entrada (formato texto) |
| `<w_in>` | Ancho imagen entrada |
| `<h_in>` | Alto imagen entrada |
| `<w_out>` | Ancho imagen salida |
| `<h_out>` | Alto imagen salida |
| `<output.txt>` | Archivo de salida |

### Ejemplos

#### Modo Secuencial (512×512 → 256×256)
```bash
./dsa_downscale seq ../imagen_grayscale.txt 512 512 256 256 output_seq.txt
```

#### Modo SIMD (128×128 → 64×64)
```bash
./dsa_downscale simd ../imagen_128x128_gradient.txt 128 128 64 64 output_simd.txt
```

#### Comparar ambos modos
```bash
./dsa_downscale both ../imagen_grayscale.txt 256 256 128 128 output.txt
```

Esto genera:
- `output_seq.txt` - Resultado modo secuencial
- `output_simd.txt` - Resultado modo SIMD
- `output.txt` - Resultado final (SIMD si son idénticos)
- Comparación bit a bit entre ambos modos

---

## 📁 Formato de Archivos

### Archivo de Entrada/Salida (.txt)

Formato: Valores separados por espacios, una fila por línea

```
0 1 2 3 4 5 ...
10 11 12 13 14 15 ...
20 21 22 23 24 25 ...
...
```

- Valores: 0-255 (grayscale)
- Total líneas = `height`
- Valores por línea = `width`

**Mismo formato que usa el hardware en FPGA.**

---

## ✅ Validación Bit a Bit

### Comparar con resultado de hardware FPGA

1. **Ejecutar downscale en FPGA** (vía JTAG):
   ```tcl
   source tcl/test_downscale_complete.tcl
   # Resultado guardado en: imagen_output_secuencial.txt
   ```

2. **Ejecutar modelo de referencia**:
   ```bash
   ./dsa_downscale seq ../imagen_grayscale.txt 512 512 256 256 output_ref.txt
   ```

3. **Comparar archivos**:
   ```bash
   diff output_ref.txt ../imagen_output_secuencial.txt
   ```

Si no hay diferencias, ¡el modelo es **bit a bit idéntico** al hardware! ✓

---

## 📊 Salida Ejemplo

```
=============================================
  Configuración
=============================================
Modo:         seq
Entrada:      512 × 512 píxeles
Salida:       256 × 256 píxeles
Archivo IN:   input.txt
Archivo OUT:  output.txt
Factor escala: 0.500 (width), 0.500 (height)
=============================================

Cargando imagen de entrada...
Imagen cargada: 512 × 512 (262144 píxeles)

[Modo Secuencial]
Procesando... Completado en 45 ms

=========================================
  ESTADÍSTICAS - Secuencial
=========================================
Ciclos:           393216
Lecturas memoria: 262144
Escrituras mem:   65536
FLOPs:            655360

Píxeles de salida: 65536
Ciclos/píxel:      6.00
=========================================

Imagen guardada: output.txt

¡Proceso completado exitosamente!
```

---

## 🔬 Detalles de Implementación

### Formato Numérico

| Componente | Formato | Rango | Uso |
|------------|---------|-------|-----|
| Píxeles | uint8 | 0-255 | Entrada/Salida |
| Alpha/Beta | Q0.8 | 0.0-1.0 | Pesos interpolación |
| Cálculos internos | Q0.16 | - | Productos intermedios |

### Algoritmo de Interpolación Bilinear

```cpp
result = I00*(1-α)*(1-β) + I10*α*(1-β) + I01*(1-α)*β + I11*α*β
```

Donde:
- `I00, I10, I01, I11` = 4 píxeles vecinos
- `α (alpha)` = fracción horizontal en Q0.8
- `β (beta)` = fracción vertical en Q0.8

### Redondeo y Saturación

1. Suma en Q0.16
2. Redondeo: `result += 0x8000` (0.5 en Q0.16)
3. Shift: `result >> 16`
4. Saturación: `clamp(result, 0, 255)`

**Idéntico al hardware (ModoSecuencial.sv líneas 70-83)**

---

## 📝 Archivos

| Archivo | Descripción |
|---------|-------------|
| `bilinear_downscale.h` | Declaraciones de clases |
| `bilinear_downscale.cpp` | Implementación |
| `main.cpp` | Programa principal |
| `Makefile` | Compilación |
| `README.md` | Esta documentación |

---

## 🐛 Troubleshooting

### Error de compilación
```bash
make clean
make
```

### Diferencias con hardware
- Verificar que usas el **mismo archivo de entrada**
- Verificar que las **dimensiones coincidan**
- El modelo usa el **mismo algoritmo exacto** que el hardware

---

## 📚 Referencias

- **Hardware:** `rtl/ModoSecuencial.sv`, `rtl/Downscale_Secuencial.sv`, `rtl/Downscale_SIMD.sv`
- **Especificación:** `Proyectos_especificacion_proyecto_02_CE_4302_S2_2025.pdf`
- **Plan de Verificación:** Ver archivo separado `plan_verificacion.md`

---

**Autor:** Proyecto DSA - CE4302  
**Fecha:** Diciembre 2025  
**Estado:** ✅ Modelo completo y validado

