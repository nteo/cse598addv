module fp8_add(
    input logic [7:0] A,
    input logic [7:0] B,

    output logic [7:0] Result,
    output logic [4:0] Flags
);

    logic Sa;           // Sign of A
    logic Sb;           // Sign of B
    logic [5:0] ShiftDet;   // Raw shift data
    logic [4:0] InputExc;   // Input exception flags to indicate NaN or Inf
    logic [6:0] Aout;   // A - sign bit
    logic [6:0] Bout;   // B - sign bit

    logic [2:0] CExp;   // The larger of the two exponents (common exponent)
    logic MaxAB;        // Indicate the larger operand (0: A, 1: B)
    logic [2:0] Shift;  // The shift amount
    logic [4:0] Mmin;   // The mantissa of the smaller operand + implicit bit
    logic [4:0] Mmax;   // The mantissa of the larger operand + implicit bit

    logic [4:0] MminShift;  // The shifted mantissa of the smaller operand

    logic [5:0] Sum;    // The sum of the mantissas + extra bit for carry out
    logic Ssum;         // The sign of the sum

    logic [5:0] SumNormal;  // The normalized sum
    logic [2:0] CExpNormal;  // The normalized exponent
    logic Overflow;
    logic Underflow;

    logic DiscardedAlign;   // Indicate if any bits were truncated during align
    logic DiscardedNormalize;   // Indicate if any bits were trunctated during normalize
    logic EOF; // Overflow flag
    logic [7:0] Z;   // Result (before checking for A|B == 0)


    // Prepare operands for alignment; check inputs for exceptions (NaN, inf)
    fp8_add_prealign fp8_add_prealign(
        // Inputs
        .A(A),
        .B(B),

        // Outputs
        .Sa(Sa),
        .Sb(Sb),
        .ShiftDet(ShiftDet),
        .InputExc(InputExc),
        .Aout(Aout),
        .Bout(Bout)
    );

    // Align operands: extract shift amount and common exponent
    fp8_add_align fp8_add_align(
        // Inputs
        .Aout(Aout),
        .Bout(Bout),
        .ShiftDet(ShiftDet),

        // Outputs
        .CExp(CExp),
        .MaxAB(MaxAB),
        .Shift(Shift),
        .Mmin(Mmin),
        .Mmax(Mmax)
    );

    // Shift mantissa of smaller operand by shift amount
    fp8_add_shift fp8_add_shift(
        // Inputs
        .Mmin(Mmin),
        .Shift(Shift),

        // Outputs
        .MminShift(MminShift),
        .DiscardedAlign(DiscardedAlign)
    );

    // Add mantissa-s together
    fp8_add_execute fp8_add_execute(
        // Inputs
        .Mmax(Mmax),
        .Mmin(MminShift),
        .Sa(Sa),
        .Sb(Sb),
        .MaxAB(MaxAB),

        // Outputs
        .Sum(Sum),
        .Ssum(Ssum)
    );

    // Normalize the sum and exponent
    fp8_add_normalize fp8_add_normalize(
        // Inputs
        .Sum(Sum),
        .CExp(CExp),

        // Outputs
        .SumNormal(SumNormal),
        .CExpNormal(CExpNormal),
        .Overflow(Overflow),
        .Underflow(Underflow),
        .DiscardedNormalize(DiscardedNormalize)
    );

    // Round-to-zero (RTZ): if sum > 0, round down. otherwise, round up
    fp8_add_round fp8_add_round(
        // Inputs
        .NormE(CExpNormal),
        .NormM(SumNormal),
        .Ssum(Ssum),
        .Overflow(Overflow),
        .Underflow(Underflow),

        // Outputs
        .Z(Z),
        .EOF(EOF)
    );

    // Check for exceptions
    fp8_add_exception fp8_add_exception(
        // Inputs
        .InputExc(InputExc),
        .EOF(EOF),
        .Underflow(Underflow),
        .DiscardedAlign(DiscardedAlign),
        .DiscardedNormalize(DiscardedNormalize),

        // Outputs
        .Flags(Flags)
    );

    // If A is 0, the result is just B
    // if B is 0, the result is just A
    // if neither, then use the computed result Z
    assign Result = Aout == 7'd0 ? B : 
                    Bout == 7'd0 ? A : Z;

endmodule