# Lab 5 Part 5: ISS vs RTL trace comparison
# Run from the PART5/ folder.
#
#   make              compile the RTL once, then run all 3 programs
#   make prog1        run one program (ISS -> RTL -> compare); needs 'make compile' first
#   make waves_verdi  open Verdi with the waves from the last RTL run

PYTHON ?= python3
PROJ_F ?= rtl/project.f
TOP    ?= testbench
SIM    := MIPS-Simulator/Mips_Simulator.py
PROGS  := prog1 prog2 prog3

.PHONY: all compile regress $(PROGS) verdi waves_verdi clean clean_all

all: compile regress

# This compiles the RTL (from project.f) plus the Part 5 testbench with VCS
compile:
	${VCS_HOME}/bin/vcs -full64 -sverilog -timescale=1ns/1ps -F $(PROJ_F) -top $(TOP) -debug_access+all -kdb -lca |& tee compile.log

# This runs all 3 programs
regress: $(PROGS)

# For one program: run the ISS, run the RTL on the same machine code, compare traces.
# The '-' before compare.py lets the other programs still run if one fails.
$(PROGS):
	mkdir -p traces
	$(PYTHON) $(SIM) programs/$@.asm traces/$@.bin > traces/$@.iss.trace
	./simv +PROG=traces/$@.bin +TRACE=traces/$@.rtl.trace |& tee traces/$@.sim.log
	-$(PYTHON) compare.py traces/$@.iss.trace traces/$@.rtl.trace

# This launches Verdi
verdi:
	$(VERDI_HOME)/bin/verdi -dbdir ./simv.daidir -nologo

# This launches Verdi with waves loaded (waves are from the most recent program run)
waves_verdi:
	$(VERDI_HOME)/bin/verdi -dbdir ./simv.daidir -ssf novas.fsdb -nologo

# This removes simulation files but keeps the traces
clean:
	\rm -rf *.log *.h csrc DVEFiles simv.daidir simv ucli.key vcdplus.vpd *.syn *.pvl *.mr *.svf command.log novas.conf novas.rc verdi_config_file verdiLog novas.fsdb novas.log novas_dump.log

# This also removes the traces
clean_all: clean
	\rm -rf traces
