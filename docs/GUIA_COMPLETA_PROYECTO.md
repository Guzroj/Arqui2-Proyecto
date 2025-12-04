# GUÍA COMPLETA: PROYECTO DOWNSCALING CON INTERPOLACIÓN BILINEAL EN FPGA

**Proyecto**: CE-4302 Arquitectura de Computadores II - Proyecto 02
**Objetivo**: Implementar DSA para downscaling de imágenes con interpolación bilineal
**Estrategia**: Desarrollo incremental desde cero con validación en cada fase
**Directorio de trabajo**: `C:\Users\josev\OneDrive\Documentos\Arqui2ProyectoInicio`

---

## 📐 ESTRATEGIA GENERAL DEL PROYECTO

### Progresión Incremental:
1. **Fase inicial**: Imágenes pequeñas (64×64 → 32×32) - 4 KB memoria
2. **Fase intermedia**: Imágenes medianas (128×128 → 64×64) - 16 KB memoria
3. **Fase final**: Imágenes completas (512×512 → 256×256) - 262 KB memoria

### Orden de Implementación:
1. ✅ Modelos de referencia (Python + C++)
2. ✅ Comunicación JTAG básica (test con LEDs)
3. ✅ Modo Secuencial completo (1 píxel/ciclo)
4. ✅ Validación bit-a-bit con modelo de referencia
5. ✅ Modo SIMD (4 píxeles/ciclo)
6. ✅ Performance counters y optimización
7. ✅ Documentación y pruebas finales

---

## 📋 TABLA DE CONTENIDOS

