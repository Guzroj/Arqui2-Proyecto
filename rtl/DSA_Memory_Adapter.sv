// ============================================================================
// DSA_Memory_Adapter.sv
// ============================================================================
// Descripción:
//   Adaptador que convierte las interfaces byte-wise del DSA (Downscale_SIMD
//   y Downscale_Secuencial) a interfaz Avalon-MM Master estándar (32 bits).
//
// Funcionalidad:
//   - Convierte direcciones de byte a word (divide por 4)
//   - Extrae bytes específicos de palabras de 32 bits
//   - Serializa requests de lectura SIMD (N requests → 1 a la vez)
//   - Maneja escrituras directas con byte enable
//   - Performance counters para reads/writes
//
// Problema Resuelto:
//   DSA usa direcciones de BYTE (offset 0,1,2,3,...)
//   Avalon-MM usa direcciones de WORD de 32 bits (offset 0,4,8,12,...)
//
// Arquitectura:
//   - FSM de arbitraje (IDLE, READ, WRITE)
//   - Prioridad: Escrituras > Lecturas (no se pueden perder)
//   - Serialización round-robin para lecturas SIMD
//
// Autor: DSA Project Team
// Fecha: Noviembre 2025
// ============================================================================

`timescale 1ns/1ps

module DSA_Memory_Adapter #(
    parameter int N = 4  // Número de lanes SIMD
)(
    input  logic        clk,
    input  logic        rst,

    // ========== Base Addresses ==========
    input  logic [31:0] input_base_addr,
    input  logic [31:0] output_base_addr,

    // ========== SIMD - Lecturas (N puertos) ==========
    input  logic        simd_mem_rd_req   [N],
    input  logic [31:0] simd_mem_rd_addr  [N],  // Direcciones de BYTE
    output logic        simd_mem_rd_valid [N],
    output logic [7:0]  simd_mem_rd_data  [N],

    // ========== SIMD - Escrituras (1 puerto compartido) ==========
    input  logic        simd_wr_req,
    input  logic [31:0] simd_wr_addr,            // Dirección de BYTE
    input  logic [7:0]  simd_wr_data,

    // ========== Secuencial - Lecturas ==========
    input  logic        seq_mem_rd_req,
    input  logic [31:0] seq_mem_rd_addr,         // Dirección de BYTE
    output logic        seq_mem_rd_valid,
    output logic [7:0]  seq_mem_rd_data,

    // ========== Secuencial - Escrituras ==========
    input  logic        seq_wr_req,
    input  logic [31:0] seq_wr_addr,             // Dirección de BYTE
    input  logic [7:0]  seq_wr_data,

    // ========== Avalon-MM Master ==========
    output logic [31:0] avm_address,
    output logic        avm_read,
    output logic        avm_write,
    output logic [31:0] avm_writedata,
    output logic [3:0]  avm_byteenable,
    input  logic        avm_waitrequest,
    input  logic [31:0] avm_readdata,
    input  logic        avm_readdatavalid,

    // ========== Performance Counters ==========
    output logic [31:0] perf_mem_reads,
    output logic [31:0] perf_mem_writes
);

    // ========================================================================
    // FSM Estados
    // ========================================================================
    typedef enum logic [1:0] {
        ARB_IDLE,
        ARB_WRITE,
        ARB_READ
    } arb_state_t;

    arb_state_t state;

    // ========================================================================
    // Señales Internas
    // ========================================================================
    logic        write_req;
    logic [31:0] write_addr;
    logic [7:0]  write_data;

    logic        read_req;
    logic [31:0] read_addr;
    logic        is_simd_read;
    logic [2:0]  read_lane_idx;  // Para SIMD (0-3)

    logic [31:0] word_address;
    logic [1:0]  byte_offset;
    logic [7:0]  extracted_byte;

    // ========================================================================
    // Multiplexación de Escrituras (SIMD o Secuencial)
    // ========================================================================
    always_comb begin
        if (simd_wr_req) begin
            write_req  = 1'b1;
            write_addr = simd_wr_addr;
            write_data = simd_wr_data;
        end else if (seq_wr_req) begin
            write_req  = 1'b1;
            write_addr = seq_wr_addr;
            write_data = seq_wr_data;
        end else begin
            write_req  = 1'b0;
            write_addr = 32'd0;
            write_data = 8'd0;
        end
    end

    // ========================================================================
    // Arbitraje de Lecturas (Round-Robin para SIMD)
    // ========================================================================
    logic [2:0] rr_counter;  // Round-robin counter para SIMD

    always_comb begin
        automatic int idx;  // Declarar fuera del loop

        read_req       = 1'b0;
        read_addr      = 32'd0;
        is_simd_read   = 1'b0;
        read_lane_idx  = 3'd0;

        // Primero check secuencial
        if (seq_mem_rd_req) begin
            read_req     = 1'b1;
            read_addr    = seq_mem_rd_addr;
            is_simd_read = 1'b0;
        end else begin
            // Luego check SIMD (round-robin)
            for (int k = 0; k < N; k++) begin
                idx = (rr_counter + k) % N;
                if (simd_mem_rd_req[idx] && !read_req) begin
                    read_req      = 1'b1;
                    read_addr     = simd_mem_rd_addr[idx];
                    is_simd_read  = 1'b1;
                    read_lane_idx = idx[2:0];
                end
            end
        end
    end

    // ========================================================================
    // Conversión Byte Address → Word Address
    // ========================================================================
    always_comb begin
        word_address = read_addr >> 2;   // Divide por 4
        byte_offset  = read_addr[1:0];   // Offset dentro de la palabra
    end

    // ========================================================================
    // Extracción de Byte desde Word de 32 bits
    // ========================================================================
    always_comb begin
        case (byte_offset)
            2'b00: extracted_byte = avm_readdata[7:0];
            2'b01: extracted_byte = avm_readdata[15:8];
            2'b10: extracted_byte = avm_readdata[23:16];
            2'b11: extracted_byte = avm_readdata[31:24];
        endcase
    end

    // ========================================================================
    // FSM de Arbitraje
    // ========================================================================
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state            <= ARB_IDLE;
            avm_read         <= 1'b0;
            avm_write        <= 1'b0;
            avm_address      <= 32'd0;
            avm_writedata    <= 32'd0;
            avm_byteenable   <= 4'b0000;
            rr_counter       <= 3'd0;
            perf_mem_reads   <= 32'd0;
            perf_mem_writes  <= 32'd0;

            seq_mem_rd_valid <= 1'b0;
            seq_mem_rd_data  <= 8'd0;

            for (int k = 0; k < N; k++) begin
                simd_mem_rd_valid[k] <= 1'b0;
                simd_mem_rd_data[k]  <= 8'd0;
            end

        end else begin
            // Defaults
            avm_read  <= 1'b0;
            avm_write <= 1'b0;
            seq_mem_rd_valid <= 1'b0;

            for (int k = 0; k < N; k++)
                simd_mem_rd_valid[k] <= 1'b0;

            case (state)

                // ============================================================
                // IDLE: Esperar requests
                // ============================================================
                ARB_IDLE: begin
                    // Prioridad: Escrituras > Lecturas
                    if (write_req) begin
                        state <= ARB_WRITE;
                    end else if (read_req) begin
                        state <= ARB_READ;
                    end
                end

                // ============================================================
                // WRITE: Procesar escritura
                // ============================================================
                ARB_WRITE: begin
                    if (!avm_waitrequest) begin
                        // Calcular dirección word y byte enable
                        logic [31:0] word_addr;
                        logic [1:0]  byte_offs;

                        word_addr = write_addr >> 2;
                        byte_offs = write_addr[1:0];

                        // Emitir escritura Avalon-MM
                        avm_write   <= 1'b1;
                        avm_address <= output_base_addr + (word_addr << 2);

                        // Byte enable según offset
                        case (byte_offs)
                            2'b00: begin
                                avm_byteenable <= 4'b0001;
                                avm_writedata  <= {24'd0, write_data};
                            end
                            2'b01: begin
                                avm_byteenable <= 4'b0010;
                                avm_writedata  <= {16'd0, write_data, 8'd0};
                            end
                            2'b10: begin
                                avm_byteenable <= 4'b0100;
                                avm_writedata  <= {8'd0, write_data, 16'd0};
                            end
                            2'b11: begin
                                avm_byteenable <= 4'b1000;
                                avm_writedata  <= {write_data, 24'd0};
                            end
                        endcase

                        perf_mem_writes <= perf_mem_writes + 32'd1;
                        state <= ARB_IDLE;
                    end
                end

                // ============================================================
                // READ: Procesar lectura
                // ============================================================
                ARB_READ: begin
                    if (!avm_waitrequest && !avm_read) begin
                        // Emitir lectura Avalon-MM
                        avm_read        <= 1'b1;
                        avm_address     <= input_base_addr + (word_address << 2);
                        avm_byteenable  <= 4'b1111;  // Leer palabra completa
                        perf_mem_reads  <= perf_mem_reads + 32'd1;
                    end

                    // Esperar readdatavalid
                    if (avm_readdatavalid) begin
                        if (is_simd_read) begin
                            simd_mem_rd_valid[read_lane_idx] <= 1'b1;
                            simd_mem_rd_data[read_lane_idx]  <= extracted_byte;
                            rr_counter <= rr_counter + 3'd1;  // Round-robin
                        end else begin
                            seq_mem_rd_valid <= 1'b1;
                            seq_mem_rd_data  <= extracted_byte;
                        end

                        state <= ARB_IDLE;
                    end
                end

            endcase
        end
    end

endmodule
