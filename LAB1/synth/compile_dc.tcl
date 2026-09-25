#/**************************************************/
#/* Compile Script for Synopsys                    */
#/*                                                */
#/* dc_shell-t -f compile_dc.tcl                   */
#/*                                                */
#/* OSU FreePDK 45nm                               */
#/**************************************************/

#/* All verilog files, separated by spaces         */
set my_verilog_files [list ../rtl/fifo/fifo_if.sv ../rtl/fifo/fifo.sv]

#/* Top-level Module                               */
set my_toplevel fifo


#/* Target frequency in MHz for optimization       */
#/* Set initial target for BOTH clock domains       */
set my_rclk_freq_MHz 1320
set my_wclk_freq_MHz 1650


#/* Delay of input signals */
set my_input_delay_ns 0.1

#/* Reserved time for output signals */
set my_output_delay_ns 0.1


#/**************************************************/
#/* No modifications needed below                  */
#/**************************************************/

set OSU_FREEPDK [format "%s%s" [getenv "PDK_DIR"] "/osu_soc/lib/files"]
set search_path [concat $search_path $OSU_FREEPDK]
set alib_library_analysis_path $OSU_FREEPDK

set link_library [set target_library [concat [list gscl45nm.db] [list dw_foundation.sldb]]]
set target_library "gscl45nm.db"

define_design_lib WORK -path ./WORK

set verilogout_show_unconnected_pins "true"

set_ultra_optimization true
set_ultra_optimization -force


# --------------------------------------------------
# Analyze / elaborate
# --------------------------------------------------

analyze -f sverilog $my_verilog_files

elaborate $my_toplevel

current_design $my_toplevel

link
get_ports *
uniquify


# --------------------------------------------------
# Clock definitions
# --------------------------------------------------

# 100 MHz = 10 ns period
set my_rperiod [expr 1000.0 / $my_rclk_freq_MHz]
set my_wperiod [expr 1000.0 / $my_wclk_freq_MHz]

create_clock \
    -name WCLK \
    -period $my_wperiod \
    [get_ports fifo_i.wclk]

create_clock \
    -name RCLK \
    -period $my_rperiod \
    [get_ports fifo_i.rclk]


# WCLK and RCLK are asynchronous
set_clock_groups -asynchronous \
    -group [get_clocks WCLK] \
    -group [get_clocks RCLK]


# --------------------------------------------------
# Input/output constraints
# --------------------------------------------------

set_driving_cell -lib_cell INVX1 [all_inputs]

# Don't apply input delay to either clock
set_input_delay $my_input_delay_ns \
    -clock WCLK \
    [remove_from_collection [all_inputs] [get_ports wclk]]

set_input_delay $my_input_delay_ns \
    -clock RCLK \
    [remove_from_collection [all_inputs] [get_ports rclk]]

# Output delays
set_output_delay $my_output_delay_ns \
    -clock RCLK \
    [all_outputs]


# --------------------------------------------------
# Compile
# --------------------------------------------------

compile -ungroup_all -map_effort medium

compile -incremental_mapping -map_effort medium


# --------------------------------------------------
# Checks / reports
# --------------------------------------------------

check_design

report_constraint -all_violators

redirect timing.rep {
    report_timing
}

redirect cell.rep {
    report_cell
}

redirect power.rep {
    report_power
}

redirect area.rep {
    report_area
}

quit