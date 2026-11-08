// FIFO read interface
interface fifo_rif #(
    parameter int DATA_WIDTH = 8
) (input logic rclk);
    logic rinc;
    logic rrst_n;
    logic [DATA_WIDTH-1:0] rdata;
    logic empty;

    modport FIFO (
    input rclk,
	input rinc,
	input rrst_n,
	output rdata,
	output empty
    );

    modport CONTROLLER (
    input rclk,
	output rinc,
	output rrst_n,
	input rdata,
	input empty
    );

endinterface