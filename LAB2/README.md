# cse598addv
Repo for CSE598: ADDV

# Setup
1. Swap to tcsh
   %tcsh
2. Swap to lab directory
   %cd LAB2
3. Source env for Synopsys tools
   % source env.cshrc

# Sim and synth
First, 
   %cd LAB2
1. To compile, run simulation, and open Verdi waveforms:
   % cd sim
   $ make run
2. To run synthesis, change compile_dc.tcl accordingly, then:
   % cd synth
   % make synth

# Running different programs
1. Go to top.sv
2. Modify line 83 with the readmem and replace the memfile.dat to run different programs
 - memfile.dat tests the pipeline (PART1)
 - memfile_test.dat is another test but the waveform is not in the report (NO PART)
 - memfile_ch.dat tests handling control hazards (PART1)
 - memfile_dh.dat tests handling data hazards (PART1)
 - memfile_load.dat tests the lw and sw instructions (PART1)
 - memfile_muladd.dat tests the muladd instruction (PART2)
 - memfile_perfmon.dat tests the perfmon instruction (PART2)
3. The expected values will have to be calculated by reading the report