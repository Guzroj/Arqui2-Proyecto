// ============================================================================
// dsa_system_wrapper.sv - Top-Level para DE1-SoC
// ============================================================================
// Descripción:
//   Wrapper que conecta el sistema Qsys (dsa_system) con los pines físicos
//   de la FPGA Intel Cyclone V (DE1-SoC).
//
// Versión: BRAM (On-Chip Memory)
//   - Clock: 50 MHz desde pin físico
//   - Reset: Power-on reset interno
//   - LEDs: 10 LEDs (LEDR[9:0])
//   - JTAG: Interfaz automática (no necesita pines)
//
// Fecha: Noviembre 2025
// ============================================================================

`timescale 1ns/1ps

module dsa_system_wrapper (
    // ========== Clock y Reset ==========
    input  logic        CLOCK_50,    // Clock 50 MHz (pin físico DE1-SoC)

    // ========== LEDs ==========
    output logic [9:0]  LEDR         // 10 LEDs rojos (LEDR[9:0])
);

    // ========================================================================
    // Power-On Reset Generator
    // ========================================================================
    // Genera un reset de ~10 ciclos al encender la FPGA

    logic [3:0] reset_counter;
    logic       system_reset_n;  // Reset negado (activo bajo)

    always_ff @(posedge CLOCK_50) begin
        if (reset_counter != 4'hF) begin
            reset_counter  <= reset_counter + 4'd1;
            system_reset_n <= 1'b0;  // Reset activo
        end else begin
            system_reset_n <= 1'b1;  // Reset liberado
        end
    end

    // ========================================================================
    // Instancia del Sistema Qsys
    // ========================================================================
    // Este módulo es generado automáticamente por Platform Designer
    // Archivo: qsys/dsa_system/synthesis/dsa_system.v

    dsa_system u_dsa_system (
        // Clock y Reset
        .clk_clk       (CLOCK_50),         // Clock 50 MHz
        .reset_reset_n (system_reset_n),   // Reset (activo bajo)

        // LEDs (exportados desde PIO)
        .leds_export   (LEDR)              // 10 bits → LEDR[9:0]

        // NOTA: JTAG no necesita conexiones externas, es automático
        // NOTA: Memorias BRAM son internas, no tienen pines
    );

endmodule
