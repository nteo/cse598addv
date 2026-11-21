verdiSetActWin -dock widgetDock_<Decl._Tree>
simSetSimulator "-vcssv" -exec "./simv" -args "+VERBOSE=0"
debImport "-dbdir" "./simv.daidir"
debLoadSimResult /home/a34263_asu/CSE598/LAB4/PART4/sim/novas.fsdb
wvCreateWindow
verdiSetActWin -win $_nWave2
verdiWindowResize -win $_Verdi_1 "298" "46" "900" "700"
verdiSetActWin -dock widgetDock_MTB_SOURCE_TAB_1
srcTBInvokeSim
verdiSetActWin -win $_InteractiveConsole_3
verdiSetActWin -dock widgetDock_<Member>
verdiDockWidgetSetCurTab -dock windowDock_nWave_2
verdiSetActWin -win $_nWave2
assCtrlInvoke -statistic
verdiSetActWin -dock widgetDock_Statistics
srcTBRunSim
srcTBRebuild -fromCmd "make compile_verdi" -path "." -reloadKDB -restartSim \
           -simOpt "+VERBOSE=0 +fsdb+sva_success +fsdb+sva_vacuous"
verdiWindowResize -win $_Verdi_1 "298" "46" "1060" "700"
srcTBRunSim
verdiDockWidgetSetCurTab -dock windowDock_nWave_2
verdiSetActWin -win $_nWave2
wvRestoreSignal -win $_nWave2 \
           "/home/a34263_asu/CSE598/LAB4/PART4/sim/even_odd_assertions.rc" \
           -overWriteAutoAlias on -appendSignals on
wvZoomAll -win $_nWave2
wvZoomAll -win $_nWave2
wvZoom -win $_nWave2 119.843284 327.571642
verdiSetActWin -dock widgetDock_Statistics
