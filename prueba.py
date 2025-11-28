import numpy as np

# Cargar entrada (512x512)
entrada = np.loadtxt('imagen_grayscale.txt', dtype=np.uint8).reshape(512, 512)

# Cargar salida (256x256)
with open('imagen_output.txt', 'r') as f:
    lines = f.readlines()
salida = np.array([[int(x) for x in line.split()] for line in lines[1:]], dtype=np.uint8)

print(f"Entrada shape: {entrada.shape}")
print(f"Salida shape: {salida.shape}")

# Verificar píxeles específicos
print("\n=== VERIFICACIÓN MANUAL ===")

# Píxel de salida [0,0] debería venir de entrada [0,0]
print(f"Salida[0,0] = {salida[0,0]}")
print(f"Entrada[0,0] = {entrada[0,0]}")

# Píxel de salida [255,255] debería venir de entrada [511,511]
print(f"Salida[255,255] = {salida[255,255]}")
print(f"Entrada[511,511] = {entrada[511,511]}")

# Píxel de salida [128,128] debería venir de entrada ~[256,256]
print(f"Salida[128,128] = {salida[128,128]}")
print(f"Entrada[256,256] = {entrada[256,256]}")

# Verificar si hay patrón repetido
cuadrante1 = salida[0:128, 0:128]
cuadrante2 = salida[0:128, 128:256]
cuadrante3 = salida[128:256, 0:128]
cuadrante4 = salida[128:256, 128:256]

if np.array_equal(cuadrante1, cuadrante2):
    print("\n⚠ PROBLEMA: Cuadrantes 1 y 2 son idénticos!")
if np.array_equal(cuadrante1, cuadrante3):
    print("⚠ PROBLEMA: Cuadrantes 1 y 3 son idénticos!")
if np.array_equal(cuadrante1, cuadrante4):
    print("⚠ PROBLEMA: Cuadrantes 1 y 4 son idénticos!")