`timescale 1ns/1ps

module tb_Top_Downscale_Integration;

    // ==================================================
    // Parámetros
    // ==================================================
    localparam SRC_H = 4;
    localparam SRC_W = 4;
    localparam DST_H = 3;
    localparam DST_W = 3;
    localparam N     = 4;

    localparam CLK_PERIOD = 10; // 100 MHz

    // ==================================================
    // Señales
    // ==================================================
    reg clk;
    reg rst;
    reg start;
    wire done;

    reg         wr_en;
    reg [15:0]  wr_addr;
    reg [7:0]   wr_data;

    wire [7:0] image_out [0:DST_H-1][0:DST_W-1];

    // ==================================================
    // Instancia del DUT
    // ==================================================
    Top_Downscale_Integration #(
        .SRC_H(SRC_H),
        .SRC_W(SRC_W),
        .DST_H(DST_H),
        .DST_W(DST_W),
        .N(N)
    )
    dut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .done(done),
        .wr_en(wr_en),
        .wr_addr(wr_addr),
        .wr_data(wr_data),
        .image_out(image_out)
    );

    // ==================================================
    // Reloj
    // ==================================================
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // ==================================================
    // Imagen de prueba
    // ==================================================
    reg [7:0] test_image [0:SRC_H-1][0:SRC_W-1];

    initial begin
        test_image[0][0]=96;   test_image[0][1]=32;  test_image[0][2]=64;  test_image[0][3]=96;
        test_image[1][0]=32;  test_image[1][1]=64;  test_image[1][2]=96;  test_image[1][3]=128;
        test_image[2][0]=64;  test_image[2][1]=96;  test_image[2][2]=128; test_image[2][3]=160;
        test_image[3][0]=96;  test_image[3][1]=128; test_image[3][2]=160; test_image[3][3]=192;
    end

    // ==================================================
    // Tarea para cargar la imagen
    // ==================================================
    task load_image;
        integer i,j;
        begin
            $display("[%0t] Cargando imagen...", $time);
            wr_en = 0;
            @(posedge clk);

            for (i=0; i<SRC_H; i=i+1) begin
                for (j=0; j<SRC_W; j=j+1) begin
                    wr_en   = 1;
                    wr_addr = i*SRC_W + j;
                    wr_data = test_image[i][j];
                    @(posedge clk);
                end
            end

            wr_en = 0;
            @(posedge clk);
            $display("[%0t] Imagen cargada.", $time);
        end
    endtask

    // ==================================================
    // Iniciar procesamiento (sin fork/join_any)
    // ==================================================
    task run_downscale;
        integer timeout;
        begin
            $display("[%0t] Iniciando downscale...", $time);
            start = 1;
            @(posedge clk);
            start = 0;

            // Tiempo máximo de espera
            timeout = 0;
            while (done == 0 && timeout < 1000) begin
                @(posedge clk);
                timeout = timeout + 1;
            end

            if (done)
                $display("[%0t] ✓ Procesamiento completado", $time);
            else begin
                $display("[%0t] ✗ ERROR: Timeout", $time);
                $stop;
            end
        end
    endtask

    // ==================================================
    // Mostrar resultados
    // ==================================================
    task display_output;
        integer i,j;
        begin
            $display("\n=== IMAGEN DE SALIDA %0dx%0d ===", DST_H, DST_W);
            for (i=0; i<DST_H; i=i+1) begin
                $write("Row %0d: ", i);
                for (j=0; j<DST_W; j=j+1) begin
                    $write("%3d ", image_out[i][j]);
                end
                $write("\n");
            end
            $display("==============================\n");
        end
    endtask

    // ==================================================
    // Verificación
    // ==================================================
    task verify_output;
        integer i,j;
        integer errors;
        begin
            errors = 0;

            $display("[%0t] Verificando salida...", $time);

            for (i=0; i<DST_H; i=i+1) begin
                for (j=0; j<DST_W; j=j+1) begin
                    
                    if (image_out[i][j] === 8'd0) begin
                        $display(" ✗ Pixel [%0d,%0d] = 0", i,j);
                        errors = errors + 1;
                    end

                end
            end

            if (errors == 0)
                $display(" ✓ Verificación PASADA");
            else
                $display(" ✗ %0d errores detectados", errors);
        end
    endtask

    // ==================================================
    // Secuencia principal
    // ==================================================
    initial begin
        $display("\n\n==== TEST Top_Downscale_Integration ====\n");

        rst = 1;
        start = 0;
        wr_en = 0;
        wr_addr = 0;
        wr_data = 0;

        repeat(5) @(posedge clk);
        rst = 0;

        // 1. Cargar imagen
        load_image();

        // 2. Procesar
        run_downscale();

        // 3. Mostrar resultado
        display_output();

        // 4. Verificar
        verify_output();

        $display("\n==== TEST COMPLETADO ====\n");
        $stop;
    end

endmodule
