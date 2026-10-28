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
    global mock_missing_clock
    if {[llength $args]} {
        set name [lindex $args 0]
        if {$mock_missing_clock && $name eq "oled_clk"} {return {}}
        return $name
    }
    return {sys_clk_pin oled_clk}
}
proc get_timing_paths {args} {
    if {[lsearch -exact $args min]>=0} {return hold_path}
    return setup_path
}
proc get_property {name object} {
    global mock_status mock_setup mock_hold mock_oled_period
    switch -- $name {
        PART {return xc7a35tcpg236-1}
        PERIOD {
            if {$object eq "oled_clk"} {return $mock_oled_period}
            return 10.0
        }
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
proc report_timing_summary {args} {
    global mock_reports mock_setup mock_hold mock_pulse mock_pulse_failures mock_summary_bad
    lappend mock_reports routed_timing.txt
    if {$mock_summary_bad} {return "Unrecognized summary"}
    return [format "Design Timing Summary\n%.3f 0.000 0 1 %.3f 0.000 0 1 %.3f 0.000 %d 1\n" \
        $mock_setup $mock_hold $mock_pulse $mock_pulse_failures]
}
proc report_timing {args} {record_report {*}$args}
proc check_timing {args} {
    global mock_reports mock_bad_coverage mock_coverage_missing
    lappend mock_reports timing_coverage.txt
    set report ""
    set i 0
    foreach category {no_clock constant_clock pulse_width_clock
            unconstrained_internal_endpoints multiple_clock generated_clocks loops latch_loops} {
        if {$mock_coverage_missing && $category eq "no_clock"} {continue}
        append report "[incr i]. checking $category ([expr {$category eq $mock_bad_coverage ? 1 : 0}])\n"
    }
    return $report
}

foreach scenario {pass setup hold pulse pulse_count missing_clock wrong_period
        no_clock constant_clock pulse_width_clock unconstrained_internal_endpoints
        multiple_clock generated_clocks loops latch_loops missing_coverage bad_summary route} {
    set mock_status "route_design Complete!"
    set mock_setup 0.25
    set mock_hold 0.10
    set mock_pulse 3.75
    set mock_pulse_failures 0
    set mock_missing_clock 0
    set mock_oled_period 160.0
    set mock_bad_coverage ""
    set mock_coverage_missing 0
    set mock_summary_bad 0
    set expected_error ""
    switch -- $scenario {
        setup {
            set mock_status "route_design Complete, Failed Timing!"
            set mock_setup -0.45; set expected_error "*fails setup timing*"
        }
        hold {
            set mock_status "route_design Complete, Failed Timing!"
            set mock_hold -0.10; set expected_error "*fails hold timing*"
        }
        pulse {set mock_pulse -0.01; set expected_error "*fails pulse-width timing*"}
        pulse_count {set mock_pulse_failures 1; set expected_error "*fails pulse-width timing*"}
        missing_clock {set mock_missing_clock 1; set expected_error "*Missing or ambiguous clock*"}
        wrong_period {set mock_oled_period 320.0; set expected_error "*Unexpected oled_clk period*"}
        missing_coverage {set mock_coverage_missing 1; set expected_error "*Cannot verify timing coverage*"}
        bad_summary {set mock_summary_bad 1; set expected_error "*No design timing summary row*"}
        route {set mock_status "route_design ERROR!"; set expected_error "*Implementation did not route*"}
        pass {}
        default {set mock_bad_coverage $scenario; set expected_error "*Incomplete internal timing coverage*"}
    }
    set mock_reports {}
    set failed [catch {source $checker_script} message]
    if {$expected_error eq ""} {
        if {$failed} {error "Unexpected checker failure: $message"}
    } elseif {!$failed || ![string match $expected_error $message]} {
        error "Unexpected checker result for $scenario ($mock_status): $message"
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
puts "PASS Vivado checker: 18 mocked routing, clock coverage, period, setup/hold/pulse and report-export cases"

# Optional real-format fixture: validate parsing only, not the current RTL.
# A historical report must never be presented as a fresh implementation.
if {[llength $argv]>1} {
    set fixture_file [open [lindex $argv 1] r]
    set fixture_report [read $fixture_file]
    close $fixture_file
    check_internal_coverage $fixture_report
    check_pulse_width $fixture_report
    puts "PASS historical Vivado report format parsing (not current-branch timing verification)"
}
