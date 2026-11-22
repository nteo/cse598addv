interface instr_mem_if;
    logic reset;
    logic clk;
    logic [31:0] instr;
    logic branch;
    logic equal;
    logic program_done;

    modport DUT(
        input reset,
        input clk,
        input program_done,
        output instr,
        output branch,
        output equal
    );

    modport TESTBENCH(
        output reset,
        output clk,
        output program_done,
        input instr,
        input branch,
        input equal
    );
endinterface
