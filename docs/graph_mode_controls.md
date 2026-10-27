# Graph mode controls

The main project boots into Hanna's two-entry menu. `BTNU` selects the upper
Calculator entry, `BTND` selects the lower Graph entry, and `BTNC` enters the
selection. Raise `SW15` at any point to return to the menu.

## Input flow

1. `COUNT`: set `SW0=0` for one graph or `SW0=1` for two, then press `BTNC`.
2. `TYPE1/TYPE2`: set `SW0=0` for linear or `SW0=1` for quadratic, then press `BTNC`.
3. Enter signed 8-bit two's-complement coefficients on `SW7..SW0` and press
   `BTNC` after each value. Linear functions skip `A`; quadratic functions use
   `y = Ax^2 + Bx + C`.
4. At `READY`, first return `SW14` low if necessary, then raise it to draw.
5. Raise `SW15` at any time to reset/back to the first graph-input screen.

## Graph-view controls

| Graph view | Buttons | Action |
| --- | --- | --- |
| default | `BTNU/BTND` | Zoom in/out; scale range is 1-8 pixels per unit. |
| default | `BTNL/BTNR` | Pan horizontally. |

Line 1 is green and line 2 is orange. Linear intersections are shown in white.
The renderer displays `PAR`, `SAME`, `OUT`, or `ERR` when an intersection is not
valid. Quadratic graphs are rendered, but the controller intentionally does not
claim a quadratic intersection because that requires a separate root solver.

The final Hanna-based top level uses `JB[7:0]` for the OLED and does not expose
the earlier debug LED bus. `SW15` remains the mode-return control.
