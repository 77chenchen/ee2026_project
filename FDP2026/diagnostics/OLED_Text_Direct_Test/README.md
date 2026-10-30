# OLED direct graph-text diagnostic

This diagnostic uses the exact Graph `COUNT` and `SAVE` glyph bitmaps and
locations from `graph_renderer.v`, but sends them through `Oled_Display`
without the graph controller, intersections, curve renderer, or main project
mux. It uses the same OLED address staging as the current design.

In Vivado's Tcl Console, run
`source {C:/path/to/ee2026_project/FDP2026/diagnostics/OLED_Text_Direct_Test/build.tcl}`.
Program the printed bitstream, then power off before connecting the Pmod to JB.

Expected display:

- SW0=0: yellow `COUNT` at the Graph input-page title location.
- SW0=1, SW1=0: yellow `SAVE` at the Graph lower-left prompt location.
- SW0=1, SW1=1: yellow `COUNT` and `SAVE` together, useful for checking
  both regions without changing the switch between screenshots.

Compare missing pixels against the uniform-color diagnostic. If fixed dark
spots appear here but the same glyph data is correct in RTL, capture the
Vivado elaborated netlist/schematic for the listed glyphs and the JB outputs.
