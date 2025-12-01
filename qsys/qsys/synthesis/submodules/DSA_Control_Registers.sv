// ============================================================================
// DSA_Control_Registers.sv
// ============================================================================
// Descripción:
//   Módulo de registros de control y estado para el DSA Downscaler.
//   Interfaz: Avalon-MM Slave (lectura/escritura de registros)
//
// Características:
//   - 12 registros de 32 bits (48 bytes total)
//   - Waitrequest = 0 (transacciones en 1 ciclo)
//   - Auto-clear de pulsos (start, reset_counters)
//   - Registro de factor de escala configurable (0.5-1.0 en pasos de 0.05)
//
// Mapa de Registros:
//   0x00: CTRL          - Control (start, reset_counters, mode, scale_factor)
//   0x04: STATUS        - Estado (busy, done, error)
//   0x08: IMG_WIDTH_IN  - Ancho imagen entrada (píxeles)
//   0x0C: IMG_HEIGHT_IN - Alto imagen entrada (píxeles)
//   0x10: IMG_WIDTH_OUT - Ancho imagen salida (píxeles)
//   0x14: IMG_HEIGHT_OUT- Alto imagen salida (píxeles)
//   0x18: INPUT_BASE    - Dirección base memoria entrada
//   0x1C: OUTPUT_BASE   - Dirección base memoria salida
//   0x20: PERF_CYCLES   - Contador de ciclos de reloj
//   0x24: PERF_READS    - Contador de lecturas de memoria
//   0x28: PERF_WRITES   - Contador de escrituras de memoria
//   0x2C: PERF_FLOPS    - Contador de operaciones FP
//
// Autor: DSA Project Team
// Fecha: Noviembre 2025
// ============================================================================

