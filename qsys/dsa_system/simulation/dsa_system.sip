set_global_assignment -entity "dsa_system" -library "lib_dsa_system" -name IP_TOOL_NAME "Qsys"
set_global_assignment -entity "dsa_system" -library "lib_dsa_system" -name IP_TOOL_VERSION "20.1"
set_global_assignment -entity "dsa_system" -library "lib_dsa_system" -name IP_TOOL_ENV "Qsys"
set_global_assignment -library "lib_dsa_system" -name SPD_FILE [file join $::quartus(sip_path) "../dsa_system.spd"]
set_global_assignment -library "lib_dsa_system" -name MISC_FILE [file join $::quartus(sip_path) "../../dsa_system.qsys"]

set_global_assignment -library "lib_dsa_system" -name MISC_FILE [file join $::quartus(sip_path) "dsa_system.v"]
