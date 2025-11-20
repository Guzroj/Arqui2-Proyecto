`timescale 1ns/1ps

module tb_SIMD_Registros;

    localparam int N = 4;

    logic clk, rst, load;

    logic [7:0] I00_in  [N], I10_in  [N], I01_in  [N], I11_in  [N];
    logic [7:0] alpha_in[N], beta_in[N];

    logic [7:0] I00_out [N], I10_out [N], I01_out [N], I11_out [N];
    logic [7:0] alpha_out[N], beta_out[N];

    SIMD_Registros #(N) dut (.*);

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    task show;
        integer i;
        begin
            $write("OUT: ");
            for (i = 0; i < N; i++)
                $write("%0d ", I00_out[i]);
            $write("\n");
        end
    endtask

    initial begin
        $display("\n=== TEST SIMD_Registros ===");

        rst = 1; load = 0;
        repeat(2) @(posedge clk);
        rst = 0;

        // Assign sample values
        I00_in = '{10,20,30,40};
        I10_in = '{50,60,70,80};
        I01_in = '{90,100,110,120};
        I11_in = '{130,140,150,160};
        alpha_in = '{1,2,3,4};
        beta_in  = '{5,6,7,8};

        @(posedge clk);
        load = 1;
        @(posedge clk);
        load = 0;

        show();

        // Change inputs (should NOT load)
        I00_in = '{200,201,202,203};

        repeat(2) @(posedge clk);

        show(); // must print 10 20 30 40

        $display("\n=== FIN TEST SIMD_Registros ===");
        $finish;
    end

endmodule
