# Guía de Testing - DSA Downscaler

Esta guía explica cómo usar los scripts de prueba para verificar el funcionamiento del DSA Downscaler en hardware.

## 📋 Prerequisitos

1. **Hardware:**
   - DE1-SoC conectada vía USB Blaster
   - FPGA programada con `output_files/ModoSecuencial.sof`

2. **Software:**
   - Quartus Prime 20.1.1 Lite Edition
   - System Console (incluido con Quartus)
   - Python 3.x (para generación de imágenes)
   - Numpy (`pip install numpy`)
   - Matplotlib (opcional, para visualización: `pip install matplotlib`)

## 🚀 Paso 1: Programar la FPGA

1. Conectar DE1-SoC a PC vía USB
2. Abrir Quartus Programmer
3. Cargar `output_files/ModoSecuencial.sof`
4. Click en "Start" para programar

**Verificación:** Los LEDs rojos deben parpadear brevemente (power-on reset).

## 🔍 Paso 2: Test Básico de JTAG

### Opción A: Desde System Console

1. Abrir **Tools → System Console** en Quartus
2. En la consola TCL, ejecutar:

```tcl
cd "c:/Users/gabri/OneDrive/Desktop/PrograProyectoArqui/Arqui2-Proyecto/tcl"
source test_basic_jtag.tcl
test_basic_connection
```

### Opción B: Línea por línea

```tcl
# Conectar a JTAG Master
connect_jtag

# Test de LEDs (deben cambiar de patrón)
test_leds

# Leer registros DSA
read_dsa_registers

# Test de memoria de entrada (256 bytes)
test_memory 0x00000000 256

# Test de memoria de salida (256 bytes)
test_memory 0x00040000 256
```

### Salida Esperada:

```
==========================================
Conectando a JTAG Master...
==========================================
Servicios JTAG disponibles:
  [0] /devices/5CSEMA5(.|ES)|5CSEBA5/...
Usando: /devices/5CSEMA5(.|ES)|5CSEBA5/...
Conexión establecida ✓

==========================================
Test de LEDs
==========================================
Escribiendo patrón: 0x000
Escribiendo patrón: 0x3FF
...
LEDs apagados ✓

==========================================
Registros DSA (Base: 0x00500000)
==========================================
CTRL (0x00):          0x00000000
  - start:            0
  - reset_counters:   0
  - mode:             0 (Secuencial)
  - scale_factor_idx: 0 (factor: 0.5)
  - manual_dims:      0
...
```

## 🎯 Paso 3: Test de Downscaling Simple

### Test 4×4 → 2×2 (Secuencial)

```tcl
source test_downscale_simple.tcl
test_downscale_4x4_to_2x2
```

Este test:
1. Escribe una imagen 4×4 con gradiente
2. Configura DSA para downscale a 2×2 (modo Secuencial)
3. Inicia procesamiento
4. Lee resultado
5. Muestra métricas de performance

### Salida Esperada:

```
==========================================
TEST: Downscale 4×4 → 2×2 (Secuencial)
==========================================

Escribiendo imagen de entrada (4×4)...
Imagen escrita ✓ (16 píxeles = 4 words)

Imagen de Entrada (4×4):
┌─────────────────┐
│   0  64 128 192 │
│  32  96 160 224 │
│  64 128 192 255 │
│  96 160 224 255 │
└─────────────────┘

Configurando DSA...
  Entrada:  4×4
  Salida:   2×2
  Modo:     Secuencial
DSA configurado ✓

Iniciando procesamiento...
Start signal enviado ✓

Esperando finalización (timeout: 5000ms)...
Procesamiento completado ✓

Leyendo imagen de salida (2×2)...
Imagen leída ✓ (4 píxeles)

Imagen de Salida (2×2):
┌─────────┐
│  48 176 │
│ 112 232 │
└─────────┘

PERF_CYCLES (0x20):   123
PERF_READS (0x24):    16
PERF_WRITES (0x28):   4
PERF_FLOPS (0x2C):    40
```

### Test 8×8 → 4×4 (SIMD)

```tcl
test_downscale_8x8_to_4x4
```

Este test usa modo SIMD para procesar 4 píxeles en paralelo.

## 🖼️ Paso 4: Generar Imágenes de Prueba

### Generar patrón gradiente 512×512 → 256×256

```bash
cd Python
python test_dsa_downscale.py --generate --pattern gradient --input 512 512 --output 256 256
```

Esto genera:
- `gradient_512x512_to_256x256_input.mif` - Para cargar en BRAM vía Quartus
- `gradient_512x512_to_256x256_input.bin` - Archivo binario
- `gradient_512x512_to_256x256_input.tcl` - Lista TCL de bytes
- `gradient_512x512_to_256x256_reference.npy` - Referencia (para comparación)

