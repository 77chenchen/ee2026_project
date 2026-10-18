#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
src="$repo_root/FDP2026/FDP2026.srcs/sources_1/new"
sim="$repo_root/FDP2026/FDP2026.srcs/sim_1/new"
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

run_tb calculator_mode_tb \
    "$src/check_invalid.v" "$src/check_overflow.v" \
    "$src/calculation_history.v" "$src/calculator_mode.v" \
    "$sim/calculator_mode_tb.v"

run_tb calculator_renderer_tb \
    "$src/calculator_renderer.v" "$sim/calculator_renderer_tb.v"

run_tb menu_renderer_tb \
    "$src/menu_renderer.v" "$sim/menu_renderer_tb.v"

run_tb graph_controller_tb \
    "$src/graph_controller.v" "$sim/graph_controller_tb.v"

run_tb mouse_graph_adapter_tb \
    "$src/mouse_graph_adapter.v" "$sim/mouse_graph_adapter_tb.v"

run_tb graph_renderer_tb \
    "$src/graph_renderer.v" "$sim/graph_renderer_tb.v"

run_tb oled_display_tb \
    "$src/Oled_Display.v" "$sim/oled_display_tb.v"

run_tb integration_tb \
    "$src/button_onepulse.v" "$src/switch_sync.v" \
    "$src/signed_switch_input.v" "$src/check_invalid.v" \
    "$src/check_overflow.v" "$src/calculation_history.v" \
    "$src/calculator_mode.v" "$src/calculator_renderer.v" \
    "$src/graph_controller.v" "$src/mouse_graph_adapter.v" \
    "$src/graph_renderer.v" \
    "$src/menu_renderer.v" "$src/Oled_Display.v" \
    "$src/My_Top_Module.v" "$sim/integration_tb.v"

echo "All EE2026 simulations passed."
