# FASE 6: Integración JTAG y Control de Sistema

## Arquitectura de Computadores 2 - Proyecto de Downscaling

---

## Descripción General

La **FASE 6** integra todo el sistema de downscaling desarrollado en las fases anteriores con una interfaz de control JTAG. Esto permite:

- Cargar imágenes de entrada (64×64) en la memoria del FPGA
- Controlar el procesamiento de downscaling
- Leer las imágenes de salida (32×32) procesadas
- Monitorear el estado del sistema en tiempo real

El sistema completo es controlado remotamente desde un PC mediante un servidor TCL y un cliente Python.

---

## Arquitectura del Sistema

```
┌─────────────────────────────────────────────────────────────┐
│                           PC (Host)                          │
│  ┌────────────────────┐         ┌─────────────────────────┐ │
│  │ Python Client      │◄───────►│ TCL Server              │ │
│  │ downscale_client.py│  Socket │ jtag_downscale_server.tcl│ │
│  └────────────────────┘         └──────────┬──────────────┘ │
│                                            │ JTAG Commands   │
└────────────────────────────────────────────┼─────────────────┘
                                             │
                                   ┌─────────▼──────────┐
                                   │   USB-Blaster      │
                                   │   JTAG Interface   │
                                   └─────────┬──────────┘
                                             │
┌────────────────────────────────────────────┼─────────────────┐
│                        FPGA (Cyclone V)    │                 │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Virtual JTAG IP (Quartus)                           │   │
│  └──────────────────┬───────────────────────────────────┘   │
│                     │                                        │
│  ┌──────────────────▼───────────────────────────────────┐   │
│  │  jtag_avalon_controller.sv                           │   │
│  │  (40-bit command decoder)                            │   │
│  └──────────────────┬───────────────────────────────────┘   │
│                     │                                        │
│  ┌──────────────────▼───────────────────────────────────┐   │
│  │  jtag_register_map.sv                                │   │
│  │  (7 registers: CONTROL, STATUS, MEM_ACCESS, etc.)    │   │
│  └──┬────────────┬────────────┬──────────────────────┬──┘   │
│     │            │            │                      │       │
│  ┌──▼────┐  ┌───▼──────┐  ┌──▼────────────┐  ┌─────▼────┐ │
│  │Input  │  │Output    │  │downscale_      │  │FSM       │ │
│  │Memory │  │Memory    │  │sequential      │  │Control   │ │
│  │64×64  │  │32×32     │  │(Pipeline)      │  │          │ │
│  │4096B  │  │1024B     │  │                │  │          │ │
│  └───────┘  └──────────┘  └────────────────┘  └──────────┘ │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

---

## Componentes del Sistema

### 1. Módulos RTL (SystemVerilog)

#### a. `jtag_register_map.sv`
**Ubicación:** `rtl/jtag/jtag_register_map.sv`

**Función:** Banco de registros accesibles via JTAG para control y monitoreo del sistema.

**Registros:**

| Dirección | Nombre           | Tipo | Descripción                                      |
|-----------|------------------|------|--------------------------------------------------|
| `0x00`    | CONTROL          | R/W  | [7]: busy, [1]: reset, [0]: start                |
| `0x01`    | STATUS           | R    | [10:8]: fsm_state, [0]: done                     |
| `0x02`    | IMG_WR_ADDR      | R/W  | Dirección de escritura en memoria de entrada     |
| `0x03`    | IMG_WR_DATA      | W    | Escribir píxel (auto-incrementa dirección)       |
| `0x04`    | IMG_RD_ADDR      | R/W  | Dirección de lectura en memoria de salida        |
| `0x05`    | IMG_RD_DATA      | R    | Leer píxel (auto-incrementa dirección)           |
| `0x06`    | PIXEL_COUNT      | R    | Contador de píxeles procesados (0-1024)          |

**Características:**
- Auto-incremento de direcciones para transferencias eficientes
- Latencia de 1 ciclo en lecturas de memoria
- Señales de control con pulsos de 1 ciclo

#### b. `jtag_avalon_controller.sv`
**Ubicación:** `rtl/jtag/jtag_avalon_controller.sv`

**Función:** Interfaz entre JTAG Virtual y el banco de registros.

**Protocolo de Comandos (40 bits):**
```
[39]     = R/W (1=Write, 0=Read)
[38:31]  = Address (8 bits)
[31:0]   = Data (para Write) / Reserved (para Read)
```

**Estados de la FSM:**
- `IDLE`: Esperando comando
- `CAPTURE`: Capturar estado inicial
- `SHIFT`: Recibir comando serial (LSB primero)
- `EXECUTE_WRITE`: Escribir registro
- `EXECUTE_READ`: Leer registro
- `WAIT_RESPONSE`: Esperar validación de lectura
- `UPDATE`: Actualizar salida

#### c. `top_downscale_system.sv`
**Ubicación:** `rtl/top_downscale_system.sv`

**Función:** Integración completa del sistema.

**Componentes instanciados:**
1. Virtual JTAG IP (Quartus)
2. JTAG Avalon Controller
3. JTAG Register Map
4. Memoria de entrada (64×64)
5. Memoria de salida (32×32)
6. Downscaler secuencial con pipeline

**Señales de Debug (LEDs):**
- `LEDR[0]`: done
- `LEDR[1]`: busy
- `LEDR[2]`: start_processing
- `LEDR[3]`: reset_memories
- `LEDR[9:4]`: pixels_written[5:0]

### 2. Software de Control

#### a. Servidor TCL: `jtag_downscale_server.tcl`
**Ubicación:** `software/tcl/server/jtag_downscale_server.tcl`

**Función:** Servidor TCP que traduce comandos de alto nivel a operaciones JTAG.

**Funciones principales:**

```tcl
# Funciones de bajo nivel
openport                    # Abrir conexión JTAG
closeport                   # Cerrar conexión JTAG
jtag_shift_40bit {rw addr data}  # Ejecutar comando JTAG

