`timescale 1ns/1ps

module tb_Top_Downscale_Integration;

    // ==================================================
    // Parámetros
    // ==================================================
    localparam SRC_H = 512;
    localparam SRC_W = 512;

    // Reducción a 1/3 → 171x171
    localparam DST_H = 171;
    localparam DST_W = 171;

    localparam N = 4;
    localparam CLK_PERIOD = 10;   // 100 MHz

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
    // DUT
    // ==================================================
    Top_Downscale_Integration #(
        .SRC_H(SRC_H),
        .SRC_W(SRC_W),
        .DST_H(DST_H),
        .DST_W(DST_W),
        .N(N)
    ) dut (
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
    // Imagen 512x512 desde archivo
    // ==================================================
    reg [7:0] test_image [0:SRC_H-1][0:SRC_W-1];

    // VARIABLES FUERA DEL INITIAL (RESTRICCIÓN DE QUARTUS)
    integer file;
    integer code;
    integer i;
    integer j;

    initial begin
        $display("[%0t] Leyendo archivo imagen_grayscale.txt ...", $time);

        file = $fopen("C:/Users/gabri/OneDrive/Desktop/PrograProyectoArqui/Arqui2-Proyecto/imagen_grayscale.txt", "r");


        if (file == 0) begin
            $fatal("ERROR: No se pudo abrir imagen_grayscale.txt");
        end

        for (i = 0; i < SRC_H; i = i + 1) begin
            for (j = 0; j < SRC_W; j = j + 1) begin
                code = $fscanf(file, "%d", test_image[i][j]);
                if (code != 1) begin
                    $fatal("ERROR leyendo txt en [%0d,%0d]", i, j);
                end
            end
        end

        $fclose(file);
        $display("[%0t] ✓ Lectura completa de 512x512", $time);
    end

    // ==================================================
    // Cargar imagen
    // ==================================================
    task load_image;
        begin
            wr_en = 0;
            @(posedge clk);

            for (i = 0; i < SRC_H; i = i + 1) begin
                for (j = 0; j < SRC_W; j = j + 1) begin
                    wr_en   = 1;
                    wr_addr = i * SRC_W + j;
                    wr_data = test_image[i][j];
                    @(posedge clk);
                end
            end

            wr_en = 0;
            @(posedge clk);

            $display("[%0t] Imagen cargada en BRAM.", $time);
        end
    endtask

    // ==================================================
    // Ejecutar downscale
    // ==================================================
    task run_downscale;
        integer timeout;
        begin
            start = 1;
            @(posedge clk);
            start = 0;

            timeout = 0;
            while (!done && timeout < 2000000) begin
                @(posedge clk);
                timeout = timeout + 1;
            end

            if (!done)
                $fatal("Timeout en downscale");

            $display("[%0t] ✓ Downscale terminado", $time);
        end
    endtask

    // ==================================================
    // Mostrar primeras filas
    // ==================================================
    task display_some;
        begin
            $display("Mostrando primeras líneas del resultado:");
            for (i = 0; i < 8; i = i + 1) begin
                $write("Row %0d: ", i);
                for (j = 0; j < 16; j = j + 1)
                    $write("%3d ", image_out[i][j]);
                $write("\n");
            end
        end
    endtask

    // ==================================================
    // Secuencia principal
    // ==================================================
    initial begin
        rst = 1;
        start = 0;
        wr_en = 0;
        wr_addr = 0;
        wr_data = 0;

        repeat(10) @(posedge clk);
        rst = 0;

        load_image();
        run_downscale();
        display_some();

        $display("TEST COMPLETADO");
        $stop;
    end

endmodule