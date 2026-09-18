`timescale 1ns/1ps

// Example top module for fifo.sv
module fifo_tb;

    localparam DATA_WIDTH = 8;
    localparam ADDR_WIDTH = 4;

    // Testbench signals
    fifo_if fifo_i();

    fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) fifo (
        .*
    );

    initial begin
        fifo_i.wdata = DATA_WIDTH'(0);
        fifo_i.winc = 1'b0;
        fifo_i.wclk = 1'b0;
        fifo_i.wrst_n = 1'b1;
        fifo_i.rinc = 1'b0;
        fifo_i.rclk = 1'b0;
        fifo_i.rrst_n = 1'b1;
    end
endmodule

    
