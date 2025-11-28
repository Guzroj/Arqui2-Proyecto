// ======================================================
// Top_Downscale_SIMD.sv (FIX para Quartus 20.1.1)
// ======================================================

module Top_Downscale_SIMD #(
    parameter int SRC_W = 32,
    parameter int SRC_H = 32,
    parameter int DST_W = 16,
    parameter int DST_H = 16,
    parameter int N     = 4
)(
    input  logic clk,
    input  logic rst,

    input  logic        cfg_we,
    input  logic [15:0] cfg_addr,
    input  logic [7:0]  cfg_data,

    input  logic        start_req,

    output logic        done,
    output logic [7:0]  dbg_data
);

    localparam int SRC_DEPTH = SRC_W * SRC_H;
    localparam int ADDR_BITS = $clog2(SRC_DEPTH);

    // ==================================================
    // Memory interface
    // ==================================================
    logic                   mem_rd_req   [N];
    logic [ADDR_BITS-1:0]   mem_rd_addr  [N];
    logic                   mem_rd_valid [N];
    logic [7:0]             mem_rd_data  [N];

    ImageMemory_SIMDPort #(
        .IMG_W(SRC_W),
        .IMG_H(SRC_H),
        .N(N)
    ) mem (
        .clk     (clk),
        .rst     (rst),
        .rd_req  (mem_rd_req),
        .rd_addr (mem_rd_addr),
        .rd_valid(mem_rd_valid),
        .rd_data (mem_rd_data),
        .we      (cfg_we),
        .wr_addr (cfg_addr[ADDR_BITS-1:0]),
        .wr_data (cfg_data)
    );

    // ==================================================
    // Buffers
    // ==================================================
    logic [7:0] image_in  [0:SRC_H-1][0:SRC_W-1];
    logic [7:0] image_out [0:DST_H-1][0:DST_W-1];

    logic downscale_start;
    logic downscale_done;

    Downscale_SIMD #(
        .SRC_H(SRC_H),
        .SRC_W(SRC_W),
        .DST_H(DST_H),
        .DST_W(DST_W),
        .N(N)
    ) u_downscale (
        .clk       (clk),
        .rst       (rst),
        .start     (downscale_start),
        .image_in  (image_in),
        .done      (downscale_done),
        .image_out (image_out)
    );

    // ==================================================
    // FSM
    // ==================================================
    typedef enum logic [2:0] {
        S_IDLE,
        S_LOAD_IMAGE,
        S_WAIT_LOAD,
        S_START_DOWNSCALE,
        S_WAIT_DOWNSCALE,
        S_WRITE_RESULTS,
        S_DONE
    } state_t;

    state_t state;

    // ==================================================
    // Registers
    // ==================================================
    logic [ADDR_BITS-1:0] load_addr;
    logic [ADDR_BITS-1:0] write_addr;

    logic [$clog2(SRC_H):0] load_row;
    logic [$clog2(SRC_W):0] load_col;
    logic [$clog2(DST_H):0] write_row;
    logic [$clog2(DST_W):0] write_col;

    logic [5:0] wait_counter;

    // ===== FIX: Declaraciones movidas afuera =====
    logic any_valid;
    logic [$clog2(SRC_H):0] row;
    logic [$clog2(SRC_W):0] col;

    // ==================================================
    // FSM
    // ==================================================
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin

            state           <= S_IDLE;
            done            <= 1'b0;
            downscale_start <= 1'b0;

            load_addr       <= '0;
            write_addr      <= '0;
            wait_counter    <= '0;

            for (int k = 0; k < N; k++) begin
                mem_rd_req[k]  <= 1'b0;
                mem_rd_addr[k] <= '0;
            end

            for (int i = 0; i < SRC_H; i++)
                for (int j = 0; j < SRC_W; j++)
                    image_in[i][j] <= 8'd0;

        end else begin
            case (state)

                // ==========================================================
                S_IDLE: begin
                    done            <= 0;
                    downscale_start <= 0;

                    load_addr <= 0;
                    write_addr <= SRC_DEPTH;

                    for (int k = 0; k < N; k++)
                        mem_rd_req[k] <= 0;

                    if (start_req)
                        state <= S_LOAD_IMAGE;
                end

                // ==========================================================
                S_LOAD_IMAGE: begin
                    $display("[LOAD] load_addr=%0d", load_addr);

                    for (int k = 0; k < N; k++) begin
                        if (load_addr + k < SRC_DEPTH) begin
                            mem_rd_req[k]  <= 1;
                            mem_rd_addr[k] <= load_addr + k;
                        end else
                            mem_rd_req[k] <= 0;
                    end

                    wait_counter <= 0;
                    state <= S_WAIT_LOAD;
                end

                // ==========================================================
                S_WAIT_LOAD: begin
                    $display("[WAIT] load_addr=%0d wait=%0d",
                        load_addr, wait_counter);

                    if (wait_counter == 0)
                        for (int k = 0; k < N; k++)
                            mem_rd_req[k] <= 0;

                    wait_counter <= wait_counter + 1;

                    // ---- FIX: no declaración interna ----
                    any_valid = 0;
                    for (int k = 0; k < N; k++)
                        if (mem_rd_valid[k])
                            any_valid = 1;

                    if (any_valid) begin
                        for (int k = 0; k < N; k++) begin
                            if (mem_rd_valid[k]) begin
                                row = (load_addr + k) / SRC_W;
                                col = (load_addr + k) % SRC_W;
                                image_in[row][col] <= mem_rd_data[k];
                            end
                        end

                        load_addr <= load_addr + N;

                        if (load_addr + N >= SRC_DEPTH)
                            state <= S_START_DOWNSCALE;
                        else
                            state <= S_LOAD_IMAGE;

                    end else if (wait_counter > 20) begin
                        $display("TIMEOUT - sin valids!");
                        $finish;
                    end
                end

                // ==========================================================
                S_START_DOWNSCALE: begin
                    downscale_start <= 1;
                    state <= S_WAIT_DOWNSCALE;
                end

                S_WAIT_DOWNSCALE: begin
                    downscale_start <= 0;
                    if (downscale_done)
                        state <= S_WRITE_RESULTS;
                end

                S_WRITE_RESULTS: begin
                    done <= 1;
                    state <= S_DONE;
                end

                S_DONE: begin
                    if (!start_req)
                        state <= S_IDLE;
                end

            endcase
        end
    end

    assign dbg_data = mem_rd_data[0];

endmodule
