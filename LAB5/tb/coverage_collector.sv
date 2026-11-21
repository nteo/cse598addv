typedef enum bit [5:0] {
  RTYPE = 6'b000000,
  ADDI = 6'b001000,
  LW = 6'b100011,
  SW = 6'b101011,
  BEQ = 6'b000100
} opcode_t;

typedef enum bit [5:0] {
  NO_FUNCT = 6'b000000,
  ADD = 6'b100000,
  AND = 6'b100100
} funct_t;

class instr_monitor extends uvm_monitor;
  `uvm_component_utils(instr_monitor) // register monitor with UVM factory

  instruction instr; // instruction transaction
  uvm_analysis_port #(instruction) ap; // analysis port for instruction transactions
  virtual instr_mem_if vif; // virtual DUT interface

  // Constructor
  function new(string name = "instr_monitor", uvm_component parent = null);
    super.new(name, parent); // instantiate parent
    ap = new("ap", this); // instantiate object
    instr = new(); // instantiate transaction item
  endfunction

  // Build phase
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    //Get vif from resource db
    if (!uvm_resource_db #(virtual instr_mem_if)::read_by_name(get_full_name(), "instr_mem_if_ptr", vif, this))
        `uvm_fatal(get_type_name(), "read by name failed for instr_monitor")
  endfunction

  task run_phase(uvm_phase phase);
    super.run_phase(phase);

    //wait for reset
    forever begin
      if (!vif.reset) begin
        @(posedge vif.clk);
        instr = new("instruction")
        phase.raise_objection(this);
        instr.opcode = vif.instr[31:26];
        if (instr.opcode == 6'b000000) begin
          instr.rs = vif.instr[25:21];
          instr.rt = vif.instr[20:16];
          instr.rd = vif.instr[15:11];
          instr.funct = vif.instr[5:0];
        end
        else begin
          instr.rs = vif.instr[25:21];
          instr.rt = vif.instr[20:16];
          instr.rd = 5'b0;
        end
        ap.write(instr); // post to UVM analysis
      end
    end
  endtask
endclass


class instr_coverage extends uvm_subscriber #(instruction);
  `uvm_component_utils(instr_coverage)

  uvm_analysis_imp #(instruction, instr_coverage) imp;

  instruction instr;
  int instr_type;

  covergroup instr_fields_cg;
    coverpoint instr.opcode {
      bins rtype = {6'b000000};
      bins lw = {6'b100011};
      bins sw = {6'b101011};
      bins beq = {6'b000100};
    }
    coverpoint instr.rd {
      bins valid_regs = {[1:4]};
    }
    coverpoint instr.rs {
      bins valid_regs = {[1:4]};
    }
    coverpoint instr.rt {
      bins valid_regs = {[1:4]};
    }
    coverpoint instr.imm {
      bins valid_imms = {[1:4]};
    }
    coverpoint instr.func {
      bins no_func = {6'b000000};
      bins add = {6'b100000};
      bins and = {6'b100100};
    }
  endgroup

  covergroup instr_order_cg;
    coverpoint 
  endgroup

  covergroup instr_gap_cg;
  endgroup

  ...

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void write(instruction i);

    instr = i;

    case (instr.opcode)
	    6'b000000: begin
		    case (instr.funct)
			    6'b100000: instr_type = 1; // ADD
			    6'b100100: instr_type = 2; // AND
			    default: instr_type = 0;   // other
		    endcase
	    end

	    6'b100011: instr_type = 3; // LW
	    6'b101011: instr_type = 4; // SW
	    6'b000100: instr_type = 5; // BEQ
	    default: instr_type = 0;
    endcase

    //Create a queue
    //Call sample of various cgs
    instr_fields_cg.sample();
    instr_order_cg.sample();
    instr_gap_cg.sample();
    
  endfunction
endclass

class instr_env extends uvm_env;
  `uvm_component_utils(instr_env)

  instr_monitor mon;
  instr_coverage cov;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ...
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    mon.ap.connect(cov.imp);
  endfunction
endclass

class my_test extends uvm_test;

    my_env env;

    `uvm_component_utils(my_test)

    function new (string name = "my_test", uvm_component parent = null);
      super.new (name, parent);
    endfunction

    function void build_phase (uvm_phase phase);
         super.build_phase (phase);
         env  = my_env::type_id::create ("my_env", this);
      endfunction
endclass

module top;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  //DUT instance
  //Interface

  //Resource db population

  initial begin
    //Code from the instr generator part:
    gen = new();
    gen.generate_machine_code();
    gen.display_all();
    //Note you will merge the codes from the instr generator and the coverage collector properly. I'm just showing something basic.

    //Copy memory from gen to the instr mem
    //OR: Call $readmemh on that file you wrote using $writememh
    //Deassert reset
    run_test("my_test");
  end
endmodule
