set diag_root [file dirname [file normalize [info script]]]
set fpga_root [file normalize [file join $diag_root .. ..]]

create_project OLED_Text_Direct_Test [file join $diag_root Vivado_Project] -part xc7a35tcpg236-1 -force
add_files [file join $diag_root OLED_Text_Direct_Test.v]
add_files [file join $fpga_root FDP2026.srcs sources_1 new clock_hz.v]
add_files [file join $fpga_root FDP2026.srcs sources_1 new Oled_Display.v]
add_files -fileset constrs_1 [file join $diag_root OLED_Text_Direct_Test.xdc]
set_property top OLED_Text_Direct_Test [get_filesets sources_1]
update_compile_order -fileset sources_1
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
if {![string match "write_bitstream Complete*" [get_property STATUS [get_runs impl_1]]]} {
    error "OLED direct text diagnostic implementation failed: [get_property STATUS [get_runs impl_1]]"
}
puts "Bitstream: [file join $diag_root Vivado_Project OLED_Text_Direct_Test.runs impl_1 OLED_Text_Direct_Test.bit]"
