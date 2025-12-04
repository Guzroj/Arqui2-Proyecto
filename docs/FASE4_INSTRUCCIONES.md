# FASE 4: Módulos de Memoria para Imágenes - Instrucciones Completas

## Resumen
Esta fase implementa módulos de memoria dual-port parametrizables para almacenar las imágenes de entrada (64×64) y salida (32×32). Los módulos están diseñados para que Quartus infiera bloques de memoria BRAM (M10K) en lugar de usar lógica combinacional.

---

## Archivos Generados

### RTL (Hardware)
- `rtl/memory/image_memory_input.sv` - Dual-port RAM para imagen de entrada (64×64)
- `rtl/memory/image_memory_output.sv` - Dual-port RAM para imagen de salida (32×32)

### Simulación
- `sim/tb_image_memory.sv` - Testbench completo con 6 tests
- `sim/run_modelsim.do` - Script TCL para ModelSim
- `sim/run_sim.bat` - Script batch para ejecutar simulación

### Documentación
- `docs/FASE4_INSTRUCCIONES.md` - Este archivo

---

## Características de los Módulos de Memoria

### image_memory_input.sv

**Propósito**: Almacenar la imagen de entrada completa (64×64 píxeles)

**Características**:
- **Tamaño**: 4096 píxeles (64×64)
- **Ancho de datos**: 8 bits por píxel (grayscale)
- **Total de bits**: 32,768 bits = 4 KB
- **Arquitectura**: Dual-port RAM
  - **Puerto A**: Escritura (desde JTAG o fuente externa)
  - **Puerto B**: Lectura (hacia downscaler)
- **Inferencia de BRAM**: Usa atributo `(* ramstyle = "M10K" *)`
- **Latencia de lectura**: 1 ciclo de reloj

**Señales**:
```systemverilog
input  logic                    clk           // Clock del sistema
input  logic                    rst_n         // Reset activo bajo
input  logic                    wr_en_a       // Enable de escritura (Puerto A)
input  logic [11:0]             wr_addr_a     // Dirección de escritura (12 bits para 4096)
input  logic [7:0]              wr_data_a     // Dato a escribir (8 bits)
input  logic                    rd_en_b       // Enable de lectura (Puerto B)
input  logic [11:0]             rd_addr_b     // Dirección de lectura
output logic [7:0]              rd_data_b     // Dato leído (registrado)
```

### image_memory_output.sv

**Propósito**: Almacenar la imagen de salida después del downscaling (32×32 píxeles)

**Características**:
- **Tamaño**: 1024 píxeles (32×32)
- **Ancho de datos**: 8 bits por píxel (grayscale)
- **Total de bits**: 8,192 bits = 1 KB
- **Arquitectura**: Dual-port RAM
  - **Puerto A**: Escritura (desde downscaler)
  - **Puerto B**: Lectura (hacia JTAG o fuente externa)
- **Inferencia de BRAM**: Usa atributo `(* ramstyle = "M10K" *)`
- **Latencia de lectura**: 1 ciclo de reloj
- **Feature extra**: Contador de píxeles escritos

**Señales**:
```systemverilog
input  logic                    clk               // Clock del sistema
input  logic                    rst_n             // Reset activo bajo
input  logic                    wr_en_a           // Enable de escritura (Puerto A)
input  logic [9:0]              wr_addr_a         // Dirección de escritura (10 bits para 1024)
input  logic [7:0]              wr_data_a         // Dato a escribir (8 bits)
input  logic                    rd_en_b           // Enable de lectura (Puerto B)
input  logic [9:0]              rd_addr_b         // Dirección de lectura
output logic [7:0]              rd_data_b         // Dato leído (registrado)
output logic [10:0]             pixels_written    // Contador de píxeles escritos
```

---

## Inferencia de BRAM (M10K)

### ¿Por qué usar BRAM?

