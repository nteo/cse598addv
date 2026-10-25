//////////////////////////////////////////////////////////////////////////////////
//
// Create Date:    	10/21/2026
// Module Name:    	fp8_add_align
//
// Description:	 	The alignment module determines the larger input operand and
//							sets the mantissas, shift and common exponent accordingly.
//
//////////////////////////////////////////////////////////////////////////////////

module fp8_add_align (
		input logic [6:0] Aout,     // A - sign bit
		input logic [6:0] Bout,     // B - sign bit
		input logic [5:0] ShiftDet, // {B-A, A-B}

		output logic [2:0] CExp,    // common exponent (larger of the A and B's exponents)
		output logic MaxAB,         // indicates larger of A and B (0: A, 1: B)
		output logic [2:0] Shift,   // number of steps to smaller mantissa shift right
		output logic [4:0] Mmin,    // smaller mantissa
		output logic [4:0] Mmax     // larger mantissa
	);
	
	// Select the larger of A and B (0: A, 1: B)
	assign MaxAB = (Aout < Bout);	
	
	// Determine final shift value: the absolute difference between A and B
	assign Shift = MaxAB ? ShiftDet[5:3] : ShiftDet[2:0];
	
	// Select the mantissa of the smaller value
	assign Mmin = {1'b1, MaxAB ? Aout[3:0] : Bout[3:0]}; 
	
	// Select the mantissa of the larger value
	// prepend the implicit 1 bit in front of it.
	// we do this for the smaller value in the shift module
	assign Mmax = {1'b1, MaxAB ? Bout[3:0]: Aout[3:0]};	
	
	// Common exponent: the larger exponent between A and B
	assign CExp = (MaxAB ? Bout[6:4] : Aout[6:4]);		
	
endmodule