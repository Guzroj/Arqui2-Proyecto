# FASE 3: Test de JTAG con LEDs - Instrucciones Completas

## Resumen
Esta fase implementa un test simple de comunicación JTAG entre la PC y la FPGA DE1-SoC, controlando 8 LEDs (LEDR[7:0]) a través de Virtual JTAG.

**Basado en**: https://idlelogiclabs.com/2012/04/15/talking-to-the-de0-nano-using-the-virtual-jtag-interface/

---

## Archivos Generados

### RTL (Hardware)
- `rtl/jtag/vJTAG_interface.v` - Módulo de interfaz JTAG para control de LEDs
- `rtl/top/test_jtag_leds.v` - Módulo top-level

### Software
- `software/tcl/server/jtag_server_leds.tcl` - Servidor TCP/IP que controla JTAG
- `software/tcl/server/run_jtag_server.bat` - Script para ejecutar el servidor
- `software/python/utils/test_jtag_leds.py` - Cliente de prueba

### Quartus
- `quartus/test_jtag_leds/test_jtag_leds.qpf` - Archivo de proyecto
- `quartus/test_jtag_leds/test_jtag_leds.qsf` - Settings del proyecto
- `quartus/test_jtag_leds/pin_assignments_de1soc.tcl` - Pin assignments

---

## PASO 1: Generar el IP Core de Virtual JTAG en Quartus

### 1.1 Abrir el proyecto
```
1. Abre Quartus Prime 20.1
2. File → Open Project
3. Navega a: C:\Users\josev\OneDrive\Documentos\Arqui2ProyectoInicio\quartus\test_jtag_leds
4. Abre: test_jtag_leds.qpf
```

### 1.2 Generar Virtual JTAG IP Core
```
1. En Quartus, ve a: Tools → IP Catalog
2. En la ventana de IP Catalog, busca "Virtual JTAG" o "Altera Virtual JTAG"
   - Ubicación: Library → Interface Protocols → JTAG → Altera Virtual JTAG
   - NOTA: El nombre puede aparecer como "Altera Virtual JTAG" (es lo mismo)
3. Doble clic en "Altera Virtual JTAG"
4. En el wizard:
   - Device family: Cyclone V
   - Create an HDL file: Sí
   - Output file name: vJTAG.v
   - Ubicación: C:\Users\josev\OneDrive\Documentos\Arqui2ProyectoInicio\quartus\test_jtag_leds\
5. Haz clic en "Next"
6. Configura los parámetros:
   - sld_auto_instance_index: YES
   - sld_instance_index: 0
   - sld_ir_width: 1
   - sld_sim_action: (dejar en blanco)
   - sld_sim_n_scan: 0
   - sld_sim_total_length: 0
7. Haz clic en "Finish" y luego "Generate"
8. Cierra el wizard
```

### 1.3 Agregar vJTAG.v al proyecto
```
1. En Quartus, ve a: Project → Add/Remove Files in Project
2. Haz clic en "..." (browse)
3. Selecciona el archivo vJTAG.v recién generado
4. Haz clic en "Add" y luego "OK"
```

**IMPORTANTE**: También puedes agregar el archivo manualmente editando `test_jtag_leds.qsf`:
```tcl
set_global_assignment -name VERILOG_FILE vJTAG.v
```

---

## PASO 2: Compilar el proyecto en Quartus

### 2.1 Compilación completa
```
1. En Quartus: Processing → Start Compilation
2. Espera a que termine (puede tardar varios minutos)
3. Verifica que la compilación termine sin errores
4. El archivo .sof se generará en: quartus/test_jtag_leds/output_files/test_jtag_leds.sof
```

---

## PASO 3: Programar la FPGA

### 3.1 Conectar la DE1-SoC
```
1. Conecta la DE1-SoC a la PC via USB-Blaster
2. Enciende la placa (switch de poder)
```

### 3.2 Programar via Quartus GUI
```
1. En Quartus: Tools → Programmer
2. Si no hay hardware detectado:
   - Haz clic en "Hardware Setup..."
   - Selecciona "USB-Blaster [USB-1]" (o similar)
   - Haz clic en "Close"
3. Si no hay archivo .sof cargado:
   - Haz clic en "Add File..."
   - Navega a: quartus/test_jtag_leds/output_files/test_jtag_leds.sof
   - Haz clic en "Open"
4. Marca la casilla "Program/Configure" junto al .sof
5. Haz clic en "Start"
6. Espera a que termine (barra de progreso 100%)
```

