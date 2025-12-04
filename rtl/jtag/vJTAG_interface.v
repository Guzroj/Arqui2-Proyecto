// ============================================================================
// vJTAG_interface.v
// JTAG Interface Module para control de 8 LEDs
// Basado en: https://idlelogiclabs.com/2012/04/15/talking-to-the-de0-nano-using-the-virtual-jtag-interface/
// Adaptado para DE1-SoC con 8 LEDs (LEDR[7:0])
// ============================================================================

module vJTAG_interface (
    input tck,           // JTAG clock
    input tdi,           // Test Data In
    input aclr,          // Asynchronous clear (not used, but kept for compatibility)
    input ir_in,         // Instruction Register input (1-bit: 0=bypass, 1=LED control)
    input v_sdr,         // Virtual Shift DR state
    input udr,           // Update Data Register signal

    output reg [7:0] LEDs,  // 8-bit LED output
    output reg tdo          // Test Data Out
);

    // ========================================================================
    // Data Registers
    // ========================================================================
    reg DR0_bypass_reg;     // Bypass register (safeguard for bad IR)
    reg [7:0] DR1;          // Data Register 1: LED settings (8 bits)

    // ========================================================================
    // IR Decoding
    // ========================================================================
    wire select_DR0 = !ir_in;   // IR=0: Bypass mode
    wire select_DR1 = ir_in;    // IR=1: LED control mode

    // ========================================================================
    // Shift Register Logic
    // ========================================================================
    // Shift data on JTAG clock rising edge
    always @ (posedge tck or posedge aclr) begin
        if (aclr) begin
            DR0_bypass_reg <= 1'b0;
            DR1 <= 8'b00000000;
        end
        else begin
            // Always update bypass register
            DR0_bypass_reg <= tdi;

            // Shift into DR1 when in Shift-DR state and DR1 is selected
            if (v_sdr) begin
                if (select_DR1)
                    DR1 <= {tdi, DR1[7:1]};  // Shift right, MSB first
            end
        end
    end

    // ========================================================================
    // TDO Output Logic
    // ========================================================================
    // Maintain TDO continuity (combinational logic)
    always @ (*) begin
        if (select_DR1)
            tdo <= DR1[0];          // Shift out from DR1 LSB
        else
            tdo <= DR0_bypass_reg;  // Shift out from bypass register
    end

    // ========================================================================
    // LED Output Update
    // ========================================================================
    // Update LED outputs when Update-DR signal asserts
    // Note: LEDs are NOT connected directly to DR1 to avoid unwanted behavior
    // during shifting
    always @(posedge udr) begin
        LEDs <= DR1;
    end

endmodule
