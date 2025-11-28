// JTAGInterface.sv
// Interfaz JTAG usando Avalon-MM para comunicacion FPGA-PC

module JTAG_Interface (
    input  logic        clk,
    input  logic        rst,

    // Señales de control hacia el sistema (TopGeneral)
    output logic        start,
    output logic        step,
    output logic        mode,          // 0 Secuencial, 1 SIMD
    output logic [31:0] paramxratio,
    output logic [31:0] paramyratio,

    // Escritura de datos a la memoria de imagen
    output logic [31:0] imgwriteaddr,
    output logic [31:0] imgwritedata,

    // Lectura de datos desde el sistema (TopGeneral)
    input  logic [31:0] imgreaddata,
    input  logic        doneflag,
    input  logic [31:0] perfcounter,

    // Interfaz Avalon-MM JTAG
    input  logic        avsread,
    input  logic        avswrite,
    input  logic [7:0]  avsaddress,
    input  logic [31:0] avswritedata,
    output logic [31:0] avsreaddata
);

    // Mapa de registros
    // 0x00: regcontrol   bit 0 start, bit 1 step, bit 2 mode
    // 0x01: regxratio
    // 0x02: regyratio
    // 0x03: regwriteaddr
    // 0x04: regwritedata
    // 0x05: imgreaddata   (read-only, viene de TopGeneral)
    // 0x06: {31:1=0, 0=doneflag} (read-only)
    // 0x07: perfcounter   (read-only)

    // Registros internos
    logic [31:0] regcontrol;
    logic [31:0] regxratio;
    logic [31:0] regyratio;
    logic [31:0] regwriteaddr;
    logic [31:0] regwritedata;

    // Escritura de registros
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            regcontrol   <= 32'h00000000;
            regxratio    <= 32'h00000000;
            regyratio    <= 32'h00000000;
            regwriteaddr <= 32'h00000000;
            regwritedata <= 32'h00000000;
        end else if (avswrite) begin
            case (avsaddress)
                8'h00: regcontrol   <= avswritedata;
                8'h01: regxratio    <= avswritedata;
                8'h02: regyratio    <= avswritedata;
                8'h03: regwriteaddr <= avswritedata;
                8'h04: regwritedata <= avswritedata;
                default: ; // registros de solo lectura no se escriben
            endcase
        end
    end

    // Lectura de registros
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
                default: avsreaddata <= 32'h00000000;
            endcase
        end
    end

    // Asignación de señales de salida hacia TopGeneral
    assign start       = regcontrol[0];
    assign step        = regcontrol[1];
    assign mode        = regcontrol[2];
    assign paramxratio = regxratio;
    assign paramyratio = regyratio;
    assign imgwriteaddr= regwriteaddr;
    assign imgwritedata= regwritedata;

endmodule
