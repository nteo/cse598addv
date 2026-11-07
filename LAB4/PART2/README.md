# cse598addv
Repo for CSE598: ADDV

# Setup
1. Swap to tcsh
   %tcsh
2. Swap to lab directory
   %cd LAB4/PART2
3. Source env for Synopsys tools
   % source env.cshrc

# Sim
First, 
   %cd LAB4/PART2
1. To compile, run simulation, and open Verdi waveforms:
   % cd sim
   % make run
   To run one test, pass its number through the Makefile:
   % make run TEST=1
   Tests 1, 2, and 3 select the individual tests; the default `TEST=0` runs all tests.

# Running the bug
First, 
   %cd LAB4/PART2
1. To compile, run simulation, and open Verdi waveforms:
   % cd sim
   % make run_bug
   To run one test, pass its number through the Makefile:
   % make run_bug TEST=1
   Tests 1, 2, and 3 select the individual tests; the default `TEST=0` runs all tests.