module tb_fp8_add;

    logic [7:0] A;
    logic [7:0] B;
    logic [7:0] Result;
    logic [4:0] Flags;

    integer pass_count;
    integer fail_count;

    // Instantiate DUT
    fp8_add dut (
        .A(A),
        .B(B),
        .Result(Result),
        .Flags(Flags)
    );

    // Apply a test and compare the result
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
            #10;

            if (Result === expected) begin
                $display(
                    "PASS: %-24s A=%02h B=%02h Result=%02h Expected=%02h Flags=%05b",
                    test_name, A, B, Result, expected, Flags
                );
                pass_count = pass_count + 1;
            end
            else begin
                $display(
                    "FAIL: %-24s A=%02h B=%02h Result=%02h Expected=%02h Flags=%05b",
                    test_name, A, B, Result, expected, Flags
                );
                fail_count = fail_count + 1;
            end
        end
    endtask

    initial begin
        A = 8'h00;
        B = 8'h00;
        pass_count = 0;
        fail_count = 0;

        $display("\n===== FP8 E3M4 ADD TESTS =====");

        // 1. Positive + positive: 1.0 + 1.0 = 2.0
        check_result("Positive + positive",
                     8'h30, 8'h30, 8'h40);

        // 2. Negative + negative: -1.0 + -1.0 = -2.0
        check_result("Negative + negative",
                     8'hB0, 8'hB0, 8'hC0);

        // 3. Positive + negative: 2.0 + (-0.5) = 1.5
        check_result("Positive + negative",
                     8'h40, 8'hA0, 8'h38);

        // 4. Result in zero: 1.0 + (-1.0) = 0
        check_result("Result in zero",
                     8'h30, 8'hB0, 8'h00);

        // 5. Overflow: 15.5 + 15.5 = 31.0
        // Saturates to maximum finite value, +15.5
        check_result("Overflow",
                     8'h6F, 8'h6F, 8'h6F);

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
