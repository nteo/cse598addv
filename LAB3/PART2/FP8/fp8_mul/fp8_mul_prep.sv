//////////////////////////////////////////////////////////////////////////////////
//
// Create Date:    10/23/2026
// Module Name:    fp8_mul_prep
//
// Description:	 The pre-alignment module is responsible for taking the inputs
//							apart, checking the parts for exceptions and feeding them to
//							the alignment module.
//
//////////////////////////////////////////////////////////////////////////////////

 module fp8_mul_prep(
		input logic clk,
		input logic rst,
		input logic [7:0] A,
		input logic [7:0] B,

		output logic Sa,
		output logic Sb,
		output logic [2:0] ExpA,
		output logic [2:0] ExpB,
		output logic [9:0] Mp, // Mantissa product
		output logic [4:0] InputExc // Exception flags for inputs
	);
	
	// Internal signals
	logic ANaN;			// A is A NaN
	logic BNaN;			// B is A NaN
	logic AInf;			// A is infinity
	logic BInf;			// B is infinity
	logic [4:0] Ma;     // Mantissa of A
    logic [4:0] Mb;     // Mantissa of B
	
	assign ANaN = &(A[6:4]) & |(A[3:0]);		// All one exponent and not all zero mantissa - NaN
	assign BNaN = &(B[6:4]) & |(B[3:0]);		// All one exponent and not all zero mantissa - NaN
	assign AInf = &(A[6:4]) & ~|(A[3:0]);		// All one exponent and all zero mantissa - Infinity
	assign BInf = &(B[6:4]) & ~|(B[3:0]);		// All one exponent and all zero mantissa - Infinity
	
	// Check for any exceptions and put all flags into exception vector
	assign InputExc = {(ANaN | BNaN | AInf | BInf), ANaN, BNaN, AInf, BInf} ;
	
	// Take input numbers apart
	assign Sa = A[7] ;		// A's sign
	assign Sb = B[7] ;		// B's sign
	assign ExpA = A[6:4];	// Store A's exponent in ExpA, unless A is an exception
	assign ExpB = B[6:4];	// Store B's exponent in ExpB, unless B is an exception
    assign Ma = (ExpA == 3'b000 || ExpA == 3'b111) ? 5'b0 : {1'b1, A[3:0]};   // Mantissa A + sign bit
    assign Mb = (ExpB == 3'b000 || ExpB == 3'b111) ? 5'b0 : {1'b1, B[3:0]};   // Mantissa B + sign bit
	
	assign Mp = Ma * Mb;

endmodule