1. **Eficiencia**: Las BRAM son bloques de memoria dedicados en la FPGA
2. **Recursos**: No consumen LUTs ni registros de lógica
3. **Velocidad**: Acceso rápido y predecible
4. **Tamaño**: Cada bloque M10K tiene 10,240 bits (10 Kbits)

### Cálculo de recursos

**Memoria de entrada (64×64 × 8 bits = 32,768 bits)**:
- 32,768 bits / 10,240 bits por M10K = **3.2 bloques M10K**
- Quartus usará **4 bloques M10K**

**Memoria de salida (32×32 × 8 bits = 8,192 bits)**:
- 8,192 bits / 10,240 bits por M10K = **0.8 bloques M10K**
- Quartus usará **1 bloque M10K**

**Total: 5 bloques M10K** (la Cyclone V 5CSEMA5F31C6 tiene 553 bloques M10K disponibles)

### Patrón de codificación para inferencia de BRAM

Para que Quartus infiera correctamente BRAM, el código debe seguir este patrón:

```systemverilog
// 1. Declarar el array con atributo ramstyle
(* ramstyle = "M10K" *) logic [7:0] mem [0:4095];

// 2. Escritura sincrónica
always_ff @(posedge clk) begin
    if (wr_en_a) begin
        mem[wr_addr_a] <= wr_data_a;
    end
end

// 3. Lectura sincrónica y registrada
always_ff @(posedge clk) begin
    if (rd_en_b) begin
        rd_data_b <= mem[rd_addr_b];
    end
end
```

**Características clave**:
- ✅ Usar `always_ff` (flip-flops)
- ✅ Todas las operaciones sincronizadas con el reloj
- ✅ Lectura registrada (no combinacional)
- ✅ Atributo `ramstyle = "M10K"`
- ❌ NO usar lógica combinacional para acceso
- ❌ NO inicializar la memoria en el código (muy costoso)

---

## Tests Implementados en el Testbench

### TEST 1: Basic Input Memory Read/Write
- Escribe 4 píxeles en posiciones específicas
- Lee y verifica los valores escritos
- Verifica direcciones: 0, 1, 100, última

### TEST 2: Basic Output Memory Read/Write
- Escribe 4 píxeles en memoria de salida
- Verifica el contador de píxeles escritos
- Lee y verifica los valores

### TEST 3: Sequential Write (Input Memory)
- Escribe los 4096 píxeles secuencialmente
- Patrón: valor = dirección & 0xFF
- Verifica algunos píxeles aleatorios

### TEST 4: Sequential Read (Output Memory)
- Escribe 1024 píxeles con patrón (valor = dirección × 3)
- Lee toda la memoria secuencialmente
- Verifica todos los valores

### TEST 5: Dual-Port Simultaneous Access
- Prueba escritura y lectura simultáneas
- Verifica que no hay conflictos entre puertos
- Escribe en dirección 50 mientras lee dirección 5

### TEST 6: Checkerboard Pattern
- Escribe patrón de tablero de ajedrez (0xFF / 0x00)
- Verifica algunas posiciones clave
- Demuestra acceso por coordenadas (x, y)

---

## PASO 1: Simular en ModelSim

### Opción A: Usando el script batch (Recomendado)

```bash
cd C:\Users\josev\OneDrive\Documentos\Arqui2ProyectoInicio\sim
run_sim.bat
```

El script:
1. Detecta automáticamente ModelSim
2. Compila los módulos RTL
3. Compila el testbench
4. Ejecuta la simulación
5. Abre las ventanas de waveforms

### Opción B: Manual desde ModelSim

1. Abre ModelSim
2. File → Change Directory → Navega a `sim/`
3. En la consola TCL:
   ```tcl
   do run_modelsim.do
   ```

### Salida esperada

