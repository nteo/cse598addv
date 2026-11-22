verdiWindowResize -win $_vdCoverage_1 "0" "27" "1504" "776"
gui_set_pref_value -category {coveragesetting} -key {geninfodumping} -value 1
gui_exclusion -set_force true
verdiSetFont  -font  {DejaVu Sans}  -size  12
verdiSetFont -font "DejaVu Sans" -size "12"
gui_assert_mode -mode flat
gui_class_mode -mode hier
gui_excl_mgr_flat_list -on  0
gui_covdetail_select -id  CovDetail.1   -name   Line
verdiWindowWorkMode -win $_vdCoverage_1 -coverageAnalysis
gui_open_cov  -hier cov_merged/merged.vdb -testdir {} -test {cov_merged/merged/test} -merge MergedTest -db_max_tests 10 -sdc_level 1 -fsm transition
verdiSetActWin -dock widgetDock_<CovDetail>
gui_covtable_show -show  { Tests } -id  CoverageTable.1  -test  MergedTest
verdiSetActWin -dock widgetDock_<Summary>
vdCovExit -noprompt
