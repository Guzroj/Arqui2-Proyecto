# FASE 3: Test de JTAG con LEDs - Instrucciones

## Archivos Creados

1. **rtl/jtag/jtag_led_interface.sv** - Interfaz JTAG para controlar LEDs
2. **rtl/top/test_jtag_leds.sv** - Top-level con Virtual JTAG
3. **software/tcl/server/jtag_server_leds.tcl** - Servidor TCP/IP
4. **software/python/utils/test_jtag_leds.py** - Cliente de prueba Python
5. **quartus/test_jtag_leds/pin_assignments_de1soc.qsf** - Pin assignments

## Pasos para Ejecutar

### 1. Crear Proyecto Quartus

1. Abrir Quartus Prime Lite 20.1
2. File → New Project Wizard
3. Configuración:
   - **Project name**: `test_jtag_leds`
   - **Project directory**: `quartus/test_jtag_leds/`
   - **Top-level entity**: `test_jtag_leds`
   - **Device**: `5CSEMA5F31C6` (Cyclone V)

### 2. Agregar Archivos al Proyecto

1. Project → Add/Remove Files in Project
2. Agregar:
   - `rtl/top/test_jtag_leds.sv`
   - `rtl/jtag/jtag_led_interface.sv`

### 3. Agregar IP Core Virtual JTAG

1. Tools → IP Catalog
2. Buscar: "Virtual JTAG" o "sld_virtual_jtag"
3. Ubicación: Library → Interface Protocols → JTAG → Virtual JTAG
4. Doble clic para abrir el wizard
5. Configuración:
   - **Instance index**: 0
   - **IR width**: 1
   - **Simulation**: Dejar por defecto
6. Generate → Finish
7. Agregar el archivo generado al proyecto

### 4. Importar Pin Assignments

1. Assignments → Import Assignments
2. Seleccionar: `quartus/test_jtag_leds/pin_assignments_de1soc.qsf`
3. O manualmente en Pin Planner:
   - CLOCK_50 → PIN_AF14
   - KEY0 → PIN_AA14
   - LEDR[0] → PIN_V16
   - LEDR[1] → PIN_W16
   - ... (ver archivo pin_assignments_de1soc.qsf)

### 5. Compilar Proyecto

1. Processing → Start Compilation
2. Verificar que no hay errores
3. El archivo `.sof` se genera en `output_files/test_jtag_leds.sof`

### 6. Programar FPGA

1. Tools → Programmer
2. Hardware Setup → Seleccionar USB-Blaster
3. Add File → Seleccionar `test_jtag_leds.sof`
4. Program/Configure → Clic en "Start"
5. Verificar que aparece "Success"

### 7. Ejecutar Servidor TCL

Abrir terminal/command prompt:

```bash
cd C:\Users\josev\OneDrive\Documentos\Arqui2ProyectoInicio
quartus_stp -t software/tcl/server/jtag_server_leds.tcl
```

El servidor debe mostrar:
```
==========================================
JTAG LED Server - FASE 3
==========================================

Hardware encontrado: USB-Blaster
Dispositivo encontrado: 5CSEMA5F31C6
Usando hardware: USB-Blaster
Usando dispositivo: 5CSEMA5F31C6
Servidor escuchando en puerto 2540
Esperando conexiones...
```

### 8. Ejecutar Cliente Python

En otra terminal:

```bash
cd C:\Users\josev\OneDrive\Documentos\Arqui2ProyectoInicio
python software/python/utils/test_jtag_leds.py
```

El cliente ejecutará 6 tests:
1. Contar de 0 a 255
2. Contar de 255 a 0
3. Patrón alternante (0xAA, 0x55)
4. LEDs individuales
5. Contar en binario (0-15)
6. Patrón de onda

### 9. Observar Resultados

Los LEDs en la placa DE1-SoC deben cambiar según los comandos enviados.

## Solución de Problemas

### Error: "No se encontró hardware JTAG"
- Verificar que el cable USB-Blaster está conectado
- Verificar drivers del USB-Blaster
- En Quartus: Tools → Programmer → Hardware Setup → Verificar que aparece USB-Blaster

### Error: "No se encontró dispositivo"
- Verificar que la FPGA está programada con `test_jtag_leds.sof`
- Verificar que la placa está encendida
- Intentar reprogramar la FPGA

### Error: "No se pudo conectar al servidor"
- Verificar que el servidor TCL está corriendo
- Verificar que el puerto 2540 no está bloqueado por firewall
- Verificar que el servidor muestra "Servidor escuchando en puerto 2540"

### LEDs no cambian
- Verificar que el servidor muestra "OK" después de cada comando
- Verificar que la FPGA está programada correctamente
- Verificar pin assignments en Quartus
- Revisar que Virtual JTAG está instanciado correctamente

### Error de compilación: "sld_virtual_jtag not found"
- Verificar que el IP Core Virtual JTAG fue agregado al proyecto
- Verificar que el archivo generado por el IP Core está en el proyecto
- Regenerar el IP Core si es necesario

## Checklist FASE 3

- [ ] Proyecto Quartus creado
- [ ] Archivos SystemVerilog agregados
- [ ] IP Core Virtual JTAG agregado
- [ ] Pin assignments importados
- [ ] Compilación exitosa (sin errores)
- [ ] FPGA programada correctamente
- [ ] Servidor TCL detecta hardware y dispositivo
- [ ] Cliente Python se conecta al servidor
- [ ] LEDs cambian según comandos enviados
- [ ] Todos los tests pasan exitosamente

## Próximos Pasos

Una vez completada la FASE 3, continuar con:
- **FASE 4**: Memoria de Imagen
- **FASE 5**: Interpolación Secuencial en Hardware
- **FASE 6**: Integración JTAG + Downscaling

