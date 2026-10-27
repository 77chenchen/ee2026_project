# Recreate the active Vivado project without any machine-specific paths.
# Run from any Windows directory in Vivado's Tcl Console:
#   source {C:/path/to/ee2026_project/FDP2026/recreate_project.tcl}

set origin_dir [file dirname [file normalize [info script]]]
set source_dir [file join $origin_dir FDP2026.srcs sources_1 new]
set sim_dir [file join $origin_dir FDP2026.srcs sim_1 new]
set constraints_dir [file join $origin_dir FDP2026.srcs constrs_1 new]
set project_dir [file join $origin_dir vivado_rebuilt]

create_project FDP2026 $project_dir -part xc7a35tcpg236-1 -force
set_property target_language Verilog [current_project]

set design_sources [list \
    [file join $source_dir Oled_Display.v] \
    [file join $source_dir clock_hz.v] \
    [file join $source_dir debounce.v] \
    [file join $source_dir signed_switch_input.v] \
    [file join $source_dir check_invalid.v] \
    [file join $source_dir check_overflow.v] \
    [file join $source_dir calculation_history.v] \
    [file join $source_dir history_renderer.v] \
    [file join $source_dir owerflow_renderer.v] \
    [file join $source_dir calculator.v] \
    [file join $source_dir calculator_signed_divider.v] \
    [file join $source_dir switch_to_binary.v] \
    [file join $origin_dir team_sources hanna_2026_10_17 graph_controller.v] \
    [file join $source_dir graph_cubic_input.v] \
    [file join $source_dir graph_quadratic_intersections.v] \
    [file join $source_dir graph_controller_adapter.v] \
    [file join $source_dir graph_curve_cache.v] \
    [file join $source_dir graph_renderer.v] \
    [file join $source_dir graph_mode_integration.v] \
    [file join $source_dir right_angle_triangle.v] \
    [file join $source_dir triangle_renderer.v] \
    [file join $source_dir My_Top_Module.v]]

set simulation_sources [list \
    [file join $sim_dir button_onepulse_tb.v] \
    [file join $sim_dir graph_controller_tb.v] \
    [file join $sim_dir graph_extensions_tb.v] \
    [file join $sim_dir graph_renderer_tb.v] \
    [file join $sim_dir graph_oled_tb.v] \
    [file join $sim_dir calculator_mode_tb.v] \
    [file join $sim_dir calculator_signed_divider_tb.v] \
    [file join $sim_dir calculator_renderer_tb.v] \
    [file join $sim_dir menu_renderer_tb.v] \
    [file join $sim_dir compact_text_renderer_tb.v] \
    [file join $sim_dir oled_display_tb.v] \
    [file join $sim_dir triangle_tb.v] \
    [file join $sim_dir integration_tb.v]]

foreach required_file [concat $design_sources $simulation_sources \
        [list [file join $constraints_dir Basys3_Master.xdc]]] {
    if {![file exists $required_file]} {
        error "Required project file not found: $required_file"
    }
}

add_files -norecurse -fileset sources_1 $design_sources
add_files -norecurse -fileset constrs_1 \
    [file join $constraints_dir Basys3_Master.xdc]
add_files -norecurse -fileset sim_1 $simulation_sources

set_property top My_Top_Module [get_filesets sources_1]
set_property top integration_tb [get_filesets sim_1]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

# Only the resource-constrained integrated sources above belong to this
# synthesis set.  The PS/2 VHDL controller and optional history/cursor
# adapters remain available in the repository but are deliberately excluded.
set source_files [get_files -of_objects [get_filesets sources_1]]
foreach optional_pattern {Mouse_Control.vhd Ps2Interface.vhd \
        mouse_graph_adapter.v} {
    foreach candidate $source_files {
        if {[string match "*$optional_pattern" $candidate]} {
            set_property is_enabled false $candidate
        }
    }
}

puts "Portable Vivado project created at: [file join $project_dir FDP2026.xpr]"
