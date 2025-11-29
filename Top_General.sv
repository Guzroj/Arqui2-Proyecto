// =======================================================
// TOP GENERAL DEL PROYECTO — Basado en GuiaJtag
// Aqui se integran ambos modos: Secuencial y SIMD
// Compatible con Quartus 20.1
// =======================================================
module Top_General #(
    // Tamaño MAXIMO de imagen (para asignacion de memoria)
    // Reducido a 128x128 para pruebas
    parameter int MAX_IMGW = 128,
    parameter int MAX_IMGH = 128,
    parameter int N        = 4
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
    logic mode_reg;  // Aqui se selecciona el modo: 0=Secuencial, 1=SIMD

    // Dimensiones de imagen configurables via JTAG
    logic [31:0] img_width_reg;
    logic [31:0] img_height_reg;

    logic [31:0] rd_data_reg;
    logic [31:0] perf_counter;
    logic done_flag;
    
    // Señales para control de escritura a memoria (32 bits para soportar imagenes grandes)
    logic [31:0] img_addr;
    logic [7:0]  img_data;

    // ====================================================
    // 1. Banco de Registros Accesible por JTAG
    // ====================================================
    JTAG_Interface jtag (
        .clk(clk),
        .rst(rst),

        .start(start),
        .step(step),
        .mode(mode_reg),
        .paramxratio(xratio_reg),
        .paramyratio(yratio_reg),

        .imgwidth(img_width_reg),
        .imgheight(img_height_reg),

        .imgwriteaddr(wr_addr_reg),
        .imgwritedata(wr_data_reg),

        .imgreaddata(rd_data_reg),
        .doneflag(done_flag),
        .perfcounter(perf_counter),

        .avsread(avsread),
        .avswrite(avswrite),
        .avsaddress(avsaddress),
        .avswritedata(avswritedata),
        .avsreaddata(avsreaddata)
    );

    // ====================================================
    // 2. Detección de escritura a memoria de imagen
    //    Se detecta cuando se escribe a la direccion 0x04 (WRITEDATA)
    // ====================================================
    logic prev_avswrite;
    logic write_to_imgdata;
    
    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            prev_avswrite <= 1'b0;
        else
            prev_avswrite <= avswrite;
    end
    
    // Pulso cuando se escribe en el registro de datos de imagen
    assign write_to_imgdata = avswrite && !prev_avswrite && (avsaddress == 8'h04);
    
    // Direccion y dato para la memoria (32 bits)
    assign img_addr = wr_addr_reg;
    assign img_data = wr_data_reg[7:0];

    // ====================================================
    // 3. Top Downscale Secuencial
    //    Usa tamaño MAXIMO para asignacion de memoria
    //    El tamaño real se puede configurar via registros
    // ====================================================
    logic done_seq;
    logic [7:0] dbg_seq;

    Top_Downscale_Secuencial #(
        .SRC_W(MAX_IMGW),
        .SRC_H(MAX_IMGH),
        .DST_W(MAX_IMGW/2),
        .DST_H(MAX_IMGH/2)
    ) u_top_seq (
        .clk      (clk),
        .rst      (rst),
        .cfg_we   (write_to_imgdata && !mode_reg),
        .cfg_addr (img_addr),
        .cfg_data (img_data),
        .start_req(start && !mode_reg),
        .done     (done_seq),
        .dbg_data (dbg_seq)
    );

    // ====================================================
    // 4. Top Downscale SIMD
    //    Usa tamaño MAXIMO para asignacion de memoria
    //    El tamaño real se puede configurar via registros
    // ====================================================
    logic done_simd;
    logic [7:0] dbg_simd;

    Top_Downscale_SIMD #(
        .SRC_W(MAX_IMGW),
        .SRC_H(MAX_IMGH),
        .DST_W(MAX_IMGW/2),
        .DST_H(MAX_IMGH/2),
        .N(N)
    ) u_top_simd (
        .clk      (clk),
        .rst      (rst),
        .cfg_we   (write_to_imgdata && mode_reg),
        .cfg_addr (img_addr),
        .cfg_data (img_data),
        .start_req(start && mode_reg),
        .done     (done_simd),
        .dbg_data (dbg_simd)
    );

    // ====================================================
    // 5. Multiplexado de señales de salida
    // ====================================================
    assign done_flag = mode_reg ? done_simd : done_seq;

    // Aqui se multiplexa el dato de debug segun el modo
    assign rd_data_reg = {24'd0, (mode_reg ? dbg_simd : dbg_seq)};

    // ====================================================
    // 6. Performance Counter
    // ====================================================
    logic counting;
    
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            perf_counter <= 32'd0;
            counting <= 1'b0;
        end else begin
            if (start && !counting) begin
                perf_counter <= 32'd0;
                counting <= 1'b1;
            end else if (done_flag && counting) begin
                counting <= 1'b0;
            end else if (counting) begin
                perf_counter <= perf_counter + 32'd1;
            end
        end
    end

endmodule
