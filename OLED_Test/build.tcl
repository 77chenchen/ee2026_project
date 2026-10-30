# Creates only the standalone OLED test project, reruns implementation,
# exports diagnostics and generates a bitstream only after timing passes.
set test_root [file dirname [file normalize [info script]]]
source [file join $test_root create_project.tcl]
set report_root [file join $test_root reports]
file mkdir $report_root
launch_runs synth_1 -jobs 4
wait_on_run synth_1
if {[get_property STATUS [get_runs synth_1]] ne "synth_design Complete!"} {
    error "OLED test synthesis failed"
}
launch_runs impl_1 -to_step route_design -jobs 4
wait_on_run impl_1
if {![string match "route_design Complete*" [get_property STATUS [get_runs impl_1]]]} {
    error "OLED test routing did not complete"
}
open_run impl_1
report_utilization -file [file join $report_root utilization.txt]
report_io -file [file join $report_root io.txt]
check_timing -verbose -file [file join $report_root coverage.txt]
set timing [report_timing_summary -report_unconstrained -return_string]
set fd [open [file join $report_root timing.txt] w]
puts $fd $timing
close $fd
foreach {clock period} {sys_clk 10.0 oled_clk 160.0} {
    set objects [get_clocks $clock]
    if {[llength $objects]!=1 || abs([get_property PERIOD $objects]-$period)>0.001} {
        error "Missing or incorrect OLED test clock $clock; see reports"
    }
}
if {![string match "*Timing constraints are met.*" $timing]} {
    error "OLED test timing has not passed; see $report_root"
}
close_design
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
if {![string match "write_bitstream Complete*" [get_property STATUS [get_runs impl_1]]]} {
    error "OLED test bitstream generation failed"
}
set bitfile [file join [get_property DIRECTORY [get_runs impl_1]] OLED_Test_Top.bit]
if {![file exists $bitfile]} {error "No generated OLED test bitstream: $bitfile"}
puts "PROGRAM THIS FILE: $bitfile"
puts "Power OFF before connecting/removing the OLED on JB."
