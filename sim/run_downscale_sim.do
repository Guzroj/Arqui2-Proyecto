# ============================================================================
# run_downscale_sim.do
# Script TCL para ModelSim - Simulación de downscaling con pipeline
# FASE 5: Downscaling secuencial
# ============================================================================

# Crear biblioteca de trabajo
if {[file exists work]} {
    vdel -lib work -all
}
vlib work
vmap work work

# ============================================================================
# Compilar archivos RTL
# ============================================================================

puts "========================================="
puts "Compilando módulos RTL..."
puts "========================================="

# Memorias (FASE 4)
vlog -sv ../rtl/memory/image_memory_input.sv
vlog -sv ../rtl/memory/image_memory_output.sv

# Módulos de downscaling (FASE 5)
vlog -sv ../rtl/downscale/fixed_point_mult.sv
vlog -sv ../rtl/downscale/bilinear_interpolator.sv
vlog -sv ../rtl/downscale/downscale_fsm.sv
vlog -sv ../rtl/downscale/downscale_sequential.sv

# Testbench
vlog -sv +define+SIMULATION tb_downscale_sequential.sv

# ============================================================================
# Cargar diseño
# ============================================================================

puts "========================================="
puts "Cargando simulación..."
puts "========================================="

vsim -voptargs="+acc" work.tb_downscale_sequential

# ============================================================================
# Configurar waveforms
# ============================================================================

# Señales principales
add wave -group "Top" sim:/tb_downscale_sequential/clk
add wave -group "Top" sim:/tb_downscale_sequential/rst_n
add wave -group "Top" sim:/tb_downscale_sequential/start
add wave -group "Top" sim:/tb_downscale_sequential/busy
add wave -group "Top" sim:/tb_downscale_sequential/done

# FSM
add wave -group "FSM" sim:/tb_downscale_sequential/u_dut/u_fsm/state
add wave -group "FSM" sim:/tb_downscale_sequential/u_dut/u_fsm/out_x
add wave -group "FSM" sim:/tb_downscale_sequential/u_dut/u_fsm/out_y
add wave -group "FSM" sim:/tb_downscale_sequential/u_dut/u_fsm/pixel_count

# Memoria de entrada
add wave -group "Mem Input" sim:/tb_downscale_sequential/mem_in_rd_en
add wave -group "Mem Input" -radix unsigned sim:/tb_downscale_sequential/mem_in_rd_addr
add wave -group "Mem Input" -radix unsigned sim:/tb_downscale_sequential/mem_in_rd_data

# Interpolador
add wave -group "Interpolator" sim:/tb_downscale_sequential/u_dut/u_interpolator/start
add wave -group "Interpolator" sim:/tb_downscale_sequential/u_dut/u_interpolator/valid
add wave -group "Interpolator" -radix unsigned sim:/tb_downscale_sequential/u_dut/u_interpolator/p00
add wave -group "Interpolator" -radix unsigned sim:/tb_downscale_sequential/u_dut/u_interpolator/p01
add wave -group "Interpolator" -radix unsigned sim:/tb_downscale_sequential/u_dut/u_interpolator/p10
add wave -group "Interpolator" -radix unsigned sim:/tb_downscale_sequential/u_dut/u_interpolator/p11
add wave -group "Interpolator" -radix unsigned sim:/tb_downscale_sequential/u_dut/u_interpolator/result

# Memoria de salida
add wave -group "Mem Output" sim:/tb_downscale_sequential/mem_out_wr_en
add wave -group "Mem Output" -radix unsigned sim:/tb_downscale_sequential/mem_out_wr_addr
add wave -group "Mem Output" -radix unsigned sim:/tb_downscale_sequential/mem_out_wr_data

# ============================================================================
# Ejecutar simulación
# ============================================================================

puts "========================================="
puts "Ejecutando simulación..."
puts "========================================="

# Configurar formato de tiempo
configure wave -timelineunits ns

# Ejecutar simulación hasta el final
run -all

puts "========================================="
puts "Simulación completada"
puts "========================================="

# Zoom to fit
wave zoom full
