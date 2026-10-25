module tb_fp8_mul;

    logic clk;
    logic rst;
    logic [7:0] A;
    logic [7:0] B;
    logic [7:0] result;
    logic [4:0] flags;

    integer pass_count;
    integer fail_count;

    // Instantiate DUT
    fp8_mul dut (
        .clk(clk),
        .rst(rst),
        .A(A),
        .B(B),
        .result(result),
        .flags(flags)
    );

    // Clock: 10 ns period
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // Apply one test and compare the result
    task automatic check_result(
        input string test_name,
        input logic [7:0] test_A,
        input logic [7:0] test_B,
        input logic [7:0] expected
    );
        begin
            A = test_A;
            B = test_B;

            // Allow combinational logic to settle
            #2;

            if (result === expected) begin
                $display(
                    "PASS: %-24s A=%02h B=%02h Result=%02h Expected=%02h Flags=%05b",
                    test_name, A, B, result, expected, flags
                );
                pass_count = pass_count + 1;
            end
            else begin
                $display(
                    "FAIL: %-24s A=%02h B=%02h Result=%02h Expected=%02h Flags=%05b",
                    test_name, A, B, result, expected, flags
                );
                fail_count = fail_count + 1;
            end
        end
    endtask

    initial begin
        // Initialize
        rst = 1'b1;
        A = 8'h00;
        B = 8'h00;
        pass_count = 0;
        fail_count = 0;

        // Allow reset to settle
        #12;
        rst = 1'b0;
        #2;

        $display("\n===== FP8 E3M4 MULTIPLIER TESTS =====");

        // Basic multiplication
        check_result("1.0 * 1.0",       8'h30, 8'h30, 8'h30);
        check_result("1.0 * 2.0",       8'h30, 8'h40, 8'h40);
        check_result("2.0 * 2.0",       8'h40, 8'h40, 8'h50);

        // Fractional multiplication
        check_result("1.5 * 1.0",       8'h38, 8'h30, 8'h38);
        check_result("1.5 * 1.5",       8'h38, 8'h38, 8'h42);
        check_result("0.5 * 0.5",       8'h20, 8'h20, 8'h10);

        // Sign handling
        check_result("-1.0 * 1.0",      8'hB0, 8'h30, 8'hB0);
        check_result("-1.0 * -1.0",     8'hB0, 8'hB0, 8'h30);
        check_result("-1.5 * 1.0",      8'hB8, 8'h30, 8'hB8);

        // Zero operand
        check_result("0.0 * 1.0",       8'h00, 8'h30, 8'h00);

        // Overflow: 4.0 * 4.0 = 16.0
        // Expected saturation to maximum finite positive value
        check_result("Overflow: 4.0 * 4.0", 8'h50, 8'h50, 8'h6F);

        // Summary
        $display("\n===== TEST SUMMARY =====");
        $display("Passed: %0d", pass_count);
        $display("Failed: %0d", fail_count);
        $display("Total:  %0d", pass_count + fail_count);

        if (fail_count == 0)
            $display("ALL TESTS PASSED");
        else
            $display("SOME TESTS FAILED");

        $finish;
    end

endmodule
