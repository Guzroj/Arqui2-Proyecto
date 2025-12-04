// ============================================================================
// downscale_fsm.sv
// Máquina de estados para control del downscaling secuencial
// Procesa 1 píxel de salida por iteración (32x32 = 1024 píxeles)
// Arquitectura de Computadores 2 - FASE 5
// ============================================================================

module downscale_fsm (
    input  logic        clk,
    input  logic        rst_n,

    // Control
    input  logic        start,          // Iniciar downscaling
    output logic        busy,           // FSM ocupada
    output logic        done,           // Downscaling completado

    // Control de interpolador
    output logic        interp_start,   // Iniciar interpolación
    input  logic        interp_valid,   // Resultado válido

    // Control de memoria de entrada (lectura)
    output logic        mem_in_rd_en,
    output logic [11:0] mem_in_rd_addr,

    // Control de memoria de salida (escritura)
    output logic        mem_out_wr_en,
    output logic [9:0]  mem_out_wr_addr,

    // Coordenadas del píxel de salida actual
    output logic [4:0]  out_x,          // 0-31
    output logic [4:0]  out_y           // 0-31
);

    // ========================================================================
    // Parámetros
    // ========================================================================

    localparam IN_WIDTH  = 64;
    localparam OUT_WIDTH = 32;

    // Estados simplificados
    typedef enum logic [2:0] {
        IDLE,
        READ_P00,         // Leer píxel (0,0)
        READ_P01,         // Leer píxel (0,1)
        READ_P10,         // Leer píxel (1,0)
        READ_P11,         // Leer píxel (1,1)
        INTERPOLATE,      // Ejecutar interpolación
        WRITE_RESULT      // Escribir resultado
    } state_t;

    state_t state, next_state;

    // ========================================================================
    // Señales internas
    // ========================================================================

    logic [4:0]  out_x_reg, out_y_reg;
    logic [9:0]  pixel_count;          // Contador 0-1023
    logic [2:0]  wait_counter;         // Contador para esperar pipeline

    // Coordenadas enteras de píxeles vecinos
    logic [5:0]  x0, x1;               // 0-63
    logic [5:0]  y0, y1;               // 0-63

    // Direcciones de memoria calculadas
    logic [11:0] addr_00, addr_01, addr_10, addr_11;

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
                if (start) begin
                    next_state = READ_P00;
                end
            end

            READ_P00: begin
                next_state = READ_P01;
            end

            READ_P01: begin
                next_state = READ_P10;
            end

            READ_P10: begin
                next_state = READ_P11;
            end

            READ_P11: begin
                next_state = INTERPOLATE;
            end

            INTERPOLATE: begin
                // Esperar ~8 ciclos para que el pipeline complete
                if (wait_counter >= 3'd7) begin
                    next_state = WRITE_RESULT;
                end
            end

            WRITE_RESULT: begin
                // Verificar si terminamos todos los píxeles
                if (pixel_count == 10'd1023) begin
                    next_state = IDLE;  // Terminado
                end else begin
                    next_state = READ_P00;  // Siguiente píxel
                end
            end

            default: next_state = IDLE;
        endcase
    end

    // ========================================================================
    // Señales de salida
    // ========================================================================

    assign busy = (state != IDLE);
    assign done = (state == WRITE_RESULT) && (pixel_count == 10'd1023);

    assign interp_start = (state == INTERPOLATE) && (wait_counter == 3'd0);
    assign mem_out_wr_en = (state == WRITE_RESULT);

    assign out_x = out_x_reg;
    assign out_y = out_y_reg;
    assign mem_out_wr_addr = {out_y_reg, 5'd0} + {5'd0, out_x_reg};

    // ========================================================================
    // Contador de espera para pipeline
    // ========================================================================

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wait_counter <= 3'd0;
        end else begin
            if (state == INTERPOLATE) begin
                if (wait_counter < 3'd7) begin
                    wait_counter <= wait_counter + 3'd1;
                end
            end else begin
                wait_counter <= 3'd0;
            end
        end
    end

    // ========================================================================
    // Contador de píxeles y coordenadas de salida
    // ========================================================================

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pixel_count <= 10'd0;
            out_x_reg   <= 5'd0;
            out_y_reg   <= 5'd0;
        end else begin
            if (state == IDLE && start) begin
                pixel_count <= 10'd0;
                out_x_reg   <= 5'd0;
                out_y_reg   <= 5'd0;
            end else if (state == WRITE_RESULT && next_state == READ_P00) begin
                // Solo incrementar si vamos a procesar otro píxel
                pixel_count <= pixel_count + 10'd1;

                // Incrementar coordenadas (recorrer row-major)
                if (out_x_reg == 5'd31) begin
                    out_x_reg <= 5'd0;
                    out_y_reg <= out_y_reg + 5'd1;
                end else begin
                    out_x_reg <= out_x_reg + 5'd1;
                end
            end
        end
    end

    // ========================================================================
    // Cálculo de coordenadas en imagen de entrada
    // ========================================================================
    // Mapeo: out(x,y) → in(x*2, y*2)
    // x0 = out_x * 2
    // x1 = out_x * 2 + 1
    // y0 = out_y * 2
    // y1 = out_y * 2 + 1

    always_comb begin
        x0 = {out_x_reg, 1'b0};           // x*2
        x1 = {out_x_reg, 1'b0} + 6'd1;    // x*2 + 1
        y0 = {out_y_reg, 1'b0};           // y*2
        y1 = {out_y_reg, 1'b0} + 6'd1;    // y*2 + 1

        // Saturación en los bordes
        if (x1 >= 6'd64) x1 = 6'd63;
        if (y1 >= 6'd64) y1 = 6'd63;
    end

    // ========================================================================
    // Cálculo de direcciones de memoria
    // ========================================================================
    // Dirección = y * 64 + x

    always_comb begin
        addr_00 = {y0, 6'd0} + {6'd0, x0};  // y0*64 + x0
        addr_01 = {y0, 6'd0} + {6'd0, x1};  // y0*64 + x1
        addr_10 = {y1, 6'd0} + {6'd0, x0};  // y1*64 + x0
        addr_11 = {y1, 6'd0} + {6'd0, x1};  // y1*64 + x1
    end

    // ========================================================================
    // Control de lectura de memoria
    // ========================================================================

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_in_rd_en <= 1'b0;
            mem_in_rd_addr <= 12'd0;
        end else begin
            case (state)
                READ_P00: begin
                    mem_in_rd_en <= 1'b1;
                    mem_in_rd_addr <= addr_00;
                end
                READ_P01: begin
                    mem_in_rd_en <= 1'b1;
                    mem_in_rd_addr <= addr_01;
                end
                READ_P10: begin
                    mem_in_rd_en <= 1'b1;
                    mem_in_rd_addr <= addr_10;
                end
                READ_P11: begin
                    mem_in_rd_en <= 1'b1;
                    mem_in_rd_addr <= addr_11;
                end
                default: begin
                    mem_in_rd_en <= 1'b0;
                end
            endcase
        end
    end

endmodule
