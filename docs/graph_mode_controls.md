# Graph mode controls

The main project boots into Hanna's Calculator / Graph / Triangle menu.
`BTNU`/`BTND` move the selection and `BTNC` enters it. Raise `SW15` at any
point to return to the menu.

## Input flow

1. `COUNT`: set `SW0=0` for one graph or `SW0=1` for two, then press `BTNC`.
2. `TYPE1/TYPE2`: set `SW0=0` for linear or `SW0=1` for quadratic, then press `BTNC`.
   `SW1` has no graph-type-selection role; there is no third-degree option.
3. Enter signed 8-bit two's-complement coefficients on `SW7..SW0` and press
   `BTNC` after each value. Linear functions skip `A`; quadratic functions use
   `y = Ax^2 + Bx + C`.
4. At `READY`, first return `SW14` low if necessary, then raise it to draw.
5. Raise `SW15` at any time to return to the main menu and reset graph input.

## Graph-view controls

| Graph view | Buttons | Action |
| --- | --- | --- |
| default | `BTNU/BTND` | Pan vertically. |
| default | `BTNL/BTNR` | Pan horizontally. |
| `SW13=1` | `BTNU/BTND` | Zoom in/out; scale range is 1-8 pixels per unit. |
| `SW13=1` | `BTNL/BTNR` | Pan horizontally. |

Graph 1 is green and graph 2 is orange. Linear, mixed linear/quadratic and
quadratic/quadratic intersections are shown as white crosses (up to two real
roots). The renderer displays `PAR`, `SAME`, `OUT`, `NO` or `ERR` when appropriate.
Direct curve rendering retains the minimum-zoom grid and steep-line continuity
fixes. There is no curve RAM or rebuild wait.

The final Hanna-based top level uses `JB[7:0]` for the OLED and does not expose
the earlier debug LED bus. `SW15` remains the mode-return control.
