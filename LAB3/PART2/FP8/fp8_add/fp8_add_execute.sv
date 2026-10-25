//////////////////////////////////////////////////////////////////////////////////
//
// Create Date:    10/22/2026
// Module Name:    FPAddSub_ExecutionModule 
//
// Description:	 Module that executes the addition or subtraction on mantissas.
//
//////////////////////////////////////////////////////////////////////////////////

module fp8_add_execute(
		input logic [4:0] Mmax,
		input logic [4:0] Mmin,
		input logic Sa,
		input logic Sb,
		input logic MaxAB,  // Indicates larger number (0:A, 1:B)
		
        output logic [5:0] Sum,
		output logic Ssum  // The sign of the sum
    );

    logic Smax; // Sign of the larger number
    logic Smin; // Sign of the smaller number

	// Perform effective operation
    // Case:
    //  Both A and B's signs are the same: add both operands, keep sign
    //  A and B's signs differ: subtract smaller operand from larger
	assign Sum = (Sa ^ Sb) ? ({1'b0, Mmax} - {1'b0, Mmin}) : ({1'b0, Mmax} + {1'b0, Mmin});
	
	// Assign result sign to the sign of the max operand
    //  because if both signs match, then it doesn't matter
    //  and if both signs do not match, the sign of the max operand will remain
	assign Ssum = MaxAB ? Sb : Sa;

endmodule