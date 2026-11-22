// Add -ntb_opts uvm to the VCS command line.
import uvm_pkg::*;

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

class instruction extends uvm_transaction;
  rand opcode_t opcode;
  rand bit [4:0] rs, rt, rd;
  rand bit [15:0] imm;
  rand funct_t funct;
  bit branch;
  bit equal;

  function new(string name = "instruction");
    super.new(name);
  endfunction

  constraint valid_opcode {
    opcode inside {RTYPE, ADDI, LW, SW, BEQ};
  }

  constraint valid_funct {
    if (opcode == RTYPE) {
      funct inside {ADD, AND};
    }
    else {
      funct == NO_FUNCT; // not used for these instructions
    }
  }

  constraint valid_regs {
    if (opcode == RTYPE) {
      rs inside {[1:4]};
      rt inside {[1:4]};
      rd inside {[1:4]};
    }
    else if (opcode == ADDI) {
      rs == 0;            // ADDI is only used to initialize registers, so rs is always $0
      rt inside {[1:4]};
      rd == 0;            // not used for this instruction
    }
    else if ((opcode == LW) || (opcode == SW)) {
      rs == 0;            // base register is always $0 for this assignment
      rt inside {[1:4]};
      rd == 0;            // not used for this instruction
    }
    else if (opcode == BEQ) {
      rs inside {[1:4]};
      rt inside {[1:4]};
      rd == 0;            // not used for these instructions
    }
  }

  constraint valid_imm {
    if (opcode == RTYPE) {
      imm == 16'h0000;    // not used for these instructions
    }
    else if ((opcode == LW) || (opcode == SW)) {
      imm inside {16'h0000, 16'h0004, 16'h0008, 16'h000C};
    }
    else if (opcode == ADDI) {
      imm inside {[16'h0000:16'hFFFF]};
    }
    else if (opcode == BEQ) {
      imm inside {16'd1, 16'd2, 16'd3, 16'd4};
    }
  }

  function void print_me();
    case (opcode)
      RTYPE: begin
        if (funct == ADD)
          $display("ADD $%0d, $%0d, $%0d", rd, rs, rt);
        else if (funct == AND)
          $display("AND $%0d, $%0d, $%0d", rd, rs, rt);
      end
      ADDI: $display("ADDI $%0d, $%0d, %0d", rt, rs, imm);
      LW:  $display("LW $%0d, 0x%0h($%0d)", rt, imm, rs);
      SW:  $display("SW $%0d, 0x%0h($%0d)", rt, imm, rs);
      BEQ: $display("BEQ $%0d, $%0d, %0d", rs, rt, imm);
    endcase
  endfunction
endclass

