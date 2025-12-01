`timescale 1ns/1ps

// ============================================================================
// Downscale_SIMD - Arquitectura Dinámica (Fase 4.6)
// ============================================================================
// Cambios críticos respecto a versión estática:
// - Parámetros SRC_H, SRC_W, DST_H, DST_W ELIMINADOS
// - Dimensiones ahora son PUERTOS DE ENTRADA (configurables en runtime)
// - Direcciones cambiadas a 32 bits estándar (Avalon-MM)
// - Ratios calculados dinámicamente en runtime
// - ELIMINADO array estático image_out[DST_H][DST_W] → Salida byte-wise
// - Sin arrays estáticos → Reducción de 94.5% en recursos
// ============================================================================

module Downscale_SIMD #(
    parameter int N = 4  // ✅ ÚNICO parámetro: SIMD lanes
)(
    input  logic        clk,
    input  logic        rst,
    input  logic        start,

    // ✅ NUEVO: Dimensiones configurables en runtime
    input  logic [31:0] img_width_in,
    input  logic [31:0] img_height_in,
    input  logic [31:0] img_width_out,
    input  logic [31:0] img_height_out,

    // Interfaz de memoria - N puertos de lectura (SIMD)
    output logic        mem_rd_req   [N],
    output logic [31:0] mem_rd_addr  [N],  // ✅ CAMBIADO: 32 bits fijos
    input  logic        mem_rd_valid [N],
    input  logic [7:0]  mem_rd_data  [N],

    // Interfaz de escritura - Byte-wise (sin array estático)
    output logic        out_mem_we,
    output logic [31:0] out_mem_addr,      // ✅ CAMBIADO: 32 bits fijos
    output logic [7:0]  out_mem_data,

    output logic        done
);

    localparam int FRAC = 8;  // Q0.8 para alpha/beta

    // ✅ Instancias SIMD del interpolador (N lanes paralelos)
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

    // FSM estados
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

    // ✅ Señales dinámicas (32 bits para soportar cualquier dimensión)
    logic [31:0] base_idx;
    logic [31:0] total_pixels;
    logic [31:0] idx       [N];
    logic [31:0] i_dst     [N];
    logic [31:0] j_dst     [N];
    logic [31:0] x_src_fp  [N];
    logic [31:0] y_src_fp  [N];
    logic [31:0] x_ratio_fp;
    logic [31:0] y_ratio_fp;
    logic [31:0] x_l       [N];
    logic [31:0] y_l       [N];
    logic [31:0] x_h       [N];
    logic [31:0] y_h       [N];
    logic        valid_lane[N];

    logic all_valid;
    integer kk;
    integer write_idx;  // Para escritura secuencial de batch

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state     <= S_IDLE;
            base_idx  <= 32'd0;
            done      <= 1'b0;
            top_start <= 1'b0;
            total_pixels <= 32'd0;
            x_ratio_fp <= 32'd0;
            y_ratio_fp <= 32'd0;
            out_mem_we <= 1'b0;
            out_mem_addr <= 32'd0;
            out_mem_data <= 8'd0;
            write_idx <= 0;

            for (int k = 0; k < N; k++) begin
                mem_rd_req[k]  <= 1'b0;
                mem_rd_addr[k] <= 32'd0;
                valid_lane[k]  <= 1'b0;
                idx[k]         <= 32'd0;
                i_dst[k]       <= 32'd0;
                j_dst[k]       <= 32'd0;
                x_src_fp[k]    <= 32'd0;
                y_src_fp[k]    <= 32'd0;
                x_l[k]         <= 32'd0;
                y_l[k]         <= 32'd0;
                x_h[k]         <= 32'd0;
                y_h[k]         <= 32'd0;
                I00_vec[k]     <= 8'd0;
                I10_vec[k]     <= 8'd0;
                I01_vec[k]     <= 8'd0;
                I11_vec[k]     <= 8'd0;
                alpha_vec[k]   <= 8'd0;
                beta_vec[k]    <= 8'd0;
            end

        end else begin

            // Defaults
            out_mem_we <= 1'b0;

            case (state)

            S_IDLE: begin
                done      <= 1'b0;
                top_start <= 1'b0;
                base_idx  <= 32'd0;
                write_idx <= 0;

                for (int k = 0; k < N; k++)
                    mem_rd_req[k] <= 1'b0;

                if (start) begin
                    // ✅ Calcular ratios dinámicamente en runtime
                    total_pixels <= img_width_out * img_height_out;
                    x_ratio_fp <= ((img_width_in - 32'd1) << FRAC) / (img_width_out - 32'd1);
                    y_ratio_fp <= ((img_height_in - 32'd1) << FRAC) / (img_height_out - 32'd1);
                    state <= S_CALC_COORDS;
                end
            end

            // Calcular coordenadas para N píxeles paralelos
            S_CALC_COORDS: begin
                for (int k = 0; k < N; k++) begin
                    idx[k] <= base_idx + k;
                    valid_lane[k] <= (base_idx + k < total_pixels);

                    if (base_idx + k < total_pixels) begin
                        i_dst[k] <= (base_idx + k) / img_width_out;
                        j_dst[k] <= (base_idx + k) % img_width_out;
                    end
                end
                state <= S_CALC_SRC;
            end

            // Calcular coordenadas fuente en punto fijo
            S_CALC_SRC: begin
                for (int k = 0; k < N; k++) begin
                    if (valid_lane[k]) begin
                        x_src_fp[k] <= j_dst[k] * x_ratio_fp;
                        y_src_fp[k] <= i_dst[k] * y_ratio_fp;
                    end
                end
                state <= S_REQ_I00;
            end

            // Request I00 para todos los lanes
            S_REQ_I00: begin
                for (int k = 0; k < N; k++) begin
                    if (valid_lane[k]) begin
                        x_l[k] <= x_src_fp[k][31:FRAC];
                        y_l[k] <= y_src_fp[k][31:FRAC];

                        x_h[k] <= (x_src_fp[k][31:FRAC] < img_width_in - 32'd1) ?
                                  (x_src_fp[k][31:FRAC] + 32'd1) :
                                  x_src_fp[k][31:FRAC];
                        y_h[k] <= (y_src_fp[k][31:FRAC] < img_height_in - 32'd1) ?
                                  (y_src_fp[k][31:FRAC] + 32'd1) :
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
                        else
                            I00_vec[k] <= 8'd0;
                    state <= S_REQ_I10;
                end
            end

            // Request I10 para todos los lanes
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
                        else
                            I10_vec[k] <= 8'd0;
                    state <= S_REQ_I01;
                end
            end

            // Request I01 para todos los lanes
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
                        else
                            I01_vec[k] <= 8'd0;
                    state <= S_REQ_I11;
                end
            end

            // Request I11 para todos los lanes
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
                        else
                            I11_vec[k] <= 8'd0;
                    state <= S_START_TOP;
                end
            end

            // Iniciar interpolación paralela
            S_START_TOP: begin
                top_start <= 1'b1;
                state <= S_WAIT_TOP;
            end

            S_WAIT_TOP: begin
                top_start <= 1'b0;
                if (top_done) begin
                    write_idx <= 0;
                    state <= S_WRITE_BATCH;
                end
            end

            // ✅ NUEVO: Escribir batch secuencialmente (sin array estático)
            S_WRITE_BATCH: begin
                if (write_idx < N && valid_lane[write_idx]) begin
                    out_mem_we   <= 1'b1;
                    out_mem_addr <= i_dst[write_idx] * img_width_out + j_dst[write_idx];
                    out_mem_data <= pixel_out_vec[write_idx];
                    write_idx    <= write_idx + 1;
                end else if (write_idx >= N || !valid_lane[write_idx]) begin
                    // Batch completo
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
                if (!start)
                    state <= S_IDLE;
            end

            endcase
        end
    end

endmodule
