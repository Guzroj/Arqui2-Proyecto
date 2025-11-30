# 📋 RESUMEN TÉCNICO COMPLETO - Proyecto DSA Downscaler con JTAG

**Proyecto:** Downscaler de Imágenes con Interpolación Bilineal  
**Plataforma:** Intel DE1-SoC (Cyclone V 5CSEMA5F31C6)  
**Herramientas:** Quartus Prime 20.1, Platform Designer (Qsys), SystemVerilog  
**Fecha:** Noviembre 2025

---

## 🎯 OBJETIVO DEL PROYECTO

Implementar un acelerador hardware (DSA - Domain-Specific Accelerator) para downscaling de imágenes usando interpolación bilineal, con dos modos de operación:
- **Modo Secuencial:** 1 píxel por ciclo
- **Modo SIMD:** N=4 píxeles paralelos por ciclo

**Interfaz:** Avalon-MM para integración con sistema Qsys y acceso vía JTAG.

---

## 📊 ARQUITECTURA GENERAL

```
┌─────────────────────────────────────────────────────────────┐
│                    FPGA DE1-SoC                             │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │         dsa_system_wrapper (Top Level)               │   │
│  │  - Clock: 50 MHz                                     │   │
│  │  - LEDs: 10 pines                                    │   │
│  │  - SDRAM: 33 pines (16 data + 13 addr + 4 control) │   │
│  └──────────────────┬───────────────────────────────────┘   │
│                     │                                        │
│  ┌──────────────────▼───────────────────────────────────┐   │
│  │         dsa_system (Qsys Generated)                   │   │
│  │                                                       │   │
│  │  ┌──────────────┐  ┌──────────────┐                 │   │
│  │  │ JTAG Master  │  │ SDRAM Ctrl   │                 │   │
│  │  │              │  │ (64MB)       │                 │   │
│  │  └──────┬───────┘  └──────┬───────┘                 │   │
│  │         │                  │                         │   │
│  │         └────────┬─────────┘                         │   │
│  │                  │                                   │   │
│  │         ┌────────▼─────────┐                        │   │
│  │         │ DSA_Avalon_Wrapper│                        │   │
│  │         │  - Control Regs   │                        │   │
│  │         │  - Memory Adapter │                        │   │
│  │         │  - SIMD Core      │                        │   │
│  │         │  - Sequential Core│                        │   │
│  │         └───────────────────┘                        │   │
│  └───────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

---

## 📁 ESTRUCTURA DE ARCHIVOS FINAL

```
Arqui2-Proyecto/
├── rtl/
│   ├── DSA_Control_Registers.sv      ✅ FASE 3.1
│   ├── DSA_Memory_Adapter.sv         ✅ FASE 3.2
│   ├── DSA_Avalon_Wrapper.sv        ✅ FASE 3.3
│   ├── dsa_system_wrapper.sv        ✅ FASE 4.2, 4.5.5
│   ├── Downscale_SIMD.sv            ✅ Existente
│   ├── Downscale_Secuencial.sv      ✅ Existente
│   ├── ModoSecuencial.sv            ✅ Existente
│   ├── ModoSIMD.sv                  ✅ Existente
│   ├── Top_SIMD.sv                  ✅ Existente
│   ├── FSM_SIMD.sv                  ✅ Existente
│   ├── SIMD_Registros.sv            ✅ Existente
│   └── [otros módulos DSA...]       ✅ Existente
│
├── qsys/
│   └── dsa_system/
│       ├── dsa_system.qsys          ✅ FASE 2, 4.5.2
│       └── synthesis/               ✅ Generado por Qsys
│
├── tcl/
│   └── dsa_avalon_wrapper_hw.tcl    ✅ FASE 4.1
│
├── constraints/
│   └── pin_assignments_de1soc.qsf   ✅ FASE 4.5.6
│
└── testbench/                       ✅ Existente
```

---

# 🔧 FASES DE DESARROLLO

---

## ✅ FASE 1: HARDWARE DSA (PRE-EXISTENTE)

### **Objetivo:**
Implementar cores de procesamiento DSA con interpolación bilineal.

### **Archivos Clave:**
- `ModoSecuencial.sv` - Interpolador bilineal (Q0.16)
- `ModoSIMD.sv` - N instancias de ModoSecuencial
- `Downscale_Secuencial.sv` - FSM secuencial (1 píxel/ciclo)
- `Downscale_SIMD.sv` - FSM SIMD (N=4 píxeles/ciclo)

### **Características Técnicas:**
- **Precisión:** Q0.8 para alpha/beta, Q0.16 interno
- **Pipeline:** 1 ciclo de latencia
- **SIMD:** N=4 lanes paralelos
- **Coordenadas:** 32 bits (Q0.8) para 512×512

### **Estado:** ✅ COMPLETADO (pre-existente)

---

## ✅ FASE 2: PLATFORM DESIGNER - Sistema Base

### **Objetivo:**
Crear sistema Qsys con JTAG, memorias y LEDs.

### **Componentes Agregados:**
1. **clk_0** - Clock Source (50 MHz)
2. **reset_bridge_0** - Reset Bridge
3. **jtag_master** - JTAG to Avalon Master Bridge
4. **input_memory** - On-Chip Memory 256KB (eliminada en Fase 4.5)
5. **output_memory** - On-Chip Memory 64KB (eliminada en Fase 4.5)
6. **pio_leds** - PIO para 10 LEDs

### **Mapa de Memoria Inicial:**
```
0x00000000 - 0x0003FFFF : input_memory (256KB)
0x00040000 - 0x0004FFFF : output_memory (64KB)
0x00050000 - 0x0005000F : pio_leds (16 bytes)
```

### **Archivos Generados:**
- `qsys/dsa_system/synthesis/dsa_system.v`
- `qsys/dsa_system/synthesis/submodules/*.v`

### **Estado:** ✅ COMPLETADO

---

## ✅ FASE 3: WRAPPER AVALON - Integración DSA

### **Objetivo:**
Adaptar DSA para interfaz Avalon-MM y crear sistema de control.

---

### **FASE 3.1: DSA_Control_Registers.sv**

**Archivo:** `rtl/DSA_Control_Registers.sv` (195 líneas)

**Función:** Interfaz Avalon-MM Slave para registros de control y estado.

**Registros Implementados (12 registros, 48 bytes):**

| Offset | Nombre | R/W | Bits | Descripción |
|--------|--------|-----|------|-------------|
| 0x00 | CTRL | RW | [31:0] | [0]=start, [1]=reset_counters, [2]=mode (0=Seq, 1=SIMD) |
| 0x04 | STATUS | RO | [31:0] | [0]=busy, [1]=done, [2]=error |
| 0x08 | IMG_WIDTH_IN | RW | [31:0] | Ancho imagen entrada (píxeles) |
| 0x0C | IMG_HEIGHT_IN | RW | [31:0] | Alto imagen entrada (píxeles) |
| 0x10 | IMG_WIDTH_OUT | RW | [31:0] | Ancho imagen salida (píxeles) |
| 0x14 | IMG_HEIGHT_OUT | RW | [31:0] | Alto imagen salida (píxeles) |
| 0x18 | INPUT_BASE | RW | [31:0] | Dirección base memoria entrada |
| 0x1C | OUTPUT_BASE | RW | [31:0] | Dirección base memoria salida |
| 0x20 | PERF_CYCLES | RO | [31:0] | Contador de ciclos de reloj |
| 0x24 | PERF_READS | RO | [31:0] | Contador de lecturas de memoria |
| 0x28 | PERF_WRITES | RO | [31:0] | Contador de escrituras de memoria |
| 0x2C | PERF_FLOPS | RO | [31:0] | Contador de operaciones FP |

**Características:**
- ✅ Auto-clear de pulsos (start, reset_counters)
- ✅ Valores por defecto: 512×512 → 256×256
- ✅ Waitrequest = 0 (transacciones en 1 ciclo)
- ✅ STATUS construido dinámicamente desde señales DSA

**Interfaz:**
```systemverilog
// Avalon-MM Slave
input  logic [3:0]  avs_address;      // 4 bits = 16 registros
input  logic        avs_read;
input  logic        avs_write;
input  logic [31:0] avs_writedata;
output logic [31:0] avs_readdata;
output logic        avs_waitrequest;

// Control hacia DSA
output logic        dsa_start;
output logic        dsa_reset_counters;
output logic        dsa_mode;
output logic [31:0] dsa_img_width_in/out;
output logic [31:0] dsa_img_height_in/out;
output logic [31:0] dsa_input_base;
output logic [31:0] dsa_output_base;

// Estado desde DSA
input  logic        dsa_busy;
input  logic        dsa_done;
input  logic        dsa_error;
input  logic [31:0] dsa_perf_cycles/reads/writes/flops;
```

---

### **FASE 3.2: DSA_Memory_Adapter.sv**

**Archivo:** `rtl/DSA_Memory_Adapter.sv` (301 líneas)

**Función:** Adaptador que convierte interfaz byte-wise del DSA a Avalon-MM (word-based).

**Problema Resuelto:**
- DSA usa direcciones de **byte** (8 bits)
- Avalon-MM usa direcciones de **word** (32 bits)
- Necesita conversión y extracción de bytes

**Arquitectura:**

```
┌─────────────────────────────────────────┐
│     DSA_Memory_Adapter                  │
├─────────────────────────────────────────┤
│                                         │
│  ┌──────────────┐      ┌─────────────┐│
│  │ SIMD Mode    │      │ Seq Mode    ││
│  │ (N requests) │      │ (1 request) ││
│  └──────┬───────┘      └──────┬──────┘│
│         │                     │        │
│         └──────────┬──────────┘        │
│                    │                   │
│         ┌──────────▼──────────┐        │
│         │  Arbitrador         │        │
│         │  (Prioridad: Write) │        │
│         └──────────┬──────────┘        │
│                    │                   │
│         ┌──────────▼──────────┐        │
│         │ Byte→Word Converter │        │
│         │ + Byte Extractor    │        │
│         └──────────┬──────────┘        │
│                    │                   │
│         ┌──────────▼──────────┐        │
│         │ Avalon-MM Master    │        │
│         └─────────────────────┘        │
└─────────────────────────────────────────┘
```

**Funcionalidades:**

1. **Serialización de Lecturas SIMD:**
   - N requests paralelas → 1 transacción Avalon a la vez
   - Round-robin entre lanes

2. **Conversión Byte → Word:**
   ```systemverilog
   word_address = base_addr + (byte_addr >> 2);
   byte_offset  = byte_addr[1:0];
   ```

3. **Extracción de Byte:**
   ```systemverilog
   case (byte_offset)
       2'b00: byte = avm_readdata[7:0];
       2'b01: byte = avm_readdata[15:8];
       2'b10: byte = avm_readdata[23:16];
       2'b11: byte = avm_readdata[31:24];
   endcase
   ```

4. **Escrituras Directas:**
   - Forward inmediato a Avalon-MM
   - Byte enable según offset
   - Sin buffers intermedios

5. **Performance Counters:**
   - `perf_mem_reads`: +1 por cada `avm_read`
   - `perf_mem_writes`: +1 por cada `avm_write`

**Interfaz:**

```systemverilog
// SIMD - Lecturas (N puertos)
input  logic        simd_mem_rd_req   [N];
input  logic [31:0] simd_mem_rd_addr  [N];
output logic        simd_mem_rd_valid [N];
output logic [7:0]  simd_mem_rd_data  [N];

// SIMD - Escrituras (directas)
input  logic        simd_wr_req;
input  logic [31:0] simd_wr_addr;
input  logic [7:0]  simd_wr_data;

// Secuencial - Lecturas
input  logic        seq_mem_rd_req;
input  logic [31:0] seq_mem_rd_addr;
output logic        seq_mem_rd_valid;
output logic [7:0]  seq_mem_rd_data;

// Secuencial - Escrituras
input  logic        seq_wr_req;
input  logic [31:0] seq_wr_addr;
input  logic [7:0]  seq_wr_data;

// Avalon-MM Master
output logic [31:0] avm_address;
output logic        avm_read;
output logic        avm_write;
output logic [31:0] avm_writedata;
output logic [3:0]  avm_byteenable;
input  logic        avm_waitrequest;
input  logic [31:0] avm_readdata;
input  logic        avm_readdatavalid;
```

**FSM de Arbitraje:**
```
ARB_IDLE
  ├─ write_req → ARB_WRITE (prioridad)
  └─ read_req  → ARB_READ

ARB_WRITE → Emite avm_write → ARB_IDLE
ARB_READ  → Emite avm_read → Espera readdatavalid → ARB_IDLE
```

---

### **FASE 3.3: DSA_Avalon_Wrapper.sv**

**Archivo:** `rtl/DSA_Avalon_Wrapper.sv` (240 líneas)

**Función:** Wrapper principal que integra todos los componentes DSA.

**Componentes Integrados:**

1. **DSA_Control_Registers** - Registros de control
2. **DSA_Memory_Adapter** - Adaptador de memoria
3. **Downscale_SIMD** - Core SIMD (N=4)
4. **Downscale_Secuencial** - Core secuencial

**Lógica de Control:**

```systemverilog
// Selección de modo
dsa_start && dsa_mode == 1'b1 → Downscale_SIMD
dsa_start && dsa_mode == 1'b0 → Downscale_Secuencial

// Señal de busy
dsa_busy = dsa_core_running  // Core activo

// Señal de done
dsa_done = (dsa_mode ? simd_done : seq_done)  // Inmediato
```

**Performance Counters:**

1. **perf_cycles:**
   - Cuenta mientras `dsa_busy = 1`
   - Reset con `dsa_reset_counters`

2. **perf_reads/writes:**
   - Desde `adapter_perf_reads/writes`

3. **perf_flops:**
   - Calculado: `DST_W × DST_H × 10`
   - ~10 operaciones por píxel interpolado

**Parámetros:**
```systemverilog
parameter int N = 4;              // SIMD lanes
parameter int MAX_SRC_W = 512;    // Máximo ancho entrada
parameter int MAX_SRC_H = 512;    // Máximo alto entrada
parameter int MAX_DST_W = 512;    // Máximo ancho salida
parameter int MAX_DST_H = 512;    // Máximo alto salida
```

**Interfaz Avalon-MM:**

```systemverilog
// Slave (Registros)
input  logic [3:0]  avs_ctrl_address;
input  logic        avs_ctrl_read;
input  logic        avs_ctrl_write;
input  logic [31:0] avs_ctrl_writedata;
output logic [31:0] avs_ctrl_readdata;
output logic        avs_ctrl_waitrequest;

// Master (Memorias)
output logic [31:0] avm_mem_address;
output logic        avm_mem_read;
output logic        avm_mem_write;
output logic [31:0] avm_mem_writedata;
output logic [3:0]  avm_mem_byteenable;
input  logic        avm_mem_waitrequest;
input  logic [31:0] avm_mem_readdata;
input  logic        avm_mem_readdatavalid;
```

**Estado:** ✅ COMPLETADO

---

## ✅ FASE 4: INTEGRACIÓN QSYS Y TOP LEVEL

---

### **FASE 4.1: Componente IP para Platform Designer**

**Archivo:** `tcl/dsa_avalon_wrapper_hw.tcl` (200+ líneas)

**Función:** Define el DSA como componente IP reutilizable en Platform Designer.

**Características:**
- ✅ Metadatos del componente (nombre, versión, descripción)
- ✅ Archivos HDL incluidos (todos los módulos DSA)
- ✅ Parámetros configurables (N, MAX_SRC/DST)
- ✅ Interfaces Avalon-MM (Slave + Master)
- ✅ Validación de parámetros

**Uso:**
```
Platform Designer → IP Catalog → Buscar "DSA"
→ Agregar al sistema con parámetros deseados
```

---

### **FASE 4.2: Actualizar System Wrapper**

**Archivo:** `rtl/dsa_system_wrapper.sv` (67 líneas)

**Función:** Top-level que conecta Qsys con pines FPGA.

**Modificaciones:**
- ✅ Actualizado para DE1-SoC (antes decía DE10-Lite)
- ✅ Power-on reset generator
- ✅ Instancia de `dsa_system` (generado por Qsys)

**Interfaz FPGA:**
```systemverilog
input  logic        clk;              // 50 MHz
output logic [9:0]  LEDR;             // 10 LEDs
// SDRAM (agregado en Fase 4.5)
output logic [12:0] DRAM_ADDR;
output logic [1:0]  DRAM_BA;
output logic        DRAM_CAS_N;
output logic        DRAM_CKE;
output logic        DRAM_CLK;
output logic        DRAM_CS_N;
inout  wire  [15:0] DRAM_DQ;
output logic        DRAM_LDQM;
output logic        DRAM_RAS_N;
output logic        DRAM_UDQM;
output logic        DRAM_WE_N;
```

---

### **FASE 4.3: Agregar Archivos a Quartus**

**Acción:** Verificar que todos los archivos RTL estén en el proyecto.

**Archivos Agregados:**
- ✅ DSA_Control_Registers.sv
- ✅ DSA_Memory_Adapter.sv
- ✅ DSA_Avalon_Wrapper.sv
- ✅ Todos los módulos DSA existentes
- ✅ dsa_system_wrapper.sv
- ✅ qsys/dsa_system/synthesis/dsa_system.qip

---

### **FASE 4.4: Compilación Completa**

**Resultado:**
- ✅ Analysis & Synthesis exitoso
- ✅ Fitter (Place & Route) exitoso
- ✅ Timing verificado
- ✅ Archivo .sof generado

**Tiempos de Compilación:**
- Con arrays 512×512: ~30-40 minutos
- Con arrays 256×256: ~8-14 minutos
- Con arrays 128×128: ~3-5 minutos

---

### **FASE 4.5: INTEGRACIÓN SDRAM (BONUS +10%)**

---

#### **FASE 4.5.1: Preparación**

**Acción:** Cancelar compilación y abrir Platform Designer.

---

#### **FASE 4.5.2: Agregar SDRAM Controller**

**Componente:** SDRAM Controller Intel FPGA IP

**Configuración:**
- **Chip:** IS42S16320D-7TL (64MB, 16 bits)
- **Data Width:** 16 bits
- **Banks:** 4
- **Rows:** 13 bits (8192)
- **Columns:** 10 bits (1024)
- **CAS Latency:** 3 ciclos
- **Timing:** Optimizado para 50 MHz

**Conexiones:**
- Clock: `clk_0.clk`
- Reset: `reset_bridge_0.out_reset`
- Masters: `jtag_master.master`, `dsa_avalon_wrapper.avalon_master`

**Dirección Base:** `0x00000000` (64MB)

---

#### **FASE 4.5.3: Eliminar On-Chip Memories**

**Acción:** Remover `input_memory` y `output_memory` del sistema Qsys.

**Razón:** SDRAM reemplaza completamente las memorias on-chip.

---

#### **FASE 4.5.4: Exportar Señales SDRAM**

**Acción:** Exportar interfaz `wire` del SDRAM Controller como `sdram`.

**Señales Exportadas:**
- `sdram.addr[12:0]`
- `sdram.ba[1:0]`
- `sdram.cas_n`
- `sdram.cke`
- `sdram.cs_n`
- `sdram.dq[15:0]`
- `sdram.dqm[1:0]`
- `sdram.ras_n`
- `sdram.we_n`
- `sdram_clk.clk`

---

#### **FASE 4.5.5: Actualizar dsa_system_wrapper.sv**

**Modificaciones:**
- ✅ Agregados 11 puertos SDRAM
- ✅ Conectado `DRAM_CLK = clk` (50 MHz directo)
- ✅ Conectado todas las señales SDRAM al sistema Qsys

**Mapa de Memoria Final:**
```
0x00000000 - 0x03FFFFFF : SDRAM (64MB)
0x04000000 - 0x040000FF : pio_leds (256 bytes)
0x04000100 - 0x0400012F : dsa_avalon_wrapper (48 bytes)
```

---

#### **FASE 4.5.6: Pin Assignments y Compilación**

**Acción:** Asignar ~33 pines SDRAM según manual DE1-SoC.

**Archivo:** `constraints/pin_assignments_de1soc.qsf`

**Pines SDRAM:**
- DRAM_ADDR[12:0] → Pines específicos DE1-SoC
- DRAM_BA[1:0] → Pines específicos
- DRAM_DQ[15:0] → Pines bidireccionales
- DRAM_*_N → Señales de control

**Compilación Final:**
- ✅ Analysis & Elaboration exitoso
- ✅ Compilación completa exitosa
- ✅ Timing verificado
- ✅ Archivo .sof listo para programar

---

## 📊 ANÁLISIS TÉCNICO DE LOS 3 MÓDULOS DSA

---

### **1. DSA_Control_Registers.sv**

#### **Arquitectura:**

```
┌─────────────────────────────────────┐
│  DSA_Control_Registers              │
├─────────────────────────────────────┤
│                                     │
│  ┌──────────────────────────────┐   │
│  │  Avalon-MM Slave Interface   │   │
│  │  - address[3:0]              │   │
│  │  - read/write                │   │
│  │  - readdata/writedata[31:0]  │   │
│  └──────────┬───────────────────┘   │
│             │                       │
│  ┌──────────▼───────────────────┐   │
│  │  Banco de Registros (R/W)    │   │
│  │  - reg_ctrl                  │   │
│  │  - reg_img_width_in/out      │   │
│  │  - reg_img_height_in/out      │   │
│  │  - reg_input/output_base      │   │
│  └──────────┬───────────────────┘   │
│             │                       │
│  ┌──────────▼───────────────────┐   │
│  │  Lógica de Auto-Clear        │   │
│  │  - start (1 ciclo)           │   │
│  │  - reset_counters (1 ciclo)  │   │
│  └──────────┬───────────────────┘   │
│             │                       │
│  ┌──────────▼───────────────────┐   │
│  │  STATUS (combinacional)       │   │
│  │  - busy, done, error          │   │
│  └───────────────────────────────┘   │
└─────────────────────────────────────┘
```

#### **Características Clave:**

1. **Auto-Clear de Pulsos:**
   ```systemverilog
   // start se limpia automáticamente después de 1 ciclo
   if (reg_ctrl[0]) begin
       reg_ctrl[0] <= 1'b0;  // Auto-clear
   end
   ```
   - Genera pulsos de 1 ciclo
   - Evita que el usuario tenga que limpiar manualmente

2. **Registro STATUS Dinámico:**
   ```systemverilog
   always_comb begin
       reg_status[0] = dsa_busy;
       reg_status[1] = dsa_done;
       reg_status[2] = dsa_error;
   end
   ```
   - Se actualiza en tiempo real
   - No requiere escritura

3. **Valores por Defecto:**
   ```systemverilog
   reg_img_width_in   <= 32'd512;
   reg_img_height_in  <= 32'd512;
   reg_img_width_out  <= 32'd256;
   reg_img_height_out <= 32'd256;
   reg_input_base     <= 32'h00000000;
   reg_output_base    <= 32'h00040000;
   ```
   - Sistema funcional sin configuración inicial
   - Útil para testing rápido

#### **Análisis de Timing:**

- **Read Latency:** 1 ciclo (waitrequest = 0)
- **Write Latency:** 1 ciclo
- **Throughput:** 1 transacción/ciclo

#### **Recursos Estimados:**
- **LUTs:** ~200
- **FFs:** ~250 (7 registros × 32 bits + lógica de control)
- **BRAM:** 0 (solo registros)

---

### **2. DSA_Memory_Adapter.sv**

#### **Arquitectura:**

```
┌─────────────────────────────────────────────┐
│      DSA_Memory_Adapter                     │
├─────────────────────────────────────────────┤
│                                             │
│  ┌──────────────┐      ┌──────────────┐    │
│  │ SIMD Mode    │      │ Seq Mode     │    │
│  │ N requests   │      │ 1 request    │    │
│  └──────┬───────┘      └──────┬───────┘    │
│         │                     │             │
│         └──────────┬──────────┘             │
│                    │                        │
│         ┌──────────▼──────────┐             │
│         │  Arbitrador FSM     │             │
│         │  - ARB_IDLE         │             │
│         │  - ARB_WRITE        │             │
│         │  - ARB_READ         │             │
│         └──────────┬──────────┘             │
│                    │                        │
│         ┌──────────▼──────────┐             │
│         │  Byte→Word Converter│             │
│         │  - addr >> 2        │             │
│         │  - byte_offset[1:0] │             │
│         └──────────┬──────────┘             │
│                    │                        │
│         ┌──────────▼──────────┐             │
│         │  Byte Extractor     │             │
│         │  - readdata[7:0]    │             │
│         │  - readdata[15:8]   │             │
│         │  - readdata[23:16]  │             │
│         │  - readdata[31:24]  │             │
│         └──────────┬──────────┘             │
│                    │                        │
│         ┌──────────▼──────────┐             │
│         │  Avalon-MM Master   │             │
│         │  - address[31:0]    │             │
│         │  - read/write       │             │
│         │  - byteenable[3:0]  │             │
│         └─────────────────────┘             │
└─────────────────────────────────────────────┘
```

#### **Características Clave:**

1. **Serialización de Lecturas SIMD:**
   ```systemverilog
   // Procesa 1 lane a la vez
   for (int k = 0; k < N; k++) begin
       if (!found && simd_mem_rd_req[k]) begin
           avm_read <= 1'b1;
           read_lane_idx <= k;
           found = 1'b1;
       end
   end
   ```
   - **Latencia:** N ciclos para servir N requests
   - **Throughput:** 1 request/ciclo

2. **Conversión Byte → Word:**
   ```systemverilog
   word_address = base_addr + (byte_addr >> 2);
   byte_offset  = byte_addr[1:0];
   ```
   - **División por 4:** Shift de 2 bits
   - **Offset:** Bits [1:0] para selección de byte

3. **Arbitraje:**
   - **Prioridad:** Escrituras > Lecturas
   - **Razón:** Escrituras son críticas (no se pueden perder)
   - **FSM:** 3 estados (IDLE, WRITE, READ)

4. **Performance Counters:**
   ```systemverilog
   if (avm_read)  perf_mem_reads  <= perf_mem_reads + 1;
   if (avm_write) perf_mem_writes <= perf_mem_writes + 1;
   ```
   - Contadores de 32 bits
   - Reset con señal externa

#### **Análisis de Timing:**

- **Read Latency:**
  - Request → Avalon: 1 ciclo
  - Avalon → Response: Variable (depende de SDRAM, ~10-20 ciclos)
  - **Total:** ~11-21 ciclos

- **Write Latency:**
  - Request → Avalon: 1 ciclo
  - Avalon → Complete: Variable (depende de waitrequest)
  - **Total:** ~2-5 ciclos

#### **Recursos Estimados:**
- **LUTs:** ~500
- **FFs:** ~150 (contadores + FSM + registros de estado)
- **BRAM:** 0 (sin buffers)

---

### **3. DSA_Avalon_Wrapper.sv**

#### **Arquitectura:**

```
┌─────────────────────────────────────────────┐
│      DSA_Avalon_Wrapper                     │
├─────────────────────────────────────────────┤
│                                             │
│  ┌──────────────────────────────────────┐   │
│  │  DSA_Control_Registers               │   │
│  │  (Avalon-MM Slave)                   │   │
│  └──────────┬───────────────────────────┘   │
│             │                               │
│  ┌──────────▼───────────────────────────┐   │
│  │  Señales de Control                 │   │
│  │  - dsa_start, mode, dimensions      │   │
│  └──────────┬───────────────────────────┘   │
│             │                               │
│  ┌──────────┴──────────┐                   │
│  │                     │                   │
│  ▼                     ▼                   │
│  ┌──────────┐  ┌──────────────┐           │
│  │ SIMD     │  │ Secuencial   │           │
│  │ Core     │  │ Core         │           │
│  │ (N=4)    │  │ (N=1)        │           │
│  └────┬─────┘  └──────┬───────┘           │
│       │               │                   │
│       └───────┬───────┘                     │
│               │                             │
│  ┌────────────▼──────────────┐              │
│  │  DSA_Memory_Adapter       │              │
│  │  (Avalon-MM Master)       │              │
│  └────────────┬──────────────┘              │
│               │                              │
│  ┌────────────▼──────────────┐              │
│  │  Performance Counters    │              │
│  │  - cycles                │              │
│  │  - reads/writes          │              │
│  │  - FLOPs                 │              │
│  └───────────────────────────┘              │
└─────────────────────────────────────────────┘
```

#### **Características Clave:**

1. **Selección de Modo:**
   ```systemverilog
   // SIMD
   .start(dsa_start && dsa_mode == 1'b1)
   
   // Secuencial
   .start(dsa_start && dsa_mode == 1'b0)
   ```
   - Solo un core activo a la vez
   - Selección por bit de control

2. **Lógica de Estado:**
   ```systemverilog
   // Busy: Core corriendo
   dsa_busy = dsa_core_running;
   
   // Done: Core terminó
   dsa_done = (dsa_mode ? simd_done : seq_done);
   ```
   - **Busy:** Flip-flop que se activa con start
   - **Done:** Combinacional desde señal del core

3. **Performance Counter - Ciclos:**
   ```systemverilog
   if (dsa_busy) begin
       dsa_perf_cycles <= dsa_perf_cycles + 1;
   end
   ```
   - Cuenta mientras procesa
   - Reset con señal externa

4. **Performance Counter - FLOPs:**
   ```systemverilog
   if (dsa_done && !flops_counted) begin
       dsa_perf_flops <= total_pixels * 32'd10;
       flops_counted <= 1'b1;
   end
   ```
   - Calculado al finalizar
   - ~10 operaciones por píxel

#### **Análisis de Timing:**

- **Start → Processing:** 1 ciclo (propagación de señal)
- **Processing Time:**
  - Secuencial: ~(DST_W × DST_H) ciclos
  - SIMD: ~(DST_W × DST_H / N) ciclos
- **Done Signal:** Inmediato cuando core termina

#### **Recursos Estimados:**
- **LUTs:** ~1000 (wrapper + lógica de control)
- **FFs:** ~200 (contadores + estado)
- **BRAM:** 0 (sin arrays internos en versión optimizada)

---

## 🔗 CONEXIONES ENTRE MÓDULOS

### **Flujo de Datos:**

```
JTAG Master
    │
    ├─→ DSA_Control_Registers (avalon_slave)
    │       │
    │       ├─→ dsa_start, mode, dimensions
    │       │
    │       └─→ DSA_Avalon_Wrapper
    │               │
    │               ├─→ Downscale_SIMD (si mode=1)
    │               │       │
    │               │       └─→ DSA_Memory_Adapter
    │               │               │
    │               │               └─→ SDRAM (avalon_master)
    │               │
    │               └─→ Downscale_Secuencial (si mode=0)
    │                       │
    │                       └─→ DSA_Memory_Adapter
    │                               │
    │                               └─→ SDRAM
```

### **Señales de Control:**

```
DSA_Control_Registers
    ├─→ dsa_start ──────────────→ DSA_Avalon_Wrapper
    ├─→ dsa_mode ───────────────→ DSA_Avalon_Wrapper
    ├─→ dsa_img_* ──────────────→ DSA_Avalon_Wrapper
    │                                   │
    │                                   └─→ DSA_Memory_Adapter
    │
    └─← dsa_busy, done, perf_* ←─────── DSA_Avalon_Wrapper
```

---

## 📈 MÉTRICAS DE PERFORMANCE

### **Throughput Teórico:**

**Modo Secuencial:**
- **Píxeles/ciclo:** 1
- **Tiempo (256×256):** ~65,536 ciclos = ~1.3 ms @ 50 MHz
- **Tiempo (512×512):** ~262,144 ciclos = ~5.2 ms @ 50 MHz

**Modo SIMD (N=4):**
- **Píxeles/ciclo:** 4 (teórico), ~1 (real por serialización)
- **Tiempo (256×256):** ~65,536 ciclos = ~1.3 ms @ 50 MHz
- **Tiempo (512×512):** ~262,144 ciclos = ~5.2 ms @ 50 MHz

**Nota:** SIMD no mejora mucho debido a serialización de lecturas en el adaptador.

### **Latencia de Memoria:**

- **SDRAM Read:** ~10-20 ciclos
- **SDRAM Write:** ~2-5 ciclos
- **Impacto:** Significativo en throughput real

---

## 🎯 ESTADO FINAL DEL PROYECTO

### **✅ COMPLETADO:**

- ✅ Fase 1: Hardware DSA (pre-existente)
- ✅ Fase 2: Sistema Qsys base
- ✅ Fase 3: Wrapper Avalon completo
- ✅ Fase 4: Integración Qsys y compilación
- ✅ Fase 4.5: Integración SDRAM (bonus)

### **📦 ARCHIVOS CREADOS:**

1. `rtl/DSA_Control_Registers.sv` (195 líneas)
2. `rtl/DSA_Memory_Adapter.sv` (301 líneas)
3. `rtl/DSA_Avalon_Wrapper.sv` (240 líneas)
4. `rtl/dsa_system_wrapper.sv` (67 líneas, modificado)
5. `tcl/dsa_avalon_wrapper_hw.tcl` (200+ líneas)
6. `qsys/dsa_system.qsys` (modificado)

### **🔧 ARCHIVOS MODIFICADOS:**

- `rtl/dsa_system_wrapper.sv` - Agregadas señales SDRAM
- `qsys/dsa_system.qsys` - Agregado SDRAM Controller, eliminadas memorias on-chip

### **📊 RECURSOS FPGA ESTIMADOS:**

- **Logic Elements:** ~15,000-20,000 LUTs
- **Memory Bits:** ~0 (sin arrays internos)
- **M10K Blocks:** ~5-10 (para SDRAM controller)
- **PLLs:** 0 (clock directo 50 MHz)
- **I/O Pins:** ~43 (clk + 10 LEDs + 33 SDRAM)

---

## 🚀 PRÓXIMOS PASOS (FASE 5)

### **Scripts TCL para JTAG:**

1. **Cargar imagen** (PC → SDRAM)
2. **Configurar DSA** (dimensiones, modo)
3. **Iniciar procesamiento**
4. **Leer resultado** (SDRAM → PC)
5. **Leer performance counters**

---

## 📝 NOTAS FINALES

### **Optimizaciones Realizadas:**

1. ✅ **Eliminación de arrays internos** - Escrituras directas a SDRAM
2. ✅ **Serialización eficiente** - Arbitraje entre lecturas/escrituras
3. ✅ **Performance counters** - Métricas completas de operación

### **Limitaciones Conocidas:**

1. ⚠️ **Serialización SIMD** - N requests se procesan secuencialmente
2. ⚠️ **Latencia SDRAM** - Impacta throughput real
3. ⚠️ **Parámetros fijos** - MAX_DST debe ser >= dimensiones reales

### **Mejoras Futuras:**

1. 🔮 **Burst reads** - Mejorar throughput SIMD
2. 🔮 **Cache local** - Reducir latencia SDRAM
3. 🔮 **Pipeline más profundo** - Overlap de operaciones

---

**FIN DEL RESUMEN TÉCNICO**

