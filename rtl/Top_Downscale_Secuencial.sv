`timescale 1ns/1ps

// ============================================================================
// Top_Downscale_Secuencial - Wrapper con memorias integradas
// ============================================================================
// Este módulo envuelve Downscale_Secuencial y añade:
// - Memoria de entrada (BRAM configurable)
// - Memoria de salida (output_memory)
// - Interfaz de configuración estática (cfg_we, cfg_addr, cfg_data)
// - Adaptación entre interfaz estática del testbench y dinámica del core
// ============================================================================

module Top_Downscale_Secuencial #(
    parameter int SRC_W = 512,
    parameter int SRC_H = 512,
    parameter int DST_W = 256,
    parameter int DST_H = 256
)(
    input  logic        clk,
    input  logic        rst,

    // Interfaz de configuración (carga de imagen)
    input  logic        cfg_we,
    input  logic [17:0] cfg_addr,
    input  logic [7:0]  cfg_data,

    // Registro de factor de escala
    // Factor de escala: 0.5 a 1.0 en pasos de 0.05
    // Representación: 0=0.5, 1=0.55, 2=0.60, ..., 10=1.0
    input  logic [3:0]  scale_factor,  // 0-10 (11 valores posibles)

    // Control
    input  logic        start_req,
    output logic        done,

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
    // Tabla de conversión de scale_factor a dimensiones:
    // scale_factor | Factor real | DST_W    | DST_H
    // -------------|-------------|----------|----------
    //      0       |    0.50     | 256      | 256
    //      1       |    0.55     | 281      | 281
    //      2       |    0.60     | 307      | 307
    //      3       |    0.65     | 332      | 332
    //      4       |    0.70     | 358      | 358
    //      5       |    0.75     | 384      | 384
    //      6       |    0.80     | 409      | 409
    //      7       |    0.85     | 435      | 435
    //      8       |    0.90     | 460      | 460
    //      9       |    0.95     | 486      | 486
    //     10       |    1.00     | 512      | 512

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
        if (cfg_we && cfg_addr < SRC_SIZE) begin
            memory[cfg_addr] <= cfg_data;
        end
    end

    // ========================================================================
    // Memoria de salida
    // ========================================================================
    // La memoria debe ser lo suficientemente grande para el caso máximo (512x512)
    localparam int MAX_DST_SIZE = 512 * 512;
    logic [7:0] output_memory [0:MAX_DST_SIZE-1];

    // ========================================================================
    // Interfaz de lectura de memoria
    // ========================================================================
    logic        mem_rd_req;
    logic [31:0] mem_rd_addr;
    logic        mem_rd_valid;
    logic [7:0]  mem_rd_data;

    // Lógica de lectura con latencia de 1 ciclo (simula BRAM)
    always_ff @(posedge clk) begin
        if (rst) begin
            mem_rd_valid <= 1'b0;
            mem_rd_data  <= 8'd0;
        end else begin
            mem_rd_valid <= mem_rd_req;
            if (mem_rd_req && mem_rd_addr < SRC_SIZE) begin
                mem_rd_data <= memory[mem_rd_addr];
            end else begin
                mem_rd_data <= 8'd0;
            end
        end
    end

    // ========================================================================
    // Interfaz de escritura de memoria de salida
    // ========================================================================
    logic        out_mem_we;
    logic [31:0] out_mem_addr;
    logic [7:0]  out_mem_data;

    always_ff @(posedge clk) begin
        if (out_mem_we && out_mem_addr < MAX_DST_SIZE) begin
            output_memory[out_mem_addr] <= out_mem_data;
        end
    end

    // ========================================================================
    // Instancia del módulo Downscale_Secuencial
    // ========================================================================
    Downscale_Secuencial u_seq (
        .clk(clk),
        .rst(rst),
        .start(start_req),

        // Dimensiones configurables dinámicamente según scale_factor
        .img_width_in(32'd512),      // SRC_W (entrada siempre 512x512)
        .img_height_in(32'd512),     // SRC_H
        .img_width_out(dst_width),   // Calculado según scale_factor
        .img_height_out(dst_height), // Calculado según scale_factor

        // Interfaz de memoria de lectura
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
    assign dbg_data = output_memory[0];

    // ========================================================================
    // Performance Counters
    // ========================================================================
    // Cada píxel de salida requiere:
    // - 4 lecturas de memoria (I00, I10, I01, I11)
    // - 1 escritura de memoria (píxel de salida)
    // - Para interpolación bilineal:
    //   * 4 multiplicaciones (I00*(1-α)*(1-β), I10*α*(1-β), I01*(1-α)*β, I11*α*β)
    //   * 3 sumas (sumar los 4 productos)
    //   * Total: 7 operaciones aritméticas por píxel

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            perf_mem_reads  <= 32'd0;
            perf_mem_writes <= 32'd0;
            perf_flops      <= 32'd0;
        end else begin
            // Contar lecturas de memoria
            if (mem_rd_valid) begin
                perf_mem_reads <= perf_mem_reads + 32'd1;
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
