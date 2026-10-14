///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// BEQ Control Hazard Testbench
// Tests branch redirect, IF/ID flush, ID/EX bubble, and final program result.
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
module MIPS_ControlHazard_Testbench;

    logic clk;
    logic reset;
    logic [31:0] writedata, dataadr;
    logic memwrite;

    integer errors;
    integer write_count;
    integer cycles;

    top dut(
        .clk(clk),
        .reset(reset),
        .writedata(writedata),
        .dataadr(dataadr),
        .memwrite(memwrite)
    );

    // Clock: 10 time-unit period
    initial clk = 1'b0;
    always #5 clk = ~clk;

   initial begin
        reset = 1;
        errors = 0;

        // Initialize instruction/data memories as required
        // by your existing testbench.

        repeat (2) @(posedge clk);
        reset = 0;

        // Allow the ADD instructions to progress through
        // the pipeline.
        repeat (20) @(posedge clk);

        // Check final register values.
        if (dut.mips.dp.rf.rf[3] !== 32'd2) begin
            $display("FAIL: $3 expected 2, got %0d",
                    dut.mips.dp.rf.rf[3]);
            errors = errors + 1;
        end

        if (dut.mips.dp.rf.rf[4] !== 32'd3) begin
            $display("FAIL: $4 expected 3, got %0d",
                    dut.mips.dp.rf.rf[4]);
            errors = errors + 1;
        end

        if (dut.mips.dp.rf.rf[5] !== 32'd5) begin
            $display("FAIL: $5 expected 5, got %0d",
                    dut.mips.dp.rf.rf[5]);
            errors = errors + 1;
        end

        if (dut.mips.dp.rf.rf[6] !== 32'd8) begin
            $display("FAIL: $6 expected 8, got %0d",
                    dut.mips.dp.rf.rf[6]);
            errors = errors + 1;
        end

        if (dut.mips.dp.rf.rf[7] !== 32'd13) begin
            $display("FAIL: $7 expected 13, got %0d",
                    dut.mips.dp.rf.rf[7]);
            errors = errors + 1;
        end

        if (errors == 0)
            $display("PASS: ADD forwarding results are correct");
        else
            $display("FAIL: %0d errors", errors);

        $finish;
   end
endmodule