# FASE 5: Downscaling Secuencial con Interpolación Bilinear - Instrucciones Completas

## Resumen
Esta fase implementa el sistema completo de downscaling 64×64 → 32×32 con interpolación bilinear usando aritmética de punto fijo Q8.8. El diseño es **modular, pipelined y sintetizable** para la FPGA Cyclone V (DE1-SoC MTL2).

---

## Características Principales

### Arquitectura
- **Modular**: 4 módulos separados con responsabilidades claras
- **Pipelined**: 3 etapas de pipeline para throughput de 1 píxel/ciclo
- **Secuencial**: Procesa 1 píxel de salida por iteración
- **Sintetizable**: Diseño optimizado para FPGA Cyclone V

### Throughput
- **Latencia inicial**: ~20 ciclos (pipeline + lectura de memoria)
- **Throughput**: 1 píxel de salida/ciclo (después de latencia inicial)
- **Tiempo total**: ~1044 ciclos para procesar imagen completa (32×32)
- **Frecuencia objetivo**: 50 MHz → ~20.88 μs por imagen

---

## Archivos Generados

### RTL (Hardware)

#### 1. `rtl/downscale/fixed_point_mult.sv`
**Propósito**: Multiplicador de punto fijo Q8.8 con pipeline de 2 etapas

**Características**:
- Formato Q8.8 (8 bits enteros, 8 bits fraccionarios)
- Pipeline de 2 etapas para Fmax óptima
- Redondeo al bit más cercano
- Detección de overflow (solo en simulación)

**Señales**:
```systemverilog
input  logic [15:0] a          // Q8.8 multiplicando
input  logic [15:0] b          // Q8.8 multiplicador
output logic [15:0] result     // Q8.8 resultado
```

**Operación**:
```
a * b = resultado
Ejemplo: 2.5 * 1.25 = 3.125
(0x0280) * (0x0140) = (0x0320)
```

#### 2. `rtl/downscale/bilinear_interpolator.sv`
**Propósito**: Unidad de interpolación bilinear con pipeline de 3 etapas

**Características**:
- 6 multiplicadores Q8.8 instanciados
- Pipeline de 3 etapas:
  - Etapa 1: Interpolación horizontal (top y bottom)
  - Etapa 2: Interpolación vertical
  - Etapa 3: Conversión Q8.8 → 8 bits con saturación
- Throughput: 1 interpolación/ciclo (después de latencia)

**Señales**:
```systemverilog
input  logic [7:0]  p00, p01, p10, p11  // 4 píxeles vecinos (2x2)
input  logic [15:0] weight_x, weight_y  // Pesos Q8.8 (dx, dy)
output logic [7:0]  result              // Píxel interpolado
output logic        valid               // Resultado válido
```

**Fórmula implementada**:
```
result = p00*(1-dx)*(1-dy) + p01*dx*(1-dy) + p10*(1-dx)*dy + p11*dx*dy

Donde:
  dx, dy ∈ [0, 1] (pesos de interpolación)
  p00, p01, p10, p11 = píxeles vecinos en configuración 2x2
```

#### 3. `rtl/downscale/downscale_fsm.sv`
**Propósito**: Máquina de estados para control del procesamiento secuencial

**Características**:
- 8 estados: IDLE, CALC_COORDS, READ_PIXELS, WAIT_READ, INTERPOLATE, WAIT_INTERP, WRITE_RESULT, NEXT_PIXEL
- Calculador de direcciones de memoria integrado
- Generación automática de coordenadas y pesos
- Contador de píxeles procesados (0-1023)

**Estados**:
```
IDLE → CALC_COORDS → READ_PIXELS → WAIT_READ →
INTERPOLATE → WAIT_INTERP → WRITE_RESULT → NEXT_PIXEL → ...
```

**Señales principales**:
```systemverilog
input  logic        start              // Iniciar procesamiento
output logic        busy               // Ocupada
output logic        done               // Completado (1024 píxeles)
output logic [4:0]  out_x, out_y      // Coordenadas actuales (0-31)
```

