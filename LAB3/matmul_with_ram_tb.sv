`timescale 1ns/1ns

module matmul_tb;

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
        u_matmul.matrix_a_top.memory[0] = {8'd1, 8'd1, 8'd1, 8'd1};
        u_matmul.matrix_a_top.memory[1] = {8'd1, 8'd1, 8'd1, 8'd1};
        u_matmul.matrix_a_top.memory[2] = {8'd1, 8'd1, 8'd1, 8'd1};
        u_matmul.matrix_a_top.memory[3] = {8'd1, 8'd1, 8'd1, 8'd1};
        u_matmul.matrix_a_top.memory[4] = {8'd1, 8'd1, 8'd1, 8'd1};
        u_matmul.matrix_a_top.memory[5] = {8'd1, 8'd1, 8'd1, 8'd1};
        u_matmul.matrix_a_top.memory[6] = {8'd1, 8'd1, 8'd1, 8'd1};
        u_matmul.matrix_a_top.memory[7] = {8'd1, 8'd1, 8'd1, 8'd1};
        u_matmul.matrix_a_bottom.memory[0] = {8'd1, 8'd1, 8'd1, 8'd1};
        u_matmul.matrix_a_bottom.memory[1] = {8'd1, 8'd1, 8'd1, 8'd1};
        u_matmul.matrix_a_bottom.memory[2] = {8'd1, 8'd1, 8'd1, 8'd1};
        u_matmul.matrix_a_bottom.memory[3] = {8'd1, 8'd1, 8'd1, 8'd1};
        u_matmul.matrix_a_bottom.memory[4] = {8'd1, 8'd1, 8'd1, 8'd1};
        u_matmul.matrix_a_bottom.memory[5] = {8'd1, 8'd1, 8'd1, 8'd1};
        u_matmul.matrix_a_bottom.memory[6] = {8'd1, 8'd1, 8'd1, 8'd1};
        u_matmul.matrix_a_bottom.memory[7] = {8'd1, 8'd1, 8'd1, 8'd1};

        // B is stored by row: each word contains four columns.
        u_matmul.matrix_b_left.memory[0] = {8'd1, 8'd1, 8'd1, 8'd1};
        u_matmul.matrix_b_left.memory[1] = {8'd1, 8'd1, 8'd1, 8'd1};
        u_matmul.matrix_b_left.memory[2] = {8'd1, 8'd1, 8'd1, 8'd1};
        u_matmul.matrix_b_left.memory[3] = {8'd1, 8'd1, 8'd1, 8'd1};
        u_matmul.matrix_b_left.memory[4] = {8'd1, 8'd1, 8'd1, 8'd1};
        u_matmul.matrix_b_left.memory[5] = {8'd1, 8'd1, 8'd1, 8'd1};
        u_matmul.matrix_b_left.memory[6] = {8'd1, 8'd1, 8'd1, 8'd1};
        u_matmul.matrix_b_left.memory[7] = {8'd1, 8'd1, 8'd1, 8'd1};
        u_matmul.matrix_b_right.memory[0] = {8'd1, 8'd1, 8'd1, 8'd1};
        u_matmul.matrix_b_right.memory[1] = {8'd1, 8'd1, 8'd1, 8'd1};
        u_matmul.matrix_b_right.memory[2] = {8'd1, 8'd1, 8'd1, 8'd1};
        u_matmul.matrix_b_right.memory[3] = {8'd1, 8'd1, 8'd1, 8'd1};
        u_matmul.matrix_b_right.memory[4] = {8'd1, 8'd1, 8'd1, 8'd1};
        u_matmul.matrix_b_right.memory[5] = {8'd1, 8'd1, 8'd1, 8'd1};
        u_matmul.matrix_b_right.memory[6] = {8'd1, 8'd1, 8'd1, 8'd1};
        u_matmul.matrix_b_right.memory[7] = {8'd1, 8'd1, 8'd1, 8'd1};
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

        // Second test: every A and B element has a distinct value.
        // A remains row-major; B remains column-major.
        u_matmul.matrix_a_top.memory[0] = {8'd25, 8'd17, 8'd9, 8'd1};
        u_matmul.matrix_a_top.memory[1] = {8'd26, 8'd18, 8'd10, 8'd2};
        u_matmul.matrix_a_top.memory[2] = {8'd27, 8'd19, 8'd11, 8'd3};
        u_matmul.matrix_a_top.memory[3] = {8'd28, 8'd20, 8'd12, 8'd4};
        u_matmul.matrix_a_top.memory[4] = {8'd29, 8'd21, 8'd13, 8'd5};
        u_matmul.matrix_a_top.memory[5] = {8'd30, 8'd22, 8'd14, 8'd6};
        u_matmul.matrix_a_top.memory[6] = {8'd31, 8'd23, 8'd15, 8'd7};
        u_matmul.matrix_a_top.memory[7] = {8'd32, 8'd24, 8'd16, 8'd8};
        u_matmul.matrix_a_bottom.memory[0] = {8'd57, 8'd49, 8'd41, 8'd33};
        u_matmul.matrix_a_bottom.memory[1] = {8'd58, 8'd50, 8'd42, 8'd34};
        u_matmul.matrix_a_bottom.memory[2] = {8'd59, 8'd51, 8'd43, 8'd35};
        u_matmul.matrix_a_bottom.memory[3] = {8'd60, 8'd52, 8'd44, 8'd36};
        u_matmul.matrix_a_bottom.memory[4] = {8'd61, 8'd53, 8'd45, 8'd37};
        u_matmul.matrix_a_bottom.memory[5] = {8'd62, 8'd54, 8'd46, 8'd38};
        u_matmul.matrix_a_bottom.memory[6] = {8'd63, 8'd55, 8'd47, 8'd39};
        u_matmul.matrix_a_bottom.memory[7] = {8'd64, 8'd56, 8'd48, 8'd40};

        u_matmul.matrix_b_left.memory[0] = {8'd68, 8'd67, 8'd66, 8'd65};
        u_matmul.matrix_b_left.memory[1] = {8'd72, 8'd71, 8'd70, 8'd69};
        u_matmul.matrix_b_left.memory[2] = {8'd76, 8'd75, 8'd74, 8'd73};
        u_matmul.matrix_b_left.memory[3] = {8'd80, 8'd79, 8'd78, 8'd77};
        u_matmul.matrix_b_left.memory[4] = {8'd84, 8'd83, 8'd82, 8'd81};
        u_matmul.matrix_b_left.memory[5] = {8'd88, 8'd87, 8'd86, 8'd85};
        u_matmul.matrix_b_left.memory[6] = {8'd92, 8'd91, 8'd90, 8'd89};
        u_matmul.matrix_b_left.memory[7] = {8'd96, 8'd94, 8'd95, 8'd93};
        u_matmul.matrix_b_right.memory[0] = {8'd100, 8'd99, 8'd98, 8'd97};
        u_matmul.matrix_b_right.memory[1] = {8'd104, 8'd103, 8'd102, 8'd101};
        u_matmul.matrix_b_right.memory[2] = {8'd108, 8'd107, 8'd106, 8'd105};
        u_matmul.matrix_b_right.memory[3] = {8'd112, 8'd111, 8'd110, 8'd109};
        u_matmul.matrix_b_right.memory[4] = {8'd116, 8'd115, 8'd114, 8'd113};
        u_matmul.matrix_b_right.memory[5] = {8'd120, 8'd119, 8'd118, 8'd117};
        u_matmul.matrix_b_right.memory[6] = {8'd124, 8'd123, 8'd122, 8'd121};
        u_matmul.matrix_b_right.memory[7] = {8'd128, 8'd127, 8'd126, 8'd125};

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

        $display("\nC matrix output for distinct-value test:");
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
