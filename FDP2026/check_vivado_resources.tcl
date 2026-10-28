# Run in Vivado Tcl batch mode from any directory:
#   vivado -mode batch -source C:/path/to/ee2026_project/FDP2026/check_vivado_resources.tcl
# This rebuilds the synthesis/implementation runs before checking the actual
# XC7A35T resource usage and routed 100 MHz timing. It does not program a board.

set project_dir [file dirname [file normalize [info script]]]
open_project [file join $project_dir FDP2026.xpr]
if {[get_property PART [current_project]] ne "xc7a35tcpg236-1"} {
    error "Unexpected FPGA part: [get_property PART [current_project]]"
}

set report_dir [file join $project_dir vivado_resource_reports]
file mkdir $report_dir

proc check_utilization {report stage} {
    foreach {label limit} {"Slice LUTs" 20800 "Slice Registers" 41600
                            "Block RAM Tile" 50 "DSPs" 90} {
        set escaped_label [string map {" " {\s+}} $label]
        set pattern [format {(?m)^\|\s*%s\*?\s*\|\s*([0-9,.]+)\s*\|} $escaped_label]
        if {![regexp $pattern $report unused used_text]} {
            error "Could not read $label from $stage utilization report"
        }
        set used [string map {, {}} $used_text]
        puts "$stage $label: $used / $limit"
        if {$used > $limit} {
            error "$stage $label exceeds XC7A35T capacity: $used / $limit"
        }
    }
}

# Force a fresh result so an old successful run cannot hide added graph logic.
reset_run synth_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1
if {[get_property STATUS [get_runs synth_1]] ne "synth_design Complete!"} {
    error "Synthesis did not complete: [get_property STATUS [get_runs synth_1]]"
}
open_run synth_1
set synth_missing [check_timing -override_defaults {no_clock unconstrained_internal_endpoints}]
set report_file [open [file join $report_dir synthesis_check_timing.txt] w]
puts $report_file $synth_missing
close $report_file
if {[string match "*no_clock*" $synth_missing] ||
    [string match "*unconstrained_internal_endpoints*" $synth_missing]} {
    # The full text is retained in the report; list the structural check
    # again so an unconstrained OLED-domain path cannot be mistaken for a pass.
    puts $synth_missing
}
if {[llength [get_timing_paths -max_paths 1 -delay_type max]] == 0} {
    error "Synthesis has no constrained path; check the OLED generated clock"
}
set utilization [report_utilization -return_string]
set report_file [open [file join $report_dir synthesis_utilization.txt] w]
puts $report_file $utilization
close $report_file
check_utilization $utilization synthesis
close_design

launch_runs impl_1 -to_step route_design -jobs 4
wait_on_run impl_1
if {![string match "route_design Complete!*" [get_property STATUS [get_runs impl_1]]]} {
    error "Implementation did not route: [get_property STATUS [get_runs impl_1]]"
}
open_run impl_1
set utilization [report_utilization -return_string]
set report_file [open [file join $report_dir routed_utilization.txt] w]
puts $report_file $utilization
close $report_file
check_utilization $utilization routed
set check_timing_report [file join $report_dir routed_check_timing.txt]
check_timing -verbose -file $check_timing_report
report_timing_summary -file [file join $report_dir routed_timing.txt]
set worst_path [lindex [get_timing_paths -max_paths 1 -delay_type max] 0]
if {$worst_path eq ""} {
    error "No constrained timing path was found; check the XDC clock constraint"
}
set slack [get_property SLACK $worst_path]
puts "Worst routed setup slack: $slack ns"
if {$slack < 0} {
    error "Routed design fails the 100 MHz timing constraint (WNS $slack ns)"
}
set hold_path [lindex [get_timing_paths -max_paths 1 -delay_type min] 0]
if {$hold_path ne "" && [get_property SLACK $hold_path] < 0} {
    error "Routed design fails hold timing: [get_property SLACK $hold_path] ns"
}
puts "PASS: XC7A35T resources and routed timing are within limits."
puts "See routed_timing.txt and routed_check_timing.txt for clock-domain coverage,"
puts "hold/pulse-width results and external I/O-delay warnings."
close_project