### 3.3 Verificar programación
- Los LEDs LEDR[7:0] deberían estar apagados después de programar
- Si algún LED queda encendido, es normal (estado inicial del registro)

---

## PASO 4: Ejecutar el Servidor JTAG

### 4.1 Ejecutar el servidor TCL
```
1. Abre una terminal de Windows (cmd)
2. Navega al directorio del proyecto:
   cd C:\Users\josev\OneDrive\Documentos\Arqui2ProyectoInicio
3. Ejecuta el servidor:
   software\tcl\server\run_jtag_server.bat
4. Verás la salida:
   ==========================================
   JTAG LED Server - FASE 3
   ==========================================

   Hardware detectado: USB-Blaster [USB-1]

   Dispositivo encontrado: @1: 5M(1270ZF324|2210Z)/5S(GS3E1|GS3B1) (0x02D020DD)
   Dispositivo encontrado: @2: 5CSEMA5(F31|U23) (0x02D020DD)

   Dispositivo seleccionado: @2: 5CSEMA5(F31|U23) (0x02D020DD)

   ==========================================
   Servidor escuchando en puerto 2540
   Esperando conexiones...
   Presiona Ctrl+C para detener el servidor
   ==========================================
```

**NOTA**: Si ves "ERROR: No se encontró USB-Blaster", verifica que:
- La placa esté conectada y encendida
- Los drivers del USB-Blaster estén instalados
- Quartus Prime esté correctamente instalado

---

## PASO 5: Ejecutar el Cliente de Prueba

### 5.1 Abrir una SEGUNDA terminal
```
1. Abre otra terminal de Windows (cmd) - NO cierres la del servidor
2. Navega al directorio del proyecto:
   cd C:\Users\josev\OneDrive\Documentos\Arqui2ProyectoInicio
```

### 5.2 Ejecutar todos los tests
```
python software\python\utils\test_jtag_leds.py
```

Verás la salida:
```
==========================================
JTAG LED Test Client - FASE 3
==========================================

[OK] Conectado al servidor JTAG en localhost:2540
[OK] Servidor: JTAG LED Server - Listo

==========================================
TEST 1: Contador binario (0-255)
==========================================
LEDs = 255 (0b11111111)
[OK] Test completado correctamente

==========================================
TEST 2: Walking Ones
==========================================
LED[0] = 1 (0b00000001)
LED[1] = 1 (0b00000010)
LED[2] = 1 (0b00000100)
LED[3] = 1 (0b00001000)
LED[4] = 1 (0b00010000)
LED[5] = 1 (0b00100000)
LED[6] = 1 (0b01000000)
LED[7] = 1 (0b10000000)
[OK] Test completado correctamente

==========================================
TEST 3: Walking Zeros
==========================================
LED[0] = 0 (0b11111110)
LED[1] = 0 (0b11111101)
LED[2] = 0 (0b11111011)
LED[3] = 0 (0b11110111)
LED[4] = 0 (0b11101111)
LED[5] = 0 (0b11011111)
LED[6] = 0 (0b10111111)
LED[7] = 0 (0b01111111)
[OK] Test completado correctamente

==========================================
TEST 4: Patrones
==========================================
Todos apagados: 0b00000000 (0x00)
Todos encendidos: 0b11111111 (0xFF)
Patron 10101010: 0b10101010 (0xAA)
Patron 01010101: 0b01010101 (0x55)
Nibble bajo: 0b00001111 (0x0F)
Nibble alto: 0b11110000 (0xF0)
Extremos (10000001): 0b10000001 (0x81)
Centro (01000010): 0b01000010 (0x42)
[OK] Test completado correctamente

Apagando todos los LEDs...

[OK] Conexion cerrada
```

### 5.3 Ejecutar tests individuales

**Test de contador binario (0-255):**
```bash
python software\python\utils\test_jtag_leds.py counter
```

**Test de walking ones:**
```bash
python software\python\utils\test_jtag_leds.py walking1
```

**Test de walking zeros:**
```bash
python software\python\utils\test_jtag_leds.py walking0
```

**Test de patrones:**
```bash
python software\python\utils\test_jtag_leds.py patterns
```

**Valor personalizado:**
```bash
# Decimal
python software\python\utils\test_jtag_leds.py custom 170

# Hexadecimal
python software\python\utils\test_jtag_leds.py custom 0xAA

# Binario
python software\python\utils\test_jtag_leds.py custom 0b10101010
```

---

## Verificación Visual

Durante los tests, deberías ver en la DE1-SoC:

