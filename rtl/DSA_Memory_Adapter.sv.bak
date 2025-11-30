/**
 * DSA_Memory_Adapter.sv
 * 
 * Adaptador de memoria para DSA Downscaler: convierte interfaz byte-wise del DSA
 * a interfaz Avalon-MM (word-based, 32 bits)
 * 
 * Funcionalidades:
 * - Sirve lecturas de memoria durante procesamiento (input_memory)
 * - Captura escrituras del DSA en buffers internos
 * - Transfiere arrays de salida a memoria Avalon después de done (output_memory)
 * - Soporta dual-mode: SIMD (N lanes) y Secuencial (1 lane)
 * - Performance counters integrados
 * 
 * Modos:
 * - SIMD (mode=1): Serializa N requests paralelas, captura image_out[i][j] 2D
 * - Secuencial (mode=0): Forward directo, captura out_mem_we/addr/data
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
    input  logic [31:0] input_base_addr,    // Dirección base memoria entrada (0x00000000)
    input  logic [31:0] output_base_addr,   // Dirección base memoria salida (0x00040000)
    input  logic [31:0] img_width_out,      // Ancho salida (DST_W)
    input  logic [31:0] img_height_out,     // Alto salida (DST_H)
    
    // ========== Señales de estado DSA ==========
    input  logic        dsa_core_done,      // DSA core terminó (SIMD o Seq)
    output logic        adapter_busy,       // Adaptador ocupado (writeback)
    
    // ========== SIMD - Interfaz de lectura (N puertos) ==========
    input  logic        simd_mem_rd_req   [N],
    input  logic [31:0] simd_mem_rd_addr  [N],  // Byte address (offset relativo)
    output logic        simd_mem_rd_valid [N],
    output logic [7:0]  simd_mem_rd_data  [N],
    
    // ========== SIMD - Array de salida (después de done) ==========
    input  logic [7:0]  simd_image_out [0:MAX_HEIGHT-1][0:MAX_WIDTH-1],
    
    // ========== Secuencial - Interfaz de lectura (1 puerto) ==========
    input  logic        seq_mem_rd_req,
    input  logic [31:0] seq_mem_rd_addr,
    output logic        seq_mem_rd_valid,
    output logic [7:0]  seq_mem_rd_data,
    
    // ========== Secuencial - Interfaz de escritura (captura) ==========
    input  logic        seq_wr_req,         // = out_mem_we del Downscale_Secuencial
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
    // FSM Principal
    // =========================================================================
    typedef enum logic [2:0] {
        IDLE,               // Esperando start
        READ_SERVING,       // Sirviendo lecturas durante procesamiento
        WRITEBACK_INIT,     // Inicialización de writeback
        WRITEBACK_WRITE,    // Escribiendo píxel a Avalon
        WRITEBACK_WAIT,     // Esperando Avalon
        WRITEBACK_DONE      // Writeback completo
    } state_t;
    
    state_t state, next_state;

    // =========================================================================
    // Buffer de Salida Secuencial (captura escrituras)
    // =========================================================================
    logic [7:0] seq_output_buffer [0:(MAX_WIDTH*MAX_HEIGHT)-1];
    
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            seq_output_buffer <= '{default: 8'd0};
        end else if (dsa_mode == 0 && seq_wr_req) begin
            // Capturar escrituras secuenciales en tiempo real
            seq_output_buffer[seq_wr_addr] <= seq_wr_data;
        end
    end

    // =========================================================================
    // Serializador de Lecturas SIMD
    // =========================================================================
    logic [$clog2(N)-1:0] read_lane_idx;    // Lane actual siendo servido [0..N-1]
    logic                 simd_read_active; // Hay requests SIMD pendientes
    logic [31:0]          current_rd_addr;  // Dirección actual de lectura
    logic [1:0]           current_byte_offset;
    
    // Detectar si hay requests SIMD pendientes
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
    
    // Seleccionar dirección según modo
    always_comb begin
        if (dsa_mode == 1) begin
            // SIMD: usar lane actual
            byte_address = simd_mem_rd_addr[read_lane_idx];
        end else begin
            // Secuencial: directo
            byte_address = seq_mem_rd_addr;
        end
        
        // Conversión byte → word
        word_address = input_base_addr + (byte_address >> 2);
        byte_offset  = byte_address[1:0];
    end
    
    // Extraer byte del word de 32 bits
    always_comb begin
        case (byte_offset)
            2'b00: extracted_byte = avm_readdata[7:0];
            2'b01: extracted_byte = avm_readdata[15:8];
            2'b10: extracted_byte = avm_readdata[23:16];
            2'b11: extracted_byte = avm_readdata[31:24];
        endcase
    end

    // =========================================================================
    // Lógica de Writeback (Transferir arrays de salida a Avalon)
    // =========================================================================
    logic [31:0] wb_pixel_idx;              // Índice píxel actual [0..DST_W*DST_H-1]
    logic [31:0] wb_total_pixels;           // Total de píxeles a escribir
    logic [31:0] wb_row, wb_col;            // Coordenadas (i, j)
    logic [7:0]  wb_pixel_data;             // Dato del píxel actual
    
    always_comb begin
        wb_total_pixels = img_width_out * img_height_out;
        wb_row = wb_pixel_idx / img_width_out;
        wb_col = wb_pixel_idx % img_width_out;
        
        // Seleccionar dato según modo
        if (dsa_mode == 1) begin
            // SIMD: leer de array 2D
            wb_pixel_data = simd_image_out[wb_row][wb_col];
        end else begin
            // Secuencial: leer de buffer 1D
            wb_pixel_data = seq_output_buffer[wb_pixel_idx];
        end
    end

    // =========================================================================
    // FSM: Transición de Estados
    // =========================================================================
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // =========================================================================
    // Detectar actividad de lectura (cualquier request activo)
    // =========================================================================
    logic read_requests_active;
    
    always_comb begin
        read_requests_active = 1'b0;
        
        if (dsa_mode == 1) begin
            // SIMD: detectar cualquier request SIMD
            for (int k = 0; k < N; k++) begin
                if (simd_mem_rd_req[k]) begin
                    read_requests_active = 1'b1;
                end
            end
        end else begin
            // Secuencial: detectar request secuencial
            read_requests_active = seq_mem_rd_req;
        end
    end

    // =========================================================================
    // FSM: Lógica de Estado Siguiente
    // =========================================================================
    always_comb begin
        next_state = state;
        
        case (state)
            IDLE: begin
                // Comenzar cuando hay requests de lectura
                if (read_requests_active) begin
                    next_state = READ_SERVING;
                end
            end
            
            READ_SERVING: begin
                // Cuando el core DSA termina, pasar a writeback
                if (dsa_core_done) begin
                    next_state = WRITEBACK_INIT;
                end
            end
            
            WRITEBACK_INIT: begin
                next_state = WRITEBACK_WRITE;
            end
            
            WRITEBACK_WRITE: begin
                if (!avm_waitrequest) begin
                    next_state = WRITEBACK_WAIT;
                end
            end
            
            WRITEBACK_WAIT: begin
                // Esperar 1 ciclo (write posting en Avalon)
                if (wb_pixel_idx + 1 >= wb_total_pixels) begin
                    next_state = WRITEBACK_DONE;
                end else begin
                    next_state = WRITEBACK_WRITE;
                end
            end
            
            WRITEBACK_DONE: begin
                next_state = IDLE;
            end
        endcase
    end

    // =========================================================================
    // FSM: Lógica de Salida y Registros
    // =========================================================================
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            // Señales de control
            adapter_busy       <= 1'b0;
            read_lane_idx      <= '0;
            wb_pixel_idx       <= '0;
            
            // Avalon-MM
            avm_address        <= '0;
            avm_read           <= 1'b0;
            avm_write          <= 1'b0;
            avm_writedata      <= '0;
            avm_byteenable     <= 4'b0000;
            
            // Señales de lectura
            for (int k = 0; k < N; k++) begin
                simd_mem_rd_valid[k] <= 1'b0;
                simd_mem_rd_data[k]  <= 8'd0;
            end
            seq_mem_rd_valid   <= 1'b0;
            seq_mem_rd_data    <= 8'd0;
            
            // Performance counters
            perf_mem_reads     <= '0;
            perf_mem_writes    <= '0;
            
        end else begin
            // Defaults
            avm_read  <= 1'b0;
            avm_write <= 1'b0;
            
            case (state)
                // =============================================================
                // IDLE: Esperar inicio
                // =============================================================
                IDLE: begin
                    adapter_busy  <= 1'b0;
                    read_lane_idx <= '0;
                    wb_pixel_idx  <= '0;
                    
                    for (int k = 0; k < N; k++) begin
                        simd_mem_rd_valid[k] <= 1'b0;
                    end
                    seq_mem_rd_valid <= 1'b0;
                end
                
                // =============================================================
                // READ_SERVING: Servir lecturas de memoria
                // =============================================================
                READ_SERVING: begin
                    if (dsa_mode == 1) begin
                        // ========== MODO SIMD: Serializar N requests ==========
                        if (simd_read_active) begin
                            // Buscar próximo lane con request
                            logic found;
                            found = 1'b0;
                            
                            for (int k = 0; k < N; k++) begin
                                if (!found && simd_mem_rd_req[k]) begin
                                    // Emitir lectura Avalon para este lane
                                    avm_address <= word_address;
                                    avm_read    <= 1'b1;
                                    read_lane_idx <= k;
                                    found = 1'b1;
                                    
                                    // Incrementar contador
                                    perf_mem_reads <= perf_mem_reads + 1;
                                end
                            end
                        end
                        
                        // Cuando Avalon responde, enviar a lane correspondiente
                        if (avm_readdatavalid) begin
                            simd_mem_rd_valid[read_lane_idx] <= 1'b1;
                            simd_mem_rd_data[read_lane_idx]  <= extracted_byte;
                        end else begin
                            // Clear valid después de 1 ciclo
                            for (int k = 0; k < N; k++) begin
                                simd_mem_rd_valid[k] <= 1'b0;
                            end
                        end
                        
                    end else begin
                        // ========== MODO SECUENCIAL: Forward directo ==========
                        if (seq_mem_rd_req) begin
                            avm_address <= word_address;
                            avm_read    <= 1'b1;
                            
                            // Incrementar contador
                            perf_mem_reads <= perf_mem_reads + 1;
                        end
                        
                        // Cuando Avalon responde
                        if (avm_readdatavalid) begin
                            seq_mem_rd_valid <= 1'b1;
                            seq_mem_rd_data  <= extracted_byte;
                        end else begin
                            seq_mem_rd_valid <= 1'b0;
                        end
                    end
                end
                
                // =============================================================
                // WRITEBACK_INIT: Preparar transferencia de salida
                // =============================================================
                WRITEBACK_INIT: begin
                    adapter_busy <= 1'b1;
                    wb_pixel_idx <= '0;
                end
                
                // =============================================================
                // WRITEBACK_WRITE: Escribir píxel a memoria Avalon
                // =============================================================
                WRITEBACK_WRITE: begin
                    if (!avm_waitrequest) begin
                        // Calcular dirección de escritura (byte address)
                        logic [31:0] write_byte_addr;
                        logic [31:0] write_word_addr;
                        logic [1:0]  write_byte_offset;
                        
                        write_byte_addr   = wb_pixel_idx;
                        write_word_addr   = output_base_addr + (write_byte_addr >> 2);
                        write_byte_offset = write_byte_addr[1:0];
                        
                        // Emitir escritura Avalon
                        avm_address   <= write_word_addr;
                        avm_write     <= 1'b1;
                        avm_writedata <= {4{wb_pixel_data}};  // Replicar en los 4 bytes
                        
                        // Byte enable según offset
                        case (write_byte_offset)
                            2'b00: avm_byteenable <= 4'b0001;
                            2'b01: avm_byteenable <= 4'b0010;
                            2'b10: avm_byteenable <= 4'b0100;
                            2'b11: avm_byteenable <= 4'b1000;
                        endcase
                        
                        // Incrementar contador
                        perf_mem_writes <= perf_mem_writes + 1;
                    end
                end
                
                // =============================================================
                // WRITEBACK_WAIT: Esperar ciclo post-write
                // =============================================================
                WRITEBACK_WAIT: begin
                    wb_pixel_idx <= wb_pixel_idx + 1;
                end
                
                // =============================================================
                // WRITEBACK_DONE: Finalizar writeback
                // =============================================================
                WRITEBACK_DONE: begin
                    adapter_busy <= 1'b0;
                end
            endcase
        end
    end

endmodule

