# ---- Settings (override on the command line, e.g. make run SEED=7) ----
SEED       = 1
COV_DIR    = simv.vdb             # coverage database for a single "make run"
CODE_COV   = line+cond+fsm+tgl    # code coverage metrics (Part 4)

# ---- Multi-run settings ----
RUN_DIR    = cov_runs             # one coverage db, log and program per run
COUNTER    = .run_counter         # persists the last run number (= seed) used
MERGED     = cov_merged
K          = 10                   # runs per "make batch"

# ---- Compile: RTL + instr_gen.sv (listed in ../project.f) ----
# -ntb_opts uvm-1.2 is still required because instr_gen.sv does
# "import uvm_pkg::*" and the instruction class extends uvm_transaction.
VCS = $(VCS_HOME)/bin/vcs -full64 -sverilog -timescale=1ns/1ps \
      -f ../project.f -ntb_opts uvm-1.2 +incdir+$(VCS_HOME)/etc/uvm-1.2/src \
      -debug_access+all -kdb -lca \
      -cm $(CODE_COV) -cm_hier cov_hier.cfg -l comp.log

# ---- Single simulation: same -cm metrics, coverage dir and seed ----
SIMV = ./simv +ntb_random_seed=$(SEED) \
       -cm $(CODE_COV) -cm_dir $(COV_DIR) -l sim.log

comp:
	$(VCS)

run:
	$(SIMV)

# Compile and simulate in one step
all: comp run

# ---- Multi-run flow ----
# Each call increments .run_counter and uses that number as the seed, so no
# two runs can share a seed. Saves the coverage db, log, and the generated
# program (instr_gen_mem.dat) as cov_runs/run_<n>.*
next:
	@mkdir -p $(RUN_DIR)
	@n=$$(cat $(COUNTER) 2>/dev/null || echo 0); n=$$((n+1)); echo $$n > $(COUNTER); \
	echo "=== Run $$n (seed $$n) ==="; \
	./simv +ntb_random_seed=$$n -cm $(CODE_COV) -cm_dir $(RUN_DIR)/run_$$n.vdb \
	       -l $(RUN_DIR)/run_$$n.log; \
	cp instr_gen_mem.dat $(RUN_DIR)/run_$$n.dat

# Run K more tests in a row (make batch K=20)
batch:
	@for i in $$(seq 1 $(K)); do $(MAKE) --no-print-directory next || exit 1; done

# Merge every run in cov_runs/ and generate a report
merge:
	@mkdir -p $(MERGED)
	$(VCS_HOME)/bin/urg -dir $(RUN_DIR)/*.vdb -dbname $(MERGED)/merged.vdb \
	    -report $(MERGED)/urgReport
	@echo "Runs merged: $$(ls -d $(RUN_DIR)/*.vdb | wc -l)"
	@cat $(MERGED)/urgReport/dashboard.txt 2>/dev/null || true

# ---- Viewing ----
waves:
	$(VERDI_HOME)/bin/verdi -dbdir ./simv.daidir -ssf novas.fsdb -nologo &

cov:
	$(VERDI_HOME)/bin/verdi -cov -covdir $(COV_DIR) &

cov_merged:
	$(VERDI_HOME)/bin/verdi -cov -covdir $(MERGED)/merged.vdb &

# ---- Cleaning ----
# clean: build products and single-run outputs (keeps cov_runs and the counter)
clean:
	rm -rf csrc simv simv.daidir simv.vdb *.log ucli.key vc_hdrs.h \
	       novas.fsdb novas.conf novas.rc verdiLog verdi_config_file \
	       instr_gen_mem.dat urgReport DVEfiles

# clean_runs: wipe all multi-run results and restart the seed counter at 1
clean_runs:
	rm -rf $(RUN_DIR) $(MERGED) $(COUNTER)

.PHONY: all comp run next batch merge waves cov cov_merged clean clean_runs
