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

    // Control
    input  logic        start_req,
    output logic        done,

    // Debug
    output logic [7:0]  dbg_data
);

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
    localparam int DST_SIZE = DST_H * DST_W;
    logic [7:0] output_memory [0:DST_SIZE-1];

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
        if (out_mem_we && out_mem_addr < DST_SIZE) begin
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

        // Dimensiones configurables (ahora son constantes en este wrapper)
        .img_width_in(32'd512),   // SRC_W
        .img_height_in(32'd512),  // SRC_H
        .img_width_out(32'd256),  // DST_W
        .img_height_out(32'd256), // DST_H

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
    // Bloque para facilitar debug con mem
    // ========================================================================
    // Esto permite al testbench acceder a las memorias con dut.mem.memory
    // y dut.output_memory

    // Alias para compatibilidad con testbench
    typedef struct {
        logic [7:0] memory [0:SRC_SIZE-1];
    } mem_t;

    // No podemos crear un struct real en SystemVerilog de esta forma,
    // pero el testbench puede acceder directamente a memory

endmodule
