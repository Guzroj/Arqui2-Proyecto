# Modelo de Referencia C++ - Downscaling con Interpolación Bilineal

Este es el modelo de referencia en C++ para el proyecto de downscaling de imágenes.
Implementa interpolación bilineal usando aritmética de punto fijo Q8.8.

## 📋 Requisitos

- Compilador C++ con soporte C++11 o superior
  - Linux/Mac: g++ 7.x o superior
  - Windows: MinGW-w64 o Visual Studio 2015+

## 🏗️ Compilación

### Linux/Mac

```bash
make
```

### Windows (MinGW)

```bash
mingw32-make
```

### Windows (Visual Studio)

Abrir Developer Command Prompt y:

```cmd
nmake /F Makefile
```

Alternativamente, compilar manualmente:

```bash
g++ -std=c++11 -O2 -Iinclude -o bin/downscale src/*.cpp
```

## 🚀 Uso

```bash
./bin/downscale input.txt output.txt src_w src_h dst_w dst_h
```

### Parámetros

- `input.txt`: Archivo de entrada (formato texto)
- `output.txt`: Archivo de salida
- `src_w`: Ancho de imagen fuente
- `src_h`: Alto de imagen fuente
- `dst_w`: Ancho de imagen destino
- `dst_h`: Alto de imagen destino

### Ejemplo

```bash
./bin/downscale imagen_64x64.txt salida_32x32.txt 64 64 32 32
```

## 📄 Formato de Archivos

### Archivo de entrada

```
altura ancho
pixel0 pixel1 pixel2 ...
```

Ejemplo (4×4):

```
4 4
128 200 100 50
130 195 105 55
125 190 110 60
120 185 115 65
```

### Archivo de salida

Mismo formato que entrada.

## 🧪 Tests

### Test por defecto

```bash
make run
```

Esto ejecuta un test con imagen de gradiente 64×64 → 32×32.

### Validación cruzada con Python

```bash
cd ../python/utils
python validate_cpp_model.py
```

Esto compara resultados C++ vs Python y verifica que sean idénticos (o diff ≤ 1).

## 📂 Estructura

```
reference_model/
├── include/          # Headers
│   ├── fixed_point.h   # Aritmética Q8.8
│   ├── bilinear.h      # Interpolación
│   └── image.h         # Manejo de imágenes
├── src/             # Implementación
│   ├── bilinear.cpp
│   ├── image.cpp
│   └── main.cpp
├── obj/             # Objetos (generado)
├── bin/             # Ejecutables (generado)
├── Makefile
└── README.md        # Este archivo
```

## 🔧 Limpieza

```bash
make clean
```

## ⚙️ Detalles de Implementación

### Formato Q8.8

- 16 bits totales
- 8 bits parte entera (0-255)
- 8 bits parte fraccionaria (precisión 1/256)

Ejemplo: 100.5 → (100 × 256 + 128) = 25728 en Q8.8

### Interpolación Bilineal

Fórmula:

```
result = p00*(1-fx)*(1-fy) + p01*fx*(1-fy) + p10*(1-fx)*fy + p11*fx*fy
```

Donde:
- `p00, p01, p10, p11`: 4 píxeles vecinos
- `fx, fy`: Pesos fraccionarios (0.0-1.0)

## 📊 Performance

Imagen 512×512 → 256×256 (65,536 píxeles de salida):
- Tiempo típico: ~10-20 ms (CPU moderna)
- Memoria: ~327 KB (entrada + salida)

## ✅ Validación

El modelo debe producir resultados **BIT A BIT idénticos** al hardware.

Tolerancia aceptable: ±1 píxel por redondeo (≥95% match)

## 🐛 Troubleshooting

### Error: "No se pudo abrir archivo"

Verificar que el archivo existe y la ruta es correcta.

### Error de compilación: "C++11 no soportado"

Actualizar compilador o agregar flag `-std=c++11`.

### Resultados diferentes vs Python

Ejecutar `validate_cpp_model.py` para diagnóstico detallado.

## 📝 Notas

- Este modelo es OBLIGATORIO según especificación del proyecto
- Debe dar resultados idénticos al hardware (validación bit-a-bit)
- Usar SOLO aritmética Q8.8 (no float en cálculos)
