//////////////////////////////////////////////////////////////////////
// ===================================================================
// This file has the following module implementations:
// 1. datapath
// 2. regfile
// 3. alu
// 4. adder
// 5. mux2
// 6. sl2
// 7. signext
// 8. flopr
// ===================================================================
//////////////////////////////////////////////////////////////////////


//////////////////////////////////////////////////////////////////////
// Datapath module
//////////////////////////////////////////////////////////////////////
module datapath (
    input clk, reset,
    input [31:0] readdata,
    input [31:0] instr,
    input regwrite,
    input memtoreg,
    input memwrite, 
    input [2:0] alucontrol,
    input alusrc, 
    input regdst,
    input branch,
    input jump,
    output [31:0] instrD,
    output zero,
    output [31:0] pc,
    output memwriteM,
    output [31:0] aluoutM,
    output [31:0] writedataM
);

    // Pipelined control signals
    logic [31:0] instrE, instrM, instrW;
    logic regwriteE, regwriteM, regwriteW;
    logic memtoregE, memtoregM, memtoregW;
    logic memwriteE;
    logic [2:0] alucontrolE;
    logic alusrcE;
    logic regdstE;
    logic branchE, branchM;
    logic zeroM;

    // Pipelined internal datapath signals
    logic pcsrc, pcsrcD;
    logic equalD;
    logic [31:0] aluout, aluoutE, aluoutW;
    logic [31:0] writedata, writedataMUX, writedataE;
    logic [31:0] readdataW;
    logic [4:0] writeregE, writeregM, writeregW;
    logic [4:0] rtE, rsE, rdE;
    logic [31:0] pcnext, pcnextbr, pcbranch, pcbranchD, pcbranchM, pcplus4, pcplus4D, pcplus4E;
    logic [31:0] signimmsh, signimmD, signimmE;
    logic [31:0] srca, srcaMUX, srcaE, srcbE, srccE;
    logic [31:0] result;

    // Hazard internal signals
    logic [1:0] forwardAE, forwardBE;
    logic forwardAD, forwardBD;
    logic stallF, stallD, flushE;

	logic [31:0] srcaEQ, writedataEQ;
    
    // ====================================
    // Next PC logic
    // ====================================
    // Switch between PC+1 or a computed PC
    assign pcsrcD = branch & equalD;

    // Register to hold and update the PC
    flopr #(32) pcreg(
        stallF, clk, reset, pcnext, // Input
        pc                  // Output
    );

    // Adder to calculate next PC address
    adder pcadd1(
        pc, 32'b100,    // Input
        pcplus4         // Output
    );
    
    // Shift immediate 2 to the left to jump word addresses
    sl2 immsh(
        signimmD,    // Input
        signimmsh   // Output
    );

    // Adder to calculate branch address
    adder pcadd2(
        pcplus4D, signimmsh, // Input
        pcbranchD            // Output
    );

    // Branch and jump logic
    always_comb begin
        if (pcsrcD)
            pcnext = pcbranchD;
        else if (jump)
            pcnext = {pcplus4D[31:28], instrD[25:0], 2'b00};
        else
            pcnext = pcplus4;
    end

    // Instruction fetch --> Instruction decode register
    IF_ID IF_ID(
        pcsrcD, stallD, clk, instr, pcplus4,    // Input
        instrD, pcplus4D        // Output
    );

    // ====================================
    // Register File Logic
    // ====================================
    // Register file instantiation
    regfile rf(
        clk, regwriteW, instrD[25:21], instrD[20:16], instrD[15:11], writeregW, result, // Input
        srca, writedata, srcc                                                           // Output
    );

    // Select which register to write to
    mux2 #(5) wrmux(
        rtE, rdE, regdstE, // Input
        writeregE          // Output
    );

    // Select what value gets written back to the register
    mux2 #(32) resmux(
        aluoutW, readdataW, memtoregW, // Input
        result                      // Output
    );

    // Sign extend the lower 16 bits of the instruction for branch and immediate instructions
    signext se(
        instrD[15:0],    // Input
        signimmD         // Output
    );

    // Instruction Decode --> Execution pipeline register
	ID_EX ID_EX(
        flushE, clk, instrD[25:21], instrD, // Inputs
        regwrite, memtoreg, memwrite, branch, alucontrol, alusrc, regdst, // Inputs (control)
        srca, writedata, srcc, instrD[20:16], instrD[15:11], signimmD, pcplus4D, // Inputs
		regwriteE, memtoregE, memwriteE, branchE, alucontrolE, alusrcE, regdstE, // Outputs (control)
        srcaMUX, writedataMUX, srccE, rtE, rdE, signimmE, pcplus4E, instrE, rsE // Outputs
    );
    
    // ====================================
    // ALU logic
    // ====================================
    // Forwarding logic for the ALU
    mux_dontcare3 muxsrca(srcaMUX, result, aluoutM, forwardAE, srcaE);
    mux_dontcare3 muxwritedata(writedataMUX, result, aluoutM, forwardBE, writedataE);

    // Choose between register and immediate values for the ALU
    mux2 #(32) srcbmux(
        writedataE, signimmE, alusrcE, // Input
        srcbE                        // Output
    );

    // ALU instantiation
    alu alu(
        srcaE, srcbE, srccE, alucontrolE,   // Input
        aluout, zero                        // Output
    );

    // Execution --> Memory pipeline register
    EX_MEM EX_MEM(
        clk, instrE, // Inputs
        regwriteE, memtoregE, memwriteE, branchE, // Inputs (control)
        zero, aluout, writedataE, writeregE, pcbranch, // Inputs 
		regwriteM, memtoregM, memwriteM, branchM, // Outputs (control)
		zeroM, aluoutM, writedataM, writeregM, pcbranchM, instrM // Outputs
    );

    // Memory --> Writeback pipeline register
    MEM_WB MEM_WB(
        clk, instrM, // Inputs
        regwriteM, memtoregM, aluoutM, readdata, writeregM, // Inputs (control)
		regwriteW, memtoregW, aluoutW, readdataW, writeregW, instrW // Outputs (control)
    );

    hazardunit hazardunit(
        branch, memtoregE, memtoregM, instrD[25:21], instrD[20:16], // Inputs
        regwriteE, regwriteM, regwriteW, rsE, rtE, writeregE, writeregM, writeregW, // Inputs
		forwardAE, forwardBE, stallF, stallD, flushE, forwardAD, forwardBD // Outputs
    );

    equal equal(srcaEQ, writedataEQ, equalD);

    mux_dontcare srcsEQMUX(srca, aluoutM, forwardAD, srcaEQ);
    mux_dontcare writedataEQMUX(writedata, aluoutM, forwardBD, writedataEQ);

