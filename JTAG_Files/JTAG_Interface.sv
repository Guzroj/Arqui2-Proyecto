// ======================================================
// JTAG_Interface.sv
// Interfaz JTAG usando Avalon-MM para comunicacion FPGA-PC
// Basado en: https://github.com/Abner2111/GuiaJtag
// Compatible con Quartus 20.1
// ======================================================

module JTAG_Interface (
    input  logic        clk,
    input  logic        rst,

    // Señales de control hacia el sistema (Top_General)
    output logic        start,
    output logic        step,
    output logic        mode,          // 0 Secuencial, 1 SIMD
    output logic [31:0] paramxratio,
    output logic [31:0] paramyratio,

    // Configuracion de dimensiones de imagen
    output logic [31:0] imgwidth,      // Ancho de imagen actual
    output logic [31:0] imgheight,     // Alto de imagen actual

    // Escritura de datos a la memoria de imagen
    output logic [31:0] imgwriteaddr,
    output logic [31:0] imgwritedata,

    // Lectura de datos desde el sistema (Top_General)
    input  logic [31:0] imgreaddata,
    input  logic        doneflag,
    input  logic [31:0] perfcounter,

    // Interfaz Avalon-MM JTAG (desde connect.sv)
    input  logic        avsread,
    input  logic        avswrite,
    input  logic [7:0]  avsaddress,
    input  logic [31:0] avswritedata,
    output logic [31:0] avsreaddata
);

    // ====================================================
    // Mapa de registros
    // ====================================================
    // 0x00: regcontrol   bit 0 start, bit 1 step, bit 2 mode
    // 0x01: regxratio
    // 0x02: regyratio
    // 0x03: regwriteaddr
    // 0x04: regwritedata
    // 0x05: imgreaddata   (read-only, viene de Top_General)
    // 0x06: {31:1=0, 0=doneflag} (read-only)
    // 0x07: perfcounter   (read-only)
    // 0x08: imgwidth      (ancho de imagen)
    // 0x09: imgheight     (alto de imagen)

    // Registros internos
    logic [31:0] regcontrol;
    logic [31:0] regxratio;
    logic [31:0] regyratio;
    logic [31:0] regwriteaddr;
    logic [31:0] regwritedata;
    logic [31:0] regimgwidth;
    logic [31:0] regimgheight;

    // ====================================================
    // Escritura de registros
    // ====================================================
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            regcontrol   <= 32'h00000000;
            regxratio    <= 32'h00000000;
            regyratio    <= 32'h00000000;
            regwriteaddr <= 32'h00000000;
            regwritedata <= 32'h00000000;
            regimgwidth  <= 32'd64;        // Valor por defecto 64
            regimgheight <= 32'd64;        // Valor por defecto 64
        end else if (avswrite) begin
            case (avsaddress)
                8'h00: regcontrol   <= avswritedata;
                8'h01: regxratio    <= avswritedata;
                8'h02: regyratio    <= avswritedata;
                8'h03: regwriteaddr <= avswritedata;
                8'h04: regwritedata <= avswritedata;
                8'h08: regimgwidth  <= avswritedata;
                8'h09: regimgheight <= avswritedata;
                default: ; // registros de solo lectura no se escriben
            endcase
        end
    end

    // ====================================================
    // Lectura de registros
    // ====================================================
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            avsreaddata <= 32'h00000000;
        end else if (avsread) begin
            case (avsaddress)
                8'h00: avsreaddata <= regcontrol;
                8'h01: avsreaddata <= regxratio;
                8'h02: avsreaddata <= regyratio;
                8'h03: avsreaddata <= regwriteaddr;
                8'h04: avsreaddata <= regwritedata;
                8'h05: avsreaddata <= imgreaddata;               // dato de imagen/debug
                8'h06: avsreaddata <= {31'b0, doneflag};         // estado global
                8'h07: avsreaddata <= perfcounter;               // contador de ciclos
                8'h08: avsreaddata <= regimgwidth;               // ancho de imagen
                8'h09: avsreaddata <= regimgheight;              // alto de imagen
                default: avsreaddata <= 32'h00000000;
            endcase
        end
    end

    // ====================================================
    // Asignacion de señales de salida hacia Top_General
    // ====================================================
    assign start        = regcontrol[0];
    assign step         = regcontrol[1];
    assign mode         = regcontrol[2];
    assign paramxratio  = regxratio;
    assign paramyratio  = regyratio;
    assign imgwriteaddr = regwriteaddr;
    assign imgwritedata = regwritedata;
    assign imgwidth     = regimgwidth;
    assign imgheight    = regimgheight;

endmodule
