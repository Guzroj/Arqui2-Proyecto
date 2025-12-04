`timescale 1ns/1ps

// ============================================================================
// Top_Downscale_SIMD - Wrapper con memorias integradas (SIMD N=4)
// ============================================================================
// Este módulo envuelve Downscale_SIMD y añade:
// - Memoria de entrada (BRAM configurable)
// - Memoria de salida (output_memory)
// - Interfaz de configuración estática (wr_en, wr_addr, wr_data)
// - Adaptación entre interfaz estática del testbench y dinámica del core
// - Performance counters (FLOPs, mem reads, mem writes)
// - Factor de escala configurable
// ============================================================================

module Top_Downscale_SIMD #(
    parameter int SRC_W = 512,
    parameter int SRC_H = 512,
    parameter int DST_W = 256,
    parameter int DST_H = 256,
    parameter int N = 4  // SIMD lanes
)(
    input  logic        clk,
    input  logic        rst,

    // Interfaz de configuración (carga de imagen)
    input  logic        wr_en,
    input  logic [17:0] wr_addr,
    input  logic [7:0]  wr_data,

    // Registro de factor de escala
    // Factor de escala: 0.5 a 1.0 en pasos de 0.05
    // Representación: 0=0.5, 1=0.55, 2=0.60, ..., 10=1.0
    input  logic [3:0]  scale_factor,  // 0-10 (11 valores posibles)

    // Control
    input  logic        start,
    output logic        done,

    // Salida de imagen (compatible con testbench)
    output logic [7:0]  image_out [0:DST_H-1][0:DST_W-1],

    // Debug
    output logic [7:0]  dbg_data,

    // Performance Counters
    output logic [31:0] perf_flops,         // Operaciones aritméticas (FLOPs)
    output logic [31:0] perf_mem_reads,     // Lecturas de memoria
    output logic [31:0] perf_mem_writes     // Escrituras de memoria
);

    // ========================================================================
    // Cálculo de dimensiones de salida basadas en factor de escala
    // ========================================================================
    logic [31:0] dst_width;
    logic [31:0] dst_height;

    always_comb begin
        case (scale_factor)
            4'd0:  begin dst_width = 32'd256; dst_height = 32'd256; end // 0.50
            4'd1:  begin dst_width = 32'd281; dst_height = 32'd281; end // 0.55
            4'd2:  begin dst_width = 32'd307; dst_height = 32'd307; end // 0.60
            4'd3:  begin dst_width = 32'd332; dst_height = 32'd332; end // 0.65
            4'd4:  begin dst_width = 32'd358; dst_height = 32'd358; end // 0.70
            4'd5:  begin dst_width = 32'd384; dst_height = 32'd384; end // 0.75
            4'd6:  begin dst_width = 32'd409; dst_height = 32'd409; end // 0.80
            4'd7:  begin dst_width = 32'd435; dst_height = 32'd435; end // 0.85
            4'd8:  begin dst_width = 32'd460; dst_height = 32'd460; end // 0.90
            4'd9:  begin dst_width = 32'd486; dst_height = 32'd486; end // 0.95
            4'd10: begin dst_width = 32'd512; dst_height = 32'd512; end // 1.00
            default: begin dst_width = 32'd256; dst_height = 32'd256; end // Default 0.50
        endcase
    end

    // ========================================================================
    // Memoria de entrada (BRAM)
    // ========================================================================
    localparam int SRC_SIZE = SRC_H * SRC_W;
    logic [7:0] memory [0:SRC_SIZE-1];

    // Escritura por configuración
    always_ff @(posedge clk) begin
        if (wr_en && wr_addr < SRC_SIZE) begin
            memory[wr_addr] <= wr_data;
        end
    end

    // ========================================================================
    // Memoria de salida (máximo 512x512)
    // ========================================================================
    localparam int MAX_DST_SIZE = 512 * 512;
    logic [7:0] output_memory_flat [0:MAX_DST_SIZE-1];

    // ========================================================================
    // Interfaz de lectura de memoria SIMD (N puertos)
    // ========================================================================
    logic        mem_rd_req   [N];
    logic [31:0] mem_rd_addr  [N];
    logic        mem_rd_valid [N];
    logic [7:0]  mem_rd_data  [N];

    // Lógica de lectura con latencia de 1 ciclo por cada puerto SIMD
    genvar g;
    generate
        for (g = 0; g < N; g++) begin : gen_mem_ports
            always_ff @(posedge clk) begin
                if (rst) begin
                    mem_rd_valid[g] <= 1'b0;
                    mem_rd_data[g]  <= 8'd0;
                end else begin
                    mem_rd_valid[g] <= mem_rd_req[g];
                    if (mem_rd_req[g] && mem_rd_addr[g] < SRC_SIZE) begin
                        mem_rd_data[g] <= memory[mem_rd_addr[g]];
                    end else begin
                        mem_rd_data[g] <= 8'd0;
                    end
                end
            end
        end
    endgenerate

    // ========================================================================
    // Interfaz de escritura de memoria de salida
    // ========================================================================
    logic        out_mem_we;
    logic [31:0] out_mem_addr;
    logic [7:0]  out_mem_data;

    always_ff @(posedge clk) begin
        if (out_mem_we && out_mem_addr < MAX_DST_SIZE) begin
            output_memory_flat[out_mem_addr] <= out_mem_data;
        end
    end

    // ========================================================================
    // Mapeo de memoria plana a array 2D (para compatibilidad con testbench)
    // ========================================================================
    always_comb begin
        for (int i = 0; i < DST_H; i++) begin
            for (int j = 0; j < DST_W; j++) begin
                image_out[i][j] = output_memory_flat[i * DST_W + j];
            end
        end
    end

    // ========================================================================
    // Instancia del módulo Downscale_SIMD
    // ========================================================================
    Downscale_SIMD #(
        .N(N)
    ) u_downscale (
        .clk(clk),
        .rst(rst),
        .start(start),

        // Dimensiones configurables dinámicamente según scale_factor
        .img_width_in(32'd512),      // SRC_W (entrada siempre 512x512)
        .img_height_in(32'd512),     // SRC_H
        .img_width_out(dst_width),   // Calculado según scale_factor
        .img_height_out(dst_height), // Calculado según scale_factor

        // Interfaz de memoria de lectura (N puertos SIMD)
        .mem_rd_req(mem_rd_req),
        .mem_rd_addr(mem_rd_addr),
        .mem_rd_valid(mem_rd_valid),
        .mem_rd_data(mem_rd_data),

        // Interfaz de memoria de escritura
        .out_mem_we(out_mem_we),
        .out_mem_addr(out_mem_addr),
        .out_mem_data(out_mem_data),

        .done(done)
    );

    // Debug: primer pixel de salida
    assign dbg_data = output_memory_flat[0];

    // ========================================================================
    // Performance Counters
    // ========================================================================
    // Cada píxel de salida requiere:
    // - 4 lecturas de memoria por SIMD lane (I00, I10, I01, I11)
    // - 1 escritura de memoria (píxel de salida)
    // - Para interpolación bilineal:
    //   * 4 multiplicaciones + 3 sumas = 7 FLOPs por píxel

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            perf_mem_reads  <= 32'd0;
            perf_mem_writes <= 32'd0;
            perf_flops      <= 32'd0;
        end else begin
            // Contar lecturas de memoria (sumar todos los puertos SIMD)
            for (int k = 0; k < N; k++) begin
                if (mem_rd_valid[k]) begin
                    perf_mem_reads <= perf_mem_reads + 32'd1;
                end
            end

            // Contar escrituras de memoria
            if (out_mem_we) begin
                perf_mem_writes <= perf_mem_writes + 32'd1;
                // Cada escritura representa un píxel completo procesado
                // Por cada píxel: 4 multiplicaciones + 3 sumas = 7 FLOPs
                perf_flops <= perf_flops + 32'd7;
            end
        end
    end

endmodule
