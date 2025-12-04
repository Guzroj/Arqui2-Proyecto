# FASE 0: Setup y Preparación - CHECKLIST

**Fecha inicio**: 2025-12-03
**Tiempo estimado**: 30 minutos

---

## ✅ Tareas Completadas

### 0.1 Estructura de carpetas
- [x] Carpeta `rtl/` con subdirectorios (top, jtag, downscale, memory, common)
- [x] Carpeta `tb/` con subdirectorios (unit, integration)
- [x] Carpeta `software/` con subdirectorios completos
- [x] Carpeta `quartus/`
- [x] Carpeta `docs/` con subdirectorios
- [x] Carpeta `validation/` con subdirectorios

### 0.2 Herramientas a verificar (PENDIENTE - Usuario debe verificar)
```bash
# Verificar Quartus Prime Lite 20.1
quartus --version
# Esperado: Version 20.1.x

# Verificar ModelSim
vsim -version
# Esperado: ModelSim-Intel/Altera

# Verificar Python
python --version
# Esperado: Python 3.x

# Verificar librerías Python
pip list | grep -E "numpy|matplotlib|Pillow"
# Esperado: numpy, matplotlib, Pillow

# Verificar compilador C++
g++ --version  # o mingw32-g++ en Windows
# Esperado: gcc/g++ 7.x o superior
```

### 0.3 Copiar ejemplo de referencia JTAG
**ACCIÓN MANUAL REQUERIDA**:
```bash
# Copiar desde:
C:\Users\josev\Downloads\vJTAG_DE0-Nano_Example\vJTAG_DE0-Nano_Example_restored\*

# Hacia:
C:\Users\josev\OneDrive\Documentos\Arqui2ProyectoInicio\software\tcl\reference_example\
```

Archivos importantes a estudiar:
- `vJTAG_interface.v` - Interfaz JTAG básica
- `TCL_Server_vJTAG_SimpleTest.tcl` - Servidor TCP/IP
- `LED_Counter.py` - Cliente Python

---

## 📝 Notas de Setup

### Estructura creada exitosamente
```
Arqui2ProyectoInicio/
├── rtl/
│   ├── top/
│   ├── jtag/
│   ├── downscale/
│   ├── memory/
│   └── common/
├── tb/
│   ├── unit/
│   └── integration/
├── software/
│   ├── reference_model/
│   │   ├── src/
│   │   ├── include/
│   │   └── test/
│   ├── python/
│   │   ├── reference/
│   │   ├── utils/
│   │   ├── client/
│   │   └── test_images/
│   └── tcl/
│       ├── server/
│       ├── client/
│       └── reference_example/
├── quartus/
│   └── downscale_project/
├── docs/
│   ├── GUIA_COMPLETA_PROYECTO.md
│   ├── architecture/
│   ├── validation_plan/
│   └── progress/
└── validation/
    ├── simulation/
    ├── hardware/
    └── comparisons/
```

---

## ⏭️ Próximos pasos

Una vez verificadas las herramientas, continuar con:
- **FASE 1**: Modelo de referencia Python
- **FASE 2**: Modelo de referencia C++

---

## ✅ Criterios de éxito FASE 0

- [x] Estructura de carpetas completa
- [ ] Quartus 20.1 funcional (verificar manualmente)
- [ ] ModelSim funcional (verificar manualmente)
- [ ] Python 3.x con numpy, matplotlib, PIL (verificar manualmente)
- [ ] Compilador C++ funcional (verificar manualmente)
- [ ] Ejemplo JTAG copiado (acción manual pendiente)

**Status**: ⚠️ PARCIALMENTE COMPLETO - Requiere verificación manual de herramientas
