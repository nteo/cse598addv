//////////////////////////////////////////////////////////////////////////////////
//
// Create Date:    10/22/2026
// Module Name:    fp8_add_align_shift1
//
// Description:	 Alignment shift
//
//////////////////////////////////////////////////////////////////////////////////

module fp8_add_shift(
		input logic [4:0] Mmin,    // Smaller mantissa
		input logic [2:0] Shift,    // Shift amount
		
        output logic [4:0] MminShift,     // Smaller mantissa after shift
		output logic DiscardedAlign
	);
	
	// Shift the mantissa of the smaller value to the right
	//  later, we will increment the exponent to reflect this
	logic [4:0] MminFull;

	assign MminFull  = {1'b1, Mmin};
	assign MminShift = MminFull >> Shift;

	// Track any discarded bits
	always_comb begin
		DiscardedAlign = 1'b0;

		for (int i = 0; i < 5; i++) begin
			if (i < Shift)
				DiscardedAlign |= MminFull[i];
		end
	end
	
endmodule