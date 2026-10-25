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

    // 10 ns clock period
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // Apply test and compare result
    task automatic check_result(
        input string test_name,
        input logic [7:0] test_A,
        input logic [7:0] test_B,
        input logic [7:0] expected
    );
        begin
            @(negedge clk);
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
        rst = 1'b1;
        A = 8'h00;
        B = 8'h00;
        pass_count = 0;
        fail_count = 0;

        repeat (2) @(negedge clk);
        rst = 1'b0;

        $display("\n===== FP8 E3M4 MULTIPLIER TESTS =====");

        // 1. Positive x Positive: 1.0 * 2.0 = 2.0
        check_result("Positive x Positive",
                     8'h30, 8'h40, 8'h40);

        // 2. Negative x Negative: (-1.0) * (-2.0) = 2.0
        check_result("Negative x Negative",
                     8'hB0, 8'hC0, 8'h40);

        // 3. Positive x Negative: 1.5 * (-1.0) = -1.5
        check_result("Positive x Negative",
                     8'h38, 8'hB0, 8'hB8);

        // 4. Result in infinity: +infinity * 1.0 = +infinity
        // Assumes infinity is encoded as sign | 111 | 0000.
        check_result("Result in infinity",
                     8'h70, 8'h30, 8'h70);

        // 5. Overflow: 4.0 * 4.0 = 16.0
        // With saturation, result is maximum finite positive = 15.5.
        check_result("Overflow",
                     8'h50, 8'h50, 8'h6F);

        $display("\n===== TEST SUMMARY =====");
        $display("Passed: %0d", pass_count);
        $display("Failed: %0d", fail_count);
        $display("Total:  %0d", pass_count + fail_count);

        if (fail_count == 0)
            $display("ALL TESTS PASSED");
        else
            $display("SOME TESTS FAILED");
        #20;
        $finish;
    end

endmodule
