`timescale 1ns/1ps

module ModoSecuencial (
    input  logic       clk,
    input  logic       rst,
    input  logic       valid_in,
    input  logic [7:0] I00, I10, I01, I11,  // Píxeles vecinos [0-255]
    input  logic [7:0] alpha, beta,         // Pesos Q0.8 [0-255]
    output logic       valid_out,
    output logic [7:0] pixel_out
);

    // ===============================================
    // Fórmula bilinear:
    // result = I00*(1-α)*(1-β) + I10*α*(1-β) + I01*(1-α)*β + I11*α*β
    // ===============================================

    // Calcular complementos (1 - alpha) y (1 - beta) en Q0.8
    logic [8:0] one_minus_alpha;  // 9 bits para 256
    logic [8:0] one_minus_beta;

    always_comb begin
        one_minus_alpha = 9'd256 - {1'b0, alpha};
        one_minus_beta  = 9'd256 - {1'b0, beta};
    end

    // ===============================================
    // Calcular 4 términos
    // Cada término: pixel * coef1 * coef2
    // Resultado en Q0.16 (necesitamos >> 16 al final)
    // ===============================================
    
    logic [31:0] term1, term2, term3, term4;
    
    always_comb begin
        // term1 = I00 * (1-α) * (1-β)
        // I00 es uint8, (1-α) y (1-β) son uint9
        // Producto: 8 * 9 * 9 = necesita 26 bits, usamos 32 para seguridad
        term1 = 32'(I00) * 32'(one_minus_alpha[7:0]) * 32'(one_minus_beta[7:0]);
        
        // term2 = I10 * α * (1-β)
        term2 = 32'(I10) * 32'(alpha) * 32'(one_minus_beta[7:0]);
        
        // term3 = I01 * (1-α) * β
        term3 = 32'(I01) * 32'(one_minus_alpha[7:0]) * 32'(beta);
        
        // term4 = I11 * α * β
        term4 = 32'(I11) * 32'(alpha) * 32'(beta);
    end

    // ===============================================
    // Sumar los 4 términos
    // ===============================================
    
    logic [33:0] sum;  // 34 bits para evitar overflow en suma
    
    always_comb begin
        sum = 34'(term1) + 34'(term2) + 34'(term3) + 34'(term4);
    end

    // ===============================================
    // Convertir Q0.16 → uint8 con redondeo
    // Dividir por 65536 (shift >> 16) con redondeo
    // ===============================================
    
    logic [33:0] sum_rounded;
    logic [17:0] result_shifted;
    logic [7:0]  result_clamped;
    
    always_comb begin
        // Redondeo: sumar 0.5 antes de truncar
        // En Q0.16, 0.5 = 32768 (0x8000)
        sum_rounded = sum + 34'd32768;
        
        // Shift de 16 bits a la derecha
        result_shifted = sum_rounded[33:16];
        
        // Saturar a rango [0, 255]
        if (result_shifted > 18'd255)
            result_clamped = 8'd255;
        else
            result_clamped = result_shifted[7:0];
    end

    // ===============================================
    // Registro de salida (pipeline de 1 ciclo)
    // ===============================================
    
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            valid_out <= 1'b0;
            pixel_out <= 8'd0;
        end else begin
            valid_out <= valid_in;
            if (valid_in) begin
                pixel_out <= result_clamped;
            end
        end
    end

endmodule