1. **Test 1 (Counter)**: Los 8 LEDs cuentan de 0 a 255 en binario rápidamente
2. **Test 2 (Walking 1s)**: Un LED se enciende a la vez, de derecha a izquierda
3. **Test 3 (Walking 0s)**: Todos encendidos excepto uno, que se mueve de derecha a izquierda
4. **Test 4 (Patterns)**: Diferentes patrones de LEDs encendidos/apagados

---

## Solución de Problemas

### Problema: "No se encontró USB-Blaster"
**Solución:**
- Verifica que la placa esté conectada y encendida
- Instala los drivers del USB-Blaster desde Quartus
- Ejecuta `jtagconfig` en cmd para verificar la detección

### Problema: "The specified virtual JTAG instance cannot be found"
**Solución:**
- Verifica que el archivo vJTAG.v fue generado y agregado al proyecto
- Recompila el proyecto en Quartus
- Reprograma la FPGA con el nuevo .sof

### Problema: "Connection refused" al ejecutar cliente Python
**Solución:**
- Verifica que el servidor TCL esté ejecutándose
- Verifica que el servidor muestre "Servidor escuchando en puerto 2540"

### Problema: LEDs no cambian
**Solución:**
- Verifica que el servidor muestre "Escribiendo LEDs: ..."
- Verifica que el cliente muestre "[OK]" en cada operación
- Reprograma la FPGA

---

## Arquitectura del Sistema

```
┌─────────────────┐
│  PC (Python)    │
│  test_jtag_     │
│  leds.py        │
└────────┬────────┘
         │ TCP/IP (puerto 2540)
         │ Comandos: "set_leds <value>"
         ▼
┌─────────────────┐
│  PC (TCL)       │
│  quartus_stp    │
│  jtag_server_   │
│  leds.tcl       │
└────────┬────────┘
         │ Quartus TCL API
         │ device_virtual_ir_shift
         │ device_virtual_dr_shift
         ▼
┌─────────────────┐
│  USB-Blaster    │
│  (Hardware)     │
└────────┬────────┘
         │ JTAG Protocol (TDI, TDO, TCK)
         ▼
┌─────────────────────────────────┐
│  FPGA (DE1-SoC)                 │
│  ┌───────────────────────────┐  │
│  │ sld_virtual_jtag (IP)     │  │
│  │ - IR (1-bit)              │  │
│  │ - DR (8-bit)              │  │
│  └───────┬───────────────────┘  │
│          │ tck, tdi, tdo         │
│          │ ir_in, v_sdr, udr     │
│          ▼                        │
│  ┌───────────────────────────┐  │
│  │ vJTAG_interface           │  │
│  │ - DR0 (bypass)            │  │
│  │ - DR1 (8-bit LED data)    │  │
│  └───────┬───────────────────┘  │
│          │ [7:0] LEDs            │
│          ▼                        │
│  ┌───────────────────────────┐  │
│  │ LEDR[7:0] Physical LEDs   │  │
│  └───────────────────────────┘  │
└─────────────────────────────────┘
```

---

## Flujo de Datos

1. **Python Client** envía comando: `set_leds 170\n`
2. **TCL Server** recibe y parsea: `170` (0xAA, 0b10101010)
3. **TCL Server** ejecuta secuencia JTAG:
   - `device_virtual_ir_shift -ir_value 1` → Selecciona DR1 (LEDs)
   - `device_virtual_dr_shift -dr_value 170 -length 8` → Escribe 0b10101010
   - `device_virtual_ir_shift -ir_value 0` → Regresa a bypass
4. **Virtual JTAG IP** shifta los bits via JTAG
5. **vJTAG_interface** recibe los bits en DR1[7:0]
6. **vJTAG_interface** actualiza LEDs cuando `udr` se activa
7. **LEDs físicos** muestran: 10101010 (LEDs alternados)

---

## Próximos Pasos

Una vez verificado que la comunicación JTAG funciona correctamente:

1. **FASE 4**: Integrar el módulo de downscaling
2. Modificar vJTAG_interface para recibir/enviar datos de imágenes
3. Expandir DR a 16-32 bits para transferencia de píxeles
4. Implementar protocolo de handshaking para transferencias grandes

---

## Referencias

- Tutorial original: https://idlelogiclabs.com/2012/04/15/talking-to-the-de0-nano-using-the-virtual-jtag-interface/
- Repositorio de referencia: `C:\Users\josev\Downloads\vJTAG_DE0-Nano_Example\`
- Quartus Virtual JTAG IP User Guide: https://www.intel.com/content/www/us/en/docs/programmable/683705/current/virtual-jtag-sld-virtual-jtag-megafunction.html
