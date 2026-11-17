// Add -ntb_opts uvm to the VCS command line.
import uvm_pkg::*;

typedef enum bit [2:0] { ADD, AND, ADDI, LW, SW, BEQ } opcode_t;

class instruction extends uvm_transaction;
  rand opcode_t opcode;
  rand bit [4:0] rs, rt, rd;
  rand bit [15:0] imm;

  function new(string name = "instruction");
    super.new(name);
  endfunction

  constraint valid_opcode {
    opcode inside {ADD, AND, ADDI, LW, SW, BEQ};
  }

  constraint valid_regs {
    if ((opcode == ADD) || (opcode == AND)) {
      rs inside {[0:4]};
      rt inside {[0:4]};
      rd inside {[1:4]};
    }
    else if (opcode == ADDI) {
      rs inside {[0:4]};
      rt inside {[1:4]};
      rd == 0;            // not used for this instruction
    }
    else if (opcode == LW) {
      rs inside {[0:4]};
      rt inside {[1:4]};
      rd == 0;            // not used for this instruction
    }
    else if ((opcode == SW) || (opcode == BEQ)) {
      rs inside {[0:4]};
      rt inside {[0:4]};
      rd == 0;            // not used for these instructions
    }
  }

  constraint valid_imm {
    if ((opcode == ADD) || (opcode == AND)) {
      imm == 16'h0000; // not used for these instructions
    }
    else if ((opcode == LW) || (opcode == SW)) {
      imm inside {16'h0000, 16'h0004, 16'h0008, 16'h000C};
    }
    else if (opcode == ADDI) {
      imm inside {[16'h0000:16'h000F]};
    }
    else if (opcode == BEQ) {
      imm inside {16'd1, 16'd2, 16'd3, 16'd4};
    }
  }

  function void print_me();
    case (opcode)
      ADD: $display("ADD $%0d, $%0d, $%0d", rd, rs, rt);
      AND: $display("AND $%0d, $%0d, $%0d", rd, rs, rt);
      ADDI: $display("ADDI $%0d, $%0d, 0x%0d", rt, rs, imm);
      LW:  $display("LW $%0d, 0x%0h($%0d)", rt, imm, rs);
      SW:  $display("SW $%0d, 0x%0h($%0d)", rt, imm, rs);
      BEQ: $display("BEQ $%0d, $%0d, %0d", rs, rt, imm);
    endcase
  endfunction
endclass