# Funciones de registros
write_register {addr data}  # Escribir registro
read_register {addr}        # Leer registro

# Funciones de control
start_downscaling           # Iniciar procesamiento
reset_system                # Resetear memorias
get_status                  # Obtener estado
wait_for_completion {timeout_ms}  # Esperar terminación

# Funciones de transferencia
upload_image {image_data}   # Subir imagen 64×64
download_image              # Descargar imagen 32×32
process_image {input_image} # Proceso completo
```

**Comandos del socket:**
- `STATUS`: Obtener estado del sistema
- `START`: Iniciar downscaling
- `RESET`: Resetear memorias
- `UPLOAD <n> <pixels>`: Subir imagen
- `DOWNLOAD`: Descargar imagen
- `PROCESS <n> <pixels>`: Proceso completo
- `CLOSE`: Cerrar conexión

**Puerto:** 2540

#### b. Cliente Python: `downscale_client.py`
**Ubicación:** `software/python/client/downscale_client.py`

**Función:** Cliente de alto nivel para uso desde Python.

**Clase principal:**

```python
class JTAGDownscaleClient:
    def __init__(host, port)
    def connect()
    def disconnect()
    def get_status() -> (busy, done, fsm_state, pixel_count)
    def print_status()
    def start_processing()
    def reset_system()
    def upload_image(image_data: np.ndarray)
    def download_image() -> np.ndarray
    def process_image(image_data: np.ndarray) -> np.ndarray
```

**Funciones de utilidad:**

```python
create_test_pattern(pattern_type)  # Crear patrón de prueba
save_image_txt(image, filename)    # Guardar imagen como texto
load_image_txt(filename)           # Cargar imagen desde texto
print_image_ascii(image)           # Mostrar imagen como ASCII art
```

**Dependencias:**
- Python 3.6+
- NumPy (`pip install numpy`)

---

## Flujo de Operación

### Secuencia Completa de Procesamiento

```
1. PC: Iniciar servidor TCL
   └─► tcl: jtag_downscale_server.tcl

2. PC: Ejecutar cliente Python
   └─► python: downscale_client.py

3. Cliente se conecta al servidor (socket TCP)
   └─► Conexión establecida en puerto 2540

