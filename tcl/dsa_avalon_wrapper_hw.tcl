# ============================================================================
# dsa_avalon_wrapper_hw.tcl
# ============================================================================
# TCL script para definir DSA_Avalon_Wrapper como componente IP en Qsys
#
# Uso:
#   1. Copiar este archivo a la carpeta del proyecto
#   2. En Platform Designer: Tools → Options → IP Search Path → Agregar ruta
#   3. Refresh IP Catalog (F5)
#   4. Buscar "DSA Downscaler" y agregar
#
# Autor: DSA Project Team
# Fecha: Noviembre 2025
# ============================================================================

package require -exact qsys 16.0

# ============================================================================
# Módulo
# ============================================================================
set_module_property DESCRIPTION "DSA Downscaler with Bilinear Interpolation - Avalon-MM Interface"
set_module_property NAME dsa_avalon_wrapper
set_module_property VERSION 1.0
set_module_property INTERNAL false
set_module_property OPAQUE_ADDRESS_MAP true
set_module_property GROUP "DSA Components"
set_module_property AUTHOR "DSA Project Team"
set_module_property DISPLAY_NAME "DSA Downscaler (Avalon-MM)"
set_module_property INSTANTIATE_IN_SYSTEM_MODULE true
set_module_property EDITABLE true
set_module_property REPORT_TO_TALKBACK false
set_module_property ALLOW_GREYBOX_GENERATION false
set_module_property REPORT_HIERARCHY false

# ============================================================================
# Archivos HDL
# ============================================================================
add_fileset QUARTUS_SYNTH QUARTUS_SYNTH "" ""
set_fileset_property QUARTUS_SYNTH TOP_LEVEL DSA_Avalon_Wrapper
set_fileset_property QUARTUS_SYNTH ENABLE_RELATIVE_INCLUDE_PATHS false
set_fileset_property QUARTUS_SYNTH ENABLE_FILE_OVERWRITE_MODE false

add_fileset_file DSA_Avalon_Wrapper.sv     SYSTEM_VERILOG PATH ../rtl/DSA_Avalon_Wrapper.sv TOP_LEVEL_FILE
add_fileset_file DSA_Control_Registers.sv  SYSTEM_VERILOG PATH ../rtl/DSA_Control_Registers.sv
add_fileset_file DSA_Memory_Adapter.sv     SYSTEM_VERILOG PATH ../rtl/DSA_Memory_Adapter.sv
add_fileset_file Downscale_Secuencial.sv   SYSTEM_VERILOG PATH ../rtl/Downscale_Secuencial.sv
add_fileset_file Downscale_SIMD.sv         SYSTEM_VERILOG PATH ../rtl/Downscale_SIMD.sv
add_fileset_file ModoSecuencial.sv         SYSTEM_VERILOG PATH ../rtl/ModoSecuencial.sv
add_fileset_file ModoSIMD.sv               SYSTEM_VERILOG PATH ../rtl/ModoSIMD.sv
add_fileset_file Top_SIMD.sv               SYSTEM_VERILOG PATH ../rtl/Top_SIMD.sv
add_fileset_file FSM_SIMD.sv               SYSTEM_VERILOG PATH ../rtl/FSM_SIMD.sv
add_fileset_file SIMD_Registros.sv         SYSTEM_VERILOG PATH ../rtl/SIMD_Registros.sv

# ============================================================================
# Parámetros
# ============================================================================
add_parameter N INTEGER 4
set_parameter_property N DEFAULT_VALUE 4
set_parameter_property N DISPLAY_NAME "SIMD Lanes"
set_parameter_property N TYPE INTEGER
set_parameter_property N UNITS None
set_parameter_property N ALLOWED_RANGES {1 2 4 8}
set_parameter_property N DESCRIPTION "Number of parallel SIMD lanes (1, 2, 4, or 8)"
set_parameter_property N HDL_PARAMETER true

# ============================================================================
# Interfaz Clock
# ============================================================================
add_interface clock clock end
set_interface_property clock clockRate 0
set_interface_property clock ENABLED true
set_interface_property clock EXPORT_OF ""
set_interface_property clock PORT_NAME_MAP ""
set_interface_property clock CMSIS_SVD_VARIABLES ""
set_interface_property clock SVD_ADDRESS_GROUP ""

add_interface_port clock clk clk Input 1

