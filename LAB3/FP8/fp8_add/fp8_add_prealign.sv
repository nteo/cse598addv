//////////////////////////////////////////////////////////////////////////////////
//
// Create Date:    	10/21/2026
// Module Name:    	fp8_add_prealign
//
// Description:	 	The pre-alignment module is responsible for taking the inputs
//							apart and checking the parts for exceptions.
//							The exponent difference is also calculated in this module.
//
//////////////////////////////////////////////////////////////////////////////////

module fp8_add_prealign(
	input logic [7:0] A,
	input logic [7:0] B,

	output logic Sa,    // sign bit of A
	output logic Sb,    // sign bit of B
	output logic [5:0] ShiftDet,  // shift data (size: 2x exponent bits)
	output logic [4:0] InputExc,  // exception flag for inputs
	output logic [6:0] Aout,   // A - sign bit
	output logic [6:0] Bout    // B - sign bit
);
	
	// Internal signals									// If signal is high...
	logic ANaN ;									    // A is NaN (Not-a-Number)
	logic BNaN ;							    		// B is NaN
	logic AInf ;										// A is infinity
	logic BInf ;										// B is infinity
	logic [2:0] DAB ;							        // ExpA - ExpB					
	logic [2:0] DBA ;							        // ExpB - ExpA	
	
	assign ANaN = &(A[6:4]) & |(A[3:0]);    // A: All one exponent and not all zero mantissa - NaN
	assign BNaN = &(B[6:4]) & |(B[3:0]);    // B: All one exponent and not all zero mantissa - NaN
	assign AInf = &(A[6:4]) & ~|(A[3:0]);	// A: All one exponent and all zero mantissa - Infinity
	assign BInf = &(B[6:4]) & ~|(B[3:0]);	// B: All one exponent and all zero mantissa - Infinity
	
	// Put all flags into exception vector
	assign InputExc = {(ANaN | BNaN | AInf | BInf), ANaN, BNaN, AInf, BInf} ;
	
    // Subtract exponents
	assign DAB = A[6:4] - B[6:4];
	assign DBA = B[6:4] - A[6:4];
	
	assign Sa = A[7];   // A's sign bit
	assign Sb = B[7];   // B's sign	bit
	assign ShiftDet = {DBA, DAB};  // Shift data (decoded in align and shift units)
	assign Aout = A[6:0];
	assign Bout = B[6:0];
	
endmodule