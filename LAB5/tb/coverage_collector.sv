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
    wait(vif.reset == 0);

    forever begin
      @(posedge vif.clk);
      if (vif.reset)
        continue;

      instr = new("instruction"); // TODO: consider if this is the instruction being retired or fetched
      instr.opcode = vif.instr[31:26];
      instr.rs = vif.instr[25:21];
      instr.rt = vif.instr[20:16];
      if (instr.opcode == 6'b000000) begin
        instr.rd = vif.instr[15:11];
        instr.imm = 16'b0;
        instr.funct = vif.instr[5:0];
      end
      else begin
        instr.rd = 5'b0;
        instr.imm = vif.instr[15:0];
        instr.funct = 6'b0;
      end

      ap.write(instr); // post to UVM analysis
    end
  endtask
endclass


class instr_coverage extends uvm_subscriber #(instruction);
  `uvm_component_utils(instr_coverage)

  uvm_analysis_imp #(instruction, instr_coverage) imp;

  instruction instr;
  int instr_type;
  int reg_gap[4];
  int raw_gap;
  int waw_gap;

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
      bins valid_imms = {[0:4], 6'h8, 6'hC};
    }
    coverpoint instr.funct {
      bins no_func = {6'b000000};
      bins add = {6'b100000};
      bins and = {6'b100100};
    }
  endgroup

  covergroup instr_order_cg;
    coverpoint instr_type {
      bins instruction_transitions[] = ([1:5] => [1:5]);
    }
  endgroup

  covergroup instr_gap_cg;
    coverpoint raw_gap {
      bins raw_gaps = {[1:4]}; // read after write gaps
    }
    coverpoint waw_gap {
      bins waw_gaps = {[1:4]}; // write after write gaps
    }
  endgroup

  ...

  function new(string name, uvm_component parent);
    super.new(name, parent);
    imp = new("analysis_imp", this);
    instr_fields_cg = new();
    instr_order_cg = new();
    instr_gap_cg = new();
    reg_gap = '{default:0};
    raw_gap = 0;
    waw_gap = 0;
  endfunction

  function void write(instruction i);

    instr = i;

    // Determine what insruction is encoded in the transaction
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

    // Updated the gaps between dependent instructions
    // Dependencies are tracked from the last write
    if (instr_type == 1 || instr_type == 2) begin // write reg is rd, read reg is rs and rt
      waw_gap = reg_gap[instr.rd - 1]; // save the gap of the rd register for sampling
      instr_gap_cg.sample();
      
      raw_gap = reg_gap[instr.rs - 1]; // save the gap of the rs register for sampling
      instr_gap_cg.sample();

      raw_gap = reg_gap[instr.rt - 1]; // save the gap of the rt register for sampling
      instr_gap_cg.sample();

      reg_gap[0] = (instr.rd == 1) ? 0 : reg_gap[0] + 1;  // if the write reg is 1, reset the count, otherwise increment
      reg_gap[1] = (instr.rd == 2) ? 0 : reg_gap[1] + 1;  // if the write reg is 2, reset the count, otherwise increment  
      reg_gap[2] = (instr.rd == 3) ? 0 : reg_gap[2] + 1;  // if the write reg is 3, reset the count, otherwise increment
      reg_gap[3] = (instr.rd == 4) ? 0 : reg_gap[3] + 1;  // if the write reg is 4, reset the count, otherwise increment
    end
    else if (instr_type == 3) begin // write reg is rt, read reg is rs
      waw_gap = reg_gap[instr.rt - 1]; // save the gap of the rt register for sampling
      instr_gap_cg.sample();

      raw_gap = reg_gap[instr.rs - 1]; // save the gap of the rs register for sampling
      instr_gap_cg.sample();

      reg_gap[0] = (instr.rt == 1) ? 0 : reg_gap[0] + 1;  // if the write reg is 1, reset the count, otherwise increment
      reg_gap[1] = (instr.rt == 2) ? 0 : reg_gap[1] + 1;  // if the write reg is 2, reset the count, otherwise increment  
      reg_gap[2] = (instr.rt == 3) ? 0 : reg_gap[2] + 1;  // if the write reg is 3, reset the count, otherwise increment
      reg_gap[3] = (instr.rt == 4) ? 0 : reg_gap[3] + 1;  // if the write reg is 4, reset the count, otherwise increment
    end
    else if (instr_type == 4 || instr_type == 5) begin // no write reg, read reg is rt and rs
      raw_gap = reg_gap[instr.rs - 1]; // save the gap of the rs register for sampling
      instr_gap_cg.sample();

      raw_gap = reg_gap[instr.rt - 1]; // save the gap of the rt register for sampling
      instr_gap_cg.sample();

      reg_gap[0] = reg_gap[0] + 1;  // if the write reg is 1, reset the count, otherwise increment
      reg_gap[1] = reg_gap[1] + 1;  // if the write reg is 2, reset the count, otherwise increment  
      reg_gap[2] = reg_gap[2] + 1;  // if the write reg is 3, reset the count, otherwise increment
      reg_gap[3] = reg_gap[3] + 1;  // if the write reg is 4, reset the count, otherwise increment
    end
    else begin // no write reg
      reg_gap[0] = reg_gap[0] + 1;  // no write reg, increment
      reg_gap[1] = reg_gap[1] + 1;  // no write reg, increment  
      reg_gap[2] = reg_gap[2] + 1;  // no write reg, increment
      reg_gap[3] = reg_gap[3] + 1;  // no write reg, increment
    end

    //Create a queue
    //Call sample of various cgs
    instr_fields_cg.sample();
    
    instr_order_cg.sample();
    
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
