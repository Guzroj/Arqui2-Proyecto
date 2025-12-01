`timescale 1ns/1ps

module Downscale_SIMD #(
    parameter int N = 4
)(
    input  logic clk,
    input  logic rst,
    input  logic start,
    
    // ========== Dimensiones dinámicas ==========
    input  logic [31:0] img_width_in,   // SRC_W
    input  logic [31:0] img_height_in,  // SRC_H
    input  logic [31:0] img_width_out,  // DST_W
    input  logic [31:0] img_height_out, // DST_H

    // ========== Interfaz de memoria (32 bits) ==========
    output logic        mem_rd_req   [N],
    output logic [31:0] mem_rd_addr  [N],
    input  logic        mem_rd_valid [N],
    input  logic [7:0]  mem_rd_data  [N],

    output logic        out_mem_we,
    output logic [31:0] out_mem_addr,
    output logic [7:0]  out_mem_data,
    
    output logic        done
);

    localparam int FRAC = 8;

    // ========== Ratios pre-calculados desde software ==========
    // Las dimensiones de salida ya vienen calculadas desde DSA_Avalon_Wrapper
    // a partir del scale_factor: width_out = (width_in * scale_factor) >> 8
    logic [31:0] x_ratio_fp;  // ((SRC_W - 1) << FRAC) / (DST_W - 1)
    logic [31:0] y_ratio_fp;  // ((SRC_H - 1) << FRAC) / (DST_H - 1)
    logic [31:0] total_pixels;  // DST_H * DST_W

    always_comb begin
        total_pixels = img_width_out * img_height_out;
        // Nota: Aún hay UNA división, pero ahora width_out y width_in están
        // correctamente relacionados por scale_factor, minimizando casos patológicos
        x_ratio_fp = ((img_width_in - 1) << FRAC) / (img_width_out - 1);
        y_ratio_fp = ((img_height_in - 1) << FRAC) / (img_height_out - 1);
    end

    logic [7:0] I00_vec   [N];
    logic [7:0] I10_vec   [N];
    logic [7:0] I01_vec   [N];
    logic [7:0] I11_vec   [N];
    logic [7:0] alpha_vec [N];
    logic [7:0] beta_vec  [N];
    logic [7:0] pixel_out_vec [N];

    logic top_start;
    logic top_done;

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
        S_START_TOP,
        S_WAIT_TOP,
        S_WRITE_BATCH,
        S_DONE
    } state_t;

    state_t state;

    // ========== Variables con tamaño fijo máximo ==========
    logic [31:0] base_idx;
    logic [31:0] idx       [N];
    logic [31:0] i_dst     [N];
    logic [31:0] j_dst     [N];
    logic [31:0] x_src_fp  [N];
    logic [31:0] y_src_fp  [N];
    logic [31:0] x_l       [N];
    logic [31:0] y_l       [N];
    logic [31:0] x_h       [N];
    logic [31:0] y_h       [N];
    logic        valid_lane[N];

    logic all_valid;
    integer kk;
    
    logic [2:0] write_lane_idx;  // [0..N-1]
    
    // ========== Timeout para evitar deadlock ==========
    logic [15:0] wait_timeout;
    localparam int TIMEOUT_MAX = 1000;  // ~20ms @ 50MHz

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state     <= S_IDLE;
            base_idx  <= '0;
            done      <= 1'b0;
            top_start <= 1'b0;
            
            // ========== CAMBIO: Inicializar señales de escritura ==========
            out_mem_we   <= 1'b0;
            out_mem_addr <= '0;
            out_mem_data <= 8'd0;
            write_lane_idx <= '0;

            for (int k = 0; k < N; k++) begin
                mem_rd_req[k]  <= 1'b0;
                mem_rd_addr[k] <= '0;
                valid_lane[k]  <= 1'b0;
                idx[k]         <= '0;
                i_dst[k]       <= '0;
                j_dst[k]       <= '0;
                x_src_fp[k]    <= '0;
                y_src_fp[k]    <= '0;
                x_l[k]         <= '0;
                y_l[k]         <= '0;
                x_h[k]         <= '0;
                y_h[k]         <= '0;
                I00_vec[k]     <= 8'd0;
                I10_vec[k]     <= 8'd0;
                I01_vec[k]     <= 8'd0;
                I11_vec[k]     <= 8'd0;
                alpha_vec[k]   <= 8'd0;
                beta_vec[k]    <= 8'd0;
            end
            wait_timeout <= '0;

        end else begin

            // ========== Default: escritura OFF ==========
            out_mem_we <= 1'b0;

            // Timeout counter
            if (state == S_WAIT_I00 || state == S_WAIT_I10 ||
                state == S_WAIT_I01 || state == S_WAIT_I11) begin
                all_valid = 1'b1;
                for (kk = 0; kk < N; kk++) begin
                    if (valid_lane[kk] && mem_rd_valid[kk])
                        ; // Lane válido
                    else if (valid_lane[kk] && !mem_rd_valid[kk])
                        all_valid = 1'b0;
                end

                if (all_valid) begin
                    wait_timeout <= '0;  // Reset on all valid
                end else begin
                    wait_timeout <= wait_timeout + 1;
                end
            end else begin
                wait_timeout <= '0;
            end

            case (state)

            S_IDLE: begin
                done      <= 1'b0;
                top_start <= 1'b0;
                base_idx  <= '0;

                for (int k = 0; k < N; k++)
                    mem_rd_req[k] <= 1'b0;

                if (start)
                    state <= S_CALC_COORDS;
            end

            S_CALC_COORDS: begin
                for (int k = 0; k < N; k++) begin
                    idx[k] <= base_idx + k;
                    valid_lane[k] <= (base_idx + k < total_pixels);
                    mem_rd_req[k] <= 1'b0;

                    if (base_idx + k < total_pixels) begin
                        i_dst[k] <= (base_idx + k) / img_width_out;
                        j_dst[k] <= (base_idx + k) % img_width_out;
                    end
                end
                state <= S_CALC_SRC;
            end

            S_CALC_SRC: begin
                for (int k = 0; k < N; k++) begin
                    mem_rd_req[k] <= 1'b0;
                    if (valid_lane[k]) begin
                        x_src_fp[k] <= j_dst[k] * x_ratio_fp;
                        y_src_fp[k] <= i_dst[k] * y_ratio_fp;
                    end
                end
                state <= S_REQ_I00;
            end

            S_REQ_I00: begin
                for (int k = 0; k < N; k++) begin
                    if (valid_lane[k]) begin
                        x_l[k] <= x_src_fp[k][31:FRAC];
                        y_l[k] <= y_src_fp[k][31:FRAC];

                        x_h[k] <= (x_src_fp[k][31:FRAC] < (img_width_in - 1)) ? 
                                  (x_src_fp[k][31:FRAC] + 1) : 
                                  x_src_fp[k][31:FRAC];
                        y_h[k] <= (y_src_fp[k][31:FRAC] < (img_height_in - 1)) ? 
                                  (y_src_fp[k][31:FRAC] + 1) : 
                                  y_src_fp[k][31:FRAC];

                        alpha_vec[k] <= x_src_fp[k][FRAC-1:0];
                        beta_vec[k]  <= y_src_fp[k][FRAC-1:0];

                        mem_rd_req[k]  <= 1'b1;
                        mem_rd_addr[k] <= y_src_fp[k][31:FRAC] * img_width_in + x_src_fp[k][31:FRAC];
                    end else begin
                        mem_rd_req[k] <= 1'b0;
                    end
                end
                state <= S_WAIT_I00;
            end

            S_WAIT_I00: begin
                // Mantener mem_rd_req activo para todos los lanes válidos
                for (int k = 0; k < N; k++)
                    if (valid_lane[k])
                        mem_rd_req[k] <= 1'b1;
                    else
                        mem_rd_req[k] <= 1'b0;

                if (all_valid) begin
                    for (int k = 0; k < N; k++) begin
                        if (valid_lane[k])
                            I00_vec[k] <= mem_rd_data[k];
                        else
                            I00_vec[k] <= 8'd0;
                        mem_rd_req[k] <= 1'b0;  // Bajar después de recibir
                    end
                    state <= S_REQ_I10;
                end else if (wait_timeout >= TIMEOUT_MAX) begin
                    // Timeout: usar valores por defecto y continuar
                    for (int k = 0; k < N; k++) begin
                        I00_vec[k] <= 8'd0;
                        mem_rd_req[k] <= 1'b0;
                    end
                    state <= S_REQ_I10;
                end
            end

            S_REQ_I10: begin
                for (int k = 0; k < N; k++) begin
                    if (valid_lane[k]) begin
                        mem_rd_req[k]  <= 1'b1;
                        mem_rd_addr[k] <= y_l[k] * img_width_in + x_h[k];
                    end else begin
                        mem_rd_req[k] <= 1'b0;
                    end
                end
                state <= S_WAIT_I10;
            end

            S_WAIT_I10: begin
                // Mantener mem_rd_req activo
                for (int k = 0; k < N; k++)
                    if (valid_lane[k])
                        mem_rd_req[k] <= 1'b1;
                    else
                        mem_rd_req[k] <= 1'b0;

                if (all_valid) begin
                    for (int k = 0; k < N; k++) begin
                        if (valid_lane[k])
                            I10_vec[k] <= mem_rd_data[k];
                        else
                            I10_vec[k] <= 8'd0;
                        mem_rd_req[k] <= 1'b0;
                    end
                    state <= S_REQ_I01;
                end else if (wait_timeout >= TIMEOUT_MAX) begin
                    for (int k = 0; k < N; k++) begin
                        I10_vec[k] <= 8'd0;
                        mem_rd_req[k] <= 1'b0;
                    end
                    state <= S_REQ_I01;
                end
            end

            S_REQ_I01: begin
                for (int k = 0; k < N; k++) begin
                    if (valid_lane[k]) begin
                        mem_rd_req[k]  <= 1'b1;
                        mem_rd_addr[k] <= y_h[k] * img_width_in + x_l[k];
                    end else begin
                        mem_rd_req[k] <= 1'b0;
                    end
                end
                state <= S_WAIT_I01;
            end

            S_WAIT_I01: begin
                // Mantener mem_rd_req activo
                for (int k = 0; k < N; k++)
                    if (valid_lane[k])
                        mem_rd_req[k] <= 1'b1;
                    else
                        mem_rd_req[k] <= 1'b0;

                if (all_valid) begin
                    for (int k = 0; k < N; k++) begin
                        if (valid_lane[k])
                            I01_vec[k] <= mem_rd_data[k];
                        else
                            I01_vec[k] <= 8'd0;
                        mem_rd_req[k] <= 1'b0;
                    end
                    state <= S_REQ_I11;
                end else if (wait_timeout >= TIMEOUT_MAX) begin
                    for (int k = 0; k < N; k++) begin
                        I01_vec[k] <= 8'd0;
                        mem_rd_req[k] <= 1'b0;
                    end
                    state <= S_REQ_I11;
                end
            end

            S_REQ_I11: begin
                for (int k = 0; k < N; k++) begin
                    if (valid_lane[k]) begin
                        mem_rd_req[k]  <= 1'b1;
                        mem_rd_addr[k] <= y_h[k] * img_width_in + x_h[k];
                    end else begin
                        mem_rd_req[k] <= 1'b0;
                    end
                end
                state <= S_WAIT_I11;
            end

            S_WAIT_I11: begin
                // Mantener mem_rd_req activo
                for (int k = 0; k < N; k++)
                    if (valid_lane[k])
                        mem_rd_req[k] <= 1'b1;
                    else
                        mem_rd_req[k] <= 1'b0;

                if (all_valid) begin
                    for (int k = 0; k < N; k++) begin
                        if (valid_lane[k])
                            I11_vec[k] <= mem_rd_data[k];
                        else
                            I11_vec[k] <= 8'd0;
                        mem_rd_req[k] <= 1'b0;
                    end
                    state <= S_START_TOP;
                end else if (wait_timeout >= TIMEOUT_MAX) begin
                    for (int k = 0; k < N; k++) begin
                        I11_vec[k] <= 8'd0;
                        mem_rd_req[k] <= 1'b0;
                    end
                    state <= S_START_TOP;
                end
            end

            S_START_TOP: begin
                top_start <= 1'b1;
                for (int k = 0; k < N; k++)
                    mem_rd_req[k] <= 1'b0;
                state <= S_WAIT_TOP;
            end

            S_WAIT_TOP: begin
                top_start <= 1'b0;
                for (int k = 0; k < N; k++)
                    mem_rd_req[k] <= 1'b0;
                if (top_done) begin
                    write_lane_idx <= '0;  // Resetear contador
                    state <= S_WRITE_BATCH;
                end
            end

            // ========== CAMBIO: Serializar escrituras de N píxeles ==========
            S_WRITE_BATCH: begin
                for (int k = 0; k < N; k++)
                    mem_rd_req[k] <= 1'b0;

                if (write_lane_idx < N) begin
                    if (valid_lane[write_lane_idx]) begin
                        // Escribir píxel actual
                        out_mem_we   <= 1'b1;
                        out_mem_addr <= i_dst[write_lane_idx] * img_width_out + j_dst[write_lane_idx];
                        out_mem_data <= pixel_out_vec[write_lane_idx];
                    end

                    // Avanzar al siguiente lane
                    write_lane_idx <= write_lane_idx + 1;

                end else begin
                    // Todas las escrituras completadas
                    base_idx <= base_idx + N;

                    if (base_idx + N >= total_pixels) begin
                        done  <= 1'b1;
                        state <= S_DONE;
                    end else begin
                        state <= S_CALC_COORDS;
                    end
                end
            end

            S_DONE: begin
                for (int k = 0; k < N; k++)
                    mem_rd_req[k] <= 1'b0;
                if (!start)
                    state <= S_IDLE;
            end

            endcase
        end
    end

endmodule 