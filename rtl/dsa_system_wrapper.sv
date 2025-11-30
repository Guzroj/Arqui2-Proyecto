`timescale 1ns/1ps

//==============================================================================
// DSA System Wrapper for DE1-SoC
// Wraps the Qsys-generated system with FPGA pin connections
//==============================================================================

module dsa_system_wrapper (
    // ====== DE1-SoC Clock Input (50 MHz) ======
    input  logic       clk,
    
    // ====== DE1-SoC LED Output (10 LEDs) ======
    output logic [9:0] LEDR
);

    // ====== Internal Signals ======
    logic reset;
    
    // ====== Power-On Reset Generator ======
    // Generate a clean reset pulse at startup (active HIGH)
    logic [3:0] reset_counter = 4'b0;
    
    always_ff @(posedge clk) begin
        if (reset_counter != 4'hF) begin
            reset_counter <= reset_counter + 1'b1;
            reset <= 1'b1;  // Assert reset (active HIGH)
        end else begin
            reset <= 1'b0;  // De-assert reset
        end
    end

    // ====== Qsys System Instance ======
    dsa_system u_qsys (
        .clk_clk                             (clk),  // clk.clk
        .reset_reset                         (reset),          // reset.reset (active HIGH)
        .pio_leds_external_connection_export (LEDR)            // pio_leds_external_connection.export
    );

endmodule