set_property -dict {PACKAGE_PIN W5 IOSTANDARD LVCMOS33} [get_ports CLOCK]
create_clock -name sys_clk_pin -period 10.000 [get_ports CLOCK]
create_generated_clock -name oled_clk -source [get_ports CLOCK] -divide_by 16 [get_pins clk_6_25/SLOW_CLOCK_reg/Q]

set_property -dict {PACKAGE_PIN V17 IOSTANDARD LVCMOS33} [get_ports {sw[0]}]
set_property -dict {PACKAGE_PIN V16 IOSTANDARD LVCMOS33} [get_ports {sw[1]}]

set_property -dict {PACKAGE_PIN A14 IOSTANDARD LVCMOS33} [get_ports {JB[0]}]
set_property -dict {PACKAGE_PIN A16 IOSTANDARD LVCMOS33} [get_ports {JB[1]}]
set_property -dict {PACKAGE_PIN B15 IOSTANDARD LVCMOS33} [get_ports {JB[2]}]
set_property -dict {PACKAGE_PIN B16 IOSTANDARD LVCMOS33} [get_ports {JB[3]}]
set_property -dict {PACKAGE_PIN A15 IOSTANDARD LVCMOS33} [get_ports {JB[4]}]
set_property -dict {PACKAGE_PIN A17 IOSTANDARD LVCMOS33} [get_ports {JB[5]}]
set_property -dict {PACKAGE_PIN C15 IOSTANDARD LVCMOS33} [get_ports {JB[6]}]
set_property -dict {PACKAGE_PIN C16 IOSTANDARD LVCMOS33} [get_ports {JB[7]}]

set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
