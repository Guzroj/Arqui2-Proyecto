# 📝 COMANDOS TCL PARA EJECUTAR EN JTAG SYSTEM CONSOLE

## 🚀 SECUENCIA COMPLETA DE COMANDOS

### **PASO 1: Conectar a JTAG System Console**

Abrir: `Tools` → `System Console` en Quartus

---

### **PASO 2: Cargar los scripts necesarios**

Ejecutar en orden:

```tcl
# 1. Script básico con funciones de conexión y utilidades
source tcl/test_basic_jtag.tcl

# 2. Script para cargar imágenes desde archivos
source tcl/load_image_txt.tcl

# 3. Script de diagnóstico (opcional, pero útil)
source tcl/diagnose_busy.tcl

# 4. Script de test completo
source tcl/test_downscale_complete.tcl
```

---

### **PASO 3: Ejecutar el test completo**

Tienes dos opciones:

#### **Opción A: Test rápido (4×4 → 2×2, sin archivo)**

```tcl
test_downscale_quick
```

Esta función:
- Genera una imagen de prueba automáticamente
- Configura DSA para 4×4 → 2×2
- Ejecuta el downscaling
- Muestra resultados

---

#### **Opción B: Test completo con imagen real**

```tcl
test_downscale_complete "../imagen_grayscale.txt" 512 512 256 256
```

Parámetros:
- `"../imagen_grayscale.txt"` - Ruta al archivo de imagen
- `512` - Ancho imagen entrada
- `512` - Alto imagen entrada  
- `256` - Ancho imagen salida
- `256` - Alto imagen salida

**Otras configuraciones comunes:**

```tcl
# Para 256×256 → 128×128
test_downscale_complete "../imagen_grayscale.txt" 256 256 128 128

# Para 1024×1024 → 512×512
test_downscale_complete "../imagen_grayscale.txt" 1024 1024 512 512
```

---

## 🔍 COMANDOS ÚTILES ADICIONALES

### **Verificar conexión básica:**

```tcl
test_basic_connection
```

### **Leer registros DSA:**

```tcl
read_dsa_registers
```

### **Monitorear estado en tiempo real:**

```tcl
monitor_busy_status
```

### **Diagnóstico completo si hay problemas:**

```tcl
full_diagnosis
```

---

## ✅ QUÉ ESPERAR EN EL OUTPUT

### **Si todo funciona correctamente:**

```
PASO 1/6: Conectando a JTAG...
Conexion establecida

PASO 2/6: Verificando estado inicial...
Sistema esta idle y listo

PASO 3/6: Cargando imagen de entrada...
Imagen cargada
Primeros 16 pixeles...

PASO 4/6: Configurando DSA...
Configuracion aplicada:
   Entrada:  512x512
   Salida:   256x256

PASO 5/6: Iniciando procesamiento...
Sistema inicio procesamiento (busy=1)

PASO 6/6: Monitoreando progreso...

Tiempo   busy   done   CYCLES       READS        WRITES       ΔREADS    Progreso  
-------------------------------------------------------------------------------------
0.0      1      0      3215078      100          0            100       0.1%
1.0      1      0      55011026     500          0            400       0.5%
2.1      1      0      106052476    1000         100          500       1.0%
...
[N minutos después]
...
Procesamiento completado!

EXTRA: Guardando imagen de salida...
Imagen guardada en: ../imagen_output_complete.txt

  TEST COMPLETADO EXITOSAMENTE
```

### **Indicadores de éxito:**

✅ **PERF_READS > 0** - Las lecturas están funcionando  
✅ **PERF_READS aumenta** - El procesamiento avanza  
✅ **busy = 0, done = 1** - El procesamiento terminó  
✅ **Progreso aumenta** - El porcentaje avanza hacia 100%

---

## ⚠️ SI HAY PROBLEMAS

### **Si PERF_READS sigue en 0:**

```tcl
# Ejecutar diagnóstico
diagnose_busy_stuck

# O verificar manualmente
set status [read_reg $DSA_BASE_ADDR $REG_STATUS]
set reads [read_reg $DSA_BASE_ADDR $REG_PERF_READS]
puts "STATUS: $status, READS: $reads"
```

### **Si busy nunca termina:**

```tcl
# Ver estado actual
read_dsa_registers

# Monitorear en tiempo real
monitor_busy_status
```

### **Si hay errores de conexión:**

```tcl
# Verificar conexión
test_basic_connection

# Re-conectar manualmente
connect_jtag
```

---

## 📋 SECUENCIA RÁPIDA (COPY-PASTE)

Copia y pega todo esto de una vez:

```tcl
source tcl/test_basic_jtag.tcl
source tcl/load_image_txt.tcl
source tcl/diagnose_busy.tcl
source tcl/test_downscale_complete.tcl

# Para test rápido (4×4 → 2×2)
test_downscale_quick

# O para test completo con imagen
# test_downscale_complete "../imagen_grayscale.txt" 512 512 256 256
```

---

## 🎯 RECOMENDACIÓN

**Para la primera prueba después de las correcciones:**

1. **Primero ejecuta el test rápido:**
   ```tcl
   test_downscale_quick
   ```
   - Es más rápido (solo 16 píxeles)
   - Te dirá rápidamente si las correcciones funcionaron
   - Si funciona, puedes pasar al test completo

2. **Si el test rápido funciona, prueba con imagen real:**
   ```tcl
   test_downscale_complete "../imagen_grayscale.txt" 512 512 256 256
   ```

---

¡Buena suerte! 🚀

