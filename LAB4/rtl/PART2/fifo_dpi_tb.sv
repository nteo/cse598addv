// Import the C function using DPI
import "DPI-C" function void push(int data);
import "DPI-C" function int pop();
import "DPI-C" function bool is_full();
import "DPI-C" function bool is_empty();

`timescale 1ns/1ns

//////////////////////
//Drivers
/////////////////////
module write_driver #(
        parameter CLK_PERIOD = 5,
        parameter WIDTH = 4,
        parameter DEPTH = 8
) (
    fifo_wif fifo_wi.CONTROLLER
);
    // Define the wclk signal
    initial begin
        fifo_wi.wclk = 0;
        forever #(CLK_PERIOD/2) fifo_wi.wclk = ~fifo_wi.wclk;
    end

    // Define the reset task
    task reset();
        fifo_wi.wrst_n = 1'b0;
        fifo_wi.wdata = 0;
        fifo_wi.winc = 0;
        @(posedge fifo_wi.wclk);
        fifo_wi.wrst_n = 1'b1;
    endtask

    // Define the write task
    task write(input logic [DSIZE-1:0] data);
        fifo_wi.wdata = data;
        fifo_wi.winc = 1'b1;
        @(posedge fifo_wi.wclk);
        fifo_wi.winc = 1'b0;
    endtask
endmodule

module read_driver #(
    parameter RCLK_PERIOD = 7,
    parameter WIDTH = 4,
    parameter DEPTH = 8
) (
    fifo_rif fifo_ri.CONTROLLER
);
    // Define the rclk signal
    initial begin
        fifo_ri.rclk = 0;
        forever #(RCLK_PERIOD/2) fifo_ri.rclk = ~fifo_ri.rclk;
    end

    // Define the reset task
    task reset();
        fifo_ri.rrst_n = 1'b0;
        fifo_ri.rinc = 0;
        @(posedge fifo_ri.rclk);
        fifo_ri.rrst_n = 1'b1;
    endtask

    // Define the read task
    task read();
        fifo_ri.rinc = 1'b1;
        @(posedge fifo_ri.rclk);
        fifo_ri.rinc = 1'b0;
    endtask
endmodule

//////////////////////
//Checker
/////////////////////
module checker(/* include fifo read_IF and write_IF */);
        integer expected_rdata;
        boolean expected_full;
        boolean expected_empty;

        always @(posedge wclk) begin    // TODO: FIX THE TIMING ON THIS
            if (winc) begin
                push(wdata);
            end

            expected_full = is_full();
            expected_empty = is_empty();

            @(negedge wclk);
            if (expected_full != full) $error("FAILED - FULL mismatch: Expected full = %0d, got %0d", expected_full, full);
        end

        always @(posedge rclk) begin    // TODO: FIX THE TIMING ON THIS
            if (rinc && !rempty) begin
                expected_rdata = pop();

                @(negedge rclk);
                if (rdata != expected_rdata)
                    $error("FAILED - READ DATA mismatch: Expected rdata = %0d, got %0d", expected_rdata, rdata);
                else
                    $info("PASSED - READ DATA: rdata = %0d", rdata);
                
                if (rempty !== is_empty()) begin
                    $error("FAILED - EMPTY mismatch: Expected empty = %0d, got %0d", is_empty(), rempty);
                end
            end
            else begin
                @(negedge rclk);
                if (rempty !== is_empty()) begin
                    $error("EMPTY mismatch: Expected empty = %0d, got %0d", is_empty(), rempty);
                end
            end
        end

endmodule

//////////////////////
//Testbench
/////////////////////
module fifo_dpi_tb;
    localparam int DATA_WIDTH = 8;
    localparam int ADDR_WIDTH = 4;
    localparam int DEPTH = 16;

    // Testbench signals
    fifo_if #(
        .DATA_WIDTH(DATA_WIDTH))
    fifo_dut_if();

    fifo_wif #(
        .DATA_WIDTH(DATA_WIDTH)
    ) fifo_wi();

    fifo_rif #(
        .DATA_WIDTH(DATA_WIDTH)
    ) fifo_ri();

    // Write --> DUT
    assign fifo_dut_if.wdata  = fifo_write_if.wdata;
    assign fifo_dut_if.winc   = fifo_write_if.winc;
    assign fifo_dut_if.wclk   = fifo_write_if.wclk;
    assign fifo_dut_if.wrst_n = fifo_write_if.wrst_n;

    // DUT --> Write
    assign fifo_write_if.full = fifo_dut_if.full;

    // Read --> DUT
    assign fifo_dut_if.rinc   = fifo_read_if.rinc;
    assign fifo_dut_if.rclk   = fifo_read_if.rclk;
    assign fifo_dut_if.rrst_n = fifo_read_if.rrst_n;

    // DUT --> Read
    assign fifo_read_if.rdata = fifo_dut_if.rdata;
    assign fifo_read_if.empty = fifo_dut_if.empty;

    // Define the test number (1, 2, or 3)
    int test_num;

    fifo dut(/* include fifo if */);    // TODO: FINISH IMPLEMENTING THIS
    write_driver write_driver_inst(/* include fifo read if */);
    read_driver read_driver_inst(/* include fifo write if */);
    checker checker_inst(/* include fifo if */);

    // Test reading and writing at the same time
    task test_simultaneous_read_write();
        // Implement the test for simultaneous read and write operations
        
        fork
            begin
                // Write data to FIFO    // TODO: FINISH IMPLEMENTING THIS
                for (int i = 0; i < 10; i++) begin
                    write_driver_inst.write(i);
                    $display("Wrote: %0d", i);
                    @(posedge write_driver_inst.wclk);
                end
            end

            begin
                // Read data from FIFO    // TODO: FINISH IMPLEMENTING THIS
                for (int i = 0; i < 10; i++) begin
                    read_driver_inst.read();
                    @(posedge read_driver_inst.rclk);
                    c = dut.rdata;
                    $display("Read: %0d", c);
                end
            end
        join
    endtask
    
    // Test writing to FIFO until it is full
    task test_full_condition();
        // Write data to FIFO until it is full
        for (int i = 0; i < 10; i++) begin
            write_driver_inst.write(i);
            $display("Wrote: %0d", i);
            @(posedge write_driver_inst.wclk);
        end
        
        // Read data from FIFO    // TODO: FINISH IMPLEMENTING THIS
        for (int i = 0; i < 10; i++) begin
            read_driver_inst.read();
            @(posedge read_driver_inst.rclk);
            c = dut.rdata;
            $display("Read: %0d", c);
        end
    endtask
    
    // Test reading from FIFO until it is empty
    task test_empty_condition();
        // Write data to FIFO    // TODO: FINISH IMPLEMENTING THIS
        for (int i = 0; i < 10; i++) begin
            write_driver_inst.write(i);
            $display("Wrote: %0d", i);
            @(posedge write_driver_inst.wclk);
        end

        // Read data from FIFO    // TODO: FINISH IMPLEMENTING THIS
        for (int i = 0; i < 10; i++) begin
            read_driver_inst.read();
            @(posedge read_driver_inst.rclk);
            c = dut.rdata;
            $display("Read: %0d", c);
        end
    endtask

    initial begin
        // Get the test number from command line arguments (default to running all tests if not provided)
        if (!$value$plusargs("TEST=%d", test_num)) begin
            test_num = 0; // Default to running all tests
        end

        case (test_num)
            1: begin
                $display("Running Test #1: Simultaneous Read and Write");
                test_simultaneous_read_write();
            end
            2: begin
                $display("Running Test #2: Full Condition");
                test_full_condition();
            end
            3: begin
                $display("Running Test #3: Empty Condition");
                test_empty_condition();
            end
            default: begin
                $display("Running Test #1: Simultaneous Read and Write");
                test_simultaneous_read_write();

                $display("Running Test #2: Full Condition");
                test_full_condition();

                $display("Running Test #3: Empty Condition");
                test_empty_condition();
            end
        endcase

        $finish;
    end

    // Dump waves
    initial begin
        $fsdbDumpfile("novas.fsdb");
        $fsdbDumpvars(0, fifo_dpi_tb);
    end
endmodule



//vcs -sverilog dpi_class_example.sv dpi_add.c -o dpi_class_sim