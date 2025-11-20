`timescale 1ns/1ps

module tb_FSM_SIMD;

    logic clk, rst;
    logic start;
    logic simd_valid;

    logic load_regs;
    logic run_simd;
    logic write_back;
    logic done;

    // Instancia
    FSM_SIMD #(
        .N(4),
        .OUT_W(3),
        .OUT_H(3)
    ) dut (
        .* 
    );

    // Clock
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // -----------------------------
    // Función para mostrar el estado
    // -----------------------------
    function string state_to_str(input logic [2:0] s);
        case (s)
            3'd0: state_to_str = "S_IDLE";
            3'd1: state_to_str = "S_LOAD";
            3'd2: state_to_str = "S_RUN";
            3'd3: state_to_str = "S_WAIT";
            3'd4: state_to_str = "S_WRITE";
            3'd5: state_to_str = "S_NEXT";
            3'd6: state_to_str = "S_DONE";
            default: state_to_str = "UNKNOWN";
        endcase
    endfunction

    // Monitor REAL
    initial begin
        $monitor("t=%0t | state=%s | load=%b run=%b write=%b done=%b | simd_valid=%b | batch=%0d",
            $time,
            state_to_str(dut.state),
            load_regs,
            run_simd,
            write_back,
            done,
            simd_valid,
            dut.batch_cnt
        );
    end

    // Stimulus
    initial begin
        $display("\n=== TEST FSM SIMD ===");

        rst = 1;
        start = 0;
        simd_valid = 0;

        repeat(3) @(posedge clk);
        rst = 0;

        @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;

        // ---------------------
        // BATCH 1
        // ---------------------
        repeat(4) @(posedge clk);
        simd_valid = 1; @(posedge clk);
        simd_valid = 0;

        // ---------------------
        // BATCH 2
        // ---------------------
        repeat(4) @(posedge clk);
        simd_valid = 1; @(posedge clk);
        simd_valid = 0;

        // ---------------------
        // BATCH 3
        // ---------------------
        repeat(4) @(posedge clk);
        simd_valid = 1; @(posedge clk);
        simd_valid = 0;

        repeat(5) @(posedge clk);

        $display("\n=== FIN TEST FSM ===");
        $finish;
    end

endmodule
