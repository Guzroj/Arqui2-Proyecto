# FASE 6 - PASOS RÁPIDOS DE IMPLEMENTACIÓN

## Arquitectura de Computadores 2

---

## ⚠️ ANTES DE EMPEZAR

**IMPORTANTE:** El archivo `.qsf` del proyecto ya ha sido actualizado con:
- ✅ Top-level cambiado a `top_downscale_system`
- ✅ Todos los archivos RTL incluidos (FASE 4, 5, y 6)
- ✅ Asignaciones de pines configuradas

---

## 📋 RESUMEN DE LO QUE VAMOS A HACER

1. Generar IP de Virtual JTAG en Quartus
2. Compilar el proyecto completo
3. Programar la FPGA
4. Iniciar el servidor TCL
5. Ejecutar el cliente Python para probar

**Tiempo estimado:** 30-45 minutos

---

## PASO 1: GENERAR VIRTUAL JTAG IP

### 1.1 Abrir Quartus Prime

```
Navega a: C:\Users\josev\OneDrive\Documentos\Arqui2ProyectoInicio\quartus\downscale_project
Abre: Proyecto2Arqui.qpf
```

### 1.2 Abrir IP Catalog

```
Menu: Tools → IP Catalog
```

### 1.3 Buscar y Generar Virtual JTAG

1. En la barra de búsqueda del IP Catalog, escribe: `Virtual JTAG`
2. Selecciona: **"Virtual JTAG Intel FPGA IP"**
3. Haz clic en: **"Add..."**

### 1.4 Configurar el IP

Aparecerá una ventana de configuración. Configura los siguientes parámetros:

```
┌─────────────────────────────────────────────────┐
│ Virtual JTAG Intel FPGA IP                      │
├─────────────────────────────────────────────────┤
│ IP Variation Name: sld_virtual_jtag             │
│                                                 │
│ Parameters:                                     │
│   IR Width:                    1                │
│   Auto instance index:         Yes (checked)    │
│   Instance ID:                 0                │
│   SLD NODE Instance ID:        Auto             │
│                                                 │
│ Output:                                         │
│   Create HDL design files:     SystemVerilog    │
│   Output directory:            .                │
└─────────────────────────────────────────────────┘
```

### 1.5 Generar el IP

1. Haz clic en: **"Generate HDL..."**
2. En la ventana de generación:
   - ✅ Create simulation model: **None** (no necesario)
   - ✅ Synthesis: **VHDL** o **SystemVerilog** (elige SystemVerilog)
3. Haz clic en: **"Generate"**
4. Espera a que termine (aparecerá "Generation completed successfully")
5. Haz clic en: **"Finish"**

### 1.6 Agregar el IP al Proyecto

El IP se genera como `sld_virtual_jtag.v` o `sld_virtual_jtag.sv`

1. En Project Navigator (panel izquierdo), verifica que aparezca:
   - `sld_virtual_jtag` (puede estar en la carpeta `db` o en el directorio del proyecto)

2. **Si NO aparece automáticamente:**
   - Menu: Project → Add/Remove Files in Project
   - Busca el archivo generado (normalmente en el directorio del proyecto)
   - Agrégalo manualmente

---

## PASO 2: COMPILAR EL PROYECTO

### 2.1 Verificar Jerarquía

Antes de compilar, verifica que el proyecto tenga la jerarquía correcta:

```
Menu: Project → Show Instance & Entity of Current File
```

Deberías ver:
```
top_downscale_system (TOP)
├── sld_virtual_jtag (IP generado)
├── jtag_avalon_controller
├── jtag_register_map
├── image_memory_input
├── image_memory_output
└── downscale_sequential
    ├── downscale_fsm
    ├── bilinear_interpolator
    │   └── fixed_point_mult (x6)
    └── (buffer logic)
```

### 2.2 Iniciar Compilación Completa

```
Menu: Processing → Start Compilation
```

O usa el atajo: **Ctrl+L**

### 2.3 Esperar Compilación

La compilación tiene varias etapas:

1. ✅ **Analysis & Synthesis** (~3-5 minutos)
   - Verifica sintaxis SystemVerilog
   - Infiere memorias (BRAMs)
   - Optimiza lógica

2. ✅ **Fitter** (~5-10 minutos)
   - Coloca componentes en FPGA
   - Rutea conexiones

3. ✅ **Assembler** (~1 minuto)
   - Genera bitstream (.sof)

4. ✅ **TimeQuest Timing Analyzer** (~2 minutos)
   - Verifica timing constraints

**Tiempo total estimado:** 10-15 minutos

### 2.4 Verificar Resultados

Al finalizar, deberías ver en el **Compilation Report:**

```
Flow Status: Successful
Errors: 0
Warnings: < 50 (ignorar warnings menores)
```

**Recursos utilizados aproximados:**
- Logic Elements: ~2,000 / 32,070 (6%)
- Memory Bits: ~45,056 / 4,065,280 (1%)
- Embedded Multipliers: ~18 / 87 (20%)

