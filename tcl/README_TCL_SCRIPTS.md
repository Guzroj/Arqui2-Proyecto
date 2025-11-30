# 📋 Guía de Uso - Scripts TCL para DSA Downscaler

Esta guía explica cómo usar los scripts TCL para probar el acelerador DSA en la FPGA.

---

## 📁 Archivos Disponibles

| Script | Función |
|--------|---------|
| `test_dsa_basic.tcl` | Verificación básica del sistema |
| `load_image.tcl` | Cargar imagen desde archivo .txt a SDRAM |
| `run_downscale.tcl` | Ejecutar procesamiento de downscale |
| `read_result.tcl` | Leer imagen procesada desde SDRAM |
| `full_test.tcl` | Test automatizado completo |

---

## 🚀 Inicio Rápido

### **1. Conectar y Verificar Sistema**

Abre **System Console** en Quartus:
```
Tools → System Debugging Tools → System Console
```

En la consola TCL, ejecuta:

```tcl
cd "C:/Users/sebas/OneDrive/Escritorio/Arqui2-Proyecto1/tcl"
source test_dsa_basic.tcl
```

**Resultado esperado:**
```
✓ JTAG Master: Conectado
✓ Bus Avalon-MM: Funcional (LEDs OK)
✓ Registros DSA: Accesibles
✓ SDRAM: Funcional
✓ Estado DSA: IDLE (listo)
```

---

### **2. Cargar Imagen**

Prepara tu archivo de imagen:
- **Formato:** Archivo `.txt` con un píxel por línea
- **Valores:** Enteros de 0 a 255 (grayscale)
- **Ejemplo:** Para 512×512 necesitas 262,144 líneas

```tcl
source load_image.tcl
load_image_to_sdram "input_512x512.txt" 512 512
```

**O usar atajos:**
```tcl
quick_load_512x512 "input_512x512.txt"
quick_load_256x256 "input_256x256.txt"
```

---

### **3. Ejecutar Downscale**

```tcl
source run_downscale.tcl

# Modo Secuencial (1 píxel/ciclo)
run_downscale 512 512 256 256 0

# Modo SIMD (4 píxeles/ciclo)
run_downscale 512 512 256 256 1
```

**O usar atajos:**
```tcl
downscale_512_to_256_seq   # Secuencial
downscale_512_to_256_simd  # SIMD
```

**Resultado esperado:**
```
✓ Procesamiento completado
  Tiempo real: 1300 ms
  Ciclos: 65536
  Píxeles/segundo: 50000
```

---

### **4. Leer Resultado**

```tcl
source read_result.tcl
read_result_from_sdram "output_256x256.txt" 256 256 0x00100000
```

**O usar atajos:**
```tcl
quick_read_256x256 "output.txt"
```

El archivo de salida contendrá los píxeles procesados.

---

## 🎯 Test Completo Automatizado

Para ejecutar todo el flujo de una vez:

```tcl
source full_test.tcl
full_test "input.txt" 512 512 256 256 0
```

**O usar tests predefinidos:**
```tcl
test_512_to_256_sequential "input.txt"
test_512_to_256_simd "input.txt"
```

**Con archivo de comparación:**
```tcl
test_512_to_256_sequential "input.txt" "expected_256x256.txt"
```

---

## ⚡ Benchmark: Secuencial vs SIMD

Para comparar performance:

```tcl
source full_test.tcl
benchmark_seq_vs_simd "input.txt" 512 512 256 256
```

**Resultado esperado:**
```
Modo Secuencial:
  Ciclos: 65536
  Tiempo: 1.31 ms

Modo SIMD (N=4):
  Ciclos: 16384
  Tiempo: 0.33 ms

Speedup: 4.00×
✓ Excelente speedup (cercano a 4×)
```

---

## 📊 Formato de Archivos

### **Archivo de Entrada (input.txt)**

```
128
45
200
67
...
```

- Un valor por línea
- Valores: 0-255
- Total líneas = width × height
- Orden: fila por fila, de izquierda a derecha

### **Archivo de Salida (output.txt)**

Mismo formato que la entrada, pero con dimensiones de salida.

---

## 🔧 Funciones Avanzadas

### **Configurar Dimensiones Personalizadas**

```tcl
# Downscale arbitrario
run_downscale 480 320 240 160 0

# Con direcciones personalizadas
run_downscale 512 512 256 256 0 0x00000000 0x00200000
```

### **Comparar Imágenes**

```tcl
source read_result.tcl
compare_images "expected.txt" "output.txt"
```

**Resultado:**
```
Píxeles diferentes: 152 / 65536
Porcentaje error: 0.23%
Diferencia máxima: 3
Diferencia promedio: 1.2
✓ IMÁGENES MUY SIMILARES (< 1% diferencia)
```

### **Leer Performance Counters Manualmente**

