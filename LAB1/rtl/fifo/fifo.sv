// Asynchronous FIFO
module fifo #(
    parameter int DATA_WIDTH = 8,
    parameter int ADDR_WIDTH = 4
) (
    fifo_if.FIFO fifo_i
);
    localparam MEM_DEPTH = 1 << ADDR_WIDTH; // The memory depth is 2^ADDR_WIDTH
    localparam ALMOST_FULL_THRESHOLD = MEM_DEPTH/4 * 3; // 75% full
    localparam ALMOST_EMPTY_THRESHOLD = MEM_DEPTH/4; // 25% full

    // All pointers have an extra bit to mark the full/empty condition
    logic [ADDR_WIDTH:0] wptr;
    logic [ADDR_WIDTH:0] rptr;
    logic [ADDR_WIDTH:0] wptr_next;
    logic [ADDR_WIDTH:0] rptr_next;

    // Graycode representation of pointers
    logic [ADDR_WIDTH:0] wgray;
    logic [ADDR_WIDTH:0] rgray;
    logic [ADDR_WIDTH:0] wgray_next;
    logic [ADDR_WIDTH:0] rgray_next;

    // Synchronized graycode pointers
    logic [ADDR_WIDTH:0] wgray_sync1;
    logic [ADDR_WIDTH:0] wgray_sync2;
    logic [ADDR_WIDTH:0] rgray_sync1;
    logic [ADDR_WIDTH:0] rgray_sync2;

    // Binary representation of synchronized graycode pointers
    logic [ADDR_WIDTH:0] wbin;
    logic [ADDR_WIDTH:0] rbin;

    // FIFO contents
    logic [DATA_WIDTH-1:0] fifo_mem [0:MEM_DEPTH-1];

    // Convert graycode back to binary for almost_full and almost_empty calc
    function automatic logic [ADDR_WIDTH:0] gray2bin(
        input logic [ADDR_WIDTH:0] gray
    );
        logic [ADDR_WIDTH:0] bin;

        bin[ADDR_WIDTH] = gray[ADDR_WIDTH];

        for (int i = ADDR_WIDTH-1; i >= 0; i--) begin
            bin[i] = bin[i+1] ^ gray[i];
        end

        return bin;
    endfunction

    // Increment wptr and rptr
    assign wptr_next = wptr + (fifo_i.winc && !fifo_i.full);
    assign rptr_next = rptr + (fifo_i.rinc && !fifo_i.empty);

    // Convert the next wptr and rptr values to graycode
    assign wgray_next = (wptr_next >> 1) ^ wptr_next;
    assign rgray_next = (rptr_next >> 1) ^ rptr_next;

    // Write control: write data to memory if not full and write enable is asserted
    // Update write pointer on write
    always_ff @(posedge fifo_i.wclk or negedge fifo_i.wrst_n) begin
        if (!fifo_i.wrst_n) begin
            wptr <= 0;
            wgray <= 0;
        end
        else begin
            if ((fifo_i.winc && !fifo_i.full)) begin
                fifo_mem[wptr[ADDR_WIDTH-1:0]] <= fifo_i.wdata;
            end
            wptr <= wptr_next;
            wgray <= wgray_next;
        end
    end

    // Read control: Update read pointer on read
    always_ff @(posedge fifo_i.rclk or negedge fifo_i.rrst_n) begin
        if (!fifo_i.rrst_n) begin
            rptr <= 0;
            rgray <= 0;
        end
        else begin
            rptr <= rptr_next;
            rgray <= rgray_next;
        end
    end
    
    // Read data from memory at the read pointer location
    assign fifo_i.rdata = fifo_mem[rptr[ADDR_WIDTH-1:0]];

    // Write gray code pointer synchronizer
    always_ff @(posedge fifo_i.rclk or negedge fifo_i.rrst_n) begin
        if (!fifo_i.rrst_n) begin
            wgray_sync1 <= 0;
            wgray_sync2 <= 0;
        end
        else begin
            wgray_sync1 <= wgray;
            wgray_sync2 <= wgray_sync1;
        end
    end

    // Read gray code pointer synchronizer
    always_ff @(posedge fifo_i.wclk or negedge fifo_i.wrst_n) begin
        if (!fifo_i.wrst_n) begin
            rgray_sync1 <= 0;
            rgray_sync2 <= 0;
        end
        else begin
            rgray_sync1 <= rgray;
            rgray_sync2 <= rgray_sync1;
        end
    end

    // FIFO is empty when the read gray pointer equals the write gray pointer
    assign fifo_i.empty = (rgray == wgray_sync2);

    // When the FIFO is full, the graycode pointer will have form {2'b11, (ADDR_WIDTH-1)'(0)}
    // as a reslt of how the graycode is calculated. Then, we invert the top 2 bits to compare.
    assign fifo_i.full = (wgray == 
                            {~rgray_sync2[ADDR_WIDTH:ADDR_WIDTH-1], 
                            rgray_sync2[ADDR_WIDTH-2:0]});

    // Convert the graycode back to binary in order to evaluate almost_full and almost_empty
    assign wbin = gray2bin(wgray);
    assign rbin = gray2bin(rgray);

    // Due to the wrap bit, we can subtract the two pointers to find the number of items in the FIFO
    assign fifo_i.almost_full = (wbin - rbin) >= ALMOST_FULL_THRESHOLD;
    assign fifo_i.almost_empty = (wbin - rbin) <= ALMOST_EMPTY_THRESHOLD;
endmodule