**Archivos generados:**
```
quartus/downscale_project/output_files/Proyecto2Arqui.sof
```

---

## PASO 3: PROGRAMAR LA FPGA

### 3.1 Conectar la FPGA

1. Conecta el cable USB-Blaster a la FPGA
2. Conecta el cable de alimentación a la FPGA
3. Enciende la FPGA (switch de power)

### 3.2 Abrir Programmer

```
Menu: Tools → Programmer
```

### 3.3 Configurar Hardware

1. En la ventana del Programmer, haz clic en: **"Hardware Setup..."**
2. Selecciona: **"USB-Blaster [USB-0]"**
3. Haz clic en: **"Close"**

### 3.4 Agregar Archivo de Programación

Si el archivo `.sof` no está listado:

1. Haz clic en: **"Add File..."**
2. Navega a: `output_files/Proyecto2Arqui.sof`
3. Selecciona el archivo y haz clic en: **"Open"**

### 3.5 Programar

1. Marca la casilla: **"Program/Configure"** junto al archivo `.sof`
2. Haz clic en: **"Start"**
3. Espera a que termine (barra de progreso al 100%)
4. Deberías ver: **"100% (Successful)"**

### 3.6 Verificar Programación

Observa los LEDs de la FPGA:
- Al programar, todos los LEDs deberían apagarse
- `LEDR[0]` = done (apagado inicialmente)
- `LEDR[1]` = busy (apagado inicialmente)

---

## PASO 4: INICIAR SERVIDOR TCL

### 4.1 Abrir System Console

```
Menu (en Quartus): Tools → System Console
```

O desde el menú de inicio de Windows:
```
Intel Quartus Prime 20.1 → System Console
```

### 4.2 Navegar al Directorio del Servidor

En la consola TCL de System Console, ejecuta:

```tcl
cd C:/Users/josev/OneDrive/Documentos/Arqui2ProyectoInicio/software/tcl/server
```

**NOTA:** Usa `/` (slash) en lugar de `\` (backslash) en TCL

### 4.3 Cargar el Script del Servidor

```tcl
source jtag_downscale_server.tcl
```

### 4.4 Verificar que el Servidor Esté Corriendo

Deberías ver:

```
=========================================
Servidor JTAG Downscaling
=========================================
Puerto: 2540
Esperando conexiones...
=========================================
```

**¡IMPORTANTE!** Deja esta ventana abierta. El servidor debe estar corriendo para que el cliente Python pueda conectarse.

---

## PASO 5: EJECUTAR CLIENTE PYTHON

### 5.1 Abrir Terminal de Python

Abre una terminal (CMD, PowerShell, o Terminal de Windows):

```
Win+R → cmd → Enter
```

### 5.2 Navegar al Directorio del Cliente

```bash
cd C:\Users\josev\OneDrive\Documentos\Arqui2ProyectoInicio\software\python\client
```

### 5.3 Verificar que NumPy esté Instalado

```bash
python -c "import numpy; print(numpy.__version__)"
```

Si da error, instalar NumPy:

```bash
pip install numpy
```

### 5.4 Ejecutar el Cliente

```bash
python downscale_client.py
```

### 5.5 Salida Esperada

Deberías ver:

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
Progreso: 25% (1024/4096 píxeles)
Progreso: 37% (1536/4096 píxeles)
Progreso: 50% (2048/4096 píxeles)
Progreso: 62% (2560/4096 píxeles)
Progreso: 75% (3072/4096 píxeles)
Progreso: 87% (3584/4096 píxeles)
Imagen subida exitosamente: 4096 píxeles

=========================================
Estado del Sistema
=========================================
BUSY:        0
DONE:        0
FSM State:   0
Pixels:      0 / 1024
=========================================

Enviando comando START...
Comando START enviado exitosamente

Esperando que termine el procesamiento...
Progreso: 0.0% (0/1024 píxeles)
Progreso: 10.0% (102/1024 píxeles)
Progreso: 20.0% (205/1024 píxeles)
...
Progreso: 90.0% (922/1024 píxeles)
Progreso: 100.0% (1024/1024 píxeles)
Procesamiento completado: 1024 píxeles procesados

Descargando imagen de 32x32...
Progreso: 0% (0/1024 píxeles)
Progreso: 25% (256/1024 píxeles)
Progreso: 50% (512/1024 píxeles)
Progreso: 75% (768/1024 píxeles)
Imagen descargada exitosamente: 1024 píxeles

Imagen guardada en: input_64x64.txt
Imagen guardada en: output_32x32.txt

Imagen ASCII (32x32):
==================================
| .....::::----====++++****####@@|
| .....::::----====++++****####@@|
| .....::::----====++++****####@@|
...
==================================

Estadísticas de la imagen de salida:
Min:  0
Max:  255
Mean: 127.50
Std:  73.90

==================================================
Procesamiento completado exitosamente
==================================================

Desconectado del servidor

¡Prueba completada exitosamente!
```

