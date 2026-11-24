verdiWindowResize -win $_vdCoverage_1 "0" "27" "1496" "803"
gui_set_pref_value -category {coveragesetting} -key {geninfodumping} -value 1
gui_exclusion -set_force true
verdiSetFont  -font  {DejaVu Sans}  -size  12
verdiSetFont -font "DejaVu Sans" -size "12"
gui_assert_mode -mode flat
gui_class_mode -mode hier
gui_excl_mgr_flat_list -on  0
gui_covdetail_select -id  CovDetail.1   -name   Line
verdiWindowWorkMode -win $_vdCoverage_1 -coverageAnalysis
gui_open_cov  -hier simv.vdb -testdir {} -test {simv/test} -merge MergedTest -db_max_tests 10 -sdc_level 1 -fsm transition
gui_set_pref_value -category {ColumnCfg} -key {covtblAssertList_Assert} -value {true}
verdiSetActWin -dock widgetDock_<CovDetail>
verdiSetActWin -dock widgetDock_<Summary>
gui_list_expand -id  CoverageTable.1   -list {covtblInstancesList} instr_gen
gui_list_expand -id  CoverageTable.1   -list {covtblInstancesList} instr_gen.dut
gui_list_expand -id  CoverageTable.1   -list {covtblInstancesList} instr_gen.dut.mips
gui_list_expand -id  CoverageTable.1   -list {covtblInstancesList} instr_gen.dut.mips.dp
gui_list_select -id CoverageTable.1 -list covtblInstancesList { instr_gen.dut.mips.dp.pcadd1   }
gui_list_action -id  CoverageTable.1 -list {covtblInstancesList} instr_gen.dut.mips.dp.pcadd1  -column {} 
gui_covtable_show -show  { Design Hierarchy } -id  CoverageTable.1  -test  MergedTest
verdiSetActWin -dock widgetDock_<CovSrc.1>
gui_covdetail_select -id  CovDetail.1   -name   Toggle
verdiSetActWin -dock widgetDock_<CovDetail>
