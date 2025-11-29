================================================================
  ARCHIVOS DE INTERFAZ JTAG
  Proyecto Downscale - Arquitectura de Computadores 2
  Basado en: https://github.com/Abner2111/GuiaJtag
================================================================

ARCHIVOS INCLUIDOS:
-------------------

1. Top_VJTAG.sv
   - Modulo top-level que integra Virtual JTAG con el sistema
   - Instancia sld_virtual_jtag (primitivo Intel)
   - Conecta: VJTAG -> connect -> JTAG_Interface -> Top_General

2. connect.sv
   - Controlador del protocolo Virtual JTAG
   - Traduce comandos JTAG a interfaz Avalon-like
   - Instrucciones: BYPASS, SET_ADDR, WRITE_REG, READ_REG

3. JTAG_Interface.sv
   - Banco de registros Avalon-MM
   - Mapa de registros:
     * 0x00: CONTROL (bit0=start, bit2=mode)
     * 0x01: XRATIO
     * 0x02: YRATIO
     * 0x03: WRITEADDR
     * 0x04: WRITEDATA
     * 0x05: READDATA (read-only)
     * 0x06: DONEFLAG (read-only)
     * 0x07: PERFCOUNT (read-only)

4. form.tcl
   - Script TCL con GUI para comunicacion JTAG
   - Ejecutar con: quartus_stp -t form.tcl

5. run_jtag.bat
   - Script batch para ejecutar form.tcl facilmente
   - Busca automaticamente quartus_stp.exe


CONFIGURACION EN QUARTUS:
-------------------------

1. Agregar archivos al proyecto:
   - Top_VJTAG.sv
   - connect.sv
   - JTAG_Interface.sv

2. Configurar Top-Level Entity:
   - Assignments -> Settings -> General
   - Top-level entity: Top_VJTAG

3. Asignaciones de pines (DE1-SoC):
   - clk: PIN_AF14 (CLOCK_50)
   - rst: PIN_AA14 (KEY0)
   - LEDR[0-7]: PIN_V16, PIN_W16, PIN_V17, PIN_V18, PIN_W17, PIN_W19, PIN_Y19, PIN_W20


USO:
----

1. Compilar proyecto en Quartus
2. Programar FPGA con archivo .sof
3. Ejecutar run_jtag.bat (doble click)
4. En la GUI:
   - Click "Conectar"
   - Click "Cargar Imagen Gradiente"
   - Click "Iniciar SIMD" o "Iniciar Secuencial"
   - Click "Leer Done" para verificar
   - Click "Leer Ciclos" para ver performance


JERARQUIA DEL DISENO:
---------------------

Top_VJTAG
|-- sld_virtual_jtag (primitivo Intel)
|-- connect (protocolo JTAG -> Avalon)
+-- Top_General
    |-- JTAG_Interface (registros)
    |-- Top_Downscale_Secuencial
    +-- Top_Downscale_Integration (SIMD)

================================================================

