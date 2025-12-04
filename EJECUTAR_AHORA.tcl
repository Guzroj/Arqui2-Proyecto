# ============================================================================
# COMANDOS PARA EJECUTAR EN JTAG SYSTEM CONSOLE
# Copia y pega esto completo
# ============================================================================

# Cargar script principal (esto carga todos los demás automáticamente)
source tcl/test_downscale_complete.tcl

# OPCIÓN 1: Test rápido (recomendado primero - solo 4×4 → 2×2)
test_downscale_quick

# OPCIÓN 2: Test completo con imagen real (descomentar si el rápido funciona)
# test_downscale_complete "../imagen_grayscale.txt" 512 512 256 256

