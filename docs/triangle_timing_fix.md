# Triangle timing source fix

The 2026-11-02 Hanna archive routed with WNS -70.111 ns. Its worst setup
path was `triangle/c_reg[1]` to `triangle/a_reg[2]`: 80.064 ns of data delay
against a 10 ns requirement. The eight-step binary-search `sqrt` function
was combinational, so all iterations were in one clock path.

The active `FDP2026` project and the new source-only Hanna archive now use
an eight-cycle digit-by-digit integer square root. Squaring and radicand
formation have separate states. The module ports, board controls and
triangle renderer interface are unchanged. The original Hanna ZIP is kept
for provenance. The new ZIP is `project_2026_11_02_triangle_fix_sources.zip`.
It excludes the old bitstream and old routed reports, which do not describe
the fixed source. The ZIP also moves one calculator declaration before use
and braces `seg[7]` in the XDC for a clean rebuild.

Verification performed on macOS:

- `./scripts/run_tests.sh` passes, including 32,772 triangle cases covering
  both modes, maximum hypotenuse, invalid input and reset while busy.
- The standalone archive top elaborates with Icarus Verilog.
- The source ZIP passes `unzip -t` and the main XPR passes `xmllint`.

Vivado is unavailable on this machine. No new routed WNS, resource use,
bitstream or hardware behavior is claimed. On Windows, extract the new ZIP,
source its `build_triangle_fix.tcl`, rerun synthesis and implementation, and
inspect setup/hold/pulse-width timing before programming the board.