### Otros patrones

```bash
# Checkerboard
python test_dsa_downscale.py --generate --pattern checkerboard --input 512 512 --output 256 256

# Círculos concéntricos
python test_dsa_downscale.py --generate --pattern circles --input 512 512 --output 256 256
```

### Visualizar (requiere matplotlib)

```bash
python test_dsa_downscale.py --generate --pattern gradient --input 512 512 --output 256 256 --visualize
```

## 📊 Paso 5: Test Completo con Imagen Grande

### Cargar imagen en BRAM (vía TCL)

```tcl
# Cargar datos desde archivo TCL
source gradient_512x512_to_256x256_input.tcl

# Convertir a formato word de 32 bits
set words {}
set word 0
set byte_idx 0

foreach pixel $image_data {
    set word [expr {$word | (($pixel & 0xFF) << ($byte_idx * 8))}]
    incr byte_idx

    if {$byte_idx == 4} {
        lappend words $word
        set word 0
        set byte_idx 0
    }
}

# Escribir a BRAM
master_write_32 $jtag_master 0x00000000 $words
puts "Imagen cargada en BRAM ✓"
```

### Ejecutar downscaling

```tcl
# Configurar DSA (512×512 → 256×256, modo SIMD)
configure_dsa 512 512 256 256 1

# Iniciar
start_processing

# Esperar (timeout 30 segundos)
wait_for_completion 30000

# Leer performance
read_dsa_registers
```

### Leer resultado

```tcl
# Leer imagen de salida (256×256 = 65536 bytes = 16384 words)
set output_words [master_read_32 $jtag_master 0x00040000 16384]

# Convertir a bytes
set output_pixels {}
foreach word $output_words {
    for {set i 0} {$i < 4} {incr i} {
        set byte [expr {($word >> ($i * 8)) & 0xFF}]
        lappend output_pixels $byte
    }
}

# Guardar a archivo
set fp [open "output_256x256.txt" w]
foreach pixel $output_pixels {
    puts $fp $pixel
}
close $fp

puts "Resultado guardado en output_256x256.txt ✓"
```

## 🔧 Comandos Útiles

### Leer un registro específico

```tcl
# Leer STATUS
set status [read_reg 0x00500000 0x04]
puts "STATUS: 0x[format %08X $status]"
puts "  busy: [expr {($status >> 0) & 0x1}]"
puts "  done: [expr {($status >> 1) & 0x1}]"
```

### Escribir dimensiones manualmente

```tcl
# Entrada: 640×480
write_reg 0x00500000 0x08 640
write_reg 0x00500000 0x0C 480

# Salida: 320×240
write_reg 0x00500000 0x10 320
write_reg 0x00500000 0x14 240

# Habilitar dimensiones manuales (bit 8 = 1)
write_reg 0x00500000 0x00 0x100
```

### Cambiar modo (Secuencial ↔ SIMD)

```tcl
# Modo Secuencial (bit 2 = 0)
write_reg 0x00500000 0x00 0x000

# Modo SIMD (bit 2 = 1)
write_reg 0x00500000 0x00 0x004
```

## 📈 Métricas de Performance Esperadas

### Modo Secuencial (512×512 → 256×256)

- **Ciclos:** ~65,536 (1 píxel/ciclo)
- **Tiempo:** ~1.3 ms @ 50 MHz
- **Reads:** 1,048,576 (4 lecturas por píxel de salida)
- **Writes:** 65,536 (1 escritura por píxel)
- **FLOPs:** 655,360 (10 ops por píxel)

### Modo SIMD (512×512 → 256×256, N=4)

- **Ciclos:** ~16,384 (4 píxeles/ciclo)
- **Tiempo:** ~0.33 ms @ 50 MHz
- **Speedup:** ~4× vs Secuencial
- **Reads:** 1,048,576 (serializados)
- **Writes:** 65,536

## ❗ Troubleshooting

### Error: No se encuentra JTAG Master

**Solución:**
1. Verificar que USB Blaster esté conectado
2. En Device Manager (Windows), verificar driver "Intel FPGA USB-Blaster"
3. Reinstalar drivers: `C:\intelFPGA_lite\20.1\quartus\drivers\usb-blaster-ii`

### Error: Timeout esperando done

**Posibles causas:**
1. DSA no recibió señal start → Verificar bit 0 de CTRL
2. Dimensiones incorrectas → Verificar registros 0x08-0x14
3. Direcciones base incorrectas → Verificar registros 0x18-0x1C

**Diagnóstico:**
```tcl
read_dsa_registers
# Verificar que busy=1 después de start
# Si busy=0, el start no se registró
```

### LEDs no responden

**Solución:**
1. Verificar dirección: `0x00050000`
2. Probar escribir 0x3FF (todos encendidos)
3. Si no funciona, regenerar Qsys y recompilar

