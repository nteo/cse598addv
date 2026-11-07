// Import the C function using DPI
import "DPI-C" function void reset_fifo();
import "DPI-C" function void push_fifo(int data);
import "DPI-C" function int  pop_fifo();
import "DPI-C" function int is_fifo_full();
import "DPI-C" function int is_fifo_empty();


//////////////////////
//Drivers
/////////////////////
class fifo_write_driver #(int DATA_WIDTH = 8);
    virtual fifo_wif.CONTROLLER vif;

    function new(virtual fifo_wif.CONTROLLER vif);
        this.vif = vif;
    endfunction

    task reset();
        vif.wrst_n <= 1'b0;
        vif.wdata  <= '0;
        vif.winc   <= 1'b0;

        @(posedge vif.wclk);
        vif.wrst_n <= 1'b1;
    endtask

    task write(input logic [DATA_WIDTH-1:0] data);
        @(negedge vif.wclk);
        vif.wdata <= data;
        vif.winc  <= 1'b1;

        @(posedge vif.wclk);

        @(negedge vif.wclk);
        vif.wdata <= '0;
        vif.winc  <= 1'b0;
    endtask

    task stall();
        @(negedge vif.wclk);
        vif.wdata <= '0;
        vif.winc  <= 1'b0;
    endtask
endclass

class fifo_read_driver;
    virtual fifo_rif.CONTROLLER vif;

    function new(virtual fifo_rif.CONTROLLER vif);
        this.vif = vif;
    endfunction

    task reset();
        vif.rrst_n <= 1'b0;
        vif.rinc   <= 1'b0;

        @(posedge vif.rclk);
        vif.rrst_n <= 1'b1;
    endtask

    task read();
        @(negedge vif.rclk);
        vif.rinc  <= 1'b1;
    endtask

    task stall();
        @(negedge vif.rclk);
        vif.rinc  <= 1'b0;
    endtask
endclass


//////////////////////
//Checker
/////////////////////
class fifo_checker #(int DATA_WIDTH = 8);
    virtual fifo_wif write_vif;
    virtual fifo_rif read_vif;

    function new(virtual fifo_wif write_vif, virtual fifo_rif read_vif);
        this.write_vif = write_vif;
        this.read_vif = read_vif;
    endfunction

    task run();
        reset_fifo();
        fork
            check_writes();
            check_reads();
        join_none
    endtask

    task check_writes();
        logic [DATA_WIDTH-1:0] sampled_wdata;
        logic sampled_winc;
        logic sampled_full, sampled_empty;

        bit expected_full, expected_empty;

        forever begin
            // Sample the write signals and empty flag on the posedge of the write clock
            sampled_full  = write_vif.full;

            @(posedge write_vif.wclk);
            #1;
            sampled_wdata = write_vif.wdata;
            sampled_winc  = write_vif.winc;

            // Check the sampled values against the expected values on the negedge of the write clock
            @(negedge write_vif.wclk);
            // Get the expected values from the DPI calls
            expected_full  = is_fifo_full();
            if (sampled_winc && !is_fifo_full()) begin
                $display("\tTime %0t:: Pushing data to FIFO: %0d",
                    $time,
                    sampled_wdata
                );
                push_fifo(sampled_wdata);
            end

            // Compare the sampled values with the expected values
            if (sampled_full !== expected_full) begin
                $display("\tTime %0t:: FULL (write) mismatch: expected=%0d actual=%0d",
                    $time,
                    expected_full,
                    sampled_full
                );
            end
            else begin
                $display("\tTime %0t:: FULL PASS: full=%0d", $time, sampled_full);
            end
        end
    endtask

    task check_reads();
        logic [DATA_WIDTH-1:0] sampled_rdata;
        logic sampled_rinc;
        logic sampled_full, sampled_empty;

        int expected_rdata;
        bit expected_full, expected_empty;

        forever begin
            // Capture rdata before it is updated
            sampled_rdata = read_vif.rdata;
            sampled_empty = read_vif.empty;

            // Sample the rest of the read signals and full flag on the posedge of the read clock
            @(posedge read_vif.rclk);
            #1;
            sampled_rinc  = read_vif.rinc;

            // Check the sampled values against the expected values on the negedge of the read clock
            @(negedge read_vif.rclk);
            // Get the expected values from the DPI calls
            expected_empty = is_fifo_empty();
            if (sampled_rinc && !is_fifo_empty()) begin
                expected_rdata = pop_fifo();
            end
            else begin
                expected_rdata = sampled_rdata;
            end

            // Compare the sampled values with the expected values
            if (sampled_rdata !== expected_rdata) begin
                $display("\tTime %0t:: READ DATA mismatch: expected=%0d actual=%0d",
                    $time,
                    expected_rdata,
                    sampled_rdata
                );
            end
            else begin
                $display("\tTime %0t:: READ PASS: rdata=%0d", $time, sampled_rdata);
            end

            if (sampled_empty !== expected_empty) begin
                $display("\tTime %0t:: EMPTY (read) mismatch: expected=%0d actual=%0d",
                    $time,
                    expected_empty,
                    sampled_empty
                );
            end
            else begin
                $display("\tTime %0t:: EMPTY PASS: empty=%0d", $time, sampled_empty);
            end
        end
    endtask
