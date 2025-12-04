transcript on
if {[file exists rtl_work]} {
	vdel -lib rtl_work -all
}
vlib rtl_work
vmap work rtl_work

vlog -sv -work work +incdir+C:/Users/josev/OneDrive/Documentos/Arqui2ProyectoInicio/rtl {C:/Users/josev/OneDrive/Documentos/Arqui2ProyectoInicio/rtl/Proyecto2Arqui.sv}
vlog -sv -work work +incdir+C:/Users/josev/OneDrive/Documentos/Arqui2ProyectoInicio/rtl/memory {C:/Users/josev/OneDrive/Documentos/Arqui2ProyectoInicio/rtl/memory/image_memory_input.sv}
vlog -sv -work work +incdir+C:/Users/josev/OneDrive/Documentos/Arqui2ProyectoInicio/rtl/memory {C:/Users/josev/OneDrive/Documentos/Arqui2ProyectoInicio/rtl/memory/image_memory_output.sv}

