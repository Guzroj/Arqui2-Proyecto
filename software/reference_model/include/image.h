/**
 * image.h
 * Clase para manejo de imágenes en escala de grises
 */

#ifndef IMAGE_H
#define IMAGE_H

#include <cstdint>
#include <vector>
#include <string>

/**
 * Clase Image para representar imágenes en escala de grises
 */
class Image {
public:
    int width;
    int height;
    std::vector<std::vector<uint8_t>> data;

    // Constructor
    Image(int w, int h);

    // Cargar desde archivo de texto
    bool load_from_txt(const std::string& filename);

    // Guardar a archivo de texto
    bool save_to_txt(const std::string& filename) const;

    // Acceso a píxeles
    uint8_t get_pixel(int x, int y) const;
    void set_pixel(int x, int y, uint8_t value);

    // Estadísticas
    void print_stats() const;
};

/**
 * Aplica downscaling con interpolación bilineal
 *
 * @param src Imagen origen
 * @param dst_w Ancho destino
 * @param dst_h Alto destino
 * @return Imagen reducida
 */
Image downscale_image(const Image& src, int dst_w, int dst_h);

#endif // IMAGE_H
