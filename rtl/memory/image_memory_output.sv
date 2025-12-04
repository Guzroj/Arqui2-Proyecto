// ============================================================================
// image_memory_output.sv
// Dual-port RAM parametrizable para almacenar imagen de salida
// FASE 4: Módulos de Memoria
// ============================================================================
//
// Características:
// - Dual-port RAM (lectura/escritura independientes)
// - Ancho de datos parametrizable (por defecto 8 bits para Q8.8)
// - Dimensiones parametrizables (por defecto 32×32 = 1024 píxeles)
// - Inferencia de BRAM para usar bloques M10K de Cyclone V
// - Puerto A: Escritura (desde downscaler)
// - Puerto B: Lectura (hacia JTAG o memoria externa)
//
// ============================================================================

module image_memory_output #(
    parameter WIDTH       = 32,              // Ancho de la imagen (píxeles)
    parameter HEIGHT      = 32,              // Alto de la imagen (píxeles)
    parameter DATA_WIDTH  = 8,               // Bits por píxel (8 bits para grayscale)
    parameter ADDR_WIDTH  = $clog2(WIDTH * HEIGHT)  // Bits de dirección
) (
    // Clock y Reset
    input  logic                    clk,
    input  logic                    rst_n,

    // Puerto A: Escritura (Write Port)
    input  logic                    wr_en_a,
    input  logic [ADDR_WIDTH-1:0]   wr_addr_a,
    input  logic [DATA_WIDTH-1:0]   wr_data_a,

    // Puerto B: Lectura (Read Port)
    input  logic                    rd_en_b,
    input  logic [ADDR_WIDTH-1:0]   rd_addr_b,
    output logic [DATA_WIDTH-1:0]   rd_data_b,

    // Señales de control adicionales
    output logic [ADDR_WIDTH:0]     pixels_written  // Contador de píxeles escritos
);

    // ========================================================================
    // Memoria interna (inferencia de BRAM)
    // ========================================================================
    // Para que Quartus infiera BRAM (M10K), es importante:
    // 1. Usar un array de registros
    // 2. Sincronizar las operaciones con el reloj
    // 3. Usar bloques always_ff separados para lectura/escritura
    // ========================================================================

    localparam MEM_DEPTH = WIDTH * HEIGHT;

    (* ramstyle = "M10K" *) logic [DATA_WIDTH-1:0] mem [0:MEM_DEPTH-1];

    // ========================================================================
    // Contador de píxeles escritos (útil para saber cuándo está completa)
    // ========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pixels_written <= '0;
        end
        else begin
            if (wr_en_a) begin
                // Incrementar solo si escribimos en una dirección nueva
                if (pixels_written < MEM_DEPTH) begin
                    pixels_written <= pixels_written + 1;
                end
            end
        end
    end

    // ========================================================================
    // Puerto A: Escritura (Write Port)
    // ========================================================================
    // Escritura sincrónica con enable
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // No es necesario inicializar la memoria en hardware
            // (demasiado costoso en términos de recursos)
        end
        else begin
            if (wr_en_a) begin
                mem[wr_addr_a] <= wr_data_a;
            end
        end
    end

    // ========================================================================
    // Puerto B: Lectura (Read Port)
    // ========================================================================
    // Lectura sincrónica con enable (patrón de BRAM)
    // La salida se registra para mejor timing
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_data_b <= '0;
        end
        else begin
            if (rd_en_b) begin
                rd_data_b <= mem[rd_addr_b];
            end
        end
    end

    // ========================================================================
    // Funciones de utilidad para conversión de coordenadas
    // ========================================================================
    // Estas funciones son para debugging/testbench, no sintetizan

    function automatic logic [ADDR_WIDTH-1:0] xy_to_addr;
        input integer x;
        input integer y;
        begin
            xy_to_addr = y * WIDTH + x;
        end
    endfunction

    function automatic void addr_to_xy;
        input  logic [ADDR_WIDTH-1:0] addr;
        output integer x;
        output integer y;
        begin
            y = addr / WIDTH;
            x = addr % WIDTH;
        end
    endfunction

    // ========================================================================
    // Assertions para verificación (solo en simulación)
    // ========================================================================
    `ifdef SIMULATION
        // Verificar que no escribamos fuera de rango
        always @(posedge clk) begin
            if (wr_en_a && wr_addr_a >= MEM_DEPTH) begin
                $error("Write address out of range: %0d >= %0d", wr_addr_a, MEM_DEPTH);
            end
        end

        // Verificar que no leamos fuera de rango
        always @(posedge clk) begin
            if (rd_en_b && rd_addr_b >= MEM_DEPTH) begin
                $error("Read address out of range: %0d >= %0d", rd_addr_b, MEM_DEPTH);
            end
        end
    `endif

endmodule
