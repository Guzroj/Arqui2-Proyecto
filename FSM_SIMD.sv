`timescale 1ns/1ps

module FSM_SIMD (
    input  logic clk,
    input  logic rst,

    input  logic start,       // pulso o nivel desde el top
    input  logic simd_valid,  // viene de ModoSIMD cuando el batch está listo

    output logic load_regs,   // 1 ciclo: carga registros SIMD
    output logic run_simd,    // 1 ciclo: dispara cálculo SIMD
    output logic write_back,  // 1 ciclo: escribir resultados
    output logic done         // 1 ciclo: batch terminado
);

    typedef enum logic [2:0] {
        S_IDLE,
        S_LOAD,
        S_RUN,
        S_WAIT,
        S_WRITE
    } state_t;

    state_t state, next;

    // Registro de estado
    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            state <= S_IDLE;
        else
            state <= next;
    end

    // Lógica combinacional de la FSM
    always_comb begin
        // Valores por defecto
        load_regs  = 1'b0;
        run_simd   = 1'b0;
        write_back = 1'b0;
        done       = 1'b0;
        next       = state;

        case (state)

            S_IDLE: begin
                if (start)
                    next = S_LOAD;
            end

            S_LOAD: begin
                // Un ciclo para capturar los datos en los registros
                load_regs = 1'b1;
                next      = S_RUN;
            end

            S_RUN: begin
                // Un ciclo de valid_in hacia ModoSIMD
                run_simd = 1'b1;
                next     = S_WAIT;
            end

            S_WAIT: begin
                // Esperamos a que ModoSIMD diga que terminó el batch
                if (simd_valid)
                    next = S_WRITE;
            end

            S_WRITE: begin
                write_back = 1'b1;
                done       = 1'b1; // pulso de 1 ciclo
                next       = S_IDLE;
            end

            default: next = S_IDLE;

        endcase
    end

endmodule
