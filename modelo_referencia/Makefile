# ============================================================================
# Makefile - Modelo de Referencia DSA Downscaler
# ============================================================================

CXX = g++
CXXFLAGS = -std=c++17 -Wall -Wextra -O3 -march=native
TARGET = dsa_downscale
SOURCES = main.cpp bilinear_downscale.cpp
HEADERS = bilinear_downscale.h

# ============================================================================
# Reglas
# ============================================================================

all: $(TARGET)

$(TARGET): $(SOURCES) $(HEADERS)
	$(CXX) $(CXXFLAGS) $(SOURCES) -o $(TARGET)
	@echo ""
	@echo "============================================="
	@echo "  Compilación exitosa: $(TARGET)"
	@echo "============================================="
	@echo "Ejecuta: ./$(TARGET) <modo> <input> <w_in> <h_in> <w_out> <h_out> <output>"
	@echo "Ejemplo: ./$(TARGET) seq input.txt 512 512 256 256 output.txt"
	@echo "============================================="

clean:
	rm -f $(TARGET) *.o
	@echo "Archivos de compilación eliminados"

test: $(TARGET)
	@echo "Ejecutando test rápido (4×4 → 2×2)..."
	@echo "0 1 2 3" > test_4x4.txt
	@echo "4 5 6 7" >> test_4x4.txt
	@echo "8 9 10 11" >> test_4x4.txt
	@echo "12 13 14 15" >> test_4x4.txt
	./$(TARGET) both test_4x4.txt 4 4 2 2 test_output.txt
	@echo ""
	@echo "Resultado guardado en: test_output.txt"
	@cat test_output.txt

.PHONY: all clean test

