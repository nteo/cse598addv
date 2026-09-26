`timescale 1ns/1ps

module even_odd_sorter_tb;
    // Parameters
    localparam int DATA_WIDTH = 8;
    localparam int FIFO_DEPTH = 6;  // depth is 40 but the address width is 6

    // DUT signals
    logic                   clk;
    logic                   rst_n;
    logic [DATA_WIDTH-1:0]  data_in;
    logic                   write_en;
    logic [DATA_WIDTH-1:0]  data_out;
    logic                   read_en;

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    even_odd_sorter #(
        .FIFO_DEPTH(FIFO_DEPTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (.*);

    // Reset the dut
    task automatic apply_reset();
        write_en = 1'b0;
        data_in  = '0;
        read_en  = 1'b0;
        rst_n    = 1'b0;
        repeat (4) @(negedge clk);
        rst_n = 1'b1;
        @(negedge clk);
    endtask


    // Test 1: random 100 cycles
    logic                  we_case1[100]  = '{1,0,1,1,1,1,0,1,1,1,1,1,1,0,1,1,1,0,1,1,0,1,1,1,1,1,1,0,1,1,1,1,0,1,1,1,1,1,1,0,0,1,1,1,0,1,1,1,1,1,1,1,1,1,1,0,1,1,1,0,0,1,1,1,0,1,1,1,1,1,1,1,0,1,1,1,1,1,0,1,1,1,0,1,1,0,1,1,1,1,1,1,1,1,0,1,1,0,1,1};
    logic [DATA_WIDTH-1:0] din_case1[100] = '{88,0,132,87,235,84,0,118,70,22,197,137,152,0,150,142,32,0,212,65,0,66,97,36,225,9,103,0,11,172,12,250,0,55,173,41,82,134,92,0,0,113,235,132,0,234,19,219,197,247,81,68,181,127,234,0,150,58,91,0,0,130,22,168,0,235,209,6,177,150,86,222,0,146,61,43,125,128,0,177,243,174,0,245,37,0,227,139,160,160,19,38,139,245,0,217,64,0,179,44};

    // Test 2: worst case 40 EVEN, 20 write stalls, 40 ODD
    logic                  we_case2[100]  = '{1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1};
    logic [DATA_WIDTH-1:0] din_case2[100] = '{2,4,6,8,10,12,14,16,18,20,22,24,26,28,30,32,34,36,38,40,42,44,46,48,50,52,54,56,58,60,62,64,66,68,70,72,74,76,78,80,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,3,5,7,9,11,13,15,17,19,21,23,25,27,29,31,33,35,37,39,41,43,45,47,49,51,53,55,57,59,61,63,65,67,69,71,73,75,77,79};

    // Test 3: worst case 40 ODD, 20 write stalls, 40 EVEN
    logic                  we_case3[100]  = '{1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1};
    logic [DATA_WIDTH-1:0] din_case3[100] = '{1,3,5,7,9,11,13,15,17,19,21,23,25,27,29,31,33,35,37,39,41,43,45,47,49,51,53,55,57,59,61,63,65,67,69,71,73,75,77,79,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,4,6,8,10,12,14,16,18,20,22,24,26,28,30,32,34,36,38,40,42,44,46,48,50,52,54,56,58,60,62,64,66,68,70,72,74,76,78,80};

    // The same read_en pattern is used for all 3 tests
    logic                  re_shared[100] = '{1,1,1,1,1,1,1,0,0,1,1,1,1,1,1,1,1,0,0,1,1,1,1,0,0,1,1,1,1,1,1,1,1,0,0,1,1,1,1,1,1,1,0,1,1,0,1,1,1,1,1,1,1,1,0,1,0,1,1,1,0,1,1,1,1,1,1,1,1,0,1,1,1,1,1,1,1,0,0,1,1,1,1,1,1,0,1,1,0,1,1,0,1,0,1,1,1,1,1,1};


    // Driver
    task automatic drive_case(
        input logic                    we[100],
        input logic [DATA_WIDTH-1:0]   din[100],
        input logic                    re[100]
    );
        apply_reset();
        for (int i = 0; i < 100; i++) begin
            // Update the stimulus on the negedge since the output updates on the posedge
            @(negedge clk);
            write_en = we[i];
            data_in  = din[i];
            read_en  = re[i];
        end
        @(negedge clk);
    endtask

    // Execute each test case
    initial begin
        $display("Begin simulation");
        drive_case(we_case1, din_case1, re_shared);
        drive_case(we_case2, din_case2, re_shared);
        drive_case(we_case3, din_case3, re_shared);
        $display("Simulation finished");
        $finish;
    end

    // Dump waves
    initial begin
        $fsdbDumpfile("novas.fsdb");
        $fsdbDumpvars(0, even_odd_sorter_tb);
    end
endmodule