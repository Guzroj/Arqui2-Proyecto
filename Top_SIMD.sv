`timescale 1ns/1ps

module Top_SIMD #(
    parameter int N = 4
)(
    input  logic         clk,
    input  logic         rst,
    input  logic         start,

    // Entradas de datos (N píxeles por batch)
    input  logic [7:0]   I00_vec [N],
    input  logic [7:0]   I10_vec [N],
    input  logic [7:0]   I01_vec [N],
    input  logic [7:0]   I11_vec [N],
    input  logic [7:0]   alpha_vec [N],
    input  logic [7:0]   beta_vec  [N],

    // Salidas
    output logic         done,
    output logic [7:0]   pixel_out_vec [N]
);

    // Señales internas FSM
    logic load_regs;
    logic run_simd;
    logic write_back;
    logic simd_valid;

    // Señales entre registros y SIMD
    logic [7:0] I00_reg [N];
    logic [7:0] I10_reg [N];
    logic [7:0] I01_reg [N];
    logic [7:0] I11_reg [N];
    logic [7:0] alpha_reg [N];
    logic [7:0] beta_reg  [N];

    // ===========================
    // FSM de control
    // ===========================
    FSM_SIMD fsm_inst (
        .clk        (clk),
        .rst        (rst),
        .start      (start),
        .simd_valid (simd_valid),
        .load_regs  (load_regs),
        .run_simd   (run_simd),
        .write_back (write_back),
        .done       (done)
    );

    // ===========================
    // Registros SIMD
    // ===========================
		SIMD_Registros #(.N(N)) regs_inst (
			 .clk(clk),
			 .rst(rst),
			 .load(load_regs),

			 .I00_in(I00_vec),
			 .I10_in(I10_vec),
			 .I01_in(I01_vec),
			 .I11_in(I11_vec),
			 .alpha_in(alpha_vec),
			 .beta_in(beta_vec),

			 .I00_out(I00_regs),
			 .I10_out(I10_regs),
			 .I01_out(I01_regs),
			 .I11_out(I11_regs),
			 .alpha_out(alpha_regs),
			 .beta_out(beta_regs)
		);



    // ===========================
    // Bloque SIMD (N píxeles/ciclo)
    // ===========================
		ModoSIMD #(.N(N)) simd_inst (
			 .clk(clk),
			 .rst(rst),
			 .valid_in(run_simd),

			 .I00_vec(I00_regs),     // ← AQUÍ SE ARREGLA TODO
			 .I10_vec(I10_regs),
			 .I01_vec(I01_regs),
			 .I11_vec(I11_regs),
			 .alpha_vec(alpha_regs),
			 .beta_vec(beta_regs),

			 .valid_out(simd_valid),
			 .pixel_out_vec(pixel_out_vec)
		);


    // Por ahora no usamos write_back internamente,
    // pero queda por si luego querés que los registros
    // hagan algo especial en esa etapa.
endmodule