# ============================================================================
# Interfaz Reset
# ============================================================================
add_interface reset reset end
set_interface_property reset associatedClock clock
set_interface_property reset synchronousEdges DEASSERT
set_interface_property reset ENABLED true
set_interface_property reset EXPORT_OF ""
set_interface_property reset PORT_NAME_MAP ""
set_interface_property reset CMSIS_SVD_VARIABLES ""
set_interface_property reset SVD_ADDRESS_GROUP ""

add_interface_port reset rst reset Input 1

# ============================================================================
# Interfaz Avalon-MM Slave (Control Registers)
# ============================================================================
add_interface avalon_slave avalon end
set_interface_property avalon_slave addressUnits WORDS
set_interface_property avalon_slave associatedClock clock
set_interface_property avalon_slave associatedReset reset
set_interface_property avalon_slave bitsPerSymbol 8
set_interface_property avalon_slave burstOnBurstBoundariesOnly false
set_interface_property avalon_slave burstcountUnits WORDS
set_interface_property avalon_slave explicitAddressSpan 0
set_interface_property avalon_slave holdTime 0
set_interface_property avalon_slave linewrapBursts false
set_interface_property avalon_slave maximumPendingReadTransactions 0
set_interface_property avalon_slave maximumPendingWriteTransactions 0
set_interface_property avalon_slave readLatency 0
set_interface_property avalon_slave readWaitTime 1
set_interface_property avalon_slave setupTime 0
set_interface_property avalon_slave timingUnits Cycles
set_interface_property avalon_slave writeWaitTime 0
set_interface_property avalon_slave ENABLED true
set_interface_property avalon_slave EXPORT_OF ""
set_interface_property avalon_slave PORT_NAME_MAP ""
set_interface_property avalon_slave CMSIS_SVD_VARIABLES ""
set_interface_property avalon_slave SVD_ADDRESS_GROUP ""

add_interface_port avalon_slave avs_ctrl_address    address    Input 4
add_interface_port avalon_slave avs_ctrl_read       read       Input 1
add_interface_port avalon_slave avs_ctrl_write      write      Input 1
add_interface_port avalon_slave avs_ctrl_writedata  writedata  Input 32
add_interface_port avalon_slave avs_ctrl_readdata   readdata   Output 32
add_interface_port avalon_slave avs_ctrl_waitrequest waitrequest Output 1

set_interface_assignment avalon_slave embeddedsw.configuration.isFlash 0
set_interface_assignment avalon_slave embeddedsw.configuration.isMemoryDevice 0
set_interface_assignment avalon_slave embeddedsw.configuration.isNonVolatileStorage 0
set_interface_assignment avalon_slave embeddedsw.configuration.isPrintableDevice 0

# ============================================================================
# Interfaz Avalon-MM Master (Memory Access)
# ============================================================================
add_interface avalon_master avalon start
set_interface_property avalon_master addressUnits SYMBOLS
set_interface_property avalon_master associatedClock clock
set_interface_property avalon_master associatedReset reset
set_interface_property avalon_master bitsPerSymbol 8
set_interface_property avalon_master burstOnBurstBoundariesOnly false
set_interface_property avalon_master burstcountUnits WORDS
set_interface_property avalon_master doStreamReads false
set_interface_property avalon_master doStreamWrites false
set_interface_property avalon_master holdTime 0
set_interface_property avalon_master linewrapBursts false
set_interface_property avalon_master maximumPendingReadTransactions 0
set_interface_property avalon_master maximumPendingWriteTransactions 0
set_interface_property avalon_master readLatency 0
set_interface_property avalon_master readWaitTime 1
set_interface_property avalon_master setupTime 0
set_interface_property avalon_master timingUnits Cycles
set_interface_property avalon_master writeWaitTime 0
set_interface_property avalon_master ENABLED true
set_interface_property avalon_master EXPORT_OF ""
set_interface_property avalon_master PORT_NAME_MAP ""
set_interface_property avalon_master CMSIS_SVD_VARIABLES ""
set_interface_property avalon_master SVD_ADDRESS_GROUP ""

add_interface_port avalon_master avm_mem_address       address       Output 32
add_interface_port avalon_master avm_mem_read          read          Output 1
add_interface_port avalon_master avm_mem_write         write         Output 1
add_interface_port avalon_master avm_mem_writedata     writedata     Output 32
add_interface_port avalon_master avm_mem_byteenable    byteenable    Output 4
add_interface_port avalon_master avm_mem_waitrequest   waitrequest   Input 1
add_interface_port avalon_master avm_mem_readdata      readdata      Input 32
add_interface_port avalon_master avm_mem_readdatavalid readdatavalid Input 1
