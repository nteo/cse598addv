`timescale 1ns/1ns

module apb_matmul_tb;

    logic clk, resetn, pe_resetn;
    logic [`APB_ADDRWIDTH-1:0] PADDR;
    logic PWRITE, PSEL, PENABLE;
    logic [`APB_DATAWIDTH-1:0] PWDATA;
    logic [`APB_DATAWIDTH-1:0] PRDATA;
    logic PREADY;

    logic [`APB_DATAWIDTH-1:0] rdata;
    integer errors = 0;
    localparam bit SWAP_HALVES = 1;
    logic [7:0] A [8][8];
    logic [7:0] B [8][8];
    logic [7:0] C [8][8];

    apb_top u_top (
        .clk(clk), .resetn(resetn), .pe_resetn(pe_resetn),
        .PADDR(PADDR), .PWRITE(PWRITE), .PSEL(PSEL), .PENABLE(PENABLE),
        .PWDATA(PWDATA), .PRDATA(PRDATA), .PREADY(PREADY),
        .bram_addr_a_top_ext('0), .bram_rdata_a_top_ext(), .bram_wdata_a_top_ext('0), .bram_we_a_top_ext('0),
        .bram_addr_a_bottom_ext('0), .bram_rdata_a_bottom_ext(), .bram_wdata_a_bottom_ext('0), .bram_we_a_bottom_ext('0),
        .bram_addr_b_left_ext('0), .bram_rdata_b_left_ext(), .bram_wdata_b_left_ext('0), .bram_we_b_left_ext('0),
        .bram_addr_b_right_ext('0), .bram_rdata_b_right_ext(), .bram_wdata_b_right_ext('0), .bram_we_b_right_ext('0),
        .bram_addr_c_top_ext('0), .bram_rdata_c_top_ext(), .bram_wdata_c_top_ext('0), .bram_we_c_top_ext('0),
        .bram_addr_c_bottom_ext('0), .bram_rdata_c_bottom_ext(), .bram_wdata_c_bottom_ext('0), .bram_we_c_bottom_ext('0)
    );

    initial begin clk = 0; forever #10 clk = ~clk; end

    task write(input [`APB_ADDRWIDTH-1:0] addr, input [`APB_DATAWIDTH-1:0] data);
        @(negedge clk);
        PSEL = 1; PWRITE = 1; PADDR = addr; PWDATA = data;
        @(negedge clk);
        PENABLE = 1;
        @(negedge clk);
        PSEL = 0; PENABLE = 0; PWRITE = 0; PADDR = 0; PWDATA = 0;
        $display("%t: WRITE PADDR %h, PWDATA %h", $time, addr, data);
    endtask

    task read(input [`APB_ADDRWIDTH-1:0] addr, output [`APB_DATAWIDTH-1:0] data);
        @(negedge clk);
        PSEL = 1; PWRITE = 0; PADDR = addr;
        @(negedge clk);
        PENABLE = 1;
        @(negedge clk);
        PSEL = 0; PENABLE = 0;
        data = PRDATA;
        PADDR = 0;
        $display("%t: READ  PADDR %h, PRDATA %h", $time, addr, data);
    endtask

    task check(input string name, input [`APB_DATAWIDTH-1:0] got, input [`APB_DATAWIDTH-1:0] exp);
        if (got !== exp) begin
            errors++;
            $display("FAIL %s: got %h expected %h", name, got, exp);
        end else
            $display("PASS %s: %h", name, got);
    endtask

    task configure(input [9:0] base, input [7:0] stride);
        write(`REG_ADDR_A_TOP_ADDR, base);    write(`REG_ADDR_A_BOTTOM_ADDR, base);
        write(`REG_ADDR_B_LEFT_ADDR, base);   write(`REG_ADDR_B_RIGHT_ADDR, base);
        write(`REG_ADDR_C_TOP_ADDR, base);    write(`REG_ADDR_C_BOTTOM_ADDR, base);
        write(`REG_STRIDE_A_TOP_ADDR, stride);    write(`REG_STRIDE_A_BOTTOM_ADDR, stride);
        write(`REG_STRIDE_B_LEFT_ADDR, stride);   write(`REG_STRIDE_B_RIGHT_ADDR, stride);
        write(`REG_STRIDE_C_TOP_ADDR, stride);    write(`REG_STRIDE_C_BOTTOM_ADDR, stride);
    endtask

    task run_matmul;
        integer t;
        write(`REG_CTRL_ADDR, 16'h1);
        t = 0;
        rdata = 0;
        while (!rdata[0] && t < 400) begin
            read(`REG_STATUS_ADDR, rdata);
            t++;
        end
        if (t >= 400) begin errors++; $display("FAIL timeout waiting for done"); end
    endtask

    task load;
        integer i, k;
        for (k = 0; k < 8; k++) begin
            for (i = 0; i < 4; i++) begin
                u_top.u_matmul.matrix_a_top.memory[k][8*i +: 8]    = A[i][k];
                u_top.u_matmul.matrix_a_bottom.memory[k][8*i +: 8] = A[i+4][k];
                u_top.u_matmul.matrix_b_left.memory[k][8*i +: 8]   = B[k][i];
                u_top.u_matmul.matrix_b_right.memory[k][8*i +: 8]  = B[k][i+4];
            end
        end
    endtask

    task check_c;
        integer r, c, w;
        logic [7:0] got;
        for (c = 0; c < 8; c++)
            for (r = 0; r < 8; r++) begin
                w = SWAP_HALVES ? (c + 4) % 8 : c;
                got = (r < 4) ? u_top.u_matmul.matrix_c_top.memory[w][8*r +: 8]
                              : u_top.u_matmul.matrix_c_bottom.memory[w][8*(r-4) +: 8];
                if (got !== C[r][c]) begin
                    errors++;
                    $display("FAIL C[%0d][%0d]: got %h expected %h", r, c, got, C[r][c]);
                end
            end
    endtask

`ifdef VCS
    initial $fsdbDumpvars;
`endif

    integer r, c;

    initial begin
        PSEL = 0; PENABLE = 0; PWRITE = 0; PADDR = 0; PWDATA = 0;
        resetn = 0; pe_resetn = 0;
        #55; resetn = 1; pe_resetn = 1;
        #30;

        $display("== Test 0: register readback");
        write(`REG_ADDR_A_TOP_ADDR, 16'h0123);
        read (`REG_ADDR_A_TOP_ADDR, rdata);
        check("ADDR_A_TOP", rdata, 16'h0123);
        write(`REG_STRIDE_C_BOTTOM_ADDR, 16'h0005);
        read (`REG_STRIDE_C_BOTTOM_ADDR, rdata);
        check("STRIDE_C_BOTTOM", rdata, 16'h0005);
        read (`REG_STATUS_ADDR, rdata);
        check("STATUS idle", rdata, 16'h0);

        $display("== Test 1: all ones (1.0 x 1.0, 8 terms = 8.0), no exception");
        for (r = 0; r < 8; r++) for (c = 0; c < 8; c++) begin A[r][c] = 8'h30; B[r][c] = 8'h30; C[r][c] = 8'h60; end
        load;
        configure(0, 1);
        run_matmul;
        check("STATUS done", rdata, 16'h1);
        read(`REG_FLAGS_ADDR, rdata);
        check("FLAGS", rdata, 16'h0);
        check_c;

        $display("== Test 2: identity x distinct values, C must equal B");
        for (r = 0; r < 8; r++) for (c = 0; c < 8; c++) begin
            A[r][c] = (r == c) ? 8'h30 : 8'h00;
            B[r][c] = 8'h30 + r*8 + c;
            C[r][c] = B[r][c];
        end
        load;
        run_matmul;
        check("STATUS done", rdata, 16'h1);
        read(`REG_FLAGS_ADDR, rdata);
        check("FLAGS", rdata, 16'h0);
        check_c;

        $display("== Test 3: overflow (max finite x 1.0 summed) raises exception flag");
        for (r = 0; r < 8; r++) for (c = 0; c < 8; c++) begin A[r][c] = 8'h6F; B[r][c] = 8'h30; end
        load;
        run_matmul;
        read(`REG_STATUS_ADDR, rdata);
        check("STATUS done+exception", rdata, 16'h3);
        read(`REG_FLAGS_ADDR, rdata);
        if (rdata[4] !== 1'b1) begin errors++; $display("FAIL FLAGS overflow bit not set: %b", rdata[4:0]); end
        else $display("PASS FLAGS overflow bit set: %b", rdata[4:0]);

        $display("== Test 4: new start clears done and flags");
        for (r = 0; r < 8; r++) for (c = 0; c < 8; c++) begin A[r][c] = 8'h30; B[r][c] = 8'h30; C[r][c] = 8'h60; end
        load;
        configure(0, 1);
        run_matmul;
        check("STATUS done", rdata, 16'h1);
        read(`REG_FLAGS_ADDR, rdata);
        check("FLAGS", rdata, 16'h0);
        check_c;

        $display("");
        if (errors == 0) $display("ALL TESTS PASSED");
        else $display("TESTS FAILED: %0d errors", errors);
        $finish;
    end

endmodule