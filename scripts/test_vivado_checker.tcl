# Unit-test the checker control flow with mocked Vivado commands. This does
# not emulate synthesis, resource estimation or static timing analysis.
# argv[0] must be a scratch copy: the checker writes report files beside it.
set checker_script [lindex $argv 0]
if {$checker_script eq ""} {error "Usage: test_vivado_checker.tcl SCRATCH_CHECKER"}

proc open_project {args} {}
proc current_project {} {return mock_project}
proc get_runs {name} {return $name}
proc reset_run {args} {}
proc launch_runs {args} {}
proc wait_on_run {args} {}
proc open_run {args} {}
proc close_design {} {}
proc close_project {} {}
proc get_clocks {args} {
    if {[llength $args]} {return oled_clk}
    return {sys_clk_pin oled_clk}
}
proc get_timing_paths {args} {
    if {[lsearch -exact $args min]>=0} {return hold_path}
    return setup_path
}
proc get_property {name object} {
    global mock_status mock_setup mock_hold
    switch -- $name {
        PART {return xc7a35tcpg236-1}
        STATUS {
            if {$object eq "synth_1"} {return "synth_design Complete!"}
            return $mock_status
        }
        SLACK {
            if {$object eq "hold_path"} {return $mock_hold}
            return $mock_setup
        }
    }
    error "Unexpected property $name"
}
proc report_utilization {args} {
    return "| Slice LUTs | 7151 |\n| Slice Registers | 1617 |\n| Block RAM Tile | 0 |\n| DSPs | 12 |"
}
proc record_report {args} {
    global mock_reports
    set index [lsearch -exact $args -file]
    if {$index>=0} {
        lappend mock_reports [file tail [lindex $args [expr {$index+1}]]]
    }
}
proc report_timing_summary {args} {record_report {*}$args}
proc report_timing {args} {record_report {*}$args}
proc check_timing {args} {record_report {*}$args}

foreach {mock_status mock_setup mock_hold expected_error} {
    {route_design Complete!}                0.25  0.10 {}
    {route_design Complete, Failed Timing!} -0.45  0.10 {*fails setup timing*}
    {route_design Complete, Failed Timing!}  0.25 -0.10 {*fails hold timing*}
    {route_design ERROR!}                   0.25  0.10 {*Implementation did not route*}
} {
    set mock_reports {}
    set failed [catch {source $checker_script} message]
    if {$expected_error eq ""} {
        if {$failed} {error "Unexpected checker failure: $message"}
    } elseif {!$failed || ![string match $expected_error $message]} {
        error "Unexpected checker result for $mock_status: $message"
    }
    if {$mock_status ne "route_design ERROR!"} {
        foreach report {routed_timing.txt timing_coverage.txt worst_setup_paths.txt
                        worst_hold_paths.txt clock_pair_paths.txt failing_setup_endpoints.txt} {
            if {[lsearch -exact $mock_reports $report]<0} {
                error "Checker failed to export $report before its timing verdict"
            }
        }
    } elseif {[llength $mock_reports]} {
        error "Checker reported an implementation that never completed routing"
    }
}
puts "PASS Vivado checker status handling and report export before setup/hold rejection (mocked)"
