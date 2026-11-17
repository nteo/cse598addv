
all: sim clean

# This compiles RTL, runs the sim and dumps its results, and opens verdi with waves
run: compile_verdi sim waves_verdi

# This compiles with VCS and runs simulation
compile_and_sim:
	${VCS_HOME}/bin/vcs -R -full64 -sverilog -f ../project.f -debug_access+all |& tee compile_and_sim.log

# This compiles with VCS
compile:
	${VCS_HOME}/bin/vcs -full64 -sverilog -f ../project.f -debug_access+all |& tee compile.log

# This compiles with VCS and also generates the database for Verdi
compile_verdi:
	${VCS_HOME}/bin/vcs -full64 -sverilog -f ../project.f -debug_access+all -kdb -lca  |& tee compile_verdi.log

# This compiles the RTL and generator with UVM 1.2 enabled
compile_uvm:
	${VCS_HOME}/bin/vcs -full64 -sverilog -timescale=1ns/1ps -f ../project.f -debug_access+all -ntb_opts uvm-1.2 +incdir+${VCS_HOME}/etc/uvm-1.2/src |& tee compile_uvm.log

# This runs simulation
sim:
	./simv

# This launches Verdi
verdi:
	$(VERDI_HOME)/bin/verdi -dbdir ./simv.daidir -nologo

# This launches Verdi with waves loaded
waves_verdi:
	$(VERDI_HOME)/bin/verdi -dbdir ./simv.daidir -ssf novas.fsdb -nologo

clean:
	\rm -rf *.log *.h  csrc DVEFiles simv.daidir simv ucli.key vcdplus.vpd *.syn *.pvl *.mr *.svf command.log *.txt novas.conf  novas.rc  verdi_config_file  verdiLog novas.fsdb novas.log novas_dump.log