4. Cliente envía imagen 64×64
   └─► Servidor ejecuta: upload_image()
       ├─► write_register(IMG_WR_ADDR, 0)
       └─► Loop 4096 veces:
           └─► write_register(IMG_WR_DATA, pixel[i])
               └─► JTAG: Shift 40 bits (W, 0x03, pixel)
                   └─► FPGA: Escribir en memoria de entrada
                       └─► Auto-incrementar dirección

5. Cliente inicia procesamiento
   └─► Servidor ejecuta: start_downscaling()
       └─► write_register(CONTROL, 0x01)
           └─► JTAG: Shift 40 bits (W, 0x00, 0x01)
               └─► FPGA: start_processing = 1 por 1 ciclo
                   └─► FSM: IDLE → READ_P00

6. FPGA procesa imagen (secuencial)
   Loop 1024 iteraciones (píxeles de salida):
   ├─► READ_P00: Leer píxel (x0, y0)
   ├─► READ_P01: Leer píxel (x1, y0)
   ├─► READ_P10: Leer píxel (x0, y1)
   ├─► READ_P11: Leer píxel (x1, y1)
   ├─► INTERPOLATE: Pipeline (8 ciclos)
   │   ├─► Stage 1: Interpolación horizontal
   │   ├─► Stage 2: Interpolación vertical
   │   └─► Stage 3: Conversión Q8.8 → 8-bit
   └─► WRITE_RESULT: Escribir píxel en memoria de salida

7. Cliente monitorea progreso (polling)
   └─► Loop cada 200ms:
       └─► read_register(STATUS)
       └─► read_register(PIXEL_COUNT)
       └─► Mostrar progreso
       └─► Si done==1 y busy==0: Salir

8. Cliente descarga resultado
   └─► Servidor ejecuta: download_image()
       ├─► write_register(IMG_RD_ADDR, 0)
       └─► Loop 1024 veces:
           └─► read_register(IMG_RD_DATA)
               └─► JTAG: Shift 40 bits (R, 0x05, 0)
                   └─► FPGA: Leer de memoria de salida
                       └─► Auto-incrementar dirección

9. Cliente guarda resultados
   └─► save_image_txt("output_32x32.txt")
   └─► print_image_ascii(output_image)
