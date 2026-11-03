# EE2026 FPGA graphical calculator

Group 06's active design targets the Basys3 `xc7a35tcpg236-1` and a 96 × 64
RGB565 OLED on Pmod JB. The top-level menu and board ports follow Hanna's
2026-10-26 `My_Top_Module.v`. Her original archive, Milla's sources, and
Oskar's original `graph_controller.v` are preserved under `FDP2026/team_sources/`.
Graph extensions live in separate adapter, solver and renderer files.

## Implemented modes

- Calculator: signed 8-bit two's-complement input; addition, subtraction,
  multiplication and division; full result, invalid and overflow displays.
- Graph: one or two linear `y=Bx+C`, quadratic `y=Ax²+Bx+C`, or cubic
  `y=Ax³+Bx²+Cx+D` plots. A mixed pair is allowed. Graph 1 is green and
  Graph 2 orange, with axes, grid, zoom and pan.
- Graph intersections: two linear, linear–quadratic and two quadratic graphs.
  The latter two can have zero, one or two real roots. Visible roots receive
  white crosses; `PAR`, `SAME`, `OUT`, `NO` or `ERR` is shown when appropriate.
  Cubic intersections are not implemented; cubic graphs are plot-only.
- Right-angle triangle mode from Hanna's top-level integration.

## How to use the board

Connect the OLED to Pmod JB before powering the Basys3, then program the
bitstream built from `FDP2026/FDP2026.xpr`. Start with `SW14` and `SW15` down.
In the main menu, `BTNU`/`BTND` move among Calculator, Graph and Triangle;
press `BTNC` to enter the highlighted mode. In any mode, raise `SW15` to
return to the menu, then lower it before entering another mode. Button presses
are debounced and routed only to the selected mode.

### Graph

1. At `COUNT`, set `SW0=0` for one graph or `SW0=1` for two; press `BTNC`.
2. At `TYPE1` (and later `TYPE2` if you selected two graphs), choose a line
   with `SW1=0, SW0=0`, a quadratic with `SW1=0, SW0=1`, or a cubic with
   `SW1=1` (`SW0` is ignored for cubic); press `BTNC`.
3. For every coefficient shown at the top of the OLED, set `SW7..SW0` to its
   signed 8-bit two's-complement value and press `BTNC` to save it. For
   example, `1111_1011` is −5. A line needs `B,C` for `y=Bx+C`; a quadratic
   needs `A,B,C`; a cubic needs `A,B,C,D`. Complete Graph 2 the same way if
   requested. The current value is shown on the OLED before saving.
4. At `READY`, move `SW14` from down to up to draw. Graph 1 is green and
   Graph 2 orange. Visible linear/quadratic intersections have white crosses;
   the upper-right status may show `PAR`, `SAME`, `OUT`, or `NO`. Cubic
   intersections are not calculated.
5. In the graph view, `BTNL`/`BTNR` pan left/right and `BTNU`/`BTND` pan
   up/down. With `SW13` up, `BTNU` zooms in and `BTND` zooms out through
   1/8, 1/4, 1/2, 1, 2, 4 and 8 pixels per graph unit; `BTNL`/`BTNR` still
   pan horizontally. The current scale appears at the lower right of the plot
   (for example, `S1/8` is the widest view).
   Lower `SW13` to use up/down for vertical panning again. To enter new
   coefficients, return to the menu with `SW15` and re-enter Graph.
6. Raise `SW12` while viewing the graph to read the X and Y coordinates of
   each visible intersection. Values are shown to two decimal places (rounded
   from the solver's 1/16-unit precision). Lower `SW12` to see the plot again.
   If no intersection is visible, the page shows `NO ROOT DATA`; the status
   label distinguishes parallel, identical, no-real-root and off-screen cases.

The OLED labels each input stage. At scales below 4, grid lines stay at least
eight pixels apart. The curve cache rebuilds when coefficients or view
settings change; the renderer waits for that rebuild to finish before showing
the curves.

### Calculator

1. Set the first signed number on `SW7..SW0` and press `BTNC`.
2. Choose an operation: `BTNU` adds, `BTND` subtracts, `BTNL` multiplies,
   and `BTNR` divides. Press `BTNC` to confirm the operation.
3. Set the second number on `SW7..SW0` and press `BTNC` to calculate.
   Division by zero is shown as invalid; results outside the signed 8-bit
   range are flagged as overflow.
4. Raise `SW14` on the result screen to start another calculation, then
   lower it. `SW13` shows the saved history. When selecting either operand,
   `SW8`, `SW9`, or `SW10` recalls the newest, second-newest, or third-newest
   saved result, respectively; only existing results within the signed
   8-bit range can be used as operands.

### Right-angle triangle

1. Press `BTNU` to calculate the hypotenuse from two legs, or `BTND` to
   calculate a missing leg from the hypotenuse and the other leg. Press
   `BTNC` to confirm.
2. Set the first prompted value on `SW6..SW0` and press `BTNC`; repeat for
   the second value. Inputs are unsigned integers from 0 to 127.
3. Read the calculated side on the OLED. An impossible leg calculation is
   marked invalid. Raise `SW14` to reset this mode, then lower it before
   starting again.

The optional PS/2 mouse and coordinate cursor are not part of the active
project; unused prototype modules were removed from `sources_1/new`.

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

On a machine with Icarus Verilog, run:

```sh
./scripts/run_tests.sh
```

The suite checks controller input, 0/1/2 intersections, signed cubic and
quadratic pixels at multiple zoom levels, both markers, the coordinate page,
OLED reset and all
6144 transmitted pixels, and routing through Hanna's top-level menu.

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
