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

    output logic        done
);

    localparam int FRAC       = 8;
    localparam int X_RATIO_FP = ((SRC_W - 1) << FRAC) / (DST_W - 1);
    localparam int Y_RATIO_FP = ((SRC_H - 1) << FRAC) / (DST_H - 1);

    localparam int COORD_BITS = $clog2(SRC_W > SRC_H ? SRC_W : SRC_H) + 1;
    localparam int DST_I_BITS = $clog2(DST_H) + 1;
    localparam int DST_J_BITS = $clog2(DST_W) + 1;

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

    typedef enum logic [2:0] {
        S_IDLE,
        S_FETCH,
        S_INTERP,
        S_DONE
    } state_t;

    state_t state;

    logic [DST_I_BITS-1:0] i_dst;
    logic [DST_J_BITS-1:0] j_dst;
    logic [23:0] x_src_fp, y_src_fp;
    logic [COORD_BITS-1:0] x_l, x_h, y_l, y_h;
    logic [2:0] fetch_cnt;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state       <= S_IDLE;
            done        <= 1'b0;
            valid_in    <= 1'b0;
            mem_rd_req  <= 1'b0;
            out_mem_we  <= 1'b0;
            i_dst       <= 0;
            j_dst       <= 0;
            fetch_cnt   <= 0;
                    
        end else begin
            out_mem_we <= 1'b0;  // Default
            
            case (state)
                
                S_IDLE: begin
                    done       <= 1'b0;
                    valid_in   <= 1'b0;
                    mem_rd_req <= 1'b0;
                    
                    if (start) begin
                        i_dst     <= 0;
                        j_dst     <= 0;
                        x_src_fp  <= 0;
                        y_src_fp  <= 0;
                        x_l       <= 0;
                        y_l       <= 0;
                        x_h       <= 1;
                        y_h       <= 1;
                        alpha     <= 0;
                        beta      <= 0;
                        fetch_cnt <= 0;
                        state     <= S_FETCH;
                    end
                end

                S_FETCH: begin
                    case (fetch_cnt)
                        0: begin
                            mem_rd_req  <= 1'b1;
                            mem_rd_addr <= y_l * SRC_W + x_l;
                            fetch_cnt   <= 1;
                        end
                        1: begin
                            if (mem_rd_valid) begin
                                I00         <= mem_rd_data;
                                mem_rd_req  <= 1'b1;
                                mem_rd_addr <= y_l * SRC_W + x_h;
                                fetch_cnt   <= 2;
                            end
                        end
                        2: begin
                            if (mem_rd_valid) begin
                                I10         <= mem_rd_data;
                                mem_rd_req  <= 1'b1;
                                mem_rd_addr <= y_h * SRC_W + x_l;
                                fetch_cnt   <= 3;
                            end
                        end
                        3: begin
                            if (mem_rd_valid) begin
                                I01         <= mem_rd_data;
                                mem_rd_req  <= 1'b1;
                                mem_rd_addr <= y_h * SRC_W + x_h;
                                fetch_cnt   <= 4;
                            end
                        end
                        4: begin
                            if (mem_rd_valid) begin
                                I11        <= mem_rd_data;
                                mem_rd_req <= 1'b0;
                                valid_in   <= 1'b1;
                                state      <= S_INTERP;
                            end
                        end
                    endcase
                end

                S_INTERP: begin
                    valid_in <= 1'b0;
                    
                    if (valid_out) begin
                        out_mem_we   <= 1'b1;
                        out_mem_addr <= i_dst * DST_W + j_dst;
                        out_mem_data <= pixel_out;

                        if ((i_dst == (DST_H-1)) && (j_dst == (DST_W-1))) begin
                            done  <= 1'b1;
                            state <= S_DONE;
                        end else begin
                            if (j_dst == (DST_W-1)) begin
                                j_dst <= 0;
                                i_dst <= i_dst + 1;
                            end else begin
                                j_dst <= j_dst + 1;
                            end
                            
                            if (j_dst == (DST_W-1)) begin
                                x_src_fp <= 0;
                                y_src_fp <= 24'(i_dst + 1) * 24'(Y_RATIO_FP);
                                x_l      <= 0;
                                y_l      <= (24'(i_dst + 1) * 24'(Y_RATIO_FP)) >> FRAC;
                                x_h      <= 1;
                                
                                if (((24'(i_dst + 1) * 24'(Y_RATIO_FP)) >> FRAC) >= (SRC_H-1))
                                    y_h <= (24'(i_dst + 1) * 24'(Y_RATIO_FP)) >> FRAC;
                                else
                                    y_h <= ((24'(i_dst + 1) * 24'(Y_RATIO_FP)) >> FRAC) + 1;
                                
                                alpha <= 0;
                                beta  <= (24'(i_dst + 1) * 24'(Y_RATIO_FP)) & 8'hFF;
                            end else begin
                                x_src_fp <= 24'(j_dst + 1) * 24'(X_RATIO_FP);
                                x_l      <= (24'(j_dst + 1) * 24'(X_RATIO_FP)) >> FRAC;
                                
                                if (((24'(j_dst + 1) * 24'(X_RATIO_FP)) >> FRAC) >= (SRC_W-1))
                                    x_h <= (24'(j_dst + 1) * 24'(X_RATIO_FP)) >> FRAC;
                                else
                                    x_h <= ((24'(j_dst + 1) * 24'(X_RATIO_FP)) >> FRAC) + 1;
                                
                                alpha <= (24'(j_dst + 1) * 24'(X_RATIO_FP)) & 8'hFF;
                            end
                            
                            fetch_cnt <= 0;
                            state     <= S_FETCH;
                        end
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