## 📝 Notas Importantes

1. **Auto-clear de start:** El bit start se pone automáticamente en 0 después de 1 ciclo. No es necesario limpiarlo manualmente.

2. **Orden de bytes:** El sistema usa little-endian. Byte 0 en bits [7:0], byte 1 en bits [15:8], etc.

3. **Límites de memoria:**
   - Input: 0x00000000 - 0x0003FFFF (256 KB)
   - Output: 0x00040000 - 0x0004FFFF (64 KB)
   - Verificar que la imagen cabe en estos límites

4. **Factor de escala vs dimensiones manuales:**
   - Con scale_factor_idx: Dimensiones de salida se calculan automáticamente
   - Con manual_dims=1: Usar dimensiones escritas en registros 0x10-0x14

## 🎓 Ejemplo Completo

```tcl
# 1. Conectar
source test_basic_jtag.tcl
connect_jtag

# 2. Verificar sistema
test_leds
read_dsa_registers

# 3. Test simple
source test_downscale_simple.tcl
test_downscale_4x4_to_2x2

# 4. Test SIMD
test_downscale_8x8_to_4x4

# 5. Ver performance
read_dsa_registers
```

## 🖼️ Test con Imagen Real (512×512)

Tienes `imagen_grayscale.txt` que es una imagen de 512×512 píxeles en formato texto (valores separados por espacios).

### Cargar y procesar imagen 512×512 → 256×256

```tcl
# Cargar scripts
source test_downscale_512x512.tcl

# Test con modo SIMD (más rápido)
test_512x512_to_256x256_simd

# O con modo Secuencial
test_512x512_to_256x256_seq

# Comparar ambos modos
test_simd_vs_seq
```

### Proceso del test automático:

1. **Carga** `imagen_grayscale.txt` (512×512 = 262,144 píxeles)
2. **Escribe** a BRAM en `0x00000000` (256 KB)
3. **Configura** DSA para 512×512 → 256×256
4. **Inicia** procesamiento
5. **Mide** performance (ciclos, tiempo, throughput)
6. **Lee** resultado de `0x00040000` (64 KB)
7. **Guarda** `imagen_output_256x256_simd.txt` o `imagen_output_256x256_seq.txt`

### Salida esperada:

```
==========================================
TEST: Downscale 512×512 → 256×256 (SIMD)
==========================================
Cargando imagen desde archivo TXT
Archivo: ../imagen_grayscale.txt
Dimensiones: 512×512
Píxeles leídos: 262144
Convirtiendo a formato de 32 bits...
Total: 65536 words (256 KB)
Escribiendo a BRAM...
Progreso: 100% (64/64 bloques)

Imagen cargada exitosamente ✓

Configurando DSA...
  Entrada:  512×512
  Salida:   256×256
  Modo:     SIMD

Procesamiento completado ✓

==========================================
Resultados de Performance
==========================================
PERF_CYCLES:   ~16,384
PERF_READS:    1,048,576
PERF_WRITES:   65,536
PERF_FLOPS:    655,360

Métricas Calculadas:
  Tiempo real:      ~330 ms
  Tiempo (ciclos):  0.33 ms @ 50 MHz
  Throughput:       198.4 MPix/s
  GFLOPS:           1.99

Imagen guardada ✓
  - imagen_output_256x256_simd.txt
```

### Performance esperada:

| Modo | Ciclos | Tiempo @ 50MHz | Speedup |
|------|--------|----------------|---------|
| **Secuencial** | ~65,536 | ~1.3 ms | 1× |
| **SIMD (N=4)** | ~16,384 | ~0.33 ms | 4× |

### Múltiples factores de escala:

```tcl
# Probar diferentes tamaños de salida
test_multiple_scales
```

Esto genera:
- `imagen_output_256x256.txt` (factor 0.5)
- `imagen_output_307x307.txt` (factor 0.6)
- `imagen_output_358x358.txt` (factor 0.7)
- `imagen_output_410x410.txt` (factor 0.8)
- `imagen_output_461x461.txt` (factor 0.9)
- `imagen_output_512x512.txt` (factor 1.0, copia)

### Comandos manuales (paso a paso):

```tcl
# Cargar imagen
source load_image_txt.tcl
connect_jtag
load_image_from_txt "../imagen_grayscale.txt" 512 512

# Verificar que se cargó bien
verify_loaded_image 512 512 16

# Configurar y ejecutar
source test_downscale_simple.tcl
configure_dsa 512 512 256 256 1  ;# SIMD
start_processing
wait_for_completion 30000

# Ver resultados
read_dsa_registers

# Guardar resultado
save_output_image "../resultado.txt" 256 256
```

---

**Autor:** DSA Project Team
**Fecha:** Diciembre 2025
**Versión:** 1.0
