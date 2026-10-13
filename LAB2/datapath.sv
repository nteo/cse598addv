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
    input [1:0] resultsrc,
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
    logic [1:0] resultsrcE, resultsrcM, resultsrcW;
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
    logic [31:0] perfmon_value;
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

    // Valid bit for each stage of the pipeline
    logic validD, validE, validM, validW;
    
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
        (pcsrcD || jump), stallD, clk, reset, instr, pcplus4,    // Input
        instrD, pcplus4D, validD                // Output
    );

    // ====================================
    // Register File Logic
    // ====================================
    // Register file instantiation
    regfile rf(
        clk, reset, regwriteW, instrD[25:21], instrD[20:16], instrD[15:11], writeregW, result, // Input
        srca, writedata, srcc                                                           // Output
    );

    // Select which register to write to
    mux2 #(5) wrmux(
        rtE, rdE, regdstE, // Input
        writeregE          // Output
    );

    // Select what value gets written back to the register
    mux_dontcare3 resmux(
        aluoutW, readdataW, perfmon_value, resultsrcW, // Input
        result                      // Output
    );

    // Sign extend the lower 16 bits of the instruction for branch and immediate instructions
    signext se(
        instrD[15:0],    // Input
        signimmD         // Output
    );

    // Instruction Decode --> Execution pipeline register
	ID_EX ID_EX(
        flushE, clk, reset, instrD[25:21], instrD, // Inputs
        regwrite, resultsrc, memwrite, branch, alucontrol, alusrc, regdst, // Inputs (control)
        srca, writedata, srcc, instrD[20:16], instrD[15:11], signimmD, pcplus4D, validD// Inputs
		regwriteE, resultsrcE, memwriteE, branchE, alucontrolE, alusrcE, regdstE, // Outputs (control)
        srcaMUX, writedataMUX, srccE, rtE, rdE, signimmE, pcplus4E, instrE, rsE, validE // Outputs
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

    performance_monitor pm(
        clk,
        reset,
        instrW[0],  // use the LSB of the immediate value for the flag
        validW,
        perfmon_value
    );
    // Execution --> Memory pipeline register
    EX_MEM EX_MEM(
        clk, reset, instrE, // Inputs
        regwriteE, resultsrcE, memwriteE, branchE, // Inputs (control)
        zero, aluout, writedataE, writeregE, pcbranch, validE // Inputs 
		regwriteM, resultsrcM, memwriteM, branchM, // Outputs (control)
		zeroM, aluoutM, writedataM, writeregM, pcbranchM, instrM, validM // Outputs
    );

    // Memory --> Writeback pipeline register
    MEM_WB MEM_WB(
        clk, reset, instrM, // Inputs
        regwriteM, resultsrcM, aluoutM, readdata, writeregM, validM // Inputs (control)
		regwriteW, resultsrcW, aluoutW, readdataW, writeregW, instrW, validW // Outputs (control)
    );

    hazardunit hazardunit(
        branch, resultsrcE, resultsrcM, instrD[25:21], instrD[20:16], // Inputs
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
    input logic clk, reset,
    input logic we3,
    input logic [4:0] ra1, ra2, ra3, wa3,
    input logic [31:0] wd3,
    output logic [31:0] rd1, rd2, rd3
);

    logic [31:0] rf[31:0];
    integer i;

    always_ff @(negedge clk or posedge reset) begin
        if (reset) begin
            for (i = 0; i < 32; i = i + 1)
                rf[i] <= 32'b0;
        end
        else if (we3 && wa3 != 5'd0) begin
            rf[wa3] <= wd3;
        end
    end
  
    assign rd1 = (ra1 != 5'd0) ? rf[ra1] : 32'b0;
    assign rd2 = (ra2 != 5'd0) ? rf[ra2] : 32'b0;
    assign rd3 = (ra3 != 5'd0) ? rf[ra3] : 32'b0;
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
// Performance Monitor Module
//////////////////////////////////////////////////////////////////////
module performance_monitor(
    input  logic clk,
    input  logic reset,
    input  logic flag,
    input  logic validW,
    output logic [31:0] result
);

    logic [31:0] cycle_count, inst_count;

    assign result = (flag == 1'b0) ? cycle_count : inst_count;

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            cycle_count <= 0;
            inst_count <= 0;
        end
        else begin
            cycle_count <= cycle_count + 1;
            if (validW)
                inst_count <= inst_count + 1;
            else
                inst_count <= inst_count;
        end
    end
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
    input logic [1:0] resultsrcE, resultsrcM, 
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
            (rsE == writeregM) && regwriteM && (resultsrcM == 2'b00))
            forwardAE = 2'b10;
        else if ((rsE != 5'd0) &&
                (rsE == writeregW) && regwriteW)
            forwardAE = 2'b01;
        else
            forwardAE = 2'b00;
		
        if ((rtE != 5'd0) &&
            (rtE == writeregM) && regwriteM && (resultsrcM == 2'b00))
            forwardBE = 2'b10;
        else if ((rtE != 5'd0) &&
                (rtE == writeregW) && regwriteW)
            forwardBE = 2'b01;
        else
            forwardBE = 2'b00;

        lwstall = ((rsD == rtE) || (rtD == rtE))
                && (resultsrcE == 2'b01)
                && (rtE != 5'd0);

        forwardAD = (rsD != 5'd0) &&
                    (rsD == writeregM) &&
                    regwriteM && (resultsrcM == 2'b00);

        forwardBD = (rtD != 5'd0) &&
                    (rtD == writeregM) &&
                    regwriteM && (resultsrcM == 2'b00);
		
        branchstall =
            (branch && regwriteE &&
                (writeregE != 5'd0) &&
                ((writeregE == rsD) || (writeregE == rtD))) ||
            (branch && (resultsrcM == 2'b01) &&
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
    input logic clk, reset,
	input logic [31:0] instr, pcplus4,
	output logic [31:0] instrD, pcplus4D,
    output logic validD
);
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            instrD  <= 32'b0;
            pcplus4D <= 32'b0;
            validD <= 1'b0;
        end
        else if (pcsrcD) begin
            instrD <= 32'b0;
            pcplus4D <= 32'b0;
            validD <= 1'b0;
        end
        else if (!stallD) begin
            instrD  <= instr;
            pcplus4D <= pcplus4;
            validD <= 1'b1;
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
    input logic clk, reset,
    input logic [4:0] rsD,
	input logic [31:0] instrD,
    input logic [1:0] resultsrc,
	input logic regwrite, memwrite, branch, 
	input logic [2:0] alucontrol,
	input logic alusrc, regdst,
	input logic [31:0] srca, writedata, srcc,
	input logic [4:0] rtD, rdD,
	input logic [31:0] signimmD, pcplus4D,
    input logic validD,
    output logic [1:0] resultsrcE,
	output logic regwriteE, memwriteE, branchE, 
	output logic [2:0] alucontrolE,
	output logic alusrcE, regdstE,
    output logic [31:0] srcaMUX, writedataMUX, srccE,
	output logic [4:0] rtE, rdE,
	output logic [31:0] signimmE, pcplus4E,
	output logic [31:0] instrE,
	output logic [4:0] rsE,
    output logic validE
);
	always_ff @(posedge clk or posedge reset)
	begin
		if(reset || flushE)
		begin
			regwriteE <= 0;
			resultsrcE <= 0;
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
			validE <= 0;
		end
		else 
		begin
			regwriteE <= regwrite;
			resultsrcE <= resultsrc;
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
            validE <= validD;
			if(instrE!=8'hx)
			$display("Instruction %h is in EX stage", instrE);
		end
	end
endmodule


//////////////////////////////////////////////////////////////////////
// EX --> MEM Pipelined Register Module
//////////////////////////////////////////////////////////////////////
module EX_MEM(
    input logic clk, reset,
	input logic [31:0] instrE,
    input logic [1:0] resultsrcE,
    input logic regwriteE, memwriteE, branchE,
	input logic zero, 
	input logic [31:0] aluout, writedataE, 
	input logic [4:0] writeregE, 
	input logic [31:0] pcbranch,
    input logic validE,
    output logic [1:0] resultsrcM,
    output logic regwriteM, memwriteM, branchM,
	output logic zeroM, 
	output logic [31:0] aluoutM, writedataM,
	output logic [4:0] writeregM, 
	output logic [31:0] pcbranchM,
	output logic [31:0] instrM,
    output logic validM
);
	always_ff @(posedge clk or posedge reset)
	begin
        if (reset) begin
            regwriteM <= 1'b0;
            resultsrcM <= 2'b00;
            memwriteM <= 1'b0;
            branchM   <= 1'b0;
            zeroM     <= 1'b0;
            aluoutM   <= 32'b0;
            writedataM <= 32'b0;
            writeregM <= 5'b0;
            pcbranchM <= 32'b0;
            instrM    <= 32'b0;
            validM    <= 32'b0;
        end
        else begin
            //$display("EX to MEM");
            regwriteM <= regwriteE;
            resultsrcM <= resultsrcE;
            memwriteM <= memwriteE;
            branchM <= branchE;
            zeroM <= zero;
            aluoutM <= aluout;
            writedataM <= writedataE;
            writeregM <= writeregE;
            pcbranchM <= pcbranch;
            instrM <= instrE;
            validM <= validE;
            if(instrM != 8'hx)
                $display("Instruction %h entered MEM stage", instrM);
        end
	end
endmodule


//////////////////////////////////////////////////////////////////////
// MEM --> WB Pipelined Register Module
//////////////////////////////////////////////////////////////////////
module MEM_WB(
    input logic clk, reset,
	input logic [31:0] instrM,
	input logic regwriteM,
	input logic [1:0] resultsrcM,
	input logic [31:0] aluoutM, readdata,
	input logic [4:0] writeregM,
    input logic validM,
	output logic regwriteW,
	output logic [1:0] resultsrcW,
	output logic [31:0] aluoutW, readdataW,
	output logic [4:0] writeregW,
	output logic [31:0] instrW,
    output logic validW
);
	always_ff @(posedge clk, posedge reset)
	begin
        if (reset) begin
            regwriteW <= 1'b0;
            resultsrcW <= 2'b00;
            aluoutW   <= 32'b0;
            readdataW <= 32'b0;
            writeregW <= 5'b0;
            instrW    <= 32'b0;
            validW    <= 32'b0;
        end
        else begin
            //$display("MEM to WB");
            regwriteW <= regwriteM;
            resultsrcW <= resultsrcM;
            aluoutW <= aluoutM;
            readdataW <= readdata;
            writeregW <= writeregM;
            instrW <= instrM;
            validW <= validM;
            if(instrW != 8'hx)
                $display("Instruction %h entered WB stage", instrW);
        end
	end
endmodule