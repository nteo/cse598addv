/* 8x8 Systolic Matrix Multiplier Design
 *
 * Consists of 4 matmul_4x4_systolic blocks from matmul.sv and interconnect.
*/

module matmul_8x8 #(
    parameter DWIDTH             = 8,
    parameter AWIDTH             = 10,
    parameter MAT_MUL_SIZE       = 4,
    parameter ADDR_STRIDE_WIDTH  = 8
)(
    input logic clk,
    input logic reset,
    input logic pe_reset,
    input logic start_mat_mul,
    input logic [AWIDTH-1:0] address_mat_a_top,
    input logic [AWIDTH-1:0] address_mat_a_bottom,
    input logic [AWIDTH-1:0] address_mat_b_left,
    input logic [AWIDTH-1:0] address_mat_b_right,
    input logic [AWIDTH-1:0] address_mat_c_top,
    input logic [AWIDTH-1:0] address_mat_c_bottom,
    input logic [ADDR_STRIDE_WIDTH-1:0] address_stride_a_top,
    input logic [ADDR_STRIDE_WIDTH-1:0] address_stride_a_bottom,
    input logic [ADDR_STRIDE_WIDTH-1:0] address_stride_b_left,
    input logic [ADDR_STRIDE_WIDTH-1:0] address_stride_b_right,
    input logic [ADDR_STRIDE_WIDTH-1:0] address_stride_c_top,
    input logic [ADDR_STRIDE_WIDTH-1:0] address_stride_c_bottom,
    input logic [MAT_MUL_SIZE*DWIDTH-1:0] a_data_top,
    input logic [MAT_MUL_SIZE*DWIDTH-1:0] a_data_bottom,
    input logic [MAT_MUL_SIZE*DWIDTH-1:0] b_data_left,
    input logic [MAT_MUL_SIZE*DWIDTH-1:0] b_data_right,
    output logic [MAT_MUL_SIZE*DWIDTH-1:0] c_data_out_top,
    output logic [MAT_MUL_SIZE*DWIDTH-1:0] c_data_out_bottom,
    output logic [AWIDTH-1:0] a_addr_top,
    output logic [AWIDTH-1:0] a_addr_bottom,
    output logic [AWIDTH-1:0] b_addr_left,
    output logic [AWIDTH-1:0] b_addr_right,
    output logic [AWIDTH-1:0] c_addr_top,
    output logic [AWIDTH-1:0] c_addr_bottom,
    output logic done_mat_mul,
    output logic c_data_available
);

// Internal signals
// A flows downward and B flows rightward
logic [MAT_MUL_SIZE*DWIDTH-1:0] a_data_out00;
logic [MAT_MUL_SIZE*DWIDTH-1:0] b_data_out00;
logic [MAT_MUL_SIZE*DWIDTH-1:0] b_data_out01;
logic [MAT_MUL_SIZE*DWIDTH-1:0] a_data_out10;

logic c_valid00, c_valid01, c_valid10, c_valid11;
logic done00, done01, done10, done11;

//////////////////////////////////////////////////////////////////////////
// Instantiation of 4 matmul_4x4_systolic blocks
//////////////////////////////////////////////////////////////////////////

