# cse598addv
Repo for CSE598: ADDV

# Setup
1. Swap to tcsh
   %tcsh
2. Source env for Synopsys tools
   % source env.cshrc

# Sim and synth
First, 
1. To compile, run simulation, and open Verdi waveforms:
   % cd even_odd
   $ make run
2. To run synthesis, change compile_dc.tcl accordingly, then:
   % cd synth
   % make synth