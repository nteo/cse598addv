// FIFO read interface
interface fifo_rif #(
    parameter int DATA_WIDTH = 8
);
    logic rinc;
    logic rclk;
    logic rrst_n;
    logic [DATA_WIDTH-1:0] rdata;
    logic empty;

    modport FIFO (
	input rinc,
	input rclk,
	input rrst_n,
	output rdata,
	output empty
    );

    modport CONTROLLER (
	output rinc,
	output rclk,
	output rrst_n,
	input rdata,
	input empty
    );

endinterface