`timescale 1ns/1ps

module DSA_Control_Registers (
    input  logic        clk,
    input  logic        rst,

    // ========== Interfaz Avalon-MM Slave ==========
    input  logic [3:0]  avs_address,      // 4 bits = 16 registros (usamos 12)
    input  logic        avs_read,
    input  logic        avs_write,
    input  logic [31:0] avs_writedata,
    output logic [31:0] avs_readdata,
    output logic        avs_waitrequest,  // Siempre 0 (sin wait states)

    // ========== Señales de Control hacia DSA ==========
    output logic        dsa_start,         // Pulso de inicio
    output logic        dsa_reset_counters,// Pulso de reset de contadores
    output logic        dsa_mode,          // 0=Secuencial, 1=SIMD
    output logic [31:0] dsa_img_width_in,
    output logic [31:0] dsa_img_height_in,
    output logic [31:0] dsa_img_width_out,
    output logic [31:0] dsa_img_height_out,
    output logic [31:0] dsa_input_base,
    output logic [31:0] dsa_output_base,

    // ========== Señales de Estado desde DSA ==========
    input  logic        dsa_busy,
    input  logic        dsa_done,
    input  logic        dsa_error,
    input  logic [31:0] dsa_perf_cycles,
    input  logic [31:0] dsa_perf_reads,
    input  logic [31:0] dsa_perf_writes,
    input  logic [31:0] dsa_perf_flops
);

    // ========================================================================
    // Registros Internos
    // ========================================================================

    logic [31:0] reg_ctrl;           // 0x00: Control
    logic [31:0] reg_status;         // 0x04: Status (combinacional)
    logic [31:0] reg_img_width_in;   // 0x08
    logic [31:0] reg_img_height_in;  // 0x0C
    logic [31:0] reg_img_width_out;  // 0x10
    logic [31:0] reg_img_height_out; // 0x14
    logic [31:0] reg_input_base;     // 0x18
    logic [31:0] reg_output_base;    // 0x1C
    // Los contadores de performance vienen directamente del DSA

    // ========================================================================
    // Decodificación de CTRL Register
    // ========================================================================
    // Bit [0]   : start (auto-clear)
    // Bit [1]   : reset_counters (auto-clear)
    // Bit [2]   : mode (0=Seq, 1=SIMD)
    // Bit [7:3] : scale_factor_idx (0-10 para factores 0.5-1.0 en pasos 0.05)
    // Bit [8]   : use_manual_dimensions (0=usa scale_factor, 1=usa dimensiones manuales)
    // Bits [31:9]: Reservados

    logic [4:0] scale_factor_idx;
    logic       use_manual_dimensions;

    assign scale_factor_idx       = reg_ctrl[7:3];
    assign use_manual_dimensions  = reg_ctrl[8];

    // ========================================================================
    // Cálculo Automático de Dimensiones de Salida (según factor de escala)
    // ========================================================================
    logic [31:0] scale_ratio;      // En porcentaje (50 a 100)
    logic [31:0] auto_width_out;
    logic [31:0] auto_height_out;

    always_comb begin
        // Calcular ratio: 50 + (idx * 5) = 50, 55, 60, ..., 100
        if (scale_factor_idx > 5'd10)
            scale_ratio = 32'd100;  // Clamp a 100%
        else
            scale_ratio = 32'd50 + (32'(scale_factor_idx) * 32'd5);

        // Calcular dimensiones automáticas: (input_dim * ratio) / 100
        auto_width_out  = (reg_img_width_in  * scale_ratio) / 32'd100;
        auto_height_out = (reg_img_height_in * scale_ratio) / 32'd100;
    end

    // ========================================================================
    // Salidas de Dimensiones (manual o automático)
    // ========================================================================
    assign dsa_img_width_in   = reg_img_width_in;
    assign dsa_img_height_in  = reg_img_height_in;

    // Si use_manual_dimensions=1, usa valores manuales; sino usa automáticos
    assign dsa_img_width_out  = use_manual_dimensions ? reg_img_width_out  : auto_width_out;
    assign dsa_img_height_out = use_manual_dimensions ? reg_img_height_out : auto_height_out;

    // ========================================================================
    // Salidas de Control (con auto-clear)
    // ========================================================================
    assign dsa_start          = reg_ctrl[0];
    assign dsa_reset_counters = reg_ctrl[1];
    assign dsa_mode           = reg_ctrl[2];
    assign dsa_input_base     = reg_input_base;
    assign dsa_output_base    = reg_output_base;

    // ========================================================================
    // Registro STATUS (Combinacional - refleja estado actual del DSA)
    // ========================================================================
    always_comb begin
        reg_status       = 32'd0;
        reg_status[0]    = dsa_busy;
        reg_status[1]    = dsa_done;
        reg_status[2]    = dsa_error;
        // Bits [31:3] reservados
    end

    // ========================================================================
    // Avalon-MM: Sin wait states
    // ========================================================================
    assign avs_waitrequest = 1'b0;

    // ========================================================================
    // Avalon-MM: Lectura de Registros
    // ========================================================================
    always_comb begin
        case (avs_address)
            4'h0: avs_readdata = reg_ctrl;
            4'h1: avs_readdata = reg_status;
            4'h2: avs_readdata = reg_img_width_in;
            4'h3: avs_readdata = reg_img_height_in;
            4'h4: avs_readdata = reg_img_width_out;
            4'h5: avs_readdata = reg_img_height_out;
            4'h6: avs_readdata = reg_input_base;
            4'h7: avs_readdata = reg_output_base;
            4'h8: avs_readdata = dsa_perf_cycles;
            4'h9: avs_readdata = dsa_perf_reads;
            4'hA: avs_readdata = dsa_perf_writes;
            4'hB: avs_readdata = dsa_perf_flops;
            default: avs_readdata = 32'h0;
        endcase
    end

    // ========================================================================
    // Avalon-MM: Escritura de Registros
    // ========================================================================
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            // Valores por defecto
            reg_ctrl           <= 32'd0;
            reg_img_width_in   <= 32'd512;    // Default: 512×512
            reg_img_height_in  <= 32'd512;
            reg_img_width_out  <= 32'd256;    // Default: 256×256
            reg_img_height_out <= 32'd256;
            reg_input_base     <= 32'h00000000;  // input_memory base
            reg_output_base    <= 32'h00040000;  // output_memory base

        end else begin
            // Auto-clear de pulsos
            if (reg_ctrl[0]) reg_ctrl[0] <= 1'b0;  // start
            if (reg_ctrl[1]) reg_ctrl[1] <= 1'b0;  // reset_counters

            // Escritura de registros
            if (avs_write) begin
                case (avs_address)
                    4'h0: reg_ctrl           <= avs_writedata;
                    4'h1: ; // STATUS es read-only
                    4'h2: reg_img_width_in   <= avs_writedata;
                    4'h3: reg_img_height_in  <= avs_writedata;
                    4'h4: reg_img_width_out  <= avs_writedata;
                    4'h5: reg_img_height_out <= avs_writedata;
                    4'h6: reg_input_base     <= avs_writedata;
                    4'h7: reg_output_base    <= avs_writedata;
                    // 0x08-0x0B: Performance counters son read-only
                    default: ;
                endcase
            end
        end
    end

endmodule