matmul_4x4_systolic matmul_4x4_systolic_00(
    // Connect ports
    .clk(clk),
    .reset(reset),
    .pe_reset(pe_reset),
    .start_mat_mul(start_mat_mul),
    .done_mat_mul(done00),
    .address_mat_a(address_mat_a_top),
    .address_mat_b(address_mat_b_left),
    .address_mat_c(address_mat_c_top),
    .address_stride_a(address_stride_a_top),
    .address_stride_b(address_stride_b_left),
    .address_stride_c(address_stride_c_top),
    .a_data(a_data_top),
    .b_data(b_data_left),
    .a_data_in(), // Not connected to memory or other 4x4
    .b_data_in(), // Not connected to memory or other 4x4
    .c_data_in('0),
    .c_data_out(c_data_out00),
    .a_data_out(a_data_out00),
    .b_data_out(b_data_out00),
    .a_addr(a_addr_top),
    .b_addr(b_addr_left),
    .c_addr(), // Not connected to memory
    .c_data_available(c_valid00),
    .validity_mask_a_rows(4'b1111), // Tie validity_mask* values to default values
    .validity_mask_a_cols_b_rows(4'b1111),
    .validity_mask_b_cols(4'b1111),
    .final_mat_mul_size('d8),
    .a_loc('d0),
    .b_loc('d0)
);

matmul_4x4_systolic matmul_4x4_systolic_01(
    // Connect ports
    .clk(clk),
    .reset(reset),
    .pe_reset(pe_reset),
    .start_mat_mul(start_mat_mul),
    .done_mat_mul(done01),
    .address_mat_a(address_mat_a_top),
    .address_mat_b(address_mat_b_right),
    .address_mat_c(address_mat_c_top),
    .address_stride_a(address_stride_a_top),
    .address_stride_b(address_stride_b_right),
    .address_stride_c(address_stride_c_top),
    .a_data(), // Not connected to memory or other 4x4
    .b_data(b_data_right),
    .a_data_in(a_data_out00),
    .b_data_in(), // Not connected to memory or other 4x4
    .c_data_in(c_data_out00),
    .c_data_out(c_data_out_top),
    .a_data_out(),
    .b_data_out(b_data_out01),
    .a_addr(),
    .b_addr(b_addr_right),
    .c_addr(c_addr_top),
    .c_data_available(c_valid01),
    .validity_mask_a_rows(4'b1111), // Tie validity_mask* values to default values
    .validity_mask_a_cols_b_rows(4'b1111),
    .validity_mask_b_cols(4'b1111),
    .final_mat_mul_size('d8),
    .a_loc('d0),
    .b_loc('d1)
);

matmul_4x4_systolic matmul_4x4_systolic_10(
    // Connect ports
    .clk(clk),
    .reset(reset),
    .pe_reset(pe_reset),
    .start_mat_mul(start_mat_mul),
    .done_mat_mul(done10),
    .address_mat_a(address_mat_a_bottom),
    .address_mat_b(address_mat_b_left),
    .address_mat_c(address_mat_c_bottom),
    .address_stride_a(address_stride_a_bottom),
    .address_stride_b(address_stride_b_left),
    .address_stride_c(address_stride_c_bottom),
    .a_data(a_data_bottom),
    .b_data(), // Not connected to memory or other 4x4
    .a_data_in(), // Not connected to memory or other 4x4
    .b_data_in(b_data_out00),
    .c_data_in('0),
    .c_data_out(c_data_out10),
    .a_data_out(a_data_out10),
    .b_data_out(),
    .a_addr(a_addr_bottom),
    .b_addr(),
    .c_addr(), // Not connected to memory
    .c_data_available(c_valid10),
    .validity_mask_a_rows(4'b1111), // Tie validity_mask* values to default values
    .validity_mask_a_cols_b_rows(4'b1111),
    .validity_mask_b_cols(4'b1111),
    .final_mat_mul_size('d8),
    .a_loc('d1),
    .b_loc('d0)
);

matmul_4x4_systolic matmul_4x4_systolic_11(
    // Connect ports
    .clk(clk),
    .reset(reset),
    .pe_reset(pe_reset),
    .start_mat_mul(start_mat_mul),
    .done_mat_mul(done11),
    .address_mat_a(address_mat_a_bottom),
    .address_mat_b(address_mat_b_right),
    .address_mat_c(address_mat_c_bottom),
    .address_stride_a(address_stride_a_bottom),
    .address_stride_b(address_stride_b_right),
    .address_stride_c(address_stride_c_bottom),
    .a_data(), // Not connected to memory or other 4x4
    .b_data(), // Not connected to memory or other 4x4
    .a_data_in(a_data_out10),
    .b_data_in(b_data_out01),
    .c_data_in(c_data_out10),
    .c_data_out(c_data_out_bottom),
    .a_data_out(),
    .b_data_out(),
    .a_addr(),
    .b_addr(),
    .c_addr(c_addr_bottom),
    .c_data_available(c_valid11),
    .validity_mask_a_rows(4'b1111), // Tie validity_mask* values to default values
    .validity_mask_a_cols_b_rows(4'b1111),
    .validity_mask_b_cols(4'b1111),
    .final_mat_mul_size('d8),
    .a_loc('d1),
    .b_loc('d1)
);

assign done_mat_mul = done00 & done01 & done10 & done11;
assign c_data_available = c_valid01 | c_valid11;

endmodule