class instruction_generator #(
  parameter bit [4:0] TRICKBOX_REG = 5'd5,
  parameter bit [15:0] TRICKBOX_VALUE = 16'h0DED,
  parameter bit [15:0] TRICKBOX_MEM_ADDR = 16'h0040
);
  instruction instr_list[];
  bit [31:0] machine_code_list[];

  function void append_instruction(instruction instr);
    instr_list = new[instr_list.size() + 1] (instr_list);
    instr_list[instr_list.size() - 1] = instr;
  endfunction

  function void generate_setup();
    // Initialize registers $1-$4 to known values using ADDI instructions
    for (int i = 1; i <= 4; i++) begin
      instruction init_reg_instr = new();
      assert(init_reg_instr.randomize() with {
        opcode == ADDI;
        rt == i;
      });
      append_instruction(init_reg_instr);
    end

    // Initialize memory locations 0x0000, 0x0004, 0x0008, and 0x000C using SW instructions
    for (int i = 0; i < 4; i++) begin
      instruction init_mem_instr = new();
      assert(init_mem_instr.randomize() with {
        opcode == SW;
        rt inside {[0:4]};
        imm == (i * 16'h0004);
      });
      append_instruction(init_mem_instr);
    end
  endfunction

  function void generate_trickbox_setup();
    // Load a value into register $5 using an ADDI instruction
    instruction trickbox_addi_instr = new();
    instruction trickbox_store_instr = new();

    trickbox_addi_instr.opcode = ADDI;
    trickbox_addi_instr.rt = TRICKBOX_REG;
    trickbox_addi_instr.imm = TRICKBOX_VALUE;
    append_instruction(trickbox_addi_instr);
  endfunction

  function void generate_trickbox_store();
    // Store the value from register $5 into memory address 0x40 using an SW instruction
    instruction trickbox_store_instr = new();

    trickbox_store_instr.opcode = SW;
    trickbox_store_instr.rs = 0;
    trickbox_store_instr.rt = TRICKBOX_REG;
    trickbox_store_instr.imm = TRICKBOX_MEM_ADDR;
    append_instruction(trickbox_store_instr);
  endfunction

  function void generate_individual();
    instruction instr = new();

    randcase
      2: begin
        assert(instr.randomize() with {opcode == RTYPE;});
        append_instruction(instr);
      end
      2: begin
        assert(instr.randomize() with {opcode inside {LW, SW}; });
        append_instruction(instr);
      end

      1: begin
        assert(instr.randomize() with {opcode == BEQ; rs == rt;});
        append_instruction(instr);
      end

      1: begin
        assert(instr.randomize() with {opcode == BEQ; rs != rt;});
        append_instruction(instr);
      end
    endcase
  endfunction

  function void generate_pairs();
    instruction txn1 = new();
    instruction txn2 = new();

    randcase
      // RTYPE -> RTYPE/BEQ: txn2 reads txn1.rd (register dependency).
      1: begin
        assert(txn1.randomize() with {
          opcode == RTYPE;
        });
        assert(txn2.randomize() with {
          opcode inside {RTYPE, BEQ};
          (rs == txn1.rd) || (rt == txn1.rd);
        });

        append_instruction(txn1);
        insert_gaps(.avoid_reg(txn1.rd));
        append_instruction(txn2);
      end

      // RTYPE -> SW: txn2 uses txn1.rd as its target register (register dependency).
      1: begin
        assert(txn1.randomize() with {
          opcode == RTYPE;
        });
        assert(txn2.randomize() with {
          opcode == SW;
          rt == txn1.rd;
        });
        append_instruction(txn1);
        insert_gaps(.avoid_reg(txn1.rd));
        append_instruction(txn2);
      end

      // LW -> RTYPE/BEQ: txn2 reads the register loaded by txn1 (register dependency).
      1: begin
        assert(txn1.randomize() with {
          opcode == LW;
        });
        assert(txn2.randomize() with {
          opcode inside {RTYPE, BEQ};
          (rs == txn1.rt) || (rt == txn1.rt);
        });
        append_instruction(txn1);
        insert_gaps(.avoid_reg(txn1.rt));
        append_instruction(txn2);
      end

      // LW -> SW: txn2 uses txn1.rt as its target register (register dependency).
      1: begin
        assert(txn1.randomize() with {
          opcode == LW;
        });
        assert(txn2.randomize() with {
          opcode == SW;
          rt == txn1.rt;
        });
        append_instruction(txn1);
        insert_gaps(.avoid_reg(txn1.rt));
        append_instruction(txn2);
      end

      // LW/SW -> LW/SW: txn2 accesses the same memory location as txn1 (memory dependency).
      1: begin
        assert(txn1.randomize() with {
          opcode inside {LW, SW};
        });
        assert(txn2.randomize() with {
          opcode inside {LW, SW};
          imm == txn1.imm;
        });
        append_instruction(txn1);
        insert_gaps(.avoid_mem(txn1.imm));
        append_instruction(txn2);
      end

    endcase
  endfunction

  function void insert_gaps(int gap_size = -1, int avoid_reg = -1, int avoid_mem = -1);
    int num_gaps;
    instruction gap_instr;

    if (gap_size == -1)
      num_gaps = $urandom_range(1, 4);
    else if (gap_size >= 0)
      num_gaps = gap_size;
    else
      $fatal(1, "Gap size must be non-negative");

    for (int i = 0; i < num_gaps; i++) begin
      gap_instr = new();
      assert(gap_instr.randomize() with {
        opcode inside {RTYPE, LW, SW};
        if (avoid_reg != -1) {
          rs != avoid_reg;
          rt != avoid_reg;
          rd != avoid_reg;
        }
        if (avoid_mem != -1) {
          (opcode inside {LW, SW}) -> (imm != avoid_mem);
        }
      });

      append_instruction(gap_instr);
    end
  endfunction

  function void generate_sequence();
    integer num_instr = $urandom_range(5, 8);
    instr_list = new[0];

    // Setup the initial instructions to initialize registers and memory
    generate_setup();

    // Setup the trick-box by loading a value into the trickbox register
    generate_trickbox_setup();

    // Generate a sequence of instructions with a mix of individual and paired instructions.
    for (int i = 0; i < num_instr; i++) begin
      if ($urandom_range(1, 0) == 0)
        generate_individual();
      else
        generate_pairs();
    end

    // Pad the sequence with four instructions to cover the maximum branch minus 1
    insert_gaps(.gap_size(4));

    // Store the trickbox value into the trickbox memory address
    generate_trickbox_store();
  endfunction

  function void generate_machine_code();
    generate_sequence();

    machine_code_list = new[instr_list.size()];
    for (int i = 0; i < instr_list.size(); i++) begin
      instruction instr = instr_list[i];
      bit [31:0] machine_code;

      case (instr.opcode)
        // R-type instruction format: opcode (6 bits), rs (5 bits), rt (5 bits), rd (5 bits), shamt (5 bits), funct (6 bits)
        // I-type instruction format: opcode (6 bits), rs (5 bits), rt (5 bits), immediate (16 bits)
        RTYPE: machine_code = {6'b000000, instr.rs, instr.rt, instr.rd, 5'b00000, instr.funct};
        ADDI: machine_code = {6'b001000, instr.rs, instr.rt, instr.imm};
        LW:  machine_code = {6'b100011, instr.rs, instr.rt, instr.imm};
        SW:  machine_code = {6'b101011, instr.rs, instr.rt, instr.imm};
        BEQ: machine_code = {6'b000100, instr.rs, instr.rt, instr.imm};
      endcase

      machine_code_list[i] = machine_code;
    end

    $writememh("instr_gen_mem.dat", machine_code_list);
  endfunction

  function void display_all();
    for (int i = 0; i < instr_list.size(); i++) begin
      instr_list[i].print_me();
    end
  endfunction
endclass

module instr_gen;
  timeunit 1ns;
  timeprecision 1ps;

  instruction_generator #(
    .TRICKBOX_REG(5'd5),
    .TRICKBOX_VALUE(16'h0DED),
    .TRICKBOX_MEM_ADDR(16'h0040)
  ) gen;
  bit [31:0] machine_code_list[];

  logic clk, reset;
  logic [31:0] writedata, dataadr;
  logic memwrite;

  top dut (
    .clk(clk),
    .reset(reset),
    .writedata(writedata),
    .dataadr(dataadr),
    .memwrite(memwrite)
  );

  initial begin
    clk = 0;
    forever #5 clk = ~clk; // 100MHz clock
  end

  initial begin
    reset = 1;

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

    repeat (2) @(posedge clk);
    reset = 0;

    // Wait until the trickbox value is stored in memory before finishing the simulation
    while (dut.dmem.RAM[16'h0040 >> 2] !== 32'h0000_0DED)
      @(posedge clk);

    $finish;
  end

  initial begin
    $fsdbDumpfile("novas.fsdb");
    $fsdbDumpvars(0, instr_gen);
    $fsdbDumpMDA(instr_gen.dut.dmem.RAM);
    $fsdbDumpMDA(instr_gen.dut.mips.dp.rf);
  end
endmodule