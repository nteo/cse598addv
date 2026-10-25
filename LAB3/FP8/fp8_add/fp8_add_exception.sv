//////////////////////////////////////////////////////////////////////////////////
//
// Create Date:    10/23/2026
// Module Name:    fp8_add_exception
//
// Description:	 Check the final result for exception conditions and set
//						 flags accordingly.
//
//////////////////////////////////////////////////////////////////////////////////

module fp8_add_exception(
		input logic [4:0] InputExc,
		input logic EOF,
        input logic Underflow,
        input logic DiscardedAlign,
        input logic DiscardedNormalize,

		output logic [4:0] Flags
    );
	
	// Internal signals
	logic Overflow ;				// Overflow flag
	logic DivideByZero ;			// Divide-by-Zero flag (always 0 in Add/Sub)
	logic Invalid ;				    // Invalid inputs or result
	logic Inexact ;					// Result is inexact because of rounding
	
	// Exception flags
	
	// Result is too big to be represented
	assign Overflow = EOF | InputExc[1] | InputExc[0] ;
	
	// Infinite result computed exactly from finite operands
	assign DivideByZero = 0;
	
	// Invalid inputs or operation
	assign Invalid = |(InputExc[4:2]);
	
	// Inexact answer due to rounding, overflow or underflow
	assign Inexact = (DiscardedAlign | DiscardedNormalize) | Overflow | Underflow;
	
	// Collect exception flags	
	assign Flags = {Overflow, Underflow, DivideByZero, Invalid, Inexact};
	
endmodule