module SIMD_Registros #(
    parameter int N = 4
)(
    input  logic clk,
    input  logic rst,
    input  logic load,

    // Entradas SIMD (N lanes)
    input  logic [7:0] I00_in   [N],
    input  logic [7:0] I10_in   [N],
    input  logic [7:0] I01_in   [N],
    input  logic [7:0] I11_in   [N],
    input  logic [7:0] alpha_in [N],
    input  logic [7:0] beta_in  [N],

    // Salidas registradas
    output logic [7:0] I00_out  [N],
    output logic [7:0] I10_out  [N],
    output logic [7:0] I01_out  [N],
    output logic [7:0] I11_out  [N],
    output logic [7:0] alpha_out[N],
    output logic [7:0] beta_out [N]
);

    // Registros internos
    logic [7:0] I00_r   [N];
    logic [7:0] I10_r   [N];
    logic [7:0] I01_r   [N];
    logic [7:0] I11_r   [N];
    logic [7:0] alpha_r [N];
    logic [7:0] beta_r  [N];

    int i;

    // ============================================================
    // Registro: reset + carga con 'load'
    // ============================================================
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < N; i++) begin
                I00_r[i]   <= 8'd0;
                I10_r[i]   <= 8'd0;
                I01_r[i]   <= 8'd0;
                I11_r[i]   <= 8'd0;
                alpha_r[i] <= 8'd0;
                beta_r[i]  <= 8'd0;
            end
        end else if (load) begin
            for (i = 0; i < N; i++) begin
                I00_r[i]   <= I00_in[i];
                I10_r[i]   <= I10_in[i];
                I01_r[i]   <= I01_in[i];
                I11_r[i]   <= I11_in[i];
                alpha_r[i] <= alpha_in[i];
                beta_r[i]  <= beta_in[i];
            end
        end
    end

    // ============================================================
    // Asignación a salidas (simples wires)
    // ============================================================
    genvar g;
    generate
        for (g = 0; g < N; g++) begin : GEN_OUT
            assign I00_out[g]   = I00_r[g];
            assign I10_out[g]   = I10_r[g];
            assign I01_out[g]   = I01_r[g];
            assign I11_out[g]   = I11_r[g];
            assign alpha_out[g] = alpha_r[g];
            assign beta_out[g]  = beta_r[g];
        end
    endgenerate

endmodule
