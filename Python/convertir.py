from PIL import Image
import numpy as np

def convertir_a_grayscale(path_imagen):
    # 1. Cargar imagen
    img = Image.open(path_imagen)

    # 2. Redimensionar manteniendo proporción (máx 512x512)
    max_dim = 512
    img.thumbnail((max_dim, max_dim))

    # 3. Convertir a blanco y negro (0–255)
    img_gray = img.convert("L")  # "L" = 8-bit grayscale

    # 4. Convertir a array NumPy
    arr = np.array(img_gray, dtype=np.uint8)

    return arr

# Convertir imagen
matriz = convertir_a_grayscale("Imagen.png")

# Mostrar matriz y forma
print(matriz)
print(matriz.shape)

# Guardar matriz en archivo .txt
np.savetxt("imagen_grayscale.txt", matriz, fmt="%d")
print("Archivo 'imagen_grayscale.txt' guardado correctamente.")
