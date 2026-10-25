`timescale 1ns / 1ps
parameter DWIDTH = 8;
parameter AWIDTH = 10;
parameter MEM_SIZE = 1024;

parameter MAT_MUL_SIZE = 4;
parameter MASK_WIDTH = 4;
parameter LOG2_MAT_MUL_SIZE = 2;

parameter BB_MAT_MUL_SIZE = MAT_MUL_SIZE;
parameter NUM_CYCLES_IN_MAC = 3;
parameter MEM_ACCESS_LATENCY = 1;
parameter REG_DATAWIDTH = 32;
parameter REG_ADDRWIDTH = 8;
parameter ADDR_STRIDE_WIDTH = 8;
parameter MAX_BITS_POOL = 3;

module matmul_4x4_systolic(
    input   logic   clk,
    input   logic   reset,
    input   logic   pe_reset,
    input   logic   start_mat_mul,
    output  logic   done_mat_mul,
    output  logic   [4:0] flag,
    input   logic   [AWIDTH-1:0] address_mat_a,
    input   logic   [AWIDTH-1:0] address_mat_b,
    input   logic   [AWIDTH-1:0] address_mat_c,
    input   logic   [ADDR_STRIDE_WIDTH-1:0] address_stride_a,
    input   logic   [ADDR_STRIDE_WIDTH-1:0] address_stride_b,
    input   logic   [ADDR_STRIDE_WIDTH-1:0] address_stride_c,
    input   logic   [MAT_MUL_SIZE*DWIDTH-1:0] a_data,
    input   logic   [MAT_MUL_SIZE*DWIDTH-1:0] b_data,
    input   logic   [MAT_MUL_SIZE*DWIDTH-1:0] a_data_in, //Data values coming in from previous matmul - systolic connections
    input   logic   [MAT_MUL_SIZE*DWIDTH-1:0] b_data_in,
    input   logic   [MAT_MUL_SIZE*DWIDTH-1:0] c_data_in, //Data values coming in from previous matmul - systolic shifting
    output  logic   [MAT_MUL_SIZE*DWIDTH-1:0] c_data_out, //Data values going out to next matmul - systolic shifting
    output  logic   [MAT_MUL_SIZE*DWIDTH-1:0] a_data_out,
    output  logic   [MAT_MUL_SIZE*DWIDTH-1:0] b_data_out,
    output  logic   [AWIDTH-1:0] a_addr,
    output  logic   [AWIDTH-1:0] b_addr,
    output  logic   [AWIDTH-1:0] c_addr,
    output  logic   c_data_available,
    input   logic   [MASK_WIDTH-1:0] validity_mask_a_rows,
    input   logic   [MASK_WIDTH-1:0] validity_mask_a_cols_b_rows,
    input   logic   [MASK_WIDTH-1:0] validity_mask_b_cols,
    //7:0 is okay here. We aren't going to make a matmul larger than 128x128
    //In fact, these will get optimized out by the synthesis tool, because
    //we hardcode them at the instantiation level.
    input   logic   [7:0] final_mat_mul_size,
    input   logic   [7:0] a_loc,
    input   logic   [7:0] b_loc
    );


//////////////////////////////////////////////////////////////////////////
// Logic for clock counting and when to assert done
//////////////////////////////////////////////////////////////////////////

    //This is 7 bits because the expectation is that clock count will be pretty
    //small. For large matmuls, this will need to increased to have more bits.
    //In general, a systolic multiplier takes f(N)+P cycles, where N is the size 
    //of the matmul and P is the number of pipleine stages in the MAC block.
    //f(N) is a function describing the number of cycles taken to perform matmul
    //with a systolic array strcture.
    logic [7:0] clk_cnt;
    
    //Finding out number of cycles to assert matmul done.
    logic [7:0] clk_cnt_for_done;
    logic [7:0] cycles_for_matmul; 
        
    assign cycles_for_matmul = 8'd14;
    assign clk_cnt_for_done = (cycles_for_matmul + NUM_CYCLES_IN_MAC) ;  


    always_ff @(posedge clk) 
    begin
        if (reset || ~start_mat_mul) 
        begin
            clk_cnt <= 0;
            done_mat_mul <= 0;
        end
        else if (clk_cnt == clk_cnt_for_done) 
        begin
            done_mat_mul <= 1;
            clk_cnt <= clk_cnt + 1;
        end
        else if (done_mat_mul == 0) 
            clk_cnt <= clk_cnt + 1;   
        else 
        begin
            done_mat_mul <= 0;
            clk_cnt <= clk_cnt + 1;
        end
    end


    logic [DWIDTH-1:0] a0_data;
    logic [DWIDTH-1:0] a1_data;
    logic [DWIDTH-1:0] a2_data;
    logic [DWIDTH-1:0] a3_data;
    logic [DWIDTH-1:0] b0_data;
    logic [DWIDTH-1:0] b1_data;
    logic [DWIDTH-1:0] b2_data;
    logic [DWIDTH-1:0] b3_data;
    logic [DWIDTH-1:0] a1_data_delayed_1;
    logic [DWIDTH-1:0] a2_data_delayed_1;
    logic [DWIDTH-1:0] a2_data_delayed_2;
    logic [DWIDTH-1:0] a3_data_delayed_1;
    logic [DWIDTH-1:0] a3_data_delayed_2;
    logic [DWIDTH-1:0] a3_data_delayed_3;
    logic [DWIDTH-1:0] b1_data_delayed_1;
    logic [DWIDTH-1:0] b2_data_delayed_1;
    logic [DWIDTH-1:0] b2_data_delayed_2;
    logic [DWIDTH-1:0] b3_data_delayed_1;
    logic [DWIDTH-1:0] b3_data_delayed_2;
    logic [DWIDTH-1:0] b3_data_delayed_3;
    
//////////////////////////////////////////////////////////////////////////
// Instantiation of systolic data setup
//////////////////////////////////////////////////////////////////////////
    systolic_data_setup u_systolic_data_setup(.*);


//////////////////////////////////////////////////////////////////////////
// Logic to mux data_in coming from neighboring matmuls
//////////////////////////////////////////////////////////////////////////
    logic [DWIDTH-1:0] a0;
    logic [DWIDTH-1:0] a1;
    logic [DWIDTH-1:0] a2;
    logic [DWIDTH-1:0] a3;
    logic [DWIDTH-1:0] b0;
    logic [DWIDTH-1:0] b1;
    logic [DWIDTH-1:0] b2;
    logic [DWIDTH-1:0] b3;
    
    logic [DWIDTH-1:0] a0_data_in;
    logic [DWIDTH-1:0] a1_data_in;
    logic [DWIDTH-1:0] a2_data_in;
    logic [DWIDTH-1:0] a3_data_in;
    assign a0_data_in = a_data_in[DWIDTH-1:0];
    assign a1_data_in = a_data_in[2*DWIDTH-1:DWIDTH];
    assign a2_data_in = a_data_in[3*DWIDTH-1:2*DWIDTH];
    assign a3_data_in = a_data_in[4*DWIDTH-1:3*DWIDTH];
    
    logic [DWIDTH-1:0] b0_data_in;
    logic [DWIDTH-1:0] b1_data_in;
    logic [DWIDTH-1:0] b2_data_in;
    logic [DWIDTH-1:0] b3_data_in;
    assign b0_data_in = b_data_in[DWIDTH-1:0];
    assign b1_data_in = b_data_in[2*DWIDTH-1:DWIDTH];
    assign b2_data_in = b_data_in[3*DWIDTH-1:2*DWIDTH];
    assign b3_data_in = b_data_in[4*DWIDTH-1:3*DWIDTH];
    
    //If b_loc is 0, that means this matmul block is on the top-row of the
    //final large matmul. In that case, b will take inputs from mem.
    //If b_loc != 0, that means this matmul block is not on the top-row of the
    //final large matmul. In that case, b will take inputs from the matmul on top
    //of this one.
    assign a0 = (b_loc==0) ? a0_data           : a0_data_in;
    assign a1 = (b_loc==0) ? a1_data_delayed_1 : a1_data_in;
    assign a2 = (b_loc==0) ? a2_data_delayed_2 : a2_data_in;
    assign a3 = (b_loc==0) ? a3_data_delayed_3 : a3_data_in;

    //If a_loc is 0, that means this matmul block is on the left-col of the
    //final large matmul. In that case, a will take inputs from mem.
    //If a_loc != 0, that means this matmul block is not on the left-col of the
    //final large matmul. In that case, a will take inputs from the matmul on left
    //of this one.
    assign b0 = (a_loc==0) ? b0_data           : b0_data_in;
    assign b1 = (a_loc==0) ? b1_data_delayed_1 : b1_data_in;
    assign b2 = (a_loc==0) ? b2_data_delayed_2 : b2_data_in;
    assign b3 = (a_loc==0) ? b3_data_delayed_3 : b3_data_in;
    

    logic [DWIDTH-1:0] matrixC00;
    logic [DWIDTH-1:0] matrixC01;
    logic [DWIDTH-1:0] matrixC02;
    logic [DWIDTH-1:0] matrixC03;
    logic [DWIDTH-1:0] matrixC10;
    logic [DWIDTH-1:0] matrixC11;
    logic [DWIDTH-1:0] matrixC12;
    logic [DWIDTH-1:0] matrixC13;
    logic [DWIDTH-1:0] matrixC20;
    logic [DWIDTH-1:0] matrixC21;
    logic [DWIDTH-1:0] matrixC22;
    logic [DWIDTH-1:0] matrixC23;
    logic [DWIDTH-1:0] matrixC30;
    logic [DWIDTH-1:0] matrixC31;
    logic [DWIDTH-1:0] matrixC32;
    logic [DWIDTH-1:0] matrixC33;
    

//////////////////////////////////////////////////////////////////////////
// Instantiation of the output logic
//////////////////////////////////////////////////////////////////////////
    output_logic u_output_logic(.*, .row_latch_en());

//////////////////////////////////////////////////////////////////////////
// Instantiations of the actual PEs
//////////////////////////////////////////////////////////////////////////
    systolic_pe_matrix u_systolic_pe_matrix(.*);

endmodule

//////////////////////////////////////////////////////////////////////////
// Output logic
//////////////////////////////////////////////////////////////////////////
module output_logic(
    input   logic   clk,
    input   logic   reset,
    input   logic   start_mat_mul,
    input   logic   done_mat_mul,
    input   logic   [AWIDTH-1:0] address_mat_c,
    input   logic   [ADDR_STRIDE_WIDTH-1:0] address_stride_c,
    input   logic   [MAT_MUL_SIZE*DWIDTH-1:0] c_data_in,
    output  logic   [MAT_MUL_SIZE*DWIDTH-1:0] c_data_out, //Data values going out to next matmul - systolic shifting
    output  logic   [AWIDTH-1:0] c_addr,
    output  logic   c_data_available,
    input   logic   [7:0] clk_cnt,
    output  logic   row_latch_en,
    input   logic   [7:0] final_mat_mul_size,
    input   logic   [DWIDTH-1:0] matrixC00,
    input   logic   [DWIDTH-1:0] matrixC01,
    input   logic   [DWIDTH-1:0] matrixC02,
    input   logic   [DWIDTH-1:0] matrixC03,
    input   logic   [DWIDTH-1:0] matrixC10,
    input   logic   [DWIDTH-1:0] matrixC11,
    input   logic   [DWIDTH-1:0] matrixC12,
    input   logic   [DWIDTH-1:0] matrixC13,
    input   logic   [DWIDTH-1:0] matrixC20,
    input   logic   [DWIDTH-1:0] matrixC21,
    input   logic   [DWIDTH-1:0] matrixC22,
    input   logic   [DWIDTH-1:0] matrixC23,
    input   logic   [DWIDTH-1:0] matrixC30,
    input   logic   [DWIDTH-1:0] matrixC31,
    input   logic   [DWIDTH-1:0] matrixC32,
    input   logic   [DWIDTH-1:0] matrixC33
    );

//////////////////////////////////////////////////////////////////////////
// Logic to capture matrix C data from the PEs and shift it out
//////////////////////////////////////////////////////////////////////////
    assign row_latch_en = ((clk_cnt == ((final_mat_mul_size<<2) - final_mat_mul_size -1 + NUM_CYCLES_IN_MAC)));
    
    logic start_capturing_c_data;
    integer counter;
    logic [MAT_MUL_SIZE*DWIDTH-1:0] c_data_out_1;
    logic [MAT_MUL_SIZE*DWIDTH-1:0] c_data_out_2;
    logic [MAT_MUL_SIZE*DWIDTH-1:0] c_data_out_3;
    
    logic [MAT_MUL_SIZE*DWIDTH-1:0] col0;
    logic [MAT_MUL_SIZE*DWIDTH-1:0] col1;
    logic [MAT_MUL_SIZE*DWIDTH-1:0] col2;
    logic [MAT_MUL_SIZE*DWIDTH-1:0] col3;
    assign col0 = {matrixC30, matrixC20, matrixC10, matrixC00};
    assign col1 = {matrixC31, matrixC21, matrixC11, matrixC01};
    assign col2 = {matrixC32, matrixC22, matrixC12, matrixC02};
    assign col3 = {matrixC33, matrixC23, matrixC13, matrixC03};

//If save_output_to_accum is asserted, that means we are not intending to shift
//out the outputs, because the outputs are still partial sums. 
    logic condition_to_start_shifting_output;
    assign condition_to_start_shifting_output = row_latch_en ;  

//For larger matmuls, this logic will have more entries in the case statement
    always_ff @(posedge clk) 
    begin
        if (reset | ~start_mat_mul) 
        begin
            start_capturing_c_data <= 1'b0;
            c_data_available <= 1'b0;
            c_addr <= address_mat_c - address_stride_c;
            c_data_out <= 0;
            counter <= 0;
            c_data_out_1 <= 0; 
            c_data_out_2 <= 0; 
            c_data_out_3 <= 0; 
        end
        else if (condition_to_start_shifting_output) 
        begin
            start_capturing_c_data <= 1'b1;
            c_data_available <= 1'b1;
            c_addr <= c_addr + address_stride_c;
            c_data_out <= col0; 
            c_data_out_1 <= col1; 
            c_data_out_2 <= col2; 
            c_data_out_3 <= col3; 
            counter <= counter + 1;
        end 
        else if (done_mat_mul) 
        begin
            start_capturing_c_data <= 1'b0;
            c_data_available <= 1'b0;
            c_addr <= address_mat_c+address_stride_c;
            c_data_out <= 0;
            c_data_out_1 <= 0;
            c_data_out_2 <= 0;
            c_data_out_3 <= 0;
        end 
        else if (counter >= MAT_MUL_SIZE) 
        begin
            c_addr <= c_addr + address_stride_c;
            c_data_out <= c_data_out_1;
            c_data_out_1 <= c_data_out_2;
            c_data_out_2 <= c_data_out_3;
            c_data_out_3 <= c_data_in;
        end
        else if (start_capturing_c_data) 
        begin
            c_data_available <= 1'b1;
            c_addr <= c_addr + address_stride_c;
            counter <= counter + 1;
            c_data_out <= c_data_out_1;
            c_data_out_1 <= c_data_out_2;
            c_data_out_2 <= c_data_out_3;
            c_data_out_3 <= c_data_in;
        end
    end

endmodule

//////////////////////////////////////////////////////////////////////////
// Systolic data setup
//////////////////////////////////////////////////////////////////////////
module systolic_data_setup(
    input   logic   clk,
    input   logic   reset,
    input   logic   start_mat_mul,
    output  logic   [AWIDTH-1:0] a_addr,
    output  logic   [AWIDTH-1:0] b_addr,
    input   logic   [AWIDTH-1:0] address_mat_a,
    input   logic   [AWIDTH-1:0] address_mat_b,
    input   logic   [ADDR_STRIDE_WIDTH-1:0] address_stride_a,
    input   logic   [ADDR_STRIDE_WIDTH-1:0] address_stride_b,
    input   logic   [MAT_MUL_SIZE*DWIDTH-1:0] a_data,
    input   logic   [MAT_MUL_SIZE*DWIDTH-1:0] b_data,
    input   logic   [7:0] clk_cnt,
    output  logic   [DWIDTH-1:0] a0_data,
    output  logic   [DWIDTH-1:0] a1_data_delayed_1,
    output  logic   [DWIDTH-1:0] a2_data_delayed_2,
    output  logic   [DWIDTH-1:0] a3_data_delayed_3,
    output  logic   [DWIDTH-1:0] b0_data,
    output  logic   [DWIDTH-1:0] b1_data_delayed_1,
    output  logic   [DWIDTH-1:0] b2_data_delayed_2,
    output  logic   [DWIDTH-1:0] b3_data_delayed_3,
    input   logic   [MASK_WIDTH-1:0] validity_mask_a_rows,
    input   logic   [MASK_WIDTH-1:0] validity_mask_a_cols_b_rows,
    input   logic   [MASK_WIDTH-1:0] validity_mask_b_cols,
    input   logic   [7:0] final_mat_mul_size,
    input   logic   [7:0] a_loc,
    input   logic   [7:0] b_loc
    );

    logic [DWIDTH-1:0] a1_data;
    logic [DWIDTH-1:0] a2_data;
    logic [DWIDTH-1:0] a3_data;
    logic [DWIDTH-1:0] b1_data;
    logic [DWIDTH-1:0] b2_data;
    logic [DWIDTH-1:0] b3_data;

//////////////////////////////////////////////////////////////////////////
// Logic to generate addresses to BRAM A
//////////////////////////////////////////////////////////////////////////
    logic a_mem_access; //flag that tells whether the matmul is trying to access memory or not
    
    always_ff @(posedge clk) 
    begin
        if ((reset || ~start_mat_mul) || (clk_cnt >= (a_loc<<LOG2_MAT_MUL_SIZE)+final_mat_mul_size)) begin
            a_addr <= address_mat_a-address_stride_a;
            a_mem_access <= 0;
        end
        else if ((clk_cnt >= (a_loc<<LOG2_MAT_MUL_SIZE)) && (clk_cnt < (a_loc<<LOG2_MAT_MUL_SIZE)+final_mat_mul_size)) 
        begin
            a_addr <= a_addr + address_stride_a;
            a_mem_access <= 1;
        end
    end  

//////////////////////////////////////////////////////////////////////////
// Logic to generate valid signals for data coming from BRAM A
//////////////////////////////////////////////////////////////////////////
    logic [7:0] a_mem_access_counter;
    always_ff @(posedge clk) 
    begin
        if (reset || ~start_mat_mul) 
            a_mem_access_counter <= 0;
        else if (a_mem_access == 1) 
            a_mem_access_counter <= a_mem_access_counter + 1;  
        else 
            a_mem_access_counter <= 0;
    end

    logic a_data_valid; //flag that tells whether the data from memory is valid
    assign a_data_valid = 
        ((validity_mask_a_cols_b_rows[0]==1'b0 && a_mem_access_counter==1) ||
        (validity_mask_a_cols_b_rows[1]==1'b0 && a_mem_access_counter==2) ||
        (validity_mask_a_cols_b_rows[2]==1'b0 && a_mem_access_counter==3) ||
        (validity_mask_a_cols_b_rows[3]==1'b0 && a_mem_access_counter==4)) ?
        1'b0 : (a_mem_access_counter >= MEM_ACCESS_LATENCY);
    
//////////////////////////////////////////////////////////////////////////
// Logic to delay certain parts of the data received from BRAM A (systolic data setup)
//////////////////////////////////////////////////////////////////////////
//Slice data into chunks and qualify it with whether it is valid or not
    assign a0_data = a_data[DWIDTH-1:0] & {DWIDTH{a_data_valid}} & {DWIDTH{validity_mask_a_rows[0]}};
    assign a1_data = a_data[2*DWIDTH-1:DWIDTH] & {DWIDTH{a_data_valid}} & {DWIDTH{validity_mask_a_rows[1]}};
    assign a2_data = a_data[3*DWIDTH-1:2*DWIDTH] & {DWIDTH{a_data_valid}} & {DWIDTH{validity_mask_a_rows[2]}};
    assign a3_data = a_data[4*DWIDTH-1:3*DWIDTH] & {DWIDTH{a_data_valid}} & {DWIDTH{validity_mask_a_rows[3]}};

//For larger matmuls, more such delaying flops will be needed
    logic [DWIDTH-1:0] a2_data_delayed_1;
    logic [DWIDTH-1:0] a3_data_delayed_1;
    logic [DWIDTH-1:0] a3_data_delayed_2;
    
    always_ff @(posedge clk) 
    begin
        if (reset || ~start_mat_mul || clk_cnt==0) 
        begin
            a1_data_delayed_1 <= 0;
            a2_data_delayed_1 <= 0;
            a2_data_delayed_2 <= 0;
            a3_data_delayed_1 <= 0;
            a3_data_delayed_2 <= 0;
            a3_data_delayed_3 <= 0;
        end
        else 
        begin
            a1_data_delayed_1 <= a1_data;
            a2_data_delayed_1 <= a2_data;
            a2_data_delayed_2 <= a2_data_delayed_1;
            a3_data_delayed_1 <= a3_data;
            a3_data_delayed_2 <= a3_data_delayed_1;
            a3_data_delayed_3 <= a3_data_delayed_2;
        end
    end

//////////////////////////////////////////////////////////////////////////
// Logic to generate addresses to BRAM B
//////////////////////////////////////////////////////////////////////////
    logic b_mem_access; //flag that tells whether the matmul is trying to access memory or not

    always_ff @(posedge clk) 
    begin
        if ((reset || ~start_mat_mul) || (clk_cnt >= (b_loc<<LOG2_MAT_MUL_SIZE)+final_mat_mul_size)) 
        begin
            b_addr <= address_mat_b - address_stride_b;
            b_mem_access <= 0;
        end
        else if ((clk_cnt >= (b_loc<<LOG2_MAT_MUL_SIZE)) && (clk_cnt < (b_loc<<LOG2_MAT_MUL_SIZE)+final_mat_mul_size)) 
        begin
            b_addr <= b_addr + address_stride_b;
            b_mem_access <= 1;
        end
    end  

//////////////////////////////////////////////////////////////////////////
// Logic to generate valid signals for data coming from BRAM B
//////////////////////////////////////////////////////////////////////////
    logic [7:0] b_mem_access_counter;
    always_ff @(posedge clk) 
    begin
        if (reset || ~start_mat_mul) 
            b_mem_access_counter <= 0;
        else if (b_mem_access == 1)
            b_mem_access_counter <= b_mem_access_counter + 1;  
        else
            b_mem_access_counter <= 0;
    end

    logic b_data_valid; //flag that tells whether the data from memory is valid
    assign b_data_valid = 
        ((validity_mask_a_cols_b_rows[0]==1'b0 && b_mem_access_counter==1) ||
        (validity_mask_a_cols_b_rows[1]==1'b0 && b_mem_access_counter==2) ||
        (validity_mask_a_cols_b_rows[2]==1'b0 && b_mem_access_counter==3) ||
        (validity_mask_a_cols_b_rows[3]==1'b0 && b_mem_access_counter==4)) ?
        1'b0 : (b_mem_access_counter >= MEM_ACCESS_LATENCY);


//////////////////////////////////////////////////////////////////////////
// Logic to delay certain parts of the data received from BRAM B (systolic data setup)
//////////////////////////////////////////////////////////////////////////
//Slice data into chunks and qualify it with whether it is valid or not
    assign b0_data = b_data[DWIDTH-1:0] & {DWIDTH{b_data_valid}} & {DWIDTH{validity_mask_b_cols[0]}};
    assign b1_data = b_data[2*DWIDTH-1:DWIDTH] & {DWIDTH{b_data_valid}} & {DWIDTH{validity_mask_b_cols[1]}};
    assign b2_data = b_data[3*DWIDTH-1:2*DWIDTH] & {DWIDTH{b_data_valid}} & {DWIDTH{validity_mask_b_cols[2]}};
    assign b3_data = b_data[4*DWIDTH-1:3*DWIDTH] & {DWIDTH{b_data_valid}} & {DWIDTH{validity_mask_b_cols[3]}};

//For larger matmuls, more such delaying flops will be needed
    logic [DWIDTH-1:0] b2_data_delayed_1;
    logic [DWIDTH-1:0] b3_data_delayed_1;
    logic [DWIDTH-1:0] b3_data_delayed_2;
    
    always_ff @(posedge clk) 
    begin
        if (reset || ~start_mat_mul || clk_cnt==0) 
        begin
            b1_data_delayed_1 <= 0;
            b2_data_delayed_1 <= 0;
            b2_data_delayed_2 <= 0;
            b3_data_delayed_1 <= 0;
            b3_data_delayed_2 <= 0;
            b3_data_delayed_3 <= 0;
        end
        else 
        begin
            b1_data_delayed_1 <= b1_data;
            b2_data_delayed_1 <= b2_data;
            b2_data_delayed_2 <= b2_data_delayed_1;
            b3_data_delayed_1 <= b3_data;
            b3_data_delayed_2 <= b3_data_delayed_1;
            b3_data_delayed_3 <= b3_data_delayed_2;
        end
    end

endmodule



//////////////////////////////////////////////////////////////////////////
// Systolically connected PEs
//////////////////////////////////////////////////////////////////////////
module systolic_pe_matrix(
    input   logic   clk,
    input   logic   reset,
    input   logic   pe_reset,
    input   logic   start_mat_mul,
    input   logic   [DWIDTH-1:0] a0,
    input   logic   [DWIDTH-1:0] a1,
    input   logic   [DWIDTH-1:0] a2,
    input   logic   [DWIDTH-1:0] a3,
    input   logic   [DWIDTH-1:0] b0,
    input   logic   [DWIDTH-1:0] b1,
    input   logic   [DWIDTH-1:0] b2,
    input   logic   [DWIDTH-1:0] b3,
    output  logic   [DWIDTH-1:0] matrixC00,
    output  logic   [DWIDTH-1:0] matrixC01,
    output  logic   [DWIDTH-1:0] matrixC02,
    output  logic   [DWIDTH-1:0] matrixC03,
    output  logic   [DWIDTH-1:0] matrixC10,
    output  logic   [DWIDTH-1:0] matrixC11,
    output  logic   [DWIDTH-1:0] matrixC12,
    output  logic   [DWIDTH-1:0] matrixC13,
    output  logic   [DWIDTH-1:0] matrixC20,
    output  logic   [DWIDTH-1:0] matrixC21,
    output  logic   [DWIDTH-1:0] matrixC22,
    output  logic   [DWIDTH-1:0] matrixC23,
    output  logic   [DWIDTH-1:0] matrixC30,
    output  logic   [DWIDTH-1:0] matrixC31,
    output  logic   [DWIDTH-1:0] matrixC32,
    output  logic   [DWIDTH-1:0] matrixC33,
    output  logic   [MAT_MUL_SIZE*DWIDTH-1:0] a_data_out,
    output  logic   [MAT_MUL_SIZE*DWIDTH-1:0] b_data_out,
    output  logic   [4:0] flag
    );

    logic [DWIDTH-1:0] a00to01, a01to02, a02to03, a03to04;
    logic [DWIDTH-1:0] a10to11, a11to12, a12to13, a13to14;
    logic [DWIDTH-1:0] a20to21, a21to22, a22to23, a23to24;
    logic [DWIDTH-1:0] a30to31, a31to32, a32to33, a33to34;
    
    logic [DWIDTH-1:0] b00to10, b10to20, b20to30, b30to40; 
    logic [DWIDTH-1:0] b01to11, b11to21, b21to31, b31to41;
    logic [DWIDTH-1:0] b02to12, b12to22, b22to32, b32to42;
    logic [DWIDTH-1:0] b03to13, b13to23, b23to33, b33to43;
    
    logic [4:0] flag00, flag10, flag20, flag30; 
    logic [4:0] flag01, flag11, flag21, flag31;
    logic [4:0] flag02, flag12, flag22, flag32;
    logic [4:0] flag03, flag13, flag23, flag33;
    
    logic effective_rst;
    assign effective_rst = reset | pe_reset;
    
    
    //There are a total of 16 PEs arranged in a mesh structure like in the lecture slides. 	
	//Each PE has a number. PE00 is the top-left PE. PE01 is the second PE on the first row. 
	//PE10 is the first PE on the second row. PE33 is the bottom right PE.	
    //Signals a0, a1, a2, a3 are coming from matrix A. They need to be be connected to the first column of PEs.
	//b0, b1, b2, b3 signals are coming from matrix B. They need to be connected to the first row of the PEs.
	//Signals axytozw go from PExy to PEzw horizontally.
	//Signals bxytozw go from PExy to PEzw vertically.
	//Signals matrixCxx are the output results from each PE.
	//Reset and clock signals of all PEs are the same.	

	processing_element pe00(.reset(effective_rst), .clk(clk), .in_a(a0),      .in_b(b0), .out_a(a00to01), .out_b(b00to10), .out_c(matrixC00), .flag(flag00));
	processing_element pe01(.reset(effective_rst), .clk(clk), .in_a(a00to01), .in_b(b1), .out_a(a01to02), .out_b(b01to11), .out_c(matrixC01), .flag(flag01));
	processing_element pe02(.reset(effective_rst), .clk(clk), .in_a(a01to02), .in_b(b2), .out_a(a02to03), .out_b(b02to12), .out_c(matrixC02), .flag(flag02));
	processing_element pe03(.reset(effective_rst), .clk(clk), .in_a(a02to03), .in_b(b3), .out_a(a03to04), .out_b(b03to13), .out_c(matrixC03), .flag(flag03));
	processing_element pe10(.reset(effective_rst), .clk(clk), .in_a(a1),      .in_b(b00to10), .out_a(a10to11), .out_b(b10to20), .out_c(matrixC10), .flag(flag10));
	processing_element pe11(.reset(effective_rst), .clk(clk), .in_a(a10to11), .in_b(b01to11), .out_a(a11to12), .out_b(b11to21), .out_c(matrixC11), .flag(flag11));
	processing_element pe12(.reset(effective_rst), .clk(clk), .in_a(a11to12), .in_b(b02to12), .out_a(a12to13), .out_b(b12to22), .out_c(matrixC12), .flag(flag12));
	processing_element pe13(.reset(effective_rst), .clk(clk), .in_a(a12to13), .in_b(b03to13), .out_a(a13to14), .out_b(b13to23), .out_c(matrixC13), .flag(flag13));
	processing_element pe20(.reset(effective_rst), .clk(clk), .in_a(a2),      .in_b(b10to20), .out_a(a20to21), .out_b(b20to30), .out_c(matrixC20), .flag(flag20));
	processing_element pe21(.reset(effective_rst), .clk(clk), .in_a(a20to21), .in_b(b11to21), .out_a(a21to22), .out_b(b21to31), .out_c(matrixC21), .flag(flag21));
	processing_element pe22(.reset(effective_rst), .clk(clk), .in_a(a21to22), .in_b(b12to22), .out_a(a22to23), .out_b(b22to32), .out_c(matrixC22), .flag(flag22));
	processing_element pe23(.reset(effective_rst), .clk(clk), .in_a(a22to23), .in_b(b13to23), .out_a(a23to24), .out_b(b23to33), .out_c(matrixC23), .flag(flag23));
	processing_element pe30(.reset(effective_rst), .clk(clk), .in_a(a3),      .in_b(b20to30), .out_a(a30to31), .out_b(b30to40), .out_c(matrixC30), .flag(flag30));
	processing_element pe31(.reset(effective_rst), .clk(clk), .in_a(a30to31), .in_b(b21to31), .out_a(a31to32), .out_b(b31to41), .out_c(matrixC31), .flag(flag31));
	processing_element pe32(.reset(effective_rst), .clk(clk), .in_a(a31to32), .in_b(b22to32), .out_a(a32to33), .out_b(b32to42), .out_c(matrixC32), .flag(flag32));
	processing_element pe33(.reset(effective_rst), .clk(clk), .in_a(a32to33), .in_b(b23to33), .out_a(a33to34), .out_b(b33to43), .out_c(matrixC33), .flag(flag33));

    assign a_data_out = {a33to34,a23to24,a13to14,a03to04};
    assign b_data_out = {b33to43,b32to42,b31to41,b30to40};
    assign flag = (flag00 | flag01 | flag02 | flag03 |
                   flag10 | flag11 | flag12 | flag13 |
                   flag20 | flag21 | flag22 | flag23 |
                   flag30 | flag31 | flag32 | flag33);

endmodule


//////////////////////////////////////////////////////////////////////////
// Processing element (PE)
//////////////////////////////////////////////////////////////////////////
module processing_element(
    input   logic   reset,
    input   logic   clk,
    input   logic   [DWIDTH-1:0] in_a,
    input   logic   [DWIDTH-1:0] in_b,
    output  logic   [DWIDTH-1:0] out_a,
    output  logic   [DWIDTH-1:0] out_b,
    output  logic   [DWIDTH-1:0] out_c,  //reduced precision
    output  logic   [4:0] flag
    );

    logic [DWIDTH-1:0] out_mac;

    assign out_c = out_mac;
    
    seq_mac u_mac(.a(in_a), .b(in_b), .out(out_mac), .flag(flag), .reset(reset), .clk(clk));

    always_ff @(posedge clk)
    begin
        if(reset) 
        begin
            out_a<=0;
            out_b<=0;
        end
        else 
        begin  
            out_a<=in_a;
            out_b<=in_b;
        end
    end

endmodule

//////////////////////////////////////////////////////////////////////////
// Multiply-and-accumulate (MAC) block
//////////////////////////////////////////////////////////////////////////
module seq_mac (
    input  logic clk,
    input  logic reset,
    input  logic [DWIDTH-1:0] a,
    input  logic [DWIDTH-1:0] b,
    output logic [DWIDTH-1:0] out,
    output logic [4:0]        flag
);

    logic [DWIDTH-1:0] a_flop, b_flop, mult, mult_reg, add;
    logic [4:0] mult_flag, add_flag, flag_reg;

    // exponent==0 -> zero (no denormals); exponent==7 -> inf/NaN
    logic a_z, b_z, mr_z, o_z, a_s, b_s, mr_s, o_s;
    logic mult_exact, add_exact;

    // checks if any operands are zero
    assign a_z  = (a_flop[6:4]   == 3'd0);
    assign b_z  = (b_flop[6:4]   == 3'd0);
    assign mult_z = (mult_reg[6:4] == 3'd0);
    assign out_z  = (out[6:4]      == 3'd0);

    // checks if any operands are special (inf/NaN)
    assign a_s  = (a_flop[6:4]   == 3'd7);
    assign b_s  = (b_flop[6:4]   == 3'd7);
    assign mult_s = (mult_reg[6:4] == 3'd7);
    assign out_s  = (out[6:4]      == 3'd7);

    assign mult_exact = (a_z  | b_z) & ~(a_s  | b_s);   // 0*x is exact
    assign add_exact  = (mult_z | out_z) & ~(mult_s | out_s);   // 0+x is exact

    // in the always_ff else-branch:
    flag_reg <= flag_reg                      // sticky, see below
              | (mult_exact ? 5'b0 : mult_flag)
              | (add_exact  ? 5'b0 : add_flag);

    fp8_mul multiplier (.clk(clk), .rst(reset), .A(a_flop),   .B(b_flop), .result(mult), .flags(mult_flag));
    fp8_add  adder      (.A(mult_reg), .B(out),    .Result(add),  .Flags(add_flag));

    always_ff @(posedge clk) begin
        if (reset) begin
            a_flop   <= '0;
            b_flop   <= '0;
            mult_reg <= '0;
            out      <= '0;
            flag_reg <= 1'b0;
        end
        else begin
            a_flop   <= a;
            b_flop   <= b;
            mult_reg <= mult;
            out      <= add;
            flag_reg <= mult_flag | add_flag;
        end
    end

    assign flag = flag_reg;

endmodule
