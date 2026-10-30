# OLED uniform-color diagnostic

This standalone Vivado top uses the project's working `Oled_Display.v` and
`clock_hz.v`, but no menu, Graph, calculator, triangle, or font logic.
It does **not** change the main project's top module or `.xpr` file.

In Vivado's Tcl Console, run `source {C:/path/to/ee2026_project/FDP2026/diagnostics/OLED_Uniform_Test/build.tcl}`.
After the status says `write_bitstream Complete!`, program the `.bit` path
printed by the script. Connect the PmodOLEDrgb to the full JB header.

With both SW0 and SW1 down, all 96 x 64 pixels should be white. SW0 up makes
the screen red; SW1 up makes it green; both up makes it blue. Inspect for
fixed dark pixels or rows, then return to the normal project bitstream.
Do not leave a bright full-screen image on the OLED for an extended period.

If every solid color is uniform, the panel can light all pixels and the
remaining defect is in the project pixel stream or its implementation. If
the same locations stay dark in solid colors, suspect panel hardware.
