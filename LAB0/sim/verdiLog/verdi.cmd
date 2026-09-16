simSetSimulator "-vcssv" -exec "./simv" -args
debImport "-dbdir" "./simv.daidir"
verdiSetActWin -dock widgetDock_MTB_SOURCE_TAB_1
verdiWindowResize -win $_Verdi_1 "298" "48" "900" "700"
srcHBSelect "tb_dsp_slice.slice_me" -win $_nTrace1
verdiSetActWin -dock widgetDock_<Inst._Tree>
srcHBSelect "tb_dsp_slice.slice_me" -win $_nTrace1
srcSetScope "tb_dsp_slice.slice_me" -delim "." -win $_nTrace1
srcHBSelect "tb_dsp_slice.slice_me" -win $_nTrace1
srcDeselectAll -win $_nTrace1
verdiSetActWin -dock widgetDock_MTB_SOURCE_TAB_1
srcDeselectAll -win $_nTrace1
