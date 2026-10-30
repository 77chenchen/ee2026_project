# OLED fixed-text-gap investigation

## Baseline

This branch starts at `origin/oled-text-fix` commit
`ebf3c8056cbf24ac9af682987eead0f05f4b2ea7`. Its tracked tree is byte-for-byte
identical to `b765c89fc9d1ea113dd7a302b2cb63e1f2a8946d`. The failing symptom is
reproduced on hardware after reseating the Pmod and programming a newly
generated bitstream. The missing strokes remain in the same locations in the
menu, Graph `COUNT`, and the Graph lower-left prompt.

## Evidence reviewed

### RTL behavior

The complete baseline regression suite was rerun locally and passed. Existing
tests include six full OLED frames (24,576 RGB565 words), a 196,608-pixel
direct graph rendering oracle, menu integration, and calculator/triangle
regressions. They show that the RTL model emits the intended pixels for the
affected text regions.

### Vivado timing report

`oled_text_timing.rpt` is a fresh routed report from Vivado 2025.2 at
2026-10-30 17:50:35. It contains:

* `sys_clk_pin` WNS `+0.675 ns`, WHS `+0.030 ns`, WPWS `+4.500 ns`;
* `oled_clk` WNS `+61.586 ns`, WHS `+0.187 ns`, WPWS `+79.500 ns`;
* zero internal unconstrained endpoints, missing clocks, constant clocks,
  pulse-width failures, loops, or latch loops;
* 19 inputs without `set_input_delay` and 6 outputs without
  `set_output_delay`.

The reported inter-clock paths are only internal register paths. The report
does not contain any timing endpoint ending at a `JB` output pad. Therefore it
does not prove or disprove board-level OLED interface timing. The internal
timing evidence does not support a setup/hold-induced fixed missing stroke.

### Static RTL-to-synthesis risk

`graph_renderer.v` calls its `font_pixel` function with the module-local
signals `px` and `py`, which are aliases assigned to `render_x` and `render_y`.
Most other positional expressions in the same always block also use `px` and
`py`. This is legal RTL and matches Icarus behavior, but the affected text is
the only region that repeatedly passes these aliases through a function call.
This remains a Vivado elaboration audit item; there is not yet evidence of a
synthesis bug, and no RTL was changed on that speculation.

The routed report's worst OLED-domain path ends at
`graphnator/graph_view/render_y_reg[3]/D`. This confirms the pipeline registers
were reached and constrained, not that every real I/O board interface is timed.

## Added board diagnostics

The previous uniform diagnostic from commit `ab4ae7c` was restored in
`FDP2026/diagnostics/OLED_Uniform_Test`. It uses the project's OLED driver but
no fonts, calculator, triangle, graph maths, or project mux. Four solid colors
are selected with SW1/SW0: white, red, green, and blue. The same fixed dark
locations across all colors indicate panel hardware; a uniform screen supports
a data-path fault.

A new `FDP2026/diagnostics/OLED_Text_Direct_Test` isolates the exact affected
`COUNT` and `SAVE` glyphs from the normal integration path. It still uses the
project OLED driver and the same OLED coordinate staging, but excludes the
graph controller, intersections, curve renderer, and main mux. SW0 selects
`COUNT` or `SAVE`; both switches up display both regions. It can distinguish a
main integration/mux fault from a glyph-region implementation fault.

Build either diagnostic with its `build.tcl`. Neither changes the main
`.xpr` or top module. Do not leave a bright full-screen uniform image on the
OLED for an extended period.

## Verification status

Verified locally:

* `./scripts/run_tests.sh` passes on this branch's baseline.
* The routed timing report was reviewed for internal clock coverage and
  clock-pair slacks.

Not yet verified:

* Windows Vivado synthesis and implementation of the two diagnostics.
* The solid-color board test.
* The direct text board test.
* Vivado elaborated-schematic inspection of the `COUNT`/`SAVE` glyph logic if
  the direct diagnostic reproduces the same fixed gaps.
* Board-level JB output-delay constraints and measurements. The existing
  internal timing report is not board-level I/O signoff.

No main RTL was changed in this investigation because the current evidence does
not identify a safe, minimal functional fix. Adding another pixel offset was
explicitly rejected because both RTL SPI and the earlier hardware prefetch
test were negative.
