# EE2026 FPGA graphical calculator

Group 06's active design targets the Basys3 `xc7a35tcpg236-1` and a 96 × 64
RGB565 OLED on Pmod JB. The top-level menu and board ports follow Hanna's
2026-10-26 `My_Top_Module.v`. Her original archive, Milla's sources, and
Oskar's original `graph_controller.v` are preserved under `FDP2026/team_sources/`.
Graph extensions live in separate adapter, solver and renderer files.

## Implemented modes

- Calculator: signed 8-bit two's-complement input; addition, subtraction,
  multiplication and division; full result, invalid and overflow displays.
  Division uses eight clocked steps after the second operand is saved, so a
  recalled history value does not feed a combinational divider in one cycle.
- Graph: one or two linear `y=Bx+C`, quadratic `y=Ax²+Bx+C`, or cubic
  `y=Ax³+Bx²+Cx+D` plots. A mixed pair is allowed. Graph 1 is green and
  Graph 2 orange, with axes, grid, zoom and pan.
- Graph intersections: two linear, linear–quadratic and two quadratic graphs.
  The latter two can have zero, one or two real roots. Visible roots receive
  white crosses; `PAR`, `SAME`, `OUT`, `NO` or `ERR` is shown when appropriate.
  Cubic intersections are not implemented; cubic graphs are plot-only.
- Right-angle triangle mode from Hanna's top-level integration.

## Controls

In the main menu, `BTNU`/`BTND` move among Calculator, Graph and Triangle;
`BTNC` enters the highlighted mode. `SW15` returns to the menu. Buttons are
debounced and routed only to the active mode. `SW7..SW0` represent a signed
8-bit two's-complement number: for example `1111_1011` means −5.

For Graph Mode:

1. At `COUNT`, set `SW0=0` for one graph or `SW0=1` for two, then press `BTNC`.
2. At `TYPE1` (and `TYPE2` if needed), select line with `SW0=0, SW1=0`,
   quadratic with `SW0=1, SW1=0`, or cubic with `SW1=1`. Press `BTNC`.
3. Set each coefficient on `SW7..SW0` and press `BTNC` to save it. A line
   takes `B,C`; a quadratic takes `A,B,C`; a cubic takes `A,B,C,D`.
4. At `READY`, lower and then raise `SW14` to draw. In the graph view,
   `BTNL`/`BTNR` pan horizontally and `BTNU`/`BTND` pan vertically.
   Holding `SW13` changes the latter buttons to zoom in/out through
   1, 2, 4 and 8 pixels per unit.

The OLED labels the current input stage and shows the signed switch value.
At zoom 1 or 2, the grid remains at least eight pixels apart so it does not
cover the curves. A plot cache is rebuilt after coefficients or view settings
change; rendering resumes from the next complete OLED frame.

The optional PS/2 mouse and coordinate cursor modules remain in the
repository, but are excluded from the resource-constrained synthesis top.

## Build and test

The active Vivado project is `FDP2026/FDP2026.xpr`, synthesis top
`My_Top_Module`. If its saved paths do not open on another computer,
start Vivado without a project and run:

```tcl
source {C:/path/to/ee2026_project/FDP2026/recreate_project.tcl}
```

This builds a portable project at `FDP2026/vivado_rebuilt/FDP2026.xpr`.
The Basys3 XDC must be active. Connect the OLED to Pmod JB with power off;
`JB[0:7]` map to CS, SDIN, unused, SCLK, D/C, RESN, VCCEN and PMODEN.
The top level asserts an OLED startup reset before the driver's power-up
delay; the display should show the menu without any button press.

On a machine with Icarus Verilog, run:

```sh
./scripts/run_tests.sh
```

The suite checks controller input, 0/1/2 intersections, signed cubic and
quadratic pixels at multiple zoom levels, both markers, OLED reset and all
6144 transmitted pixels, and routing through Hanna's top-level menu.
It also covers calculator signed division, history recall, divide-by-zero,
overflow and the top-level OLED startup reset.

For **actual FPGA resource and timing verification**, open the checked-in
Vivado project and run this script in Vivado batch mode (adjust the path):

```sh
vivado -mode batch -source C:/path/to/ee2026_project/FDP2026/check_vivado_resources.tcl
```

The script resets and reruns synthesis and implementation, checks XC7A35T
LUT/flip-flop/BRAM/DSP limits and 100 MHz routed setup slack, and writes
reports to `FDP2026/vivado_resource_reports/`. It does not generate or
program a bitstream. Vivado is not installed on this development machine;
simulation passing is **not** a substitute for a passing implementation
report and on-board OLED check.

The graph curve cache reuses one multiplier across columns. The intersection
solver also reuses a sequential divider instead of instantiating a wide
combinational divider. These choices reduce logic use, but only a fresh
Vivado report can establish whether the final design fits and meets timing.
