# cse598addv
Repo for CSE598: ADDV

# LAB5 PART4: Code coverage

# Setup
1. Swap to tcsh
   %tcsh
2. Swap to lab directory
   %cd LAB5/PART4
3. Source env for Synopsys tools
   % source env.cshrc

# Files
- `sim/Makefile`: compile with coverage, run single or multiple simulations, merge, view
- `sim/cov_hier.cfg`: limits code coverage to the processor (`+tree instr_gen.dut`), so testbench code is not counted
- `tb/instr_gen.sv`: same instruction generator and testbench as PART2 (no UVM test is used)
- `project.f`: file list used by the Makefile
- `rtl/`: the pipelined MIPS processor

Code coverage metrics enabled: line, condition, FSM, toggle (`-cm line+cond+fsm+tgl`).
The FSM metric is empty because the design has no FSM; Verdi and urg print a "Shape Not Found" warning for it.

# Initial coverage report (one run)
First,
   %cd LAB5/PART4/sim
1. Compile with coverage enabled:
   % make comp
2. Run one simulation (seed 1) into `simv.vdb`:
   % make run
3. Open the coverage report in Verdi:
   % make cov
To use a different seed: `make run SEED=<value>`

# Multiple runs and merged coverage
1. Run N more tests:
   % make batch K=10
   Each test uses the next number in `.run_counter` as its seed, so no two runs repeat. Results are saved in `cov_runs/`:
   - `run_<n>.vdb`: coverage database
   - `run_<n>.log`: simulation log (includes the generated program)
   - `run_<n>.dat`: generated machine code
   To run a single extra test: `make next`
2. Merge all runs and generate the report:
   % make merge
   Output: `cov_merged/merged.vdb` and `cov_merged/urgReport/`
3. Open the merged report in Verdi:
   % make cov_merged
Repeat steps 1 and 2 until the merged coverage stops improving.

`make merge` reads the design information from `simv.vdb`, so run `make comp` and `make run` before the first merge, and do not run `make clean` in between.

# Other
- To open the waveforms from the last single run:
   % make waves

# Clean
- Remove build products and the single-run database (keeps `cov_runs/` and the seed counter):
   % make clean
- Remove all multi-run results and restart the seed counter:
   % make clean_runs
After changing `instr_gen.sv` or the RTL, run `make clean`, `make clean_runs`, and `make comp` so old runs are not mixed with new code.
