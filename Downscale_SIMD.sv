// ================================================================
// Downscale_SIMD.sv
// Downscale por muestreo vecino más cercano (nearest-neighbour)
// con N lanes en paralelo
// ================================================================

module Downscale_SIMD #(
    parameter int SRC_H = 32,
    parameter int SRC_W = 32,
    parameter int DST_H = 16,
    parameter int DST_W = 16,
    parameter int N     = 4
)(
    input  logic clk,
    input  logic rst,
    input  logic start,

    // Interfaz de lectura SIMD hacia ImageMemory_SIMDPort
    output logic        mem_rd_req   [N],
    output logic [$clog2(SRC_H*SRC_W)-1:0] mem_rd_addr  [N],
    input  logic        mem_rd_valid [N],        // no lo usamos estrictamente, pero se mantiene
    input  logic [7:0]  mem_rd_data  [N],

    output logic        done,
    output logic [7:0]  image_out [0:DST_H-1][0:DST_W-1]
);

    // ------------------------------------------------------------
    // FSM
    // ------------------------------------------------------------
    typedef enum logic [1:0] {
        S_IDLE,
        S_READ,
        S_WRITE
    } state_t;

    state_t state, next_state;

    // Índices destino
    int r;       // fila destino
    int c;       // columna destino (inicio del bloque SIMD)

    // Buffer para los N píxeles leídos
    logic [7:0] pixel_buf [N];

    // ------------------------------------------------------------
    // Registro de estado
    // ------------------------------------------------------------
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= S_IDLE;
        end else begin
            state <= next_state;
        end
    end

    // ------------------------------------------------------------
    // Lógica combinacional de cambios de estado
    // ------------------------------------------------------------
    always_comb begin
        next_state = state;

        case (state)
            S_IDLE: begin
                if (start)
                    next_state = S_READ;
            end

            S_READ: begin
                // Después de pedir lectura, en el siguiente ciclo escribimos
                next_state = S_WRITE;
            end

            S_WRITE: begin
                // Seguimos leyendo hasta completar toda la imagen destino
                if (r == (DST_H-1) && (c + N) >= DST_W)
                    next_state = S_IDLE;   // último bloque, regresamos a IDLE
                else
                    next_state = S_READ;
            end

            default: next_state = S_IDLE;
        endcase
    end

    // ------------------------------------------------------------
    // Datapath: control de r, c, acceso a memoria y escritura
    // ------------------------------------------------------------
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            r   <= 0;
            c   <= 0;
            done <= 1'b0;

            for (int i = 0; i < N; i++) begin
                mem_rd_req[i]  <= 1'b0;
                mem_rd_addr[i] <= '0;
                pixel_buf[i]   <= 8'd0;
            end

        end else begin
            done <= 1'b0;  // por defecto: done es pulso de 1 ciclo

            case (state)

                // ------------------------------------------------
                // S_IDLE: esperamos start, limpiamos cosas
                // ------------------------------------------------
                S_IDLE: begin
                    r <= 0;
                    c <= 0;
                    for (int i = 0; i < N; i++) begin
                        mem_rd_req[i] <= 1'b0;
                    end
                end

                // ------------------------------------------------
                // S_READ: calculamos posiciones fuente y hacemos
                //         petición de lectura a la memoria
                // ------------------------------------------------
                S_READ: begin
                    for (int i = 0; i < N; i++) begin
                        int pix_dst = c + i;
                        if (pix_dst < DST_W) begin
                            // Coordenadas destino
                            int Xd = pix_dst;
                            int Yd = r;

                            // Escalamos a coordenadas fuente (nearest-neighbour)
                            int Xs = (Xd * SRC_W) / DST_W;
                            int Ys = (Yd * SRC_H) / DST_H;

                            // Clamp por seguridad
                            if (Xs >= SRC_W) Xs = SRC_W - 1;
                            if (Ys >= SRC_H) Ys = SRC_H - 1;

                            mem_rd_req[i]  <= 1'b1;
                            mem_rd_addr[i] <= Ys * SRC_W + Xs;
                        end else begin
                            // Fuera del rango de la fila destino
                            mem_rd_req[i]  <= 1'b0;
                            mem_rd_addr[i] <= '0;
                        end
                    end
                end

                // ------------------------------------------------
                // S_WRITE: usamos lo leído en el ciclo anterior
                //          y lo copiamos a image_out
                // ------------------------------------------------
                S_WRITE: begin
                    // Bajamos las peticiones de lectura
                    for (int i = 0; i < N; i++) begin
                        mem_rd_req[i] <= 1'b0;
                    end

                    // Guardamos lo que llegó de la memoria en el buffer
                    for (int i = 0; i < N; i++) begin
                        pixel_buf[i] <= mem_rd_data[i];
                    end

                    // Escribimos en la imagen destino
                    for (int i = 0; i < N; i++) begin
                        int pix_dst = c + i;
                        if (pix_dst < DST_W) begin
                            image_out[r][pix_dst] <= mem_rd_data[i];
                        end
                    end

                    // Actualizamos r, c y done
                    if (c + N >= DST_W) begin
                        c <= 0;
                        if (r + 1 < DST_H) begin
                            r <= r + 1;
                        end else begin
                            // Fin de la última fila
                            r    <= 0;
                            c    <= 0;
                            done <= 1'b1;  // pulso al terminar todo el frame
                        end
                    end else begin
                        c <= c + N;
                    end
                end

                default: begin
                    // Nada especial
                end

            endcase
        end
    end

endmodule
