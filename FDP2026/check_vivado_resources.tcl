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

# Force both runs to rebuild; report_timing alone can reuse an old routed netlist.
reset_run impl_1
reset_run synth_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1
if {[get_property STATUS [get_runs synth_1]] ne "synth_design Complete!"} {
    error "Synthesis did not complete: [get_property STATUS [get_runs synth_1]]"
}
open_run synth_1
set utilization [report_utilization -return_string]
set report_file [open [file join $report_dir synthesis_utilization.txt] w]
puts $report_file $utilization
close $report_file
check_utilization $utilization synthesis
close_design

launch_runs impl_1 -to_step route_design -jobs 4
wait_on_run impl_1
# Vivado also returns "route_design Complete, Failed Timing!". It still
# contains a routed design: export diagnostics before rejecting its slack.
if {![string match "route_design Complete*" [get_property STATUS [get_runs impl_1]]]} {
    error "Implementation did not route: [get_property STATUS [get_runs impl_1]]"
}
open_run impl_1
if {[llength [get_clocks oled_clk]] != 1} {
    error "The 6.25 MHz OLED generated clock was not created; check the XDC"
}
set utilization [report_utilization -return_string]
set report_file [open [file join $report_dir routed_utilization.txt] w]
puts $report_file $utilization
close $report_file
check_utilization $utilization routed
report_timing_summary -report_unconstrained -file [file join $report_dir routed_timing.txt]
check_timing -file [file join $report_dir timing_coverage.txt]
report_timing -delay_type max -max_paths 200 -nworst 1 \
    -file [file join $report_dir worst_setup_paths.txt]
report_timing -delay_type min -max_paths 20 -nworst 1 \
    -file [file join $report_dir worst_hold_paths.txt]
# A single global top-ten report can hide the 100 MHz arithmetic behind
# several OLED text paths. Include every clock pairing and failing endpoint.
set pair_report [file join $report_dir clock_pair_paths.txt]
set pair_header [open $pair_report w]
puts $pair_header "Routed setup paths for each launch/capture clock pairing"
close $pair_header
foreach launch_clock [get_clocks] {
    foreach capture_clock [get_clocks] {
        report_timing -from $launch_clock -to $capture_clock -delay_type max \
            -max_paths 20 -nworst 1 -append -file $pair_report
    }
}
report_timing -delay_type max -max_paths 100000 -nworst 1 \
    -slack_lesser_than 0 -path_type summary \
    -file [file join $report_dir failing_setup_endpoints.txt]
set worst_path [lindex [get_timing_paths -max_paths 1 -delay_type max] 0]
if {$worst_path eq ""} {
    error "No constrained timing path was found; check the XDC clock constraint"
}
set slack [get_property SLACK $worst_path]
puts "Worst routed setup slack: $slack ns"
if {$slack < 0} {
    error "Routed design fails setup timing (WNS $slack ns)"
}
set worst_hold_path [lindex [get_timing_paths -max_paths 1 -delay_type min] 0]
if {$worst_hold_path eq ""} {
    error "No constrained hold path was found"
}
set hold_slack [get_property SLACK $worst_hold_path]
puts "Worst routed hold slack: $hold_slack ns"
if {$hold_slack < 0} {
    error "Routed design fails hold timing (WHS $hold_slack ns)"
}
puts "PASS: XC7A35T resources and routed timing are within limits."
close_project
