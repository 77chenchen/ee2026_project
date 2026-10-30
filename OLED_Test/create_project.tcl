# Run this file in Vivado Tcl Console, not the calculator's FDP2026.xpr.
set test_root [file dirname [file normalize [info script]]]
set driver [file join [file dirname $test_root] FDP2026 FDP2026.srcs sources_1 new Oled_Display.v]
foreach source [list $driver [file join $test_root OLED_Test_Top.v] \
        [file join $test_root oled_test_pattern.v] [file join $test_root oled_test.xdc]] {
    if {![file exists $source]} {error "Required OLED test source missing: $source"}
}
create_project OLED_Test [file join $test_root vivado_project] -part xc7a35tcpg236-1 -force
set_property target_language Verilog [current_project]
add_files -norecurse [list $driver [file join $test_root OLED_Test_Top.v] \
    [file join $test_root oled_test_pattern.v]]
add_files -norecurse -fileset constrs_1 [file join $test_root oled_test.xdc]
set_property top OLED_Test_Top [get_filesets sources_1]
update_compile_order -fileset sources_1
puts "Standalone OLED project: [file join $test_root vivado_project OLED_Test.xpr]"
puts "Top: OLED_Test_Top. OLED is on JB. All switches OFF selects RED."
