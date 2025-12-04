# 🔄 PASOS PARA REGENERAR Y COMPILAR DESPUÉS DE MODIFICAR DSA_Memory_Adapter.sv

## ✅ CAMBIOS REALIZADOS

Modificamos `rtl/DSA_Memory_Adapter.sv` para corregir el bloqueo en el estado ARB_READ.

---

## 📋 PASOS REQUERIDOS

### **PASO 1: Regenerar HDL en Platform Designer (Qsys)**

1. **Abrir Quartus Prime**

2. **Abrir Platform Designer:**
   - `Tools` → `Platform Designer`
   - O buscar el archivo `qsys/qsys/dsa_system.qsys` y abrirlo directamente

3. **Abrir el sistema:**
   - En Platform Designer, `File` → `Open...`
   - Navegar a: `qsys/qsys/dsa_system.qsys`
   - Clic en `Open`

4. **Verificar que el componente DSA está presente:**
   - Deberías ver `dsa_downscaler_0` en la lista de componentes

5. **Regenerar HDL:**
   - `File` → `Generate` → `Generate HDL...`
   - O usar el botón `Generate HDL` en la barra de herramientas
   - Esperar a que complete la generación

   ⚠️ **Importante:** Platform Designer copiará los archivos desde `rtl/` a `qsys/qsys/synthesis/submodules/`

6. **Cerrar Platform Designer:**
   - Ya no es necesario mantenerlo abierto

---

### **PASO 2: Verificar que los cambios se copiaron**

Platform Designer debería haber copiado automáticamente:
- `rtl/DSA_Memory_Adapter.sv` → `qsys/qsys/synthesis/submodules/DSA_Memory_Adapter.sv`

**Verificar:**
- Abrir `qsys/qsys/synthesis/submodules/DSA_Memory_Adapter.sv`
- Buscar las líneas con `read_issued` y `read_address_hold`
- Si están presentes, los cambios se copiaron correctamente ✅

---

### **PASO 3: Compilar el Proyecto en Quartus**

1. **Abrir el proyecto en Quartus:**
   - Si no está abierto, abrir el proyecto principal

2. **Actualizar archivos (opcional pero recomendado):**
   - `Project` → `Add/Remove Files in Project...`
   - Verificar que todos los archivos están incluidos

3. **Iniciar compilación:**
   - `Processing` → `Start Compilation`
   - O usar el botón `Start Compilation` (▶️) en la barra de herramientas

4. **Esperar a que complete:**
   - Esto puede tomar varios minutos dependiendo del tamaño del proyecto
   - Verificar que no haya errores en la ventana de mensajes

5. **Verificar advertencias:**
   - Revisar si hay advertencias importantes (algunas advertencias menores son normales)

---

### **PASO 4: Reprogramar FPGA**

1. **Conectar FPGA:**
   - Conectar el cable USB Blaster
   - Encender la placa

2. **Programar:**
   - `Tools` → `Programmer`
   - Clic en `Auto Detect` si es necesario
   - Seleccionar el archivo `.sof` generado
   - Clic en `Start` para programar

---

### **PASO 5: Probar los cambios**

1. **Abrir JTAG System Console:**
   - `Tools` → `System Console`

2. **Ejecutar el test:**
   ```tcl
   source tcl/test_downscale_complete.tcl
   test_downscale_complete "../imagen_grayscale.txt" 512 512 256 256
   ```

3. **Verificar:**
   - ✅ `PERF_READS` debería incrementar (ya no será 0)
   - ✅ El procesamiento debería completarse
   - ✅ `busy` debería terminar y `done` activarse

---

## 🔍 VERIFICACIÓN RÁPIDA

### Verificar que los cambios están en el archivo copiado:

Buscar en `qsys/qsys/synthesis/submodules/DSA_Memory_Adapter.sv`:

```systemverilog
// Debe existir alrededor de la línea 105:
logic        read_issued;
logic [31:0] read_address_hold;
```

Y alrededor de la línea 277-323 debe estar el estado ARB_READ corregido con las 3 fases.

---

## ⚠️ PROBLEMAS COMUNES

### **Problema 1: Platform Designer no encuentra los archivos**

**Solución:**
- Verificar que la ruta en `dsa_avalon_wrapper_hw.tcl` está correcta
- La ruta relativa debe ser `../rtl/DSA_Memory_Adapter.sv` desde la carpeta del IP

### **Problema 2: Los cambios no se reflejan**

**Solución:**
- Asegurarse de regenerar HDL en Platform Designer
- Verificar que el archivo en `synthesis/submodules/` tiene las modificaciones
- Si no, copiar manualmente el archivo desde `rtl/`

### **Problema 3: Errores de compilación**

**Solución:**
- Revisar mensajes de error en la ventana de compilación
- Verificar que no haya errores de sintaxis en `DSA_Memory_Adapter.sv`
- Si hay errores, revisar que todas las señales estén declaradas

---

## 📝 NOTAS

- **Tiempo estimado:** 
  - Regenerar HDL: ~30 segundos
  - Compilar: 5-15 minutos (depende del tamaño)
  - Programar: ~10 segundos

- **Archivos modificados:**
  - `rtl/DSA_Memory_Adapter.sv` (archivo fuente)
  - `qsys/qsys/synthesis/submodules/DSA_Memory_Adapter.sv` (copia generada)

---

## ✅ CHECKLIST

- [ ] Abrir Platform Designer y cargar `dsa_system.qsys`
- [ ] Regenerar HDL (`File` → `Generate` → `Generate HDL...`)
- [ ] Verificar que los cambios se copiaron a `synthesis/submodules/`
- [ ] Compilar proyecto en Quartus
- [ ] Verificar que la compilación fue exitosa
- [ ] Programar FPGA
- [ ] Ejecutar test y verificar que `PERF_READS` aumenta

---

¡Buena suerte con la compilación! 🚀