```

---

## Instrucciones de Implementación

### Paso 1: Compilar RTL en Quartus

1. **Abrir proyecto en Quartus Prime**
   ```
   Archivo: Proyecto2Arqui.qpf
   ```

2. **Agregar módulos JTAG al proyecto**
   - `rtl/jtag/jtag_register_map.sv`
   - `rtl/jtag/jtag_avalon_controller.sv`

3. **Agregar Virtual JTAG IP**
   - Tools → IP Catalog
   - Buscar: "Virtual JTAG"
   - Generar con configuración:
     - IR Width: 1 bit
     - Instance ID: 0 (auto)
     - Output: SystemVerilog
   - Agregar al proyecto

4. **Establecer top-level**
   - Project → Set as Top-Level Entity
   - Seleccionar: `top_downscale_system`

5. **Verificar archivos incluidos**
   ```
   rtl/
   ├── top_downscale_system.sv          ← Top-level
   ├── jtag/
   │   ├── jtag_register_map.sv
   │   └── jtag_avalon_controller.sv
   ├── downscale/
   │   ├── downscale_sequential.sv
   │   ├── downscale_fsm.sv
   │   ├── bilinear_interpolator.sv
   │   └── fixed_point_mult.sv
   └── memory/
       ├── image_memory_input.sv
       └── image_memory_output.sv
   ```

6. **Configurar pines (archivo .qsf o Pin Planner)**
   ```tcl
   set_location_assignment PIN_AF14 -to CLOCK_50
   set_location_assignment PIN_AA14 -to KEY0
   set_location_assignment PIN_V16 -to LEDR[0]
   set_location_assignment PIN_W16 -to LEDR[1]
   # ... (resto de LEDs)
   ```

7. **Compilar diseño**
   - Processing → Start Compilation
   - Verificar: 0 errores, 0 warnings críticos

8. **Programar FPGA**
   - Tools → Programmer
   - Agregar archivo: `output_files/Proyecto2Arqui.sof`
   - Hardware Setup: USB-Blaster
   - Start

### Paso 2: Configurar Servidor TCL

1. **Abrir Quartus System Console**
   ```
   Tools → System Console
   ```

2. **Cargar script del servidor**
   ```tcl
   % cd software/tcl/server
   % source jtag_downscale_server.tcl
   ```

3. **Verificar inicio del servidor**
   ```
   =========================================
   Servidor JTAG Downscaling
   =========================================
   Puerto: 2540
   Esperando conexiones...
   =========================================
   ```

### Paso 3: Ejecutar Cliente Python

1. **Instalar dependencias**
   ```bash
   pip install numpy
   ```

2. **Ejecutar cliente de prueba**
   ```bash
   cd software/python/client
   python downscale_client.py
   ```

3. **Salida esperada**
   ```
   ==================================================
   Cliente JTAG - Downscaling 64x64 → 32x32
   ==================================================
   Conectando a 127.0.0.1:2540...
   Conectado exitosamente

   =========================================
   Estado del Sistema
   =========================================
   BUSY:        0
   DONE:        0
   FSM State:   0
   Pixels:      0 / 1024
   =========================================

   Creando patrón de prueba (gradiente)...

   ==================================================
   Procesamiento de Imagen - Downscaling
   ==================================================
   Subiendo imagen de 64x64...
   Progreso: 0% (0/4096 píxeles)
   Progreso: 12% (512/4096 píxeles)
   ...
   Imagen subida exitosamente: 4096 píxeles

   Enviando comando START...

   Esperando que termine el procesamiento...
   Progreso: 50.0% (512/1024 píxeles)
   Procesamiento completado: 1024 píxeles procesados

   Descargando imagen de 32x32...
   Progreso: 0% (0/1024 píxeles)
   ...
   Imagen descargada exitosamente: 1024 píxeles

   Imagen guardada en: input_64x64.txt
   Imagen guardada en: output_32x32.txt

   Imagen ASCII (32x32):
   ==================================
   | .....::::----====++++****####@@|
   ...
   ==================================

   Estadísticas de la imagen de salida:
   Min:  0
   Max:  255
   Mean: 127.50
   Std:  73.90

   ¡Prueba completada exitosamente!
   ```

---

## Verificación y Debugging

### 1. Verificar Conexión JTAG

**En Quartus System Console:**
```tcl
% get_service_paths device
Device: USB-Blaster on localhost [USB-0]

% set device [lindex [get_service_paths device] 0]
% open_service device $device
```

### 2. Verificar Virtual JTAG

```tcl
% set vjtag [lindex [get_service_paths sld] 0]
% open_service sld $vjtag

% sld_access_ir $vjtag 1 1
% sld_access_dr $vjtag 40 0x0000000000
```

### 3. Monitor de LEDs

Observar `LEDR[9:0]` en la FPGA:
- Durante carga: LEDs deberían estar apagados
- Al iniciar: `LEDR[2]` se enciende brevemente (start pulse)
- Durante procesamiento: `LEDR[1]` = 1 (busy)
- Al terminar: `LEDR[0]` = 1 (done), `LEDR[1]` = 0

### 4. Simulación de Registro Map

**Archivo de testbench:** `sim/tb_jtag_register_map.sv`

```systemverilog
// Simular escritura y lectura de registros
initial begin
    // Reset
    rst_n = 0;
    #100 rst_n = 1;

    // Escribir CONTROL = 0x01 (start)
    @(posedge clk);
    reg_write = 1;
    reg_addr = 8'h00;
    reg_write_data = 32'h00000001;
    @(posedge clk);
    reg_write = 0;

    // Leer STATUS
    @(posedge clk);
    reg_read = 1;
    reg_addr = 8'h01;
    @(posedge clk);
    reg_read = 0;

    // Verificar reg_read_data
    @(posedge clk);
    assert(reg_read_valid == 1);

    $finish;
