# EE2026 Interactive FPGA Graphical Calculator

This repository contains the integrated Basys3 design for Group 06. The
synthesis top follows Hanna's 2026-10-17 archive (`Hanna_2026_10_17.xpr.zip`)
for its `CLOCK`, `sw`, button and `JB[7:0]` interface. The verified calculator
and graph logic from the main project is connected behind that interface.

- Milla: signed switch input, invalid-operation checking and overflow checking.
- Hanna: four-operation calculator and calculator OLED interface.
- Oskar: graph input controller, line/quadratic parameters, linear intersection mathematics and view controls.
- Wang: graph OLED renderer, graph UI and final OLED/top-level integration.

The active Vivado project is `FDP2026/FDP2026.xpr`. The active synthesis top is
`My_Top_Module` and the simulation top is `integration_tb`. The port and menu
convention is the Hanna 2026-10-17 convention, not the older `BTNL`/`JA`
convention in the standalone archive copies.

## Implemented functions

### Calculator

- Signed 8-bit two's-complement input from `SW7..SW0`.
- Addition, subtraction, multiplication and division.
- Full signed 16-bit result display.
- Division-by-zero error display.
- Overflow warning when the result is outside the signed 8-bit input range.
- No FPGA reprogramming is needed between calculations.

### Graph Mode

- One or two graphs.
- Linear functions: `y = Bx + C`.
- Quadratic functions: `y = Ax^2 + Bx + C`.
- Green Graph 1 and orange Graph 2.
- Axes, grid, clipping and continuous line/curve rendering.
- Exact intersection for two linear functions.
- `PAR`, `SAME`, `OUT` and `ERR` status overlays.
- Zoom and pan controls.
- Input-stage OLED guidance and signed coefficient preview.

## Hardware controls

### Main menu

| Control | Action |
| --- | --- |
| `BTNU` | Select the upper Calculator entry |
| `BTND` | Select the lower Graph entry |
| `BTNC` | Enter the selected mode |
| `SW15` | Return to the main menu from either mode |

The menu is Hanna's two-entry menu: **Calculator is the upper/initial choice**
and **Graph is the lower choice**. A cyan ">" marker and the selected entry's
highlight show the current choice. `BTNU`/`BTND` only change the menu choice;
`BTNC` enters it. Once Calculator or Graph is active, menu buttons have no
menu effect and only that mode receives the button events. `SW15` returns to
the menu and resets the choice to Calculator.

### Signed switch input

`SW7..SW0` are interpreted as one signed 8-bit two's-complement number:

| Value | `SW7..SW0` |
| ---: | --- |
| `5` | `0000_0101` |
| `-1` | `1111_1111` |
| `-5` | `1111_1011` |
| `-128` | `1000_0000` |

Leave a switch value stable briefly before pressing `BTNC`. All buttons and
mode switches are synchronised/debounced by the design.

### Calculator Mode

1. Set Operand A on `SW7..SW0`; press `BTNC`.
2. Select the operation:
   - `BTNU`: add
   - `BTND`: subtract
   - `BTNL`: multiply
   - `BTNR`: divide
3. Press `BTNC` to confirm the operation.
4. Set Operand B on `SW7..SW0`; press `BTNC` to calculate.
5. Raise `SW14` to start a new expression. Lower it before the next use.

An `OVF` message means the full result is valid but outside the signed 8-bit
input range. `DIV0` means the attempted division was invalid.

### Graph Mode input

1. `COUNT`: set `SW0=0` for one graph or `SW0=1` for two; press `BTNC`.
2. `TYPE1/TYPE2`: set `SW0=0` for linear or `SW0=1` for quadratic; press `BTNC`.
3. Enter each signed coefficient on `SW7..SW0`, pressing `BTNC` after each:
   - Linear: `B`, then `C`.
   - Quadratic: `A`, then `B`, then `C`.
4. At `READY`, make sure `SW14` is low, then raise it to draw.

Graph view controls:

| Switch mode | Buttons | Action |
| --- | --- | --- |
| Graph view | `BTNU/BTND` | Zoom in/out (`1, 2, 4, 8` pixels per unit) |
| Graph view | `BTNL/BTNR` | Pan horizontally |

The graph view keeps the existing zoom/pan implementation. `BTNC` in the
coefficient-entry states saves only the current coefficient or choice; it is
not forwarded to the menu, so it cannot switch modes.

Graph status meanings:

| Status | Meaning |
| --- | --- |
| `PAR` | Two linear graphs are parallel |
| `SAME` | Two linear graphs are identical |
| `OUT` | The intersection is outside the visible OLED area |
| `ERR` | The fixed-point intersection result overflowed |

## OLED and Pmod connection

The design uses the supplied `Oled_Display` interface at 6.25 MHz and the
96 x 64 RGB565 pixel contract. The OLED is connected to Pmod `JB`:

