#/**************************************************/
#/* Compile Script for Synopsys                    */
#/*                                                */
#/* dc_shell-t -f compile_dc.tcl                   */
#/*                                                */
#/* OSU FreePDK 45nm                               */
#/* LAB3 Part 2: synthesize matmul_4x4_systolic    */
#/* LAB3 Part 3: synthesize matmul_8x8             */
#/**************************************************/

#/* All verilog files, separated by spaces         */
#/* Leaf modules first, then matmul.sv and         */
#/* matmul_8x8.sv.                                */
#/* Do NOT include testbenches or matmul_with_ram. */
set my_verilog_files [list \
    ../FP8/fp8_add/fp8_add_prealign.sv \
    ../FP8/fp8_add/fp8_add_align.sv \
    ../FP8/fp8_add/fp8_add_shift.sv \
    ../FP8/fp8_add/fp8_add_execute.sv \
    ../FP8/fp8_add/fp8_add_normalize.sv \
    ../FP8/fp8_add/fp8_add_round.sv \
    ../FP8/fp8_add/fp8_add_exception.sv \
    ../FP8/fp8_add/fp8_add.sv \
    ../FP8/fp8_mul/fp8_mul_prep.sv \
    ../FP8/fp8_mul/fp8_mul_execute.sv \
    ../FP8/fp8_mul/fp8_mul_round.sv \
    ../FP8/fp8_mul/fp8_mul.sv \
    ../matmul.sv \
    ../matmul_8x8.sv ]

# For the BASELINE integer run, replace the list above with just the
# original integer matmul (plus a defines file if it uses `DWIDTH etc.):
# set my_verilog_files [list ../defines.vh ../matmul_int.v]

#/* Top-level Module                               */
# Modified: matmul_8x8.sv is the design being synthesized
# set my_toplevel   matmul_4x4_systolic
set my_toplevel   matmul_8x8

#/* The name of the clock pin. If no clock-pin     */
#/* exists, pick anything                          */
set my_clock_pin clk

#/* Target frequency in MHz for optimization       */
#/* Use the SAME target for baseline and FP8 runs. */
set my_clk_freq_MHz 1000

#/* Delay of input signals (Clock-to-Q, Package etc.)  */
set my_input_delay_ns 0.1

#/* Reserved time for output signals (Holdtime etc.)   */
set my_output_delay_ns 0.1


#/**************************************************/
#/* No modifications needed below                  */
#/**************************************************/
set OSU_FREEPDK [format "%s%s"  [getenv "PDK_DIR"] "/osu_soc/lib/files"]
set search_path [concat  $search_path $OSU_FREEPDK]
set alib_library_analysis_path $OSU_FREEPDK

set link_library [set target_library [concat  [list gscl45nm.db] [list dw_foundation.sldb]]]
set target_library "gscl45nm.db"

define_design_lib WORK -path ./WORK
set verilogout_show_unconnected_pins "true"

analyze -format sverilog $my_verilog_files

elaborate $my_toplevel

current_design $my_toplevel

link
uniquify

# NOTE: the LAB2 set_dont_touch lines for imem/dmem are removed on purpose.
# matmul_4x4_systolic has no such cells and DC would error out.

# 1000.0 (float) so that non-divisor targets like 300 MHz don't truncate
set my_period [expr 1000.0 / $my_clk_freq_MHz]

set find_clock [ find port [list $my_clock_pin] ]
if {  $find_clock != [list] } {
   set clk_name $my_clock_pin
   create_clock -period $my_period $clk_name
} else {
   set clk_name vclk
   create_clock -period $my_period -name $clk_name
}

set_driving_cell  -lib_cell INVX1  [all_inputs]
set_input_delay $my_input_delay_ns -clock $clk_name [remove_from_collection [all_inputs] $my_clock_pin]
set_output_delay $my_output_delay_ns -clock $clk_name [all_outputs]

compile -map_effort medium
compile -incremental_mapping -map_effort medium

check_design
report_constraint -all_violators

redirect check_design.rep {
    check_design
}

redirect final_design.rep {
    report_reference
    report_area -hierarchy
    report_timing -delay_type max -max_paths 20 -path full
}

redirect timing.rep {
    report_timing -delay_type max -max_paths 5 -path full -input_pins -nets
}

redirect constraints.rep {
    report_constraint -all_violators
    report_clocks
}

redirect cell.rep  { report_cell }
redirect power.rep { report_power }
redirect area.rep  { report_area }

quit