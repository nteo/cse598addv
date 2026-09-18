// Asynchronous FIFO
module fifo #(
    parameter int DATA_WIDTH = 8,
    parameter int ADDR_WIDTH = 4
) (
    fifo_if.FIFO fifo_i
);
    logic [ADDR_WIDTH-1:0] wptr;
    logic [ADDR_WIDTH-1:0] wrptr1;
    logic [ADDR_WIDTH-1:0] wrptr2;
    logic [ADDR_WIDTH-1:0] wrptr3;

    logic [ADDR_WIDTH-1:0] rptr;
    logic [ADDR_WIDTH-1:0] rwptr1;
    logic [ADDR_WIDTH-1:0] rwptr2;
    logic [ADDR_WIDTH-1:0] rwptr3;

    localparam MEM_DEPTH = 1 << ADDR_WIDTH;

    logic [DATA_WIDTH-1:0] ex_mem [0:MEM_DEPTH-1];

    always_ff @(posedge fifo_i.wclk or negedge fifo_i.wrst_n) begin
        if (!fifo_i.wrst_n) begin
            wptr <= 0;
        end
        else if (fifo_i.winc && !fifo_i.wfull) begin
            ex_mem[wptr[ADDR_WIDTH-1:0]] <= fifo_i.wdata;
            wptr			             <= wptr + 1;
        end
    end

    always_ff @(posedge fifo_i.wclk or negedge fifo_i.wrst_n) begin
	if (!fifo_i.wrst_n) begin
	    {wrptr3, wrptr2, wrptr1} <= 0;
	end
	else begin
	    {wrptr3, wrptr2, wrptr1} <= {wrptr2, wrptr1, rptr};
	end
    end

    always_ff @(posedge fifo_i.rclk or negedge fifo_i.rrst_n) begin
	if (!fifo_i.rrst_n) begin
	    rptr <= 0;
	end
	else if (fifo_i.rinc && !fifo_i.rempty) begin
	    rptr <= rptr+1;
	end
    end

    always_ff @(posedge fifo_i.rclk or negedge fifo_i.rrst_n) begin
	if (!fifo_i.rrst_n) begin
	    {rwptr3, rwptr2, rwptr1} <= 0;
	end
	else begin
	    {rwptr3, rwptr2, rwptr1} <= {rwptr2, rwptr1, wptr};
	end
    end

    assign fifo_i.rdata = ex_mem[rptr[ADDR_WIDTH-1:0]];
    assign fifo_i.rempty = (rptr == rwptr3);
    assign fifo_i.wfull = ((wptr[ADDR_WIDTH-2:0] == wrptr3[ADDR_WIDTH-2:0]) 
    		              && (wptr[ADDR_WIDTH-1] != wrptr3[ADDR_WIDTH-1]));
endmodule

