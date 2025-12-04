# 📋 Plan de Verificación - DSA Downscaler

**Proyecto:** Acelerador Hardware para Downscaling de Imágenes  
**Curso:** CE-4302 Arquitectura de Computadores II  
**Fecha:** Diciembre 2025

---

## 1. Objetivo del Plan de Verificación

Garantizar que el DSA Downscaler implementado en FPGA cumple con todos los requisitos funcionales y de rendimiento especificados, mediante pruebas sistemáticas que validen:

1. **Exactitud funcional** - Resultados bit a bit idénticos al modelo de referencia
2. **Modos de operación** - Secuencial y SIMD funcionan correctamente
3. **Configurabilidad** - Soporta diferentes tamaños y factores de escala
4. **Rendimiento** - Speedup esperado en modo SIMD
5. **Interfaz JTAG** - Comunicación y control funcional

---

## 2. Niveles de Verificación

### 2.1 Verificación a Nivel de Unidad (Unit Testing)

**Objetivo:** Validar módulos individuales en simulación

#### Test 1: ModoSecuencial (Interpolador Bilinear)
- **Archivo:** `testbench/tb_ModoSecuencial.sv`
- **DUT:** `rtl/ModoSecuencial.sv`
- **Casos de prueba:**
  1. **Caso 1:** Píxeles uniformes (I00=I10=I01=I11=128) → Output debe ser 128
  2. **Caso 2:** Gradiente horizontal (I00=0, I10=255, I01=0, I11=255, α=128, β=0) → Output = 127-128
  3. **Caso 3:** Gradiente vertical (I00=0, I10=0, I01=255, I11=255, α=0, β=128) → Output = 127-128
  4. **Caso 4:** Gradiente diagonal (I00=0, I10=85, I01=85, I11=170, α=128, β=128) → Output ≈ 85
  5. **Caso 5:** Saturación superior (todos 255, resultado debe saturar a 255)
  6. **Caso 6:** Saturación inferior (todos 0, resultado debe ser 0)

- **Criterios de éxito:**
  - ✅ valid_out se activa 1 ciclo después de valid_in
  - ✅ pixel_out dentro de ±1 del valor esperado (por redondeo)
  - ✅ Pipeline funciona correctamente

---

#### Test 2: Downscale_Secuencial (Core Secuencial)
- **Archivo:** `testbench/tb_Downscale_Secuencial.sv`
- **DUT:** `rtl/Downscale_Secuencial.sv`
- **Casos de prueba:**
  1. **4×4 → 2×2:** Imagen pequeña, verificación manual
  2. **8×8 → 4×4:** Validar cálculo de coordenadas
  3. **16×16 → 8×8:** Validar múltiples píxeles
  4. **128×128 → 64×64:** Prueba de tamaño mediano

- **Validaciones:**
  - ✅ FSM transiciona correctamente entre estados
  - ✅ Señal `done` se activa cuando termina
  - ✅ Número correcto de lecturas de memoria (4 por píxel de salida)
  - ✅ Número correcto de escrituras (1 por píxel de salida)
  - ✅ Resultados coinciden con modelo de referencia C++

---

#### Test 3: Downscale_SIMD (Core SIMD)
- **Archivo:** `testbench/tb_Downscale_SIMD.sv`
- **DUT:** `rtl/Downscale_SIMD.sv` (N=4)
- **Casos de prueba:**
  1. **8×8 → 4×4:** Validar procesamiento paralelo
  2. **16×16 → 8×8:** Validar batches completos
  3. **128×128 → 64×64:** Tamaño mediano
  4. **Píxeles no múltiplos de N:** Validar píxeles finales

- **Validaciones:**
  - ✅ Procesa N píxeles en paralelo correctamente
  - ✅ Resultados **idénticos** a modo secuencial
  - ✅ Speedup teórico ~4× en ciclos (N=4)
  - ✅ Todos los lanes SIMD funcionan

---

#### Test 4: DSA_Memory_Adapter
- **Archivo:** `testbench/tb_DSA_Memory_Adapter.sv`
- **DUT:** `rtl/DSA_Memory_Adapter.sv`
- **Casos de prueba:**
  1. **Lectura secuencial:** Validar conversión byte→word
  2. **Lectura SIMD:** Validar arbitraje round-robin
  3. **Escritura:** Validar byte enable correcto
  4. **Arbitraje:** Escrituras tienen prioridad sobre lecturas

- **Validaciones:**
  - ✅ Conversión de direcciones byte→word correcta
  - ✅ Extracción de bytes de words correcta
  - ✅ FSM de arbitraje funciona sin deadlocks
  - ✅ Performance counters incrementan correctamente

---

### 2.2 Verificación a Nivel de Integración

