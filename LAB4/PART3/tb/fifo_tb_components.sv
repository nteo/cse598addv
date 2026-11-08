class transaction #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 4
);
    
    logic [DATA_WIDTH-1:0] rdata;
    logic [DATA_WIDTH-1:0] wdata;
    logic rinc;
    logic winc;
    logic empty;
    logic full;
    time timestamp;

    function new();
    endfunction

endclass

class monitor #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 4
);

    virtual fifo_rif fifo_vrif;
    virtual fifo_wif fifo_vwif;
    int verbosity;
    
    mailbox #(transaction) txn_mail;
    transaction #(DATA_WIDTH, ADDR_WIDTH) rtxn;
    transaction #(DATA_WIDTH, ADDR_WIDTH) wtxn;

    function new(virtual fifo_rif fifo_vrif, virtual fifo_wif fifo_vwif);
        txn_mail = new();
        this.fifo_vrif = fifo_vrif;
        this.fifo_vwif = fifo_vwif;
    endfunction

    task run();
        verbosity = 0;
        if ($test$plusargs("VERBOSE"))
            $value$plusargs("VERBOSE=%d", verbosity);
        else
            $display("VERBOSE flag not set.");

        fork
            // Sample for write transactions (write)
            forever begin
                @(posedge fifo_vwif.wclk);
                if (fifo_vwif.winc) begin
                    wtxn = new();
                    wtxn.wdata = fifo_vwif.wdata;
                    wtxn.winc = fifo_vwif.winc;
                    wtxn.full = fifo_vwif.full;
                    wtxn.empty = 1'bx;
                    wtxn.rinc = 1'b0;
                    wtxn.rdata = 'x;
                    wtxn.timestamp = $time;
                    txn_mail.put(wtxn);
                    if (verbosity == 1)
                        $display("Write transaction created at time = %0t", $time);
                    else if (verbosity == 2) begin
                        $display("Write transaction created at time = %0t with properties:\nWDATA = %0h\nWINC = %0b\nFULL = %0b", 
                                    wtxn.timestamp, wtxn.wdata, wtxn.winc, wtxn.full);
                    end
                end
            end

            // Sample for read transactions (read)
            forever begin
                rtxn = new();
                rtxn.rdata = fifo_vrif.rdata;
                @(posedge fifo_vrif.rclk);
                if (fifo_vrif.rinc) begin
                    rtxn.rinc = fifo_vrif.rinc;
                    rtxn.empty = fifo_vrif.empty;
                    rtxn.full = 1'bx;
                    rtxn.winc = 1'b0;
                    rtxn.wdata = 'x;
                    rtxn.timestamp = $time;
                    txn_mail.put(rtxn);
                    if (verbosity == 1)
                        $display("Read transaction created at time = %0t", $time);
                    else if (verbosity == 2) begin
                        $display("Read transaction created at time = %0t with properties:\nRDATA = %0h\nRINC = %0b\nEMPTY = %0b", 
                                    rtxn.timestamp, rtxn.rdata, rtxn.rinc, rtxn.empty);
                    end
                end
            end
        join
    endtask
endclass

class scoreboard #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 4
);
    localparam MEM_DEPTH = 1 << ADDR_WIDTH;

    mailbox #(transaction) txn_mail;
    transaction #(DATA_WIDTH, ADDR_WIDTH) txn;
    logic [DATA_WIDTH-1:0] q[$];
    logic expected_full;
    logic expected_empty;
    logic [DATA_WIDTH-1:0] expected_rdata;
    int error_count;
    int pass_count;

    function new(mailbox #(transaction) txn_mail);
        this.txn_mail = txn_mail;
    endfunction

    task run();
        error_count = 0;
        pass_count = 0;
        forever begin
            txn_mail.get(txn);
            
            //===== REFERENCE MODEL=====
            // Write transaction
            if (txn.winc) begin
                expected_full = (q.size() == MEM_DEPTH);

                // Check FIFO status
                if (txn.full != expected_full) begin
                    error_count += 1;
                    $error("FIFO FULL MISMATCH at time %0t. Expected: %0b, Observed: %0b", 
                            txn.timestamp, expected_full, txn.full);
                end

                if (!expected_full)
                    q.push_back(txn.wdata);
            end
            
            // Read transaction
            if (txn.rinc) begin
                expected_empty = (q.size() == 0);

                // Check FIFO status
                if (txn.empty != expected_empty) begin
                    error_count += 1;
                    $error("FIFO EMPTY MISMATCH at time %0t. Expected: %0b, Observed: %0b", 
                            txn.timestamp, expected_empty, txn.empty);
                end

                if (!expected_empty) begin
                    expected_rdata = q.pop_front();
                    if (expected_rdata !== txn.rdata) begin
                        error_count += 1;
                        $error("FIFO READ MISMATCH at time %0t. Expected: %0h, Observed: %0h", 
                        txn.timestamp, expected_rdata, txn.rdata);
                    end
                    else begin
                        $display("FIFO READ SUCCESS at time %0t. Expected: %0h, Observed: %0h", 
                        txn.timestamp, expected_rdata, txn.rdata);
                    end
                end
            end
        end
    endtask
endclass