endmodule


//////////////////////////////////////////////////////////////////////
// Register File Module
//////////////////////////////////////////////////////////////////////
module regfile (
    input clk,
    input we3,
    input [4:0] ra1, ra2, ra3, wa3,
    input [31:0] wd3,
    output [31:0] rd1, rd2, rd3
);
    
    logic [31:0] rf[31:0];

    // four ported register file
    // read three ports combinationally
    // write third port on rising edge of clock
    // register 0 hardwired to 0
    always_ff @ (negedge clk)
        if (we3 && wa3 != 0) rf[wa3] <= wd3;

    assign rd1 = (ra1 != 0) ? rf[ra1] : 0;
    assign rd2 = (ra2 != 0) ? rf[ra2] : 0;
    assign rd3 = (ra3 != 0) ? rf[ra3] : 0;

endmodule


//////////////////////////////////////////////////////////////////////
// ALU Module
//////////////////////////////////////////////////////////////////////
module alu(
    input [31:0] a,
    input [31:0] b,
    input [31:0] c,
    input [2:0] control,
    output logic [31:0] result,
    output zero
);

    localparam ALU_AND      = 3'b000;
    localparam ALU_OR       = 3'b001;
    localparam ALU_ADD      = 3'b010;
    localparam ALU_MULADD   = 3'b100;
    localparam ALU_SUB      = 3'b110;
    localparam ALU_SLT      = 3'b111;
    
    always_comb begin
        case(control)
            ALU_AND: result = a & b;
            ALU_OR:  result = a | b;
            ALU_ADD: result = a + b;
            ALU_MULADD: result = a * b + c;
            ALU_SUB: result = a - b;
            ALU_SLT: result = ($signed(a) < $signed(b));
            default: result = 32'bx;
        endcase
    end
    
    assign zero = (result == 32'b0);
    
endmodule


//////////////////////////////////////////////////////////////////////
// Adder Module
//////////////////////////////////////////////////////////////////////
module adder (
    input [31:0] a, b,
    output [31:0] y
);
    assign y = a + b;
endmodule


//////////////////////////////////////////////////////////////////////
// 2-to-1 Multiplexer Module
//////////////////////////////////////////////////////////////////////
module mux2 # (parameter WIDTH = 8) (
    input [WIDTH-1:0] d0, d1,
    input s,
    output [WIDTH-1:0] y
);
    assign y = s ? d1 : d0;
