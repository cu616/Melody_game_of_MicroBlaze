//Copyright 1986-2018 Xilinx, Inc. All Rights Reserved.
//--------------------------------------------------------------------------------
//Tool Version: Vivado v.2018.3 (win64) Build 2405991 Thu Dec  6 23:38:27 MST 2018
//Date        : Wed Apr 26 19:39:50 2023
//Host        : FengSheng running 64-bit major release  (build 9200)
//Command     : generate_target design_mb_wrapper.bd
//Design      : design_mb_wrapper
//Purpose     : IP block netlist
//--------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

module design_mb_wrapper
   (AUD_PWM,
    AUD_SD,
    UART1_rx,
    UART2_tx,
    VGA_B,
    VGA_G,
    VGA_HS,
    VGA_R,
    VGA_VS,
    dip_switches_16bits_tri_i,
    dual_seven_seg_led_disp_tri_o,
    led_16bits_tri_o,
    push_buttons_5bits_tri_i,
    reset,
    rgb_led_tri_o,
    rx_0,
    seven_seg_led_an_tri_o,
    sys_clock,
    usb_uart_rxd,
    usb_uart_txd,
    VS_DREQ,
    VS_MISO,
    VS_MOSI,
    VS_SCLK,
    VS_XCS,
    VS_XDCS,
    VS_XRST);
  output AUD_PWM;
  output AUD_SD;
  input UART1_rx;
  output UART2_tx;
  output [3:0]VGA_B;
  output [3:0]VGA_G;
  output VGA_HS;
  output [3:0]VGA_R;
  output VGA_VS;
  input [15:0]dip_switches_16bits_tri_i;
  output [7:0]dual_seven_seg_led_disp_tri_o;
  output [15:0]led_16bits_tri_o;
  input [4:0]push_buttons_5bits_tri_i;
  input reset;
  output [5:0]rgb_led_tri_o;
  input rx_0;
  output [7:0]seven_seg_led_an_tri_o;
  input sys_clock;
  input usb_uart_rxd;
  output usb_uart_txd;
  input VS_DREQ;
  input VS_MISO;
  output VS_MOSI;
  output VS_SCLK;
  output VS_XCS;
  output VS_XDCS;
  output VS_XRST;

  wire AUD_PWM;
  wire AUD_SD;
  wire mb_MISO;
  wire mb_MOSI;
  wire mb_SCLK0;
  wire mb_SCLK1;
  wire [0:0]mb_SS0;
  wire [0:0]mb_SS1;
  wire [15:0]mb_switches_tri_i;
  wire vs_mb_mode;
  wire UART1_rx;
  wire UART2_tx;
  wire [3:0]VGA_B;
  wire [3:0]VGA_G;
  wire VGA_HS;
  wire [3:0]VGA_R;
  wire VGA_VS;
  wire [15:0]dip_switches_16bits_tri_i;
  wire [7:0]mb_dual_seven_seg_led_disp_tri_o;
  wire [7:0]rtl_dual_seven_seg_led_disp_tri_o;
  wire [15:0]mb_led_16bits_tri_o;
  wire [15:0]rtl_led_16bits_tri_o;
  wire [4:0]push_buttons_5bits_tri_i;
  wire reset;
  wire [5:0]mb_rgb_led_tri_o;
  wire [5:0]rtl_rgb_led_tri_o;
  wire rx_0;
  wire [7:0]mb_seven_seg_led_an_tri_o;
  wire [7:0]rtl_seven_seg_led_an_tri_o;
  wire sys_clock;
  wire usb_uart_rxd;
  wire usb_uart_txd;
  wire VS_DREQ;
  wire VS_MISO;
  wire VS_MOSI;
  wire VS_SCLK;
  wire VS_XCS;
  wire VS_XDCS;
  wire VS_XRST;
  wire rtl_vs_mosi;
  wire rtl_vs_sclk;
  wire rtl_vs_xcs;
  wire rtl_vs_xdcs;
  wire rtl_vs_xrst;

  // Classroom SoC build: MicroBlaze always owns the game/audio state.
  // The RTL block remains as the VGA/display timing bridge, not as a selectable game mode.
  assign vs_mb_mode = 1'b1;
  assign mb_MISO = VS_MISO;
  assign mb_switches_tri_i = {VS_DREQ, VS_MISO, dip_switches_16bits_tri_i[13:0]};
  assign VS_MOSI = vs_mb_mode ? mb_led_16bits_tri_o[3] : rtl_vs_mosi;
  assign VS_SCLK = vs_mb_mode ? mb_led_16bits_tri_o[4] : rtl_vs_sclk;
  assign VS_XCS = vs_mb_mode ? mb_led_16bits_tri_o[0] : rtl_vs_xcs;
  assign VS_XDCS = vs_mb_mode ? mb_led_16bits_tri_o[1] : rtl_vs_xdcs;
  assign VS_XRST = vs_mb_mode ? mb_led_16bits_tri_o[2] : rtl_vs_xrst;
  assign led_16bits_tri_o = mb_led_16bits_tri_o;
  assign dual_seven_seg_led_disp_tri_o = rtl_dual_seven_seg_led_disp_tri_o;
  assign seven_seg_led_an_tri_o = rtl_seven_seg_led_an_tri_o;
  assign rgb_led_tri_o = rtl_rgb_led_tri_o;

  design_mb design_mb_i
       (.MISO(mb_MISO),
        .MOSI(mb_MOSI),
        .SCLK0(mb_SCLK0),
        .SCLK1(mb_SCLK1),
        .SS0(mb_SS0),
        .SS1(mb_SS1),
        .UART1_rx(UART1_rx),
        .UART2_tx(UART2_tx),
        .dip_switches_16bits_tri_i(mb_switches_tri_i),
        .dual_seven_seg_led_disp_tri_o(mb_dual_seven_seg_led_disp_tri_o),
        .led_16bits_tri_o(mb_led_16bits_tri_o),
        .push_buttons_5bits_tri_i(push_buttons_5bits_tri_i),
        .reset(reset),
        .rgb_led_tri_o(mb_rgb_led_tri_o),
        .rx_0(rx_0),
        .seven_seg_led_an_tri_o(mb_seven_seg_led_an_tri_o),
        .sys_clock(sys_clock),
        .usb_uart_rxd(usb_uart_rxd),
        .usb_uart_txd(usb_uart_txd));

  rhythm_video_audio rhythm_video_audio_i
       (.aud_pwm(AUD_PWM),
        .aud_sd(AUD_SD),
        .buttons(push_buttons_5bits_tri_i),
        .clk100(sys_clock),
        .diag_an(rtl_seven_seg_led_an_tri_o),
        .diag_led(rtl_led_16bits_tri_o),
        .diag_rgb(rtl_rgb_led_tri_o),
        .diag_seg(rtl_dual_seven_seg_led_disp_tri_o),
        .mb_mode(vs_mb_mode),
        .mb_led_status(mb_led_16bits_tri_o),
        .mb_rgb_status(mb_rgb_led_tri_o),
        .mb_seg_status(mb_dual_seven_seg_led_disp_tri_o),
        .mb_an_status(mb_seven_seg_led_an_tri_o),
        .reset(reset),
        .switches(dip_switches_16bits_tri_i),
        .vga_b(VGA_B),
        .vga_g(VGA_G),
        .vga_hs(VGA_HS),
        .vga_r(VGA_R),
        .vga_vs(VGA_VS),
        .vs_dreq(VS_DREQ),
        .vs_miso(VS_MISO),
        .vs_mosi(rtl_vs_mosi),
        .vs_sclk(rtl_vs_sclk),
        .vs_xcs(rtl_vs_xcs),
        .vs_xdcs(rtl_vs_xdcs),
        .vs_xrst(rtl_vs_xrst));
endmodule
