
module fp8_add_normalize(
    input  logic [5:0] Sum,
    input  logic [2:0] CExp,
    output logic [5:0] SumNormal,
    output logic [2:0] CExpNormal,
    output logic       Overflow,
    output logic       Underflow,
    output logic       DiscardedNormalize
);

    logic signed [3:0] ExpCalc;

    // Normalize the significand and adjust the exponent
    always_comb begin
        SumNormal = 6'd0;
        ExpCalc   = $signed({1'b0, CExp});
        DiscardedNormalize = 1'b0;

        if (Sum[5]) begin
            DiscardedNormalize = Sum[0];
            SumNormal = Sum >> 1;
            ExpCalc   = $signed({1'b0, CExp}) + 4'sd1;
        end
        else if (Sum[4]) begin
            SumNormal = Sum;
        end
        else if (Sum[3]) begin
            SumNormal = Sum << 1;
            ExpCalc   = $signed({1'b0, CExp}) - 4'sd1;
        end
        else if (Sum[2]) begin
            SumNormal = Sum << 2;
            ExpCalc   = $signed({1'b0, CExp}) - 4'sd2;
        end
        else if (Sum[1]) begin
            SumNormal = Sum << 3;
            ExpCalc   = $signed({1'b0, CExp}) - 4'sd3;
        end
        else if (Sum[0]) begin
            SumNormal = Sum << 4;
            ExpCalc   = $signed({1'b0, CExp}) - 4'sd4;
        end
    end

    // Detect exponent overflow and underflow
    assign Overflow  = (Sum != 6'd0) && (ExpCalc > 4'sd6);
    assign Underflow = (Sum != 6'd0) && (ExpCalc < 4'sd1);

    // Clamp the exponent to a valid normal range
    always_comb begin
        if (Sum == 6'd0 || Underflow)
            CExpNormal = 3'd0;
        else if (Overflow)
            CExpNormal = 3'd6;
        else
            CExpNormal = ExpCalc[2:0];
    end

endmodule