endmodule


//////////////////////////////////////////////////////////////////////
// 2-to-1 'Don't Care' Multiplexer Module
//////////////////////////////////////////////////////////////////////
module mux_dontcare(
    input  logic [31:0] d0, d1, 
	input  logic s, 
	output logic [31:0] y
);

    always_comb
    begin
	    case(s)
    		1'b1 : y = d1;
            default: y = d0;
    	endcase
    end

endmodule


//////////////////////////////////////////////////////////////////////
// 3-to-1 'Don't Care' Multiplexer Module
//////////////////////////////////////////////////////////////////////
module mux_dontcare3(
    input  logic [31:0] d0, d1, d2,
	input  logic [1:0] s, 
	output logic [31:0] y
);

    always_comb
    begin
        case(s)
            2'b00 : y = d0;
            2'b01 : y = d1;
            2'b10 : y = d2; 
            default: y = d0;
        endcase
    end

endmodule


//////////////////////////////////////////////////////////////////////
// Shift Left by 2 Module
//////////////////////////////////////////////////////////////////////
module sl2 (
    input [31:0] a,
    output [31:0] y
);
    // shift left by 2
    assign y = {a[29:0], 2'b00};
endmodule


//////////////////////////////////////////////////////////////////////
// Sign Extension Module
//////////////////////////////////////////////////////////////////////
module signext (
    input [15:0] a,
    output [31:0] y
);
    assign y = {{16{a[15]}}, a};
endmodule


//////////////////////////////////////////////////////////////////////
// Flop Register Module
//////////////////////////////////////////////////////////////////////
module flopr #(parameter WIDTH = 8) (
    input logic stallF,
	input logic clk, reset,
    input  logic [WIDTH-1:0] d, 
    output logic [WIDTH-1:0] q
);

    always_ff @(posedge clk, posedge reset) begin
        if (reset) q <= '0;
    	else if (!stallF) q <= d;
    end
endmodule


module equal(
    input logic [31:0] srca, writedata,
    output logic equalD
);
    always_comb begin
        equalD = (srca == writedata);
    end
endmodule


