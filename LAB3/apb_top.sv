module apb_top #(
    parameter int DWIDTH = 8,
    parameter int AWIDTH = 10,
    parameter int MAT_MUL_SIZE = 4,
    parameter int MASK_WIDTH = MAT_MUL_SIZE,
    parameter int ADDR_STRIDE_WIDTH = 8
) (
    input logic clk,
    input logic resetn,
    input logic pe_resetn,
    input logic [`APB_ADDRWIDTH-1:0] PADDR,
    input logic PWRITE,
    input logic PSEL,
    input logic PENABLE,
    input logic [`APB_DATAWIDTH-1:0] PWDATA,
    output logic [`APB_DATAWIDTH-1:0] PRDATA,
    output logic PREADY,
    input logic [AWIDTH-1:0] bram_addr_a_top_ext,
    output logic [MAT_MUL_SIZE*DWIDTH-1:0] bram_rdata_a_top_ext,
    input logic [MAT_MUL_SIZE*DWIDTH-1:0] bram_wdata_a_top_ext,
    input logic [MASK_WIDTH-1:0] bram_we_a_top_ext,
    input logic [AWIDTH-1:0] bram_addr_a_bottom_ext,
    output logic [MAT_MUL_SIZE*DWIDTH-1:0] bram_rdata_a_bottom_ext,
    input logic [MAT_MUL_SIZE*DWIDTH-1:0] bram_wdata_a_bottom_ext,
    input logic [MASK_WIDTH-1:0] bram_we_a_bottom_ext,
    input logic [AWIDTH-1:0] bram_addr_b_left_ext,
    output logic [MAT_MUL_SIZE*DWIDTH-1:0] bram_rdata_b_left_ext,
    input logic [MAT_MUL_SIZE*DWIDTH-1:0] bram_wdata_b_left_ext,
    input logic [MASK_WIDTH-1:0] bram_we_b_left_ext,
    input logic [AWIDTH-1:0] bram_addr_b_right_ext,
    output logic [MAT_MUL_SIZE*DWIDTH-1:0] bram_rdata_b_right_ext,
    input logic [MAT_MUL_SIZE*DWIDTH-1:0] bram_wdata_b_right_ext,
    input logic [MASK_WIDTH-1:0] bram_we_b_right_ext,
    input logic [AWIDTH-1:0] bram_addr_c_top_ext,
    output logic [MAT_MUL_SIZE*DWIDTH-1:0] bram_rdata_c_top_ext,
    input logic [MAT_MUL_SIZE*DWIDTH-1:0] bram_wdata_c_top_ext,
    input logic [MASK_WIDTH-1:0] bram_we_c_top_ext,
    input logic [AWIDTH-1:0] bram_addr_c_bottom_ext,
    output logic [MAT_MUL_SIZE*DWIDTH-1:0] bram_rdata_c_bottom_ext,
    input logic [MAT_MUL_SIZE*DWIDTH-1:0] bram_wdata_c_bottom_ext,
    input logic [MASK_WIDTH-1:0] bram_we_c_bottom_ext
);

    logic start, done, pe_clear;
    logic [4:0] exception_flag;
    logic [AWIDTH-1:0] address_mat_a_top, address_mat_a_bottom;
    logic [AWIDTH-1:0] address_mat_b_left, address_mat_b_right;
    logic [AWIDTH-1:0] address_mat_c_top, address_mat_c_bottom;
    logic [ADDR_STRIDE_WIDTH-1:0] address_stride_a_top, address_stride_a_bottom;
    logic [ADDR_STRIDE_WIDTH-1:0] address_stride_b_left, address_stride_b_right;
    logic [ADDR_STRIDE_WIDTH-1:0] address_stride_c_top, address_stride_c_bottom;

    apb_slave #(.AW(AWIDTH), .SW(ADDR_STRIDE_WIDTH)) u_apb_slave (
        .PCLK(clk), .PRESETn(resetn),
        .PADDR(PADDR), .PWRITE(PWRITE), .PSEL(PSEL), .PENABLE(PENABLE),
        .PWDATA(PWDATA), .PRDATA(PRDATA), .PREADY(PREADY),
        .start(start), .pe_clear(pe_clear), .done(done), .flags(exception_flag),
        .address_mat_a_top(address_mat_a_top), .address_mat_a_bottom(address_mat_a_bottom),
        .address_mat_b_left(address_mat_b_left), .address_mat_b_right(address_mat_b_right),
        .address_mat_c_top(address_mat_c_top), .address_mat_c_bottom(address_mat_c_bottom),
        .address_stride_a_top(address_stride_a_top), .address_stride_a_bottom(address_stride_a_bottom),
        .address_stride_b_left(address_stride_b_left), .address_stride_b_right(address_stride_b_right),
        .address_stride_c_top(address_stride_c_top), .address_stride_c_bottom(address_stride_c_bottom)
    );

    matrix_multiplication #(
        .DWIDTH(DWIDTH), .AWIDTH(AWIDTH), .MAT_MUL_SIZE(MAT_MUL_SIZE),
        .MASK_WIDTH(MASK_WIDTH), .ADDR_STRIDE_WIDTH(ADDR_STRIDE_WIDTH)
    ) u_matmul (
        .clk(clk), .resetn(resetn), .pe_resetn(pe_resetn & ~pe_clear),
        .address_mat_a_top(address_mat_a_top), .address_mat_a_bottom(address_mat_a_bottom),
        .address_mat_b_left(address_mat_b_left), .address_mat_b_right(address_mat_b_right),
        .address_mat_c_top(address_mat_c_top), .address_mat_c_bottom(address_mat_c_bottom),
        .address_stride_a_top(address_stride_a_top), .address_stride_a_bottom(address_stride_a_bottom),
        .address_stride_b_left(address_stride_b_left), .address_stride_b_right(address_stride_b_right),
        .address_stride_c_top(address_stride_c_top), .address_stride_c_bottom(address_stride_c_bottom),
        .bram_addr_a_top_ext(bram_addr_a_top_ext), .bram_rdata_a_top_ext(bram_rdata_a_top_ext),
        .bram_wdata_a_top_ext(bram_wdata_a_top_ext), .bram_we_a_top_ext(bram_we_a_top_ext),
        .bram_addr_a_bottom_ext(bram_addr_a_bottom_ext), .bram_rdata_a_bottom_ext(bram_rdata_a_bottom_ext),
        .bram_wdata_a_bottom_ext(bram_wdata_a_bottom_ext), .bram_we_a_bottom_ext(bram_we_a_bottom_ext),
        .bram_addr_b_left_ext(bram_addr_b_left_ext), .bram_rdata_b_left_ext(bram_rdata_b_left_ext),
        .bram_wdata_b_left_ext(bram_wdata_b_left_ext), .bram_we_b_left_ext(bram_we_b_left_ext),
        .bram_addr_b_right_ext(bram_addr_b_right_ext), .bram_rdata_b_right_ext(bram_rdata_b_right_ext),
        .bram_wdata_b_right_ext(bram_wdata_b_right_ext), .bram_we_b_right_ext(bram_we_b_right_ext),
        .bram_addr_c_top_ext(bram_addr_c_top_ext), .bram_rdata_c_top_ext(bram_rdata_c_top_ext),
        .bram_wdata_c_top_ext(bram_wdata_c_top_ext), .bram_we_c_top_ext(bram_we_c_top_ext),
        .bram_addr_c_bottom_ext(bram_addr_c_bottom_ext), .bram_rdata_c_bottom_ext(bram_rdata_c_bottom_ext),
        .bram_wdata_c_bottom_ext(bram_wdata_c_bottom_ext), .bram_we_c_bottom_ext(bram_we_c_bottom_ext),
        .start(start), .done(done), .flags(exception_flag)
    );

endmodule