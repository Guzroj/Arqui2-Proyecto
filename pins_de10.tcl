# ================================================================
# pins_de10.tcl
# Asignacion de pines para DE-10 Standard
# Ejecutar en Quartus: Tools -> Tcl Scripts -> Run
# ================================================================

# Clock 50MHz
set_location_assignment PIN_AF14 -to clk
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to clk

# Reset (KEY0 active low)
set_location_assignment PIN_AJ4 -to rst
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to rst

# LEDs
set_location_assignment PIN_AA24 -to LEDR[0]
set_location_assignment PIN_AB23 -to LEDR[1]
set_location_assignment PIN_AC23 -to LEDR[2]
set_location_assignment PIN_AD24 -to LEDR[3]
set_location_assignment PIN_AG25 -to LEDR[4]
set_location_assignment PIN_AF25 -to LEDR[5]
set_location_assignment PIN_AE24 -to LEDR[6]
set_location_assignment PIN_AF24 -to LEDR[7]

set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to LEDR[*]

puts "Pines asignados correctamente para DE-10 Standard"

