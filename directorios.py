import os

def main():
    output_file = "todos_los_codigos.txt"

    # Obtiene todos los archivos .sv en el directorio actual
    sv_files = [f for f in os.listdir('.') if f.endswith('.sv')]

    if not sv_files:
        print("No se encontraron archivos .sv en este directorio.")
        return

    with open(output_file, "w", encoding="utf-8") as out:
        for sv in sv_files:
            out.write(f"{sv}\n\n")
            out.write("////\nCódigo\n////\n\n")

            # Leer código del archivo .sv
            with open(sv, "r", encoding="utf-8", errors="ignore") as f:
                out.write(f.read())

            out.write("\n\n----------------------------------------\n\n")

    print(f"Archivo generado: {output_file}")

if __name__ == "__main__":
    main()