#### 4. `rtl/downscale/downscale_sequential.sv`
**Propósito**: Módulo top que integra todos los componentes

**Características**:
- Integra: FSM + Interpolador + Buffer de píxeles
- Interfaz simple con memorias externas
- Cálculo automático de pesos de interpolación
- Debug y monitoreo en simulación

**Señales**:
```systemverilog
// Control
input  logic        start
output logic        busy
output logic        done

// Interfaz memoria de entrada (64x64)
output logic        mem_in_rd_en
output logic [11:0] mem_in_rd_addr
input  logic [7:0]  mem_in_rd_data

// Interfaz memoria de salida (32x32)
output logic        mem_out_wr_en
output logic [9:0]  mem_out_wr_addr
output logic [7:0]  mem_out_wr_data
```

### Simulación

#### 5. `sim/tb_downscale_sequential.sv`
**Propósito**: Testbench completo con 4 tests diferentes

**Tests implementados**:
1. **Gradiente horizontal**: Verifica interpolación en dirección X
2. **Gradiente vertical**: Verifica interpolación en dirección Y
3. **Tablero de ajedrez**: Patrón complejo para verificar bordes
4. **Patrón constante**: Verifica que interpolación de valores iguales = valor constante

**Patrones de test**:
```systemverilog
Patrón 0: Gradiente horizontal (x * 4)
Patrón 1: Gradiente vertical (y * 4)
Patrón 2: Tablero de ajedrez (alternado 0xFF/0x00)
Patrón 3: Constante (128)
Patrón 4: Aleatorio
```

#### 6. `sim/run_downscale_sim.do`
Script TCL para ModelSim con configuración de waveforms

#### 7. `sim/run_downscale_sim.bat`
Script batch para ejecutar simulación automáticamente

---

## Formato de Punto Fijo Q8.8

### ¿Qué es Q8.8?

Q8.8 es un formato de punto fijo con:
- **8 bits enteros**: Rango [0, 255]
- **8 bits fraccionarios**: Resolución de 1/256 ≈ 0.00390625

### Representación

```
[15:8]  = Parte entera (0-255)
[7:0]   = Parte fraccionaria (0.0-0.99609375)

Ejemplo:
  2.5   = 0x0280 = 0000_0010.1000_0000
  128 en decimal = 512 en Q8.8 = 0x0200
```

### Conversiones

```systemverilog
// Uint8 → Q8.8
q8_value = {uint8_value, 8'd0};

// Q8.8 → Uint8 (con redondeo)
uint8_value = q8_value[15:8] + {7'd0, q8_value[7]};

// Multiplicación Q8.8
// a[15:0] * b[15:0] = result[31:0]
// Tomar bits [23:8] para mantener formato Q8.8
result_q8 = (a * b)[23:8];
```

### ¿Por qué Q8.8?

1. **Precisión suficiente**: 1/256 ≈ 0.4% de error máximo
2. **Rango adecuado**: Píxeles son 0-255
3. **Multiplicación eficiente**: 16×16 → 32 bits
4. **Sintetizable**: Usa multiplicadores DSP de la FPGA

---

## Pipeline de Procesamiento

### Etapas del Pipeline

```
Ciclo N:   Lectura píxeles → Buffer
Ciclo N+1: Inicio interpolación (Etapa 1)
Ciclo N+2: Mult horizontal (Etapa 2)
Ciclo N+3: Mult vertical (Etapa 3)
Ciclo N+4: Escritura resultado
```

### Diagrama de Flujo

```
┌─────────────┐
│ Input Image │ (64×64, BRAM)
│   Memory    │
└──────┬──────┘
       │ Read 4 pixels
       ▼
┌──────────────┐
│ Pixel Buffer │ (4×8 bits)
└──────┬───────┘
       │
       ▼
┌───────────────────┐
│   Bilinear        │  Stage 1: Horizontal interp
│   Interpolator    │  Stage 2: Vertical interp
│   (Q8.8 Pipeline) │  Stage 3: Q8.8 → Uint8
└──────┬────────────┘
       │ 1 pixel/cycle
       ▼
┌──────────────┐
│ Output Image │ (32×32, BRAM)
│   Memory     │
└──────────────┘
```

