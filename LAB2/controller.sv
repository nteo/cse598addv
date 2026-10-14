//////////////////////////////////////////////////////////////////////
// ===================================================================
// This file has the following module implementations:
// 1. controller
// 2. maindec
// 3. aludec
// ===================================================================
//////////////////////////////////////////////////////////////////////


//////////////////////////////////////////////////////////////////////
// Controller module
//////////////////////////////////////////////////////////////////////
module controller (
    input [5:0] op, funct,
    input zero,
    output [1:0] resultsrc,
    output memwrite,
    output alusrc,
    output regdst, regwrite,
    output jump,
    output branch,
    output [2:0] alucontrol
);

    logic [1:0] aluop;
    
    maindec md(
        .op(op),                // Input
        .resultsrc(resultsrc),    // Output
        .memwrite(memwrite),    // Output
        .branch(branch),        // Output
        .alusrc(alusrc),        // Output
        .regdst(regdst),        // Output
        .regwrite(regwrite),    // Output
        .jump(jump),            // Output
        .aluop(aluop)           // Output
    );

    aludec ad(
        .funct(funct),          // Input
        .aluop(aluop),          // Input
        .alucontrol(alucontrol) // Output
    );
    
endmodule


//////////////////////////////////////////////////////////////////////
// Main Decoder module
//////////////////////////////////////////////////////////////////////
module maindec(
    input [5:0] op,
    output [1:0] resultsrc,
    output memwrite,
    output branch, alusrc,
    output regdst, regwrite,
    output jump,
    output [1:0] aluop
);

    logic [9:0] controls;
    
    assign {regwrite, regdst, alusrc, branch, memwrite, resultsrc, jump, aluop} = controls;

    always_comb
        case(op)
            6'b000000: controls = 10'b1100000010; // Rtype
            6'b100011: controls = 10'b1010001000; // LW
            6'b101011: controls = 10'b0010100000; // SW
            6'b000100: controls = 10'b0001000001; // BEQ
            6'b001000: controls = 10'b1010000000; // ADDI
            6'b000010: controls = 10'b0000000100; // J
            6'b000011: controls = 10'b1000010000; // PERFMON
            default: controls   = 10'bxxxxxxxxxx; // ???
        endcase

endmodule


//////////////////////////////////////////////////////////////////////
// ALU Decoder module
//////////////////////////////////////////////////////////////////////
module aludec (
    input [5:0] funct,
    input [1:0] aluop,
    output logic [2:0] alucontrol
);

    always_comb
        case (aluop)
            2'b00: alucontrol = 3'b010; // add
            2'b01: alucontrol = 3'b110; // sub

            2'b10: begin
                case(funct) // RTYPE
                    6'b100000: alucontrol = 3'b010; // ADD
                    6'b100010: alucontrol = 3'b110; // SUB
                    6'b100100: alucontrol = 3'b000; // AND
                    6'b100101: alucontrol = 3'b001; // OR
                    6'b101010: alucontrol = 3'b111; // SLT
                    6'b101100: alucontrol = 3'b100; // MULADD
                    default:   alucontrol = 3'bxxx; // ???
                endcase
            end

            default: alucontrol = 3'b010;
        endcase

endmodule