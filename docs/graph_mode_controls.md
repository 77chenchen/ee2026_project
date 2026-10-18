# Graph mode controls

The main project boots into a small `D GRAPH` menu. Press `BTND` to enter Graph
Mode. Raise `SW15` at any point to return to the menu.

## Input flow

1. `COUNT`: set `SW0=0` for one graph or `SW0=1` for two, then press `BTNC`.
2. `TYPE1/TYPE2`: set `SW0=0` for linear or `SW0=1` for quadratic, then press `BTNC`.
3. Enter signed 8-bit two's-complement coefficients on `SW7..SW0` and press
   `BTNC` after each value. Linear functions skip `A`; quadratic functions use
   `y = Ax^2 + Bx + C`.
4. At `READY`, first return `SW14` low if necessary, then raise it to draw.
5. Raise `SW15` at any time to reset/back to the first graph-input screen.

## Graph-view controls

| Switch mode | Buttons | Action |
| --- | --- | --- |
| `SW12=0, SW13=0` | `BTNU/D/L/R` | Pan the graph origin. |
| `SW12=0, SW13=1` | `BTNU/BTND` | Zoom in/out; scale range is 1-8 pixels per unit. |
| `SW12=0, SW13=1` | `BTNL/BTNR` | Pan horizontally. |
| `SW12=1` | `BTNU/D/L/R` | Move the cyan cursor in half-unit steps. |

Line 1 is green and line 2 is orange. Linear intersections are shown in white.
The renderer displays `PAR`, `SAME`, `OUT`, or `ERR` when an intersection is not
valid. Quadratic graphs are rendered, but the controller intentionally does not
claim a quadratic intersection because that requires a separate root solver.

The LEDs expose controller state, readiness, draw state, status, intersection
validity and zoom scale for board-level debugging.
