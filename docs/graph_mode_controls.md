# Graph mode controls

The main menu contains Calculator, Graph and Triangle. Use `BTNU`/`BTND` to
highlight Graph, then press `BTNC`. Raise `SW15` to return to the menu; lower
it before entering a mode again.

## Input flow

1. At `COUNT`, choose one graph with `SW0=0` or two with `SW0=1`; press `BTNC`.
2. At `TYPE1` and, if needed, `TYPE2`, select line (`SW1=0, SW0=0`), quadratic
   (`SW1=0, SW0=1`), or cubic (`SW1=1`); press `BTNC`.
3. Enter each signed 8-bit two's-complement coefficient with `SW7..SW0` and
   save it with `BTNC`. A line uses `B,C`, a quadratic `A,B,C`, and a cubic
   `A,B,C,D`. Repeat for the second graph when selected.
4. At `READY`, move `SW14` from low to high to draw. Returning to the menu and
   re-entering Graph starts a new input sequence.

## Graph view

| Control | Action |
| --- | --- |
| `BTNL` / `BTNR` | Pan horizontally. |
| `BTNU` / `BTND` with `SW13=0` | Pan vertically. |
| `BTNU` / `BTND` with `SW13=1` | Zoom in / out, from 1 to 8 pixels per unit. |
| `SW12=1` | Show X and Y for up to two visible intersections. Lower it to restore the plot. |
| `SW15=1` | Return to the main menu. |

Graph 1 is green, Graph 2 orange, and visible intersection markers are white.
The coordinate page rounds Q4 values to two decimal places. Intersections are
solved for pairs of lines and/or quadratics; cubic intersections are not
calculated. Status labels include `PAR`, `SAME`, `OUT`, `NO`, and `ERR`. A
coordinate is shown only when its intersection marker is visible on the OLED.