```tcl
set DSA_BASE 0x05000000

# Leer contadores
set cycles [master_read_32 $jtag [expr {$DSA_BASE + 0x20}] 1]
set reads  [master_read_32 $jtag [expr {$DSA_BASE + 0x24}] 1]
set writes [master_read_32 $jtag [expr {$DSA_BASE + 0x28}] 1]
set flops  [master_read_32 $jtag [expr {$DSA_BASE + 0x2C}] 1]

puts "Ciclos: $cycles"
puts "Lecturas: $reads"
puts "Escrituras: $writes"
puts "FLOPs: $flops"
```

---

## 🐛 Troubleshooting

### **Error: "Variable 'jtag' no está definida"**

**Solución:**
```tcl
set jtag_masters [get_service_paths master]
set jtag [lindex $jtag_masters 0]
open_service master $jtag
```

### **Error: "DSA está ocupado (busy=1)"**

El DSA está procesando. Espera o resetea:

```tcl
# Leer status
set status [master_read_32 $jtag 0x05000004 1]
puts "Status: 0x[format %08X $status]"

# Esperar a que termine
while {[expr {$status & 0x01}]} {
    after 100
    set status [master_read_32 $jtag 0x05000004 1]
}
```

### **Error: "Timeout esperando DONE"**

El procesamiento tomó demasiado tiempo. Posibles causas:
- Dimensiones muy grandes
- Error en configuración
- Hardware no funciona correctamente

Verifica:
```tcl
# Ver si está procesando
set status [master_read_32 $jtag 0x05000004 1]
set busy [expr {$status & 0x01}]
puts "Busy: $busy"
```

### **LEDs no encienden**

Verifica conexión:
```tcl
# Test simple de LEDs
master_write_32 $jtag 0x04000000 0x3FF
after 1000
master_write_32 $jtag 0x04000000 0x000
```

Si no funciona:
- FPGA no está programada
- Cable USB-Blaster desconectado
- Dirección de LEDs incorrecta

---

## 📝 Mapa de Memoria

| Componente | Dirección Base | Tamaño | Uso |
|------------|----------------|--------|-----|
| SDRAM | 0x00000000 | 64 MB | Imágenes (input/output) |
| LEDs | 0x04000000 | 256 bytes | Test de conectividad |
| DSA Registros | 0x05000000 | 48 bytes | Control y estado |

### **Registros DSA (Base: 0x05000000)**

| Offset | Registro | Tipo | Descripción |
|--------|----------|------|-------------|
| 0x00 | CTRL | R/W | Control (start, reset, mode) |
| 0x04 | STATUS | RO | Estado (busy, done, error) |
| 0x08 | IMG_WIDTH_IN | R/W | Ancho entrada |
| 0x0C | IMG_HEIGHT_IN | R/W | Alto entrada |
| 0x10 | IMG_WIDTH_OUT | R/W | Ancho salida |
| 0x14 | IMG_HEIGHT_OUT | R/W | Alto salida |
| 0x18 | INPUT_BASE | R/W | Dirección base entrada |
| 0x1C | OUTPUT_BASE | R/W | Dirección base salida |
| 0x20 | PERF_CYCLES | RO | Contador de ciclos |
| 0x24 | PERF_READS | RO | Contador de lecturas |
| 0x28 | PERF_WRITES | RO | Contador de escrituras |
| 0x2C | PERF_FLOPS | RO | Operaciones FP |

---

## 🎓 Ejemplos Completos

### **Ejemplo 1: Test Básico 512→256**

```tcl
cd "C:/Users/sebas/OneDrive/Escritorio/Arqui2-Proyecto1/tcl"

# 1. Verificar sistema
source test_dsa_basic.tcl

# 2. Cargar imagen
source load_image.tcl
load_image_to_sdram "input_512.txt" 512 512

# 3. Ejecutar downscale (modo secuencial)
source run_downscale.tcl
run_downscale 512 512 256 256 0

# 4. Leer resultado
source read_result.tcl
read_result_from_sdram "output_256.txt" 256 256 0x00100000
```

### **Ejemplo 2: Comparar Modos**

```tcl
source full_test.tcl
benchmark_seq_vs_simd "input_512.txt" 512 512 256 256
```

### **Ejemplo 3: Test con Validación**

```tcl
source full_test.tcl
test_512_to_256_sequential "input.txt" "expected_output.txt"
```

---

## 📞 Soporte

Si tienes problemas:

1. **Verifica conexión:**
   ```tcl
   source test_dsa_basic.tcl
   ```

2. **Revisa logs** de System Console

3. **Verifica archivos:**
   - Formato correcto (.txt con valores 0-255)
   - Número correcto de píxeles
   - Sin líneas vacías extra

---

**Última actualización:** 30 Nov 2025  
**Versión:** 1.0  
**Proyecto:** DSA Downscaler con JTAG


