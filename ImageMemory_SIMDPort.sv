module ImageMemory_SIMDPort #(
    parameter int IMG_W = 512,
    parameter int IMG_H = 512,
    parameter int N     = 4
)(
    input  logic clk,
    input  logic rst,
    input  logic                           rd_req   [N],
    input  logic [$clog2(IMG_W*IMG_H)-1:0] rd_addr  [N],
    output logic                           rd_valid [N],
    output logic [7:0]                     rd_data  [N],
    input  logic                           we,
    input  logic [$clog2(IMG_W*IMG_H)-1:0] wr_addr,
    input  logic [7:0] wr_data
);
    localparam int DEPTH = IMG_W*IMG_H;
    localparam int ADDR_BITS = $clog2(DEPTH);
    
    // BRAM
    logic [7:0] mem_out;
    logic [ADDR_BITS-1:0] mem_addr;
    
    ImageMemory #(
        .IMG_W(IMG_W),
        .IMG_H(IMG_H)
    ) mem (
        .clk(clk),
        .we (we),
        .addr(we ? wr_addr : mem_addr),
        .wr_data(wr_data),
        .rd_data(mem_out)
    );
    
    // =========================================================
    // Procesamiento secuencial de N requests
    // =========================================================
    typedef enum logic [1:0] {
        IDLE,
        FETCHING,
        DONE_FETCH
    } mem_state_t;
    
    mem_state_t state;
    
    logic [$clog2(N)-1:0] current_lane;
    logic [$clog2(N)-1:0] lanes_processed;
    logic [N-1:0] pending_reqs;  // Qué lanes tienen requests pendientes
    
    integer cycle_count = 0;
    
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            for (int i = 0; i < N; i++) begin
                rd_valid[i] <= 1'b0;
                rd_data[i]  <= 8'd0;
            end
            state           <= IDLE;
            current_lane    <= '0;
            lanes_processed <= '0;
            pending_reqs    <= '0;
            cycle_count     <= 0;
            
            $display("[MEM_SIMD] RESET");
            
        end else begin
            cycle_count <= cycle_count + 1;
            
            // Bajar valids por defecto
            for (int i = 0; i < N; i++)
                rd_valid[i] <= 1'b0;
            
            case (state)
                
                IDLE: begin
                    // Capturar nuevos requests
                    pending_reqs = '0;
                    for (int i = 0; i < N; i++) begin
                        if (rd_req[i]) begin
                            pending_reqs[i] = 1'b1;
                            $display("[MEM_SIMD][%0t] Ciclo %0d: REQUEST capturado lane=%0d addr=%0d", 
                                     $time, cycle_count, i, rd_addr[i]);
                        end
                    end
                    
                    // Si hay requests, empezar a procesar
                    if (pending_reqs != '0) begin
                        current_lane    <= 0;
                        lanes_processed <= 0;
                        state           <= FETCHING;
                        
                        // Pedir primer dato
                        mem_addr <= rd_addr[0];
                        $display("[MEM_SIMD][%0t] Ciclo %0d: Inicio procesamiento, %0d lanes activos", 
                                 $time, cycle_count, $countones(pending_reqs));
                    end
                end
                
                FETCHING: begin
                    // Esperar 1 ciclo para que BRAM responda
                    state <= DONE_FETCH;
                end
                
                DONE_FETCH: begin
                    // Guardar dato del lane actual si tenía request
                    if (pending_reqs[current_lane]) begin
                        rd_valid[current_lane] <= 1'b1;
                        rd_data[current_lane]  <= mem_out;
                        $display("[MEM_SIMD][%0t] Ciclo %0d: DATO lane=%0d data=0x%02h", 
                                 $time, cycle_count, current_lane, mem_out);
                    end
                    
                    lanes_processed <= lanes_processed + 1;
                    
                    // ¿Quedan más lanes?
                    if (lanes_processed < N-1) begin
                        current_lane <= current_lane + 1;
                        
                        // Pedir dato del siguiente lane
                        mem_addr <= rd_addr[current_lane + 1];
                        state    <= FETCHING;
                    end else begin
                        // Todos procesados
                        $display("[MEM_SIMD][%0t] Ciclo %0d: ✓ Batch completado (%0d lanes)", 
                                 $time, cycle_count, $countones(pending_reqs));
                        state <= IDLE;
                    end
                end
                
            endcase
        end
    end
    
endmodule