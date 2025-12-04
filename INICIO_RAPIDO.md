# 🚀 INICIO RÁPIDO - Proyecto Downscaling FPGA

**Estado actual**: ✅ FASES 0, 1, 2 COMPLETADAS

---

## ⚡ Empezar AHORA (5 minutos)

### Opción 1: Script automático (Windows)

```cmd
RUN_TESTS.bat
```

Este script:
1. ✅ Verifica Python y C++
2. ✅ Ejecuta tests Python (FASE 1)
3. ✅ Compila modelo C++ (FASE 2)
4. ✅ Valida Python ↔ C++

### Opción 2: Manual (cualquier OS)

```bash
# Test Python
cd software/python
python TEST_FASE1.py

# Compilar C++
cd ../reference_model
make  # o mingw32-make en Windows

# Validación cruzada
cd ../python/utils
python validate_cpp_model.py
```

---

## 📋 Lo que YA está HECHO

### ✅ FASE 0: Setup
- Estructura de carpetas completa
- Documentación generada

### ✅ FASE 1: Modelo Python
Archivos creados:
- `software/python/reference/fixed_point.py` - Aritmética Q8.8
- `software/python/reference/bilinear_interpolation.py` - Interpolación
- `software/python/reference/downscale.py` - Downscaling completo
- `software/python/utils/create_test_images.py` - Generar pruebas
- `software/python/TEST_FASE1.py` - Script de prueba

### ✅ FASE 2: Modelo C++
Archivos creados:
- `software/reference_model/include/*.h` - Headers (3 archivos)
- `software/reference_model/src/*.cpp` - Implementación (3 archivos)
- `software/reference_model/Makefile` - Build system
- `software/python/utils/validate_cpp_model.py` - Validación cruzada

---

## 📖 Documentación Clave

| Documento | Ubicación | Descripción |
|-----------|-----------|-------------|
| **Guía Completa** | `docs/GUIA_COMPLETA_PROYECTO.md` | Todas las 11 fases |
| **Resumen Fases 0-2** | `docs/progress/RESUMEN_FASES_0_1_2.md` | Lo que hicimos |
| **README C++** | `software/reference_model/README.md` | Usar modelo C++ |
| **Este archivo** | `INICIO_RAPIDO.md` | Empezar rápido |

---

## 🎯 Próximos Pasos

### Después de validar FASES 1-2:

**→ FASE 3: Test de JTAG con LEDs**

Pregúntame:
```
"Claude, estoy listo para FASE 3: Test de JTAG con LEDs"
```

Y yo te generaré:
- Diseño Verilog con Virtual JTAG
- Servidor TCL para comunicación
- Cliente Python para probar
- Proyecto Quartus

---

## ❓ ¿Problemas?

### Python no funciona

**Error**: `python: command not found`

**Solución**:
1. Instalar Python 3.x desde https://www.python.org/
2. Verificar: `python --version`
3. Instalar librerías: `pip install numpy matplotlib pillow`

### C++ no compila

**Error**: `g++: command not found` (Windows)

**Solución**:
1. Instalar MinGW-w64 desde https://www.mingw-w64.org/
2. Agregar a PATH: `C:\mingw64\bin`
3. Verificar: `g++ --version`

**Error**: `make: command not found` (Windows)

**Solución**:
Usar `mingw32-make` en lugar de `make`

### Tests Python fallan

**Error**: `ModuleNotFoundError: No module named 'numpy'`

**Solución**:
```bash
pip install numpy matplotlib pillow
```

### Validación cruzada falla

**Error**: Match < 95%

**Posibles causas**:
1. Diferencias en redondeo Q8.8
2. Bug en implementación
3. Compilador optimizó incorrectamente

**Diagnóstico**:
1. Revisar output detallado de `validate_cpp_model.py`
2. Comparar píxeles específicos que difieren
3. Verificar cálculos Q8.8 manualmente

---

## 📊 Estructura del Proyecto

```
Arqui2ProyectoInicio/
│
├── 📄 INICIO_RAPIDO.md           ← ESTE ARCHIVO
├── 📄 RUN_TESTS.bat              ← Script de prueba rápida
│
├── 📁 docs/
│   ├── GUIA_COMPLETA_PROYECTO.md  ← Guía maestra (11 fases)
│   └── progress/
│       ├── FASE_0_CHECKLIST.md
│       └── RESUMEN_FASES_0_1_2.md
│
├── 📁 software/
│   ├── python/                    ← ✅ COMPLETO
│   │   ├── reference/             ← Modelo Python Q8.8
│   │   ├── utils/                 ← Herramientas
│   │   ├── test_images/           ← (se genera al ejecutar)
│   │   └── TEST_FASE1.py          ← Ejecutar tests
│   │
│   └── reference_model/           ← ✅ COMPLETO
│       ├── include/               ← Headers C++
│       ├── src/                   ← Implementación C++
│       ├── Makefile               ← Build system
│       └── README.md
│
├── 📁 rtl/                        ← (Futuro: FASE 3+)
├── 📁 tb/                         ← (Futuro: FASE 4+)
├── 📁 quartus/                    ← (Futuro: FASE 3+)
└── 📁 validation/                 ← (Futuro: FASE 7+)
```

---

## ✅ Checklist Pre-FASE 3

Antes de continuar con FASE 3, verificar:

- [ ] Python funciona: `python --version`
- [ ] Librerías instaladas: `pip list | grep numpy`
- [ ] C++ compila: `g++ --version`
- [ ] Tests Python pasan: `python TEST_FASE1.py`
- [ ] Modelo C++ compila: `make` exitoso
- [ ] Validación cruzada: Match ≥95%
- [ ] Quartus instalado: `quartus --version` (20.1.x)
- [ ] ModelSim instalado: `vsim -version`

---

## 🔗 Links Útiles

- **Especificación del proyecto**: `Proyectos_especificacion_proyecto_02_CE_4302_S2_2025.pdf`
- **Tutorial JTAG**: https://idlelogiclabs.com/2012/04/15/talking-to-the-de0-nano-using-the-virtual-jtag-interface/
- **Ejemplo GuiaJtag**: https://github.com/Abner2111/GuiaJtag
- **Fixed Point en Verilog**: https://projectf.io/posts/fixed-point-numbers-in-verilog/

---

## 💬 ¿Dudas?

Pregúntame sobre:
- ❓ "¿Cómo funciona Q8.8?"
- ❓ "¿Por qué el modelo C++ da resultados diferentes?"
- ❓ "¿Cuál es la fórmula de interpolación bilineal?"
- ❓ "¿Qué hace cada archivo Python?"
- ❓ "¿Cómo compilo en Visual Studio en lugar de MinGW?"

O simplemente:
```
"Claude, tengo un problema con [descripción del problema]"
```

---

## 🎉 ¡Éxito!

Si llegaste hasta aquí y todos los tests pasan:

**🎊 FELICITACIONES 🎊**

Has completado las **3 primeras fases** del proyecto:
1. ✅ Setup y estructura
2. ✅ Modelo de referencia Python
3. ✅ Modelo de referencia C++

**Quedan 8 fases más**, pero has sentado bases sólidas.

**Próximo hito**: Validar comunicación JTAG con LEDs (FASE 3)

---

**¿Listo para continuar?**

Dime: **"Claude, FASE 3"** y empezamos con JTAG! 🚀
