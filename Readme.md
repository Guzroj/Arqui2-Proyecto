# 🎯 Proyecto DSA Downscaler - Intel DE1-SoC

**Acelerador Hardware para Downscaling de Imágenes con Interpolación Bilineal**

Plataforma: Intel DE1-SoC (Cyclone V 5CSEMA5F31C6)  
Herramientas: Quartus Prime 20.1, Platform Designer, SystemVerilog  
Fecha: Noviembre 2025

---

## ✅ Estado del Proyecto

**FASE 4 COMPLETADA** - Sistema compilado, programado y verificado  
**FASE 5 EN PROGRESO** - Scripts JTAG y pruebas completas

### Recursos Utilizados:
- **Logic (ALMs):** 9,400 / 32,070 (29%) ✅
- **Registros:** 3,186 ✅
- **DSP Blocks:** 87 / 87 (100%) ✅
- **SDRAM:** 64 MB disponible ✅

---

## 🚀 Inicio Rápido

### 1. **Programar la FPGA**

```
Quartus → Tools → Programmer
- Hardware: USB-Blaster
- File: output_files/ModoSecuencial.sof
- Click "Start"
```

### 2. **Verificar Sistema**

```tcl
# Abrir System Console
cd "tcl"
source test_dsa_basic.tcl
```

### 3. **Ejecutar Test Completo**

```tcl
source full_test.tcl
test_512_to_256_sequential "input_512x512.txt"
```

---

## 📁 Estructura del Proyecto

```
Arqui2-Proyecto1/
├── rtl/                          # Archivos HDL
│   ├── Downscale_SIMD.sv         # Core SIMD (N=4)
│   ├── Downscale_Secuencial.sv   # Core Secuencial
│   ├── DSA_Avalon_Wrapper.sv     # Wrapper principal
│   ├── DSA_Control_Registers.sv  # Registros de control
│   ├── DSA_Memory_Adapter.sv     # Adaptador de memoria
│   └── ...                       # Otros módulos
│
├── tcl/                          # Scripts TCL para JTAG
│   ├── test_dsa_basic.tcl        # Verificación básica
│   ├── load_image.tcl            # Cargar imagen a SDRAM
│   ├── run_downscale.tcl         # Ejecutar procesamiento
│   ├── read_result.tcl           # Leer resultado
│   ├── full_test.tcl             # Test automatizado
│   ├── dsa_avalon_wrapper_hw.tcl # Definición IP
│   └── README_TCL_SCRIPTS.md     # Guía de scripts
│
├── qsys/                         # Sistema Platform Designer
│   └── dsa_system/
│       ├── dsa_system.qsys       # Diseño del sistema
│       └── synthesis/            # HDL generado
│
├── Python/                       # Scripts Python (futuros)
│   └── image_converter.py        # Conversión de imágenes
│
├── doc/                          # Documentación
│   ├── RESUMEN_TECNICO_FASES.md  # Documentación completa
│   └── SOLUCION_DEFINITIVA_512x512.md
│
└── output_files/                 # Archivos de compilación
    └── ModoSecuencial.sof        # Archivo de programación
```

---

## 🎯 Características

### Hardware DSA:
- ✅ **Dual-Mode:** Secuencial (1 píxel/ciclo) + SIMD (4 píxeles/ciclo)
- ✅ **Interpolación Bilineal:** Precisión Q0.8/Q0.16
- ✅ **Dimensiones Dinámicas:** Configurables hasta 512×512
- ✅ **Interfaz Avalon-MM:** Compatible con Qsys
- ✅ **SDRAM 64MB:** Para almacenamiento de imágenes
- ✅ **Performance Counters:** Métricas completas

### Software:
- ✅ **Scripts TCL:** Control completo vía JTAG
- ✅ **Test Automatizados:** Verificación y benchmark
- ✅ **Comparación de Resultados:** Validación automática
- 🔄 **Scripts Python:** En desarrollo

---

## 📊 Performance

### Downscaling 512×512 → 256×256:

| Modo | Ciclos @ 50MHz | Tiempo | Throughput |
|------|----------------|--------|------------|
| **Secuencial** | ~65,536 | ~1.3 ms | ~50K píx/s |
| **SIMD (N=4)** | ~16,384 | ~0.3 ms | ~200K píx/s |
| **Speedup** | **4.0×** | **4.0×** | **4.0×** |

---

## 🔧 Uso de Scripts TCL

