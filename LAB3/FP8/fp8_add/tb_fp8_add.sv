// tb_fp8_add.sv

module tb_fp8_add;

    logic [7:0] A;
    logic [7:0] B;
    logic [7:0] Result;
    logic [4:0] Flags;

    integer tests;
    integer errors;

    // Assumed flag order from the exception module:
    // Flags = {Overflow, Underflow, DivideByZero, Invalid, Inexact}
    fp8_add dut (
        .A(A),
        .B(B),
        .Result(Result),
        .Flags(Flags)
    );

    task automatic check_result(
        input logic [7:0] a_in,
        input logic [7:0] b_in,
        input logic [7:0] expected_result,
        input string test_name
    );
        begin
            A = a_in;
            B = b_in;
            #2;
            tests = tests + 1;

            if (Result !== expected_result) begin
                errors = errors + 1;
                $display("FAIL %-24s A=%02h B=%02h Result=%02h expected=%02h Flags=%05b",
                         test_name, A, B, Result, expected_result, Flags);
            end else begin
                $display("PASS %-24s A=%02h B=%02h Result=%02h Flags=%05b",
                         test_name, A, B, Result, Flags);
            end
        end
    endtask

    task automatic check_exact(
        input logic [7:0] a_in,
        input logic [7:0] b_in,
        input logic [7:0] expected_result,
        input string test_name
    );
        begin
            A = a_in;
            B = b_in;
            #2;
            tests = tests + 1;

            if ((Result !== expected_result) || (Flags !== 5'b00000)) begin
                errors = errors + 1;
                $display("FAIL %-24s A=%02h B=%02h Result=%02h expected=%02h Flags=%05b expected flags=00000",
                         test_name, A, B, Result, expected_result, Flags);
            end else begin
                $display("PASS %-24s A=%02h B=%02h Result=%02h Flags=%05b",
                         test_name, A, B, Result, Flags);
            end
        end
    endtask

    initial begin
        tests = 0;
        errors = 0;
        A = 8'h00;
        B = 8'h00;
        #2;

        // Assumes E3M4, exponent bias=3:
        // 0x30 = +1.0, 0x40 = +2.0, 0x20 = +0.5,
        // 0x38 = +1.5, 0x44 = +2.5, 0xA0 = -0.5, 0xB0 = -1.0.
        check_exact(8'h30, 8'h30, 8'h40, "1.0 + 1.0");
        check_exact(8'h30, 8'h20, 8'h38, "1.0 + 0.5");
        check_exact(8'h40, 8'h20, 8'h44, "2.0 + 0.5");
        check_exact(8'hB0, 8'h20, 8'hA0, "-1.0 + 0.5");
        check_exact(8'hB0, 8'hB0, 8'hC0, "-1.0 + -1.0");
        check_exact(8'h00, 8'h30, 8'h30, "+0 + 1.0");
        check_exact(8'h80, 8'h30, 8'h30, "-0 + 1.0");

        // Cancellation: result should be zero. This check accepts either
        // +0 or -0 because the zero-sign convention depends on your RTL.
        A = 8'hB0;
        B = 8'h30;
        #2;
        tests = tests + 1;
        if ((Result[6:0] !== 7'b0) || (Flags !== 5'b00000)) begin
            errors = errors + 1;
            $display("FAIL %-24s A=%02h B=%02h Result=%02h Flags=%05b",
                     "1.0 + -1.0 cancellation", A, B, Result, Flags);
        end else begin
            $display("PASS %-24s A=%02h B=%02h Result=%02h Flags=%05b",
                     "1.0 + -1.0 cancellation", A, B, Result, Flags);
        end

        // Unequal exponents and significands exercise alignment/truncation.
        // Result is checked separately from flags because the expected
        // inexact behavior depends on how discarded bits are propagated.
        check_result(8'h30, 8'h21, 8'h38, "1.0 + encoded 0.53125");
        check_result(8'h38, 8'h30, 8'h44, "1.5 + 1.0");

        $display("");
        $display("Tests run: %0d, failures: %0d", tests, errors);
        if (errors != 0)
            $fatal(1, "fp8_add testbench failed");
        else
            $display("All checked FP8 addition cases passed.");

        $finish;
    end

endmodule
