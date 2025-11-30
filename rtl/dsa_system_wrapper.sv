`timescale 1ns/1ps

//==============================================================================
// DSA System Wrapper for DE1-SoC
// Wraps the Qsys-generated system with FPGA pin connections
//==============================================================================

module dsa_system_wrapper (
    // ====== DE1-SoC Clock Input (50 MHz) ======
    input  logic        clk,
    
    // ====== DE1-SoC LED Output (10 LEDs) ======
    output logic [9:0]  LEDR,
    
    // ====== SDRAM Interface (IS42S16320D) ======
    output logic [12:0] DRAM_ADDR,     // Address
    output logic [1:0]  DRAM_BA,       // Bank Address
    output logic        DRAM_CAS_N,    // Column Address Strobe
    output logic        DRAM_CKE,      // Clock Enable
    output logic        DRAM_CLK,      // Clock
    output logic        DRAM_CS_N,     // Chip Select
    inout  wire  [15:0] DRAM_DQ,       // Data (bidirectional)
    output logic        DRAM_LDQM,     // Low Data Mask
    output logic        DRAM_RAS_N,    // Row Address Strobe
    output logic        DRAM_UDQM,     // High Data Mask
    output logic        DRAM_WE_N      // Write Enable
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

    // ====== SDRAM Clock (same as system clock) ======
    assign DRAM_CLK = clk;
    
    // ====== Qsys System Instance ======
    dsa_system u_qsys (
        // Clock and Reset
        .clk_clk                             (clk),            // clk.clk
        .reset_reset                         (reset),          // reset.reset (active HIGH)
        
        // LEDs
        .pio_leds_external_connection_export (LEDR),           // pio_leds_external_connection.export
        
        // SDRAM Interface (exported from new_sdram_controller_0)
        .sdram_addr                          (DRAM_ADDR),      // sdram.addr
        .sdram_ba                            (DRAM_BA),        // sdram.ba
        .sdram_cas_n                         (DRAM_CAS_N),     // sdram.cas_n
        .sdram_cke                           (DRAM_CKE),       // sdram.cke
        .sdram_cs_n                          (DRAM_CS_N),      // sdram.cs_n
        .sdram_dq                            (DRAM_DQ),        // sdram.dq
        .sdram_dqm                           ({DRAM_UDQM, DRAM_LDQM}), // sdram.dqm[1:0]
        .sdram_ras_n                         (DRAM_RAS_N),     // sdram.ras_n
        .sdram_we_n                          (DRAM_WE_N)       // sdram.we_n
    );

endmodule