end
```

---

## Timing y Performance

### Latencias del Sistema

| Operación                  | Ciclos | Tiempo @ 50MHz |
|----------------------------|--------|----------------|
| Escribir registro (JTAG)   | ~40    | ~800 ns        |
| Leer registro (JTAG)       | ~40    | ~800 ns        |
| Escribir píxel en memoria  | 1      | 20 ns          |
| Leer píxel de memoria      | 1      | 20 ns          |
| Procesar 1 píxel (pipeline)| ~13    | ~260 ns        |
| Downscaling completo       | ~16K   | ~320 µs        |

### Tiempos de Transferencia

**Upload de imagen (64×64 = 4096 píxeles):**
- JTAG: 4096 × 40 ciclos = 163,840 ciclos
- Tiempo: ~3.3 ms @ 50 MHz
- **Limitado por:** Velocidad JTAG y comunicación PC-FPGA

**Download de imagen (32×32 = 1024 píxeles):**
- JTAG: 1024 × 40 ciclos = 40,960 ciclos
- Tiempo: ~0.8 ms @ 50 MHz

**Procesamiento (1024 píxeles de salida):**
- Por píxel: 4 lecturas + 8 ciclos pipeline + 1 escritura = ~13 ciclos
- Total: 1024 × 13 = 13,312 ciclos
- Tiempo: ~266 µs @ 50 MHz

**Tiempo total end-to-end:**
- Upload: ~3.3 ms
- Processing: ~0.27 ms
- Download: ~0.8 ms
- **Total: ~4.4 ms** (sin overhead de comunicación)

---

## Troubleshooting

### Problema 1: "Connection refused" en cliente Python

**Síntoma:**
```
ERROR: No se pudo conectar al servidor en 127.0.0.1:2540
```

**Solución:**
1. Verificar que el servidor TCL esté ejecutándose
2. En System Console, revisar que vea:
   ```
   Esperando conexiones...
   ```
3. Verificar que no haya firewall bloqueando puerto 2540

### Problema 2: "Device not found" en TCL

**Síntoma:**
```
No se pudo abrir dispositivo JTAG: ...
```

**Solución:**
1. Verificar que USB-Blaster esté conectado
2. En Quartus Programmer, detectar hardware
3. Verificar que FPGA esté programada con el diseño correcto

### Problema 3: Timeout durante procesamiento

**Síntoma:**
```
El procesamiento no terminó en 30 segundos
```

**Solución:**
1. Verificar señales de reloj con SignalTap
2. Revisar que `start_processing` genere pulso correcto
3. Verificar FSM con LEDs de debug
4. Simular con testbench completo

### Problema 4: Datos incorrectos en imagen de salida

**Síntoma:**
Imagen de salida tiene valores inesperados

**Solución:**
1. Verificar que imagen de entrada se cargó correctamente:
   ```python
   save_image_txt(input_image, "verify_input.txt")
   ```
2. Revisar direccionamiento de memoria (auto-incremento)
3. Verificar interpolador con testbench de FASE 5
4. Comprobar que `pixels_written == 1024`

---

## Extensiones Futuras

### 1. Burst Transfers
Implementar transferencias de múltiples píxeles por comando JTAG para reducir overhead.

### 2. DMA Controller
Agregar DMA para transferencias autónomas entre PC y memoria sin intervención del procesador.

### 3. Múltiples Resoluciones
Soportar diferentes tamaños de entrada/salida configurables via registros.

### 4. Filtros Adicionales
Agregar filtros de procesamiento de imagen (blur, edge detection, etc.).

### 5. Interfaz AXI
Reemplazar JTAG con interfaz AXI para mayor velocidad en sistemas con HPS.

---

## Referencias

- **Quartus Prime Documentation:** Virtual JTAG Megafunction User Guide
- **JTAG Protocol:** IEEE 1149.1 Standard
- **Especificaciones del Proyecto:** FASE1-5 Instrucciones
- **Cyclone V Device Handbook:** Memory Controller and I/O

---

## Autores y Contacto

**Arquitectura de Computadores 2**
Universidad [Nombre]
Fecha: 2025

---