| JB bit | OLED signal |
| ---: | --- |
| 0 | `CS` |
| 1 | `SDIN` |
| 2 | unused, driven low |
| 3 | `SCLK` |
| 4 | `D/C` |
| 5 | `RESN` |
| 6 | `VCCEN` |
| 7 | `PMODEN` |

`JB[2]` is tied low. The OLED driver includes verified fixes for the initial
power-settling delay and transmission of pixel 6143, so a frame contains all
6144 pixels. Renderer state is copied only at frame boundaries to prevent a
mixed old/new frame when the user presses a control.

### Frame snapshot

All renderer inputs are copied on `frame_begin` into frame-local registers.
The renderer and shared text plane therefore only see one coherent mode,
state, coefficient set and graph view during a complete 6144-pixel frame.

## Build in Vivado

1. Open `FDP2026/FDP2026.xpr` in Vivado 2025.2 or a compatible version.
2. Confirm `My_Top_Module` is the synthesis top.
3. Confirm `Basys3_Master.xdc` is active.
4. Run **Synthesis**, **Implementation**, then **Generate Bitstream**.
5. Check timing, DRC and utilization before programming the board.
6. With board power off, connect the OLED to `JB`; power on and program the
   generated bitstream.

The checked-in XPR retains the Windows project location used by the original
working project. If the repository is stored somewhere else, use the portable
rebuild script instead of editing paths inside the XPR:

1. Open Vivado without opening an existing project.
2. In the **Tcl Console**, run
   `source {C:/your/path/ee2026_project/FDP2026/recreate_project.tcl}`.
3. The script creates and opens
   `FDP2026/vivado_rebuilt/FDP2026.xpr` with the Basys3 part, active source
   set, constraints and simulation files already configured.

Use forward slashes in the Tcl command on Windows and keep the braces around
the complete path, especially when a folder name contains spaces.

Vivado is not installed in the current development environment, so final
synthesis/timing/bitstream generation and physical Basys3/OLED verification
must still be run in the lab. The RTL and OLED protocol are covered by the
simulations below.

The archived Hanna 2026-10-17 implementation used 1,462 LUTs, 321 FFs, no
BRAM and 6 DSPs after placement, but its archived routed timing summary was
**not met** (`WNS = -10.938 ns`, 16 failing setup endpoints, 534 total
endpoints). That report is for Hanna's calculator-only/earlier graph
integration and is **not** evidence that this combined design will meet
100 MHz. The maintained calculator core uses a multi-cycle divider, but the
graph arithmetic still needs a fresh Vivado timing run.

## Run simulations

Requirements: `iverilog` and `vvp` on `PATH`.

```bash
./scripts/run_tests.sh
```

The suite checks:

- button debounce and one-pulse behaviour;
- calculator arithmetic, signed division, division by zero and overflow;
- Hanna-style calculator/menu OLED screens;
- graph input FSM, linear intersection, parallel/identical/off-screen cases;
- graph line/quadratic rendering, marker, status, pan and zoom;
- OLED power/reset timing and a complete 6144-pixel serial frame;
- integrated boot -> Hanna menu -> calculator -> menu -> graph -> menu navigation;
- the upper/lower menu selection, `BTNC` entry and mode isolation;
- the OLED `JB` mapping and complete 6144-pixel frame.

The resource-constrained top level omits the optional PS/2 mouse, calculator
history and coordinate cursor extensions. Their source files remain in the
repository history, but they are not included in the Vivado synthesis set.
The archived Hanna and Milla sources are preserved under
`FDP2026/team_sources/` and are not compiled by the main project.

## Important source files

- `FDP2026/FDP2026.srcs/sources_1/new/My_Top_Module.v`: integrated top level.
- `calculator_mode.v`, `calculator_renderer.v`: verified signed calculator
  logic and OLED UI, used behind the Hanna-compatible top-level interface.
- `graph_controller.v`, `graph_renderer.v`: graph logic and OLED UI.
- `signed_switch_input.v`, `check_invalid.v`, `check_overflow.v`,
  `calculation_history.v`: shared input/validation blocks and the optional,
  disabled history implementation.
- `Oled_Display.v`: supplied SSD1331 interface with the two verified fixes noted above.
- `FDP2026/FDP2026.srcs/sim_1/new/`: self-checking testbenches.
- `FDP2026/team_sources/hanna_2026_10_17/`: original Hanna archive sources and
  archived utilization/timing reports, kept as member-code records.
- `FDP2026/team_sources/milla/`: original Milla source snapshots.

The old `FDP2026/Hannas_part/` directory is the earlier archive and is not the
2026-10-17 integration baseline.

Do not use the standalone `Hannas_part` or `sw_to_binary` projects for the final
bitstream; use the maintained `FDP2026.xpr` project.
