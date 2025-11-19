module FSM_SIMD #(
    parameter int N = 4,              // tamaño vector SIMD
    parameter int OUT_W = 3,          // ancho de imagen salida
    parameter int OUT_H = 3           // alto de imagen salida
)(
    input  logic clk,
    input  logic rst,

    input  logic start,
    input  logic simd_valid,          // viene de ModoSIMD

    output logic load_regs,
    output logic run_simd,
    output logic write_back,
    output logic done
);

    // --------------------------------------------
    // Cantidad total de píxeles y batches SIMD
    // --------------------------------------------
    localparam int TOTAL_PIXELS = OUT_W * OUT_H;
    localparam int NUM_BATCHES  = (TOTAL_PIXELS + N - 1) / N;

    // --------------------------------------------
    // Contador de batches
    // --------------------------------------------
    logic [$clog2(NUM_BATCHES)-1:0] batch_cnt;

    // --------------------------------------------
    // Definición de estados
    // --------------------------------------------
    typedef enum logic [2:0] {
        S_IDLE,
        S_LOAD,
        S_RUN,
        S_WAIT,
        S_WRITE,
        S_NEXT,
        S_DONE
    } state_t;

    state_t state, next;

    // --------------------------------------------
    // Registro de estado
    // --------------------------------------------
    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            state <= S_IDLE;
        else
            state <= next;
    end

    // --------------------------------------------
    // Contador de batches
    // --------------------------------------------
    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            batch_cnt <= 0;
        else if (state == S_NEXT)
            batch_cnt <= batch_cnt + 1;
    end

    // --------------------------------------------
    // Lógica combinacional de estados / señales
    // --------------------------------------------
    always_comb begin
        load_regs  = 0;
        run_simd   = 0;
        write_back = 0;
        done       = 0;

        next = state;

        case (state)

            S_IDLE: begin
                if (start)
                    next = S_LOAD;
            end

            S_LOAD: begin
                load_regs = 1;
                next = S_RUN;
            end

            S_RUN: begin
                run_simd = 1;
                next = S_WAIT;
            end

            S_WAIT: begin
                if (simd_valid)
                    next = S_WRITE;
            end

            S_WRITE: begin
                write_back = 1;
                next = S_NEXT;
            end

            S_NEXT: begin
                if (batch_cnt == NUM_BATCHES - 1)
                    next = S_DONE;
                else
                    next = S_LOAD;
            end

            S_DONE: begin
                done = 1;
            end

        endcase
    end

endmodule
