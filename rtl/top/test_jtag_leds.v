// ============================================================================
// test_jtag_leds.v
// Top-level module para test de JTAG controlando 8 LEDs
// FASE 3: Test de comunicacion JTAG con LEDs en DE1-SoC
// ============================================================================
//
// Estructura del sistema:
//   test_jtag_leds (top-level)
//   |-- vJTAG (IP Core generado por Quartus)
//   |-- vJTAG_interface (modulo custom)
//
// Flujo de comunicacion:
//   PC (Python) --> TCL Server --> Virtual JTAG --> vJTAG_interface --> LEDs
//
// Hardware: DE1-SoC MTL2
// ============================================================================

module test_jtag_leds (
    // Clock y Reset
    input         CLOCK_50,     // Clock de 50 MHz
    input         KEY0,         // KEY[0] - Reset (activo bajo)

    // LEDs
    output [7:0]  LEDR          // LEDR[7:0] - LEDs rojos
);

    // ========================================================================
    // Senales internas del Virtual JTAG
    // ========================================================================
    wire tck;                   // JTAG clock
    wire tdi;                   // Test Data In
    wire tdo;                   // Test Data Out
    wire [0:0] ir_in;           // Instruction Register input (1-bit)
    wire [0:0] ir_out;          // Instruction Register output (1-bit)
    wire virtual_state_cdr;     // Capture DR state
    wire virtual_state_sdr;     // Shift DR state
    wire virtual_state_e1dr;    // Exit1 DR state
    wire virtual_state_pdr;     // Pause DR state
    wire virtual_state_e2dr;    // Exit2 DR state
    wire virtual_state_udr;     // Update DR state
    wire virtual_state_cir;     // Capture IR state
    wire virtual_state_uir;     // Update IR state

    // ========================================================================
    // Instancia del Virtual JTAG IP Core
    // ========================================================================
    // NOTA: Este modulo se genera desde Quartus IP Catalog
    // Path: Tools -> IP Catalog -> Library -> Interface Protocols -> JTAG
    //       -> Virtual JTAG (sld_virtual_jtag)
    //
    // Configuracion:
    //   - sld_auto_instance_index: "YES"
    //   - sld_instance_index: 0
    //   - sld_ir_width: 1
    //
    // El archivo vJTAG.v debe ser generado y agregado al proyecto
    vJTAG u_vJTAG (
        .ir_in(ir_in),
        .ir_out(ir_out),
        .tck(tck),
        .tdi(tdi),
        .tdo(tdo),
        .virtual_state_cdr(virtual_state_cdr),
        .virtual_state_cir(virtual_state_cir),
        .virtual_state_e1dr(virtual_state_e1dr),
        .virtual_state_e2dr(virtual_state_e2dr),
        .virtual_state_pdr(virtual_state_pdr),
        .virtual_state_sdr(virtual_state_sdr),
        .virtual_state_udr(virtual_state_udr),
        .virtual_state_uir(virtual_state_uir)
    );

    // ========================================================================
    // Instancia del JTAG Interface Module
    // ========================================================================
    vJTAG_interface u_vJTAG_interface (
        .tck(tck),
        .tdi(tdi),
        .tdo(tdo),
        .aclr(1'b0),            // No se usa reset asincrono
        .ir_in(ir_in[0]),
        .v_sdr(virtual_state_sdr),
        .udr(virtual_state_udr),
        .LEDs(LEDR)
    );

endmodule
