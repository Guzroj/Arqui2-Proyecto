/**
 * DSA_Memory_Adapter.sv
 * 
 * Adaptador de memoria para DSA Downscaler: convierte interfaz byte-wise del DSA
 * a interfaz Avalon-MM (word-based, 32 bits)
 * 
 * VERSIÓN OPTIMIZADA: Sin arrays internos, escrituras directas a SDRAM
 * 
 * Funcionalidades:
 * - Sirve lecturas de memoria durante procesamiento (input_memory)
 * - Escribe píxeles directamente a SDRAM (sin buffer intermedio)
 * - Soporta dual-mode: SIMD (N lanes) y Secuencial (1 lane)
 * - Performance counters integrados
 */

module DSA_Memory_Adapter #(
    parameter int N = 4,                    // SIMD lanes
    parameter int MAX_WIDTH = 512,          // Máximo ancho de imagen
    parameter int MAX_HEIGHT = 512          // Máximo alto de imagen
)(
    // ========== Clock y Reset ==========
    input  logic        clk,
    input  logic        reset_n,
    
    // ========== Control desde DSA_Control_Registers ==========
    input  logic        dsa_mode,           // 0=Secuencial, 1=SIMD
    input  logic [31:0] input_base_addr,    // Dirección base memoria entrada
    input  logic [31:0] output_base_addr,   // Dirección base memoria salida
    input  logic [31:0] img_width_out,      // Ancho salida (DST_W)
    input  logic [31:0] img_height_out,     // Alto salida (DST_H)
    
    // ========== Señales de estado DSA ==========
    input  logic        dsa_core_done,      // DSA core terminó
    output logic        adapter_busy,       // Adaptador ocupado
    
    // ========== SIMD - Interfaz de lectura (N puertos) ==========
    input  logic        simd_mem_rd_req   [N],
    input  logic [31:0] simd_mem_rd_addr  [N],
    output logic        simd_mem_rd_valid [N],
    output logic [7:0]  simd_mem_rd_data  [N],
    
    // ========== SIMD - Interfaz de escritura (directa) ==========
    input  logic        simd_wr_req,
    input  logic [31:0] simd_wr_addr,
    input  logic [7:0]  simd_wr_data,
    
    // ========== Secuencial - Interfaz de lectura (1 puerto) ==========
    input  logic        seq_mem_rd_req,
    input  logic [31:0] seq_mem_rd_addr,
    output logic        seq_mem_rd_valid,
    output logic [7:0]  seq_mem_rd_data,
    
    // ========== Secuencial - Interfaz de escritura (directa) ==========
    input  logic        seq_wr_req,
    input  logic [31:0] seq_wr_addr,
    input  logic [7:0]  seq_wr_data,
    
    // ========== Avalon-MM Master (hacia memorias Qsys) ==========
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

    // =========================================================================
    // Señales de Escritura Unificadas
    // =========================================================================
    logic        write_req;
    logic [31:0] write_addr;
    logic [7:0]  write_data;
    
    always_comb begin
        if (dsa_mode == 1'b1) begin
            // SIMD
            write_req  = simd_wr_req;
            write_addr = simd_wr_addr;
            write_data = simd_wr_data;
        end else begin
            // Secuencial
            write_req  = seq_wr_req;
            write_addr = seq_wr_addr;
            write_data = seq_wr_data;
        end
    end

    // =========================================================================
    // Serializador de Lecturas SIMD
    // =========================================================================
    logic [$clog2(N)-1:0] read_lane_idx;
    logic                 simd_read_active;
    
    always_comb begin
        simd_read_active = 1'b0;
        for (int k = 0; k < N; k++) begin
            if (simd_mem_rd_req[k]) begin
                simd_read_active = 1'b1;
            end
        end
    end

    // =========================================================================
    // Lógica de Lectura (Byte → Word Conversion)
    // =========================================================================
    logic [31:0] byte_address;
    logic [31:0] word_address;
    logic [1:0]  byte_offset;
    logic [7:0]  extracted_byte;
    
    always_comb begin
        if (dsa_mode == 1) begin
            byte_address = simd_mem_rd_addr[read_lane_idx];
        end else begin
            byte_address = seq_mem_rd_addr;
        end
        
        word_address = input_base_addr + (byte_address >> 2);
        byte_offset  = byte_address[1:0];
    end
    
    always_comb begin
        case (byte_offset)
            2'b00: extracted_byte = avm_readdata[7:0];
            2'b01: extracted_byte = avm_readdata[15:8];
            2'b10: extracted_byte = avm_readdata[23:16];
            2'b11: extracted_byte = avm_readdata[31:24];
        endcase
    end

    // =========================================================================
    // Lógica de Escritura (Byte → Word Conversion)
    // =========================================================================
    logic [31:0] write_word_addr;
    logic [1:0]  write_byte_offset;
    
    always_comb begin
        write_word_addr   = output_base_addr + (write_addr >> 2);
        write_byte_offset = write_addr[1:0];
    end

    // =========================================================================
    // Arbitraje: Prioridad a Escrituras
    // =========================================================================
    typedef enum logic [1:0] {
        ARB_IDLE,
        ARB_WRITE,
        ARB_READ
    } arb_state_t;
    
    arb_state_t arb_state;
    
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            arb_state <= ARB_IDLE;
        end else begin
            case (arb_state)
                ARB_IDLE: begin
                    if (write_req) begin
                        arb_state <= ARB_WRITE;
                    end else if (dsa_mode ? simd_read_active : seq_mem_rd_req) begin
                        arb_state <= ARB_READ;
                    end
                end
                
                ARB_WRITE: begin
                    if (!avm_waitrequest) begin
                        arb_state <= ARB_IDLE;
                    end
                end
                
                ARB_READ: begin
                    if (avm_readdatavalid) begin
                        arb_state <= ARB_IDLE;
                    end
                end
            endcase
        end
    end

    // =========================================================================
    // Avalon-MM Master: Emisión de Transacciones
    // =========================================================================
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            avm_address    <= '0;
            avm_read       <= 1'b0;
            avm_write      <= 1'b0;
            avm_writedata  <= '0;
            avm_byteenable <= 4'b0000;
            
            read_lane_idx  <= '0;
            
            for (int k = 0; k < N; k++) begin
                simd_mem_rd_valid[k] <= 1'b0;
                simd_mem_rd_data[k]  <= 8'd0;
            end
            seq_mem_rd_valid <= 1'b0;
            seq_mem_rd_data  <= 8'd0;
            
            perf_mem_reads  <= '0;
            perf_mem_writes <= '0;
            
        end else begin
            // Defaults
            avm_read  <= 1'b0;
            avm_write <= 1'b0;
            
            case (arb_state)
                // =============================================================
                // ESCRITURA: Forward directo a Avalon
                // =============================================================
                ARB_WRITE: begin
                    if (!avm_waitrequest) begin
                        avm_address   <= write_word_addr;
                        avm_write     <= 1'b1;
                        avm_writedata <= {4{write_data}};
                        
                        case (write_byte_offset)
                            2'b00: avm_byteenable <= 4'b0001;
                            2'b01: avm_byteenable <= 4'b0010;
                            2'b10: avm_byteenable <= 4'b0100;
                            2'b11: avm_byteenable <= 4'b1000;
                        endcase
                        
                        perf_mem_writes <= perf_mem_writes + 1;
                    end
                end
                
                // =============================================================
                // LECTURA: Servir requests
                // =============================================================
                ARB_READ: begin
                    if (dsa_mode == 1'b1) begin
                        // ========== MODO SIMD ==========
                        if (simd_read_active && !avm_read) begin
                            logic found;
                            found = 1'b0;
                            
                            for (int k = 0; k < N; k++) begin
                                if (!found && simd_mem_rd_req[k]) begin
                                    avm_address <= word_address;
                                    avm_read    <= 1'b1;
                                    read_lane_idx <= k;
                                    found = 1'b1;
                                    
                                    perf_mem_reads <= perf_mem_reads + 1;
                                end
                            end
                        end
                        
                        if (avm_readdatavalid) begin
                            simd_mem_rd_valid[read_lane_idx] <= 1'b1;
                            simd_mem_rd_data[read_lane_idx]  <= extracted_byte;
                        end else begin
                            for (int k = 0; k < N; k++) begin
                                simd_mem_rd_valid[k] <= 1'b0;
                            end
                        end
                        
                    end else begin
                        // ========== MODO SECUENCIAL ==========
                        if (seq_mem_rd_req && !avm_read) begin
                            avm_address <= word_address;
                            avm_read    <= 1'b1;
                            
                            perf_mem_reads <= perf_mem_reads + 1;
                        end
                        
                        if (avm_readdatavalid) begin
                            seq_mem_rd_valid <= 1'b1;
                            seq_mem_rd_data  <= extracted_byte;
                        end else begin
                            seq_mem_rd_valid <= 1'b0;
                        end
                    end
                end
                
                default: begin
                    // Clear valids en IDLE
                    for (int k = 0; k < N; k++) begin
                        simd_mem_rd_valid[k] <= 1'b0;
                    end
                    seq_mem_rd_valid <= 1'b0;
                end
            endcase
        end
    end

    // =========================================================================
    // Señal de Busy (siempre OFF, no hay writeback post-procesamiento)
    // =========================================================================
    assign adapter_busy = 1'b0;

endmodule 