---

## PASO 1: Simular en ModelSim

### Opción A: Usando el script batch (Recomendado)

```bash
cd C:\Users\josev\OneDrive\Documentos\Arqui2ProyectoInicio\sim
run_downscale_sim.bat
```

### Opción B: Manual desde ModelSim

1. Abre ModelSim
2. File → Change Directory → Navega a `sim/`
3. En la consola TCL:
   ```tcl
   do run_downscale_sim.do
   ```

### Salida Esperada

```
========================================
Testbench: Downscale Sequential (Pipeline)
========================================
Input:  64x64 = 4096 píxeles
Output: 32x32 = 1024 píxeles
Pipeline: 3 etapas
========================================

========================================
TEST 1: Gradiente horizontal
========================================
Inicializando memoria de entrada (64x64)...
Memoria de entrada inicializada con patrón 0

========================================
Iniciando downscaling
========================================
[DOWNSCALE] Procesados 256/1024 píxeles (25.0%)
[DOWNSCALE] Procesados 512/1024 píxeles (50.0%)
[DOWNSCALE] Procesados 768/1024 píxeles (75.0%)
[DOWNSCALE] Completado: 1024 píxeles procesados
[OK] Downscaling completado

========================================
Verificando memoria de salida (32x32)
========================================
[OK] Todos los píxeles fueron escritos
Test 1 completado

... (Tests 2, 3, 4) ...

========================================
Resumen de Tests
========================================
✓ TODOS LOS TESTS PASARON
========================================
```

### Verificar Waveforms

En ModelSim, revisa las señales:
- **FSM state**: Debe recorrer todos los estados correctamente
- **pixel_count**: Debe incrementar de 0 a 1023
- **mem_out_wr_en**: Debe activarse 1024 veces
- **interpolator valid**: Debe aparecer después de latencia

---

## PASO 2: Sintetizar en Quartus

### 2.1 Agregar archivos al proyecto

Edita `Proyecto2Arqui.qsf` y agrega:

```tcl
# FASE 5: Downscaling modules
set_global_assignment -name SYSTEMVERILOG_FILE ../../rtl/downscale/fixed_point_mult.sv
set_global_assignment -name SYSTEMVERILOG_FILE ../../rtl/downscale/bilinear_interpolator.sv
set_global_assignment -name SYSTEMVERILOG_FILE ../../rtl/downscale/downscale_fsm.sv
set_global_assignment -name SYSTEMVERILOG_FILE ../../rtl/downscale/downscale_sequential.sv
```

### 2.2 Modificar top-level para incluir downscaler

Edita `rtl/Proyecto2Arqui.sv` y conecta el downscaler entre las memorias.

### 2.3 Compilar

```
Processing → Start Compilation
```

O presiona **Ctrl + L**

### 2.4 Verificar Recursos

Después de la compilación, revisa:

**Compilation Report → Flow Summary**

Recursos esperados:
```
+--------------------------------+----------+
| Resource                       | Usage    |
+--------------------------------+----------+
| ALMs                           | ~500     |
| Registers                      | ~300     |
| M10K Memory Blocks             | 5        |
| DSP Blocks (multiplicadores)   | 6        |
+--------------------------------+----------+
```

**Notas**:
- Si no usa DSP blocks, verifica que Quartus infiera correctamente los multiplicadores
- Si usa > 1000 ALMs, puede haber problema de síntesis

### 2.5 Timing Analysis

**Tools → TimeQuest Timing Analyzer**

Verifica:
- **Fmax reportado**: Debe ser > 50 MHz
- **Setup Slack**: Debe ser positivo
- **Hold Slack**: Debe ser positivo

