// ================================================================
// connect.sv
// Controlador de interfaz Virtual JTAG
// Basado en: https://github.com/Abner2111/GuiaJtag
// Adaptado para el proyecto de Downscale
// ================================================================

module connect (
    // Señales del Virtual JTAG IP
    input  logic        tck,           // Test Clock
    input  logic        tdi,           // Test Data In
    output logic        tdo,           // Test Data Out
    input  logic [1:0]  ir_in,         // Instruction Register
    input  logic        virtual_state_cdr,   // Capture-DR
    input  logic        virtual_state_sdr,   // Shift-DR
    input  logic        virtual_state_udr,   // Update-DR
    
    // Interfaz hacia JTAG_Interface (Avalon-like)
    output logic        avswrite,
    output logic        avsread,
    output logic [7:0]  avsaddress,
    output logic [31:0] avswritedata,
    input  logic [31:0] avsreaddata
);

    // ============================================================
    // Conjunto de instrucciones JTAG (2 bits)
    // ============================================================
    // 00 = BYPASS      - Operación estándar bypass
    // 01 = SET_ADDR    - Establecer dirección de registro (8 bits)
    // 10 = WRITE_REG   - Escribir dato al registro (32 bits)
    // 11 = READ_REG    - Leer dato del registro (32 bits)
    
    localparam IR_BYPASS    = 2'b00;
    localparam IR_SET_ADDR  = 2'b01;
    localparam IR_WRITE_REG = 2'b10;
    localparam IR_READ_REG  = 2'b11;
    
    // ============================================================
    // Registros de desplazamiento
    // ============================================================
    logic [7:0]  addr_shift_reg;      // Para dirección (8 bits)
    logic [31:0] data_shift_reg;      // Para datos (32 bits)
    logic [7:0]  current_addr;        // Dirección actual seleccionada
    
    // ============================================================
    // Lógica de TDO (salida de datos)
    // ============================================================
    always_comb begin
        case (ir_in)
            IR_BYPASS:    tdo = tdi;                    // Bypass directo
            IR_SET_ADDR:  tdo = addr_shift_reg[0];     // LSB de dirección
            IR_WRITE_REG: tdo = data_shift_reg[0];    // LSB de datos
            IR_READ_REG:  tdo = data_shift_reg[0];    // LSB de datos leídos
            default:      tdo = tdi;
        endcase
    end
    
    // ============================================================
    // Registro de desplazamiento de dirección (8 bits)
    // ============================================================
    always_ff @(posedge tck) begin
        if (ir_in == IR_SET_ADDR) begin
            if (virtual_state_cdr) begin
                // Capture: cargar dirección actual
                addr_shift_reg <= current_addr;
            end else if (virtual_state_sdr) begin
                // Shift: desplazar datos entrantes
                addr_shift_reg <= {tdi, addr_shift_reg[7:1]};
            end
        end
    end
    
    // ============================================================
    // Actualizar dirección actual
    // ============================================================
    always_ff @(posedge tck) begin
        if (ir_in == IR_SET_ADDR && virtual_state_udr) begin
            current_addr <= addr_shift_reg;
        end
    end
    
    // ============================================================
    // Registro de desplazamiento de datos (32 bits)
    // ============================================================
    always_ff @(posedge tck) begin
        if (ir_in == IR_WRITE_REG || ir_in == IR_READ_REG) begin
            if (virtual_state_cdr) begin
                // Capture: cargar datos desde avsreaddata
                data_shift_reg <= avsreaddata;
            end else if (virtual_state_sdr) begin
                // Shift: desplazar datos entrantes
                data_shift_reg <= {tdi, data_shift_reg[31:1]};
            end
        end
    end
    
    // ============================================================
    // Generación de señales de control Avalon-like
    // ============================================================
    
    // Escritura: pulso en Update-DR con instrucción WRITE_REG
    always_ff @(posedge tck) begin
        if (ir_in == IR_WRITE_REG && virtual_state_udr) begin
            avswrite <= 1'b1;
        end else begin
            avswrite <= 1'b0;
        end
    end
    
    // Lectura: pulso en Capture-DR con instrucción READ_REG
    always_ff @(posedge tck) begin
        if (ir_in == IR_READ_REG && virtual_state_cdr) begin
            avsread <= 1'b1;
        end else begin
            avsread <= 1'b0;
        end
    end
    
    // Dirección y datos de salida
    assign avsaddress   = current_addr;
    assign avswritedata = data_shift_reg;

endmodule

