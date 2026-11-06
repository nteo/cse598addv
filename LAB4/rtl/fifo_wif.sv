// FIFO write interface
interface fifo_wif #(
    parameter int DATA_WIDTH = 8
) (input logic wclk);
    logic [DATA_WIDTH-1:0] wdata;
    logic winc;
    logic wrst_n;
    logic full;

    modport FIFO (
    input wclk,
	input wdata,
	input winc,
	input wrst_n,
	output full
    );

    modport CONTROLLER (
    input wclk,
	output wdata,
	output winc,
	output wrst_n,
	input full
    );

endinterface