Si Fmax < 50 MHz:
- Revisa critical path en TimeQuest
- Considera agregar etapas de pipeline adicionales
- Optimiza multiplicadores

---

## Análisis de Recursos

### Multiplicadores (DSP Blocks)

El diseño usa **6 multiplicadores** 16×16:
- 4 para interpolación horizontal (p00, p01, p10, p11)
- 2 para interpolación vertical (top, bottom)

Cada multiplicador puede usar:
- **Opción 1**: DSP block dedicado (eficiente, rápido)
- **Opción 2**: LUTs (menos eficiente, más lento)

Quartus preferirá DSP blocks si están disponibles.

### Memoria

- **Input memory**: 4 bloques M10K (32 KB)
- **Output memory**: 1 bloque M10K (8 KB)
- **Total**: 5 bloques M10K

### Lógica

- **FSM**: ~50 ALMs
- **Address calculator**: ~100 ALMs
- **Interpolator control**: ~100 ALMs
- **Buffers y registros**: ~250 ALMs

---

## Optimizaciones Posibles

### 1. Aumentar throughput (procesamiento paralelo)

Actualmente: 1 píxel/ciclo
Posible: 2 o 4 píxeles/ciclo

Requiere:
- Duplicar o cuadruplicar interpoladores
- Más puertos de memoria (dual-port → quad-port)
- Más recursos (DSP, ALMs)

### 2. Reducir latencia

Actualmente: ~20 ciclos de latencia inicial
Posible: ~10 ciclos

Requiere:
- Reducir etapas de pipeline (trade-off con Fmax)
- Optimizar FSM (menos estados)

### 3. Optimizar para área

Actualmente: ~500 ALMs, 6 DSP
Posible: ~300 ALMs, 0 DSP (time-shared mult)

Requiere:
- Compartir multiplicadores (time-multiplexing)
- Mayor latencia por píxel
- FSM más compleja

---

## Solución de Problemas

### Problema: Simulación falla con "X" en outputs

**Posibles causas**:
- Reset no aplicado correctamente
- Latencia de pipeline no considerada
- Memoria no inicializada

**Solución**:
- Verifica que `rst_n` se active correctamente
- Espera suficientes ciclos después de `start`
- Inicializa memoria de entrada en testbench

### Problema: Resultados incorrectos en interpolación

**Posibles causas**:
- Pesos de interpolación incorrectos
- Overflow en multiplicación Q8.8
- Redondeo incorrecto

**Solución**:
- Verifica cálculo de `weight_x` y `weight_y`
- Revisa waveforms de multiplicadores
- Checa conversión Q8.8 → Uint8

### Problema: Fmax < 50 MHz en síntesis

**Posibles causas**:
- Critical path en multiplicadores
- Lógica combinacional compleja
- Routing delays

**Solución**:
- Agrega más etapas de pipeline
- Simplifica cálculo de direcciones
- Usa timing constraints en Quartus

### Problema: Quartus no infiere DSP blocks

**Posibles causas**:
- Multiplicación no sintetizable
- Pipeline no reconocido
- Tamaño de operandos no soportado

**Solución**:
- Usa `always_ff` para registros
- Verifica que multiplicación sea `a * b` directo
- Consulta Quartus synthesis report

---

## Próximos Pasos

Una vez verificado el downscaler:

1. **FASE 6**: Integrar con interfaz JTAG
2. Cargar imágenes reales vía JTAG
3. Leer resultados procesados
4. Probar el sistema end-to-end en hardware

---

## Referencias

- **Intel Cyclone V Handbook**: DSP Blocks
  - https://www.intel.com/content/www/us/en/docs/programmable/683385/current/dsp-blocks.html

- **Bilinear Interpolation**:
  - https://en.wikipedia.org/wiki/Bilinear_interpolation

- **Fixed-Point Arithmetic**:
  - https://en.wikipedia.org/wiki/Fixed-point_arithmetic

- **Pipelining in FPGAs**:
  - https://www.intel.com/content/www/us/en/docs/programmable/683082/current/pipelining-for-performance.html
