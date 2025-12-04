# Proyecto 02: DSA para Downscaling de Imágenes con Interpolación Bilineal

**Curso**: CE-4302 Arquitectura de Computadores II
**Instituto Tecnológico de Costa Rica**

---

## 📖 Descripción

Implementación de una Arquitectura de Dominio Específico (DSA) en FPGA que realiza reducción de imágenes mediante interpolación bilineal, aplicando paralelismo a nivel de datos (DLP) en configuraciones secuencial y vectorial SIMD.

### Características
- ✅ Interpolación bilineal usando aritmética de punto fijo Q8.8
- ✅ Dos modos operativos: Secuencial (1 píxel/ciclo) y SIMD (4 píxeles/ciclo)
- ✅ Comunicación FPGA-PC via Virtual JTAG
- ✅ Soporte hasta 512×512 → 256×256 píxeles
- ✅ Validación bit-a-bit con modelos de referencia Python y C++

---

## 🚀 INICIO RÁPIDO

**¿Primera vez aquí?** → Ver [INICIO_RAPIDO.md](INICIO_RAPIDO.md)

### Ejecutar tests:

```bash
# Windows
RUN_TESTS.bat

# Linux/Mac
cd software/python && python TEST_FASE1.py
cd ../reference_model && make
cd ../python/utils && python validate_cpp_model.py
```

---

## 📊 Estado del Proyecto

| Fase | Nombre | Estado | Archivos |
|------|--------|--------|----------|
| 0 | Setup y Preparación | ✅ COMPLETA | Estructura de carpetas |
| 1 | Modelo Python Q8.8 | ✅ COMPLETA | 5 archivos Python |
| 2 | Modelo C++ Q8.8 | ✅ COMPLETA | 6 archivos C++ + Makefile |
| 3 | Test JTAG con LEDs | ⬜ PENDIENTE | - |
| 4 | Memoria de Imagen | ⬜ PENDIENTE | - |
| 5 | Interpolación Secuencial | ⬜ PENDIENTE | - |
| 6 | Integración JTAG + Downscaling | ⬜ PENDIENTE | - |
| 7 | Validación Hardware | ⬜ PENDIENTE | - |
| 8 | Modo SIMD Paralelo | ⬜ PENDIENTE | - |
| 9 | Performance Counters | ⬜ PENDIENTE | - |
| 10 | Escalamiento 512×512 | ⬜ PENDIENTE | - |
| 11 | Documentación Final | ⬜ PENDIENTE | - |

**Progreso**: 2/11 fases (~18%)

---

## 📁 Estructura del Proyecto

```
Arqui2ProyectoInicio/
│
├── README.md                    ← Este archivo
├── INICIO_RAPIDO.md             ← Guía de inicio rápido
├── RUN_TESTS.bat                ← Script de prueba
│
├── docs/                        ← Documentación
│   ├── GUIA_COMPLETA_PROYECTO.md
│   ├── progress/
│   │   ├── FASE_0_CHECKLIST.md
│   │   └── RESUMEN_FASES_0_1_2.md
│   ├── architecture/            (futuro)
│   └── validation_plan/         (futuro)
│
├── software/                    ← Software de soporte
│   ├── python/                  ← ✅ Modelo Python
│   │   ├── reference/           → Q8.8, interpolación, downscale
│   │   ├── utils/               → Herramientas
│   │   └── TEST_FASE1.py
│   │
│   ├── reference_model/         ← ✅ Modelo C++
│   │   ├── include/             → Headers
│   │   ├── src/                 → Implementación
│   │   ├── Makefile
│   │   └── README.md
│   │
│   └── tcl/                     (futuro: FASE 3)
│
├── rtl/                         (futuro: FASE 4+)
│   ├── top/
│   ├── jtag/
│   ├── downscale/
│   ├── memory/
│   └── common/
│
├── tb/                          (futuro: FASE 5+)
│   ├── unit/
│   └── integration/
│
├── quartus/                     (futuro: FASE 3+)
│   └── downscale_project/
│
└── validation/                  (futuro: FASE 7+)
    ├── simulation/
    ├── hardware/
    └── comparisons/
```

---

## 🛠️ Requisitos

### Software
- **Quartus Prime Lite 20.1** - Síntesis y programación FPGA
- **ModelSim** (incluido con Quartus) - Simulación
- **Python 3.x** - Modelo de referencia
  - numpy, matplotlib, Pillow
- **Compilador C++** - Modelo de referencia
  - g++ 7.x+ (Linux/Mac)
  - MinGW-w64 (Windows)
  - Visual Studio 2015+ (Windows)

### Hardware
- **Tarjeta DE1-SoC MTL2** - FPGA Cyclone V
- **Cable USB-Blaster** (incluido con tarjeta)

---

## 📚 Documentación

| Documento | Descripción |
|-----------|-------------|
| [GUIA_COMPLETA_PROYECTO.md](docs/GUIA_COMPLETA_PROYECTO.md) | Guía maestra (11 fases) |
| [INICIO_RAPIDO.md](INICIO_RAPIDO.md) | Empezar en 5 minutos |
| [RESUMEN_FASES_0_1_2.md](docs/progress/RESUMEN_FASES_0_1_2.md) | Fases completadas |
| [reference_model/README.md](software/reference_model/README.md) | Usar modelo C++ |

---

## 🧪 Tests y Validación

