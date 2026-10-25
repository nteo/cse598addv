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
            if (InputExc[3] || InputExc[2]) begin
                // NaN input: return a quiet NaN
                Z = 8'h78;
            end
            else if (InputExc[1] || InputExc[0]) begin
                // Infinity input: return infinity with product sign
                Z = {Sp, 3'b111, 4'b0000};
            end
            else begin
                Z = 8'h00;
            end
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
