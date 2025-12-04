// ============================================================================
// jtag_register_map.sv
// Banco de registros para interfaz JTAG
// Permite control y acceso a memorias del sistema de downscaling
// Arquitectura de Computadores 2 - FASE 6
// ============================================================================

module jtag_register_map (
    input  logic        clk,
    input  logic        rst_n,

    // Interfaz de lectura/escritura desde JTAG
    input  logic        reg_write,           // Señal de escritura
    input  logic        reg_read,            // Señal de lectura
    input  logic [7:0]  reg_addr,            // Dirección del registro
    input  logic [31:0] reg_write_data,      // Datos a escribir
    output logic [31:0] reg_read_data,       // Datos leídos
    output logic        reg_read_valid,      // Dato de lectura válido

    // Señales de control hacia el sistema
    output logic        start_processing,    // Iniciar downscaling
    output logic        reset_memories,      // Reset de memorias
    input  logic        busy,                // Sistema ocupado
    input  logic        done,                // Procesamiento completo
    input  logic [2:0]  fsm_state,           // Estado de la FSM

    // Interfaz con memoria de entrada (escritura)
    output logic        mem_in_wr_en,
    output logic [11:0] mem_in_wr_addr,
    output logic [7:0]  mem_in_wr_data,

    // Interfaz con memoria de salida (lectura)
    output logic        mem_out_rd_en,
    output logic [9:0]  mem_out_rd_addr,
    input  logic [7:0]  mem_out_rd_data,
    input  logic [10:0] pixels_written       // Contador de píxeles
);

    // ========================================================================
    // Mapa de registros
    // ========================================================================
    localparam ADDR_CONTROL    = 8'h00;
    localparam ADDR_STATUS     = 8'h01;
    localparam ADDR_IMG_WR_ADDR= 8'h02;
    localparam ADDR_IMG_WR_DATA= 8'h03;
    localparam ADDR_IMG_RD_ADDR= 8'h04;
    localparam ADDR_IMG_RD_DATA= 8'h05;
    localparam ADDR_PIXEL_COUNT= 8'h06;

    // ========================================================================
    // Registros internos
    // ========================================================================
    logic [11:0] img_wr_addr_reg;
    logic [9:0]  img_rd_addr_reg;
    logic [7:0]  mem_out_rd_data_reg;
    logic        mem_out_rd_valid;

    // Señales de control (pulsos de 1 ciclo)
    logic start_pulse;
    logic reset_pulse;

    // ========================================================================
    // Lógica de escritura de registros
    // ========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            start_pulse <= 1'b0;
            reset_pulse <= 1'b0;
            img_wr_addr_reg <= 12'd0;
            mem_in_wr_en <= 1'b0;
            mem_in_wr_addr <= 12'd0;
            mem_in_wr_data <= 8'd0;
        end else begin
            // Por defecto, los pulsos duran 1 ciclo
            start_pulse <= 1'b0;
            reset_pulse <= 1'b0;
            mem_in_wr_en <= 1'b0;

            if (reg_write) begin
                case (reg_addr)
                    ADDR_CONTROL: begin
                        start_pulse <= reg_write_data[0];
                        reset_pulse <= reg_write_data[1];
                    end

                    ADDR_IMG_WR_ADDR: begin
                        img_wr_addr_reg <= reg_write_data[11:0];
                    end

                    ADDR_IMG_WR_DATA: begin
                        // Escribir en memoria de entrada
                        mem_in_wr_en <= 1'b1;
                        mem_in_wr_addr <= img_wr_addr_reg;
                        mem_in_wr_data <= reg_write_data[7:0];
                        // Auto-incrementar dirección
                        if (img_wr_addr_reg < 12'd4095) begin
                            img_wr_addr_reg <= img_wr_addr_reg + 12'd1;
                        end
                    end

                    default: begin
                        // Registro no escribible o inválido
                    end
                endcase
            end
        end
    end

    assign start_processing = start_pulse;
    assign reset_memories = reset_pulse;

    // ========================================================================
    // Lógica de lectura de memoria de salida y control de img_rd_addr_reg
    // ========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            img_rd_addr_reg <= 10'd0;
            mem_out_rd_en <= 1'b0;
            mem_out_rd_addr <= 10'd0;
            mem_out_rd_data_reg <= 8'd0;
            mem_out_rd_valid <= 1'b0;
        end else begin
            mem_out_rd_en <= 1'b0;
            mem_out_rd_valid <= 1'b0;

            // Escritura de IMG_RD_ADDR desde JTAG
            if (reg_write && reg_addr == ADDR_IMG_RD_ADDR) begin
                img_rd_addr_reg <= reg_write_data[9:0];
            end

            // Leer cuando se accede a IMG_RD_DATA
            if (reg_read && reg_addr == ADDR_IMG_RD_DATA) begin
                mem_out_rd_en <= 1'b1;
                mem_out_rd_addr <= img_rd_addr_reg;
            end

            // Capturar dato leído (1 ciclo de latencia)
            if (mem_out_rd_en) begin
                mem_out_rd_data_reg <= mem_out_rd_data;
                mem_out_rd_valid <= 1'b1;
                // Auto-incrementar dirección
                if (img_rd_addr_reg < 10'd1023) begin
                    img_rd_addr_reg <= img_rd_addr_reg + 10'd1;
                end
            end
        end
    end

    // ========================================================================
    // Lógica de lectura de registros
    // ========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_read_data <= 32'd0;
            reg_read_valid <= 1'b0;
        end else begin
            reg_read_valid <= reg_read;

            if (reg_read) begin
                case (reg_addr)
                    ADDR_CONTROL: begin
                        reg_read_data <= {24'd0, busy, 6'd0, reset_pulse, start_pulse};
                    end

                    ADDR_STATUS: begin
                        reg_read_data <= {21'd0, fsm_state, 6'd0, 1'b0, done};
                    end

                    ADDR_IMG_WR_ADDR: begin
                        reg_read_data <= {20'd0, img_wr_addr_reg};
                    end

                    ADDR_IMG_WR_DATA: begin
                        reg_read_data <= 32'd0;  // Write-only
                    end

                    ADDR_IMG_RD_ADDR: begin
                        reg_read_data <= {22'd0, img_rd_addr_reg};
                    end

                    ADDR_IMG_RD_DATA: begin
                        // Dato se actualiza en el siguiente ciclo
                        reg_read_data <= {24'd0, mem_out_rd_data_reg};
                    end

                    ADDR_PIXEL_COUNT: begin
                        reg_read_data <= {21'd0, pixels_written};
                    end

                    default: begin
                        reg_read_data <= 32'hDEADBEEF;  // Registro inválido
                    end
                endcase
            end
        end
    end

endmodule