#### Test 5: DSA Completo (Sin JTAG)
- **Archivo:** `testbench/tb_DSA_Integration.sv`
- **DUT:** `rtl/DSA_Avalon_Wrapper.sv` + todos los sub-módulos
- **Casos de prueba:**
  1. **Configuración por registros:** Escribir/leer registros de control
  2. **Downscale 128×128 → 64×64 (Secuencial):** Validar operación completa
  3. **Downscale 128×128 → 64×64 (SIMD):** Comparar con secuencial
  4. **Diferentes factores de escala:** 0.5, 0.75, 1.0

- **Validaciones:**
  - ✅ Registros de control accesibles vía Avalon-MM
  - ✅ Señal `busy` se activa durante procesamiento
  - ✅ Señal `done` se activa al terminar
  - ✅ Performance counters correctos
  - ✅ Resultados en memoria de salida correctos

---

### 2.3 Verificación en Hardware (FPGA)

#### Test 6: Prueba en DE1-SoC (Comunicación JTAG)
- **Hardware:** FPGA Intel DE1-SoC programada con `ModoSecuencial.sof`
- **Interfaz:** JTAG System Console
- **Casos de prueba:**
  1. **Test de conexión:** Leer/escribir registros DSA
  2. **Test de LEDs:** Verificar bus Avalon-MM
  3. **Test de memoria:** Escribir/leer BRAM
  4. **Downscale 4×4 → 2×2:** Imagen pequeña, validación manual
  5. **Downscale 128×128 → 64×64:** Validación con modelo C++
  6. **Downscale 512×512 → 256×256:** Prueba de tamaño máximo

- **Scripts TCL:**
  - `tcl/test_basic_jtag.tcl` - Test de conexión
  - `tcl/load_image_txt.tcl` - Cargar imagen a BRAM
  - `tcl/test_downscale_complete.tcl` - Test completo
  
- **Validaciones:**
  - ✅ JTAG Master conecta correctamente
  - ✅ Registros DSA accesibles en 0x00500000
  - ✅ Imagen se carga correctamente en BRAM
  - ✅ DSA procesa y termina (done=1, busy=0)
  - ✅ Resultado bit a bit idéntico a modelo C++
  - ✅ Performance counters coinciden con estimaciones

---

## 3. Casos de Prueba Detallados

### 3.1 Tabla de Casos de Prueba Unitarios

| ID | Módulo | Entrada | Salida Esperada | Criterio |
|----|--------|---------|-----------------|----------|
| U1.1 | ModoSecuencial | I=128,128,128,128 α=0,β=0 | 128 | ±0 |
| U1.2 | ModoSecuencial | I=0,255,0,255 α=128,β=0 | 127-128 | ±1 |
| U1.3 | ModoSecuencial | I=0,0,255,255 α=0,β=128 | 127-128 | ±1 |
| U1.4 | ModoSecuencial | I=0,85,85,170 α=128,β=128 | 84-86 | ±2 |
| U1.5 | ModoSecuencial | I=255,255,255,255 α=255,β=255 | 255 | Exacto |
| U1.6 | ModoSecuencial | I=0,0,0,0 α=0,β=0 | 0 | Exacto |

### 3.2 Tabla de Casos de Prueba de Integración

| ID | Dimensiones | Factor | Modo | Validación |
|----|-------------|--------|------|------------|
| I1 | 4×4 → 2×2 | 0.5 | Seq | Manual |
| I2 | 8×8 → 4×4 | 0.5 | Seq | vs C++ |
| I3 | 8×8 → 4×4 | 0.5 | SIMD | vs C++ y vs Seq |
| I4 | 16×16 → 8×8 | 0.5 | Seq | vs C++ |
| I5 | 16×16 → 8×8 | 0.5 | SIMD | vs C++ y vs Seq |
| I6 | 128×128 → 64×64 | 0.5 | Seq | vs C++ |
| I7 | 128×128 → 64×64 | 0.5 | SIMD | vs C++ y vs Seq |
| I8 | 128×128 → 96×96 | 0.75 | Both | vs C++ |
| I9 | 256×256 → 128×128 | 0.5 | Both | vs C++ |
| I10 | 512×512 → 256×256 | 0.5 | Both | vs C++ (máximo) |

---

## 4. Procedimiento de Verificación

### 4.1 Simulación (ModelSim/Questa)

```bash
# 1. Compilar testbench
cd simulation/modelsim
vsim -do compile_testbench.do

# 2. Ejecutar test unitario
vsim -do "run tb_ModoSecuencial.sv -all"

# 3. Ejecutar test de integración
vsim -do "run tb_Downscale_Secuencial.sv -all"

# 4. Verificar resultados
# → Debe mostrar "TEST PASSED" en consola
```

### 4.2 Modelo de Referencia C++

