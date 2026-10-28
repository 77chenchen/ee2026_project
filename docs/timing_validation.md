# Timing branch: implementation and verification

## Baseline and scope

`timing` starts from remote `main` commit `e6335b5`. It ports the existing
timing repairs without adding mouse hardware, changing the JB OLED pinout,
or rewriting the menu/debouncer. The archived teammate sources, including
Oskar's original `graph_controller.v`, remain unchanged.

| Requirement | Implementation |
| --- | --- |
| OLED-domain display state | Graph, calculator/history and triangle display snapshots use the OLED rising edge. The OLED SPI core consumes pixels on the falling edge. |
| Bounded arithmetic stages | Calculator division takes eight restoring steps; triangle square root takes eight restoring steps. Quadratic discriminant products, subtraction, sign/root classification, trial-square comparison, division and coordinate projection are separate stages. Curve evaluation also registers products before projection/clipping. |
| Aligned curve readout | Cache bounds, their validity and the pixel row are registered on the OLED rising edge. Rebuilding tables are masked. |
| Complete internal clock checks | The real 100 MHz input and its related divide-by-16 OLED clock are constrained. No false-path or multicycle exception is added to hide a failing data path. |

The top-level changes are limited to OLED startup reset and the clock/frame
connections required by these display snapshots. The calculator, triangle
and graph keep their existing user controls and functionality.

## Local regression

Run from the repository root:

```sh
./scripts/run_tests.sh
```

The suite exhausts all 65,536 signed 8-bit division input pairs, includes
32,772 triangle cases, and has an independent pixel oracle
checking 24,576 actual serialized OLED RGB565 words across four graph frames.
It covers linear/quadratic/cubic rendering, both intersection markers, zoom
and pan. The Tcl checker has 18 mocked control-flow cases, including negative
setup/hold/pulse slack, missing/wrong clocks, incomplete clock coverage and
failed routing. Mock checks do **not** perform FPGA implementation.

## Fresh implementation on the Windows Vivado machine

Use the **timing branch**, not `main` or an older Desktop/Documents copy.
If using Git, update the checkout before opening Vivado:

```sh
git fetch origin
git switch timing
git pull --ff-only origin timing
git log -1 --oneline
```

Save and close any currently open Vivado project. In the Tcl Console, source
the checker from the actual checkout (replace the example absolute path):

```tcl
source {C:/path/to/ee2026_project/FDP2026/check_vivado_resources.tcl}
```

The checker opens the adjacent `FDP2026.xpr`, resets synthesis/implementation,
then runs through `route_design`. It does not program the board. Reports are
written beside that XPR in `vivado_resource_reports/`:

- `synthesis_utilization.txt`, `routed_utilization.txt`
- `routed_timing.txt`, `timing_coverage.txt`
- `worst_setup_paths.txt`, `worst_hold_paths.txt`
- `clock_pair_paths.txt`, `failing_setup_endpoints.txt`

A routed design with failed timing still produces its diagnostic reports.
Routing failure itself is rejected. After export, acceptance requires:

- `sys_clk_pin` period 10 ns and `oled_clk` period 160 ns;
- zero missing/constant/ambiguous/disconnected clocks, unconstrained internal
  endpoints, combinational loops or latch loops in the checked categories;
- nonnegative routed setup, hold and pulse-width slack, with no failing
  pulse-width endpoints;
- resources within XC7A35T LUT/register/BRAM/DSP capacities.

The checker fails closed if its coverage/pulse summary cannot be parsed.
External input/output delay warnings must still be reviewed separately:
passing these **internal** checks is not a board-level I/O timing signoff.
No arbitrary zero I/O delays or blanket false paths are added.

For the meaning of coverage checks and command options, see AMD's official
[Check Timing section](https://docs.amd.com/r/en-US/ug906-vivado-design-analysis/Check-Timing-Section)
and [check_timing command](https://docs.amd.com/r/2023.1-English/ug835-vivado-tcl-commands/check_timing).

## Verification status

Vivado is not installed on the development Mac. RTL regressions and mocked
checker tests can run locally; fresh routed slack/resource results must come
from the Windows Vivado run above. Reports from earlier commits cannot certify
this branch. After implementation passes, generate a new bitstream and check
the OLED/menu, calculator/history, triangle and graph modes on the Basys3.
