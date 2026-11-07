`timescale 1ns/1ns

module fifo #(
  parameter DATA_WIDTH = 8,
  parameter ADDR_WIDTH = 4
) (
  fifo_rif.FIFO fifo_ri,
  fifo_wif.FIFO fifo_wi,
  input logic insert_bug
);  
  localparam MEMDEPTH = 1<<ADDR_WIDTH;
  
  logic [ADDR_WIDTH:0]   wptr, wrptr1, wrptr2, wrptr3;
  logic [ADDR_WIDTH:0]   rptr, rwptr1, rwptr2, rwptr3;
  logic [DATA_WIDTH-1:0] ex_mem [0:MEMDEPTH-1];

  logic [ADDR_WIDTH-1:0] write_counter;
  
  always @(posedge fifo_wi.wclk or negedge fifo_wi.wrst_n)
  begin
    if      (!fifo_wi.wrst_n) begin
      wptr <= 0;
      write_counter <= 0;
    end
    else if (fifo_wi.winc && !fifo_wi.full) begin
      // Drop the write if INSERT_BUG is set to 1 and the write_counter equals 5
      if (INSERT_BUG == 1'b1 && write_counter == 5) begin
        write_counter <= 0; // Reset the write counter
      end
      else begin
        ex_mem[wptr[ADDR_WIDTH-1:0]] <= fifo_wi.wdata;
        wptr                    <= wptr+1;
        write_counter <= write_counter + 1;
      end
    end
  end
  
  always @(posedge fifo_wi.wclk or negedge fifo_wi.wrst_n) 
  begin
    if (!fifo_wi.wrst_n) {wrptr3,wrptr2,wrptr1} <= 0;
    else         {wrptr3,wrptr2,wrptr1} <= {wrptr2,wrptr1,rptr};
  end

  always @(posedge fifo_ri.rclk or negedge fifo_ri.rrst_n)
  begin
    if      (!fifo_ri.rrst_n)         rptr <= 0;
    else if (fifo_ri.rinc && !fifo_ri.empty) rptr <= rptr+1;
  end

  always @(posedge fifo_ri.rclk or negedge fifo_ri.rrst_n)
  begin
    if (!fifo_ri.rrst_n) {rwptr3,rwptr2,rwptr1} <= 0;
    else         {rwptr3,rwptr2,rwptr1} <= {rwptr2,rwptr1,wptr};
  end

  assign fifo_ri.rdata = ex_mem[rptr[ADDR_WIDTH-1:0]];
  assign fifo_ri.empty = (rptr == rwptr3);
  assign fifo_wi.full  = ((wptr[ADDR_WIDTH-1:0] == wrptr3[ADDR_WIDTH-1:0]) &&
                   (wptr[ADDR_WIDTH]     != wrptr3[ADDR_WIDTH]    ));
endmodule