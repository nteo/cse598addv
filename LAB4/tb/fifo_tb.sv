module fifo_tb;
    localparam DATA_WIDTH = 8;
    localparam ADDR_WIDTH = 4;

    // Testbench signals
    logic wclk;
    logic rclk;
    fifo_rif fifo_ri(rclk);
    fifo_wif fifo_wi(wclk);
    logic [DATA_WIDTH-1:0] read_data;

    // Set wclk freq
    initial begin
        wclk = 1'b0;
        forever wclk = #5 ~wclk;
    end

    // Set rclk freq
    initial begin
        rclk = 1'b0;
        forever rclk = #7 ~rclk;
    end

    // Instantiate DUT
    fifo #(
        .DATA_WIDTH(DATA_WIDTH)
    ) fifo (
        .fifo_ri(fifo_ri),
        .fifo_wi(fifo_wi)
    );

    // Write function
    task write(input logic [DATA_WIDTH-1:0] data);
        @(negedge fifo_wi.wclk);
        fifo_wi.wdata = data;
        fifo_wi.winc = 1'b1;
        @(negedge fifo_wi.wclk);
        fifo_wi.winc = 1'b0;
    endtask

    // Read function
    task read(output logic [DATA_WIDTH-1:0] data);
        @(negedge fifo_ri.rclk)
        data = fifo_ri.rdata;
        fifo_ri.rinc = 1'b1;
        @(negedge fifo_ri.rclk);
        fifo_ri.rinc = 1'b0;
    endtask

    // Reset the FIFO
    task reset_fifo();
        fifo_wi.wrst_n = 1'b0;
        fifo_ri.rrst_n = 1'b0;
        fifo_wi.wdata = 0;
        fifo_wi.winc = 0;
        fifo_ri.rinc = 0;
        @(posedge fifo_wi.wclk);
        @(posedge fifo_ri.rclk);
        fifo_wi.wrst_n = 1'b1;
        fifo_ri.rrst_n = 1'b1;
    endtask
    
    // Create testbench components
    mailbox #(transaction) txn_mail;
    monitor #(DATA_WIDTH, ADDR_WIDTH) mon;
    scoreboard #(DATA_WIDTH, ADDR_WIDTH) sb;
    
    initial begin
        txn_mail = new();
        sb = new(txn_mail);
        mon = new(fifo_ri, fifo_wi);
        mon.txn_mail = txn_mail;
        fork
            mon.run();
            sb.run();
        join
    end

    // Testbench
    initial begin
        // Reset FIFO
        reset_fifo();

        // Write data to FIFO
        for (int i = 0; i <= (1 << ADDR_WIDTH); i++) begin
            write(i);
        end

        // Read data from FIFO
        for (int i = 0; i <= (1 << ADDR_WIDTH) + 1; i++) begin
            read(read_data);
        end

        // Fill up the FIFO with some elements to deassert the empty flag
        #5;
        write(1);
        write(2);
        write(3);
        write(4);

        // Wait until neither clock is on a posedge, then trigger both write and read
        #20;
        fifo_wi.winc = 1'b1;
        fifo_ri.rinc = 1'b1;
        fifo_wi.wdata = DATA_WIDTH'(5);
        @(posedge fifo_ri.rclk);
        @(posedge fifo_wi.wclk);
        #1;
        fifo_wi.winc = 1'b0;
        fifo_ri.rinc = 1'b0;

        #20;

        $finish;
    end

    // Dump waves
    initial begin
        $fsdbDumpfile("novas.fsdb");
        $fsdbDumpvars(0, fifo_tb);
    end
    
endmodule