```
========================================
Image Memory Testbench
========================================
Input Memory:  64x64 = 4096 pixels
Output Memory: 32x32 = 1024 pixels
========================================

========================================
TEST 1: Basic Input Memory Read/Write
========================================
[OK] Address 0: 0x12
[OK] Address 1: 0x34
[OK] Address 100: 0xAB
[OK] Last address: 0xFF
Test 1 completed

========================================
TEST 2: Basic Output Memory Read/Write
========================================
Pixels written: 4
[OK] Address 0: 0x55
[OK] Last address: 0xCC
Test 2 completed

========================================
TEST 3: Sequential Write (Input Memory)
========================================
Writing 4096 pixels...
Test 3 completed

========================================
TEST 4: Sequential Read (Output Memory)
========================================
Writing 1024 pixels...
Reading and verifying 1024 pixels...
Test 4 completed

========================================
TEST 5: Dual-Port Simultaneous Access
========================================
Testing simultaneous write and read...
[OK] Simultaneous read succeeded
[OK] Simultaneous write succeeded
Test 5 completed

========================================
TEST 6: Checkerboard Pattern
========================================
Writing checkerboard pattern...
Test 6 completed

========================================
Test Summary
========================================
ALL TESTS PASSED!
========================================
```

---

## PASO 2: Sintetizar en Quartus

### 2.1 Crear proyecto de síntesis (opcional, solo para verificar recursos)

Si quieres verificar que Quartus infiere correctamente las BRAM:

1. Abre Quartus Prime
2. Crea un nuevo proyecto o usa uno existente
3. Agrega los archivos:
   - `rtl/memory/image_memory_input.sv`
   - `rtl/memory/image_memory_output.sv`

### 2.2 Compilar y verificar recursos

1. Processing → Start → Start Analysis & Elaboration
2. Tools → Netlist Viewers → RTL Viewer
   - Deberías ver bloques de memoria, no LUTs
3. Processing → Start Compilation (compilación completa)
4. Después de la compilación:
   - Tools → Compilation Report
   - Flow Summary → Memory Bits Used
   - Busca "M10K blocks"

### Reporte esperado de recursos

```
+----------------------------+--------+
| Resource                   | Usage  |
+----------------------------+--------+
| M10K Memory Blocks         | 5 / 553|
|   Input Memory (64x64)     | 4      |
|   Output Memory (32x32)    | 1      |
+----------------------------+--------+
| ALMs                       | < 100  |
| Registers                  | ~50    |
+----------------------------+--------+
```

**Nota**: Si ves que usa muchos ALMs (>1000) en lugar de M10K, significa que la inferencia de BRAM falló. Verifica:
- Que el código sigue el patrón de BRAM (lectura registrada, escritura sincrónica)
- Que usas `always_ff` en lugar de `always`
- Que el atributo `ramstyle` está presente

---

## Verificación de Inferencia de BRAM

### En el RTL Viewer

Después de "Analysis & Elaboration":
1. Tools → Netlist Viewers → RTL Viewer
2. Busca los módulos `image_memory_input` y `image_memory_output`
3. Deberías ver iconos de **"RAM"** o **"Memory Block"**
4. Si ves muchas LUTs conectadas, la inferencia falló

### En el Compilation Report

1. Compilation Report → Analysis & Synthesis → Resource Utilization by Entity
2. Busca tus módulos de memoria
3. Columna "Memory Bits": Debe mostrar el uso de memoria
4. Columna "ALMs": Debe ser muy bajo (<50)

### En Technology Map Viewer

1. Tools → Netlist Viewers → Technology Map Viewer (Post-Mapping)
2. Expande tus módulos de memoria
3. Deberías ver bloques `M10K` asignados

---

## Uso de las Memorias en el Diseño Completo

### Conexión típica

