//////////////////////////////////////////////////////////////////////////////////
//
// Create Date:    10/23/2026
// Module Name:    fp8_mul_round
//
//////////////////////////////////////////////////////////////////////////////////

module fp8_mul_round(
    input logic Sp,
    input logic signed [4:0] NormE,
    input logic [3:0] NormM,
    input logic       DiscardedExecute,
    input logic [4:0] InputExc,

    output logic [7:0] Z,
    output logic [4:0] Flags
);

    logic Overflow;
    logic Underflow;
	logic DivideByZero;
	logic Invalid;
    logic Inexact;

    always_comb begin
        Z = 8'h00;

        Overflow  = (NormE > 5'sd6);
        Underflow = (NormE < 5'sd1);
		Invalid = |(InputExc[4:2]);
		DivideByZero = 1'b0;
        Inexact = Overflow | Underflow | DiscardedExecute;

        if (InputExc[4]) begin
            // Special input handling must be defined by your
            // InputExc encoding and FP8 special-value policy.
            Z = 8'h00;
        end
        else if (Overflow) begin
            // Saturate to maximum finite value
            Z = {Sp, 3'b110, 4'b1111};
        end
        else if (Underflow) begin
            // Flush to signed zero
            Z = {Sp, 7'b0};
        end
        else begin
            // RTZ: keep the truncated mantissa; never increment it
            Z = {Sp, NormE[2:0], NormM};
        end

        Flags = {Overflow, Underflow, DivideByZero, Invalid, Inexact};
    end

endmodule
