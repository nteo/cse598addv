# cse598addv
Repo for CSE598: ADDV

# Setup
1. Swap to tcsh
   %tcsh
2. Swap to lab directory
   %cd <LAB-NUMBER>
3. Source env for Synopsys tools
   % source env.cshrc

# Sim and synth
First, 
   %cd <LAB-NUMBER>
1. To compile, run simulation, and open Verdi waveforms:
   % cd sim
   $ make run
2. To run synthesis, change compile_dc.tcl accordingly, then:
   % cd synth
   % make synth

# Adding a new file
.f denotes a file list. We can list all the .sv files the compiler should target in a singular .f, but we can also link other .f files in our list so we can create a hierarchical structure to encapsulate all our files.
1. Create some new file either with vi or in vscode
2. If it is in a brand new folder, go to the .f in the parent folder and add
   +incdir+$PROJECT_ROOT/path/to/folder (where PROJECT_ROOT is your LAB directory)
3. Create a new .f for the folder you are in (name it after the folder) and list all files within the folder
   $PROJECT_ROOT/path/to/file

# Using git
The below steps show the recommended workflow for pushing a file to the main remote branch
1. git checkout -b <branch> (creates a local branch for you to work in)
   *If your branch is already made, drop the -b*
2. git add -A (adds all files to git tracking. You can alternatively remove -A and list a specific file)
3. git commit -a (commits all modified files. See above note for listing a specific file)
4. git push --set-upstream origin <branch> (pushes changes to remote branch so you can access it elsewhere)
   *If your remote is already set, drop the --set-upstream*
5. git checkout main (switches branch to main)
6. git merge <branch> (merges your branch changes to the main branch. ONLY DO ONCE EVERYTHING IS STABLE IN YOUR BRANCH)
7. git branch -d <branch> (delete your branch. Not a necessary step, just here to show you how to do it)