endclass


//////////////////////
//Testbench
/////////////////////
module fifo_dpi_tb;
    timeunit 1ns;
    timeprecision 1ns;

    localparam int WCLK_PERIOD = 5;
    localparam int RCLK_PERIOD = 7;
    localparam int DATA_WIDTH = 8;
    localparam int ADDR_WIDTH = 4;
    localparam int DEPTH = 1 << ADDR_WIDTH;


    // <<<<< TESTBENCH SIGNALS >>>>>
    logic wclk, rclk;
    int test_num;   // define the test number (1, 2, or 3)

    fifo_wif #(DATA_WIDTH) fifo_wi(.*);
    fifo_rif #(DATA_WIDTH) fifo_ri(.*);


    // <<<<< TEST COMPONENTS INSTANTIATION >>>>>
    fifo dut(.*);
    fifo_write_driver #(DATA_WIDTH) write_driver;
    fifo_read_driver read_driver;
    fifo_checker #(DATA_WIDTH) checker;


    // <<<<< TEST CASES >>>>>
    // Test reading and writing at the same time
    task test_simultaneous_read_write();
        // Reset the FIFO
        fork
            write_driver.reset();
            read_driver.reset();
        join

        fork
            // Write data to FIFO
            begin
                for (int i = 0; i < 2 * DEPTH; i++) begin
                    write_driver.write(i);
                end
                write_driver.stall();
            end

            // Read data from FIFO
            begin
                for (int i = 0; i < 3 * DEPTH; i++) begin
                    read_driver.read();
                end
                read_driver.stall();
            end
        join
    endtask
    
    // Test writing to FIFO until it is full
    task test_full_condition();
        int count = 0;

        // Reset the FIFO
        fork
            write_driver.reset();
            read_driver.reset();
        join

        // Write data to FIFO until it is full 
        for (int i = 0; i < DEPTH; i++) begin
            write_driver.write(count);
            count++;
        end
        write_driver.stall();

        // Write 3 more times to test the full condition
        for (int i = 0; i < 3; i++) begin
            write_driver.write(count);
            count++;
        end
        write_driver.stall();

        // Read data from FIFO until it is half full
        for (int i = 0; i < (DEPTH / 2); i++) begin
            read_driver.read();
        end
        read_driver.stall();

        // Write data to FIFO again until it is full
        for (int i = 0; i < (DEPTH / 2); i++) begin
            write_driver.write(count);
            count++;
        end
        write_driver.stall();

        // Write 5 more times to test the full condition
        for (int i = 0; i < 5; i++) begin
            write_driver.write(count);
            count++;
        end
        write_driver.stall();

        // Read data from FIFO until it is empty
        for (int i = 0; i < DEPTH; i++) begin
            read_driver.read();
        end
        read_driver.stall();
    endtask
    
    // Test reading from FIFO until it is empty
    task test_empty_condition();
        int count = 0;

        // Reset the FIFO
        fork
            write_driver.reset();
            read_driver.reset();
        join

        // Write data to FIFO until it is half full
        for (int i = 0; i < (DEPTH / 2); i++) begin
            write_driver.write(count);
            count++;
        end
        write_driver.stall();

        // Read data from FIFO so that it is no longer full
        for (int i = 0; i < (DEPTH / 2); i++) begin
            read_driver.read();
        end
        read_driver.stall();

        // Read data from FIFO 3 more times to test the empty condition
        for (int i = 0; i < 3; i++) begin
            read_driver.read();
        end
        read_driver.stall();

        // Write data to FIFO again until it is full
        for (int i = 0; i < DEPTH; i++) begin
            write_driver.write(count);
            count++;
        end
        write_driver.stall();

        // Read data from FIFO until it is empty
        for (int i = 0; i < DEPTH; i++) begin
            read_driver.read();
        end
        read_driver.stall();

        // Read 5 more times to test the empty condition
        for (int i = 0; i < 5; i++) begin
            read_driver.read();
        end
        read_driver.stall();
    endtask


    // <<<<< CLOCK SETUP >>>>>
    // Set up the clock signals for the write interface
    initial begin
        wclk = 1'b0;
        forever #(WCLK_PERIOD / 2) wclk = ~wclk;
    end

    // Set up the clock signals for the read interface
    initial begin
        rclk = 1'b0;
        forever #(RCLK_PERIOD / 2) rclk = ~rclk;
    end


    // <<<<< MAIN TESTBENCH PROCESS >>>>>
    initial begin
        // Set up the drivers and checker
        write_driver = new(fifo_wi);
        read_driver = new(fifo_ri);
        checker = new(fifo_wi, fifo_ri);

        // Reset the write and read drivers
        fork
            write_driver.reset();
            read_driver.reset();
        join

        // Run the checker
        checker.run();

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