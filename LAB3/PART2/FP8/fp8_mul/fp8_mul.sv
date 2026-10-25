//////////////////////////////////////////////////////////////////////////////////
//
// Create Date:    10/23/2026
// Module Name:    FPMult
//
//////////////////////////////////////////////////////////////////////////////////

module fp8_mul(
		input logic clk,    // Clock
		input logic rst,    // Reset signal
		input logic [7:0] A,   // Input A (32 FP)
		input logic [7:0] B,   // Input B (32 FP)
		
        output logic [7:0] result, // Product of A and B
		output logic [4:0] flags    // Exception flags according to IEEE754
    );
	
	// Internal signals
	logic Sa;						// A's sign
	logic Sb;						// B's sign
	logic Sp;						// Product sign
	logic [2:0] ExpA;				// A's exponent
	logic [2:0] ExpB;				// B's exponent
	logic [9:0] Mp;				    // Product mantissa
	logic [4:0] InputExc;			// Exceptions in inputs
	logic [3:0] NormM;				// Normalized mantissa
	logic signed [4:0] NormE; 		// Normalized exponent
    logic DiscardedExecute;
	
	// Prepare the operands for alignment and check for exceptions
	fp8_mul_prep fp8_mul_prep(
        // Inputs
        .clk(clk), 
        .rst(rst), 
        .A(A), 
        .B(B), 
        
        // Outputs
        .Sa(Sa), 
        .Sb(Sb), 
        .ExpA(ExpA), 
        .ExpB(ExpB), 
        .Mp(Mp), 
        .InputExc(InputExc)
    );
	
	// Perform (unsigned) mantissa multiplication
	fp8_mul_execute fp8_mul_execute(
        // Inputs
        .Mp(Mp),
        .ExpA(ExpA),
        .ExpB(ExpB),
        .Sa(Sa),
        .Sb(Sb),

        // Outputs
        .Sp(Sp),
        .NormE(NormE),
        .NormM(NormM),
        .DiscardedExecute(DiscardedExecute)
    );

	// Round result and set exception flags
	fp8_mul_round fp8_mul_round(
        // Inputs
        .Sp(Sp),
        .NormE(NormE),
        .NormM(NormM),
        .DiscardedExecute(DiscardedExecute),
        .InputExc(InputExc),

        // Outputs
        .Z(result),
        .Flags(flags)
    );
		
endmodule