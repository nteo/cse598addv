/* 8x8 Systolic Matrix Multiplier Design
 *
 * Consists of 4 matmul_4x4_systolic blocks from matmul.v and interconnect.
*/

module matmul_8x8 #(
    parameter MAT_MUL_SIZE = 4
)(
    input logic clk,
    input rst,
    //...

);

//////////////////////////////////////////////////////////////////////////
// Instantiation of 4 matmul_4x4_systolic blocks
//////////////////////////////////////////////////////////////////////////

matmul_4x4_systolic matmul_4x4_systolic_00(
    // Connect ports
);

matmul_4x4_systolic matmul_4x4_systolic_01(
    // Connect ports
);

matmul_4x4_systolic matmul_4x4_systolic_10(
    // Connect ports
);

matmul_4x4_systolic matmul_4x4_systolic_11(
    // Connect ports
);

endmodule