Consulta la guía completa en: **`tcl/README_TCL_SCRIPTS.md`**

### Test Básico:
```tcl
source test_dsa_basic.tcl
```

### Cargar Imagen:
```tcl
source load_image.tcl
load_image_to_sdram "input.txt" 512 512
```

### Ejecutar Downscale:
```tcl
source run_downscale.tcl
run_downscale 512 512 256 256 0    # Modo Secuencial
run_downscale 512 512 256 256 1    # Modo SIMD
```

### Leer Resultado:
```tcl
source read_result.tcl
read_result_from_sdram "output.txt" 256 256 0x00100000
```

### Test Completo Automatizado:
```tcl
source full_test.tcl
test_512_to_256_simd "input.txt"
```

### Benchmark:
```tcl
benchmark_seq_vs_simd "input.txt" 512 512 256 256
```

---

## 📝 Formato de Archivos

### Imagen de Entrada (.txt):
```
pixel_0     (0-255)
pixel_1     (0-255)
pixel_2     (0-255)
...
pixel_N-1   (0-255)
```

- Un píxel por línea
- Valores: 0-255 (grayscale)
- Total líneas = width × height
- Orden: fila por fila

---

## 🗺️ Mapa de Memoria

| Componente | Base Address | Tamaño | Descripción |
|------------|--------------|--------|-------------|
| **SDRAM** | 0x00000000 | 64 MB | Almacenamiento de imágenes |
| **LEDs** | 0x04000000 | 256 B | PIO para LEDs de debug |
| **DSA** | 0x05000000 | 48 B | Registros de control DSA |

### Registros DSA (Base: 0x05000000):

| Offset | Nombre | Tipo | Descripción |
|--------|--------|------|-------------|
| 0x00 | CTRL | R/W | start(0), reset_counters(1), mode(2) |
| 0x04 | STATUS | RO | busy(0), done(1), error(2) |
| 0x08 | IMG_WIDTH_IN | R/W | Ancho imagen entrada |
| 0x0C | IMG_HEIGHT_IN | R/W | Alto imagen entrada |
| 0x10 | IMG_WIDTH_OUT | R/W | Ancho imagen salida |
| 0x14 | IMG_HEIGHT_OUT | R/W | Alto imagen salida |
| 0x18 | INPUT_BASE | R/W | Dirección base memoria entrada |
| 0x1C | OUTPUT_BASE | R/W | Dirección base memoria salida |
| 0x20 | PERF_CYCLES | RO | Contador de ciclos de reloj |
| 0x24 | PERF_READS | RO | Contador de lecturas |
| 0x28 | PERF_WRITES | RO | Contador de escrituras |
| 0x2C | PERF_FLOPS | RO | Contador de operaciones FP |

---

## 📚 Documentación

- **`RESUMEN_TECNICO_FASES.md`** - Documentación completa del desarrollo
- **`SOLUCION_DEFINITIVA_512x512.md`** - Solución a problemas de recursos
- **`tcl/README_TCL_SCRIPTS.md`** - Guía completa de scripts TCL

---

## 🐛 Troubleshooting

### FPGA no responde:
1. Verificar que esté programada (LEDs deben estar encendidos)
2. Verificar cable USB-Blaster
3. Ejecutar `test_dsa_basic.tcl` para diagnóstico

### DSA no procesa:
1. Verificar que STATUS indique IDLE (busy=0)
2. Verificar dimensiones configuradas
3. Verificar que imagen esté cargada en SDRAM

### Resultados incorrectos:
1. Comparar con archivo esperado usando `compare_images`
2. Verificar formato de entrada (un píxel por línea)
3. Verificar que dimensiones coincidan

---

## 👥 Autores

**Proyecto de Arquitectura de Computadoras 2**  
Universidad de San Carlos de Guatemala  
Noviembre 2025

---

## 📄 Licencia

Proyecto académico - Universidad de San Carlos de Guatemala

---

## 🔗 Enlaces Útiles

- [Manual DE1-SoC](https://www.terasic.com.tw/cgi-bin/page/archive.pl?No=836)
- [Quartus Prime Lite](https://www.intel.com/content/www/us/en/software/programmable/quartus-prime/download.html)
- [Avalon Interface Specifications](https://www.intel.com/content/www/us/en/programmable/documentation/nik1398707230472.html)

---

**Última actualización:** 30 Noviembre 2025  
**Estado:** Sistema funcional - Fase 5 en progreso


