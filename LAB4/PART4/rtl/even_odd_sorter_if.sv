// even_odd_sorter interface
interface even_odd_sorter_if #(
    parameter int DATA_WIDTH = 8
);
    logic                    clk;
    logic                    rst_n;
    logic [DATA_WIDTH-1:0]   data_in;
    logic                    write_en;
    logic [DATA_WIDTH-1:0]   data_out;
    logic                    read_en;

    modport EVEN_ODD (
    input clk,
	input rst_n,
	input data_in,
	input write_en,
    output data_out,
    input read_en
    );

    modport CONTROLLER (
    output clk,
	output rst_n,
	output data_in,
	output write_en,
    input data_out,
    output read_en
    );

    // if data is even, even winc should be 1
    property even_data_write;
        @(posedge clk)
        disable iff (!rst_n)
        (write_en && !data_in[0]) |-> (even_odd_sorter_tb.dut.even_fifo_wi.winc);
    endproperty

    // if data is odd, odd winc should be 1
    property odd_data_write;
        @(posedge clk)
        disable iff (!rst_n)
        (write_en && data_in[0]) |-> (even_odd_sorter_tb.dut.odd_fifo_wi.winc);
    endproperty

    // if even FIFO is empty, even rinc should be 0
    property even_fifo_empty;
        @(posedge clk)  
        disable iff (!rst_n)
        (even_odd_sorter_tb.dut.even_fifo_ri.empty) |-> (!even_odd_sorter_tb.dut.even_fifo_ri.rinc);
    endproperty

    // if odd FIFO is empty, odd rinc should be 0
    property odd_fifo_empty;
        @(posedge clk)
        disable iff (!rst_n)
        (even_odd_sorter_tb.dut.odd_fifo_ri.empty) |-> (!even_odd_sorter_tb.dut.odd_fifo_ri.rinc);
    endproperty

    // if we are reading, the output should alternate (data_out[0] != next_data_out[0])
    property alt_fifo_out;
        @(posedge clk)
        disable iff (!rst_n)
        (read_en && 
        (even_odd_sorter_tb.dut.even_fifo_ri.rinc || even_odd_sorter_tb.dut.odd_fifo_ri.rinc) && 
        (even_odd_sorter_tb.dut.output_selector_inst.data_out != 'x))
        |=> (even_odd_sorter_tb.dut.output_selector_inst.data_out[0] != $past(even_odd_sorter_tb.dut.output_selector_inst.data_out[0]));
    endproperty

    assert property (even_data_write);
    assert property (odd_data_write);
    assert property (even_fifo_empty);
    assert property (odd_fifo_empty);
    assert property (alt_fifo_out);

endinterface