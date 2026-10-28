# Timing-main fix report

## Baseline

- Source branch: `origin/main`
- Baseline commit: `e6335b5bf851141ffc7047af74e7bcb504a2eb23`
- Work branch: `timing-main-fix`
- Independent worktree, created from `origin/main` only.

No timing-fix branch, cherry-pick, or copy of another worktree was used.

## Root causes found in the baseline

1. `calculator.v` had combinational signed `A / B` and a wide multiply on the
   100 MHz path.  The archived routed report showed the matching
   `operand_A -> result` path at 54 logic levels and 20.8 ns, but that report
   was from older RTL and is not evidence about the current baseline.
2. The OLED driver was clocked by a derived divider without a generated-clock
   constraint.  The archived report listed 115 unclocked endpoints and 228
   unconstrained internal endpoints in the same structure.
3. Graph, calculator, triangle and menu display logic used live 100 MHz state
   directly in the pixel multiplexer.  A control or coefficient change could
   affect a frame mid-transmission.
4. The triangle square root searched 128 candidates combinationally, and the
   quadratic intersection solver combined discriminant multiply, square root,
   division and coordinate scaling too aggressively.
5. The baseline still contained the cubic input FSM, fourth coefficient and
   cubic plotting path.

## Implemented changes

- Removed cubic selection, the `D` coefficient, cubic renderer state and all
  cubic tests/documentation.  Oskar's archived `graph_controller.v` and
  `team_sources/` were not modified.
- Added a serialized signed divider for calculator division.
- Added a serialized 15-bit square-root engine for triangle calculations.
- Split intersection discriminant, square-root trial, divider, sign extension,
  curve evaluation and visibility checks into explicit clock phases.
- Replaced the graph curve cache with direct, explicitly sized linear/quadratic
  evaluation in the OLED display domain.  The direct path uses two adjacent
  column samples so steep segments remain connected.
- Added a coherent frame-boundary snapshot handshake from the 100 MHz control
  domain to the 6.25 MHz OLED domain.  Calculator, graph and triangle state are
  captured as one stable word and published before the next `SendPixel`.
- Registered the final pixel output in each display path where required for
  the OLED falling-edge pixel load; no extra pixel of latency was added to the
  graph/triangle color path.
- Added a generated clock constraint for `clk_6_25/SLOW_CLOCK_reg/Q`, plus
  conservative input/output delay constraints for external I/O.
- Updated the Vivado project and portable recreation script to reference only
  the active sources and tests.

## Verification completed here

`./scripts/run_tests.sh` passes:

- button debounce/one-pulse;
- linear/quadratic input, mixed graph coefficients, menus and view controls;
- 0/1/2 real intersections and visibility status;
- serialized signed divider, square root and frame snapshot;
- first/last/row-boundary OLED pixels and all 6144 RGB565 serial words;
- calculator arithmetic, divide-by-zero, overflow, history and result recall
  through the integrated top;
- calculator/graph/triangle menu routing.

The test runner is Icarus Verilog only.  It validates RTL behavior and the
serial OLED protocol contract, not placement, routing, or on-board signal
integrity.

## Vivado verification still required

Vivado is not installed on this machine, so no fresh synthesis,
implementation, route, resource or timing claim is made here.  The archived
timing report under `team_sources/` describes an older implementation and
must not be used to accept this branch.

On a Vivado machine run:

```sh
vivado -mode batch -source C:/path/to/ee2026_project/FDP2026/check_vivado_resources.tcl
```

Review, at minimum:

- XC7A35T resources against LUT 20,800 / FF 41,600 / BRAM Tile 50 / DSP 90;
- routed setup, hold and pulse-width slack;
- `sys_clk_pin` and `oled_clk` clock coverage;
- no unclocked or unconstrained internal endpoints;
- the 100 MHz-to-6.25 MHz frame-snapshot crossing;
- external I/O delay warnings separately from internal timing;
- an on-board OLED frame check, including first pixel, row transitions and
  final pixel.

## Known risks

- The direct graph renderer intentionally trades area for simpler timing:
  several bounded multipliers run in the 6.25 MHz OLED domain.  Fresh
  utilization and timing reports are still required.
- The frame snapshot uses a held multi-bit bus qualified by a synchronized
  request toggle.  This is a deliberate CDC handshake, not a blanket false
  path; timing closure still needs to be checked in Vivado.
- External I/O delays are conservative placeholders and must be reviewed
  against the actual Pmod/board requirement.
