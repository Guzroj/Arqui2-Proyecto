# ============================================================================
# run_modelsim.do
# Script TCL para simular los módulos de memoria en ModelSim
# FASE 4: Módulos de Memoria
# ============================================================================

# Crear librería de trabajo
vlib work

# Compilar los módulos RTL
vlog -sv ../rtl/memory/image_memory_input.sv
vlog -sv ../rtl/memory/image_memory_output.sv

# Compilar el testbench
vlog -sv +define+SIMULATION tb_image_memory.sv

# Iniciar simulación
vsim -voptargs=+acc work.tb_image_memory

# Configurar ventanas de visualización
view wave
view structure
view signals

# Agregar señales al viewer
add wave -divider "Clock and Reset"
add wave -format Logic /tb_image_memory/clk
add wave -format Logic /tb_image_memory/rst_n

add wave -divider "Input Memory - Write Port"
add wave -format Logic /tb_image_memory/input_wr_en_a
add wave -format Literal -radix hexadecimal /tb_image_memory/input_wr_addr_a
add wave -format Literal -radix hexadecimal /tb_image_memory/input_wr_data_a

add wave -divider "Input Memory - Read Port"
add wave -format Logic /tb_image_memory/input_rd_en_b
add wave -format Literal -radix hexadecimal /tb_image_memory/input_rd_addr_b
add wave -format Literal -radix hexadecimal /tb_image_memory/input_rd_data_b

add wave -divider "Output Memory - Write Port"
add wave -format Logic /tb_image_memory/output_wr_en_a
add wave -format Literal -radix hexadecimal /tb_image_memory/output_wr_addr_a
add wave -format Literal -radix hexadecimal /tb_image_memory/output_wr_data_a

add wave -divider "Output Memory - Read Port"
add wave -format Logic /tb_image_memory/output_rd_en_b
add wave -format Literal -radix hexadecimal /tb_image_memory/output_rd_addr_b
add wave -format Literal -radix hexadecimal /tb_image_memory/output_rd_data_b
add wave -format Literal -radix unsigned /tb_image_memory/output_pixels_written

add wave -divider "Test Control"
add wave -format Literal -radix unsigned /tb_image_memory/errors

# Configurar formato de tiempo
configure wave -timelineunits ns

# Ejecutar simulación
run -all

# Zoom para ver todo
wave zoom full