- [FASE 0: Setup y Preparación](#fase-0-setup-y-preparación)
- [FASE 1: Modelo de Referencia Python](#fase-1-modelo-de-referencia-python)
- [FASE 2: Modelo de Referencia C++](#fase-2-modelo-de-referencia-c)
- [FASE 3: Test de JTAG con LEDs](#fase-3-test-de-jtag-con-leds)
- [FASE 4: Memoria de Imagen](#fase-4-memoria-de-imagen)
- [FASE 5: Interpolación Secuencial en Hardware](#fase-5-interpolación-secuencial-en-hardware)
- [FASE 6: Integración JTAG + Downscaling](#fase-6-integración-jtag--downscaling)
- [FASE 7: Validación Hardware vs Modelo](#fase-7-validación-hardware-vs-modelo)
- [FASE 8: Modo SIMD Paralelo](#fase-8-modo-simd-paralelo)
- [FASE 9: Performance Counters](#fase-9-performance-counters)
- [FASE 10: Escalamiento a 512×512](#fase-10-escalamiento-a-512512)
- [FASE 11: Documentación Final](#fase-11-documentación-final)

---

## FASE 0: Setup y Preparación

**⏱ Tiempo estimado**: 30 minutos
**📍 Objetivo**: Configurar el entorno de desarrollo y estructura de carpetas

### Tareas:

#### 0.1 Verificar estructura de carpetas
**Ubicación**: `C:\Users\josev\OneDrive\Documentos\Arqui2ProyectoInicio`

```
Arqui2ProyectoInicio/
├── rtl/                          # Código SystemVerilog
│   ├── top/                      # Módulos top-level
│   ├── jtag/                     # Interfaz JTAG
│   ├── downscale/                # Lógica de interpolación
│   ├── memory/                   # Controladores de memoria
│   └── common/                   # Módulos compartidos
├── tb/                           # Testbenches
│   ├── unit/                     # Pruebas unitarias
│   └── integration/              # Pruebas de integración
├── software/                     # Software de soporte
│   ├── reference_model/          # Modelo C++
│   │   ├── src/
│   │   ├── include/
│   │   └── Makefile
│   ├── python/                   # Scripts Python
│   │   ├── reference/            # Modelo Python
│   │   ├── utils/                # Utilidades
│   │   └── test_images/          # Imágenes de prueba
│   └── tcl/                      # Scripts TCL para JTAG
│       ├── server/               # Servidor JTAG
│       └── client/               # Cliente de pruebas
├── quartus/                      # Proyecto Quartus
│   └── downscale_project/        # Proyecto principal
├── docs/                         # Documentación
│   ├── GUIA_COMPLETA_PROYECTO.md # Esta guía
│   ├── architecture/             # Diagramas de arquitectura
│   ├── validation_plan/          # Plan de verificación
│   └── progress/                 # Bitácora de avances
└── validation/                   # Resultados de validación
    ├── simulation/               # Resultados de ModelSim
    ├── hardware/                 # Resultados en FPGA
    └── comparisons/              # Comparaciones ref vs hw
```

#### 0.2 Verificar herramientas instaladas
- Quartus Prime Lite 20.1
- ModelSim (incluido con Quartus)
- Python 3.x con numpy, matplotlib, PIL
- Compilador C++ (MinGW/GCC)
- Editor de texto / IDE

#### 0.3 Copiar ejemplo de referencia JTAG
**Fuente**: `C:\Users\josev\Downloads\vJTAG_DE0-Nano_Example\vJTAG_DE0-Nano_Example_restored`
**Destino**: `software/tcl/reference_example/`

Archivos clave a estudiar:
- `vJTAG_interface.v` - Interfaz JTAG básica
- `TCL_Server_vJTAG_SimpleTest.tcl` - Servidor TCP/IP
- `LED_Counter.py` - Cliente Python

### ✅ Checkpoint FASE 0:
- [ ] Estructura de carpetas creada
- [ ] Quartus 20.1 funcional
- [ ] ModelSim funcional
- [ ] Python con librerías instaladas
- [ ] Compilador C++ funcional
- [ ] Ejemplo JTAG copiado y revisado

---

## FASE 1: Modelo de Referencia Python

**⏱ Tiempo estimado**: 1 hora
**📍 Objetivo**: Crear modelo de referencia en Python para validar el algoritmo

### Contexto:
El modelo de referencia es CRÍTICO porque:
1. Valida que el algoritmo de interpolación bilineal es correcto
2. Genera imágenes de referencia para comparar con hardware
3. Permite experimentar con diferentes tamaños y factores de escala
4. Sirve como "golden reference" para todas las validaciones

### Tareas:

#### 1.1 Implementar aritmética de punto fijo Q8.8
**Archivo**: `software/python/reference/fixed_point.py`

Debe incluir:
- Clase `Q8_8` para representar números en formato de punto fijo
- Conversión float ↔ Q8.8
- Operaciones: multiplicación, suma
- Validación de rango (0-255 para píxeles)

#### 1.2 Implementar interpolación bilineal
**Archivo**: `software/python/reference/bilinear_interpolation.py`

Debe incluir:
- Función `bilinear_interpolate_pixel(p00, p01, p10, p11, fx, fy)`
- Usar aritmética Q8.8 (no float nativo)
- Retornar uint8 (0-255)

#### 1.3 Implementar downscaling completo
**Archivo**: `software/python/reference/downscale.py`

Debe incluir:
- Función `downscale_image(src_img, src_w, src_h, dst_w, dst_h)`
- Calcular ratios (x_ratio, y_ratio)
- Para cada píxel de salida:
  - Calcular posición en imagen origen
  - Obtener 4 píxeles vecinos
  - Interpolar usando Q8.8
- Retornar imagen de salida

#### 1.4 Crear script de prueba
**Archivo**: `software/python/reference/test_downscale.py`

Debe:
- Generar imágenes de prueba:
  - Imagen uniforme (todos píxeles = 128)
  - Gradiente horizontal (0 → 255)
  - Gradiente vertical (0 → 255)
  - Patrón de tablero de ajedrez
- Aplicar downscaling 64×64 → 32×32
- Guardar imágenes resultantes en `software/python/test_images/`
- Validar propiedades esperadas

#### 1.5 Generar imagen de prueba real
**Archivo**: `software/python/utils/create_test_image.py`

Debe:
- Cargar/generar imagen 64×64 en escala de grises
- Guardar en formato:
  - `.png` (visualización)
  - `.txt` (valores 0-255, un píxel por línea)
  - `.hex` (formato para carga en memoria FPGA)

### 📊 Salidas esperadas:
```
software/python/test_images/
├── test_uniform_64x64.png          # Imagen uniforme
├── test_uniform_64x64.txt
├── test_uniform_32x32_ref.png      # Resultado esperado
├── test_uniform_32x32_ref.txt
├── test_gradient_h_64x64.png       # Gradiente horizontal
├── test_gradient_h_32x32_ref.png
├── test_gradient_v_64x64.png       # Gradiente vertical
├── test_gradient_v_32x32_ref.png
└── test_checker_64x64.png          # Tablero ajedrez
```

### ✅ Checkpoint FASE 1:
- [ ] Aritmética Q8.8 implementada y probada
- [ ] Interpolación bilineal funciona correctamente
- [ ] Downscaling genera imágenes coherentes
- [ ] Imágenes de prueba generadas
- [ ] Valores validados manualmente para casos simples
- [ ] Scripts documentados con comentarios

### 🎯 Prompt para Claude:
```
"Estoy en la FASE 1 de mi proyecto. Necesito que generes el código Python completo
para implementar el modelo de referencia de interpolación bilineal usando aritmética
de punto fijo Q8.8. Incluye los archivos:
- fixed_point.py
- bilinear_interpolation.py
- downscale.py
- test_downscale.py
- create_test_image.py

Usa la estructura de carpetas definida en la guía."
```

---

## FASE 2: Modelo de Referencia C++

**⏱ Tiempo estimado**: 2 horas
**📍 Objetivo**: Crear modelo de referencia en C++ (requisito obligatorio del proyecto)

### Contexto:
El modelo C++ es OBLIGATORIO según la especificación del proyecto. Debe:
- Usar el MISMO formato Q8.8 que Python
- Dar resultados BIT A BIT idénticos al modelo Python
- Ser la referencia final para validar hardware

### Tareas:

#### 2.1 Configurar estructura C++
**Ubicación**: `software/reference_model/`

Estructura:
```
reference_model/
├── include/
│   ├── fixed_point.h        # Clase/tipo Q8.8
│   ├── bilinear.h           # Interpolación
│   └── image.h              # Manejo de imágenes
├── src/
│   ├── fixed_point.cpp
│   ├── bilinear.cpp
│   ├── image.cpp
│   └── main.cpp             # Programa principal
├── test/
│   ├── test_fixed_point.cpp
│   └── test_bilinear.cpp
├── Makefile                 # Para compilar
└── README.md                # Instrucciones de uso
```

#### 2.2 Implementar aritmética Q8.8 en C++
**Archivos**: `include/fixed_point.h`, `src/fixed_point.cpp`

Debe incluir:
- Tipo `fixed_t` (typedef int16_t)
- Funciones:
  - `float_to_fixed(float)`
  - `fixed_to_float(fixed_t)`
  - `fixed_mul(fixed_t, fixed_t)` - Multiplicación con shift
  - `fixed_add(fixed_t, fixed_t)`

#### 2.3 Implementar interpolación bilineal
**Archivos**: `include/bilinear.h`, `src/bilinear.cpp`

Debe incluir:
- `uint8_t bilinear_interpolate(uint8_t p00, p01, p10, p11, fixed_t fx, fy)`
- Usar SOLO aritmética Q8.8
- Sin usar float en los cálculos

#### 2.4 Implementar manejo de imágenes
**Archivos**: `include/image.h`, `src/image.cpp`

Debe incluir:
- Clase `Image` con:
  - `std::vector<std::vector<uint8_t>> data`
  - `int width, height`
  - `load_from_txt(filename)`
  - `save_to_txt(filename)`
  - `load_from_hex(filename)`
  - `save_to_hex(filename)`

#### 2.5 Implementar programa principal
**Archivo**: `src/main.cpp`

Debe:
- Aceptar argumentos de línea de comandos:
  ```bash
  ./downscale input.txt output.txt src_w src_h dst_w dst_h
  ```
- Cargar imagen de entrada
- Aplicar downscaling con interpolación bilineal
- Guardar imagen de salida
- Reportar estadísticas (tiempo, píxeles procesados, etc.)

#### 2.6 Crear Makefile
**Archivo**: `Makefile`

Debe soportar:
```bash
make            # Compilar todo
make test       # Compilar y ejecutar tests
make clean      # Limpiar binarios
make run        # Ejecutar con imagen de prueba
```

#### 2.7 Validación cruzada Python ↔ C++
**Archivo**: `software/python/utils/validate_cpp_model.py`

Debe:
- Ejecutar modelo Python
- Ejecutar modelo C++
- Comparar resultados píxel por píxel
- Reportar diferencias (debe ser 0%)

### ✅ Checkpoint FASE 2:
- [ ] Código C++ compila sin errores ni warnings
- [ ] Tests unitarios pasan
- [ ] Modelo C++ produce resultados idénticos a Python (bit a bit)
- [ ] Programa acepta argumentos y procesa imágenes
- [ ] Makefile funciona correctamente
- [ ] Validación cruzada muestra 100% match

### 🎯 Prompt para Claude:
```
"Estoy en la FASE 2. Necesito el modelo de referencia en C++ con aritmética Q8.8
que sea BIT A BIT idéntico al modelo Python de la FASE 1. Genera:
- fixed_point.h/cpp
- bilinear.h/cpp
- image.h/cpp
- main.cpp
- Makefile
- Script de validación cruzada Python-C++

El modelo debe procesar imágenes 64×64 → 32×32 y dar resultados idénticos al Python."
```

---

## FASE 3: Test de JTAG con LEDs

**⏱ Tiempo estimado**: 1 hora
**📍 Objetivo**: Validar comunicación JTAG antes de integrar el downscaling

### Contexto:
Antes de intentar cargar imágenes, debemos PROBAR que la comunicación JTAG funciona.
Usaremos el ejemplo simple de LEDs para validar:
- Virtual JTAG se instancia correctamente
- Servidor TCL se conecta a la FPGA
- Podemos escribir datos desde PC → FPGA
- Podemos leer datos desde FPGA → PC (opcional en esta fase)

### Tareas:

#### 3.1 Crear diseño Verilog simple con LEDs
**Archivo**: `rtl/top/test_jtag_leds.sv`

Debe incluir:
- Instancia de `sld_virtual_jtag` (IP Core de Intel)
- Módulo `jtag_led_interface` (adaptado del ejemplo)
- Conexión a LEDs de la DE1-SoC (LEDR[7:0])

Estructura:
```
test_jtag_leds
├── sld_virtual_jtag (IP Core)
├── jtag_led_interface (custom)
└── LEDR[7:0] (salida)
```

#### 3.2 Implementar interfaz JTAG-LED
**Archivo**: `rtl/jtag/jtag_led_interface.sv`

Basado en `vJTAG_interface.v` del ejemplo, debe:
- Tener 1-bit IR (instruction register):
  - IR=0: Bypass
  - IR=1: Cargar LEDs
- Tener 8-bit DR (data register) para los LEDs
- Desplazar datos serialmente (TDI → DR → TDO)
- Actualizar LEDs en estado UDR (Update DR)

#### 3.3 Crear proyecto Quartus
**Ubicación**: `quartus/test_jtag_leds/`

Configuración:
- Device: 5CSEMA5F31C6 (Cyclone V en DE1-SoC MTL2)
- Top-level: `test_jtag_leds.sv`
- Pin assignments:
  - `clk` → CLOCK_50 (PIN_AF14)
  - `rst` → KEY[0] (PIN_AA14)
  - `LEDR[0]` → PIN_V16
  - `LEDR[1]` → PIN_W16
  - ... (ver manual DE1-SoC)

#### 3.4 Compilar y programar FPGA
Pasos:
1. Compilar diseño en Quartus
2. Programar FPGA con `.sof` generado
3. Verificar que no hay errores de síntesis

#### 3.5 Crear servidor TCL
**Archivo**: `software/tcl/server/jtag_server_leds.tcl`

Basado en `TCL_Server_vJTAG_SimpleTest.tcl`, debe:
- Detectar USB-Blaster
- Detectar dispositivo JTAG
- Abrir puerto TCP/IP en 2540
- Recibir comandos y escribir a Virtual JTAG

Funciones clave:
```tcl
proc set_leds {value}      # Escribir valor 0-255 a LEDs
proc get_device {}         # Detectar FPGA
proc start_server {port}   # Iniciar servidor TCP/IP
```

#### 3.6 Crear cliente de prueba Python
**Archivo**: `software/python/utils/test_jtag_leds.py`

Debe:
- Conectar a `localhost:2540`
- Enviar secuencia de prueba:
  - Contar de 0 a 255
  - Patrón alternante (0xAA, 0x55)
  - LEDs individuales (0x01, 0x02, 0x04, ...)
- Pausar entre comandos para observar visualmente

#### 3.7 Ejecutar prueba completa

Procedimiento:
1. Programar FPGA con `test_jtag_leds.sof`
2. Ejecutar servidor TCL:
   ```bash
   quartus_stp -t jtag_server_leds.tcl
   ```
3. En otra terminal, ejecutar cliente:
   ```bash
   python test_jtag_leds.py
   ```
4. Observar LEDs cambiando en la placa

### ✅ Checkpoint FASE 3:
- [ ] Diseño Verilog compila sin errores
- [ ] FPGA programada correctamente
- [ ] Servidor TCL detecta hardware y dispositivo
- [ ] Cliente Python se conecta al servidor
- [ ] LEDs cambian según comandos enviados
- [ ] Sin errores de comunicación JTAG
- [ ] Latencia aceptable (< 1 segundo por comando)

### 🎯 Prompt para Claude:
```
"Estoy en la FASE 3. Necesito crear un test simple de JTAG controlando LEDs
en la DE1-SoC antes de integrar el downscaling. Genera:
- test_jtag_leds.sv (top-level)
- jtag_led_interface.sv (manejo de JTAG)
- jtag_server_leds.tcl (servidor TCP/IP)
- test_jtag_leds.py (cliente de prueba)
- Pin assignments para DE1-SoC MTL2

Usa Virtual JTAG con 1-bit IR y 8-bit DR para 8 LEDs."
```

---

## FASE 4: Memoria de Imagen

**⏱ Tiempo estimado**: 2 horas
**📍 Objetivo**: Implementar y validar memoria para almacenar imágenes

### Contexto:
Necesitamos memoria para:
1. **Imagen de entrada**: 64×64 = 4,096 bytes
2. **Imagen de salida**: 32×32 = 1,024 bytes
**Total**: ~5 KB (cabe fácilmente en BRAM/M10K)

### Tareas:

#### 4.1 Diseñar módulo de memoria de entrada
**Archivo**: `rtl/memory/image_memory_input.sv`

Especificación:
- Tipo: Simple Dual-Port RAM (1 puerto escritura, 1 puerto lectura)
- Tamaño: Parametrizable (default 64×64 = 4096 bytes)
- Ancho de dato: 8 bits (1 píxel)
- Puerto A (escritura desde JTAG):
  - `wr_clk` - Clock de escritura
  - `wr_en` - Enable de escritura
  - `wr_addr[11:0]` - Dirección (0-4095)
  - `wr_data[7:0]` - Dato
- Puerto B (lectura para downscaling):
  - `rd_clk` - Clock de lectura
  - `rd_addr[11:0]` - Dirección
  - `rd_data[7:0]` - Dato (salida registrada)

Implementación:
- Usar inferencia de BRAM (Quartus debe sintetizar como M10K)
- Dual-clock para separar dominio JTAG de dominio procesamiento

#### 4.2 Diseñar módulo de memoria de salida
**Archivo**: `rtl/memory/image_memory_output.sv`

Especificación:
- Tipo: Simple Dual-Port RAM
- Tamaño: Parametrizable (default 32×32 = 1024 bytes)
- Puerto A (escritura desde downscaling):
  - `wr_clk`, `wr_en`, `wr_addr[9:0]`, `wr_data[7:0]`
- Puerto B (lectura hacia JTAG):
  - `rd_clk`, `rd_addr[9:0]`, `rd_data[7:0]`

#### 4.3 Crear testbench de memoria
**Archivo**: `tb/unit/tb_image_memory.sv`

Debe probar:
1. **Test de escritura-lectura básico**:
   - Escribir secuencia 0-255
   - Leer y verificar
2. **Test de patrón aleatorio**:
   - Escribir 1000 valores aleatorios
   - Verificar lectura correcta
3. **Test de concurrencia**:
   - Escribir en puerto A mientras lee puerto B
   - Verificar no hay conflictos
4. **Test de direccionamiento**:
   - Probar todas las direcciones
   - Verificar no hay aliasing

#### 4.4 Simular en ModelSim

Comandos:
```bash
cd tb/unit
vlib work
vlog ../../rtl/memory/image_memory_input.sv tb_image_memory.sv
vsim -c tb_image_memory -do "run -all; quit"
```

Verificar:
- No hay errores de compilación
- Todos los tests pasan
- Waveforms se ven correctos

#### 4.5 Sintetizar módulo de memoria

Crear proyecto Quartus temporal:
- Solo incluir `image_memory_input.sv`
- Sintetizar para Cyclone V
- Verificar en Compilation Report:
  - Usa M10K blocks (no logic cells)
  - Usa cantidad esperada (~1 M10K por cada 10 KB)

### ✅ Checkpoint FASE 4:
- [ ] Módulo de memoria implementado
- [ ] Testbench compila y corre
- [ ] Todos los tests pasan en simulación
- [ ] Síntesis usa bloques BRAM (M10K)
- [ ] Sin warnings críticos de síntesis
- [ ] Timing constraints se cumplen (si aplicable)

### 🎯 Prompt para Claude:
```
"Estoy en la FASE 4. Necesito módulos de memoria parametrizables para almacenar
las imágenes de entrada (64×64) y salida (32×32). Genera:
- image_memory_input.sv (dual-port RAM para entrada)
- image_memory_output.sv (dual-port RAM para salida)
- tb_image_memory.sv (testbench con múltiples tests)
- Instrucciones para simular en ModelSim y sintetizar

Usa inferencia de BRAM para que Quartus use bloques M10K."
```

---

## FASE 5: Interpolación Secuencial en Hardware

**⏱ Tiempo estimado**: 3 horas
**📍 Objetivo**: Implementar la lógica de interpolación bilineal en SystemVerilog

### Contexto:
Esta es la FASE MÁS CRÍTICA del proyecto. Aquí implementamos el algoritmo de interpolación
bilineal en hardware usando aritmética de punto fijo Q8.8.

Modo secuencial: procesa 1 píxel de salida por vez.

### Tareas:

#### 5.1 Implementar unidad aritmética Q8.8
**Archivo**: `rtl/common/fixed_point_mult.sv`

Debe implementar:
- Multiplicación Q8.8 × Q8.8 → Q8.8
- Entrada: dos números de 16 bits (8 enteros + 8 fraccionarios)
- Salida: 16 bits (con shift apropiado)

Lógica:
```
result[31:0] = a[15:0] * b[15:0]  // 32-bit resultado
output[15:0] = result[23:8]       // Extraer Q8.8 con shift >>8
```

Consideraciones:
- Debe ser sintetizable (usar bloques DSP de Cyclone V)
- Pipeline opcional para mejorar frecuencia
- Manejar saturación (clamp a 0-255 después de conversión)

#### 5.2 Implementar unidad de interpolación
**Archivo**: `rtl/downscale/bilinear_interpolator.sv`

Entradas:
- `p00, p01, p10, p11` [7:0] - Los 4 píxeles vecinos
- `fx, fy` [15:0] - Pesos en formato Q8.8

Salida:
- `pixel_out` [7:0] - Píxel interpolado

Lógica:
```
w00 = (1-fx) * (1-fy)
w01 = fx * (1-fy)
w10 = (1-fx) * fy
w11 = fx * fy

result = p00*w00 + p01*w01 + p10*w10 + p11*w11
pixel_out = result >> 8  // Convertir Q16.8 a uint8
```

Pipeline sugerido (3 etapas):
1. Calcular pesos (4 multiplicaciones)
2. Calcular productos ponderados (4 multiplicaciones)
3. Sumar y convertir a uint8

#### 5.3 Implementar máquina de estados (FSM)
**Archivo**: `rtl/downscale/downscale_fsm.sv`

Estados:
```
IDLE       → Esperando señal start
CALC_POS   → Calcular posición en imagen origen (x_src, y_src)
FETCH_P00  → Leer p00 de memoria
FETCH_P01  → Leer p01 de memoria
FETCH_P10  → Leer p10 de memoria
FETCH_P11  → Leer p11 de memoria
INTERPOLATE→ Ejecutar interpolación (puede tomar N ciclos si pipelined)
WRITE_OUT  → Escribir resultado a memoria de salida
NEXT_PIXEL → Incrementar contador, decidir si continuar o terminar
DONE       → Señal done=1, volver a IDLE
```

Contadores:
- `x_dst_counter` - Posición X en imagen de salida (0-31)
- `y_dst_counter` - Posición Y en imagen de salida (0-31)
- `pixel_counter` - Total de píxeles procesados (0-1023)

Cálculos:
```
x_src = x_dst * x_ratio  // x_ratio = 64/32 = 2.0 en Q8.8
y_src = y_dst * y_ratio  // y_ratio = 64/32 = 2.0 en Q8.8

x0 = floor(x_src)
y0 = floor(y_src)
x1 = x0 + 1
y1 = y0 + 1

addr_p00 = y0 * IMG_W + x0
addr_p01 = y0 * IMG_W + x1
addr_p10 = y1 * IMG_W + x0
addr_p11 = y1 * IMG_W + x1

fx = x_src - x0  // Parte fraccionaria
fy = y_src - y0
```

#### 5.4 Integrar módulo completo de downscaling secuencial
**Archivo**: `rtl/downscale/downscale_sequential.sv`

Estructura:
```
downscale_sequential
├── FSM (control)
├── Calculador de direcciones
├── Interfaz a memoria de entrada (read-only)
├── Interfaz a memoria de salida (write-only)
├── bilinear_interpolator
└── Performance counter
```

Puertos:
```systemverilog
module downscale_sequential #(
    parameter SRC_W = 64,
    parameter SRC_H = 64,
    parameter DST_W = 32,
    parameter DST_H = 32
)(
    input  logic        clk,
    input  logic        rst,

    // Control
    input  logic        start,
    output logic        done,
    output logic        busy,

    // Memoria de entrada (read)
    output logic [15:0] src_addr,
    input  logic [7:0]  src_data,

    // Memoria de salida (write)
    output logic [15:0] dst_addr,
    output logic [7:0]  dst_data,
    output logic        dst_we,

    // Performance counter
    output logic [31:0] cycle_count
);
```

#### 5.5 Crear testbench del módulo completo
**Archivo**: `tb/unit/tb_downscale_sequential.sv`

Debe:
1. Instanciar `downscale_sequential`
2. Instanciar memoria de entrada pre-cargada con imagen de prueba
3. Instanciar memoria de salida
4. Secuencia de prueba:
   - Reset
   - Cargar imagen de entrada (desde archivo .hex)
   - Pulso start
   - Esperar done
   - Leer memoria de salida
   - Guardar a archivo para comparación
5. Comparar con modelo de referencia

Casos de prueba:
- Test 1: Imagen uniforme (128, 128, 128, ...)
- Test 2: Gradiente horizontal
- Test 3: Imagen aleatoria pequeña

#### 5.6 Simular en ModelSim

Generar waveforms para debuggear:
- Estados de la FSM
- Direcciones de memoria
- Píxeles leídos (p00, p01, p10, p11)
- Píxel interpolado
- Contador de ciclos

### ✅ Checkpoint FASE 5:
- [ ] Módulo de multiplicación Q8.8 implementado
- [ ] Interpolador bilinear funciona en simulación
- [ ] FSM transiciona correctamente entre estados
- [ ] Módulo completo procesa imagen 64×64 → 32×32
- [ ] Resultados de simulación coinciden con modelo Python/C++ (tolerancia: ±1 por redondeo)
- [ ] Performance counter reporta ciclos correctamente
- [ ] Sin warnings críticos de síntesis

### 🎯 Prompt para Claude:
```
"Estoy en la FASE 5. Necesito implementar la interpolación bilineal en hardware
con aritmética Q8.8. Genera:
- fixed_point_mult.sv (multiplicador Q8.8)
- bilinear_interpolator.sv (unidad de interpolación)
- downscale_fsm.sv (máquina de estados)
- downscale_sequential.sv (módulo top integrado)
- tb_downscale_sequential.sv (testbench)

Debe procesar imágenes 64×64 → 32×32 en modo secuencial (1 píxel/ciclo).
Incluye calculador de direcciones y manejo de memoria."
```

---

## FASE 6: Integración JTAG + Downscaling

**⏱ Tiempo estimado**: 2 horas
**📍 Objetivo**: Conectar el downscaling con la interfaz JTAG para controlarlo desde PC

### Contexto:
Ahora integramos TODO:
- Comunicación JTAG (probada en FASE 3)
- Memoria de imágenes (probada en FASE 4)
- Downscaling secuencial (probado en FASE 5)

### Tareas:

#### 6.1 Diseñar mapa de registros JTAG
**Archivo**: `rtl/jtag/jtag_register_map.sv`

Registros (direcciones de 8 bits):
```
0x00: REG_CONTROL
      [0] - START    (write: iniciar procesamiento)
      [1] - RESET    (write: reset del sistema)
      [2] - MODE     (0=secuencial, 1=SIMD - para FASE 8)
      [7:3] - Reserved

0x01: REG_STATUS (read-only)
      [0] - DONE     (procesamiento terminado)
      [1] - BUSY     (procesamiento en curso)
      [7:2] - Reserved

0x02: REG_IMG_WIDTH
      [15:0] - Ancho de imagen de entrada (default 64)

0x03: REG_IMG_HEIGHT
      [15:0] - Alto de imagen de entrada (default 64)

0x04: REG_DST_WIDTH
      [15:0] - Ancho de imagen de salida (default 32)

0x05: REG_DST_HEIGHT
      [15:0] - Alto de imagen de salida (default 32)

0x06: REG_PERF_CYCLES
      [31:0] - Contador de ciclos (read-only)

0x10: REG_MEM_ADDR
      [15:0] - Dirección de memoria para lectura/escritura

0x11: REG_MEM_DATA_WR
      [7:0] - Dato a escribir en memoria

0x12: REG_MEM_DATA_RD (read-only)
      [7:0] - Dato leído de memoria

0x13: REG_MEM_CONTROL
      [0] - WR_EN     (write: escribir a memoria de entrada)
      [1] - RD_EN     (write: leer de memoria de salida)
      [2] - MEM_SEL   (0=input mem, 1=output mem)
```

#### 6.2 Implementar controlador JTAG Avalon-MM
**Archivo**: `rtl/jtag/jtag_avalon_controller.sv`

Similar a `connect.sv` del ejemplo, pero con:
- Interfaz Avalon-MM hacia registros
- 8-bit address bus
- 32-bit data bus
- Señales: `avs_read`, `avs_write`, `avs_address`, `avs_writedata`, `avs_readdata`

#### 6.3 Crear módulo top-level integrado
**Archivo**: `rtl/top/top_downscale_system.sv`

Jerarquía:
```
top_downscale_system
├── sld_virtual_jtag (IP Core)
├── jtag_avalon_controller
├── jtag_register_map
├── image_memory_input
├── image_memory_output
├── downscale_sequential
└── performance_counter
```

Señales de interconexión:
- JTAG signals: tck, tdi, tdo, ir_in, v_sdr, udr
- Avalon-MM bus
- Memoria input: addr, data, we
- Memoria output: addr, data, we
- Control: start, done, busy

#### 6.4 Crear proyecto Quartus completo
**Ubicación**: `quartus/downscale_project/`

Configuración:
- Device: 5CSEMA5F31C6
- Top-level: `top_downscale_system.sv`
- Archivos:
  - Todos los `.sv` necesarios
  - IP Core: Virtual JTAG
- Pin assignments:
  - CLOCK_50 → clk
  - KEY[0] → rst_n (activo bajo)
  - LEDR[0] → done (indicador visual)
  - LEDR[1] → busy (indicador visual)

#### 6.5 Compilar y programar
1. Analysis & Synthesis
2. Fitter
3. Timing Analysis (verificar timing se cumple)
4. Assembler (generar .sof)
5. Programmer → Programar FPGA

#### 6.6 Crear software de control completo
**Archivo**: `software/tcl/server/jtag_downscale_server.tcl`

Funciones:
```tcl
proc write_register {addr value}
proc read_register {addr}
proc write_memory_byte {addr value}
proc read_memory_byte {addr}
proc load_image {filename}          # Cargar imagen completa a memoria
proc start_processing {}
proc wait_done {}
proc read_output_image {filename}  # Leer imagen de salida
proc get_performance {}             # Leer contador de ciclos
```

**Archivo**: `software/python/client/downscale_client.py`

Programa completo que:
1. Conecta a servidor TCL (localhost:2540)
2. Carga imagen de entrada desde archivo .txt
3. Configura dimensiones
4. Inicia procesamiento
5. Espera done
6. Lee imagen de salida
7. Guarda resultado
8. Compara con modelo de referencia
9. Reporta performance

### ✅ Checkpoint FASE 6:
- [ ] Top-level integra todos los módulos
- [ ] Proyecto Quartus compila sin errores
- [ ] Timing se cumple (Fmax > 50 MHz recomendado)
- [ ] FPGA programada correctamente
- [ ] Servidor TCL detecta dispositivo
- [ ] Cliente puede escribir/leer registros
- [ ] Cliente puede cargar imagen completa
- [ ] Procesamiento se ejecuta y termina (done=1)
- [ ] Imagen de salida es legible

### 🎯 Prompt para Claude:
```
"Estoy en la FASE 6. Necesito integrar JTAG + memoria + downscaling en un
sistema completo. Genera:
- jtag_register_map.sv (banco de registros)
- jtag_avalon_controller.sv (interfaz JTAG-Avalon)
- top_downscale_system.sv (top-level completo)
- jtag_downscale_server.tcl (servidor con funciones completas)
- downscale_client.py (cliente Python end-to-end)

Sistema debe permitir cargar imagen 64×64, procesar, y leer resultado 32×32."
```

---

## FASE 7: Validación Hardware vs Modelo

**⏱ Tiempo estimado**: 2 horas
**📍 Objetivo**: Validar que el hardware produce resultados correctos

### Contexto:
Esta fase es CRÍTICA para el proyecto. Debemos demostrar que el hardware da resultados
**BIT A BIT idénticos** (o con tolerancia ±1 por redondeo) al modelo de referencia.

### Tareas:

#### 7.1 Crear suite de imágenes de prueba

Generar múltiples imágenes con propiedades conocidas:

1. **test_uniform.txt**: Todos los píxeles = 128
   - Esperado: Salida también 128

2. **test_black.txt**: Todos los píxeles = 0
   - Esperado: Salida también 0

3. **test_white.txt**: Todos los píxeles = 255
   - Esperado: Salida también 255

4. **test_gradient_h.txt**: Gradiente horizontal (0 → 255)
   - Esperado: Gradiente suavizado

5. **test_gradient_v.txt**: Gradiente vertical (0 → 255)

6. **test_checkerboard.txt**: Tablero de ajedrez (0 y 255 alternados)

7. **test_random_seed42.txt**: Imagen aleatoria con seed fijo

#### 7.2 Generar referencias con modelos

Para cada imagen de prueba:
```bash
# Python
python software/python/reference/downscale.py test_uniform.txt ref_py_uniform.txt

# C++
./software/reference_model/downscale test_uniform.txt ref_cpp_uniform.txt 64 64 32 32
```

Validar Python == C++ primero.

#### 7.3 Ejecutar en hardware

Para cada imagen:
```bash
# Iniciar servidor TCL
quartus_stp -t jtag_downscale_server.tcl &

# Ejecutar cliente
python downscale_client.py test_uniform.txt hw_output_uniform.txt
```

#### 7.4 Comparar resultados
**Archivo**: `software/python/utils/compare_images.py`

Debe:
- Cargar imagen de referencia (ref_cpp_*.txt)
- Cargar imagen de hardware (hw_output_*.txt)
- Comparar píxel por píxel
- Calcular métricas:
  - Píxeles idénticos (%)
  - Píxeles con diff ≤ 1 (%)
  - Error absoluto máximo
  - Error absoluto promedio
  - PSNR (Peak Signal-to-Noise Ratio)
- Generar reporte visual (imágenes lado a lado + mapa de diferencias)

#### 7.5 Crear script de validación automática
**Archivo**: `validation/run_validation_suite.sh` (o .bat para Windows)

Debe:
1. Compilar modelo C++ si hay cambios
2. Para cada imagen de prueba:
   - Generar referencia Python
   - Generar referencia C++
   - Verificar Python == C++
   - Ejecutar en hardware
   - Comparar HW vs referencia
3. Generar reporte consolidado
4. Exit code: 0 si todos pasan, 1 si alguno falla

#### 7.6 Documentar resultados
**Archivo**: `docs/validation_plan/validation_results.md`

Debe incluir:
- Fecha y hora de pruebas
- Versión de hardware (commit hash si usas git)
- Tabla de resultados:

```markdown
| Imagen de Prueba   | Píxeles Idénticos | Diff ≤1 | Max Error | Avg Error | PSNR   | Status |
|--------------------|-------------------|---------|-----------|-----------|--------|--------|
| test_uniform       | 100%              | 100%    | 0         | 0.00      | ∞      | ✅ PASS |
| test_black         | 100%              | 100%    | 0         | 0.00      | ∞      | ✅ PASS |
| test_gradient_h    | 98.2%             | 100%    | 1         | 0.12      | 58.3   | ✅ PASS |
| ...                |                   |         |           |           |        |        |
```

Capturas de pantalla de:
- Imagen de entrada
- Referencia (modelo C++)
- Hardware
- Mapa de diferencias

### ✅ Checkpoint FASE 7:
- [ ] Suite de imágenes de prueba generada
- [ ] Modelo Python y C++ dan resultados idénticos
- [ ] Hardware procesa todas las imágenes sin errores
- [ ] ≥95% de píxeles idénticos o diff ≤1
- [ ] Diferencias entendidas y documentadas (redondeo, etc.)
- [ ] Script de validación automatizado funciona
- [ ] Reporte de validación completo

### 🎯 Prompt para Claude:
```
"Estoy en la FASE 7. Necesito validar que el hardware da resultados correctos.
Genera:
- Suite de imágenes de prueba (.txt) con propiedades conocidas
- compare_images.py (comparador con métricas detalladas)
- run_validation_suite.sh (script automatizado)
- Template para validation_results.md

Las imágenes son 64×64 → 32×32. El hardware debe dar ≥95% match con referencia C++."
```

---

## FASE 8: Modo SIMD Paralelo

**⏱ Tiempo estimado**: 4 horas
**📍 Objetivo**: Implementar procesamiento paralelo de 4 píxeles simultáneamente

### Contexto:
Modo SIMD (Single Instruction, Multiple Data) procesa N=4 píxeles de salida en paralelo.
Esto requiere:
- 4× interpoladores bilineales simultáneos
- Leer 16 píxeles de entrada en paralelo (4 salidas × 4 vecinos c/u)
- Optimización de accesos a memoria

### Tareas:

#### 8.1 Análisis de dependencias de datos

Para 4 píxeles consecutivos de salida (ej: y=0, x=0..3):
```
Salida[0,0] necesita: Entrada[0,0], [0,1], [1,0], [1,1]
Salida[0,1] necesita: Entrada[0,2], [0,3], [1,2], [1,3]
Salida[0,2] necesita: Entrada[0,4], [0,5], [1,4], [1,5]
Salida[0,3] necesita: Entrada[0,6], [0,7], [1,6], [1,7]
```

Nota: NO hay solapamiento si procesamos píxeles distantes.

Pero si hacemos downscaling 2:1, hay solapamiento:
```
64→32 (ratio 2:1):
Salida[0,0] @ src(0.0, 0.0) → [0,0], [0,1], [1,0], [1,1]
Salida[0,1] @ src(0.0, 2.0) → [0,2], [0,3], [1,2], [1,3]
Salida[0,2] @ src(0.0, 4.0) → [0,4], [0,5], [1,4], [1,5]
```

¡No hay solapamiento! Podemos leer 16 píxeles diferentes en paralelo.

#### 8.2 Diseñar banco de registros SIMD
**Archivo**: `rtl/downscale/simd_register_file.sv`

Registros SIMD (cada uno almacena 4 píxeles de 8 bits):
```
V0: [pixel_0][pixel_1][pixel_2][pixel_3]  // 32 bits total
V1: [pixel_4][pixel_5][pixel_6][pixel_7]
V2: ...
V3: ...
```

Necesitamos ~8 registros SIMD:
- V0-V3: Píxeles de entrada (p00, p01, p10, p11 para cada lane)
- V4-V7: Resultados intermedios y finales

Operaciones:
- `VLOAD`: Cargar 4 píxeles de memoria → registro
- `VSTORE`: Guardar registro → memoria (4 píxeles)
- `VMUL`: Multiplicación vectorial (4× en paralelo)
- `VADD`: Suma vectorial

#### 8.3 Implementar unidad SIMD de interpolación
**Archivo**: `rtl/downscale/simd_interpolator.sv`

Estructura:
```
simd_interpolator #(.LANES(4))
├── Lane 0: bilinear_interpolator
├── Lane 1: bilinear_interpolator
├── Lane 2: bilinear_interpolator
└── Lane 3: bilinear_interpolator
```

Cada lane procesa 1 píxel independientemente.

Entradas:
```systemverilog
input  [7:0] p00 [0:3],  // 4 píxeles p00, uno por lane
input  [7:0] p01 [0:3],
input  [7:0] p10 [0:3],
input  [7:0] p11 [0:3],
input [15:0] fx  [0:3],  // Pesos para cada lane
input [15:0] fy  [0:3],
output [7:0] out [0:3]   // 4 píxeles de salida
```

#### 8.4 Implementar FSM SIMD
**Archivo**: `rtl/downscale/downscale_fsm_simd.sv`

Similar a FSM secuencial, pero:
- Procesa 4 píxeles por iteración
- Calcula 4 posiciones (x_dst+0, x_dst+1, x_dst+2, x_dst+3)
- Fetch de 16 píxeles (puede requerir múltiples ciclos)
- 4 interpolaciones en paralelo (1 ciclo si no hay pipeline)

Estados adicionales:
```
FETCH_PIXELS → Leer los 16 píxeles necesarios (puede ser 1 o varios ciclos)
INTERPOLATE_SIMD → Procesar 4 píxeles en paralelo
WRITE_SIMD → Escribir 4 píxeles a memoria
```

Optimización: Si memoria tiene ancho suficiente, leer 4 píxeles por ciclo.

#### 8.5 Optimizar accesos a memoria
**Archivo**: `rtl/memory/image_memory_wide.sv`

Opciones:

**Opción A**: Memoria con múltiples puertos de lectura
- 4 puertos de lectura independientes
- 1 puerto de escritura

**Opción B**: Memoria con ancho de palabra mayor
- 32-bit read (4 píxeles por ciclo)
- Requiere que píxeles estén alineados

**Opción C** (más simple): Memoria dual-port estándar
- Leer 16 píxeles en 16 ciclos (o 8 ciclos con 2 puertos)
- Usar buffers/registros para almacenar píxeles
- Pipeline: mientras procesa 4 píxeles, fetch los siguientes 16

Recomendación: Empezar con **Opción C** (más simple, menos recursos).

#### 8.6 Integrar módulo SIMD completo
**Archivo**: `rtl/downscale/downscale_simd.sv`

Interfaz similar a `downscale_sequential.sv` pero con:
- Mismo protocolo de control (start, done)
- Procesamiento 4× más rápido (ideal)

#### 8.7 Modificar top-level para soportar ambos modos
**Archivo**: `rtl/top/top_downscale_system.sv` (actualizar)

Agregar:
- Instancia de `downscale_simd`
- Multiplexor controlado por registro MODE (0=secuencial, 1=SIMD)
- Conexión a las mismas memorias

#### 8.8 Crear testbench SIMD
**Archivo**: `tb/unit/tb_downscale_simd.sv`

Similar a testbench secuencial, validar:
- Resultados idénticos a modo secuencial
- Performance: ~4× menos ciclos
- No hay race conditions

#### 8.9 Validar en hardware

Ejecutar suite de validación (FASE 7) pero con MODE=1 (SIMD).

Comparar:
- Resultados vs modelo de referencia (deben ser idénticos)
- Ciclos secuencial vs SIMD (debe haber speedup 3-4×)

### ✅ Checkpoint FASE 8:
- [ ] Módulo SIMD implementado
- [ ] Simulación muestra procesamiento paralelo correcto
- [ ] Resultados SIMD == Secuencial == Modelo de referencia
- [ ] Speedup medible (3-4× menos ciclos)
- [ ] Síntesis usa recursos razonables (~4× recursos de secuencial)
- [ ] Timing se cumple
- [ ] Validación en hardware exitosa

### 🎯 Prompt para Claude:
```
"Estoy en la FASE 8. Necesito implementar modo SIMD que procese 4 píxeles en
paralelo. Genera:
- simd_register_file.sv (banco de registros vectoriales)
- simd_interpolator.sv (4 interpoladores en paralelo)
- downscale_fsm_simd.sv (FSM optimizada para SIMD)
- downscale_simd.sv (módulo integrado)
- tb_downscale_simd.sv (testbench)
- Actualización de top_downscale_system.sv para soportar ambos modos

Debe procesar 64×64 → 32×32 con speedup ~4× vs modo secuencial."
```

---

## FASE 9: Performance Counters

**⏱ Tiempo estimado**: 1 hora
**📍 Objetivo**: Implementar contadores para medir rendimiento del sistema

### Contexto:
El proyecto requiere medir:
- FLOPs (operaciones de punto fijo)
- Lecturas de memoria
- Escrituras de memoria
- Intensidad aritmética = FLOPs / (Reads + Writes)
- Ciclos totales

### Tareas:

#### 9.1 Implementar contadores de performance
**Archivo**: `rtl/common/performance_counters.sv`

Contadores (32-bit cada uno):
```systemverilog
module performance_counters (
    input  logic clk,
    input  logic rst,
    input  logic enable,        // Contar solo cuando enable=1

    // Eventos a contar
    input  logic mem_read,      // Pulso por cada lectura
    input  logic mem_write,     // Pulso por cada escritura
    input  logic flop,          // Pulso por cada operación aritmética

    // Contadores (read-only)
    output logic [31:0] total_cycles,
    output logic [31:0] mem_reads,
    output logic [31:0] mem_writes,
    output logic [31:0] flops,

    // Reset individual de contadores
    input  logic clear_counters
);
```

#### 9.2 Instrumentar módulos de interpolación

En `bilinear_interpolator.sv`, agregar salida `flop_event`:
- Cada multiplicación Q8.8 = 1 FLOP
- Cada suma = 1 FLOP
- Por píxel: ~8-12 FLOPs (4 mult de pesos + 4 mult de píxeles + 3 sumas)

#### 9.3 Conectar contadores al top-level

En `top_downscale_system.sv`:
- Instanciar `performance_counters`
- Conectar señales de memoria (read/write)
- Conectar señal de FLOP desde interpolador
- Enable = busy (contar solo durante procesamiento)

#### 9.4 Agregar registros JTAG para contadores

En `jtag_register_map.sv`, agregar:
```
0x20: REG_PERF_CYCLES     [31:0] (read-only)
0x21: REG_PERF_MEM_READS  [31:0] (read-only)
0x22: REG_PERF_MEM_WRITES [31:0] (read-only)
0x23: REG_PERF_FLOPS      [31:0] (read-only)
0x24: REG_PERF_CONTROL
      [0] - CLEAR (write 1 to reset counters)
```

#### 9.5 Actualizar software para leer contadores

En `downscale_client.py`, después de `wait_done()`:
```python
cycles = read_register(0x20)
reads  = read_register(0x21)
writes = read_register(0x22)
flops  = read_register(0x23)

throughput = (DST_W * DST_H) / cycles  # píxeles por ciclo
intensity = flops / (reads + writes)   # intensidad aritmética

print(f"Performance Report:")
print(f"  Cycles:       {cycles}")
print(f"  Mem Reads:    {reads}")
print(f"  Mem Writes:   {writes}")
print(f"  FLOPs:        {flops}")
print(f"  Throughput:   {throughput:.3f} pixels/cycle")
print(f"  Intensity:    {intensity:.3f} FLOPs/byte")
```

#### 9.6 Comparar Secuencial vs SIMD

Crear tabla de comparación:

```markdown
| Métrica              | Secuencial | SIMD    | Speedup |
|----------------------|------------|---------|---------|
| Ciclos totales       | X          | Y       | X/Y     |
| Throughput (pix/cyc) | ~1.0       | ~3.5    | 3.5×    |
| FLOPs                | A          | A       | 1.0×    |
| Mem Reads            | B          | B/4     | 4.0×    |
| Intensidad           | I1         | I2      | I2/I1   |
```

### ✅ Checkpoint FASE 9:
- [ ] Performance counters implementados
- [ ] Contadores son accesibles vía JTAG
- [ ] Software lee y reporta métricas
- [ ] Valores son coherentes (ej: writes = DST_W × DST_H)
- [ ] Comparación Secuencial vs SIMD documentada
- [ ] Speedup medido es ≥3× en modo SIMD

### 🎯 Prompt para Claude:
```
"Estoy en la FASE 9. Necesito implementar performance counters para medir
rendimiento. Genera:
- performance_counters.sv (módulo de contadores)
- Instrumentación de bilinear_interpolator.sv (señal flop_event)
- Actualización de top_downscale_system.sv (integrar contadores)
- Actualización de jtag_register_map.sv (registros de performance)
- Actualización de downscale_client.py (leer y reportar métricas)

Debe medir: ciclos, mem reads, mem writes, FLOPs, calcular throughput e intensidad."
```

---

## FASE 10: Escalamiento a 512×512

**⏱ Tiempo estimado**: 2 horas
**📍 Objetivo**: Escalar el sistema para soportar imágenes completas 512×512 → 256×256

### Contexto:
Hasta ahora trabajamos con 64×64 → 32×32 (4 KB entrada).
Ahora escalamos a 512×512 → 256×256 (262 KB entrada + 65 KB salida = 327 KB total).

Desafíos:
- Memoria más grande (verificar capacidad BRAM)
- Tiempo de carga via JTAG más largo (~30 segundos)
- Verificación completa más lenta

### Tareas:

#### 10.1 Verificar recursos BRAM disponibles

Cyclone V 5CSEMA5F31C6 tiene:
- M10K blocks: 397 bloques
- Cada M10K: 10 Kbits = 1.25 KB
- Total: ~496 KB de BRAM

Necesitamos: 327 KB → **CABE** ✅

Verificar en Quartus Compilation Report después de síntesis.

#### 10.2 Actualizar parámetros de módulos

Cambiar defaults en todos los módulos:
```systemverilog
parameter SRC_W = 512,  // antes: 64
parameter SRC_H = 512,  // antes: 64
parameter DST_W = 256,  // antes: 32
parameter DST_H = 256   // antes: 32
```

Módulos a actualizar:
- `image_memory_input.sv` - Tamaño: 512×512 = 262,144 bytes
- `image_memory_output.sv` - Tamaño: 256×256 = 65,536 bytes
- `downscale_sequential.sv`
- `downscale_simd.sv`
- `top_downscale_system.sv`

#### 10.3 Optimizar carga de imagen via JTAG

**Problema**: Cargar 262 KB byte-a-byte toma ~10 minutos.

**Solución**: Carga por bloques (burst writes)

En `jtag_downscale_server.tcl`, modificar `load_image`:
```tcl
proc load_image_fast {filename} {
    # Leer archivo completo
    set data [read_image_file $filename]

    # Enviar en bloques de 256 bytes
    set block_size 256
    for {set addr 0} {$addr < [llength $data]} {incr addr $block_size} {
        set block [lrange $data $addr [expr {$addr + $block_size - 1}]]

        # Escribir bloque completo en una transacción JTAG
        write_memory_block $addr $block
    }
}
```

Esto reduce tiempo de ~10 min a ~30 seg.

#### 10.4 Generar imagen de prueba 512×512

**Archivo**: `software/python/utils/create_test_image_512.py`

Opciones:
- Descargar imagen real y convertir a escala de grises
- Generar patrón sintético (gradientes, formas geométricas)
- Redimensionar imagen más pequeña

Guardar en formatos:
- `.png` - Visualización
- `.txt` - Para modelo de referencia
- `.hex` - Para simulación (opcional, muy grande)

#### 10.5 Ejecutar modelo de referencia

```bash
# Python
python downscale.py test_512x512.txt ref_256x256.txt 512 512 256 256

# C++
./downscale test_512x512.txt ref_256x256.txt 512 512 256 256
```

Verificar Python == C++ (bit a bit).

#### 10.6 Simular en ModelSim (opcional)

Simular imagen completa toma MUCHO tiempo (horas).

Alternativa:
- Simular solo primeras 1000 iteraciones
- Verificar FSM funciona correctamente
- Confiar en validación con imágenes pequeñas

#### 10.7 Recompilar y programar FPGA

1. Recompilar con nuevos parámetros
2. Verificar Compilation Report:
   - BRAM usage: ~327 KB (debe ser < 496 KB)
   - Fmax: debe seguir siendo > 50 MHz
3. Programar FPGA

#### 10.8 Ejecutar en hardware

```bash
# Iniciar servidor
quartus_stp -t jtag_downscale_server.tcl &

# Ejecutar cliente (¡va a tomar 1-2 minutos!)
python downscale_client.py test_512x512.txt hw_output_256x256.txt
```

#### 10.9 Validar resultado

```bash
python compare_images.py ref_256x256.txt hw_output_256x256.txt
```

Esperado: ≥95% match.

#### 10.10 Medir performance final

Para 256×256 = 65,536 píxeles de salida:

**Modo Secuencial**:
- Ciclos esperados: ~65,536 × K (donde K = ciclos por píxel, ~10-20)
- Tiempo @ 50 MHz: ~13-26 ms

**Modo SIMD**:
- Ciclos esperados: ~65,536 / 4 × K
- Tiempo @ 50 MHz: ~3-7 ms
- Speedup: ~4×

### ✅ Checkpoint FASE 10:
- [ ] Parámetros actualizados a 512×512 → 256×256
- [ ] Recompilación exitosa con BRAM suficiente
- [ ] Timing se cumple
- [ ] Imagen de prueba 512×512 generada
- [ ] Modelo de referencia procesa imagen completa
- [ ] Hardware procesa imagen completa sin errores
- [ ] Validación muestra ≥95% match
- [ ] Performance counters reportan valores coherentes
- [ ] Speedup SIMD vs Secuencial ~3-4×

### 🎯 Prompt para Claude:
```
"Estoy en la FASE 10. Necesito escalar el sistema a 512×512 → 256×256.
Ayúdame a:
- Actualizar parámetros en todos los módulos
- Optimizar carga de imagen JTAG (burst writes)
- Generar imagen de prueba 512×512
- Script para validar imagen completa
- Verificar uso de BRAM en Quartus

Prioridad: sistema debe seguir funcionando correctamente con imágenes grandes."
```

---

## FASE 11: Documentación Final

**⏱ Tiempo estimado**: 4-6 horas
**📍 Objetivo**: Completar documentación para entrega del proyecto

### Contexto:
Según la especificación, debes entregar:
1. **Artículo científico** (formato académico)
2. **Plan de verificación** (descripción de pruebas)
3. **README** (instrucciones de uso)
4. **Código fuente** (todo el SystemVerilog, C++, Python, TCL)
5. **Bitstream** (.sof para programar FPGA)

### Tareas:

#### 11.1 Artículo Científico
**Archivo**: `docs/Articulo_Proyecto02.pdf`

Estructura (según especificación):

**1. Introducción (1-2 páginas)**
- Motivación: ¿Por qué downscaling de imágenes?
- Contexto: Aceleradores DSA, SIMD, FPGAs
- Objetivos del proyecto
- Contribuciones

**2. Marco Teórico (2-3 páginas)**
- Interpolación bilineal (algoritmo matemático)
- Aritmética de punto fijo Q8.8
- Paralelismo SIMD
- Arquitecturas DSA

**3. Identificación de Necesidades y Requerimientos (1-2 páginas)**
- Requisitos funcionales:
  - Interpolación bilineal correcta
  - Modos secuencial y SIMD
  - Comunicación JTAG
  - Validación bit a bit
- Requisitos no funcionales:
  - Eficiencia energética (uso de BRAM, bloques DSP)
  - Rendimiento (throughput, latencia)
  - Uso de recursos (BRAM, LEs, DSPs)

**4. Valoración de Alternativas (2-3 páginas)**
- **Formatos numéricos**: Q8.8 vs float vs otros fixed-point
  - Justificación: Q8.8 balancea precisión y recursos
- **Modo de procesamiento**: Secuencial vs SIMD vs fully parallel
  - Justificación: SIMD N=4 balancea speedup y recursos
- **Comunicación**: JTAG vs UART vs PCIe
  - Justificación: JTAG usa hardware existente
- **Memoria**: BRAM interna vs SDRAM externa
  - Justificación: BRAM es más simple y rápida

Tabla comparativa de cada alternativa con pros/cons.

**5. Diseño de la Solución (5-7 páginas)** ⭐ SECCIÓN MÁS IMPORTANTE
- **Arquitectura general** (diagrama de bloques top-level)
- **Módulo de interpolación** (datapath aritmético)
  - Diagrama de unidad Q8.8
  - Pipeline de interpolación
- **Máquina de estados** (FSM)
  - Diagrama de estados
  - Descripción de transiciones
- **Diseño de registros SIMD**
  - Justificación de cantidad y tamaño
  - Estrategia de buffering de píxeles
- **Interfaz de memoria**
  - Dual-port RAM
  - Esquema de direccionamiento
- **Interfaz JTAG**
  - Mapa de registros
  - Protocolo de comunicación
- **Modo SIMD**
  - Arquitectura paralela
  - Manejo de dependencias de datos

**Diagramas esenciales**:
- Arquitectura general del sistema
- Datapath del interpolador bilineal
- FSM (secuencial y SIMD)
- Organización de memoria
- Pipeline (si aplicable)

**6. Validación del Diseño (3-4 páginas)**
- **Simulación**:
  - Testbenches unitarios
  - Testbench de integración
  - Casos de prueba
  - Resultados de simulación
- **Validación en hardware**:
  - Suite de imágenes de prueba
  - Comparación con modelo de referencia
  - Tabla de resultados (% match)
  - Análisis de diferencias
- **Waveforms** (capturas de simulación)
- **Imágenes** (entrada vs salida)

**7. Análisis de Resultados (2-3 páginas)**
- **Performance counters**:
  - Tabla: Secuencial vs SIMD
  - Ciclos, throughput, latencia
  - Speedup medido
- **Utilización de recursos FPGA**:
  - BRAM, LEs, DSPs, FFs, registros
  - Comparación Secuencial vs SIMD
- **Análisis de timing**:
  - Fmax alcanzada
  - Critical path
- **Intensidad aritmética**:
  - FLOPs / (Mem accesses)
  - Análisis de bottlenecks

**8. Conclusiones (1-2 páginas)**
- Logros del proyecto
- Validación exitosa
- Performance obtenida
- Aprendizajes
- Trabajo futuro (optimizaciones, features adicionales)

**9. Referencias**
- Todas las fuentes citadas (mínimo 5-8 referencias)
- Paper de Hennessy & Patterson
- Tutorial de punto fijo (Project F)
- GuiaJtag repository
- Wikipedia (interpolación bilinear)
- Datasheets de Cyclone V

#### 11.2 Plan de Verificación
**Archivo**: `docs/validation_plan/Plan_de_Verificacion.pdf`

Estructura:

**1. Introducción**
- Importancia de la verificación
- Estrategia (bottom-up: unitario → integración → sistema)

**2. Pruebas Unitarias**

Tabla:
| Módulo                  | Test Case             | Entrada                | Salida Esperada       | Status |
|-------------------------|-----------------------|------------------------|----------------------|--------|
| fixed_point_mult        | Mult 2.5 × 3.0        | 640, 768 (Q8.8)        | 1920 (Q8.8 = 7.5)    | ✅     |
| bilinear_interpolator   | 4 esquinas iguales    | p00=p01=p10=p11=128    | out=128              | ✅     |
| bilinear_interpolator   | Gradiente horizontal  | p00=0, p01=255, ...    | out=127              | ✅     |
| image_memory_input      | Write-read test       | Secuencia 0-255        | Lectura correcta     | ✅     |
| downscale_fsm           | State transitions     | Reset → Start → Done   | FSM correcta         | ✅     |

**3. Pruebas de Integración**

| Sistema                 | Test Case              | Imagen Entrada       | Validación               | Status |
|-------------------------|------------------------|----------------------|--------------------------|--------|
| downscale_sequential    | Imagen uniforme        | 64×64 todos=128      | Salida todos=128         | ✅     |
| downscale_sequential    | Gradiente horizontal   | 64×64 gradiente      | Match con modelo C++     | ✅     |
| downscale_simd          | Imagen uniforme        | 64×64 todos=128      | == secuencial            | ✅     |
| downscale_simd          | Imagen aleatoria       | 64×64 random         | == secuencial            | ✅     |

**4. Pruebas de Sistema (Hardware)**

| Test                    | Descripción                          | Criterio de Éxito          | Status |
|-------------------------|--------------------------------------|----------------------------|--------|
| JTAG LED test           | Controlar LEDs via JTAG              | LEDs responden             | ✅     |
| Carga de imagen         | Cargar 64×64 via JTAG                | Verificación readback      | ✅     |
| Procesamiento completo  | 64×64 → 32×32                        | ≥95% match con ref         | ✅     |
| Modo secuencial         | Procesar suite completa              | Todos los tests pasan      | ✅     |
| Modo SIMD               | Procesar suite completa              | == secuencial              | ✅     |
| Escalamiento 512×512    | Imagen completa                      | ≥95% match con ref         | ✅     |

**5. Reporte de Simulaciones**
- Capturas de waveforms
- Logs de testbenches
- Análisis de timing en simulación

**6. Reporte de Resultados en Hardware**
- Imágenes procesadas
- Comparación con referencia
- Mapas de diferencias
- Performance counters

**7. Problemas Encontrados y Soluciones**
- Lista de bugs encontrados durante desarrollo
- Cómo se solucionaron
- Lecciones aprendidas

#### 11.3 README del Proyecto
**Archivo**: `README.md` (en el directorio raíz)

Contenido:

```markdown
# Proyecto 02: DSA para Downscaling de Imágenes

Arquitectura de Computadores II - CE-4302
Instituto Tecnológico de Costa Rica

## Descripción
Arquitectura de dominio específico (DSA) en FPGA que realiza reducción de
imágenes mediante interpolación bilineal con paralelismo SIMD.

## Características
- Interpolación bilineal en aritmética de punto fijo Q8.8
- Dos modos: Secuencial (1 pix/ciclo) y SIMD (4 pix/ciclo)
- Comunicación FPGA-PC via Virtual JTAG
- Soporte hasta 512×512 → 256×256
- Validación bit-a-bit con modelo de referencia C++

## Requisitos
- Quartus Prime Lite 20.1
- ModelSim (incluido con Quartus)
- Python 3.x (numpy, matplotlib, PIL)
- Compilador C++ (g++/MinGW)
- Placa DE1-SoC MTL2 (Cyclone V)

## Estructura del Proyecto
(copiar estructura de carpetas de FASE 0)

## Compilación

### Modelo de Referencia C++
```bash
cd software/reference_model
make
```

### Proyecto Quartus
1. Abrir `quartus/downscale_project/downscale_project.qpf`
2. Processing → Start Compilation
3. Programar FPGA con el `.sof` generado

## Uso

### 1. Programar FPGA
```bash
quartus_pgm -m jtag -o "p;quartus/downscale_project/output_files/top_downscale_system.sof@1"
```

### 2. Iniciar servidor JTAG
```bash
quartus_stp -t software/tcl/server/jtag_downscale_server.tcl
```

### 3. Ejecutar procesamiento
```bash
python software/python/client/downscale_client.py input.txt output.txt
```

### 4. Validar resultado
```bash
python software/python/utils/compare_images.py reference.txt output.txt
```

## Ejemplos

### Procesar imagen de prueba 64×64 → 32×32
```bash
# Generar imagen de prueba
python software/python/utils/create_test_image.py

# Generar referencia
./software/reference_model/downscale \
    test_64x64.txt ref_32x32.txt 64 64 32 32

# Procesar en FPGA (modo secuencial)
python downscale_client.py test_64x64.txt hw_32x32.txt --mode sequential

# Procesar en FPGA (modo SIMD)
python downscale_client.py test_64x64.txt hw_32x32_simd.txt --mode simd

# Comparar
python compare_images.py ref_32x32.txt hw_32x32.txt
```

## Validación
Ejecutar suite completa de validación:
```bash
cd validation
./run_validation_suite.sh
```

## Performance
Medido en DE1-SoC @ 50 MHz, imagen 256×256 → 128×128:

| Modo       | Ciclos  | Tiempo   | Throughput    | Speedup |
|------------|---------|----------|---------------|---------|
| Secuencial | ~180K   | ~3.6 ms  | 0.9 pix/ciclo | 1.0×    |
| SIMD (N=4) | ~50K    | ~1.0 ms  | 3.3 pix/ciclo | 3.6×    |

## Autores
- [Nombres de integrantes]

## Referencias
- [GuiaJtag](https://github.com/Abner2111/GuiaJtag)
- [Idle Logic Labs - vJTAG](https://idlelogiclabs.com/2012/04/15/talking-to-the-de0-nano-using-the-virtual-jtag-interface/)
- [Project F - Fixed Point](https://projectf.io/posts/fixed-point-numbers-in-verilog/)
```

#### 11.4 Preparar entregables

Crear archivo ZIP con:
```
Proyecto02_Grupo#.zip
├── rtl/                     (todo el código SystemVerilog)
├── tb/                      (testbenches)
├── software/                (C++, Python, TCL)
│   ├── reference_model/
│   ├── python/
│   └── tcl/
├── quartus/                 (proyecto Quartus SIN db/, output_files/, etc)
│   └── downscale_project/
│       ├── *.qpf
│       ├── *.qsf
│       └── *.sdc
├── docs/
│   ├── Articulo_Proyecto02.pdf
│   ├── Plan_de_Verificacion.pdf
│   └── architecture/        (diagramas en PNG/PDF)
├── validation/
│   ├── simulation/          (logs, waveforms)
│   └── hardware/            (resultados de tests)
├── bitstream/
│   └── top_downscale_system.sof
└── README.md
```

**IMPORTANTE**: NO incluir:
- Carpetas `db/`, `incremental_db/`, `output_files/` de Quartus
- Archivos `.bak`, `*~`
- Binarios compilados (`.o`, `.exe`)
- Carpeta `work/` de ModelSim

#### 11.5 Verificar checklist de entrega

Según especificación:
- [✅] Código SystemVerilog sintetizable
- [✅] Modelo de referencia C/C++
- [✅] Aplicación de comunicación PC
- [✅] Testbenches unitarios e integración
- [✅] Plan de verificación
- [✅] Artículo científico
- [✅] Bitstream para DE1-SoC MTL2
- [✅] README con instrucciones
- [✅] NO incluye ejecutables ni proyectos compilados

### ✅ Checkpoint FASE 11:
- [ ] Artículo científico completo (mínimo 15 páginas con diagramas)
- [ ] Plan de verificación documentado
- [ ] README claro y completo
- [ ] Todos los archivos organizados
- [ ] ZIP creado sin archivos innecesarios
- [ ] Bitstream funcional incluido
- [ ] Tamaño del ZIP razonable (< 50 MB)
- [ ] Verificación final: descomprimir en carpeta vacía y seguir README

### 🎯 Prompt para Claude:
```
"Estoy en la FASE 11. Necesito completar la documentación para entrega.
Ayúdame con:
- Template LaTeX para artículo científico (estructura según especificación)
- Template para Plan de Verificación
- README.md completo con ejemplos
- Checklist de archivos para el ZIP
- Script para crear ZIP sin archivos innecesarios

El artículo debe tener diagramas de: arquitectura general, interpolador,
FSM, memoria, SIMD. Necesito descripciones técnicas detalladas."
```

---

## 📊 RESUMEN DE PROGRESO

Después de completar cada fase, actualizar esta tabla:

| Fase | Nombre                        | Tiempo Est. | Tiempo Real | Status |
|------|-------------------------------|-------------|-------------|--------|
| 0    | Setup                         | 30 min      |             | ⬜     |
| 1    | Modelo Python                 | 1 hora      |             | ⬜     |
| 2    | Modelo C++                    | 2 horas     |             | ⬜     |
| 3    | Test JTAG LEDs                | 1 hora      |             | ⬜     |
| 4    | Memoria                       | 2 horas     |             | ⬜     |
| 5    | Interpolación Secuencial      | 3 horas     |             | ⬜     |
| 6    | Integración JTAG              | 2 horas     |             | ⬜     |
| 7    | Validación                    | 2 horas     |             | ⬜     |
| 8    | Modo SIMD                     | 4 horas     |             | ⬜     |
| 9    | Performance Counters          | 1 hora      |             | ⬜     |
| 10   | Escalamiento 512×512          | 2 horas     |             | ⬜     |
| 11   | Documentación                 | 6 horas     |             | ⬜     |
| **TOTAL** | **---**                  | **~26-30 horas** |        |        |

---

## 🎯 CÓMO USAR ESTA GUÍA

### Workflow Recomendado:

1. **Lee la fase completa** antes de empezar
2. **Entiende los objetivos** y por qué es importante
3. **Prepara el prompt** para Claude usando la plantilla al final de cada fase
4. **Genera el código** con ayuda de Claude
5. **Prueba incrementalmente** (no esperes a tener todo)
6. **Valida el checkpoint** antes de continuar
7. **Documenta problemas** en `docs/progress/bitacora.md`
8. **Repite** para la siguiente fase

### Ejemplo de Interacción:

```
Usuario: "Claude, estoy listo para la FASE 1. Generame el código Python
para el modelo de referencia según la guía."

Claude: [Genera código completo de los 5 archivos Python]

Usuario: "El test falla en el caso del gradiente. Ayúdame a debuggear."

Claude: [Analiza el problema y ofrece solución]

Usuario: [Valida que funciona] "Perfecto, FASE 1 completada.
Ahora vamos a FASE 2..."
```

### Tips Importantes:

- **No te saltes fases**: Cada una construye sobre la anterior
- **Valida constantemente**: Es más fácil debuggear módulos pequeños
- **Usa control de versiones**: Git para respaldar tu código
- **Pregunta cuando te atores**: Es mejor preguntar que perder horas
- **Documenta mientras avanzas**: No dejes todo para el final

---

## 📞 SOPORTE Y DEBUGGING

### Si algo no funciona:

1. **Identifica en qué fase estás**
2. **Revisa el checkpoint de la fase anterior** (¿realmente lo completaste?)
3. **Busca errores específicos** (mensajes de compilación, simulación, hardware)
4. **Pregunta a Claude con contexto**:
   ```
   "Estoy en FASE X. Tengo este error: [copia el error].
   Este es mi código: [muestra el código relevante].
   ¿Qué estoy haciendo mal?"
   ```

### Errores Comunes:

- **FASE 1-2**: Errores de redondeo en Q8.8 → Verificar shifts
- **FASE 3**: JTAG no detecta dispositivo → Verificar cable, drivers
- **FASE 4**: Memoria no sintetiza como BRAM → Verificar código inferencia
- **FASE 5**: Resultados incorrectos → Verificar cálculo de direcciones
- **FASE 6**: Comunicación JTAG falla → Verificar sincronización de clocks
- **FASE 7**: Match bajo con referencia → Debuggear Q8.8 operaciones
- **FASE 8**: SIMD no da speedup → Optimizar accesos a memoria

---

## ✅ CRITERIOS DE ÉXITO DEL PROYECTO

Al finalizar todas las fases, debes tener:

### Funcionalidad:
- ✅ Sistema procesa imágenes 512×512 → 256×256
- ✅ Modo secuencial funciona correctamente
- ✅ Modo SIMD funciona correctamente
- ✅ Resultados coinciden con modelo C++ (≥95%)
- ✅ Comunicación JTAG estable y confiable

### Performance:
- ✅ Modo SIMD 3-4× más rápido que secuencial
- ✅ Performance counters reportan métricas correctas
- ✅ Sistema corre a ≥50 MHz en FPGA

### Validación:
- ✅ Todas las pruebas unitarias pasan
- ✅ Suite de validación completa exitosa
- ✅ Plan de verificación documentado

### Documentación:
- ✅ Artículo científico completo
- ✅ Código bien comentado
- ✅ README funcional
- ✅ Diagramas claros de arquitectura

### Entrega:
- ✅ ZIP con estructura correcta
- ✅ Sin archivos innecesarios
- ✅ Bitstream funcional incluido
- ✅ Instrucciones reproducibles

---

## 🚀 EMPECEMOS

**Estás listo para empezar con FASE 0.**

Cuando completes la FASE 0, dime:
```
"FASE 0 completada. Listo para FASE 1."
```

Y yo te guiaré paso a paso en la implementación del modelo de referencia Python.

**¡Éxito en tu proyecto!** 🎯
