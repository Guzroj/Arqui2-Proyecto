`timescale 1ns/1ps

module Downscale_Secuencial (
    input  logic clk,
    input  logic rst,
    input  logic start,
    
    // ========== Dimensiones dinámicas ==========
    input  logic [31:0] img_width_in,   // SRC_W
    input  logic [31:0] img_height_in,  // SRC_H
    input  logic [31:0] img_width_out,  // DST_W
    input  logic [31:0] img_height_out, // DST_H

    // ========== Interfaz de memoria (32 bits) ==========
    output logic        mem_rd_req,
    output logic [31:0] mem_rd_addr,
    input  logic        mem_rd_valid,
    input  logic [7:0]  mem_rd_data,

    output logic        out_mem_we,
    output logic [31:0] out_mem_addr,
    output logic [7:0]  out_mem_data,

    output logic done
);

    localparam int FRAC = 8;
    
    // ========== Ratios calculados dinámicamente ==========
    logic [31:0] x_ratio_fp;
    logic [31:0] y_ratio_fp;
    logic [31:0] total_pixels;
    
    always_comb begin
        x_ratio_fp = ((img_width_in - 1) << FRAC) / (img_width_out - 1);
        y_ratio_fp = ((img_height_in - 1) << FRAC) / (img_height_out - 1);
        total_pixels = img_width_out * img_height_out;
    end

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

    // ========== Variables con tamaño fijo máximo ==========
    logic [31:0] pixel_idx;
    logic [31:0] i_dst;
    logic [31:0] j_dst;
    logic [31:0] x_src_fp;
    logic [31:0] y_src_fp;
    logic [31:0] x_l, y_l, x_h, y_h;

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

            S_CALC_COORDS: begin
                i_dst <= pixel_idx / img_width_out;
                j_dst <= pixel_idx % img_width_out;
                state <= S_CALC_SRC;
            end

            S_CALC_SRC: begin
                x_src_fp <= j_dst * x_ratio_fp;
                y_src_fp <= i_dst * y_ratio_fp;
                state    <= S_REQ_I00;
            end

            S_REQ_I00: begin
                x_l <= x_src_fp[31:FRAC];
                y_l <= y_src_fp[31:FRAC];

                x_h <= (x_src_fp[31:FRAC] < (img_width_in - 1)) ? 
                       (x_src_fp[31:FRAC] + 1) : 
                       x_src_fp[31:FRAC];
                y_h <= (y_src_fp[31:FRAC] < (img_height_in - 1)) ? 
                       (y_src_fp[31:FRAC] + 1) : 
                       y_src_fp[31:FRAC];

                alpha <= x_src_fp[FRAC-1:0];
                beta  <= y_src_fp[FRAC-1:0];

                mem_rd_req  <= 1'b1;
                mem_rd_addr <= y_src_fp[31:FRAC] * img_width_in + x_src_fp[31:FRAC];
                state       <= S_WAIT_I00;
            end

            S_WAIT_I00: begin
                if (mem_rd_valid) begin
                    I00 <= mem_rd_data;
                    state <= S_REQ_I10;
                end
            end

            S_REQ_I10: begin
                mem_rd_req  <= 1'b1;
                mem_rd_addr <= y_l * img_width_in + x_h;
                state       <= S_WAIT_I10;
            end

            S_WAIT_I10: begin
                if (mem_rd_valid) begin
                    I10 <= mem_rd_data;
                    state <= S_REQ_I01;
                end
            end

            S_REQ_I01: begin
                mem_rd_req  <= 1'b1;
                mem_rd_addr <= y_h * img_width_in + x_l;
                state       <= S_WAIT_I01;
            end

            S_WAIT_I01: begin
                if (mem_rd_valid) begin
                    I01 <= mem_rd_data;
                    state <= S_REQ_I11;
                end
            end

            S_REQ_I11: begin
                mem_rd_req  <= 1'b1;
                mem_rd_addr <= y_h * img_width_in + x_h;
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

            S_WRITE_OUT: begin
                out_mem_we   <= 1'b1;
                out_mem_addr <= i_dst * img_width_out + j_dst;
                out_mem_data <= pixel_out;

                pixel_idx <= pixel_idx + 1;

                if (pixel_idx + 1 >= total_pixels) begin
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