module hazardunit(
    input logic branch,
    input logic memtoregE, memtoregM, 
    input logic [4:0] rsD, rtD,
    input logic regwriteE, regwriteM, regwriteW,
	input logic [4:0] rsE, rtE, 
	input logic [4:0] writeregE, writeregM, writeregW,
	output logic [1:0] forwardAE, forwardBE,
    output logic stallF, stallD, flushE,
    output logic forwardAD, forwardBD
);
    
    logic lwstall;
    logic branchstall;

	always_comb
	begin
        if ((rsE != 5'd0) &&
            (rsE == writeregM) && regwriteM && !memtoregM)
            forwardAE = 2'b10;
        else if ((rsE != 5'd0) &&
                (rsE == writeregW) && regwriteW)
            forwardAE = 2'b01;
        else
            forwardAE = 2'b00;
		
        if ((rtE != 5'd0) &&
            (rtE == writeregM) && regwriteM && !memtoregM)
            forwardBE = 2'b10;
        else if ((rtE != 5'd0) &&
                (rtE == writeregW) && regwriteW)
            forwardBE = 2'b01;
        else
            forwardBE = 2'b00;

        lwstall = ((rsD == rtE) || (rtD == rtE)) && memtoregE && (rtE != 5'd0);

        forwardAD = (rsD != 5'd0) &&
                    (rsD == writeregM) &&
                    regwriteM && !memtoregM;

        forwardBD = (rtD != 5'd0) &&
                    (rtD == writeregM) &&
                    regwriteM && !memtoregM;
		
        branchstall =
            (branch && regwriteE &&
                (writeregE != 5'd0) &&
                ((writeregE == rsD) || (writeregE == rtD))) ||
            (branch && memtoregM &&
                (writeregM != 5'd0) &&
                ((writeregM == rsD) || (writeregM == rtD)));
						
		stallF = lwstall || branchstall;
		stallD = lwstall || branchstall;
		flushE = lwstall || branchstall;
	end			
endmodule


//////////////////////////////////////////////////////////////////////
// IF --> ID Pipelined Register Module
//////////////////////////////////////////////////////////////////////
module IF_ID(
    input logic pcsrcD,
    input logic stallD, 
    input logic clk,
	input logic [31:0] instr, pcplus4,
	output logic [31:0] instrD, pcplus4D
);
    always_ff @(posedge clk) begin
        if (pcsrcD == 1'b1) begin
            instrD <= 0;
            pcplus4D <= 0;
        end
        else if (!stallD) begin
            instrD  <= instr;
            pcplus4D <= pcplus4;
            if(instrD!=8'hx)
			$display("Instruction %h is in ID stage", instrD);
        end
	end
endmodule


//////////////////////////////////////////////////////////////////////
// ID --> EX Pipelined Register Module
//////////////////////////////////////////////////////////////////////
module ID_EX(
    input logic flushE,
    input logic clk,
    input logic [4:0] rsD,
	input logic [31:0] instrD,
	input logic regwrite, memtoreg, memwrite, branch, 
	input logic [2:0] alucontrol,
	input logic alusrc, regdst,
	input logic [31:0] srca, writedata, srcc,
	input logic [4:0] rtD, rdD,
	input logic [31:0] signimmD, pcplus4D,
	output logic regwriteE, memtoregE, memwriteE, branchE, 
	output logic [2:0] alucontrolE,
	output logic alusrcE, regdstE,
    output logic [31:0] srcaMUX, writedataMUX, srccE,
	output logic [4:0] rtE, rdE,
	output logic [31:0] signimmE, pcplus4E,
	output logic [31:0] instrE,
    output logic [4:0] rsE
);
	always_ff @(posedge clk)
	begin
		if(flushE==1'b1)
		begin
			regwriteE <= 0;
			memtoregE <= 0;
			memwriteE <= 0;
			branchE <= 0;
			alucontrolE <= 0;
			alusrcE <= 0;
			regdstE <= 0;
			srcaMUX <= 0;
			writedataMUX <= 0;
            srccE <= 0;
			rtE <= 0;
			rdE <= 0;
			signimmE <= 0;
			pcplus4E <= 0;
			instrE <= 0;
			rsE <= 0;
		end
		else 
		begin
			regwriteE <= regwrite;
			memtoregE <= memtoreg;
			memwriteE <= memwrite;
			branchE <= branch;
			alucontrolE <= alucontrol;
			alusrcE <= alusrc;
			regdstE <= regdst;
			srcaMUX <= srca;
			writedataMUX <= writedata;
			srccE <= srcc;
			rtE <= rtD;
			rdE <= rdD;
			signimmE <= signimmD;
			pcplus4E <= pcplus4D;
			instrE <= instrD;
			rsE <= rsD;
			if(instrE!=8'hx)
			$display("Instruction %h is in EX stage", instrE);
		end
	end
endmodule


//////////////////////////////////////////////////////////////////////
// EX --> MEM Pipelined Register Module
//////////////////////////////////////////////////////////////////////
module EX_MEM(
    input logic clk, 
	input logic [31:0] instrE,
	input logic regwriteE, memtoregE, memwriteE, branchE,
	input logic zero, 
	input logic [31:0] aluout, writedataE, 
	input logic [4:0] writeregE, 
	input logic [31:0] pcbranch,
	output logic regwriteM, memtoregM, memwriteM, branchM,
	output logic zeroM, 
	output logic [31:0] aluoutM, writedataM,
	output logic [4:0] writeregM, 
	output logic [31:0] pcbranchM,
	output logic [31:0] instrM
);
	always_ff @(posedge clk)
	begin
		//$display("EX to MEM");
		regwriteM <= regwriteE;
		memtoregM <= memtoregE;
		memwriteM <= memwriteE;
		branchM <= branchE;
		zeroM <= zero;
		aluoutM <= aluout;
		writedataM <= writedataE;
		writeregM <= writeregE;
		pcbranchM <= pcbranch;
		instrM <= instrE;
		if(instrM != 8'hx)
		    $display("Instruction %h entered MEM stage", instrM);
	end
endmodule


//////////////////////////////////////////////////////////////////////
// MEM --> WB Pipelined Register Module
//////////////////////////////////////////////////////////////////////
module MEM_WB(
    input logic clk,
	input logic [31:0] instrM,
	input logic regwriteM,
	input logic memtoregM,
	input logic [31:0] aluoutM, readdata,
	input logic [4:0] writeregM,
	output logic regwriteW,
	output logic memtoregW,
	output logic [31:0] aluoutW, readdataW,
	output logic [4:0] writeregW,
	output logic [31:0] instrW
);
	always_ff @(posedge clk)
	begin
		//$display("MEM to WB");
		regwriteW <= regwriteM;
		memtoregW <= memtoregM;
		aluoutW <= aluoutM;
		readdataW <= readdata;
		writeregW <= writeregM;
		instrW <= instrM;
		if(instrW != 8'hx)
		    $display("Instruction %h entered WB stage", instrW);
	end
endmodule