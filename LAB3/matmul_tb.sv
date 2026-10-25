`timescale 1ns / 1ps
// matmul_tb.sv
// Self-checking testbench for matmul_4x4_systolic with FP8 (E3M4, bias 3) MACs.
//
// Inputs and expected outputs are fixed raw FP8 (E3M4, bias 3) hex values.
// Encodings used: 0x10=0.25 0x20=0.5 0x30=1.0 0x38=1.5 0x40=2.0 0x60=8.0
//
// Scenarios:
//   1. No exceptions
//   2. One exception (one flag type) in one PE
//   3. Multiple exceptions (overflow + underflow) in one PE
//   4. Exceptions in multiple PEs
//
// ASSUMPTIONS (adjust if your RTL differs):
//   * Flag bit order: {Overflow, Underflow, DivideByZero, Invalid, Inexact}
//   * The 4x4 block's `flag` port and each processing_element's `flag` are 5 bits
//   * Each PE instance is reachable as dut.u_systolic_pe_matrix.peXY.flag
//   * Min normal = 0.25, max normal = 15.5 (denormals are not supported)
//
// The TB OR-accumulates every flag on every clock, so it works whether or not
// your flag registers are sticky.

module matmul_tb;

    localparam int N          = 4;
    localparam int DW         = 8;
    localparam int AW         = 10;
    localparam int FLAG_OVF   = 4;
    localparam int FLAG_UNF   = 3;
    localparam int FLAG_DIVZ  = 2;
    localparam int FLAG_INV   = 1;
    localparam int FLAG_INX   = 0;

    // -------------------------------------------------------------------
    // DUT connections
    // -------------------------------------------------------------------
    logic                 clk = 1'b0;
    logic                 reset;
    logic                 pe_reset;
    logic                 start_mat_mul;
    logic                 done_mat_mul;
    logic [4:0]           flag;
    logic [AW-1:0]        address_mat_a, address_mat_b, address_mat_c;
    logic [7:0]           address_stride_a, address_stride_b, address_stride_c;
    logic [N*DW-1:0]      a_data, b_data;
    logic [N*DW-1:0]      c_data_out, a_data_out, b_data_out;
    logic [AW-1:0]        a_addr, b_addr, c_addr;
    logic                 c_data_available;

    matmul_4x4_systolic dut (
        .*,
        .a_data_in ('0),
        .b_data_in ('0),
        .c_data_in ('0),
        .validity_mask_a_rows (4'hF),
        .validity_mask_a_cols_b_rows (4'hF),
        .validity_mask_b_cols (4'hF),
        .final_mat_mul_size (8'd4),
        .a_loc (8'd0),
        .b_loc (8'd0)
    );

    always #5 clk = ~clk;

    // -------------------------------------------------------------------
    // Per-PE flag probes (hierarchical) and OR-accumulation
    // -------------------------------------------------------------------
    logic [4:0] pe_flag [N*N];
    assign pe_flag[0] = dut.u_systolic_pe_matrix.pe00.flag;
    assign pe_flag[1] = dut.u_systolic_pe_matrix.pe01.flag;
    assign pe_flag[2] = dut.u_systolic_pe_matrix.pe02.flag;
    assign pe_flag[3] = dut.u_systolic_pe_matrix.pe03.flag;
    assign pe_flag[4] = dut.u_systolic_pe_matrix.pe10.flag;
    assign pe_flag[5] = dut.u_systolic_pe_matrix.pe11.flag;
    assign pe_flag[6] = dut.u_systolic_pe_matrix.pe12.flag;
    assign pe_flag[7] = dut.u_systolic_pe_matrix.pe13.flag;
    assign pe_flag[8] = dut.u_systolic_pe_matrix.pe20.flag;
    assign pe_flag[9] = dut.u_systolic_pe_matrix.pe21.flag;
    assign pe_flag[10] = dut.u_systolic_pe_matrix.pe22.flag;
    assign pe_flag[11] = dut.u_systolic_pe_matrix.pe23.flag;
    assign pe_flag[12] = dut.u_systolic_pe_matrix.pe30.flag;
    assign pe_flag[13] = dut.u_systolic_pe_matrix.pe31.flag;
    assign pe_flag[14] = dut.u_systolic_pe_matrix.pe32.flag;
    assign pe_flag[15] = dut.u_systolic_pe_matrix.pe33.flag;

    logic [4:0] seen_pe_flag [N*N];   // OR of everything seen since clear
    logic [4:0] seen_top_flag;
    logic       clear_seen;

    always_ff @(posedge clk) begin
        if (clear_seen) begin
            for (int p = 0; p < N*N; p++)
                seen_pe_flag[p] <= '0;
            seen_top_flag <= '0;
        end
        else begin
            for (int p = 0; p < N*N; p++)
                seen_pe_flag[p] <= seen_pe_flag[p] | pe_flag[p];
            seen_top_flag <= seen_top_flag | flag;
        end
    end

    // -------------------------------------------------------------------
    // Behavioral RAMs (1-cycle registered read, matches MEM_ACCESS_LATENCY=1)
    //   RAM A word k = {A[3][k], A[2][k], A[1][k], A[0][k]}  (column k of A)
    //   RAM B word k = {B[k][3], B[k][2], B[k][1], B[k][0]}  (row k of B)
    //   RAM C word j = {C[3][j], C[2][j], C[1][j], C[0][j]}  (column j of C)
    // -------------------------------------------------------------------
    logic [N*DW-1:0] ram_a [0:(1<<AW)-1];
    logic [N*DW-1:0] ram_b [0:(1<<AW)-1];
    logic [N*DW-1:0] ram_c [0:(1<<AW)-1];

    always_ff @(posedge clk) begin
        a_data <= ram_a[a_addr];
        b_data <= ram_b[b_addr];
    end

    // Only the first N words after c_data_available rises are real results;
    // the block keeps shifting afterwards, so bound the write window.
    always_ff @(posedge clk) begin
        if (c_data_available &&
            (c_addr >= address_mat_c) && (c_addr < address_mat_c + N))
            ram_c[c_addr] <= c_data_out;
    end

    // -------------------------------------------------------------------
    // Test data, flattened row-major: element [r][c] is entry r*4+c, entry 0 first.
    // -------------------------------------------------------------------
    logic [N*N*DW-1:0] cur_a, cur_b, cur_exp_c;
    logic [N*N*5-1:0]  cur_exp_f;

    int tests_run = 0;
    int errors    = 0;

    function automatic logic [7:0] elem(input logic [N*N*DW-1:0] m, input int r, input int c);
        elem = m[(N*N-1-(r*N+c))*DW +: DW];
    endfunction

    function automatic logic [4:0] elem_f(input logic [N*N*5-1:0] m, input int r, input int c);
        elem_f = m[(N*N-1-(r*N+c))*5 +: 5];
    endfunction

    function automatic string flag_str(input logic [4:0] f);
        string s = "";
        if (f[FLAG_OVF])  s = {s, "OVF "};
        if (f[FLAG_UNF])  s = {s, "UNF "};
        if (f[FLAG_DIVZ]) s = {s, "DIVZ "};
        if (f[FLAG_INV])  s = {s, "INV "};
        if (f[FLAG_INX])  s = {s, "INX "};
        if (s == "") s = "none";
        return s;
    endfunction

    // Fill the RAMs from cur_a / cur_b
    task automatic load_rams();
        logic [N*DW-1:0] wa, wb;
        for (int k = 0; k < N; k++) begin
            wa = '0; wb = '0;
            for (int r = 0; r < N; r++) begin
                wa[r*DW +: DW] = elem(cur_a, r, k);   // column k of A
                wb[r*DW +: DW] = elem(cur_b, k, r);   // row k of B
            end
            ram_a[address_mat_a + k] = wa;
            ram_b[address_mat_b + k] = wb;
        end
        for (int j = 0; j < N; j++) ram_c[address_mat_c + j] = {N*DW{1'bx}};
    endtask

    // Pulse pe_reset, start the multiply, wait for done
    task automatic run_matmul();
        int timeout;
        start_mat_mul = 1'b0;
        pe_reset      = 1'b1;
        clear_seen    = 1'b1;
        repeat (3) @(posedge clk);
        pe_reset      = 1'b0;
        clear_seen    = 1'b0;
        @(posedge clk);

        start_mat_mul = 1'b1;
        timeout = 0;
        while (!done_mat_mul && timeout < 200) begin
            @(posedge clk);
            timeout++;
        end
        if (!done_mat_mul) begin
            errors++;
            $display("  FAIL: done_mat_mul never asserted (timeout)");
        end
        repeat (3) @(posedge clk);
        start_mat_mul = 1'b0;
        @(posedge clk);
    endtask

    // Compare DUT results and flags against the expected values
    task automatic check_results(input string name);
        logic [7:0] got, exp_v;
        logic [4:0] exp_f, any_pe;
        int         p, local_err, n_exc;
        begin
            tests_run++;
            local_err = 0;
            n_exc     = 0;
            any_pe    = '0;

            for (int i = 0; i < N; i++) begin
                for (int j = 0; j < N; j++) begin
                    p     = i*N + j;
                    exp_f = elem_f(cur_exp_f, i, j);
                    any_pe |= seen_pe_flag[p];

                    if (exp_f != 5'b0) begin
                        // Exception PE: expected flag bits must be set (extra bits allowed)
                        n_exc++;
                        if ((seen_pe_flag[p] & exp_f) !== exp_f) begin
                            local_err++;
                            $display("  FAIL PE(%0d,%0d) flags: got %05b [%s], expected at least %05b [%s]",
                                     i, j, seen_pe_flag[p], flag_str(seen_pe_flag[p]), exp_f, flag_str(exp_f));
                        end else
                            $display("  ok   PE(%0d,%0d) flags: %05b [%s]",
                                     i, j, seen_pe_flag[p], flag_str(seen_pe_flag[p]));
                    end else begin
                        // Clean PE: no flags, and data must match exactly
                        if (seen_pe_flag[p] !== 5'b0) begin
                            local_err++;
                            $display("  FAIL PE(%0d,%0d) unexpected flags %05b [%s]",
                                     i, j, seen_pe_flag[p], flag_str(seen_pe_flag[p]));
                        end
                        exp_v = elem(cur_exp_c, i, j);
                        got   = ram_c[address_mat_c + j][i*DW +: DW];
                        if (got !== exp_v) begin
                            local_err++;
                            $display("  FAIL C[%0d][%0d]: got %02h expected %02h", i, j, got, exp_v);
                        end
                    end
                end
            end

            if (seen_top_flag !== any_pe) begin
                local_err++;
                $display("  FAIL top-level flag %05b != OR of PE flags %05b", seen_top_flag, any_pe);
            end
            if ((n_exc == 0) && (seen_top_flag !== 5'b0)) begin
                local_err++;
                $display("  FAIL top-level flag asserted in a clean run: %05b", seen_top_flag);
            end
            if ((n_exc > 0) && (seen_top_flag === 5'b0)) begin
                local_err++;
                $display("  FAIL top-level flag never asserted");
            end

            errors += local_err;
            $display("%s %s  (top flag: %05b [%s], %0d exception PE%s)\n",
                     (local_err == 0) ? "PASS" : "FAIL", name,
                     seen_top_flag, flag_str(seen_top_flag), n_exc, (n_exc == 1) ? "" : "s");
        end
    endtask

    // Load one test case, run it, and check it
    task automatic run_test(
        input string             name,
        input logic [N*N*DW-1:0] a,
        input logic [N*N*DW-1:0] b,
        input logic [N*N*DW-1:0] exp_c,
        input logic [N*N*5-1:0]  exp_f
    );
        begin
            $display("=== %s ===", name);
            cur_a     = a;
            cur_b     = b;
            cur_exp_c = exp_c;
            cur_exp_f = exp_f;
            load_rams();
            run_matmul();
            check_results(name);
        end
    endtask

    // -------------------------------------------------------------------
    // Main sequence
    // -------------------------------------------------------------------
    initial begin
        reset            = 1'b1;
        pe_reset         = 1'b0;
        start_mat_mul    = 1'b0;
        clear_seen       = 1'b1;
        address_mat_a    = '0;
        address_mat_b    = '0;
        address_mat_c    = '0;
        address_stride_a = 8'd1;
        address_stride_b = 8'd1;
        address_stride_c = 8'd1;
        a_data           = '0;
        b_data           = '0;
        repeat (5) @(posedge clk);
        reset = 1'b0;
        repeat (2) @(posedge clk);

        // All products and partial sums exact and inside [0.25, 15.5].
        run_test("Test 1: no exceptions",
            // A (row-major)
            {
            8'h30, 8'h40, 8'h20, 8'h30,
            8'h20, 8'h30, 8'h38, 8'h40,
            8'h40, 8'h20, 8'h30, 8'h30,
            8'h30, 8'h30, 8'h30, 8'h20
            },
            // B (row-major)
            {
            8'h30, 8'h20, 8'h40, 8'h30,
            8'h30, 8'h30, 8'h20, 8'h40,
            8'h40, 8'h30, 8'h30, 8'h20,
            8'h20, 8'h38, 8'h30, 8'h30
            },
            // expected C (row-major; ignored where expected flags are non-zero)
            {
            8'h52, 8'h52, 8'h52, 8'h59,
            8'h56, 8'h57, 8'h54, 8'h55,
            8'h54, 8'h50, 8'h59, 8'h52,
            8'h51, 8'h4a, 8'h50, 8'h50
            },
            // expected per-PE flags (row-major)
            {
            5'b00000, 5'b00000, 5'b00000, 5'b00000,
            5'b00000, 5'b00000, 5'b00000, 5'b00000,
            5'b00000, 5'b00000, 5'b00000, 5'b00000,
            5'b00000, 5'b00000, 5'b00000, 5'b00000
            });

        // PE(1,2): A[1][2]=8.0 * B[2][2]=8.0 = 64 -> overflow. Only that PE.
        run_test("Test 2: one exception, one PE",
            // A (row-major)
            {
            8'h30, 8'h30, 8'h30, 8'h30,
            8'h30, 8'h30, 8'h60, 8'h30,
            8'h30, 8'h30, 8'h30, 8'h30,
            8'h30, 8'h30, 8'h30, 8'h30
            },
            // B (row-major)
            {
            8'h30, 8'h30, 8'h30, 8'h30,
            8'h30, 8'h30, 8'h30, 8'h30,
            8'h30, 8'h30, 8'h60, 8'h30,
            8'h30, 8'h30, 8'h30, 8'h30
            },
            // expected C (row-major; ignored where expected flags are non-zero)
            {
            8'h50, 8'h50, 8'h66, 8'h50,
            8'h66, 8'h66, 8'h00, 8'h66,
            8'h50, 8'h50, 8'h66, 8'h50,
            8'h50, 8'h50, 8'h66, 8'h50
            },
            // expected per-PE flags (row-major)
            {
            5'b00000, 5'b00000, 5'b00000, 5'b00000,
            5'b00000, 5'b00000, 5'b10000, 5'b00000,
            5'b00000, 5'b00000, 5'b00000, 5'b00000,
            5'b00000, 5'b00000, 5'b00000, 5'b00000
            });

        // PE(2,1): k=0: 8.0*8.0 = 64 overflow; k=1: 0.5*0.25 = 0.125 underflow.
        run_test("Test 3: multiple exceptions, one PE",
            // A (row-major)
            {
            8'h30, 8'h40, 8'h30, 8'h30,
            8'h30, 8'h40, 8'h30, 8'h30,
            8'h60, 8'h20, 8'h30, 8'h30,
            8'h30, 8'h40, 8'h30, 8'h30
            },
            // B (row-major)
            {
            8'h30, 8'h60, 8'h30, 8'h30,
            8'h30, 8'h10, 8'h30, 8'h30,
            8'h30, 8'h30, 8'h30, 8'h30,
            8'h30, 8'h30, 8'h30, 8'h30
            },
            // expected C (row-major; ignored where expected flags are non-zero)
            {
            8'h54, 8'h65, 8'h54, 8'h54,
            8'h54, 8'h65, 8'h54, 8'h54,
            8'h65, 8'h00, 8'h65, 8'h65,
            8'h54, 8'h65, 8'h54, 8'h54
            },
            // expected per-PE flags (row-major)
            {
            5'b00000, 5'b00000, 5'b00000, 5'b00000,
            5'b00000, 5'b00000, 5'b00000, 5'b00000,
            5'b00000, 5'b11000, 5'b00000, 5'b00000,
            5'b00000, 5'b00000, 5'b00000, 5'b00000
            });

        // PE(0,0): 8.0*8.0 overflow. PE(3,3): 0.25*0.25 = 0.0625 underflow.
        run_test("Test 4: exceptions in multiple PEs",
            // A (row-major)
            {
            8'h60, 8'h30, 8'h30, 8'h40,
            8'h30, 8'h30, 8'h30, 8'h40,
            8'h30, 8'h30, 8'h30, 8'h40,
            8'h30, 8'h30, 8'h30, 8'h10
            },
            // B (row-major)
            {
            8'h60, 8'h30, 8'h30, 8'h30,
            8'h30, 8'h30, 8'h30, 8'h30,
            8'h30, 8'h30, 8'h30, 8'h30,
            8'h40, 8'h40, 8'h40, 8'h10
            },
            // expected C (row-major; ignored where expected flags are non-zero)
            {
            8'h00, 8'h6c, 8'h6c, 8'h65,
            8'h6c, 8'h5c, 8'h5c, 8'h4c,
            8'h6c, 8'h5c, 8'h5c, 8'h4c,
            8'h65, 8'h4c, 8'h4c, 8'h00
            },
            // expected per-PE flags (row-major)
            {
            5'b10000, 5'b00000, 5'b00000, 5'b00000,
            5'b00000, 5'b00000, 5'b00000, 5'b00000,
            5'b00000, 5'b00000, 5'b00000, 5'b00000,
            5'b00000, 5'b00000, 5'b00000, 5'b01000
            });

        // A all 1.0, B all 0.5 -> C all 2.0. Proves pe_reset clears accumulators and flags from Test 4.
        run_test("Test 5: clean run after exceptions (pe_reset check)",
            // A (row-major)
            {
            8'h30, 8'h30, 8'h30, 8'h30,
            8'h30, 8'h30, 8'h30, 8'h30,
            8'h30, 8'h30, 8'h30, 8'h30,
            8'h30, 8'h30, 8'h30, 8'h30
            },
            // B (row-major)
            {
            8'h20, 8'h20, 8'h20, 8'h20,
            8'h20, 8'h20, 8'h20, 8'h20,
            8'h20, 8'h20, 8'h20, 8'h20,
            8'h20, 8'h20, 8'h20, 8'h20
            },
            // expected C (row-major; ignored where expected flags are non-zero)
            {
            8'h40, 8'h40, 8'h40, 8'h40,
            8'h40, 8'h40, 8'h40, 8'h40,
            8'h40, 8'h40, 8'h40, 8'h40,
            8'h40, 8'h40, 8'h40, 8'h40
            },
            // expected per-PE flags (row-major)
            {
            5'b00000, 5'b00000, 5'b00000, 5'b00000,
            5'b00000, 5'b00000, 5'b00000, 5'b00000,
            5'b00000, 5'b00000, 5'b00000, 5'b00000,
            5'b00000, 5'b00000, 5'b00000, 5'b00000
            });

        $display("Tests run: %0d, errors: %0d", tests_run, errors);
        if (errors == 0) $display("ALL TESTS PASSED");
        else             $fatal(1, "tb_matmul_fp8 FAILED");
        $finish;
    end

    // Watchdog
    initial begin
        #200000;
        $fatal(1, "tb_matmul_fp8 watchdog timeout");
    end

endmodule