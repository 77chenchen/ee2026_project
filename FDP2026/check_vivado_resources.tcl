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

# Fail closed if a clock was omitted, renamed or accidentally slowed in XDC.
# sys_clk_pin and oled_clk are related clocks: do not cut their paths with
# asynchronous clock groups/false paths to make a violation disappear.
proc check_clock_periods {} {
    foreach {name expected_period} {sys_clk_pin 10.0 oled_clk 160.0} {
        set clock [get_clocks $name]
        if {[llength $clock] != 1} {error "Missing or ambiguous clock: $name"}
        set period [get_property PERIOD $clock]
        if {![string is double -strict $period] || abs($period-$expected_period)>0.001} {
            error "Unexpected $name period: $period ns (expected $expected_period ns)"
        }
    }
}

proc check_internal_coverage {report} {
    foreach category {no_clock constant_clock pulse_width_clock
            unconstrained_internal_endpoints multiple_clock generated_clocks
            loops latch_loops} {
        set pattern [format {(?m)^\s*[0-9]+\. checking %s \(([0-9]+)\)} $category]
        if {![regexp $pattern $report unused count]} {
            error "Cannot verify timing coverage category: $category"
        }
        if {$count != 0} {error "Incomplete internal timing coverage: $category ($count)"}
    }
}

# Setup/hold path objects do not cover the separate pulse-width checks.
# Read WPWS and its failing-endpoint count from the overall summary table.
proc check_pulse_width {report} {
    set in_summary 0
    foreach line [split $report \n] {
        if {[string match "*Design Timing Summary*" $line]} {set in_summary 1}
        if {$in_summary && [regexp {^\s*-?[0-9]+\.[0-9]+\s+} $line]} {
            set columns [regexp -all -inline {\S+} $line]
            if {[llength $columns] != 12} {error "Unrecognized design timing summary columns"}
            set pulse_slack [lindex $columns 8]
            set pulse_failures [lindex $columns 10]
            if {![string is double -strict $pulse_slack] ||
                ![string is integer -strict $pulse_failures]} {
                error "Cannot verify routed pulse-width timing"
            }
            puts "Worst routed pulse-width slack: $pulse_slack ns"
            if {$pulse_slack < 0 || $pulse_failures != 0} {
                error "Routed design fails pulse-width timing (WPWS $pulse_slack ns)"
            }
            return
        }
    }
    error "No design timing summary row found; cannot verify pulse width"
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
set utilization [report_utilization -return_string]
set report_file [open [file join $report_dir routed_utilization.txt] w]
puts $report_file $utilization
close $report_file
check_utilization $utilization routed
set timing_summary [report_timing_summary -report_unconstrained -return_string]
set report_file [open [file join $report_dir routed_timing.txt] w]
puts $report_file $timing_summary
close $report_file
set timing_coverage [check_timing -verbose -return_string]
set report_file [open [file join $report_dir timing_coverage.txt] w]
puts $report_file $timing_coverage
close $report_file
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
# Complete report export before any clock/coverage/timing rejection, so even
# a failed run can be diagnosed from the same fresh routed design.
check_clock_periods
check_internal_coverage $timing_coverage
check_pulse_width $timing_summary
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
puts "PASS: XC7A35T resources, internal clock coverage and routed setup/hold/pulse-width checks."
puts "Review external I/O delay warnings separately; this is not board-level interface signoff."
puts "Reports: $report_dir"
close_project