---

## ✅ VERIFICACIÓN DE FUNCIONAMIENTO

### Verificar LEDs en la FPGA

Durante el procesamiento, observa los LEDs:

1. **LEDR[2]** debe encenderse brevemente cuando ejecutas `START` (start_pulse)
2. **LEDR[1]** debe encenderse durante el procesamiento (busy)
3. **LEDR[0]** debe encenderse al terminar (done)
4. **LEDR[9:4]** deben cambiar mostrando el contador de píxeles (bits bajos)

### Verificar Archivos Generados

El cliente Python debe haber generado dos archivos:

```
software/python/client/input_64x64.txt    (imagen original 64x64)
software/python/client/output_32x32.txt   (imagen procesada 32x32)
```

Puedes abrirlos con cualquier editor de texto y ver la matriz de píxeles.

---

## 🔧 TROUBLESHOOTING COMÚN

### Error 1: "Connection refused" en Python

**Causa:** El servidor TCL no está corriendo

**Solución:**
1. Verifica que System Console esté abierto
2. Verifica que hayas ejecutado `source jtag_downscale_server.tcl`
3. Verifica que veas "Esperando conexiones..."

---

### Error 2: "Device not found" en TCL

**Causa:** FPGA no conectada o USB-Blaster no detectado

**Solución:**
1. Verifica que el cable USB-Blaster esté conectado
2. En Quartus Programmer, haz clic en "Auto Detect"
3. Verifica que aparezca "5CSEMA5"

---

### Error 3: Timeout durante procesamiento

**Causa:** FSM no está funcionando correctamente

**Solución:**
1. Observa los LEDs:
   - Si LEDR[1] (busy) se enciende pero no se apaga: FSM está atascada
   - Si LEDR[1] nunca se enciende: start_pulse no llegó a la FSM
2. Re-programa la FPGA
3. Reinicia el servidor TCL

---

### Error 4: Valores incorrectos en imagen de salida

**Causa:** Problema con el downscaler o las memorias

**Solución:**
1. Verifica que `pixels_written == 1024` al final
2. Prueba con diferentes patrones:
   ```python
   # Modificar en downscale_client.py línea ~384
   input_image = create_test_pattern("constant")  # Todos 128
   ```
3. Si el patrón constante funciona, el interpolador está OK

---

## 📊 COMANDOS COMPLETOS PARA COPIAR Y PEGAR

### Comando para Servidor TCL (System Console)

```tcl
cd C:/Users/josev/OneDrive/Documentos/Arqui2ProyectoInicio/software/tcl/server
source jtag_downscale_server.tcl
```

### Comando para Cliente Python (Terminal)

```bash
cd C:\Users\josev\OneDrive\Documentos\Arqui2ProyectoInicio\software\python\client
python downscale_client.py
```

---

## 🎯 PRÓXIMOS PASOS (OPCIONAL)

### Probar con Otros Patrones

Modifica el archivo `downscale_client.py` línea ~384:

```python
# Cambiar "gradient" por:
input_image = create_test_pattern("checkerboard")  # Tablero de ajedrez
input_image = create_test_pattern("constant")      # Valor constante 128
input_image = create_test_pattern("random")        # Patrón aleatorio
```

### Cargar tu Propia Imagen

```python
# En downscale_client.py, reemplaza la sección de crear patrón con:
input_image = np.random.randint(0, 256, (64, 64), dtype=np.uint8)
# O cargar desde archivo:
input_image = load_image_txt("mi_imagen_64x64.txt")
```

---

## 📝 RESUMEN DE ARCHIVOS IMPORTANTES

| Ubicación | Descripción |
|-----------|-------------|
| `quartus/downscale_project/Proyecto2Arqui.qpf` | Proyecto de Quartus |
| `quartus/downscale_project/output_files/Proyecto2Arqui.sof` | Bitstream para programar FPGA |
| `rtl/top_downscale_system.sv` | Top-level del sistema completo |
| `software/tcl/server/jtag_downscale_server.tcl` | Servidor TCL |
| `software/python/client/downscale_client.py` | Cliente Python |

---

## ✅ CHECKLIST FINAL

Antes de dar por terminada la FASE 6, verifica:

- [ ] Compilación exitosa en Quartus (0 errores)
- [ ] FPGA programada correctamente
- [ ] Servidor TCL corriendo y escuchando en puerto 2540
- [ ] Cliente Python se conecta sin errores
- [ ] Imagen de 64×64 se sube correctamente (4096 píxeles)
- [ ] Procesamiento se completa (1024 píxeles)
- [ ] Imagen de 32×32 se descarga correctamente
- [ ] Archivos `input_64x64.txt` y `output_32x32.txt` generados
- [ ] LEDs muestran estado correcto durante operación

---

**¡Listo! Con esto tu sistema de downscaling con control JTAG está funcionando.**
