// ============================================================================
// jtag_avalon_controller.sv
// Controlador que interfaza JTAG Virtual con el banco de registros
// Convierte comandos de 40 bits en operaciones de lectura/escritura
// Arquitectura de Computadores 2 - FASE 6
// ============================================================================

module jtag_avalon_controller (
    input  logic        clk,
    input  logic        rst_n,

    // Interfaz JTAG Virtual (desde IP de Quartus)
    input  logic        tdi,           // Datos seriales de entrada
    output logic        tdo,           // Datos seriales de salida
    input  logic        ir_in,         // Instrucción de entrada
    output logic        ir_out,        // Instrucción de salida
    input  logic        virtual_state_cdr,  // Capture-DR state
    input  logic        virtual_state_sdr,  // Shift-DR state
    input  logic        virtual_state_udr,  // Update-DR state

    // Interfaz hacia banco de registros
    output logic        reg_write,
    output logic        reg_read,
    output logic [7:0]  reg_addr,
    output logic [31:0] reg_write_data,
    input  logic [31:0] reg_read_data,
    input  logic        reg_read_valid
);

    // ========================================================================
    // Protocolo de comandos (40 bits)
    // ========================================================================
    // Formato de comando:
    // [39]    = R/W (1=Write, 0=Read)
    // [38:31] = Address (8 bits)
    // [30:0]  = Reserved/Data (31 bits)
    //
    // Para WRITE: bits [31:0] contienen datos a escribir
    // Para READ: bits [31:0] se ignoran en entrada, se llenan en salida

    localparam SHIFT_WIDTH = 40;

    // ========================================================================
    // Registro de desplazamiento
    // ========================================================================
    logic [SHIFT_WIDTH-1:0] shift_reg;
    logic [SHIFT_WIDTH-1:0] shift_reg_out;
    logic [5:0] bit_count;

    // ========================================================================
    // Decodificación de comando
    // ========================================================================
    logic        cmd_write;
    logic        cmd_read;
    logic [7:0]  cmd_addr;
    logic [31:0] cmd_data;

    // ========================================================================
    // FSM para control de operaciones
    // ========================================================================
    typedef enum logic [2:0] {
        IDLE,
        CAPTURE,
        SHIFT,
        EXECUTE_READ,
        EXECUTE_WRITE,
        WAIT_RESPONSE,
        UPDATE
    } state_t;

    state_t state, next_state;

    // ========================================================================
    // Registro de estado
    // ========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // ========================================================================
    // Lógica de próximo estado
    // ========================================================================
    always_comb begin
        next_state = state;

        case (state)
            IDLE: begin
                if (virtual_state_cdr) begin
                    next_state = CAPTURE;
                end
            end

            CAPTURE: begin
                next_state = SHIFT;
            end

            SHIFT: begin
                if (virtual_state_udr) begin
                    // Comando completo recibido
                    if (cmd_write) begin
                        next_state = EXECUTE_WRITE;
                    end else begin
                        next_state = EXECUTE_READ;
                    end
                end
            end

            EXECUTE_WRITE: begin
                next_state = UPDATE;
            end

            EXECUTE_READ: begin
                next_state = WAIT_RESPONSE;
            end

            WAIT_RESPONSE: begin
                if (reg_read_valid) begin
                    next_state = UPDATE;
                end
            end

            UPDATE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // ========================================================================
    // Shift register (entrada serial)
    // ========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg <= 40'd0;
            bit_count <= 6'd0;
        end else begin
            if (state == CAPTURE) begin
                // Inicializar para nueva captura
                shift_reg <= 40'd0;
                bit_count <= 6'd0;
            end else if (virtual_state_sdr && state == SHIFT) begin
                // Shift de entrada (LSB primero)
                shift_reg <= {tdi, shift_reg[SHIFT_WIDTH-1:1]};
                if (bit_count < SHIFT_WIDTH) begin
                    bit_count <= bit_count + 6'd1;
                end
            end
        end
    end

    // ========================================================================
    // Decodificación de comando
    // ========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cmd_write <= 1'b0;
            cmd_read  <= 1'b0;
            cmd_addr  <= 8'd0;
            cmd_data  <= 32'd0;
        end else begin
            if (state == SHIFT && virtual_state_udr) begin
                // Decodificar comando al finalizar shift
                cmd_write <= shift_reg[39];
                cmd_read  <= ~shift_reg[39];
                cmd_addr  <= shift_reg[38:31];
                cmd_data  <= shift_reg[31:0];
            end
        end
    end

    // ========================================================================
    // Generación de señales de control hacia registro
    // ========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_write <= 1'b0;
            reg_read  <= 1'b0;
            reg_addr  <= 8'd0;
            reg_write_data <= 32'd0;
        end else begin
            // Por defecto, desactivar señales
            reg_write <= 1'b0;
            reg_read  <= 1'b0;

            case (state)
                EXECUTE_WRITE: begin
                    reg_write <= 1'b1;
                    reg_addr  <= cmd_addr;
                    reg_write_data <= cmd_data;
                end

                EXECUTE_READ: begin
                    reg_read <= 1'b1;
                    reg_addr <= cmd_addr;
                end

                default: begin
                    // Mantener valores
                end
            endcase
        end
    end

    // ========================================================================
    // Shift register (salida serial)
    // ========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg_out <= 40'd0;
        end else begin
            if (state == WAIT_RESPONSE && reg_read_valid) begin
                // Cargar datos leídos en registro de salida
                shift_reg_out <= {8'd0, reg_read_data};
            end else if (state == EXECUTE_WRITE) begin
                // Para escritura, devolver status 0x00000000
                shift_reg_out <= 40'd0;
            end else if (virtual_state_sdr && state == SHIFT) begin
                // Shift de salida (LSB primero)
                shift_reg_out <= {1'b0, shift_reg_out[SHIFT_WIDTH-1:1]};
            end
        end
    end

    // ========================================================================
    // TDO output
    // ========================================================================
    assign tdo = shift_reg_out[0];

    // ========================================================================
    // IR passthrough (no se usa en este diseño)
    // ========================================================================
    assign ir_out = ir_in;

    // ========================================================================
    // Debug y monitoreo
    // ========================================================================
    `ifdef SIMULATION
        always_ff @(posedge clk) begin
            if (state == EXECUTE_WRITE) begin
                $display("[JTAG] WRITE: addr=0x%02X, data=0x%08X", cmd_addr, cmd_data);
            end
            if (state == EXECUTE_READ) begin
                $display("[JTAG] READ:  addr=0x%02X", cmd_addr);
            end
            if (state == WAIT_RESPONSE && reg_read_valid) begin
                $display("[JTAG] READ RESPONSE: data=0x%08X", reg_read_data);
            end
        end
    `endif

endmodule
