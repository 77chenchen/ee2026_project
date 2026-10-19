# EE2026 Interactive FPGA Graphical Calculator

This repository contains one integrated Basys3 bitstream design for Group 06.
The top level combines the work from all four members:

- Milla: signed switch input, invalid-operation checking and overflow checking.
- Hanna: four-operation calculator and calculator OLED interface.
- Oskar: graph input controller, line/quadratic parameters, linear intersection mathematics and view controls.
- Wang: graph OLED renderer, graph UI and final OLED/top-level integration.

The active Vivado project is `FDP2026/FDP2026.xpr`. The active top module is
`My_Top_Module`. Development is currently on the local `test` branch.

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
| `BTNL` | Enter Calculator Mode |
| `BTND` | Enter Graph Mode |
| `SW15` | Return to the main menu from either mode |

The menu shows `L CALC` in green and `D GRAPH` in orange.

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
| `SW13=0` | `BTNU/D/L/R` | Pan vertically/horizontally |
| `SW13=1` | `BTNU/BTND` | Zoom in/out (`1, 2, 4, 8` pixels per unit) |
| `SW13=1` | `BTNL/BTNR` | Pan horizontally |

Graph status meanings:

| Status | Meaning |
| --- | --- |
| `PAR` | Two linear graphs are parallel |
| `SAME` | Two linear graphs are identical |
| `OUT` | The intersection is outside the visible OLED area |
| `ERR` | The fixed-point intersection result overflowed |

## OLED and Pmod connection

The design uses the supplied `Oled_Display` interface at 6.25 MHz and the
96 x 64 RGB565 pixel contract. The OLED is connected to Pmod `JA`:

| JA bit | OLED signal |
| ---: | --- |
| 0 | `CS` |
| 1 | `SDIN` |
| 2 | unused, driven low |
| 3 | `SCLK` |
| 4 | `D/C` |
| 5 | `RESN` |
| 6 | `VCCEN` |
| 7 | `PMODEN` |

The OLED driver includes verified fixes for the initial power-settling delay
and transmission of pixel 6143, so a frame contains all 6144 pixels. Renderer
state is copied only at frame boundaries to prevent a mixed old/new frame when
the user presses a control.

## LEDs

- Menu: `LED0` is on.
- Calculator: `LED1` is on; other LEDs expose calculator state, validity,
  divide-by-zero, overflow and divider busy state.
- Graph: LEDs expose controller state, ready/draw, current graph, graph count,
  graph status, intersection validity and zoom scale.

## Build in Vivado

1. Open `FDP2026/FDP2026.xpr` in Vivado 2025.2 or a compatible version.
2. Confirm `My_Top_Module` is the synthesis top.
3. Confirm `Basys3_Master.xdc` is active.
4. Run **Synthesis**, **Implementation**, then **Generate Bitstream**.
5. Check timing, DRC and utilization before programming the board.
6. With board power off, connect the OLED to `JA`; power on and program the
   generated bitstream.

Vivado is not installed in the current development environment, so final
synthesis/timing/bitstream generation and physical Basys3/OLED verification
must still be run in the lab. The RTL and OLED protocol are covered by the
simulations below.

## Run simulations

Requirements: `iverilog` and `vvp` on `PATH`.

```bash
./scripts/run_tests.sh
```

The suite checks:

- button debounce and one-pulse behaviour;
- calculator arithmetic, signed division, division by zero and overflow;
- calculator/menu OLED screens;
- graph input FSM, linear intersection, parallel/identical/off-screen cases;
- graph line/quadratic rendering, marker, status, pan and zoom;
- OLED power/reset timing and a complete 6144-pixel serial frame;
- integrated menu -> calculator -> menu -> graph -> menu navigation.

The resource-constrained top level omits the optional PS/2 mouse, calculator
history and coordinate cursor extensions. Their source files remain in the
repository history, but they are not included in the Vivado synthesis set.

## Important source files

- `FDP2026/FDP2026.srcs/sources_1/new/My_Top_Module.v`: integrated top level.
- `calculator_mode.v`, `calculator_renderer.v`: calculator logic and OLED UI.
- `graph_controller.v`, `graph_renderer.v`: graph logic and OLED UI.
- `signed_switch_input.v`, `check_invalid.v`, `check_overflow.v`,
  `calculation_history.v`: shared input/validation blocks and the optional,
  disabled history implementation.
- `Oled_Display.v`: supplied SSD1331 interface with the two verified fixes noted above.
- `FDP2026/FDP2026.srcs/sim_1/new/`: self-checking testbenches.

Do not use the standalone `Hannas_part` or `sw_to_binary` projects for the final
bitstream; they are retained only as historical teammate work. Use the main
`FDP2026.xpr` project.
