`timescale 1ns/1ps

// Top temporal para verificar que el proyecto compila
// Este archivo se reemplazará en Fase 6
module Top_Test_Phase1 (
    input  logic       clk_50,
    input  logic [3:0] key,
    input  logic [9:0] sw,
    output logic [9:0] led
);

    // Reset activo bajo (KEY[0])
    logic rst_n;
    assign rst_n = key[0];

    // Contador simple para verificar que funciona
    logic [31:0] counter;
    
    always_ff @(posedge clk_50 or negedge rst_n) begin
        if (!rst_n)
            counter <= 32'd0;
        else
            counter <= counter + 1;
    end

    // LEDs muestran bits del contador (parpadean)
    assign led = counter[27:18];

endmodule