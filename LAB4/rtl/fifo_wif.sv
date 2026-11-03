// FIFO write interface
interface fifo_wif #(
    parameter int DATA_WIDTH = 8
);
    logic [DATA_WIDTH-1:0] wdata;
    logic winc;
    logic wclk;
    logic wrst_n;
    logic full;

    modport FIFO (
	input wdata,
	input winc,
	input wclk,
	input wrst_n,
	output full
    );

    modport CONTROLLER (
	output wdata,
	output winc,
	output wclk,
	output wrst_n,
	input full
    );

endinterface