```
┌─────────────┐
│  JTAG       │ write_port
│  Interface  ├───────────┐
└─────────────┘           │
                          ▼
                ┌──────────────────────┐
                │ image_memory_input   │
                │ (64×64, dual-port)   │
                └──────────┬───────────┘
                           │ read_port
                           ▼
                ┌──────────────────────┐
                │   Downscaler         │
                │   (bilinear interp)  │
                └──────────┬───────────┘
                           │ write_port
                           ▼
                ┌──────────────────────┐
                │ image_memory_output  │
                │ (32×32, dual-port)   │
                └──────────┬───────────┘
                           │ read_port
                           ▼
                ┌──────────────────────┐
                │  JTAG Interface      │
                └──────────────────────┘
```

### Timing considerations

- **Latencia de lectura**: 1 ciclo de reloj
- **Throughput de escritura**: 1 píxel por ciclo
- **Throughput de lectura**: 1 píxel por ciclo
- **Dual-port**: Lectura y escritura simultáneas en puertos diferentes

### Ejemplo de uso (desde otro módulo)

```systemverilog
// Escribir un píxel en memoria de entrada
assign input_mem_wr_en = 1'b1;
assign input_mem_wr_addr = y_coord * 64 + x_coord;  // Convertir (x,y) a dirección
assign input_mem_wr_data = pixel_value;

// Leer un píxel de memoria de entrada (1 ciclo de latencia)
assign input_mem_rd_en = 1'b1;
assign input_mem_rd_addr = row * 64 + col;
// Dato disponible en input_mem_rd_data en el siguiente ciclo
```

---

## Solución de Problemas

### Problema: "Cannot find vsim.exe"
**Solución**:
- Verifica que ModelSim esté instalado
- Edita `run_sim.bat` y agrega la ruta correcta de ModelSim
- O ejecuta desde la línea de comandos de ModelSim directamente

### Problema: "Error: Compilation failed"
**Solución**:
- Verifica que los archivos .sv estén en las rutas correctas
- Verifica que uses ModelSim-Intel (compatible con SystemVerilog)
- Verifica la sintaxis de los archivos

### Problema: Tests fallan con "Expected X, Got Y"
**Solución**:
- Esto indica un bug en la lógica de memoria
- Revisa las waveforms en ModelSim
- Verifica la latencia de lectura (debe ser 1 ciclo)
- Verifica que los enables estén funcionando correctamente

### Problema: Quartus no infiere BRAM, usa LUTs
**Solución**:
- Verifica que uses `always_ff` en lugar de `always`
- Verifica que la lectura esté registrada (no combinacional)
- Verifica que el atributo `(* ramstyle = "M10K" *)` esté presente
- Revisa el patrón de codificación en la sección "Inferencia de BRAM"

### Problema: "Address out of range" en simulación
**Solución**:
- Las assertions están detectando un bug
- Verifica que las direcciones estén dentro del rango correcto
- Input: 0-4095 (12 bits)
- Output: 0-1023 (10 bits)

---

## Parámetros Personalizables

Ambos módulos son parametrizables. Puedes cambiar:

```systemverilog
// Ejemplo: Memoria de 128x128 con 16 bits por píxel
image_memory_input #(
    .WIDTH(128),
    .HEIGHT(128),
    .DATA_WIDTH(16)
) u_large_mem (
    // conexiones...
);
```

**Nota**: Al cambiar los parámetros, también debes actualizar el testbench.

---

## Próximos Pasos

Una vez verificados los módulos de memoria:

1. **FASE 5**: Implementar el módulo de downscaling con interpolación bilineal
2. Conectar el downscaler entre las dos memorias
3. Integrar con JTAG para transferir imágenes completas
4. Probar el sistema end-to-end

---

## Referencias

- **Intel Cyclone V Device Handbook**: Memory blocks (M10K)
  - https://www.intel.com/content/www/us/en/docs/programmable/683385/current/memory-blocks.html

- **Quartus Prime Handbook**: Inferring RAM from HDL Code
  - https://www.intel.com/content/www/us/en/docs/programmable/683082/current/inferring-ram-from-hdl-code.html

- **ModelSim User Manual**:
  - https://www.intel.com/content/www/us/en/docs/programmable/683097/current/introduction-to-simulation.html
