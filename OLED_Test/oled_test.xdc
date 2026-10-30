# Basys3 xc7a35tcpg236-1, 100 MHz W5 oscillator.
set_property -dict {PACKAGE_PIN W5 IOSTANDARD LVCMOS33} [get_ports CLOCK]
create_clock -name sys_clk -period 10.000 [get_ports CLOCK]
create_generated_clock -name oled_clk -source [get_ports CLOCK] -divide_by 16 \
    [get_pins oled_clk_reg/Q]

# Whole two-row JB header; keep OLED GND/VCC aligned with the board labels.
foreach {port pin} {JB[0] A14 JB[1] A16 JB[2] B15 JB[3] B16
                    JB[4] A15 JB[5] A17 JB[6] C15 JB[7] C16} {
    set_property -dict [list PACKAGE_PIN $pin IOSTANDARD LVCMOS33] [get_ports $port]
}
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
