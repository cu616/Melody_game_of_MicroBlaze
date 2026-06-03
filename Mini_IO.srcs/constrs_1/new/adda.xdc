# VS1003B audio module on one PMOD header, preferably JA.
# Module pin order: XDCS XCS DREQ SCLK MOSI MISO XRST GND 5V.
# Connect signal pins to JA as listed here; connect GND to PMOD GND.
# Do not connect the module 5V pin to PMOD VCC unless the module is known to accept 3.3V.
set_property PACKAGE_PIN C17 [get_ports VS_XDCS]
set_property PACKAGE_PIN D18 [get_ports VS_XCS]
set_property PACKAGE_PIN E18 [get_ports VS_DREQ]
set_property PACKAGE_PIN G17 [get_ports VS_SCLK]
set_property PACKAGE_PIN D17 [get_ports VS_MOSI]
set_property PACKAGE_PIN E17 [get_ports VS_MISO]
set_property PACKAGE_PIN F18 [get_ports VS_XRST]
set_property IOSTANDARD LVCMOS33 [get_ports {VS_XDCS VS_XCS VS_DREQ VS_SCLK VS_MOSI VS_MISO VS_XRST}]

set_property PACKAGE_PIN F6 [get_ports UART2_tx]
set_property IOSTANDARD LVCMOS33 [get_ports UART2_tx]

set_property PACKAGE_PIN K1 [get_ports UART1_rx]
set_property IOSTANDARD LVCMOS33 [get_ports UART1_rx]


# The push button pins are supplied by the Nexys4 DDR board interface XDC:
# [0]=N17/BTNC, [1]=M18/BTNU, [2]=P17/BTNL, [3]=M17/BTNR, [4]=P18/BTND.
# rhythm_video_audio remaps those bits so lanes are P17(left), N17(center), M17(right).
set_property IOSTANDARD LVCMOS33 [get_ports {push_buttons_5bits_tri_i[*]}]

# SW14 is consumed directly by rhythm_video_audio as the VS1003B pitch calibration switch.
set_property PACKAGE_PIN U11 [get_ports {dip_switches_16bits_tri_i[14]}]
set_property IOSTANDARD LVCMOS33 [get_ports {dip_switches_16bits_tri_i[14]}]

# SW15 is also consumed directly by rhythm_video_audio as the pause switch.
set_property PACKAGE_PIN V10 [get_ports {dip_switches_16bits_tri_i[15]}]
set_property IOSTANDARD LVCMOS33 [get_ports {dip_switches_16bits_tri_i[15]}]

# Nexys4 DDR 12-bit VGA interface
set_property PACKAGE_PIN A3 [get_ports {VGA_R[0]}]
set_property PACKAGE_PIN B4 [get_ports {VGA_R[1]}]
set_property PACKAGE_PIN C5 [get_ports {VGA_R[2]}]
set_property PACKAGE_PIN A4 [get_ports {VGA_R[3]}]
set_property PACKAGE_PIN C6 [get_ports {VGA_G[0]}]
set_property PACKAGE_PIN A5 [get_ports {VGA_G[1]}]
set_property PACKAGE_PIN B6 [get_ports {VGA_G[2]}]
set_property PACKAGE_PIN A6 [get_ports {VGA_G[3]}]
set_property PACKAGE_PIN B7 [get_ports {VGA_B[0]}]
set_property PACKAGE_PIN C7 [get_ports {VGA_B[1]}]
set_property PACKAGE_PIN D7 [get_ports {VGA_B[2]}]
set_property PACKAGE_PIN D8 [get_ports {VGA_B[3]}]
set_property PACKAGE_PIN B11 [get_ports VGA_HS]
set_property PACKAGE_PIN B12 [get_ports VGA_VS]
set_property IOSTANDARD LVCMOS33 [get_ports {VGA_R[*]}]
set_property IOSTANDARD LVCMOS33 [get_ports {VGA_G[*]}]
set_property IOSTANDARD LVCMOS33 [get_ports {VGA_B[*]}]
set_property IOSTANDARD LVCMOS33 [get_ports VGA_HS]
set_property IOSTANDARD LVCMOS33 [get_ports VGA_VS]

# Nexys4 DDR J8 mono audio output
set_property PACKAGE_PIN A11 [get_ports AUD_PWM]
set_property PACKAGE_PIN D12 [get_ports AUD_SD]
set_property IOSTANDARD LVCMOS33 [get_ports AUD_PWM]
set_property IOSTANDARD LVCMOS33 [get_ports AUD_SD]

