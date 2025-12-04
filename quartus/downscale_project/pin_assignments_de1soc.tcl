# ============================================================================
# pin_assignments_de1soc.tcl
# Pin assignments para Proyecto2Arqui en DE1-SoC
# Arquitectura de Computadores 2 - FASE 4
# ============================================================================

# Clock (50 MHz)
set_location_assignment PIN_AF14 -to CLOCK_50
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to CLOCK_50

# Reset (KEY[0] - activo bajo)
set_location_assignment PIN_AA14 -to KEY0
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to KEY0

# LEDs rojos LEDR[9:0] (10 LEDs para debug)
set_location_assignment PIN_V16 -to LEDR[0]
set_location_assignment PIN_W16 -to LEDR[1]
set_location_assignment PIN_V17 -to LEDR[2]
set_location_assignment PIN_V18 -to LEDR[3]
set_location_assignment PIN_W17 -to LEDR[4]
set_location_assignment PIN_W19 -to LEDR[5]
set_location_assignment PIN_Y19 -to LEDR[6]
set_location_assignment PIN_W20 -to LEDR[7]
set_location_assignment PIN_W21 -to LEDR[8]
set_location_assignment PIN_Y21 -to LEDR[9]

# IO Standard para LEDs
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to LEDR[0]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to LEDR[1]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to LEDR[2]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to LEDR[3]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to LEDR[4]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to LEDR[5]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to LEDR[6]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to LEDR[7]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to LEDR[8]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to LEDR[9]

# Current strength para LEDs (8mA)
set_instance_assignment -name CURRENT_STRENGTH_NEW 8MA -to LEDR[0]
set_instance_assignment -name CURRENT_STRENGTH_NEW 8MA -to LEDR[1]
set_instance_assignment -name CURRENT_STRENGTH_NEW 8MA -to LEDR[2]
set_instance_assignment -name CURRENT_STRENGTH_NEW 8MA -to LEDR[3]
set_instance_assignment -name CURRENT_STRENGTH_NEW 8MA -to LEDR[4]
set_instance_assignment -name CURRENT_STRENGTH_NEW 8MA -to LEDR[5]
set_instance_assignment -name CURRENT_STRENGTH_NEW 8MA -to LEDR[6]
set_instance_assignment -name CURRENT_STRENGTH_NEW 8MA -to LEDR[7]
set_instance_assignment -name CURRENT_STRENGTH_NEW 8MA -to LEDR[8]
set_instance_assignment -name CURRENT_STRENGTH_NEW 8MA -to LEDR[9]
