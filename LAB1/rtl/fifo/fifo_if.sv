// FIFO interface
interface fifo_if #(
    parameter int DATA_WIDTH = 8,
    parameter int ADDR_WIDTH = 4
);
    logic [DATA_WIDTH-1:0] wdata;
    logic winc;
    logic wclk;
    logic wrst_n;
    logic rinc;
    logic rclk;
    logic rrst_n;
    logic [DATA_WIDTH-1:0] rdata;
    logic wfull;
    logic rempty;

    modport FIFO (
	input wdata,
	input winc,
	input wclk,
	input wrst_n,
	input rinc,
	input rclk,
	input rrst_n,
	output rdata,
	output wfull,
	output rempty
    );

    modport CONTROLLER (
	output wdata,
	output winc,
	output wclk,
	output wrst_n,
	output rinc,
	output rclk,
	output rrst_n,
	input rdata,
	input wfull,
	input rempty
    );

endinterface
