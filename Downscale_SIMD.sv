`timescale 1ns/1ps

module Downscale_SIMD #(
    parameter int SRC_H = 4,
    parameter int SRC_W = 4,
    parameter int DST_H = 3,
    parameter int DST_W = 3,
    parameter int N     = 4
)(
    input  logic clk,
    input  logic rst,
    input  logic start,

    // ====== INTERFAZ DE MEMORIA ======
    output logic                           mem_rd_req   [N],
    output logic [$clog2(SRC_W*SRC_H)-1:0] mem_rd_addr  [N],
    input  logic                           mem_rd_valid [N],
    input  logic [7:0]                     mem_rd_data  [N],

    // ====== SALIDA ======
    output logic        done,
    output logic [7:0]  image_out[0:DST_H-1][0:DST_W-1]
);

    // ------------------------------------------------------------------
    // CONSTANTES
    // ------------------------------------------------------------------
    localparam int FRAC       = 8;
    localparam int X_RATIO_FP = ((SRC_W - 1) << FRAC) / (DST_W - 1);
    localparam int Y_RATIO_FP = ((SRC_H - 1) << FRAC) / (DST_H - 1);

    localparam int TOT_PIX    = DST_H * DST_W;
    localparam int IDX_BITS   = $clog2(TOT_PIX) + 1;
    localparam int COORD_BITS = $clog2((SRC_W > SRC_H)? SRC_W : SRC_H) + 1;
    localparam int DST_BITS   = $clog2((DST_W > DST_H)? DST_W : DST_H) + 1;

    // ------------------------------------------------------------------
    // Señales SIMD
    // ------------------------------------------------------------------
    logic [7:0] I00_vec   [N];
    logic [7:0] I10_vec   [N];
    logic [7:0] I01_vec   [N];
    logic [7:0] I11_vec   [N];
    logic [7:0] alpha_vec [N];
    logic [7:0] beta_vec  [N];
    logic [7:0] pixel_out_vec [N];

    logic top_start;
    logic top_done;

    // ------------------------------------------------------------------
    // Instancia del TOP SIMD (tu pipeline)
    // ------------------------------------------------------------------
    Top_SIMD #(.N(N)) u_top_simd (
        .clk          (clk),
        .rst          (rst),
        .start        (top_start),
        .I00_vec      (I00_vec),
        .I10_vec      (I10_vec),
        .I01_vec      (I01_vec),
        .I11_vec      (I11_vec),
        .alpha_vec    (alpha_vec),
        .beta_vec     (beta_vec),
        .done         (top_done),
        .pixel_out_vec(pixel_out_vec)
    );

    // ------------------------------------------------------------------
    // FSM
    // ------------------------------------------------------------------
    typedef enum logic [3:0] {
        S_IDLE,
        S_CALC_COORDS,
        S_REQ_I00,
        S_WAIT_I00,
        S_REQ_I10,
        S_WAIT_I10,
        S_REQ_I01,
        S_WAIT_I01,
        S_REQ_I11,
        S_WAIT_I11,
        S_START_TOP,
        S_WAIT_TOP,
        S_WRITE_BATCH,
        S_DONE
    } state_t;

    state_t state;

    // ------------------------------------------------------------------
    // REGISTROS DE COORDENADAS
    // ------------------------------------------------------------------
    logic [IDX_BITS-1:0]   base_idx;
    logic [IDX_BITS-1:0]   idx       [N];
    logic [DST_BITS-1:0]   i_dst     [N];
    logic [DST_BITS-1:0]   j_dst     [N];
    logic [15:0]           x_src_fp  [N];
    logic [15:0]           y_src_fp  [N];
    logic [COORD_BITS-1:0] x_l       [N];
    logic [COORD_BITS-1:0] y_l       [N];
    logic [COORD_BITS-1:0] x_h       [N];
    logic [COORD_BITS-1:0] y_h       [N];
    logic                  valid_lane[N];

    // ------------------------------------------------------------------
    // Variables auxiliares para Quartus (NO automatic)
    // ------------------------------------------------------------------
    logic all_valid;
    integer kk;

    // ------------------------------------------------------------------
    // FSM PRINCIPAL
    // ------------------------------------------------------------------
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state     <= S_IDLE;
            base_idx  <= '0;
            done      <= 1'b0;
            top_start <= 1'b0;

            // Limpiar memoria salida
            for (int i = 0; i < DST_H; i++)
                for (int j = 0; j < DST_W; j++)
                    image_out[i][j] <= 8'd0;

            // Inicializar lanes
            for (int k = 0; k < N; k++) begin
                mem_rd_req[k]  <= 1'b0;
                mem_rd_addr[k] <= '0;
                valid_lane[k]  <= 1'b0;
                idx[k]         <= '0;
                I00_vec[k]     <= 8'd0;
                I10_vec[k]     <= 8'd0;
                I01_vec[k]     <= 8'd0;
                I11_vec[k]     <= 8'd0;
                alpha_vec[k]   <= 8'd0;
                beta_vec[k]    <= 8'd0;
            end

        end else begin

            case (state)

            // ==============================================================
            S_IDLE: begin
            // ==============================================================
                done      <= 1'b0;
                top_start <= 1'b0;
                base_idx  <= '0;

                for (int k = 0; k < N; k++)
                    mem_rd_req[k] <= 1'b0;

                if (start)
                    state <= S_CALC_COORDS;
            end

            // ==============================================================
            S_CALC_COORDS:
            // ==============================================================
            begin
                for (int k = 0; k < N; k++) begin
                    idx[k] = base_idx + k;
                    valid_lane[k] = (idx[k] < TOT_PIX);

                    if (valid_lane[k]) begin
                        i_dst[k] = idx[k] / DST_W;
                        j_dst[k] = idx[k] % DST_W;

                        x_src_fp[k] = j_dst[k] * X_RATIO_FP;
                        y_src_fp[k] = i_dst[k] * Y_RATIO_FP;

                        x_l[k] = x_src_fp[k][15:FRAC];
                        y_l[k] = y_src_fp[k][15:FRAC];

                        x_h[k] = (x_l[k] < SRC_W-1) ? (x_l[k]+1) : x_l[k];
                        y_h[k] = (y_l[k] < SRC_H-1) ? (y_l[k]+1) : y_l[k];

                        alpha_vec[k] <= x_src_fp[k][FRAC-1:0];
                        beta_vec[k]  <= y_src_fp[k][FRAC-1:0];
                    end
                end
                state <= S_REQ_I00;
            end

            // ==============================================================
            S_REQ_I00: begin
            // ==============================================================
                for (int k = 0; k < N; k++) begin
                    if (valid_lane[k]) begin
                        mem_rd_req[k]  <= 1'b1;
                        mem_rd_addr[k] <= y_l[k] * SRC_W + x_l[k];
                    end else begin
                        mem_rd_req[k] <= 1'b0;
                    end
                end
                state <= S_WAIT_I00;
            end

            // ==============================================================
            S_WAIT_I00: begin
            // ==============================================================
                for (int k = 0; k < N; k++)
                    mem_rd_req[k] <= 1'b0;

                all_valid = 1'b1;
                for (kk = 0; kk < N; kk++) begin
                    if (valid_lane[kk] && !mem_rd_valid[kk])
                        all_valid = 1'b0;
                end

                if (all_valid) begin
                    for (int k = 0; k < N; k++)
                        if (valid_lane[k])
                            I00_vec[k] <= mem_rd_data[k];

                    state <= S_REQ_I10;
                end
            end

            // ==============================================================
            S_REQ_I10: begin
            // ==============================================================
                for (int k = 0; k < N; k++) begin
                    if (valid_lane[k]) begin
                        mem_rd_req[k]  <= 1'b1;
                        mem_rd_addr[k] <= y_l[k] * SRC_W + x_h[k];
                    end else begin
                        mem_rd_req[k] <= 1'b0;
                    end
                end
                state <= S_WAIT_I10;
            end

            // ==============================================================
            S_WAIT_I10: begin
            // ==============================================================
                for (int k = 0; k < N; k++)
                    mem_rd_req[k] <= 1'b0;

                all_valid = 1'b1;
                for (kk = 0; kk < N; kk++) begin
                    if (valid_lane[kk] && !mem_rd_valid[kk])
                        all_valid = 1'b0;
                end

                if (all_valid) begin
                    for (int k = 0; k < N; k++)
                        if (valid_lane[k])
                            I10_vec[k] <= mem_rd_data[k];

                    state <= S_REQ_I01;
                end
            end

            // ==============================================================
            S_REQ_I01: begin
            // ==============================================================
                for (int k = 0; k < N; k++) begin
                    if (valid_lane[k]) begin
                        mem_rd_req[k]  <= 1'b1;
                        mem_rd_addr[k] <= y_h[k] * SRC_W + x_l[k];
                    end else begin
                        mem_rd_req[k] <= 1'b0;
                    end
                end
                state <= S_WAIT_I01;
            end

            // ==============================================================
            S_WAIT_I01: begin
            // ==============================================================
                for (int k = 0; k < N; k++)
                    mem_rd_req[k] <= 1'b0;

                all_valid = 1'b1;
                for (kk = 0; kk < N; kk++) begin
                    if (valid_lane[kk] && !mem_rd_valid[kk])
                        all_valid = 1'b0;
                end

                if (all_valid) begin
                    for (int k = 0; k < N; k++)
                        if (valid_lane[k])
                            I01_vec[k] <= mem_rd_data[k];

                    state <= S_REQ_I11;
                end
            end

            // ==============================================================
            S_REQ_I11: begin
            // ==============================================================
                for (int k = 0; k < N; k++) begin
                    if (valid_lane[k]) begin
                        mem_rd_req[k]  <= 1'b1;
                        mem_rd_addr[k] <= y_h[k] * SRC_W + x_h[k];
                    end else begin
                        mem_rd_req[k] <= 1'b0;
                    end
                end
                state <= S_WAIT_I11;
            end

            // ==============================================================
            S_WAIT_I11: begin
            // ==============================================================
                for (int k = 0; k < N; k++)
                    mem_rd_req[k] <= 1'b0;

                all_valid = 1'b1;
                for (kk = 0; kk < N; kk++) begin
                    if (valid_lane[kk] && !mem_rd_valid[kk])
                        all_valid = 1'b0;
                end

                if (all_valid) begin
                    for (int k = 0; k < N; k++)
                        if (valid_lane[k])
                            I11_vec[k] <= mem_rd_data[k];

                    state <= S_START_TOP;
                end
            end

            // ==============================================================
            S_START_TOP: begin
            // ==============================================================
                top_start <= 1'b1;
                state <= S_WAIT_TOP;
            end

            S_WAIT_TOP: begin
                top_start <= 1'b0;
                if (top_done)
                    state <= S_WRITE_BATCH;
            end

            // ==============================================================
            S_WRITE_BATCH:
            // ==============================================================
            begin
                for (int k = 0; k < N; k++)
                    if (valid_lane[k])
                        image_out[i_dst[k]][j_dst[k]] <= pixel_out_vec[k];

                if (base_idx + N >= TOT_PIX) begin
                    done  <= 1'b1;
                    state <= S_DONE;
                end else begin
                    base_idx <= base_idx + N;
                    state    <= S_CALC_COORDS;
                end
            end

            // ==============================================================
            S_DONE: begin
            // ==============================================================
                if (!start)
                    state <= S_IDLE;
            end

            endcase
        end
    end

endmodule
