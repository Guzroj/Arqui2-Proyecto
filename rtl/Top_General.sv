// =======================================================
// TOP GENERAL DEL PROYECTO — Basado en GuiaJtag
// Aqui se integran ambos modos: Secuencial y SIMD
// =======================================================
module Top_General #(
    parameter IMG_W = 512,
    parameter IMG_H = 512,
    parameter DST_W = 256,
    parameter DST_H = 256,
    parameter N     = 4
)(
    input  logic clk,
    input  logic rst,

    // Interfaz JTAG→Avalon-MM (desde connect.sv)
    input  logic        avsread,
    input  logic        avswrite,
    input  logic [7:0]  avsaddress,
    input  logic [31:0] avswritedata,
    output logic [31:0] avsreaddata
);

    // ---------------------------------------------------
    // Señales desde JTAG Interface
    // ---------------------------------------------------
    logic start, step;
    logic [31:0] xratio_reg, yratio_reg;
    logic [31:0] wr_addr_reg, wr_data_reg;
    logic [31:0] img_width_reg, img_height_reg;
    logic mode_reg;  // Aqui se selecciona el modo: 0=Secuencial, 1=SIMD

    logic [31:0] rd_data_reg;
    logic [31:0] perf_counter_reg;
    logic done_flag;

    // ====================================================
    // 1. Banco de Registros Accesible por JTAG
    // ====================================================
    JTAG_Interface jtag (
        .clk          (clk),
        .rst          (rst),

        // Señales de control
        .start        (start),
        .step         (step),
        .mode         (mode_reg),
        .paramxratio  (xratio_reg),
        .paramyratio  (yratio_reg),

        // Configuracion de dimensiones
        .imgwidth     (img_width_reg),
        .imgheight    (img_height_reg),

        // Escritura de datos a memoria
        .imgwriteaddr (wr_addr_reg),
        .imgwritedata (wr_data_reg),

        // Lectura de datos desde el sistema
        .imgreaddata  (rd_data_reg),
        .doneflag     (done_flag),
        .perfcounter  (perf_counter_reg),

        // Interfaz Avalon-MM (desde connect.sv)
        .avsread      (avsread),
        .avswrite     (avswrite),
        .avsaddress   (avsaddress),
        .avswritedata (avswritedata),
        .avsreaddata  (avsreaddata)
    );

    // ====================================================
    // 2. Top Downscale Secuencial
    // ====================================================
    logic done_seq;
    logic [7:0] dbg_seq;

    Top_Downscale_Secuencial #(
        .SRC_W(IMG_W),
        .SRC_H(IMG_H),
        .DST_W(DST_W),
        .DST_H(DST_H)
    ) u_top_seq (
        .clk      (clk),
        .rst      (rst),
        .cfg_we   (avswrite && !mode_reg),   // Escribe solo si modo secuencial
        .cfg_addr (wr_addr_reg[17:0]),
        .cfg_data (wr_data_reg[7:0]),
        .start_req(start && !mode_reg),      // Inicia solo si modo secuencial
        .done     (done_seq),
        .dbg_data (dbg_seq)
    );

    // ====================================================
    // 3. Top Downscale SIMD (Top_Downscale_Integration)
    // ====================================================
    logic done_simd;
    logic [7:0] image_out_simd [0:DST_H-1][0:DST_W-1];

    Top_Downscale_Integration #(
        .SRC_W(IMG_W),
        .SRC_H(IMG_H),
        .DST_W(DST_W),
        .DST_H(DST_H),
        .N    (N)
    ) u_top_simd (
        .clk      (clk),
        .rst      (rst),
        .start    (start && mode_reg),       // Inicia solo si modo SIMD
        .done     (done_simd),
        .wr_en    (avswrite && mode_reg),    // Escribe solo si modo SIMD
        .wr_addr  (wr_addr_reg[17:0]),
        .wr_data  (wr_data_reg[7:0]),
        .image_out(image_out_simd)
    );

    // ====================================================
    // 4. Multiplexado de señales de salida
    // ====================================================
    assign done_flag = mode_reg ? done_simd : done_seq;

    // Dato de debug: en modo secuencial usa dbg_seq, en SIMD el primer pixel de salida
    assign rd_data_reg = mode_reg ? {24'd0, image_out_simd[0][0]} : {24'd0, dbg_seq};

    // ====================================================
    // 5. Performance Counter
    // ====================================================
    logic [31:0] perf_counter;
    logic counting;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            perf_counter <= 32'd0;
            counting     <= 1'b0;
        end else begin
            if (start) begin
                perf_counter <= 32'd0;
                counting     <= 1'b1;
            end else if (done_flag) begin
                counting <= 1'b0;
            end else if (counting) begin
                perf_counter <= perf_counter + 1;
            end
        end
    end

    assign perf_counter_reg = perf_counter;

endmodule
