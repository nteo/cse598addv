// Import the C function using DPI
import "DPI-C" function void reset_fifo();
import "DPI-C" function int  push_fifo(int data);        // returns 1 on model overflow
import "DPI-C" function int  pop_fifo(output int data);  // returns 1 on model underflow
import "DPI-C" function int  fifo_count();


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
class fifo_checker #(int DATA_WIDTH = 8, int DEPTH = 16, int SYNC_STAGES = 3);
    virtual fifo_wif write_vif;
    virtual fifo_rif read_vif;

    localparam int FLAG_LAG = SYNC_STAGES + 2;   // +1 slack for coincident edges

    int unsigned errors = 0, writes = 0, reads = 0;
    int wlag = 0, rlag = 0;

    function new(virtual fifo_wif write_vif, virtual fifo_rif read_vif);
        this.write_vif = write_vif;
        this.read_vif  = read_vif;
    endfunction

    function void report_fail(string msg);
        errors++;
        $error("[FAIL] %s (model count=%0d)", msg, fifo_count());
    endfunction

    function void report_pass(string msg);
        $display("[PASS] %s (model count=%0d)", msg, fifo_count());
    endfunction

    function bit in_reset();
        return (write_vif.wrst_n !== 1'b1) || (read_vif.rrst_n !== 1'b1);
    endfunction

    task run();
        reset_fifo();
        fork
            watch_reset();
            check_writes();
            check_reads();
        join_none
    endtask

    // The test tasks re-reset the DUT; the model must follow.
    task watch_reset();
        forever begin
            @(negedge write_vif.wrst_n or negedge read_vif.rrst_n);
            reset_fifo();
            wlag = 0;
            rlag = 0;
        end
    endtask

    task check_writes();
        bit valid_write;
        int cnt;
        forever begin
            @(posedge write_vif.wclk);
            if (in_reset()) begin
                wlag = 0;
                continue;
            end
            cnt = fifo_count();

            if ($isunknown(write_vif.full))
                report_fail("full is X/Z");

            // Safety: a truly full FIFO must report full
            if (cnt == DEPTH && write_vif.full !== 1'b1)
                report_fail("full NOT asserted while model is full");
            else if (cnt == DEPTH && write_vif.full === 1'b1)
                report_pass("full asserted while model is full");

            // Latency bound: full may linger after reads, but only briefly
            if (write_vif.full === 1'b1 && cnt < DEPTH) begin
                wlag++;
                if (wlag == FLAG_LAG + 1)
                    report_fail($sformatf("full stuck high > %0d wclk edges after space was freed", FLAG_LAG));
            end
            else wlag = 0;

            // Transaction: accepted by the DUT -> accepted by the model
            if (write_vif.winc === 1'b1 && write_vif.full === 1'b0) begin
                valid_write = 1;
                if ($isunknown(write_vif.wdata)) begin
                    report_fail("wdata is X/Z on an accepted write");
                    valid_write = 0;
                end
                if (push_fifo(int'(write_vif.wdata))) begin
                    report_fail("DUT accepted a write while model is full (overflow)");
                    valid_write = 0;
                end
                if (valid_write)
                    report_pass($sformatf("DUT successfully accepted a write: wdata=%0d", write_vif.wdata));
                writes++;
            end
        end
    endtask

    task check_reads();
        int cnt;
        int expd;
        forever begin
            @(posedge read_vif.rclk);
            if (in_reset()) begin
                rlag = 0;
                continue;
            end
            cnt = fifo_count();

            if ($isunknown(read_vif.empty))
                report_fail("empty is X/Z");

            // Safety: a truly empty FIFO must report empty
            if (cnt == 0 && read_vif.empty !== 1'b1)
                report_fail("empty NOT asserted while model is empty");
            else if (cnt == 0 && read_vif.empty === 1'b1)
                report_pass("empty asserted while model is empty");

            // Latency bound: empty may linger after writes, but only briefly
            if (read_vif.empty === 1'b1 && cnt > 0) begin
                rlag++;
                if (rlag == FLAG_LAG + 1)
                    report_fail($sformatf("empty stuck high > %0d rclk edges after data was written", FLAG_LAG));
            end
            else rlag = 0;

            // Transaction. rdata is first-word-fall-through (ex_mem[rptr]), so the
            // value sampled on this edge is the word being consumed.
            if (read_vif.rinc === 1'b1 && read_vif.empty === 1'b0) begin
                if (pop_fifo(expd))
                    report_fail("DUT accepted a read while model is empty (underflow)");
                else if (read_vif.rdata !== DATA_WIDTH'(expd))
                    report_fail($sformatf("READ DATA mismatch: expected=%0d actual=%0d",
                                  DATA_WIDTH'(expd), read_vif.rdata));
                else begin
                    report_pass($sformatf("READ DATA match: value=%0d", read_vif.rdata));
                end
                reads++;
            end
        end
    endtask
 
    function void report();
        $display("[CHK] writes=%0d reads=%0d errors=%0d residual_model_count=%0d",
                 writes, reads, errors, fifo_count());
        $display("[CHK] %s", (errors == 0) ? "PASS" : "FAIL");
    endfunction
endclass


//////////////////////
//Testbench
/////////////////////
module fifo_dpi_tb;
    timeunit 1ns;
    timeprecision 1ps;

    localparam int WCLK_PERIOD = 5;
    localparam int RCLK_PERIOD = 7;
    localparam int DATA_WIDTH = 8;
    localparam int ADDR_WIDTH = 4;
    localparam int DEPTH = 1 << ADDR_WIDTH;


    // <<<<< TESTBENCH SIGNALS >>>>>
    logic wclk, rclk;
    logic insert_bug;
    int test_num;   // define the test number (1, 2, or 3)

    fifo_wif #(DATA_WIDTH) fifo_wi(.*);
    fifo_rif #(DATA_WIDTH) fifo_ri(.*);


    // <<<<< TEST COMPONENTS INSTANTIATION >>>>>
    fifo dut(.*);
    fifo_write_driver #(DATA_WIDTH) write_driver;
    fifo_read_driver read_driver;
    fifo_checker #(DATA_WIDTH, DEPTH) checker;


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
        forever #(WCLK_PERIOD / 2.0) wclk = ~wclk;
    end

    // Set up the clock signals for the read interface
    initial begin
        rclk = 1'b0;
        forever #(RCLK_PERIOD / 2.0) rclk = ~rclk;
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

        // Check if there is an insert_bug flag from command line arguments
        insert_bug = $test$plusargs("INSERT_BUG");
        
        // Get the test number from command line arguments (default to running all tests if not provided)
        if (!$value$plusargs("TEST=%d", test_num)) begin
            test_num = 0; // Default to running all tests
        end

        case (test_num)
            1: begin
                $display("Running Test #1: Simultaneous Read and Write...");
                test_simultaneous_read_write();
                checker.report();
            end

            2: begin
                $display("Running Test #2: Full Condition...");
                test_full_condition();
                checker.report();
            end

            3: begin
                $display("Running Test #3: Empty Condition...");
                test_empty_condition();
                checker.report();
            end

            default: begin
                $display("Running Test #1: Simultaneous Read and Write...");
                test_simultaneous_read_write();
                checker.report();

                $display("\nRunning Test #2: Full Condition...");
                test_full_condition();
                checker.report();

                $display("\nRunning Test #3: Empty Condition...");
                test_empty_condition();
                checker.report();
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