class instruction_generator;
  instruction instr_list[];
  bit [31:0] machine_code_list[];

  function void append_instruction(instruction instr);
    instr_list = new[instr_list.size() + 1] (instr_list);
    instr_list[instr_list.size() - 1] = instr;

    case (instr.opcode)
      ADD: $display("\t\tADD $%0d, $%0d, $%0d", instr.rd, instr.rs, instr.rt);
      AND: $display("\t\tAND $%0d, $%0d, $%0d", instr.rd, instr.rs, instr.rt);
      ADDI: $display("\t\tADDI $%0d, $%0d, 0x%0d", instr.rt, instr.rs, instr.imm);
      LW:  $display("\t\tLW $%0d, 0x%0h($%0d)", instr.rt, instr.imm, instr.rs);
      SW:  $display("\t\tSW $%0d, 0x%0h($%0d)", instr.rt, instr.imm, instr.rs);
      BEQ: $display("\t\tBEQ $%0d, $%0d, %0d", instr.rs, instr.rt, instr.imm);
    endcase
  endfunction

  function void generate_individual();
    instruction instr = new();

    $display("\t\tGenerating individual instruction:");
    randcase
      4: begin
        assert(instr.randomize() with {opcode inside {ADD, AND, LW, SW}; });
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

    $display("\t\tGenerating instruction pair:");
    randcase
      // AND/ADD -> AND/ADD/BEQ: the consumer reads txn1.rd.
      1: begin
        assert(txn1.randomize() with {
          opcode inside {ADD, AND};
        });
        assert(txn2.randomize() with {
          opcode inside {ADD, AND, BEQ};
          (rs == txn1.rd) || (rt == txn1.rd);
        });

        append_instruction(txn1);
        insert_gaps(-1, txn1.rd);
        append_instruction(txn2);
      end

      // ADD/AND -> LW/SW: the consumer uses txn1.rd as its base register.
      1: begin
        assert(txn1.randomize() with {
          opcode inside {ADD, AND};
        });
        assert(txn2.randomize() with {
          opcode inside {LW, SW};
          rs == txn1.rd;
        });
        append_instruction(txn1);
        insert_gaps(-1, txn1.rd);
        append_instruction(txn2);
      end

      // LW -> ADD/AND/BEQ: the consumer reads the register loaded by txn1.
      1: begin
        assert(txn1.randomize() with {
          opcode == LW;
        });
        assert(txn2.randomize() with {
          opcode inside {ADD, AND, BEQ};
          (rs == txn1.rt) || (rt == txn1.rt);
        });
        append_instruction(txn1);
        insert_gaps(-1, txn1.rt);
        append_instruction(txn2);
      end

      // LW -> LW/SW: the consumer uses txn1.rt as its base register.
      1: begin
        assert(txn1.randomize() with {
          opcode == LW;
        });
        assert(txn2.randomize() with {
          opcode inside {LW, SW};
          rs == txn1.rt;
        });
        append_instruction(txn1);
        insert_gaps(-1, txn1.rt);
        append_instruction(txn2);
      end
    endcase
    $display("\t\tDone generating instruction pair.");
  endfunction

  function void insert_gaps(int gap_size = -1, int avoid_reg = -1);
    int num_gaps;

    if (gap_size == -1)
      num_gaps = $urandom_range(1, 4);
    else if (gap_size >= 0)
      num_gaps = gap_size;
    else
      $fatal(1, "Gap size must be non-negative");

    $display("\t\tInserting %0d gap(s) into instruction sequence.", num_gaps);
    instr_list = new[instr_list.size() + num_gaps] (instr_list);
    for (int i = 0; i < num_gaps; i++) begin
      instruction gap_instr = new();
      if (avoid_reg != -1) begin
        assert(gap_instr.randomize() with {
          opcode inside {ADD, AND, LW, SW};
          (rs != avoid_reg) && (rt != avoid_reg) && (rd != avoid_reg);
        });
      end
      else begin
        assert(gap_instr.randomize() with {opcode inside {ADD, AND, LW, SW}; });
      end

      instr_list[instr_list.size() - num_gaps + i] = gap_instr;
      case (gap_instr.opcode)
        ADD: $display("\t\tADD $%0d, $%0d, $%0d", gap_instr.rd, gap_instr.rs, gap_instr.rt);
        AND: $display("\t\tAND $%0d, $%0d, $%0d", gap_instr.rd, gap_instr.rs, gap_instr.rt);
        LW:  $display("\t\tLW $%0d, 0x%0h($%0d)", gap_instr.rt, gap_instr.imm, gap_instr.rs);
        SW:  $display("\t\tSW $%0d, 0x%0h($%0d)", gap_instr.rt, gap_instr.imm, gap_instr.rs);
        BEQ: $display("\t\tBEQ $%0d, $%0d, %0d", gap_instr.rs, gap_instr.rt, gap_instr.imm);
      endcase
    end
    $display("\t\tDone inserting gap(s) into instruction sequence.");
  endfunction

  function void generate_sequence();
    integer num_instr = $urandom_range(5, 8);
    instr_list = new[0];

    $display("Generating a sequence of %0d instructions.", num_instr);
    $display("\tInitializing registers.");
    for (int i = 1; i <= 4; i++) begin
      instruction init_reg_instr = new();
      assert(init_reg_instr.randomize() with {
        opcode == ADDI;
        rs == 0;
        rt == i;
      });
      append_instruction(init_reg_instr);
    end

    $display("\tInitializing memory.");
    for (int i = 0; i < 4; i++) begin
      instruction init_mem_instr = new();
      assert(init_mem_instr.randomize() with {
        opcode == SW;
        rs == 0;
        rt inside {[0:4]};
        imm == (i * 16'h0004);
      });
      append_instruction(init_mem_instr);
    end

    $display("\tGenerating instruction sequence.");
    // Generate a sequence of instructions with a mix of individual and paired instructions.
    for (int i = 0; i < num_instr; i++) begin
      randcase
        1: generate_individual();
        1: generate_pairs();
      endcase
    end

    $display("\tInserting gaps.");
    // Pad the sequence with five instructions to cover the maximum branch
    // offset when a branch is placed at the end of the sequence.
    insert_gaps(5);
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
        ADD: machine_code = {6'b000000, instr.rs, instr.rt, instr.rd, 5'b00000, 6'b100000};
        AND: machine_code = {6'b000000, instr.rs, instr.rt, instr.rd, 5'b00000, 6'b100100};
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

  instruction_generator gen;
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
    $readmemh("../rtl/memfile.dat", dut.imem.mem);

    repeat (2) @(posedge clk);
    reset = 0;

    repeat (gen.instr_list.size() + 5) @(posedge clk);
    $finish;
  end
endmodule