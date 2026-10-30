#!/usr/bin/env bash
set -euo pipefail
test_root="$(cd "$(dirname "$0")" && pwd)"
driver="$test_root/../FDP2026/FDP2026.srcs/sources_1/new/Oled_Display.v"
test_build_dir="$(mktemp -d "${TMPDIR:-/tmp}/oled-hardware-tests.XXXXXX")"
trap 'rm -rf "$test_build_dir"' EXIT
for top in pattern_tb controls_tb spi_tb; do
    echo "[TEST] $top"
    iverilog -g2012 -Wall -I "$test_root/tests" -s "$top" -o "$test_build_dir/$top" \
        "$test_root/oled_test_pattern.v" "$test_root/OLED_Test_Top.v" "$driver" "$test_root/tests/$top.v"
    vvp "$test_build_dir/$top"
done
echo "All standalone OLED tests passed. This is not physical-board or Vivado implementation verification."
