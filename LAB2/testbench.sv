///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Testbench for pipelined MIPS processor
// - Checks the final memory write
// - Checks that the BEQ flush executes
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
module MIPS_Testbench ();
    logic clk;
    logic reset;
    logic [31:0] writedata, dataadr;
    logic memwrite;

    integer branch_flush_count;
    integer i;

    parameter N = 1;
    logic [31:0] expected_data[N:1];
    logic [31:0] expected_addr[N:1];

    top dut(
        .clk(clk),
        .reset(reset),
        .writedata(writedata),
        .dataadr(dataadr),
        .memwrite(memwrite)
    );

    // Expected memory write: 48 to address 0
    initial begin
        expected_data[1] = 32'h30;
        expected_addr[1] = 32'h00;
    end

    // Clock generation
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // Reset
    initial begin
        reset = 1'b1;
        repeat (2) @(posedge clk);
        @(negedge clk);
        reset = 1'b0;
    end

    // Initialize branch flush counter
    initial branch_flush_count = 0;

    // Check BEQ flush behavior only
    always @(posedge clk) begin
        if (!reset && dut.mips.dp.pcsrcD === 1'b1) begin
            branch_flush_count = branch_flush_count + 1;

            $display("Taken BEQ detected at time %0t", $time);

            // Allow pipeline registers to update
            #1;

            // Verify IF/ID was flushed
            if (dut.mips.dp.instrD !== 32'b0) begin
                $display("ERROR: IF/ID was not flushed; instrD = %h",
                        dut.mips.dp.instrD);
            end else begin
                $display("IF/ID flushed successfully");
            end

            // Verify ID/EX has no register-write or memory-write side effects
            if (dut.mips.dp.regwriteE !== 1'b0 ||
                dut.mips.dp.memwriteE !== 1'b0) begin
                $display("ERROR: ID/EX control signals were not flushed");
            end else begin
                $display("ID/EX control signals cleared successfully");
            end
        end
    end

    // Simulation timeout
    initial begin
        #5000;
        $display("ERROR: Simulation timed out.");
        $display("PC = %h, memwrite = %b, dataadr = %h, writedata = %h",
                 dut.pc, memwrite, dataadr, writedata);
        $display("BEQ flushes detected: %0d", branch_flush_count);
        $finish;
    end

    // Check expected memory write
    initial begin
        wait (reset == 1'b0);

        for (i = 1; i <= N; i = i + 1) begin
            @(posedge memwrite);
            #1;

            if (dataadr === expected_addr[i] &&
                writedata === expected_data[i]) begin
                $display("Memory write %0d successful: wrote %h to address %h",
                         i, writedata, dataadr);
            end else begin
                $display("ERROR: Memory write %0d: wrote %h to address %h; Expected %h to address %h",
                         i, writedata, dataadr,
                         expected_data[i], expected_addr[i]);
            end
        end

        @(negedge clk);

        $display("----------------------------------------");
        $display("BEQ flushes detected: %0d", branch_flush_count);

        if (branch_flush_count > 0)
            $display("PASS: Taken BEQ flush detected.");
        else
            $display("ERROR: No taken BEQ flush detected.");

        $display("TEST COMPLETE");
        $finish;
    end
endmodule