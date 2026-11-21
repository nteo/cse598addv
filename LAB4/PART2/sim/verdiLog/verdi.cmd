verdiSetActWin -dock widgetDock_<Decl._Tree>
simSetSimulator "-vcssv" -exec "./simv" -args "+VERBOSE=0 +TEST=0"
debImport "-dbdir" "./simv.daidir"
debLoadSimResult /home/a34263_asu/CSE598/LAB4/PART2/sim/novas.fsdb
wvCreateWindow
verdiSetActWin -win $_nWave2
verdiWindowResize -win $_Verdi_1 "596" "193" "900" "700"
verdiSetActWin -dock widgetDock_MTB_SOURCE_TAB_1
srcTBInvokeSim
verdiSetActWin -win $_InteractiveConsole_3
verdiSetActWin -dock widgetDock_<Member>
verdiWindowResize -win $_Verdi_1 "280" "130" "900" "700"
srcTBRunSim
verdiDockWidgetSetCurTab -dock windowDock_nWave_2
verdiSetActWin -win $_nWave2
wvRestoreSignal -win $_nWave2 "/home/a34263_asu/CSE598/LAB4/PART2/sim/fifo.rc" \
           -overWriteAutoAlias on -appendSignals on
wvZoomAll -win $_nWave2
wvZoomIn -win $_nWave2
wvZoomIn -win $_nWave2
debExit
