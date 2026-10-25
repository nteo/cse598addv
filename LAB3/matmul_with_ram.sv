// Design with memories
module matrix_multiplication #(
    parameter int DWIDTH = 8,
    parameter int AWIDTH = 10,
    parameter int MAT_MUL_SIZE = 4,
    parameter int MASK_WIDTH = MAT_MUL_SIZE,
    parameter int ADDR_STRIDE_WIDTH = 8
) (
    input logic clk,
    input logic resetn,
    input logic pe_resetn,
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
    input logic [MASK_WIDTH-1:0] bram_we_c_bottom_ext,
    input logic [`APB_ADDRWIDTH-1:0] PADDR,
    input logic PWRITE,
    input logic PSEL,
    input logic PENABLE,
    input logic [`APB_DATAWIDTH-1:0] PWDATA,
    output logic [`APB_DATAWIDTH-1:0] PRDATA,
    output logic PREADY
);

    localparam int DATA_WIDTH = MAT_MUL_SIZE * DWIDTH;

    logic [3:0] state;
    logic [3:0] output_count;
    logic [AWIDTH-1:0] c_write_addr_top;
    logic [AWIDTH-1:0] c_write_addr_bottom;
    logic start_mat_mul;
    logic reset;
    logic pe_reset;
    logic done_mat_mul;
    logic c_data_available;

    logic start, done, pe_clear, exception_flag;
    logic [AWIDTH-1:0] address_mat_a_top, address_mat_a_bottom;
    logic [AWIDTH-1:0] address_mat_b_left, address_mat_b_right;
    logic [AWIDTH-1:0] address_mat_c_top, address_mat_c_bottom;
    logic [ADDR_STRIDE_WIDTH-1:0] address_stride_a_top, address_stride_a_bottom;
    logic [ADDR_STRIDE_WIDTH-1:0] address_stride_b_left, address_stride_b_right;
    logic [ADDR_STRIDE_WIDTH-1:0] address_stride_c_top, address_stride_c_bottom;

    assign exception_flag = 1'b0; // connect to the OR of the FP8 flags from u_matmul_8x8

    logic [AWIDTH-1:0] a_addr_top, a_addr_bottom;
    logic [AWIDTH-1:0] b_addr_left, b_addr_right;
    logic [AWIDTH-1:0] c_addr_top, c_addr_bottom;
    logic [DATA_WIDTH-1:0] a_data_top, a_data_bottom;
    logic [DATA_WIDTH-1:0] b_data_left, b_data_right;
    logic [DATA_WIDTH-1:0] c_data_out_top, c_data_out_bottom;

    assign reset = ~resetn;
    assign pe_reset = ~pe_resetn | pe_clear;

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
    //Connections for bram c (output matrix)
    //bram_addr_c_top and bram_addr_c_bottom -> connected to u_matmul_8x8
    //bram_rdata_c_top and bram_rdata_c_bottom -> not used
    //bram_wdata_c_top and bram_wdata_c_bottom -> connected to u_matmul_8x8
    //bram_we_c_top and bram_we_c_bottom -> set to 1 when c_data is available

    //Connections for bram a (first input matrix)
    //bram_addr_a_top and bram_addr_a_bottom -> connected to u_matmul_8x8
    //bram_rdata_a_top and bram_rdata_a_bottom -> connected to u_matmul_8x8
    //bram_wdata_a_top and bram_wdata_a_bottom -> hardcoded to 0 (this block only reads from bram a)
    //bram_we_a_top and bram_we_a_bottom -> hardcoded to 0 (this block only reads from bram a)

    //Connections for bram b (second input matrix)
    //bram_addr_b_left and bram_addr_b_right -> connected to u_matmul_8x8
    //bram_rdata_b_left and bram_rdata_b_right -> connected to u_matmul_8x8
    //bram_wdata_b_left and bram_wdata_b_right -> hardcoded to 0 (this block only reads from bram b)
    //bram_we_b_left and bram_we_b_right -> hardcoded to 0 (this block only reads from bram b)

    //fsm to start matmul
    always_ff @(posedge clk) begin
        if (!resetn) begin
            state <= 4'b0000;
            start_mat_mul <= 1'b0;
            output_count <= '0;
            c_write_addr_top <= '0;
            c_write_addr_bottom <= '0;
            done <= 1'b0;
        end else begin
            done <= 1'b0;
            case (state)
                4'b0000: begin
                    start_mat_mul <= 1'b0;
                    state <= start ? 4'b0001 : 4'b0000;
                end
                4'b0001: begin
                    start_mat_mul <= 1'b1;
                    state <= 4'b0010;
                    output_count <= '0;
                    c_write_addr_top <= address_mat_c_top;
                    c_write_addr_bottom <= address_mat_c_bottom;
                end
                4'b0010: begin
                    // The internal core done pulse precedes output capture.
                    // Keep start asserted until c_data_available is observed.
                    start_mat_mul <= 1'b1;
                    if (c_data_available) begin
                        state <= 4'b0011;
                        c_write_addr_top <= c_write_addr_top + address_stride_c_top;
                        c_write_addr_bottom <= c_write_addr_bottom + address_stride_c_bottom;
                    end
                end
                4'b0011: begin
                    start_mat_mul <= 1'b1;
                    if (output_count == (2 * MAT_MUL_SIZE) - 1) begin
                        // The current cycle writes the final output word.
                        // Deassert start for the following cycle so the output
                        // logic clears without producing an extra write.
                        start_mat_mul <= 1'b0;
                        state <= 4'b0100;
                    end else begin
                        output_count <= output_count + 1'b1;
                    end

                    c_write_addr_top <= c_write_addr_top + address_stride_c_top;
                    c_write_addr_bottom <= c_write_addr_bottom + address_stride_c_bottom;

                end
                4'b0100: begin
                    start_mat_mul <= 1'b0;
                    done <= 1'b1;
                    state <= 4'b0000;
                end
                default: begin
                    state <= 4'b0000;
                    start_mat_mul <= 1'b0;
                    output_count <= '0;
                end
            endcase
        end
    end

    //We will utilize port 0 (addr0, d0, we0, q0) to interface with the matmul.
    //Unused ports (port 1 signals addr1, d1, we1, q1) will be connected to the "external" signals i.e. signals that exposed to the external world.
    //Signals that are external end in "_ext".
    //addr is the address of the BRAM, d is the data to be written to the BRAM, we is write enable, and q is the data read from the BRAM.
    ////////////////////////////////////////////////////////////////
    // RAM matrix A
    ////////////////////////////////////////////////////////////////
    ram #(.DWIDTH(DWIDTH), .AWIDTH(AWIDTH), .MASK_WIDTH(MASK_WIDTH)) matrix_a_top (
        .addr0(a_addr_top), .d0('0), .we0('0), .q0(a_data_top),
        .addr1(bram_addr_a_top_ext), .d1(bram_wdata_a_top_ext),
        .we1(bram_we_a_top_ext), .q1(bram_rdata_a_top_ext), .clk(clk)
    );
    ram #(.DWIDTH(DWIDTH), .AWIDTH(AWIDTH), .MASK_WIDTH(MASK_WIDTH)) matrix_a_bottom (
        .addr0(a_addr_bottom), .d0('0), .we0('0), .q0(a_data_bottom),
        .addr1(bram_addr_a_bottom_ext), .d1(bram_wdata_a_bottom_ext),
        .we1(bram_we_a_bottom_ext), .q1(bram_rdata_a_bottom_ext), .clk(clk)
    );

    ////////////////////////////////////////////////////////////////
    // RAM matrix B
    ////////////////////////////////////////////////////////////////
    ram #(.DWIDTH(DWIDTH), .AWIDTH(AWIDTH), .MASK_WIDTH(MASK_WIDTH)) matrix_b_left (
        .addr0(b_addr_left), .d0('0), .we0('0), .q0(b_data_left),
        .addr1(bram_addr_b_left_ext), .d1(bram_wdata_b_left_ext),
        .we1(bram_we_b_left_ext), .q1(bram_rdata_b_left_ext), .clk(clk)
    );
    ram #(.DWIDTH(DWIDTH), .AWIDTH(AWIDTH), .MASK_WIDTH(MASK_WIDTH)) matrix_b_right (
        .addr0(b_addr_right), .d0('0), .we0('0), .q0(b_data_right),
        .addr1(bram_addr_b_right_ext), .d1(bram_wdata_b_right_ext),
        .we1(bram_we_b_right_ext), .q1(bram_rdata_b_right_ext), .clk(clk)
    );

    ////////////////////////////////////////////////////////////////
    // RAM matrix C
    ////////////////////////////////////////////////////////////////
    ram #(.DWIDTH(DWIDTH), .AWIDTH(AWIDTH), .MASK_WIDTH(MASK_WIDTH)) matrix_c_top (
        .addr0(c_write_addr_top), .d0(c_data_out_top),
        .we0(c_data_available ? {MASK_WIDTH{1'b1}} : '0), .q0(),
        .addr1(bram_addr_c_top_ext), .d1(bram_wdata_c_top_ext),
        .we1(bram_we_c_top_ext), .q1(bram_rdata_c_top_ext), .clk(clk)
    );
    ram #(.DWIDTH(DWIDTH), .AWIDTH(AWIDTH), .MASK_WIDTH(MASK_WIDTH)) matrix_c_bottom (
        .addr0(c_write_addr_bottom), .d0(c_data_out_bottom),
        .we0(c_data_available ? {MASK_WIDTH{1'b1}} : '0), .q0(),
        .addr1(bram_addr_c_bottom_ext), .d1(bram_wdata_c_bottom_ext),
        .we1(bram_we_c_bottom_ext), .q1(bram_rdata_c_bottom_ext), .clk(clk)
    );

    //matmul instance
    matmul_8x8 #(
        .DWIDTH(DWIDTH), .AWIDTH(AWIDTH), .MAT_MUL_SIZE(MAT_MUL_SIZE),
        .ADDR_STRIDE_WIDTH(ADDR_STRIDE_WIDTH)
    ) u_matmul_8x8 (
        .clk(clk), .reset(reset), .pe_reset(pe_reset),
        .start_mat_mul(start_mat_mul),
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
        .a_data_top(a_data_top), .a_data_bottom(a_data_bottom),
        .b_data_left(b_data_left), .b_data_right(b_data_right),
        .c_data_out_top(c_data_out_top),
        .c_data_out_bottom(c_data_out_bottom),
        .a_addr_top(a_addr_top), .a_addr_bottom(a_addr_bottom),
        .b_addr_left(b_addr_left), .b_addr_right(b_addr_right),
        .c_addr_top(c_addr_top), .c_addr_bottom(c_addr_bottom),
        .done_mat_mul(done_mat_mul), .c_data_available(c_data_available)
    );

endmodule

module ram #(
    parameter int DWIDTH = 8,
    parameter int AWIDTH = 10,
    parameter int MASK_WIDTH = 4
) (
    input logic [AWIDTH-1:0] addr0,
    input logic [MASK_WIDTH*DWIDTH-1:0] d0,
    input logic [MASK_WIDTH-1:0] we0,
    output logic [MASK_WIDTH*DWIDTH-1:0] q0,
    input logic [AWIDTH-1:0] addr1,
    input logic [MASK_WIDTH*DWIDTH-1:0] d1,
    input logic [MASK_WIDTH-1:0] we1,
    output logic [MASK_WIDTH*DWIDTH-1:0] q1,
    input logic clk
);

    localparam int DATA_WIDTH = MASK_WIDTH * DWIDTH;
    localparam int DEPTH = 1 << AWIDTH;
    logic [DATA_WIDTH-1:0] memory [0:DEPTH-1];

    always @(posedge clk) begin
        if (|we0)
            memory[addr0] <= d0;
        q0 <= memory[addr0];
    end

    always @(posedge clk) begin
        if (|we1)
            memory[addr1] <= d1;
        q1 <= memory[addr1];
    end

endmodule
