#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
src="$repo_root/FDP2026/FDP2026.srcs/sources_1/new"
sim="$repo_root/FDP2026/FDP2026.srcs/sim_1/new"
oskar_src="$repo_root/FDP2026/team_sources/hanna_2026_10_17"
build_dir="$(mktemp -d "${TMPDIR:-/tmp}/ee2026-tests.XXXXXX")"
trap 'rm -rf "$build_dir"' EXIT

run_tb() {
    local top="$1"
    shift
    echo "[TEST] $top"
    iverilog -g2012 -Wall -s "$top" -o "$build_dir/$top" "$@"
    vvp "$build_dir/$top"
}

run_tb button_onepulse_tb \
    "$src/button_onepulse.v" "$sim/button_onepulse_tb.v"

run_tb graph_controller_tb \
    "$oskar_src/graph_controller.v" "$src/graph_cubic_input.v" \
    "$src/graph_quadratic_intersections.v" "$src/graph_controller_adapter.v" \
    "$sim/graph_controller_tb.v"

run_tb graph_extensions_tb \
    "$src/graph_quadratic_intersections.v" "$sim/graph_extensions_tb.v"

run_tb mouse_graph_adapter_tb \
    "$src/mouse_graph_adapter.v" "$sim/mouse_graph_adapter_tb.v"

run_tb graph_renderer_tb \
    "$src/graph_curve_cache.v" "$src/graph_renderer.v" \
    "$sim/graph_renderer_tb.v"

run_tb oled_display_tb \
    "$src/Oled_Display.v" "$sim/oled_display_tb.v"

run_tb integration_tb \
    "$src/clock_hz.v" "$src/debounce.v" \
    "$src/signed_switch_input.v" "$src/check_invalid.v" \
    "$src/check_overflow.v" "$src/calculation_history.v" \
    "$src/calculator.v" "$src/switch_to_binary.v" \
    "$src/history_renderer.v" "$src/owerflow_renderer.v" \
    "$src/right_angle_triangle.v" "$src/triangle_renderer.v" \
    "$oskar_src/graph_controller.v" "$src/graph_cubic_input.v" \
    "$src/graph_quadratic_intersections.v" "$src/graph_controller_adapter.v" \
    "$src/graph_curve_cache.v" "$src/graph_renderer.v" \
    "$src/graph_mode_integration.v" "$src/Oled_Display.v" \
    "$src/My_Top_Module.v" "$sim/integration_tb.v"

echo "All EE2026 simulations passed."
