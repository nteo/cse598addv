//////////////////////////////////////////////////////////////////////////////////
//
// Create Date:    10/23/2026
// Module Name:    fp8_mul_execute
//
//////////////////////////////////////////////////////////////////////////////////

module fp8_mul_execute(
		input logic [9:0] Mp,
		input logic [2:0] ExpA,
		input logic [2:0] ExpB,
		input logic Sa,
		input logic Sb,
		
        output logic Sp,
		output logic signed [4:0] NormE,
		output logic [3:0] NormM,
		output logic DiscardedExecute
    );
	
	assign Sp = (Sa ^ Sb);  // Equal signs give A positive product
	
    // The mantissa product of A and B must lie between 1 and 4 (exclusive)
    // if the product is < 2, then the MSB is in the right spot and no shift is required
    // otherwise if the product is >= 2, the MSB is 1 bit to the left and needs right shift
	assign NormM = (Mp[9] ? Mp[8:5] : Mp[7:4]);

    // If there is overflow and the MSB needs a right shift, increment the exponent
    // this involves adding the two exponents, subtracting the bias (3), and incrementing if there is OF
    assign NormE = $signed({2'b00, ExpA})
                + $signed({2'b00, ExpB})
                - 5'sd3
                + $signed({4'b0000, Mp[9]});

	assign DiscardedExecute = Mp[9] ? (|Mp[4:0]) : (|Mp[3:0]);
	
endmodule