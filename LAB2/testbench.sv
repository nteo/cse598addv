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

    always @(posedge clk or posedge reset) begin
        if (reset)
            cycles = 0;
        else
            cycles++;
    end

   initial begin
        reset = 1;
        errors = 0;

        // Initialize instruction/data memories as required
        // by your existing testbench.

        repeat (2) @(posedge clk);
        reset = 0;

        // Allow the program to progress through
        // the pipeline.
        repeat (20) @(posedge clk);

        // Check final register values.
        if (dut.mips.dp.rf.rf[3] !== 32'd2)  begin $display("FAIL: $3 exp 2, got %0d",  dut.mips.dp.rf.rf[3]); errors++; end
        if (dut.mips.dp.rf.rf[4] !== 32'd3)  begin $display("FAIL: $4 exp 3, got %0d",  dut.mips.dp.rf.rf[4]); errors++; end
        if (dut.mips.dp.rf.rf[7] !== 32'd13) begin $display("FAIL: $7 exp 13, got %0d", dut.mips.dp.rf.rf[7]); errors++; end
        if (dut.mips.dp.rf.rf[5] !== 32'd11) begin $display("FAIL: $5 (cycles) exp 11, got %0d", dut.mips.dp.rf.rf[5]); errors++; end
        if (dut.mips.dp.rf.rf[6] !== 32'd8)  begin $display("FAIL: $6 (insts) exp 8, got %0d",   dut.mips.dp.rf.rf[6]); errors++; end

        if (errors == 0)
            $display("PASS: Perfmon results are correct");
        else
            $display("FAIL: %0d errors", errors);

        $finish;
   end

    // Dump waves
    initial begin
        $fsdbDumpfile("novas.fsdb");
        $fsdbDumpvars(0, MIPS_ControlHazard_Testbench);
    end
endmodule