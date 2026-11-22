# cse598addv
Repo for CSE598: ADDV

# LAB5 PART2: Constrained-random instruction generator

# Setup
1. Swap to tcsh
   %tcsh
2. Swap to lab directory
   %cd LAB5/PART2
3. Source env for Synopsys tools
   % source env.cshrc

# Files
- `tb/instr_gen.sv`: the instruction generator and the testbench top module
  - `instruction` class (extends `uvm_transaction`): rand fields for opcode, funct, rs, rt, rd, imm, with constraints for ADD, AND, LW, SW and BEQ
  - `instruction_generator` class: builds the instruction stream (setup, random individual and paired instructions, random gaps, padding, end-of-simulation store) in a dynamic array and converts it to machine code
  - `instr_gen` module: clock/reset, DUT instance, loads the program into instruction memory, ends the simulation, dumps waves
- `sim/Makefile`: compile and run commands
- `project.f`: file list used by the Makefile
- `rtl/`: the pipelined MIPS processor

# Sim
First,
   %cd LAB5/PART2
1. To compile, run simulation, and open Verdi waveforms:
   % cd sim
   % make run
2. To only compile (UVM 1.2 enabled):
   % make compile_uvm
3. To only run the simulation (after compiling):
   % make sim
4. To open Verdi with the waveforms from the last run:
   % make waves_verdi

# Output
- The generated program is printed to the terminal as assembly (`display_all`).
- `instr_gen_mem.dat`: machine code written by the generator.
- `../rtl/memfile.dat`: the same machine code, loaded into the processor's instruction memory.
- `novas.fsdb`: waveform database opened by Verdi.
- Each run generates a different program unless the seed is fixed. To fix it:
   % ./simv +ntb_random_seed=<value>

# End of simulation
The last instruction of every program is `SW $5, 0x40($0)`, storing `0x0DED` to data memory address `0x40`. The testbench watches that location (`dut.dmem.RAM[16]`) and calls `$finish` when it sees the value.

# Clean
   % make clean