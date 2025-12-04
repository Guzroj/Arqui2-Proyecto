# FASE 6 - CÓMO EJECUTAR EL SISTEMA

## Guía Rápida de Ejecución

---

## ✅ VERIFICACIÓN PREVIA

Antes de ejecutar, verifica que:

1. ✅ La FPGA está conectada vía USB-Blaster
2. ✅ La FPGA está encendida
3. ✅ El diseño está programado en la FPGA (archivo `.sof`)
4. ✅ Quartus Prime 20.1 está instalado
5. ✅ Python 3.x está instalado

---

## 🚀 PASO 1: INICIAR EL SERVIDOR JTAG

### Opción A: Usando el archivo .BAT (MÁS FÁCIL)

1. Navega a la carpeta:
   ```
   C:\Users\josev\OneDrive\Documentos\Arqui2ProyectoInicio\software\tcl\server
   ```

2. **Doble clic** en:
   ```
   start_jtag_server.bat
   ```

3. Se abrirá **System Console** automáticamente

4. Espera a ver el mensaje:
   ```
   =========================================
   Servidor JTAG Downscaling
   =========================================
   Puerto: 2540
   Esperando conexiones...
   =========================================
   ```

**IMPORTANTE:** NO cierres esta ventana. Debe permanecer abierta mientras usas el sistema.

### Opción B: Manual desde System Console

Si el .BAT no funciona:

1. Abre **System Console**:
   - Quartus → Tools → System Console
   - O desde Inicio: Intel Quartus Prime 20.1 → System Console

2. Ejecuta estos comandos:
   ```tcl
   cd C:/Users/josev/OneDrive/Documentos/Arqui2ProyectoInicio/software/tcl/server
   source jtag_downscale_server.tcl
   ```

---

## 🎯 PASO 2: EJECUTAR EL CLIENTE PYTHON

### Opción A: Usando el archivo .BAT (MÁS FÁCIL)

1. Navega a la carpeta:
   ```
   C:\Users\josev\OneDrive\Documentos\Arqui2ProyectoInicio\software\python\client
   ```

2. **Doble clic** en:
   ```
   start_client.bat
   ```

3. El cliente se ejecutará automáticamente

### Opción B: Manual desde Terminal

Si el .BAT no funciona:

1. Abre una terminal (CMD o PowerShell)

2. Ejecuta:
   ```cmd
   cd C:\Users\josev\OneDrive\Documentos\Arqui2ProyectoInicio\software\python\client
   python downscale_client.py
   ```

---

## 📊 SALIDA ESPERADA

Cuando todo funcione correctamente, verás:

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
...
Imagen subida exitosamente: 4096 píxeles

Enviando comando START...

Esperando que termine el procesamiento...
Progreso: 100.0% (1024/1024 píxeles)
Procesamiento completado: 1024 píxeles procesados

Descargando imagen de 32x32...
...
Imagen descargada exitosamente: 1024 píxeles

Archivos generados:
  - input_64x64.txt
  - output_32x32.txt

¡Prueba completada exitosamente!
```

---

## 🔧 SOLUCIÓN DE PROBLEMAS

### Error: "Address already in use"

**Problema:** El servidor anterior sigue corriendo.

**Solución:**
1. Cierra System Console completamente (X en la ventana)
2. Vuelve a ejecutar `start_jtag_server.bat`

### Error: "Connection refused"

**Problema:** El servidor no está corriendo.

**Solución:**
1. Verifica que System Console esté abierto
2. Verifica que veas el mensaje "Esperando conexiones..."
3. Si no lo ves, ejecuta de nuevo el servidor

### Error: "No se encontró JTAG master"

**Problema:** La FPGA no está conectada o no está programada.

**Solución:**
1. Verifica el cable USB-Blaster
2. Verifica que la FPGA esté encendida
3. En Quartus Programmer, verifica que detecte el dispositivo
4. Programa la FPGA con el archivo `.sof`:
   ```
   quartus/downscale_project/output_files/Proyecto2Arqui.sof
   ```

### Error: "NumPy no está instalado"

**Problema:** Falta la librería NumPy.

**Solución:**
```cmd
pip install numpy
```

### El .BAT no encuentra System Console

**Problema:** Quartus instalado en otra ubicación.

**Solución:**
1. Abre `start_jtag_server.bat` con un editor de texto
2. Modifica la línea 12 con la ruta correcta:
   ```bat
   set QUARTUS_PATH=C:\ruta\a\tu\quartus\sopc_builder\bin
   ```

Rutas comunes:
- `C:\intelFPGA_lite\20.1\quartus\sopc_builder\bin`
- `C:\intelFPGA\20.1\quartus\sopc_builder\bin`
- `C:\altera\20.1\quartus\sopc_builder\bin`

---

## 📁 ARCHIVOS GENERADOS

Después de ejecutar el cliente, encontrarás en la carpeta `software/python/client/`:

- **`input_64x64.txt`** - Imagen de entrada (64×64 píxeles)
- **`output_32x32.txt`** - Imagen procesada (32×32 píxeles)

Estos archivos contienen matrices de valores de píxeles (0-255) que puedes abrir con cualquier editor de texto.

---

## 🎮 COMANDOS ÚTILES

### En System Console (servidor):

```tcl
# Cambiar directorio
cd C:/ruta/al/servidor

# Ejecutar servidor
source jtag_downscale_server.tcl

# Ver comandos disponibles (después de iniciar)
# El servidor estará esperando conexiones del cliente Python
```

### En Python (cliente):

```python
# Ejecutar cliente
python downscale_client.py

# Modificar el patrón de prueba
# Edita downscale_client.py línea ~384:
# Opciones: "gradient", "checkerboard", "constant", "random"
```

---

## 📋 ORDEN DE EJECUCIÓN

```
1. Programar FPGA (Quartus Programmer)
   └─► Archivo: output_files/Proyecto2Arqui.sof

2. Iniciar Servidor JTAG (System Console)
   └─► Ejecutar: start_jtag_server.bat
   └─► Dejar abierto

3. Ejecutar Cliente Python
   └─► Ejecutar: start_client.bat
   └─► Ver resultados
```

---

## ⚠️ NOTAS IMPORTANTES

1. El **servidor DEBE estar corriendo** antes de ejecutar el cliente
2. **NO cierres** System Console mientras uses el sistema
3. Si algo falla, **reinicia en este orden**:
   - Cierra cliente Python
   - Cierra System Console
   - Vuelve a iniciar servidor
   - Vuelve a ejecutar cliente

---

## ✅ VERIFICACIÓN RÁPIDA

Para verificar que todo funciona:

1. ✅ Ejecuta `start_jtag_server.bat`
2. ✅ Ves "Esperando conexiones..."
3. ✅ Ejecuta `start_client.bat`
4. ✅ Ves "¡Prueba completada exitosamente!"
5. ✅ Se crearon `input_64x64.txt` y `output_32x32.txt`

Si todos los pasos anteriores funcionaron: **¡Sistema funcionando correctamente!** 🎉

---

## 📞 CONTACTO Y AYUDA

Si tienes problemas:

1. Verifica la sección de **Solución de Problemas** arriba
2. Revisa el documento completo: `docs/FASE6_PASOS_RAPIDOS.md`
3. Revisa el documento técnico: `docs/FASE6_INSTRUCCIONES.md`

---

**Última actualización:** Diciembre 2025
