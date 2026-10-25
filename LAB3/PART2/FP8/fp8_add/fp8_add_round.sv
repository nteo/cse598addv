module fp8_add_round(
    input  logic [2:0] NormE,
    input  logic [5:0] NormM,
    input  logic       Ssum,
    input  logic       Overflow,
    input  logic       Underflow,
    output logic [7:0] Z,
    output logic       EOF
);
    logic ZeroSum;
    logic [3:0] RoundM;

    assign ZeroSum = (NormM == 6'd0);

    // RTZ: retain the four fraction bits
    assign RoundM = NormM[3:0];

    always_comb begin
        if (ZeroSum)
            Z = 8'b0;
        else if (Underflow)
            Z = {Ssum, 7'b0};
        else if (Overflow)
            Z = {Ssum, 3'b110, 4'b1111};
        else
            Z = {Ssum, NormE, RoundM};
    end

    assign EOF = Overflow;

endmodule