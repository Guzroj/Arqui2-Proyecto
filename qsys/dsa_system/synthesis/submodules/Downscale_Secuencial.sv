`timescale 1ns/1ps

module Downscale_Secuencial #(
    parameter int SRC_H = 512,
    parameter int SRC_W = 512,
    parameter int DST_H = 256,
    parameter int DST_W = 256
)(
    input  logic clk,
    input  logic rst,
    input  logic start,

    output logic                           mem_rd_req,
    output logic [$clog2(SRC_W*SRC_H)-1:0] mem_rd_addr,
    input  logic                           mem_rd_valid,
    input  logic [7:0]                     mem_rd_data,

    output logic                           out_mem_we,
    output logic [$clog2(DST_W*DST_H)-1:0] out_mem_addr,
    output logic [7:0]                     out_mem_data,

    output logic done
);

    localparam int FRAC       = 8;
    localparam int X_RATIO_FP = ((SRC_W - 1) << FRAC) / (DST_W - 1);
    localparam int Y_RATIO_FP = ((SRC_H - 1) << FRAC) / (DST_H - 1);

    localparam int TOT_PIX    = DST_H * DST_W;
    localparam int COORD_BITS = $clog2((SRC_W > SRC_H)? SRC_W : SRC_H) + 1;
    localparam int DST_W_BITS = $clog2(DST_W) + 1;
    localparam int DST_H_BITS = $clog2(DST_H) + 1;

    // Instancia del interpolador
    logic        valid_in;
    logic [7:0]  I00, I10, I01, I11;
    logic [7:0]  alpha, beta;
    logic        valid_out;
    logic [7:0]  pixel_out;

    ModoSecuencial u_secuencial (
        .clk(clk), .rst(rst),
        .valid_in(valid_in),
        .I00(I00), .I10(I10), .I01(I01), .I11(I11),
        .alpha(alpha), .beta(beta),
        .valid_out(valid_out),
        .pixel_out(pixel_out)
    );

    // FSM (igual estructura que SIMD)
    typedef enum logic [3:0] {
        S_IDLE,
        S_CALC_COORDS,
        S_CALC_SRC,
        S_REQ_I00,
        S_WAIT_I00,
        S_REQ_I10,
        S_WAIT_I10,
        S_REQ_I01,
        S_WAIT_I01,
        S_REQ_I11,
        S_WAIT_I11,
        S_START_INTERP,
        S_WAIT_INTERP,
        S_WRITE_OUT,
        S_DONE
    } state_t;

    state_t state;

    // Señales de coordenadas (como SIMD pero solo 1 píxel)
    logic [$clog2(TOT_PIX):0]  pixel_idx;
    logic [DST_H_BITS-1:0]     i_dst;
    logic [DST_W_BITS-1:0]     j_dst;
    logic [31:0]               x_src_fp;  // 32 bits como SIMD
    logic [31:0]               y_src_fp;
    logic [COORD_BITS-1:0]     x_l, y_l, x_h, y_h;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state       <= S_IDLE;
            done        <= 1'b0;
            valid_in    <= 1'b0;
            mem_rd_req  <= 1'b0;
            out_mem_we  <= 1'b0;
            pixel_idx   <= '0;
            i_dst       <= '0;
            j_dst       <= '0;
            x_src_fp    <= '0;
            y_src_fp    <= '0;
            x_l <= '0; y_l <= '0;
            x_h <= '0; y_h <= '0;
            I00 <= 8'd0; I10 <= 8'd0;
            I01 <= 8'd0; I11 <= 8'd0;
            alpha <= 8'd0; beta <= 8'd0;

        end else begin
            // Defaults
            valid_in   <= 1'b0;
            mem_rd_req <= 1'b0;
            out_mem_we <= 1'b0;

            case (state)

            S_IDLE: begin
                done      <= 1'b0;
                pixel_idx <= '0;
                if (start)
                    state <= S_CALC_COORDS;
            end

            // ===== IGUAL QUE SIMD: CALC_COORDS =====
            S_CALC_COORDS: begin
                i_dst <= DST_H_BITS'(pixel_idx / DST_W);
                j_dst <= DST_W_BITS'(pixel_idx % DST_W);
                state <= S_CALC_SRC;
            end

            // ===== IGUAL QUE SIMD: CALC_SRC =====
            S_CALC_SRC: begin
                x_src_fp <= 32'(j_dst) * 32'(X_RATIO_FP);
                y_src_fp <= 32'(i_dst) * 32'(Y_RATIO_FP);
                state    <= S_REQ_I00;
            end

            // ===== IGUAL QUE SIMD: REQ_I00 =====
            S_REQ_I00: begin
                x_l <= x_src_fp[31:FRAC];
                y_l <= y_src_fp[31:FRAC];

                x_h <= (x_src_fp[31:FRAC] < SRC_W-1) ? 
                       (x_src_fp[31:FRAC] + 1) : 
                       x_src_fp[31:FRAC];
                y_h <= (y_src_fp[31:FRAC] < SRC_H-1) ? 
                       (y_src_fp[31:FRAC] + 1) : 
                       y_src_fp[31:FRAC];

                alpha <= x_src_fp[FRAC-1:0];
                beta  <= y_src_fp[FRAC-1:0];

                mem_rd_req  <= 1'b1;
                mem_rd_addr <= y_src_fp[31:FRAC] * SRC_W + x_src_fp[31:FRAC];
                state       <= S_WAIT_I00;
            end

            S_WAIT_I00: begin
                if (mem_rd_valid) begin
                    I00 <= mem_rd_data;
                    state <= S_REQ_I10;
                end
            end

            // ===== IGUAL QUE SIMD: REQ_I10 =====
            S_REQ_I10: begin
                mem_rd_req  <= 1'b1;
                mem_rd_addr <= y_l * SRC_W + x_h;
                state       <= S_WAIT_I10;
            end

            S_WAIT_I10: begin
                if (mem_rd_valid) begin
                    I10 <= mem_rd_data;
                    state <= S_REQ_I01;
                end
            end

            // ===== IGUAL QUE SIMD: REQ_I01 =====
            S_REQ_I01: begin
                mem_rd_req  <= 1'b1;
                mem_rd_addr <= y_h * SRC_W + x_l;
                state       <= S_WAIT_I01;
            end

            S_WAIT_I01: begin
                if (mem_rd_valid) begin
                    I01 <= mem_rd_data;
                    state <= S_REQ_I11;
                end
            end

            // ===== IGUAL QUE SIMD: REQ_I11 =====
            S_REQ_I11: begin
                mem_rd_req  <= 1'b1;
                mem_rd_addr <= y_h * SRC_W + x_h;
                state       <= S_WAIT_I11;
            end

            S_WAIT_I11: begin
                if (mem_rd_valid) begin
                    I11 <= mem_rd_data;
                    state <= S_START_INTERP;
                end
            end

            // ===== IGUAL QUE SIMD: START_TOP =====
            S_START_INTERP: begin
                valid_in <= 1'b1;
                state    <= S_WAIT_INTERP;
            end

            // ===== IGUAL QUE SIMD: WAIT_TOP =====
            S_WAIT_INTERP: begin
                if (valid_out)
                    state <= S_WRITE_OUT;
            end

            // ===== IGUAL QUE SIMD: WRITE_BATCH =====
            S_WRITE_OUT: begin
                out_mem_we   <= 1'b1;
                out_mem_addr <= i_dst * DST_W + j_dst;
                out_mem_data <= pixel_out;

                pixel_idx <= pixel_idx + 1;

                if (pixel_idx + 1 >= TOT_PIX) begin
                    done  <= 1'b1;
                    state <= S_DONE;
                end else begin
                    state <= S_CALC_COORDS;
                end
            end

            S_DONE: begin
                if (!start)
                    state <= S_IDLE;
            end

            endcase
        end
    end

endmodule