`timescale 1ns/1ps

// Example top module for fifo.sv
module fifo_tb;
    localparam DATA_WIDTH = 8;
    localparam ADDR_WIDTH = 4;

    // Testbench signals
    fifo_if fifo_i();

    initial begin
        fifo_i.wclk = 1'b0;
        forever fifo_i.wclk = #5 ~fifo_i.wclk;
    end

    initial begin
        fifo_i.rclk = 1'b0;
        forever fifo_i.rclk = #7 ~fifo_i.rclk;
    end

    fifo #(
        .DATA_WIDTH(DATA_WIDTH)
    ) fifo (
        .*
    );

    task write(input logic [DATA_WIDTH-1:0] data);
        fifo_i.wdata = data;
        fifo_i.winc = 1'b1;
        @(posedge fifo_i.wclk);
        fifo_i.winc = 1'b0;
    endtask

    task read(output logic [DATA_WIDTH-1:0] data);
        fifo_i.rinc = 1'b1;
        @(posedge fifo_i.rclk);
        data = fifo_i.rdata;
        fifo_i.rinc = 1'b0;
    endtask

    task check_read(input logic [DATA_WIDTH-1:0] expected_data);
        logic [DATA_WIDTH-1:0] read_data;
        read(read_data);
        if (read_data !== expected_data) begin
            $display("Error: Expected %0d, got %0d", expected_data, read_data);
        end else begin
            $display("Read successful: %0d", read_data);
        end
    endtask

    task reset_fifo();
        fifo_i.wrst_n = 1'b0;
        fifo_i.rrst_n = 1'b0;
        fifo_i.wdata = 0;
        fifo_i.winc = 0;
        fifo_i.rinc = 0;
        @(posedge fifo_i.wclk);
        @(posedge fifo_i.rclk);
        fifo_i.wrst_n = 1'b1;
        fifo_i.rrst_n = 1'b1;
    endtask

    initial begin
        // Reset FIFO
        reset_fifo();

        // Write data to FIFO
        for (int i = 0; i < (1 << ADDR_WIDTH); i++) begin
            write(i);
            $display("Wrote: %0d", i);
            if (i == (1 << ADDR_WIDTH)/4 * 3) begin
                assert (fifo_i.almost_full == 1'b1)
                    else $error("Error: expected almost_full to be 1");
            end
        end

        assert (fifo_i.full == 1'b1)
            else $error("Error: expected full to be 1");

        // Read data from FIFO
        for (int i = 0; i < (1 << ADDR_WIDTH); i++) begin
            check_read(i);
            if (i == (1 << ADDR_WIDTH)/4) begin
                assert (fifo_i.almost_empty == 1'b1)
                    else $error("Error: expected almost_empty to be 1");
            end
        end

        assert (fifo_i.empty == 1'b1)
            else $error("Error: expected empty to be 1");

        #50;

        $finish;
    end

    initial begin
        $fsdbDumpfile("novas.fsdb");
        $fsdbDumpvars(0, fifo_tb);
    end
    
endmodule

    
