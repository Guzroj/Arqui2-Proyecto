module ModoSIMD #(
    parameter int N = 4
)(
    input  logic clk,
    input  logic rst,
    input  logic valid_in,

    input  logic [7:0] I00_vec  [N],
    input  logic [7:0] I10_vec  [N],
    input  logic [7:0] I01_vec  [N],
    input  logic [7:0] I11_vec  [N],
    input  logic [7:0] alpha_vec[N],
    input  logic [7:0] beta_vec [N],

    output logic valid_out,
    output logic [7:0] pixel_out_vec[N]
);

    // *** IMPORTANTE: ahora es VECTOR, NO ARRAY ***
    logic [N-1:0] lane_valid;
    logic [7:0]   lane_pixel [N];

    logic all_valid;

    genvar i;
    generate
        for (i = 0; i < N; i++) begin : SIMD_CORES
            ModoSecuencial core (
                .clk(clk),
                .rst(rst),
                .valid_in(valid_in),
                .I00(I00_vec[i]),
                .I10(I10_vec[i]),
                .I01(I01_vec[i]),
                .I11(I11_vec[i]),
                .alpha(alpha_vec[i]),
                .beta(beta_vec[i]),
                .valid_out(lane_valid[i]),
                .pixel_out(lane_pixel[i])
            );
        end
    endgenerate

    // Ahora sí: reducción válida
    assign all_valid = &lane_valid;

    // Registro de salida
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            valid_out <= 1'b0;
            for (int k = 0; k < N; k++)
                pixel_out_vec[k] <= 8'd0;

        end else begin
            valid_out <= all_valid;

            if (all_valid) begin
                for (int k = 0; k < N; k++)
                    pixel_out_vec[k] <= lane_pixel[k];
            end
        end
    end

endmodule
