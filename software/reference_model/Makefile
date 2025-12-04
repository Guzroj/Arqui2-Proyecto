# Makefile para el modelo de referencia C++
# Compilador y flags
CXX = g++
CXXFLAGS = -std=c++11 -Wall -Wextra -O2 -I./include
LDFLAGS =

# Directorios
SRC_DIR = src
INC_DIR = include
OBJ_DIR = obj
BIN_DIR = bin

# Archivos fuente y objetos
SOURCES = $(wildcard $(SRC_DIR)/*.cpp)
OBJECTS = $(SOURCES:$(SRC_DIR)/%.cpp=$(OBJ_DIR)/%.o)

# Ejecutable
TARGET = $(BIN_DIR)/downscale

# Regla por defecto
all: directories $(TARGET)

# Crear directorios necesarios
directories:
	@mkdir -p $(OBJ_DIR)
	@mkdir -p $(BIN_DIR)

# Compilar ejecutable
$(TARGET): $(OBJECTS)
	@echo "Linking $(TARGET)..."
	@$(CXX) $(LDFLAGS) $^ -o $@
	@echo "✓ Build completo: $(TARGET)"

# Compilar archivos .cpp a .o
$(OBJ_DIR)/%.o: $(SRC_DIR)/%.cpp
	@echo "Compilando $<..."
	@$(CXX) $(CXXFLAGS) -c $< -o $@

# Limpiar archivos generados
clean:
	@echo "Limpiando archivos generados..."
	@rm -rf $(OBJ_DIR) $(BIN_DIR)
	@echo "✓ Limpieza completa"

# Ejecutar test por defecto
run: $(TARGET)
	@echo ""
	@echo "Ejecutando test por defecto (64x64 → 32x32)..."
	@echo ""
	@cd ../python && python reference/downscale.py
	@$(TARGET) ../python/test_images/gradient_h_64x64.txt \
	           output_cpp_32x32.txt 64 64 32 32

# Mostrar ayuda
help:
	@echo "Makefile para modelo de referencia C++"
	@echo ""
	@echo "Targets disponibles:"
	@echo "  make         - Compilar el proyecto"
	@echo "  make clean   - Limpiar archivos generados"
	@echo "  make run     - Compilar y ejecutar test"
	@echo "  make help    - Mostrar esta ayuda"
	@echo ""
	@echo "Uso manual:"
	@echo "  $(TARGET) input.txt output.txt src_w src_h dst_w dst_h"
	@echo ""
	@echo "Ejemplo:"
	@echo "  $(TARGET) imagen_64x64.txt salida_32x32.txt 64 64 32 32"

# Dependencias de headers
$(OBJ_DIR)/main.o: $(INC_DIR)/image.h
$(OBJ_DIR)/image.o: $(INC_DIR)/image.h $(INC_DIR)/bilinear.h $(INC_DIR)/fixed_point.h
$(OBJ_DIR)/bilinear.o: $(INC_DIR)/bilinear.h $(INC_DIR)/fixed_point.h

.PHONY: all clean run help directories