```bash
# 1. Compilar modelo
cd modelo_referencia
make

# 2. Generar resultado de referencia
./dsa_downscale both input_512x512.txt 512 512 256 256 ref_output.txt

# 3. Resultados generados:
# - output_seq.txt  (secuencial)
# - output_simd.txt (SIMD)
# - ref_output.txt  (final)
```

### 4.3 Verificación en Hardware

```tcl
# 1. Programar FPGA
# Quartus → Programmer → output_files/ModoSecuencial.sof

# 2. Abrir System Console
# Tools → System Debugging Tools → System Console

# 3. Cargar scripts
cd "C:/Users/sebas/OneDrive/Escritorio/Arqui2-Proyecto"
source tcl/test_basic_jtag.tcl
source tcl/load_image_txt.tcl
source tcl/test_downscale_complete.tcl

# 4. Ejecutar test
connect_jtag
load_image_from_txt "../imagen_grayscale.txt" 512 512

# Modo Secuencial
# [Configurar y ejecutar...]

# Modo SIMD
# [Configurar y ejecutar...]

# 5. Leer resultado
save_output_image "output_fpga_seq.txt" 256 256
```

### 4.4 Comparación Bit a Bit

```bash
# Comparar resultado FPGA vs Modelo C++
diff output_fpga_seq.txt output_seq.txt

# Si no hay diferencias:
echo "✓ Validación exitosa - Resultados idénticos"

# Si hay diferencias:
# → Investigar discrepancias
# → Verificar formato de punto fijo
# → Verificar redondeo y saturación
```

---

## 5. Métricas de Éxito

### 5.1 Criterios Funcionales

| Métrica | Criterio de Éxito |
|---------|-------------------|
| Exactitud | **100%** de píxeles idénticos al modelo C++ |
| Cobertura de estados | **100%** de estados FSM alcanzados |
| Modos operativos | **Ambos** (Seq y SIMD) funcionan |
| Configuraciones | **≥3** tamaños diferentes validados |

### 5.2 Criterios de Rendimiento

| Métrica | Secuencial | SIMD (N=4) | Criterio |
|---------|------------|------------|----------|
| Ciclos/píxel | ~6 | ~1.5 | SIMD ≤ Seq/4 |
| Lecturas/píxel | 4 | 4 | Exacto |
| Escrituras/píxel | 1 | 1 | Exacto |
| FLOPs/píxel | 10 | 10 | Exacto |
| Speedup SIMD | 1× (baseline) | **≥3.5×** | Mínimo aceptable |

### 5.3 Criterios de Recursos

| Recurso | Utilizado | Disponible | Utilización |
|---------|-----------|------------|-------------|
| ALMs | ~9,894 | 32,070 | **31%** ✓ |
| Registros | ~2,969 | - | Aceptable |
| DSP Blocks | 87 | 87 | **100%** (esperado) |
| RAM Blocks | ~321 | 397 | **81%** ✓ |
| Timing @ 50MHz | ✓ | - | Sin violaciones |

---

## 6. Registro de Pruebas

### 6.1 Template de Reporte de Prueba

```markdown
### Test ID: [ID]
**Fecha:** [DD/MM/YYYY]
**Ejecutor:** [Nombre]
**Módulo:** [Nombre del módulo]
**Descripción:** [Breve descripción]

**Configuración:**
- Entrada: [Dimensiones]
- Salida: [Dimensiones]
- Modo: [Seq/SIMD]

**Procedimiento:**
1. [Paso 1]
2. [Paso 2]
...

**Resultados:**
- Esperado: [...]
- Obtenido: [...]
- Diferencias: [N píxeles, X%]

**Estado:** ✅ PASÓ / ❌ FALLÓ

**Observaciones:**
[Comentarios adicionales]
```

### 6.2 Ejemplo de Reporte

```markdown
### Test ID: I6
**Fecha:** 03/12/2025
**Ejecutor:** [Tu nombre]
**Módulo:** Downscale_Secuencial (integración)
**Descripción:** Downscale 128×128 → 64×64, modo secuencial

**Configuración:**
- Entrada: 128×128 = 16,384 píxeles
- Salida: 64×64 = 4,096 píxeles
- Modo: Secuencial
- Factor escala: 0.5

**Procedimiento:**
1. Generar imagen de referencia con modelo C++
2. Ejecutar simulación en ModelSim
3. Comparar output.txt vs referencia
4. Verificar performance counters

**Resultados:**
- Esperado: 4,096 píxeles procesados
- Obtenido: 4,096 píxeles
- Diferencias: 0 píxeles (100% idéntico)
- Cycles: 24,576 (6.0 ciclos/píxel)
- Reads: 16,384 (4.0 lecturas/píxel)
- Writes: 4,096 (1.0 escritura/píxel)

**Estado:** ✅ PASÓ

**Observaciones:**
- Performance coincide con estimaciones
- Sin deadlocks ni timeouts
- FSM funciona correctamente
```

