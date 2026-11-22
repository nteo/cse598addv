`timescale 1ns/1ps

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
    instruction instr;

    super.run_phase(phase);

    //wait for reset
    wait(vif.reset == 0);

    forever begin
      @(posedge vif.clk);
      if (vif.reset) begin
        continue;
      end
      
        instr = new();
        instr.opcode = opcode_t'(vif.instr[31:26]);
        instr.rs = vif.instr[25:21];
        instr.rt = vif.instr[20:16];
        if (instr.opcode == 6'b000000) begin
          instr.rd = vif.instr[15:11];
          instr.imm = 16'b0;
          instr.funct = funct_t'(vif.instr[5:0]);
        end
        else begin
          instr.rd = 5'b0;
          instr.imm = vif.instr[15:0];
          instr.funct = funct_t'(6'b0);
        end
        instr.branch = vif.branch;
        instr.equal = vif.equal;

        ap.write(instr); // post to UVM analysis

    end
  endtask
endclass


class instr_coverage extends uvm_subscriber #(instruction);
  `uvm_component_utils(instr_coverage)

  instruction instr;
  int instr_type;
  bit regs_written[4];
  bit addr_written[4];
  int reg_gap[4];
  int reg_raw_gap;
  int reg_waw_gap;
  int mem_gap[4];
  int mem_raw_gap;
  int mem_waw_gap;
  int dependency_reg;
  int dependency_addr;
  logic branch_taken;

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
      bins valid_imms = {[0:4], 16'h8, 16'hC};
    }
    coverpoint instr.funct {
      bins NO_FUNC = {6'b000000};
      bins ADD = {6'b100000};
      bins AND = {6'b100100};
    }
  endgroup

  covergroup instr_branch_cg;
    coverpoint branch_taken {
      bins taken = {1};
      bins not_taken = {0};
    }
  endgroup

  covergroup instr_order_cg;
    coverpoint instr_type {
      bins instruction_transitions[] = ([1:5] => [1:5]);
    }
  endgroup

  covergroup dependency_reg_cg;
    coverpoint dependency_reg {
      bins regs = {[1:4]};
    }
  endgroup

  covergroup dependency_addr_cg;
    coverpoint dependency_addr {
      bins addrs = {16'h0, 16'h4, 16'h8, 16'hC};
    }
  endgroup

  covergroup reg_raw_gap_cg;
    coverpoint reg_raw_gap {
      bins reg_raw_gaps = {[1:4]}; // reg: read after write gaps
    }
  endgroup

  covergroup reg_waw_gap_cg;
    coverpoint reg_waw_gap {
      bins reg_waw_gaps = {[1:4]}; // reg: write after write gaps
    }
  endgroup 

  covergroup mem_raw_gap_cg;
    coverpoint mem_raw_gap {
      bins mem_raw_gaps = {[1:4]}; // mem: read after write gaps
    }
  endgroup

  covergroup mem_waw_gap_cg;
    coverpoint mem_waw_gap {
      bins mem_waw_gaps = {[1:4]}; // mem: write after write gaps
    }
  endgroup

  function new(string name, uvm_component parent);
    super.new(name, parent);
    instr_fields_cg = new();
    instr_branch_cg = new();
    instr_order_cg = new();
    reg_raw_gap_cg = new();
    reg_waw_gap_cg = new();
    mem_raw_gap_cg = new();
    mem_waw_gap_cg = new();
    dependency_reg_cg = new();
    dependency_addr_cg = new();
    regs_written = '{default:0};
    addr_written = '{default:0};
    reg_gap = '{default:0};
    mem_gap = '{default:0};
    reg_raw_gap = 0;
    reg_waw_gap = 0;
    mem_raw_gap = 0;
    mem_waw_gap = 0;
    dependency_reg = 0;
    dependency_addr = 0;
  endfunction

  function void write(instruction t);

    instr = t;

    branch_taken = instr.branch && instr.equal;
    if (instr.branch) begin
      instr_branch_cg.sample();
    end

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
      if (instr_type == 1 || instr_type == 2) begin // Rtype: write reg is rd, read reg is rs and rt
        if (regs_written[instr.rd - 1]) begin
          reg_waw_gap = reg_gap[instr.rd - 1]; // save the gap of the rd register for sampling
          reg_waw_gap_cg.sample();
          dependency_reg = instr.rd;
          dependency_reg_cg.sample();
        end

        if (regs_written[instr.rs - 1]) begin
          reg_raw_gap = reg_gap[instr.rs - 1]; // save the gap of the rs register for sampling
          reg_raw_gap_cg.sample();
          dependency_reg = instr.rs;
          dependency_reg_cg.sample();
        end

        if (regs_written[instr.rt - 1]) begin
          reg_raw_gap = reg_gap[instr.rt - 1]; // save the gap of the rt register for sampling
          reg_raw_gap_cg.sample();
          dependency_reg = instr.rt;
          dependency_reg_cg.sample();
        end

        regs_written[instr.rd - 1] = 1; // mark that the rd register has been written to

        reg_gap[0] = (instr.rd == 1) ? 0 : reg_gap[0] + 1;  // if the write reg is 1, reset the count, otherwise increment
        reg_gap[1] = (instr.rd == 2) ? 0 : reg_gap[1] + 1;  // if the write reg is 2, reset the count, otherwise increment  
        reg_gap[2] = (instr.rd == 3) ? 0 : reg_gap[2] + 1;  // if the write reg is 3, reset the count, otherwise increment
        reg_gap[3] = (instr.rd == 4) ? 0 : reg_gap[3] + 1;  // if the write reg is 4, reset the count, otherwise increment

        mem_gap[0] = mem_gap[0] + 1;  // increment memory address gap
        mem_gap[1] = mem_gap[1] + 1;  // increment memory address gap
        mem_gap[2] = mem_gap[2] + 1;  // increment memory address gap
        mem_gap[3] = mem_gap[3] + 1;  // increment memory address gap
      end
      else if (instr_type == 3) begin // LW: write reg is rt, read reg is rs
        if (regs_written[instr.rt - 1]) begin
          reg_waw_gap = reg_gap[instr.rt - 1]; // save the gap of the rt register for sampling
          reg_waw_gap_cg.sample();
          dependency_reg = instr.rt;
          dependency_reg_cg.sample();
        end

        if (regs_written[instr.rs - 1]) begin
          reg_raw_gap = reg_gap[instr.rs - 1]; // save the gap of the rs register for sampling
          reg_raw_gap_cg.sample();
          dependency_reg = instr.rs;
          dependency_reg_cg.sample();
        end

        if (addr_written[instr.imm / 4]) begin
          mem_raw_gap = mem_gap[instr.imm / 4]; // save the gap of the memory address for sampling
          mem_raw_gap_cg.sample();
          dependency_addr = instr.imm;
          dependency_addr_cg.sample();
        end

        regs_written[instr.rt - 1] = 1; // mark that the rt register has been written to

        reg_gap[0] = (instr.rt == 1) ? 0 : reg_gap[0] + 1;  // if the write reg is 1, reset the count, otherwise increment
        reg_gap[1] = (instr.rt == 2) ? 0 : reg_gap[1] + 1;  // if the write reg is 2, reset the count, otherwise increment  
        reg_gap[2] = (instr.rt == 3) ? 0 : reg_gap[2] + 1;  // if the write reg is 3, reset the count, otherwise increment
        reg_gap[3] = (instr.rt == 4) ? 0 : reg_gap[3] + 1;  // if the write reg is 4, reset the count, otherwise increment

        mem_gap[0] = mem_gap[0] + 1;  // increment memory address gap
        mem_gap[1] = mem_gap[1] + 1;  // increment memory address gap
        mem_gap[2] = mem_gap[2] + 1;  // increment memory address gap
        mem_gap[3] = mem_gap[3] + 1;  // increment memory address gap
      end
      else if (instr_type == 4) begin // SW: no write reg, read reg is rt and rs
        if (regs_written[instr.rs - 1]) begin
          reg_raw_gap = reg_gap[instr.rs - 1]; // save the gap of the rs register for sampling
          reg_raw_gap_cg.sample();
          dependency_reg = instr.rs;
          dependency_reg_cg.sample();
        end

        if (regs_written[instr.rt - 1]) begin
          reg_raw_gap = reg_gap[instr.rt - 1]; // save the gap of the rt register for sampling
          reg_raw_gap_cg.sample();
          dependency_reg = instr.rt;
          dependency_reg_cg.sample();
        end
        
        if (addr_written[instr.imm / 4]) begin
          mem_waw_gap = mem_gap[instr.imm / 4]; // save the gap of the memory address for sampling
          mem_waw_gap_cg.sample();
          dependency_addr = instr.imm;
          dependency_addr_cg.sample();
        end

        addr_written[instr.imm / 4] = 1; // mark that this address has been written to

        reg_gap[0] = reg_gap[0] + 1;  // if the write reg is 1, reset the count, otherwise increment
        reg_gap[1] = reg_gap[1] + 1;  // if the write reg is 2, reset the count, otherwise increment  
        reg_gap[2] = reg_gap[2] + 1;  // if the write reg is 3, reset the count, otherwise increment
        reg_gap[3] = reg_gap[3] + 1;  // if the write reg is 4, reset the count, otherwise increment

        mem_gap[0] = (instr.imm == 16'h0) ? 0 : mem_gap[0] + 1;  // if the memory address is 0, reset the count, otherwise increment
        mem_gap[1] = (instr.imm == 16'h4) ? 0 : mem_gap[1] + 1;  // if the memory address is 4, reset the count, otherwise increment  
        mem_gap[2] = (instr.imm == 16'h8) ? 0 : mem_gap[2] + 1;  // if the memory address is 8, reset the count, otherwise increment
        mem_gap[3] = (instr.imm == 16'hC) ? 0 : mem_gap[3] + 1;  // if the memory address is C, reset the count, otherwise increment
      end
      else if (instr_type == 5) begin // BEQ: no write reg, read reg is rt and rs
        if (regs_written[instr.rs - 1]) begin
          reg_raw_gap = reg_gap[instr.rs - 1]; // save the gap of the rs register for sampling
          reg_raw_gap_cg.sample();
          dependency_reg = instr.rs;
          dependency_reg_cg.sample();
        end

        if (regs_written[instr.rt - 1]) begin
          reg_raw_gap = reg_gap[instr.rt - 1]; // save the gap of the rt register for sampling
          reg_raw_gap_cg.sample();
          dependency_reg = instr.rt;
          dependency_reg_cg.sample();
        end

        reg_gap[0] = reg_gap[0] + 1;  // if the write reg is 1, reset the count, otherwise increment
        reg_gap[1] = reg_gap[1] + 1;  // if the write reg is 2, reset the count, otherwise increment  
        reg_gap[2] = reg_gap[2] + 1;  // if the write reg is 3, reset the count, otherwise increment
        reg_gap[3] = reg_gap[3] + 1;  // if the write reg is 4, reset the count, otherwise increment
        
        mem_gap[0] = mem_gap[0] + 1;  // increment memory address gap
        mem_gap[1] = mem_gap[1] + 1;  // increment memory address gap
        mem_gap[2] = mem_gap[2] + 1;  // increment memory address gap
        mem_gap[3] = mem_gap[3] + 1;  // increment memory address gap
      end
      else begin // no write reg or memory write
        reg_gap[0] = reg_gap[0] + 1;  // no write reg, increment
        reg_gap[1] = reg_gap[1] + 1;  // no write reg, increment  
        reg_gap[2] = reg_gap[2] + 1;  // no write reg, increment
        reg_gap[3] = reg_gap[3] + 1;  // no write reg, increment
        
        mem_gap[0] = mem_gap[0] + 1;  // increment memory address gap
        mem_gap[1] = mem_gap[1] + 1;  // increment memory address gap
        mem_gap[2] = mem_gap[2] + 1;  // increment memory address gap
        mem_gap[3] = mem_gap[3] + 1;  // increment memory address gap
      end

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
    mon = instr_monitor::type_id::create("instr_monitor", this);
    cov = instr_coverage::type_id::create("instr_coverage", this);
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    mon.ap.connect(cov.analysis_export);
  endfunction
endclass

class my_test extends uvm_test;

    instr_env env;
    virtual instr_mem_if vif;

    `uvm_component_utils(my_test)

    function new (string name = "my_test", uvm_component parent = null);
      super.new (name, parent);
    endfunction

    function void build_phase (uvm_phase phase);
        super.build_phase (phase);
        env  = instr_env::type_id::create ("instr_env", this);
        if (!uvm_resource_db #(virtual instr_mem_if)::read_by_name("uvm_test_top", "instr_mem_if_ptr", vif, this))
          `uvm_fatal(get_type_name(), "Failed to get virtual interface")
    endfunction

    task run_phase(uvm_phase phase);
        phase.raise_objection(this);

	wait(vif.reset == 0);
        wait(vif.program_done == 1);

        // Allow final monitor/coverage activity to settle
        @(posedge vif.clk);

        phase.drop_objection(this);
    endtask
endclass

module tb;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  instruction_generator #(
    .TRICKBOX_REG(5'd5),
    .TRICKBOX_VALUE(16'h0DED),
    .TRICKBOX_MEM_ADDR(16'h0040)
  ) gen;
  bit [31:0] machine_code_list[];


  instr_mem_if instr_mem_if();
  logic [31:0] writedata, dataadr;
  logic memwrite;

  top dut (
    .clk(instr_mem_if.clk),
    .reset(instr_mem_if.reset),
    .writedata(writedata),
    .dataadr(dataadr),
    .memwrite(memwrite)
  );

  assign instr_mem_if.instr = dut.mips.instr;      // instruction from fetch
  assign instr_mem_if.branch = dut.mips.branch;    // branch instruction
  assign instr_mem_if.equal = dut.mips.dp.equalD;  // registers equal taken

  initial begin
    instr_mem_if.clk = 0;
    forever #5 instr_mem_if.clk = ~instr_mem_if.clk; // 100MHz clock
  end

  initial begin
    instr_mem_if.program_done = 0;
    // Wait until the trickbox value is stored in memory before finishing the simulation
    wait (dut.dmem.RAM[16'h0040 >> 2] == 32'h0000_0DED)
    instr_mem_if.program_done = 1;
  end

  initial begin
    instr_mem_if.reset = 1;

    gen = new();
    gen.generate_machine_code();
    gen.display_all();
    machine_code_list = new[gen.machine_code_list.size()];

    // Load the generated instructions after imem's initialization block has
    // completed. Writing memfile.dat alone cannot update an already-loaded
    // memory array.
    #1;
    $readmemh("instr_gen_mem.dat", machine_code_list);
    $writememh("../rtl/memfile.dat", machine_code_list);
    $readmemh("../rtl/memfile.dat", dut.imem.RAM);

    repeat (2) @(posedge instr_mem_if.clk);
    instr_mem_if.reset = 0;
  end

  initial begin
    uvm_resource_db #(virtual instr_mem_if)::set(
        "*",
        "instr_mem_if_ptr",
        instr_mem_if
    );

    run_test("my_test");
    $finish;
  end

  initial begin
    $fsdbDumpfile("novas.fsdb");
    $fsdbDumpvars(0, tb);
    $fsdbDumpMDA(tb.dut.dmem.RAM);
    $fsdbDumpMDA(tb.dut.mips.dp.rf);
  end
endmodule
