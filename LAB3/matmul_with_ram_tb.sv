`timescale 1ns/1ns

module matmul_tb;

    // FP8 format: 1 sign bit, 3 exponent bits, 4 fraction bits, bias 3.

    localparam int DWIDTH = 8;
    localparam int AWIDTH = 10;
    localparam int MAT_MUL_SIZE = 4;
    localparam int MASK_WIDTH = MAT_MUL_SIZE;
    localparam int ADDR_STRIDE_WIDTH = 8;

    logic clk;
    logic resetn;
    logic pe_resetn;
    logic start;
    logic done;
    logic [4:0] flags;

    logic [AWIDTH-1:0] address_mat_a_top;
    logic [AWIDTH-1:0] address_mat_a_bottom;
    logic [AWIDTH-1:0] address_mat_b_left;
    logic [AWIDTH-1:0] address_mat_b_right;
    logic [AWIDTH-1:0] address_mat_c_top;
    logic [AWIDTH-1:0] address_mat_c_bottom;
    logic [ADDR_STRIDE_WIDTH-1:0] address_stride_a_top;
    logic [ADDR_STRIDE_WIDTH-1:0] address_stride_a_bottom;
    logic [ADDR_STRIDE_WIDTH-1:0] address_stride_b_left;
    logic [ADDR_STRIDE_WIDTH-1:0] address_stride_b_right;
    logic [ADDR_STRIDE_WIDTH-1:0] address_stride_c_top;
    logic [ADDR_STRIDE_WIDTH-1:0] address_stride_c_bottom;

    //DUT
    matrix_multiplication #(
        .DWIDTH(DWIDTH),
        .AWIDTH(AWIDTH),
        .MAT_MUL_SIZE(MAT_MUL_SIZE),
        .MASK_WIDTH(MASK_WIDTH),
        .ADDR_STRIDE_WIDTH(ADDR_STRIDE_WIDTH)
    ) u_matmul (
        .clk(clk),
        .resetn(resetn),
        .pe_resetn(pe_resetn),
        .address_mat_a_top(address_mat_a_top),
        .address_mat_a_bottom(address_mat_a_bottom),
        .address_mat_b_left(address_mat_b_left),
        .address_mat_b_right(address_mat_b_right),
        .address_mat_c_top(address_mat_c_top),
        .address_mat_c_bottom(address_mat_c_bottom),
        .address_stride_a_top(address_stride_a_top),
        .address_stride_a_bottom(address_stride_a_bottom),
        .address_stride_b_left(address_stride_b_left),
        .address_stride_b_right(address_stride_b_right),
        .address_stride_c_top(address_stride_c_top),
        .address_stride_c_bottom(address_stride_c_bottom),
        .bram_addr_a_top_ext('0),
        .bram_rdata_a_top_ext(),
        .bram_wdata_a_top_ext('0),
        .bram_we_a_top_ext('0),
        .bram_addr_a_bottom_ext('0),
        .bram_rdata_a_bottom_ext(),
        .bram_wdata_a_bottom_ext('0),
        .bram_we_a_bottom_ext('0),
        .bram_addr_b_left_ext('0),
        .bram_rdata_b_left_ext(),
        .bram_wdata_b_left_ext('0),
        .bram_we_b_left_ext('0),
        .bram_addr_b_right_ext('0),
        .bram_rdata_b_right_ext(),
        .bram_wdata_b_right_ext('0),
        .bram_we_b_right_ext('0),
        .bram_addr_c_top_ext('0),
        .bram_rdata_c_top_ext(),
        .bram_wdata_c_top_ext('0),
        .bram_we_c_top_ext('0),
        .bram_addr_c_bottom_ext('0),
        .bram_rdata_c_bottom_ext(),
        .bram_wdata_c_bottom_ext('0),
        .bram_we_c_bottom_ext('0),
        .start(start),
        .done(done)
    );

    //Clock Generation  
    initial begin
        clk = 1'b0;
        forever #10 clk = ~clk;
    end

    //Reset
    initial begin
        resetn = 1'b0;
        pe_resetn = 1'b0;
        #55;
        resetn = 1'b1;
        pe_resetn = 1'b1;
    end

    //Matrix base addresses and strides
    initial begin
        address_mat_a_top = '0;
        address_mat_a_bottom = '0;
        address_mat_b_left = '0;
        address_mat_b_right = '0;
        address_mat_c_top = '0;
        address_mat_c_bottom = '0;
        address_stride_a_top = 8'd1;
        address_stride_a_bottom = 8'd1;
        address_stride_b_left = 8'd1;
        address_stride_b_right = 8'd1;
        address_stride_c_top = 8'd1;
        address_stride_c_bottom = 8'd1;
    end

    //Load 8x8 matrices into the six memories
    //A is split into top and bottom memories, with four rows in each memory
    //B is split into left and right memories, with four columns in each memory
    //Each RAM word contains four 8-bit matrix elements
    integer word_index;
    initial begin
        for (word_index = 0; word_index < (1 << AWIDTH); word_index = word_index + 1) begin
            u_matmul.matrix_a_top.memory[word_index] = '0;
            u_matmul.matrix_a_bottom.memory[word_index] = '0;
            u_matmul.matrix_b_left.memory[word_index] = '0;
            u_matmul.matrix_b_right.memory[word_index] = '0;
        end

        // A is stored by column: each word contains four rows.
        u_matmul.matrix_a_top.memory[0] = {8'h30, 8'h30, 8'h30, 8'h30};
        u_matmul.matrix_a_top.memory[1] = {8'h30, 8'h30, 8'h30, 8'h30};
        u_matmul.matrix_a_top.memory[2] = {8'h30, 8'h30, 8'h30, 8'h30};
        u_matmul.matrix_a_top.memory[3] = {8'h30, 8'h30, 8'h30, 8'h30};
        u_matmul.matrix_a_top.memory[4] = {8'h30, 8'h30, 8'h30, 8'h30};
        u_matmul.matrix_a_top.memory[5] = {8'h30, 8'h30, 8'h30, 8'h30};
        u_matmul.matrix_a_top.memory[6] = {8'h30, 8'h30, 8'h30, 8'h30};
        u_matmul.matrix_a_top.memory[7] = {8'h30, 8'h30, 8'h30, 8'h30};
        u_matmul.matrix_a_bottom.memory[0] = {8'h30, 8'h30, 8'h30, 8'h30};
        u_matmul.matrix_a_bottom.memory[1] = {8'h30, 8'h30, 8'h30, 8'h30};
        u_matmul.matrix_a_bottom.memory[2] = {8'h30, 8'h30, 8'h30, 8'h30};
        u_matmul.matrix_a_bottom.memory[3] = {8'h30, 8'h30, 8'h30, 8'h30};
        u_matmul.matrix_a_bottom.memory[4] = {8'h30, 8'h30, 8'h30, 8'h30};
        u_matmul.matrix_a_bottom.memory[5] = {8'h30, 8'h30, 8'h30, 8'h30};
        u_matmul.matrix_a_bottom.memory[6] = {8'h30, 8'h30, 8'h30, 8'h30};
        u_matmul.matrix_a_bottom.memory[7] = {8'h30, 8'h30, 8'h30, 8'h30};

        // B is stored by row: each word contains four columns.
        u_matmul.matrix_b_left.memory[0] = {8'h30, 8'h30, 8'h30, 8'h30};
        u_matmul.matrix_b_left.memory[1] = {8'h30, 8'h30, 8'h30, 8'h30};
        u_matmul.matrix_b_left.memory[2] = {8'h30, 8'h30, 8'h30, 8'h30};
        u_matmul.matrix_b_left.memory[3] = {8'h30, 8'h30, 8'h30, 8'h30};
        u_matmul.matrix_b_left.memory[4] = {8'h30, 8'h30, 8'h30, 8'h30};
        u_matmul.matrix_b_left.memory[5] = {8'h30, 8'h30, 8'h30, 8'h30};
        u_matmul.matrix_b_left.memory[6] = {8'h30, 8'h30, 8'h30, 8'h30};
        u_matmul.matrix_b_left.memory[7] = {8'h30, 8'h30, 8'h30, 8'h30};
        u_matmul.matrix_b_right.memory[0] = {8'h30, 8'h30, 8'h30, 8'h30};
        u_matmul.matrix_b_right.memory[1] = {8'h30, 8'h30, 8'h30, 8'h30};
        u_matmul.matrix_b_right.memory[2] = {8'h30, 8'h30, 8'h30, 8'h30};
        u_matmul.matrix_b_right.memory[3] = {8'h30, 8'h30, 8'h30, 8'h30};
        u_matmul.matrix_b_right.memory[4] = {8'h30, 8'h30, 8'h30, 8'h30};
        u_matmul.matrix_b_right.memory[5] = {8'h30, 8'h30, 8'h30, 8'h30};
        u_matmul.matrix_b_right.memory[6] = {8'h30, 8'h30, 8'h30, 8'h30};
        u_matmul.matrix_b_right.memory[7] = {8'h30, 8'h30, 8'h30, 8'h30};
    end

    //Perform test    
    initial begin
        start = 1'b0;
        #115;
        start = 1'b1;
        @(posedge done);
        start = 1'b0;
        #100;

        //Dump the packed C-memory words after the matrix multiplication
        //C_top contains the top four rows and C_bottom contains the bottom
        //four rows of the 8x8 result matrix.
        $display("\nC matrix output:");
        for (word_index = 0; word_index < 8; word_index = word_index + 1)
            $display("C_top[%0d]    = %h", word_index,
                     u_matmul.matrix_c_top.memory[word_index]);
        for (word_index = 0; word_index < 8; word_index = word_index + 1)
            $display("C_bottom[%0d] = %h", word_index,
                     u_matmul.matrix_c_bottom.memory[word_index]);

        // Second test: simple FP8 values with no expected exceptions.
        // A = 0.5 and B = 1.0, so every output element is 8 * 0.5 * 1.0 = 4.0.
        u_matmul.matrix_a_top.memory[0] = {8'h20, 8'h20, 8'h20, 8'h20};
        u_matmul.matrix_a_top.memory[1] = {8'h20, 8'h20, 8'h20, 8'h20};
        u_matmul.matrix_a_top.memory[2] = {8'h20, 8'h20, 8'h20, 8'h20};
        u_matmul.matrix_a_top.memory[3] = {8'h20, 8'h20, 8'h20, 8'h20};
        u_matmul.matrix_a_top.memory[4] = {8'h20, 8'h20, 8'h20, 8'h20};
        u_matmul.matrix_a_top.memory[5] = {8'h20, 8'h20, 8'h20, 8'h20};
        u_matmul.matrix_a_top.memory[6] = {8'h20, 8'h20, 8'h20, 8'h20};
        u_matmul.matrix_a_top.memory[7] = {8'h20, 8'h20, 8'h20, 8'h20};
        u_matmul.matrix_a_bottom.memory[0] = {8'h20, 8'h20, 8'h20, 8'h20};
        u_matmul.matrix_a_bottom.memory[1] = {8'h20, 8'h20, 8'h20, 8'h20};
        u_matmul.matrix_a_bottom.memory[2] = {8'h20, 8'h20, 8'h20, 8'h20};
        u_matmul.matrix_a_bottom.memory[3] = {8'h20, 8'h20, 8'h20, 8'h20};
        u_matmul.matrix_a_bottom.memory[4] = {8'h20, 8'h20, 8'h20, 8'h20};
        u_matmul.matrix_a_bottom.memory[5] = {8'h20, 8'h20, 8'h20, 8'h20};
        u_matmul.matrix_a_bottom.memory[6] = {8'h20, 8'h20, 8'h20, 8'h20};
        u_matmul.matrix_a_bottom.memory[7] = {8'h20, 8'h20, 8'h20, 8'h20};

        u_matmul.matrix_b_left.memory[0] = {8'h30, 8'h30, 8'h30, 8'h30};
        u_matmul.matrix_b_left.memory[1] = {8'h30, 8'h30, 8'h30, 8'h30};
        u_matmul.matrix_b_left.memory[2] = {8'h30, 8'h30, 8'h30, 8'h30};
        u_matmul.matrix_b_left.memory[3] = {8'h30, 8'h30, 8'h30, 8'h30};
        u_matmul.matrix_b_left.memory[4] = {8'h30, 8'h30, 8'h30, 8'h30};
        u_matmul.matrix_b_left.memory[5] = {8'h30, 8'h30, 8'h30, 8'h30};
        u_matmul.matrix_b_left.memory[6] = {8'h30, 8'h30, 8'h30, 8'h30};
        u_matmul.matrix_b_left.memory[7] = {8'h30, 8'h30, 8'h30, 8'h30};
        u_matmul.matrix_b_right.memory[0] = {8'h30, 8'h30, 8'h30, 8'h30};
        u_matmul.matrix_b_right.memory[1] = {8'h30, 8'h30, 8'h30, 8'h30};
        u_matmul.matrix_b_right.memory[2] = {8'h30, 8'h30, 8'h30, 8'h30};
        u_matmul.matrix_b_right.memory[3] = {8'h30, 8'h30, 8'h30, 8'h30};
        u_matmul.matrix_b_right.memory[4] = {8'h30, 8'h30, 8'h30, 8'h30};
        u_matmul.matrix_b_right.memory[5] = {8'h30, 8'h30, 8'h30, 8'h30};
        u_matmul.matrix_b_right.memory[6] = {8'h30, 8'h30, 8'h30, 8'h30};
        u_matmul.matrix_b_right.memory[7] = {8'h30, 8'h30, 8'h30, 8'h30};

        resetn = 1'b0;
        pe_resetn = 1'b0;
        #55;
        resetn = 1'b1;
        pe_resetn = 1'b1;
        #60;
        start = 1'b1;
        @(posedge done);
        start = 1'b0;
        #100;

        $display("\nC matrix output for simple-value test:");
        for (word_index = 0; word_index < 8; word_index = word_index + 1)
            $display("C_top[%0d]    = %h", word_index,
                     u_matmul.matrix_c_top.memory[word_index]);
        for (word_index = 0; word_index < 8; word_index = word_index + 1)
            $display("C_bottom[%0d] = %h", word_index,
                     u_matmul.matrix_c_bottom.memory[word_index]);

        $finish;
    end

    initial begin
        $fsdbDumpvars;
    end

endmodule
