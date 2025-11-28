// ================================================================
// ImageMemory.sv
// Memoria lineal simple para almacenar una imagen
// Acceso 1-puerto: escritura sincrónica, lectura combinacional
// ================================================================

module ImageMemory #(
    parameter int WIDTH  = 32,     // Ancho de la imagen
    parameter int HEIGHT = 32      // Alto de la imagen
)(
    input  logic                          clk,
    input  logic                          we,
    
    // Dirección lineal: 0 .. WIDTH*HEIGHT - 1
    input  logic [$clog2(WIDTH*HEIGHT)-1:0] addr,

    input  logic [7:0]                    wrdata,
    output logic [7:0]                    rddata
);

    // Cantidad total de píxeles
    localparam int DEPTH = WIDTH * HEIGHT;

    // Memoria interna
    logic [7:0] mem [0:DEPTH-1];

    // Escritura sincrónica
    always_ff @(posedge clk) begin
        if (we)
            mem[addr] <= wrdata;
    end

    // Lectura combinacional
    assign rddata = mem[addr];

endmodule
