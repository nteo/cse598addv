// FIFO interface
interface fifo_if #(
    parameter int DATA_WIDTH = 8
);
    logic [DATA_WIDTH-1:0] wdata;
    logic winc;
    logic wclk;
    logic wrst_n;
    logic rinc;
    logic rclk;
    logic rrst_n;
    logic [DATA_WIDTH-1:0] rdata;
    logic full;
    logic empty;
	logic almost_full;
	logic almost_empty;

    modport FIFO (
	input wdata,
	input winc,
	input wclk,
	input wrst_n,
	input rinc,
	input rclk,
	input rrst_n,
	output rdata,
	output full,
	output empty,
	output almost_full,
	output almost_empty
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
	input full,
	input empty,
	input almost_full,
	input almost_empty
    );

endinterface