### Modelo Python
```bash
cd software/python
python TEST_FASE1.py
```

Tests incluidos:
- ✅ Aritmética Q8.8 (conversiones, multiplicación, suma)
- ✅ Interpolación bilineal (casos esquina, gradientes, aleatorios)
- ✅ Downscaling completo (64×64 → 32×32)
- ✅ Generación de suite de pruebas (10 patrones)

### Modelo C++
```bash
cd software/reference_model
make
./bin/downscale input.txt output.txt 64 64 32 32
```

### Validación Cruzada Python ↔ C++
```bash
cd software/python/utils
python validate_cpp_model.py
```

**Criterio**: ≥95% de píxeles idénticos o diff ≤ 1

---

## 🎯 Roadmap

### ✅ Completado
- [x] **FASE 0**: Estructura del proyecto
- [x] **FASE 1**: Modelo de referencia Python con Q8.8
- [x] **FASE 2**: Modelo de referencia C++ con Q8.8

### 🚧 En progreso
- [ ] **FASE 3**: Test de JTAG con LEDs

### 📅 Próximas fases
- **FASE 4**: Memoria de imagen (BRAM M10K)
- **FASE 5**: Interpolación secuencial en hardware
- **FASE 6**: Integración JTAG + downscaling
- **FASE 7**: Validación hardware vs referencia
- **FASE 8**: Modo SIMD (4 píxeles/ciclo)
- **FASE 9**: Performance counters (FLOPs, mem accesses)
- **FASE 10**: Escalamiento a 512×512 pixels
- **FASE 11**: Documentación final (artículo + plan verificación)

---

## 📦 Entregables Finales

Según especificación del proyecto:

1. ✅ Código SystemVerilog sintetizable
2. ✅ Modelo de referencia C/C++
3. ⬜ Aplicación de comunicación PC (TCL + Python)
4. ⬜ Testbenches unitarios e integración
5. ⬜ Plan de verificación
6. ⬜ Artículo científico
7. ⬜ Bitstream para DE1-SoC MTL2
8. ✅ README con instrucciones

---

## 🤝 Uso del Proyecto

### Para desarrollo:

1. **Leer guía completa**: `docs/GUIA_COMPLETA_PROYECTO.md`
2. **Ejecutar tests**: `RUN_TESTS.bat` o scripts individuales
3. **Seguir fases secuencialmente**: No saltar fases
4. **Validar cada fase**: Usar checkpoints definidos

### Para revisión:

1. **Ver estado**: Este README
2. **Ver código**: Carpetas `software/`, `rtl/`, `tb/`
3. **Ejecutar tests**: Scripts de prueba incluidos
4. **Ver resultados**: Carpeta `validation/`

---

## 📝 Notas Importantes

### Formato Q8.8
- **16 bits totales**: 8 enteros + 8 fraccionarios
- **Rango**: 0.00 - 255.996
- **Precisión**: 1/256 ≈ 0.004
- **Ejemplo**: 100.5 → 25728 (0x6480)

### Estrategia Incremental
- Empezamos con **64×64 → 32×32** (4 KB)
- Escalamos a **512×512 → 256×256** (262 KB) en FASE 10
- **Modo secuencial primero**, SIMD después

### Validación Bit-a-Bit
- Hardware debe ser **idéntico** a modelo C++
- Tolerancia: ±1 píxel por redondeo
- Mínimo: **95% match**

---

## 🔗 Referencias

- [Especificación del Proyecto](Proyectos_especificacion_proyecto_02_CE_4302_S2_2025.pdf)
- [Tutorial Virtual JTAG](https://idlelogiclabs.com/2012/04/15/talking-to-the-de0-nano-using-the-virtual-jtag-interface/)
- [GuiaJtag Repository](https://github.com/Abner2111/GuiaJtag)
- [Fixed Point in Verilog](https://projectf.io/posts/fixed-point-numbers-in-verilog/)
- [Hennessy & Patterson - Computer Architecture](https://www.elsevier.com/books/computer-architecture/hennessy/978-0-12-811905-1)

---

## 👥 Equipo

**Estudiante**: José Venegas
**Curso**: CE-4302 Arquitectura de Computadores II
**Semestre**: II 2025
**Fecha de entrega**: 23-24 de octubre, 2025

---

## 📞 Soporte

¿Dudas o problemas?

1. **Revisar documentación**: `docs/GUIA_COMPLETA_PROYECTO.md`
2. **Consultar ejemplos**: Carpeta `software/`
3. **Ver logs de progreso**: `docs/progress/`

---

## ✅ Checklist Rápido

Antes de empezar:
- [ ] Quartus 20.1 instalado
- [ ] Python 3.x con numpy, matplotlib, Pillow
- [ ] Compilador C++ (g++/MinGW/Visual Studio)
- [ ] Tarjeta DE1-SoC disponible
- [ ] Cable USB-Blaster conectado

Validación FASES 1-2:
- [ ] `python TEST_FASE1.py` → ✅ PASS
- [ ] `make` compila sin errores
- [ ] `python validate_cpp_model.py` → Match ≥95%

Listo para FASE 3:
- [ ] Todas las validaciones anteriores pasaron
- [ ] Quartus funcional (`quartus --version`)
- [ ] ModelSim funcional (`vsim -version`)

---

**Estado**: 🟢 Proyecto activo | Fases 0-2 completadas | Listo para FASE 3

**Última actualización**: 2025-12-03
