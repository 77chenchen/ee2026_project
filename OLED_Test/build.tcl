# Run in Vivado Tcl Console. All files are in this one OLED_Test folder.
set root [file dirname [file normalize [info script]]]
create_project OLED_Test [file join $root vivado_project] -part xc7a35tcpg236-1 -force
add_files -norecurse [file join $root OLED_Test_Top.v]
add_files -norecurse -fileset constrs_1 [file join $root oled_test.xdc]
set_property top OLED_Test_Top [get_filesets sources_1]
update_compile_order -fileset sources_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1
if {[get_property STATUS [get_runs synth_1]] ne "synth_design Complete!"} {
    error "OLED test synthesis failed"
}
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
if {![string match "write_bitstream Complete*" [get_property STATUS [get_runs impl_1]]]} {
    error "OLED test implementation failed"
}
puts "Program this bitstream: [file join $root vivado_project OLED_Test.runs impl_1 OLED_Test_Top.bit]"
