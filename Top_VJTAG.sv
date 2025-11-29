// ================================================================
// Top_VJTAG.sv
// TOP con Virtual JTAG integrado
// Basado en: https://github.com/Abner2111/GuiaJtag
// Usa directamente sld_virtual_jtag (primitivo Intel/Altera)
// Compatible con Quartus 20.1
// ================================================================

module Top_VJTAG #(
    // Tamaño de imagen fuente
    parameter int IMG_W = 128,
    parameter int IMG_H = 128,
    // Tamaño de imagen destino
    parameter int DST_W = 64,
    parameter int DST_H = 64,
    // SIMD lanes
    parameter int N     = 4
)(
    input  logic        clk,
    input  logic        rst,      // KEY0: activo bajo (presionado=0)
    
    // LED de estado para evitar optimización
    output logic [7:0]  LEDR
);

    // Reset interno (invertido porque KEY0 es activo bajo)
    logic rst_internal;
    assign rst_internal = ~rst;

    // ============================================================
    // Señales del Virtual JTAG
    // ============================================================
    wire        tck;
    wire        tdi;
    wire        tdo;
    wire [1:0]  ir_in;
    wire        virtual_state_cdr;
    wire        virtual_state_sdr;
    wire        virtual_state_udr;
    
    // ============================================================
    // Señales Avalon-like (entre connect y JTAG_Interface)
    // ============================================================
    logic        avsread;
    logic        avswrite;
    logic [7:0]  avsaddress;
    logic [31:0] avswritedata;
    logic [31:0] avsreaddata;
    
    // ============================================================
    // Instancia directa de sld_virtual_jtag (primitivo Intel)
    // ============================================================
    sld_virtual_jtag #(
        .sld_auto_instance_index ("YES"),
        .sld_instance_index      (0),
        .sld_ir_width            (2),
        .sld_sim_n_scan          (0),
        .sld_sim_total_length    (0),
        .sld_sim_action          ("")
    ) u_vjtag (
        .tck                (tck),
        .tdi                (tdi),
        .tdo                (tdo),
        .ir_in              (ir_in),
        .ir_out             (2'b00),           // No usado
        .virtual_state_cdr  (virtual_state_cdr),
        .virtual_state_sdr  (virtual_state_sdr),
        .virtual_state_e1dr (),                // No usado
        .virtual_state_pdr  (),                // No usado
        .virtual_state_e2dr (),                // No usado
        .virtual_state_udr  (virtual_state_udr),
        .virtual_state_cir  (),                // No usado
        .virtual_state_uir  ()                 // No usado
    );
  
    // ============================================================
    // Controlador JTAG (connect.sv)
    // ============================================================
    connect u_connect (
        .tck                (tck),
        .tdi                (tdi),
        .tdo                (tdo),
        .ir_in              (ir_in),
        .virtual_state_cdr  (virtual_state_cdr),
        .virtual_state_sdr  (virtual_state_sdr),
        .virtual_state_udr  (virtual_state_udr),
        
        .avswrite           (avswrite),
        .avsread            (avsread),
        .avsaddress         (avsaddress),
        .avswritedata       (avswritedata),
        .avsreaddata        (avsreaddata)
    );
    
    // ============================================================
    // Top_General (tu diseño de Downscale)
    // ============================================================
    Top_General #(
        .IMG_W (IMG_W),
        .IMG_H (IMG_H),
        .DST_W (DST_W),
        .DST_H (DST_H),
        .N     (N)
    ) u_top_general (
        .clk          (clk),
        .rst          (rst_internal),
        .avsread      (avsread),
        .avswrite     (avswrite),
        .avsaddress   (avsaddress),
        .avswritedata (avswritedata),
        .avsreaddata  (avsreaddata)
    );
    
    // ============================================================
    // LEDs de estado (evita optimización y muestra actividad)
    // ============================================================
    assign LEDR = avsreaddata[7:0];

endmodule