# Nexys4 DDR user LEDs, seven segment display, and RGB LEDs.
set_property PACKAGE_PIN H17 [get_ports {led_16bits_tri_o[0]}]
set_property PACKAGE_PIN K15 [get_ports {led_16bits_tri_o[1]}]
set_property PACKAGE_PIN J13 [get_ports {led_16bits_tri_o[2]}]
set_property PACKAGE_PIN N14 [get_ports {led_16bits_tri_o[3]}]
set_property PACKAGE_PIN R18 [get_ports {led_16bits_tri_o[4]}]
set_property PACKAGE_PIN V17 [get_ports {led_16bits_tri_o[5]}]
set_property PACKAGE_PIN U17 [get_ports {led_16bits_tri_o[6]}]
set_property PACKAGE_PIN U16 [get_ports {led_16bits_tri_o[7]}]
set_property PACKAGE_PIN V16 [get_ports {led_16bits_tri_o[8]}]
set_property PACKAGE_PIN T15 [get_ports {led_16bits_tri_o[9]}]
set_property PACKAGE_PIN U14 [get_ports {led_16bits_tri_o[10]}]
set_property PACKAGE_PIN T16 [get_ports {led_16bits_tri_o[11]}]
set_property PACKAGE_PIN V15 [get_ports {led_16bits_tri_o[12]}]
set_property PACKAGE_PIN V14 [get_ports {led_16bits_tri_o[13]}]
set_property PACKAGE_PIN V12 [get_ports {led_16bits_tri_o[14]}]
set_property PACKAGE_PIN V11 [get_ports {led_16bits_tri_o[15]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led_16bits_tri_o[*]}]

set_property PACKAGE_PIN T10 [get_ports {dual_seven_seg_led_disp_tri_o[0]}]
set_property PACKAGE_PIN R10 [get_ports {dual_seven_seg_led_disp_tri_o[1]}]
set_property PACKAGE_PIN K16 [get_ports {dual_seven_seg_led_disp_tri_o[2]}]
set_property PACKAGE_PIN K13 [get_ports {dual_seven_seg_led_disp_tri_o[3]}]
set_property PACKAGE_PIN P15 [get_ports {dual_seven_seg_led_disp_tri_o[4]}]
set_property PACKAGE_PIN T11 [get_ports {dual_seven_seg_led_disp_tri_o[5]}]
set_property PACKAGE_PIN L18 [get_ports {dual_seven_seg_led_disp_tri_o[6]}]
set_property PACKAGE_PIN H15 [get_ports {dual_seven_seg_led_disp_tri_o[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {dual_seven_seg_led_disp_tri_o[*]}]

set_property PACKAGE_PIN J17 [get_ports {seven_seg_led_an_tri_o[0]}]
set_property PACKAGE_PIN J18 [get_ports {seven_seg_led_an_tri_o[1]}]
set_property PACKAGE_PIN T9 [get_ports {seven_seg_led_an_tri_o[2]}]
set_property PACKAGE_PIN J14 [get_ports {seven_seg_led_an_tri_o[3]}]
set_property PACKAGE_PIN P14 [get_ports {seven_seg_led_an_tri_o[4]}]
set_property PACKAGE_PIN T14 [get_ports {seven_seg_led_an_tri_o[5]}]
set_property PACKAGE_PIN K2 [get_ports {seven_seg_led_an_tri_o[6]}]
set_property PACKAGE_PIN U13 [get_ports {seven_seg_led_an_tri_o[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {seven_seg_led_an_tri_o[*]}]

set_property PACKAGE_PIN N15 [get_ports {rgb_led_tri_o[0]}]
set_property PACKAGE_PIN M16 [get_ports {rgb_led_tri_o[1]}]
set_property PACKAGE_PIN R12 [get_ports {rgb_led_tri_o[2]}]
set_property PACKAGE_PIN N16 [get_ports {rgb_led_tri_o[3]}]
set_property PACKAGE_PIN R11 [get_ports {rgb_led_tri_o[4]}]
set_property PACKAGE_PIN G14 [get_ports {rgb_led_tri_o[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {rgb_led_tri_o[*]}]
set_property C_CLK_INPUT_FREQ_HZ 300000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets clk]