---

## 7. Herramientas de Verificación

### 7.1 Simulación
- **ModelSim/Questa Sim** - Simulación RTL
- **Waveform viewer** - Análisis de señales
- **Testbenches SystemVerilog** - Automatización

### 7.2 Modelo de Referencia
- **C++17** - Modelo funcional
- **Makefiles** - Compilación automatizada
- **Scripts de comparación** - Validación bit a bit

### 7.3 Hardware
- **Quartus Programmer** - Programación FPGA
- **System Console** - Interfaz JTAG
- **SignalTap** - Debug de señales internas (opcional)
- **Scripts TCL** - Automatización de pruebas

---

## 8. Cronograma de Verificación

| Fase | Actividad | Duración | Responsable |
|------|-----------|----------|-------------|
| 1 | Tests unitarios (simulación) | 2 días | [Nombre] |
| 2 | Tests de integración (simulación) | 2 días | [Nombre] |
| 3 | Modelo de referencia C++ | 1 día | [Nombre] |
| 4 | Comparación modelo vs simulación | 1 día | [Nombre] |
| 5 | Programación FPGA | 0.5 días | [Nombre] |
| 6 | Tests en hardware | 1.5 días | [Nombre] |
| 7 | Validación final | 1 día | [Nombre] |
| **Total** | | **9 días** | |

---

## 9. Resultados Esperados

### 9.1 Simulación

**Output esperado de tb_Downscale_Secuencial.sv:**
```
=========================================
  TEST: Downscale 128×128 → 64×64
=========================================
Configurando dimensiones...
Cargando imagen de prueba...
Iniciando procesamiento...

Ciclos:     24576
Reads:      16384  
Writes:     4096
Done:       1

Comparando con referencia...
Diferencias: 0 / 4096 píxeles

TEST PASSED ✓
=========================================
```

### 9.2 Hardware FPGA

**Output esperado de System Console:**
```
PERF_CYCLES:  0x00006000 (24576)
PERF_READS:   0x00004000 (16384)
PERF_WRITES:  0x00001000 (4096)
STATUS:       0x00000002 (done=1, busy=0)

Comparación con modelo C++:
Diferencias: 0 / 4096 píxeles

✓ HARDWARE VALIDADO
```

---

## 10. Manejo de Fallos

### 10.1 Si test de simulación falla

1. Revisar waveforms en ModelSim
2. Verificar transiciones de FSM
3. Verificar señales de control (valid, ready, done)
4. Comparar cálculos intermedios con modelo C++

### 10.2 Si comparación con C++ falla

1. Verificar formato de punto fijo (Q0.8, Q0.16)
2. Verificar redondeo (sumar 0x8000 antes de >>16)
3. Verificar saturación (clamp a 0-255)
4. Verificar cálculo de coordenadas fuente
5. Revisar línea por línea vs código SystemVerilog

### 10.3 Si hardware FPGA falla

1. Verificar que .sof está actualizado (recompilar si es necesario)
2. Ejecutar `tcl/diagnose_busy.tcl` para diagnóstico
3. Verificar conexión JTAG
4. Verificar direcciones de memoria correctas
5. Usar SignalTap para debug interno

---

## 11. Checklist de Entregables

### Plan de Verificación
- [x] Documento completo con casos de prueba
- [x] Procedimientos detallados
- [ ] Resultados de cada prueba documentados
- [ ] Evidencia (screenshots, logs)

### Código
- [x] Testbenches SystemVerilog
- [x] Modelo de referencia C++
- [x] Scripts TCL para hardware
- [ ] Todos los tests ejecutados exitosamente

### Resultados
- [ ] Simulación: Todos los tests pasados
- [ ] Modelo C++: Compilado y funcionando
- [ ] Hardware: Validado en FPGA
- [ ] Comparación bit a bit: 100% idéntico

---

## 12. Conclusiones Esperadas

Al completar este plan de verificación, se habrá demostrado que:

1. ✅ El DSA implementado es **funcionalmente correcto**
2. ✅ Los resultados son **bit a bit idénticos** al modelo de referencia
3. ✅ El modo SIMD logra el **speedup esperado** (≥3.5×)
4. ✅ El sistema es **configurable** para diferentes tamaños
5. ✅ La interfaz JTAG funciona **correctamente**
6. ✅ Los performance counters son **precisos**
7. ✅ El diseño cumple **todos los requisitos** del proyecto

---

**Documento preparado por:** [Tu nombre]  
**Curso:** CE-4302 Arquitectura de Computadores II  
**Semestre:** II-2025  
**Fecha:** Diciembre 2025

