`timescale 1ns / 1ps

module rhythm_video_audio (
    input wire clk100,
    input wire reset,
    input wire [4:0] buttons,
    input wire [15:0] switches,
    input wire mb_mode,
    input wire [15:0] mb_led_status,
    input wire [5:0] mb_rgb_status,
    input wire [7:0] mb_seg_status,
    input wire [7:0] mb_an_status,
    output reg [3:0] vga_r,
    output reg [3:0] vga_g,
    output reg [3:0] vga_b,
    output reg vga_hs,
    output reg vga_vs,
    output reg [15:0] diag_led,
    output reg [7:0] diag_seg,
    output reg [7:0] diag_an,
    output reg [5:0] diag_rgb,
    input wire vs_dreq,
    input wire vs_miso,
    output wire vs_mosi,
    output wire vs_sclk,
    output wire vs_xcs,
    output wire vs_xdcs,
    output wire vs_xrst
);
    // This module is the hardware display bridge for the SoC version.
    // MicroBlaze owns gameplay/audio state; RTL keeps VGA timing, font/cover
    // ROM lookup, seven-segment multiplexing, and LED atmosphere effects stable.
    localparam H_VISIBLE = 640;
    localparam H_FRONT   = 16;
    localparam H_SYNC    = 96;
    localparam H_BACK    = 48;
    localparam H_TOTAL   = H_VISIBLE + H_FRONT + H_SYNC + H_BACK;

    localparam V_VISIBLE = 480;
    localparam V_FRONT   = 10;
    localparam V_SYNC    = 2;
    localparam V_BACK    = 33;
    localparam V_TOTAL   = V_VISIBLE + V_FRONT + V_SYNC + V_BACK;

    reg [1:0] pix_div = 2'b00;
    reg [9:0] h_count = 10'd0;
    reg [9:0] v_count = 10'd0;
    reg [26:0] slow_count = 27'd0;
    reg [23:0] frame_count = 24'd0;
    wire [7:0] mb_game_seg;
    wire [7:0] mb_game_an;
    wire [11:0] album_art_rgb;
    wire track_art_area;
    wire [3:0] track_bg_r;
    wire [3:0] track_bg_g;
    wire [3:0] track_bg_b;
    reg ui_text_pixel = 1'b0;
    reg ui_box_pixel = 1'b0;
    reg ui_line_pixel = 1'b0;
    reg ui_selected_pixel = 1'b0;
    reg [31:0] game_lane_mask = 32'd0;
    reg [31:0] game_hold_lane_mask = 32'd0;
    reg game_note_pixel = 1'b0;
    reg game_hold_pixel = 1'b0;
    reg game_button_pixel = 1'b0;
    reg [5:0] game_row = 6'd0;
    reg [2:0] game_lane = 3'd0;
    reg [3:0] mb_display_digit0 = 4'd0;
    reg [3:0] mb_display_digit1 = 4'd0;
    reg [3:0] mb_display_digit2 = 4'd0;
    reg [3:0] mb_display_digit3 = 4'd0;
    reg [95:0] mb_note_tracks = 96'd0;
    reg [95:0] mb_hold_tracks = 96'd0;
    reg [2:0] mb_button_tracks = 3'd0;
    reg [15:0] led_pattern = 16'd0;
    reg [7:0] led_level = 8'd0;

    wire pix_tick = (pix_div == 2'b11);
    wire reset_active = ~reset;
    wire active_video = (h_count < H_VISIBLE) && (v_count < V_VISIBLE);
    wire border = (h_count < 10'd8) || (h_count >= 10'd632) ||
                  (v_count < 10'd8) || (v_count >= 10'd472);
    wire center_box = (h_count >= 10'd280) && (h_count < 10'd360) &&
                      (v_count >= 10'd200) && (v_count < 10'd280);
    wire moving_bar = (v_count >= frame_count[8:0]) &&
                      (v_count < frame_count[8:0] + 10'd16);
    wire [2:0] game_speed = switches[5:3];
    wire [5:0] game_speed_text_id = 6'd17 + {3'b000, game_speed};
    wire [1:0] mb_game_state = mb_led_status[15:14];
    wire [1:0] mb_song_select = mb_led_status[13:12];
    wire [1:0] mb_rating_code = mb_led_status[11:10];
    wire [3:0] mb_volume_level = mb_led_status[9:6];
    // Final build accepts note/judge/score/button state only from MicroBlaze.
    // Earlier RTL self-running game state was removed from the active path.
    wire [3:0] ui_judgement = (mb_rating_code == 2'd1) ? 4'd2 :
                              (mb_rating_code == 2'd2) ? 4'd1 :
                              (mb_rating_code == 2'd3) ? 4'd0 : 4'd7;
    wire ui_paused = (mb_game_state == 2'd2);
    wire ui_finished = (mb_game_state == 2'd3);
    wire ui_audio_enabled = (mb_game_state != 2'd0);
    wire [1:0] ui_song_select = mb_song_select;
    wire [19:0] ui_score_bcd = {4'd0, mb_display_digit3, mb_display_digit2,
                                mb_display_digit1, mb_display_digit0};
    wire [95:0] ui_note_tracks = mb_note_tracks;
    wire [95:0] ui_hold_tracks = mb_hold_tracks;
    wire [2:0] ui_buttons = mb_button_tracks;
    wire [7:0] led_breathe =
        slow_count[26] ? ~slow_count[25:18] : slow_count[25:18];
    wire [7:0] led_pwm = slow_count[7:0];
    wire led_left_active =
        |(ui_note_tracks[31:24] | ui_hold_tracks[31:24]);
    wire led_mid_active =
        |(ui_note_tracks[63:56] | ui_hold_tracks[63:56]);
    wire led_right_active =
        |(ui_note_tracks[95:88] | ui_hold_tracks[95:88]);
    wire led_note_near_judge =
        |(ui_note_tracks[31:24] | ui_note_tracks[63:56] | ui_note_tracks[95:88] |
          ui_hold_tracks[31:24] | ui_hold_tracks[63:56] | ui_hold_tracks[95:88]);
    wire [5:0] ui_volume_text_id = 6'd32 + {2'b00, mb_volume_level};
    wire [5:0] ui_judgement_text_id = ui_paused ? 6'd51 :
                                       ui_finished ? 6'd30 :
                                       (ui_judgement == 4'd2) ? 6'd8 :
                                       (ui_judgement == 4'd1) ? 6'd9 :
                                       (ui_judgement == 4'd0) ? 6'd10 : 6'd29;
    assign track_art_area = (h_count >= 10'd200) && (h_count < 10'd440) &&
                            (v_count >= 10'd32) && (v_count < 10'd416);
    assign track_bg_r = album_art_rgb[11:8];
    assign track_bg_g = album_art_rgb[7:4];
    assign track_bg_b = album_art_rgb[3:0];
    wire [3:0] hold_blend_r = {1'b0, track_bg_r[3:1]} + 4'h8;
    wire [3:0] hold_blend_g = {1'b0, track_bg_g[3:1]} + 4'h8;
    wire [3:0] hold_blend_b = {1'b0, track_bg_b[3:1]} + 4'h8;

    // Final SoC build: VS1003B pins are owned by MicroBlaze through the wrapper.
    // These idle assignments keep the removed RTL test players from driving
    // anything when this display bridge is reused outside the current wrapper.
    assign vs_mosi = 1'b0;
    assign vs_sclk = 1'b0;
    assign vs_xcs  = 1'b1;
    assign vs_xdcs = 1'b1;
    assign vs_xrst = 1'b1;

    rhythm_mb_sevenseg mb_sevenseg_i (
        .clk(clk100),
        .reset(reset_active),
        .score_bcd(ui_score_bcd),
        .judgement(ui_judgement),
        .ready(!ui_audio_enabled),
        .paused(ui_paused),
        .finished(ui_finished),
        .seg(mb_game_seg),
        .an(mb_game_an)
    );

    album_art_track_rom album_art_track_i (
        .clk(clk100),
        .song_select(ui_song_select),
        .pixel_x(h_count),
        .pixel_y(v_count),
        .valid(track_art_area),
        .rgb(album_art_rgb)
    );

    function [7:0] ui_char;
        input [5:0] text_id;
        input [4:0] index;
        begin
            ui_char = " ";
            case (text_id)
                5'd0: begin
                    case (index)
                        5'd0: ui_char = "S"; 5'd1: ui_char = "o"; 5'd2: ui_char = "n"; 5'd3: ui_char = "g";
                        default: ui_char = " ";
                    endcase
                end
                5'd1: begin
                    case (index)
                        5'd0: ui_char = "C"; 5'd1: ui_char = "a"; 5'd2: ui_char = "n"; 5'd3: ui_char = "o"; 5'd4: ui_char = "n";
                        default: ui_char = " ";
                    endcase
                end
                5'd2: begin
                    case (index)
                        5'd0: ui_char = "F"; 5'd1: ui_char = "a"; 5'd2: ui_char = "d"; 5'd3: ui_char = "e"; 5'd4: ui_char = "d";
                        default: ui_char = " ";
                    endcase
                end
                5'd3: begin
                    case (index)
                        5'd0: ui_char = "K"; 5'd1: ui_char = "e"; 5'd2: ui_char = "y"; 5'd3: ui_char = "s";
                        default: ui_char = " ";
                    endcase
                end
                5'd4: begin
                    case (index)
                        5'd0: ui_char = "L"; 5'd1: ui_char = " "; 5'd2: ui_char = "C"; 5'd3: ui_char = " "; 5'd4: ui_char = "R";
                        default: ui_char = " ";
                    endcase
                end
                5'd5: begin
                    case (index)
                        5'd0: ui_char = "S"; 5'd1: ui_char = "p"; 5'd2: ui_char = "e"; 5'd3: ui_char = "e"; 5'd4: ui_char = "d";
                        default: ui_char = " ";
                    endcase
                end
                5'd6: begin
                    case (index)
                        5'd0: ui_char = "1"; 5'd1: ui_char = "X";
                        default: ui_char = " ";
                    endcase
                end
                5'd7: begin
                    case (index)
                        5'd0: ui_char = "J"; 5'd1: ui_char = "u"; 5'd2: ui_char = "d"; 5'd3: ui_char = "g"; 5'd4: ui_char = "e";
                        default: ui_char = " ";
                    endcase
                end
                5'd8: begin
                    case (index)
                        5'd0: ui_char = "G"; 5'd1: ui_char = "o"; 5'd2: ui_char = "o"; 5'd3: ui_char = "d";
                        default: ui_char = " ";
                    endcase
                end
                5'd9: begin
                    case (index)
                        5'd0: ui_char = "B"; 5'd1: ui_char = "a"; 5'd2: ui_char = "d";
                        default: ui_char = " ";
                    endcase
                end
                5'd10: begin
                    case (index)
                        5'd0: ui_char = "M"; 5'd1: ui_char = "i"; 5'd2: ui_char = "s"; 5'd3: ui_char = "s";
                        default: ui_char = " ";
                    endcase
                end
                5'd11: begin
                    case (index)
                        5'd0: ui_char = "V"; 5'd1: ui_char = "S"; 5'd2: ui_char = "1"; 5'd3: ui_char = "0";
                        5'd4: ui_char = "0"; 5'd5: ui_char = "3";
                        default: ui_char = " ";
                    endcase
                end
                5'd12: begin
                    case (index)
                        5'd0: ui_char = "D"; 5'd1: ui_char = "E"; 5'd2: ui_char = "M"; 5'd3: ui_char = "O";
                        default: ui_char = " ";
                    endcase
                end
                5'd13: begin
                    case (index)
                        5'd0: ui_char = "O"; 5'd1: ui_char = "F"; 5'd2: ui_char = "F";
                        default: ui_char = " ";
                    endcase
                end
                5'd14: begin
                    case (index)
                        5'd0: ui_char = "O"; 5'd1: ui_char = "N";
                        default: ui_char = " ";
                    endcase
                end
                5'd15: begin
                    case (index)
                        5'd0: ui_char = "B"; 5'd1: ui_char = "P"; 5'd2: ui_char = "M";
                        default: ui_char = " ";
                    endcase
                end
                5'd16: begin
                    case (index)
                        5'd0: ui_char = "9"; 5'd1: ui_char = "0";
                        default: ui_char = " ";
                    endcase
                end
                5'd17: begin
                    case (index)
                        5'd0: ui_char = "0"; 5'd1: ui_char = "7"; 5'd2: ui_char = "5";
                        default: ui_char = " ";
                    endcase
                end
                5'd18: begin
                    case (index)
                        5'd0: ui_char = "1"; 5'd1: ui_char = "0"; 5'd2: ui_char = "0";
                        default: ui_char = " ";
                    endcase
                end
                5'd19: begin
                    case (index)
                        5'd0: ui_char = "1"; 5'd1: ui_char = "2"; 5'd2: ui_char = "5";
                        default: ui_char = " ";
                    endcase
                end
                5'd20: begin
                    case (index)
                        5'd0: ui_char = "1"; 5'd1: ui_char = "5"; 5'd2: ui_char = "0";
                        default: ui_char = " ";
                    endcase
                end
                5'd21: begin
                    case (index)
                        5'd0: ui_char = "1"; 5'd1: ui_char = "7"; 5'd2: ui_char = "5";
                        default: ui_char = " ";
                    endcase
                end
                5'd22: begin
                    case (index)
                        5'd0: ui_char = "2"; 5'd1: ui_char = "0"; 5'd2: ui_char = "0";
                        default: ui_char = " ";
                    endcase
                end
                5'd23: begin
                    case (index)
                        5'd0: ui_char = "2"; 5'd1: ui_char = "5"; 5'd2: ui_char = "0";
                        default: ui_char = " ";
                    endcase
                end
                5'd24: begin
                    case (index)
                        5'd0: ui_char = "3"; 5'd1: ui_char = "0"; 5'd2: ui_char = "0";
                        default: ui_char = " ";
                    endcase
                end
                5'd25: begin
                    case (index)
                        5'd0: ui_char = "S"; 5'd1: ui_char = "c"; 5'd2: ui_char = "o"; 5'd3: ui_char = "r"; 5'd4: ui_char = "e";
                        default: ui_char = " ";
                    endcase
                end
                5'd26: begin
                    case (index)
                        5'd0: ui_char = "P"; 5'd1: ui_char = "1"; 5'd2: ui_char = "7"; 5'd3: ui_char = " "; 5'd4: ui_char = "L";
                        default: ui_char = " ";
                    endcase
                end
                5'd27: begin
                    case (index)
                        5'd0: ui_char = "N"; 5'd1: ui_char = "1"; 5'd2: ui_char = "7"; 5'd3: ui_char = " "; 5'd4: ui_char = "C";
                        default: ui_char = " ";
                    endcase
                end
                5'd28: begin
                    case (index)
                        5'd0: ui_char = "M"; 5'd1: ui_char = "1"; 5'd2: ui_char = "7"; 5'd3: ui_char = " "; 5'd4: ui_char = "R";
                        default: ui_char = " ";
                    endcase
                end
                5'd29: begin
                    case (index)
                        5'd0: ui_char = "R"; 5'd1: ui_char = "e"; 5'd2: ui_char = "a"; 5'd3: ui_char = "d"; 5'd4: ui_char = "y";
                        default: ui_char = " ";
                    endcase
                end
                5'd30: begin
                    case (index)
                        5'd0: ui_char = "F"; 5'd1: ui_char = "i"; 5'd2: ui_char = "n"; 5'd3: ui_char = "i"; 5'd4: ui_char = "s"; 5'd5: ui_char = "h";
                        default: ui_char = " ";
                    endcase
                end
                5'd31: begin
                    case (index)
                        5'd0: ui_char = "V"; 5'd1: ui_char = "o"; 5'd2: ui_char = "l";
                        default: ui_char = " ";
                    endcase
                end
                6'd32: begin
                    case (index)
                        5'd0: ui_char = "0";
                        default: ui_char = " ";
                    endcase
                end
                6'd33: begin
                    case (index)
                        5'd0: ui_char = "1";
                        default: ui_char = " ";
                    endcase
                end
                6'd34: begin
                    case (index)
                        5'd0: ui_char = "2";
                        default: ui_char = " ";
                    endcase
                end
                6'd35: begin
                    case (index)
                        5'd0: ui_char = "3";
                        default: ui_char = " ";
                    endcase
                end
                6'd36: begin
                    case (index)
                        5'd0: ui_char = "4";
                        default: ui_char = " ";
                    endcase
                end
                6'd37: begin
                    case (index)
                        5'd0: ui_char = "5";
                        default: ui_char = " ";
                    endcase
                end
                6'd38: begin
                    case (index)
                        5'd0: ui_char = "6";
                        default: ui_char = " ";
                    endcase
                end
                6'd39: begin
                    case (index)
                        5'd0: ui_char = "7";
                        default: ui_char = " ";
                    endcase
                end
                6'd40: begin
                    case (index)
                        5'd0: ui_char = "8";
                        default: ui_char = " ";
                    endcase
                end
                6'd41: begin
                    case (index)
                        5'd0: ui_char = "9";
                        default: ui_char = " ";
                    endcase
                end
                6'd42: begin
                    case (index)
                        5'd0: ui_char = "1"; 5'd1: ui_char = "0";
                        default: ui_char = " ";
                    endcase
                end
                6'd43: begin
                    case (index)
                        5'd0: ui_char = "1"; 5'd1: ui_char = "1";
                        default: ui_char = " ";
                    endcase
                end
                6'd44: begin
                    case (index)
                        5'd0: ui_char = "1"; 5'd1: ui_char = "2";
                        default: ui_char = " ";
                    endcase
                end
                6'd45: begin
                    case (index)
                        5'd0: ui_char = "1"; 5'd1: ui_char = "3";
                        default: ui_char = " ";
                    endcase
                end
                6'd46: begin
                    case (index)
                        5'd0: ui_char = "1"; 5'd1: ui_char = "4";
                        default: ui_char = " ";
                    endcase
                end
                6'd47: begin
                    case (index)
                        5'd0: ui_char = "1"; 5'd1: ui_char = "5";
                        default: ui_char = " ";
                    endcase
                end
                6'd48: begin
                    case (index)
                        5'd0: ui_char = "U"; 5'd1: ui_char = "-"; 5'd2: ui_char = "D"; 5'd3: ui_char = " "; 5'd4: ui_char = "V"; 5'd5: ui_char = "o"; 5'd6: ui_char = "l";
                        default: ui_char = " ";
                    endcase
                end
                6'd49: begin
                    case (index)
                        5'd0: ui_char = "S"; 5'd1: ui_char = "W"; 5'd2: ui_char = "0"; 5'd3: ui_char = "-"; 5'd4: ui_char = "1";
                        default: ui_char = " ";
                    endcase
                end
                6'd50: begin
                    case (index)
                        5'd0: ui_char = "S"; 5'd1: ui_char = "W"; 5'd2: ui_char = "3"; 5'd3: ui_char = "-"; 5'd4: ui_char = "5";
                        default: ui_char = " ";
                    endcase
                end
                6'd51: begin
                    case (index)
                        5'd0: ui_char = "P"; 5'd1: ui_char = "a"; 5'd2: ui_char = "u"; 5'd3: ui_char = "s"; 5'd4: ui_char = "e";
                        default: ui_char = " ";
                    endcase
                end
                6'd52: begin
                    case (index)
                        5'd0: ui_char = "S"; 5'd1: ui_char = "W"; 5'd2: ui_char = "1"; 5'd3: ui_char = "5";
                        default: ui_char = " ";
                    endcase
                end
                6'd53: begin
                    case (index)
                        5'd0: ui_char = "A"; 5'd1: ui_char = "p"; 5'd2: ui_char = "h"; 5'd3: ui_char = "a";
                        5'd4: ui_char = "s"; 5'd5: ui_char = "i"; 5'd6: ui_char = "a";
                        default: ui_char = " ";
                    endcase
                end
                6'd54: begin
                    case (index)
                        5'd0: ui_char = "S"; 5'd1: ui_char = "o"; 5'd2: ui_char = "C";
                        default: ui_char = " ";
                    endcase
                end
                6'd55: begin
                    case (index)
                        5'd0: ui_char = "M"; 5'd1: ui_char = "I"; 5'd2: ui_char = "D"; 5'd3: ui_char = "I";
                        default: ui_char = " ";
                    endcase
                end
                6'd56: begin
                    case (index)
                        5'd0: ui_char = "S"; 5'd1: ui_char = "W"; 5'd2: ui_char = "1"; 5'd3: ui_char = "4"; 5'd4: ui_char = "-"; 5'd5: ui_char = "1"; 5'd6: ui_char = "5";
                        default: ui_char = " ";
                    endcase
                end
                6'd57: begin
                    case (index)
                        5'd0: ui_char = "M"; 5'd1: ui_char = "u"; 5'd2: ui_char = "t"; 5'd3: ui_char = "e";
                        default: ui_char = " ";
                    endcase
                end
                6'd58: begin
                    case (index)
                        5'd0: ui_char = "S"; 5'd1: ui_char = "W"; 5'd2: ui_char = "2";
                        default: ui_char = " ";
                    endcase
                end
                default: ui_char = " ";
            endcase
        end
    endfunction

    function [4:0] ui_glyph_row;
        input [7:0] ch;
        input [2:0] row;
        begin
            ui_glyph_row = 5'b00000;
            case (ch)
                "0": case (row) 3'd0: ui_glyph_row=5'b01110; 3'd1: ui_glyph_row=5'b10001; 3'd2: ui_glyph_row=5'b10011; 3'd3: ui_glyph_row=5'b10101; 3'd4: ui_glyph_row=5'b11001; 3'd5: ui_glyph_row=5'b10001; 3'd6: ui_glyph_row=5'b01110; endcase
                "1": case (row) 3'd0: ui_glyph_row=5'b00100; 3'd1: ui_glyph_row=5'b01100; 3'd2: ui_glyph_row=5'b00100; 3'd3: ui_glyph_row=5'b00100; 3'd4: ui_glyph_row=5'b00100; 3'd5: ui_glyph_row=5'b00100; 3'd6: ui_glyph_row=5'b01110; endcase
                "2": case (row) 3'd0: ui_glyph_row=5'b01110; 3'd1: ui_glyph_row=5'b10001; 3'd2: ui_glyph_row=5'b00001; 3'd3: ui_glyph_row=5'b00010; 3'd4: ui_glyph_row=5'b00100; 3'd5: ui_glyph_row=5'b01000; 3'd6: ui_glyph_row=5'b11111; endcase
                "3": case (row) 3'd0: ui_glyph_row=5'b11110; 3'd1: ui_glyph_row=5'b00001; 3'd2: ui_glyph_row=5'b00001; 3'd3: ui_glyph_row=5'b01110; 3'd4: ui_glyph_row=5'b00001; 3'd5: ui_glyph_row=5'b00001; 3'd6: ui_glyph_row=5'b11110; endcase
                "4": case (row) 3'd0: ui_glyph_row=5'b00010; 3'd1: ui_glyph_row=5'b00110; 3'd2: ui_glyph_row=5'b01010; 3'd3: ui_glyph_row=5'b10010; 3'd4: ui_glyph_row=5'b11111; 3'd5: ui_glyph_row=5'b00010; 3'd6: ui_glyph_row=5'b00010; endcase
                "5": case (row) 3'd0: ui_glyph_row=5'b11111; 3'd1: ui_glyph_row=5'b10000; 3'd2: ui_glyph_row=5'b10000; 3'd3: ui_glyph_row=5'b11110; 3'd4: ui_glyph_row=5'b00001; 3'd5: ui_glyph_row=5'b00001; 3'd6: ui_glyph_row=5'b11110; endcase
                "6": case (row) 3'd0: ui_glyph_row=5'b00110; 3'd1: ui_glyph_row=5'b01000; 3'd2: ui_glyph_row=5'b10000; 3'd3: ui_glyph_row=5'b11110; 3'd4: ui_glyph_row=5'b10001; 3'd5: ui_glyph_row=5'b10001; 3'd6: ui_glyph_row=5'b01110; endcase
                "7": case (row) 3'd0: ui_glyph_row=5'b11111; 3'd1: ui_glyph_row=5'b00001; 3'd2: ui_glyph_row=5'b00010; 3'd3: ui_glyph_row=5'b00100; 3'd4: ui_glyph_row=5'b01000; 3'd5: ui_glyph_row=5'b01000; 3'd6: ui_glyph_row=5'b01000; endcase
                "8": case (row) 3'd0: ui_glyph_row=5'b01110; 3'd1: ui_glyph_row=5'b10001; 3'd2: ui_glyph_row=5'b10001; 3'd3: ui_glyph_row=5'b01110; 3'd4: ui_glyph_row=5'b10001; 3'd5: ui_glyph_row=5'b10001; 3'd6: ui_glyph_row=5'b01110; endcase
                "9": case (row) 3'd0: ui_glyph_row=5'b01110; 3'd1: ui_glyph_row=5'b10001; 3'd2: ui_glyph_row=5'b10001; 3'd3: ui_glyph_row=5'b01111; 3'd4: ui_glyph_row=5'b00001; 3'd5: ui_glyph_row=5'b00010; 3'd6: ui_glyph_row=5'b11100; endcase
                "A": case (row) 3'd0: ui_glyph_row=5'b01110; 3'd1: ui_glyph_row=5'b10001; 3'd2: ui_glyph_row=5'b10001; 3'd3: ui_glyph_row=5'b11111; 3'd4: ui_glyph_row=5'b10001; 3'd5: ui_glyph_row=5'b10001; 3'd6: ui_glyph_row=5'b10001; endcase
                "B": case (row) 3'd0: ui_glyph_row=5'b11110; 3'd1: ui_glyph_row=5'b10001; 3'd2: ui_glyph_row=5'b10001; 3'd3: ui_glyph_row=5'b11110; 3'd4: ui_glyph_row=5'b10001; 3'd5: ui_glyph_row=5'b10001; 3'd6: ui_glyph_row=5'b11110; endcase
                "C": case (row) 3'd0: ui_glyph_row=5'b01110; 3'd1: ui_glyph_row=5'b10001; 3'd2: ui_glyph_row=5'b10000; 3'd3: ui_glyph_row=5'b10000; 3'd4: ui_glyph_row=5'b10000; 3'd5: ui_glyph_row=5'b10001; 3'd6: ui_glyph_row=5'b01110; endcase
                "D": case (row) 3'd0: ui_glyph_row=5'b11110; 3'd1: ui_glyph_row=5'b10001; 3'd2: ui_glyph_row=5'b10001; 3'd3: ui_glyph_row=5'b10001; 3'd4: ui_glyph_row=5'b10001; 3'd5: ui_glyph_row=5'b10001; 3'd6: ui_glyph_row=5'b11110; endcase
                "E": case (row) 3'd0: ui_glyph_row=5'b11111; 3'd1: ui_glyph_row=5'b10000; 3'd2: ui_glyph_row=5'b10000; 3'd3: ui_glyph_row=5'b11110; 3'd4: ui_glyph_row=5'b10000; 3'd5: ui_glyph_row=5'b10000; 3'd6: ui_glyph_row=5'b11111; endcase
                "F": case (row) 3'd0: ui_glyph_row=5'b11111; 3'd1: ui_glyph_row=5'b10000; 3'd2: ui_glyph_row=5'b10000; 3'd3: ui_glyph_row=5'b11110; 3'd4: ui_glyph_row=5'b10000; 3'd5: ui_glyph_row=5'b10000; 3'd6: ui_glyph_row=5'b10000; endcase
                "G": case (row) 3'd0: ui_glyph_row=5'b01110; 3'd1: ui_glyph_row=5'b10001; 3'd2: ui_glyph_row=5'b10000; 3'd3: ui_glyph_row=5'b10111; 3'd4: ui_glyph_row=5'b10001; 3'd5: ui_glyph_row=5'b10001; 3'd6: ui_glyph_row=5'b01111; endcase
                "H": case (row) 3'd0: ui_glyph_row=5'b10001; 3'd1: ui_glyph_row=5'b10001; 3'd2: ui_glyph_row=5'b10001; 3'd3: ui_glyph_row=5'b11111; 3'd4: ui_glyph_row=5'b10001; 3'd5: ui_glyph_row=5'b10001; 3'd6: ui_glyph_row=5'b10001; endcase
                "I": case (row) 3'd0: ui_glyph_row=5'b01110; 3'd1: ui_glyph_row=5'b00100; 3'd2: ui_glyph_row=5'b00100; 3'd3: ui_glyph_row=5'b00100; 3'd4: ui_glyph_row=5'b00100; 3'd5: ui_glyph_row=5'b00100; 3'd6: ui_glyph_row=5'b01110; endcase
                "J": case (row) 3'd0: ui_glyph_row=5'b00111; 3'd1: ui_glyph_row=5'b00010; 3'd2: ui_glyph_row=5'b00010; 3'd3: ui_glyph_row=5'b00010; 3'd4: ui_glyph_row=5'b10010; 3'd5: ui_glyph_row=5'b10010; 3'd6: ui_glyph_row=5'b01100; endcase
                "K": case (row) 3'd0: ui_glyph_row=5'b10001; 3'd1: ui_glyph_row=5'b10010; 3'd2: ui_glyph_row=5'b10100; 3'd3: ui_glyph_row=5'b11000; 3'd4: ui_glyph_row=5'b10100; 3'd5: ui_glyph_row=5'b10010; 3'd6: ui_glyph_row=5'b10001; endcase
                "L": case (row) 3'd0: ui_glyph_row=5'b10000; 3'd1: ui_glyph_row=5'b10000; 3'd2: ui_glyph_row=5'b10000; 3'd3: ui_glyph_row=5'b10000; 3'd4: ui_glyph_row=5'b10000; 3'd5: ui_glyph_row=5'b10000; 3'd6: ui_glyph_row=5'b11111; endcase
                "M": case (row) 3'd0: ui_glyph_row=5'b10001; 3'd1: ui_glyph_row=5'b11011; 3'd2: ui_glyph_row=5'b10101; 3'd3: ui_glyph_row=5'b10101; 3'd4: ui_glyph_row=5'b10001; 3'd5: ui_glyph_row=5'b10001; 3'd6: ui_glyph_row=5'b10001; endcase
                "N": case (row) 3'd0: ui_glyph_row=5'b10001; 3'd1: ui_glyph_row=5'b11001; 3'd2: ui_glyph_row=5'b10101; 3'd3: ui_glyph_row=5'b10011; 3'd4: ui_glyph_row=5'b10001; 3'd5: ui_glyph_row=5'b10001; 3'd6: ui_glyph_row=5'b10001; endcase
                "O": case (row) 3'd0: ui_glyph_row=5'b01110; 3'd1: ui_glyph_row=5'b10001; 3'd2: ui_glyph_row=5'b10001; 3'd3: ui_glyph_row=5'b10001; 3'd4: ui_glyph_row=5'b10001; 3'd5: ui_glyph_row=5'b10001; 3'd6: ui_glyph_row=5'b01110; endcase
                "P": case (row) 3'd0: ui_glyph_row=5'b11110; 3'd1: ui_glyph_row=5'b10001; 3'd2: ui_glyph_row=5'b10001; 3'd3: ui_glyph_row=5'b11110; 3'd4: ui_glyph_row=5'b10000; 3'd5: ui_glyph_row=5'b10000; 3'd6: ui_glyph_row=5'b10000; endcase
                "R": case (row) 3'd0: ui_glyph_row=5'b11110; 3'd1: ui_glyph_row=5'b10001; 3'd2: ui_glyph_row=5'b10001; 3'd3: ui_glyph_row=5'b11110; 3'd4: ui_glyph_row=5'b10100; 3'd5: ui_glyph_row=5'b10010; 3'd6: ui_glyph_row=5'b10001; endcase
                "S": case (row) 3'd0: ui_glyph_row=5'b01111; 3'd1: ui_glyph_row=5'b10000; 3'd2: ui_glyph_row=5'b10000; 3'd3: ui_glyph_row=5'b01110; 3'd4: ui_glyph_row=5'b00001; 3'd5: ui_glyph_row=5'b00001; 3'd6: ui_glyph_row=5'b11110; endcase
                "U": case (row) 3'd0: ui_glyph_row=5'b10001; 3'd1: ui_glyph_row=5'b10001; 3'd2: ui_glyph_row=5'b10001; 3'd3: ui_glyph_row=5'b10001; 3'd4: ui_glyph_row=5'b10001; 3'd5: ui_glyph_row=5'b10001; 3'd6: ui_glyph_row=5'b01110; endcase
                "V": case (row) 3'd0: ui_glyph_row=5'b10001; 3'd1: ui_glyph_row=5'b10001; 3'd2: ui_glyph_row=5'b10001; 3'd3: ui_glyph_row=5'b10001; 3'd4: ui_glyph_row=5'b01010; 3'd5: ui_glyph_row=5'b01010; 3'd6: ui_glyph_row=5'b00100; endcase
                "W": case (row) 3'd0: ui_glyph_row=5'b10001; 3'd1: ui_glyph_row=5'b10001; 3'd2: ui_glyph_row=5'b10001; 3'd3: ui_glyph_row=5'b10101; 3'd4: ui_glyph_row=5'b10101; 3'd5: ui_glyph_row=5'b11011; 3'd6: ui_glyph_row=5'b10001; endcase
                "X": case (row) 3'd0: ui_glyph_row=5'b10001; 3'd1: ui_glyph_row=5'b01010; 3'd2: ui_glyph_row=5'b00100; 3'd3: ui_glyph_row=5'b00100; 3'd4: ui_glyph_row=5'b00100; 3'd5: ui_glyph_row=5'b01010; 3'd6: ui_glyph_row=5'b10001; endcase
                "Y": case (row) 3'd0: ui_glyph_row=5'b10001; 3'd1: ui_glyph_row=5'b01010; 3'd2: ui_glyph_row=5'b00100; 3'd3: ui_glyph_row=5'b00100; 3'd4: ui_glyph_row=5'b00100; 3'd5: ui_glyph_row=5'b00100; 3'd6: ui_glyph_row=5'b00100; endcase
                "a": case (row) 3'd0: ui_glyph_row=5'b00000; 3'd1: ui_glyph_row=5'b00000; 3'd2: ui_glyph_row=5'b01110; 3'd3: ui_glyph_row=5'b00001; 3'd4: ui_glyph_row=5'b01111; 3'd5: ui_glyph_row=5'b10001; 3'd6: ui_glyph_row=5'b01111; endcase
                "c": case (row) 3'd0: ui_glyph_row=5'b00000; 3'd1: ui_glyph_row=5'b00000; 3'd2: ui_glyph_row=5'b01110; 3'd3: ui_glyph_row=5'b10000; 3'd4: ui_glyph_row=5'b10000; 3'd5: ui_glyph_row=5'b10001; 3'd6: ui_glyph_row=5'b01110; endcase
                "d": case (row) 3'd0: ui_glyph_row=5'b00001; 3'd1: ui_glyph_row=5'b00001; 3'd2: ui_glyph_row=5'b01101; 3'd3: ui_glyph_row=5'b10011; 3'd4: ui_glyph_row=5'b10001; 3'd5: ui_glyph_row=5'b10011; 3'd6: ui_glyph_row=5'b01101; endcase
                "e": case (row) 3'd0: ui_glyph_row=5'b00000; 3'd1: ui_glyph_row=5'b00000; 3'd2: ui_glyph_row=5'b01110; 3'd3: ui_glyph_row=5'b10001; 3'd4: ui_glyph_row=5'b11110; 3'd5: ui_glyph_row=5'b10000; 3'd6: ui_glyph_row=5'b01110; endcase
                "g": case (row) 3'd0: ui_glyph_row=5'b00000; 3'd1: ui_glyph_row=5'b00000; 3'd2: ui_glyph_row=5'b01111; 3'd3: ui_glyph_row=5'b10001; 3'd4: ui_glyph_row=5'b01111; 3'd5: ui_glyph_row=5'b00001; 3'd6: ui_glyph_row=5'b01110; endcase
                "h": case (row) 3'd0: ui_glyph_row=5'b10000; 3'd1: ui_glyph_row=5'b10000; 3'd2: ui_glyph_row=5'b10110; 3'd3: ui_glyph_row=5'b11001; 3'd4: ui_glyph_row=5'b10001; 3'd5: ui_glyph_row=5'b10001; 3'd6: ui_glyph_row=5'b10001; endcase
                "i": case (row) 3'd0: ui_glyph_row=5'b00100; 3'd1: ui_glyph_row=5'b00000; 3'd2: ui_glyph_row=5'b01100; 3'd3: ui_glyph_row=5'b00100; 3'd4: ui_glyph_row=5'b00100; 3'd5: ui_glyph_row=5'b00100; 3'd6: ui_glyph_row=5'b01110; endcase
                "l": case (row) 3'd0: ui_glyph_row=5'b01100; 3'd1: ui_glyph_row=5'b00100; 3'd2: ui_glyph_row=5'b00100; 3'd3: ui_glyph_row=5'b00100; 3'd4: ui_glyph_row=5'b00100; 3'd5: ui_glyph_row=5'b00100; 3'd6: ui_glyph_row=5'b01110; endcase
                "n": case (row) 3'd0: ui_glyph_row=5'b00000; 3'd1: ui_glyph_row=5'b00000; 3'd2: ui_glyph_row=5'b10110; 3'd3: ui_glyph_row=5'b11001; 3'd4: ui_glyph_row=5'b10001; 3'd5: ui_glyph_row=5'b10001; 3'd6: ui_glyph_row=5'b10001; endcase
                "o": case (row) 3'd0: ui_glyph_row=5'b00000; 3'd1: ui_glyph_row=5'b00000; 3'd2: ui_glyph_row=5'b01110; 3'd3: ui_glyph_row=5'b10001; 3'd4: ui_glyph_row=5'b10001; 3'd5: ui_glyph_row=5'b10001; 3'd6: ui_glyph_row=5'b01110; endcase
                "p": case (row) 3'd0: ui_glyph_row=5'b00000; 3'd1: ui_glyph_row=5'b00000; 3'd2: ui_glyph_row=5'b11110; 3'd3: ui_glyph_row=5'b10001; 3'd4: ui_glyph_row=5'b11110; 3'd5: ui_glyph_row=5'b10000; 3'd6: ui_glyph_row=5'b10000; endcase
                "r": case (row) 3'd0: ui_glyph_row=5'b00000; 3'd1: ui_glyph_row=5'b00000; 3'd2: ui_glyph_row=5'b10110; 3'd3: ui_glyph_row=5'b11001; 3'd4: ui_glyph_row=5'b10000; 3'd5: ui_glyph_row=5'b10000; 3'd6: ui_glyph_row=5'b10000; endcase
                "s": case (row) 3'd0: ui_glyph_row=5'b00000; 3'd1: ui_glyph_row=5'b00000; 3'd2: ui_glyph_row=5'b01111; 3'd3: ui_glyph_row=5'b10000; 3'd4: ui_glyph_row=5'b01110; 3'd5: ui_glyph_row=5'b00001; 3'd6: ui_glyph_row=5'b11110; endcase
                "t": case (row) 3'd0: ui_glyph_row=5'b00100; 3'd1: ui_glyph_row=5'b00100; 3'd2: ui_glyph_row=5'b11111; 3'd3: ui_glyph_row=5'b00100; 3'd4: ui_glyph_row=5'b00100; 3'd5: ui_glyph_row=5'b00101; 3'd6: ui_glyph_row=5'b00010; endcase
                "u": case (row) 3'd0: ui_glyph_row=5'b00000; 3'd1: ui_glyph_row=5'b00000; 3'd2: ui_glyph_row=5'b10001; 3'd3: ui_glyph_row=5'b10001; 3'd4: ui_glyph_row=5'b10001; 3'd5: ui_glyph_row=5'b10011; 3'd6: ui_glyph_row=5'b01101; endcase
                "y": case (row) 3'd0: ui_glyph_row=5'b00000; 3'd1: ui_glyph_row=5'b00000; 3'd2: ui_glyph_row=5'b10001; 3'd3: ui_glyph_row=5'b10001; 3'd4: ui_glyph_row=5'b01111; 3'd5: ui_glyph_row=5'b00001; 3'd6: ui_glyph_row=5'b01110; endcase
                "-": case (row) 3'd0: ui_glyph_row=5'b00000; 3'd1: ui_glyph_row=5'b00000; 3'd2: ui_glyph_row=5'b00000; 3'd3: ui_glyph_row=5'b11111; 3'd4: ui_glyph_row=5'b00000; 3'd5: ui_glyph_row=5'b00000; 3'd6: ui_glyph_row=5'b00000; endcase
                default: ui_glyph_row = 5'b00000;
            endcase
        end
    endfunction

    function ui_text2_pixel;
        input [5:0] text_id;
        input [9:0] x;
        input [9:0] y;
        input [9:0] x0;
        input [9:0] y0;
        reg [9:0] dx;
        reg [9:0] dy;
        reg [4:0] char_index;
        reg [2:0] glyph_x;
        reg [2:0] glyph_y;
        reg [7:0] ch;
        reg [4:0] row_bits;
        begin
            ui_text2_pixel = 1'b0;
            if (x >= x0 && y >= y0 && x < x0 + 10'd144 && y < y0 + 10'd14) begin
                dx = x - x0;
                dy = y - y0;
                char_index = dx / 10'd12;
                glyph_x = (dx >> 1) % 3'd6;
                glyph_y = dy >> 1;
                ch = ui_char(text_id, char_index);
                row_bits = ui_glyph_row(ch, glyph_y);
                if (glyph_x < 3'd5) begin
                    ui_text2_pixel = row_bits[4 - glyph_x];
                end
            end
        end
    endfunction

    function ui_bcd5_pixel;
        input [19:0] bcd;
        input [9:0] x;
        input [9:0] y;
        input [9:0] x0;
        input [9:0] y0;
        reg [9:0] dx;
        reg [9:0] dy;
        reg [4:0] char_index;
        reg [2:0] glyph_x;
        reg [2:0] glyph_y;
        reg [3:0] nibble;
        reg [7:0] ch;
        reg [4:0] row_bits;
        begin
            ui_bcd5_pixel = 1'b0;
            if (x >= x0 && y >= y0 && x < x0 + 10'd48 && y < y0 + 10'd14) begin
                dx = x - x0;
                dy = y - y0;
                char_index = dx / 10'd12;
                glyph_x = (dx >> 1) % 3'd6;
                glyph_y = dy >> 1;
                case (char_index)
                    5'd0: nibble = bcd[15:12];
                    5'd1: nibble = bcd[11:8];
                    5'd2: nibble = bcd[7:4];
                    default: nibble = bcd[3:0];
                endcase
                ch = "0" + {4'd0, nibble};
                row_bits = ui_glyph_row(ch, glyph_y);
                if (glyph_x < 3'd5) begin
                    ui_bcd5_pixel = row_bits[4 - glyph_x];
                end
            end
        end
    endfunction

    function [19:0] bin16_to_bcd5;
        input [15:0] bin;
        integer i;
        reg [35:0] shift;
        begin
            shift = 36'd0;
            shift[15:0] = bin;
            for (i = 0; i < 16; i = i + 1) begin
                if (shift[19:16] >= 4'd5) shift[19:16] = shift[19:16] + 4'd3;
                if (shift[23:20] >= 4'd5) shift[23:20] = shift[23:20] + 4'd3;
                if (shift[27:24] >= 4'd5) shift[27:24] = shift[27:24] + 4'd3;
                if (shift[31:28] >= 4'd5) shift[31:28] = shift[31:28] + 4'd3;
                if (shift[35:32] >= 4'd5) shift[35:32] = shift[35:32] + 4'd3;
                shift = shift << 1;
            end
            bin16_to_bcd5 = shift[35:16];
        end
    endfunction

    function [3:0] sevenseg_to_nibble;
        input [7:0] seg;
        begin
            case (seg)
                8'hC0: sevenseg_to_nibble = 4'd0;
                8'hF9: sevenseg_to_nibble = 4'd1;
                8'hA4: sevenseg_to_nibble = 4'd2;
                8'hB0: sevenseg_to_nibble = 4'd3;
                8'h99: sevenseg_to_nibble = 4'd4;
                8'h92: sevenseg_to_nibble = 4'd5;
                8'h82: sevenseg_to_nibble = 4'd6;
                8'hF8: sevenseg_to_nibble = 4'd7;
                8'h80: sevenseg_to_nibble = 4'd8;
                8'h90: sevenseg_to_nibble = 4'd9;
                default: sevenseg_to_nibble = 4'd0;
            endcase
        end
    endfunction

    always @(posedge clk100) begin
        if (reset_active) begin
            pix_div <= 2'b00;
            h_count <= 10'd0;
            v_count <= 10'd0;
            frame_count <= 24'd0;
            slow_count <= 27'd0;
        end else begin
            slow_count <= slow_count + 27'd1;
            pix_div <= pix_div + 2'b01;
            if (pix_tick) begin
                if (h_count == H_TOTAL - 1) begin
                    h_count <= 10'd0;
                    if (v_count == V_TOTAL - 1) begin
                        v_count <= 10'd0;
                        frame_count <= frame_count + 24'd1;
                    end else begin
                        v_count <= v_count + 10'd1;
                    end
                end else begin
                    h_count <= h_count + 10'd1;
                end
            end
        end
    end
    always @(posedge clk100) begin
        vga_hs <= ~((h_count >= H_VISIBLE + H_FRONT) &&
                    (h_count < H_VISIBLE + H_FRONT + H_SYNC));
        vga_vs <= ~((v_count >= V_VISIBLE + V_FRONT) &&
                    (v_count < V_VISIBLE + V_FRONT + V_SYNC));
    end

    always @(posedge clk100) begin
        if (reset_active) begin
            mb_note_tracks <= 96'd0;
            mb_hold_tracks <= 96'd0;
            mb_button_tracks <= 3'd0;
        end else if (mb_mode) begin
            if (mb_an_status[7:5] == 3'b001) begin
                case (mb_an_status[4:0])
                    5'd0:  mb_note_tracks[7:0]    <= mb_seg_status;
                    5'd1:  mb_note_tracks[15:8]   <= mb_seg_status;
                    5'd2:  mb_note_tracks[23:16]  <= mb_seg_status;
                    5'd3:  mb_note_tracks[31:24]  <= mb_seg_status;
                    5'd4:  mb_note_tracks[39:32]  <= mb_seg_status;
                    5'd5:  mb_note_tracks[47:40]  <= mb_seg_status;
                    5'd6:  mb_note_tracks[55:48]  <= mb_seg_status;
                    5'd7:  mb_note_tracks[63:56]  <= mb_seg_status;
                    5'd8:  mb_note_tracks[71:64]  <= mb_seg_status;
                    5'd9:  mb_note_tracks[79:72]  <= mb_seg_status;
                    5'd10: mb_note_tracks[87:80]  <= mb_seg_status;
                    5'd11: mb_note_tracks[95:88]  <= mb_seg_status;
                    5'd12: mb_hold_tracks[7:0]    <= mb_seg_status;
                    5'd13: mb_hold_tracks[15:8]   <= mb_seg_status;
                    5'd14: mb_hold_tracks[23:16]  <= mb_seg_status;
                    5'd15: mb_hold_tracks[31:24]  <= mb_seg_status;
                    5'd16: mb_hold_tracks[39:32]  <= mb_seg_status;
                    5'd17: mb_hold_tracks[47:40]  <= mb_seg_status;
                    5'd18: mb_hold_tracks[55:48]  <= mb_seg_status;
                    5'd19: mb_hold_tracks[63:56]  <= mb_seg_status;
                    5'd20: mb_hold_tracks[71:64]  <= mb_seg_status;
                    5'd21: mb_hold_tracks[79:72]  <= mb_seg_status;
                    5'd22: mb_hold_tracks[87:80]  <= mb_seg_status;
                    5'd23: mb_hold_tracks[95:88]  <= mb_seg_status;
                    5'd24: mb_button_tracks       <= mb_seg_status[2:0];
                    default: begin
                    end
                endcase
            end else begin
                case (mb_an_status)
                    8'b1110_1111: mb_display_digit3 <= sevenseg_to_nibble(mb_seg_status);
                    8'b1101_1111: mb_display_digit2 <= sevenseg_to_nibble(mb_seg_status);
                    8'b1011_1111: mb_display_digit1 <= sevenseg_to_nibble(mb_seg_status);
                    8'b0111_1111: mb_display_digit0 <= sevenseg_to_nibble(mb_seg_status);
                    default: begin
                    end
                endcase
            end
        end
    end

    always @(*) begin
        if (!ui_audio_enabled) begin
            led_pattern = slow_count[25] ? 16'h03c0 : 16'h0180;
            led_level = 8'd12 + (led_breathe >> 1);
        end else if (ui_finished) begin
            led_pattern = 16'hffff;
            led_level = 8'd28 + (led_breathe >> 1);
        end else if (ui_paused) begin
            led_pattern = slow_count[25] ? 16'haaaa : 16'h5555;
            led_level = 8'd16 + (led_breathe >> 1);
        end else begin
            case (slow_count[24:22])
                3'd0: led_pattern = 16'h0180;
                3'd1: led_pattern = 16'h03c0;
                3'd2: led_pattern = 16'h07e0;
                3'd3: led_pattern = 16'h0ff0;
                3'd4: led_pattern = 16'h1ff8;
                3'd5: led_pattern = 16'h3ffc;
                3'd6: led_pattern = 16'h7ffe;
                default: led_pattern = 16'hffff;
            endcase
            led_level = 8'd28 + (led_breathe >> 2);
            if (led_note_near_judge) begin
                led_pattern = {led_left_active ? 4'hf : 4'h0,
                               led_mid_active ? 8'hff : 8'h00,
                               led_right_active ? 4'hf : 4'h0};
                led_level = 8'd176 + (led_breathe >> 2);
            end
            if (ui_buttons != 3'd0) begin
                led_pattern = {ui_buttons[0] ? 4'hf : 4'h0,
                               ui_buttons[1] ? 8'hff : 8'h00,
                               ui_buttons[2] ? 4'hf : 4'h0};
                led_level = 8'hff;
            end
        end
        diag_led = (led_pwm < led_level) ? led_pattern : 16'd0;

        if (!ui_audio_enabled || ui_finished) begin
            diag_rgb = 6'b111_111; // ready/finish: white
        end else begin
            case (ui_judgement)
                4'd2: diag_rgb = 6'b010_010; // good: green
                4'd1: diag_rgb = 6'b100_100; // bad: blue on this board wiring
                4'd0: diag_rgb = 6'b001_001; // miss: red on this board wiring
                default: diag_rgb = (ui_buttons != 3'd0) ? 6'b111_111 : 6'b000_000;
            endcase
        end
        diag_an = mb_game_an;
        diag_seg = mb_game_seg;
    end

    always @(*) begin
        game_row = 6'd0;
        game_lane = 3'd0;
        game_lane_mask = 32'd0;
        game_hold_lane_mask = 32'd0;
        game_note_pixel = 1'b0;
        game_hold_pixel = 1'b0;
        game_button_pixel = 1'b0;
        ui_text_pixel = ui_text2_pixel(5'd0, h_count, v_count, 10'd24, 10'd24) ||   // SONG
                        ui_text2_pixel(6'd49, h_count, v_count, 10'd92, 10'd24) ||  // SW0-1
                        ui_text2_pixel(5'd1, h_count, v_count, 10'd32, 10'd58) ||   // CANON
                        ui_text2_pixel(5'd2, h_count, v_count, 10'd32, 10'd102) ||  // FADE
                        ui_text2_pixel(6'd53, h_count, v_count, 10'd32, 10'd140) || // Aphasia
                        ui_text2_pixel(5'd3, h_count, v_count, 10'd24, 10'd170) ||  // KEYS
                        ui_text2_pixel(5'd4, h_count, v_count, 10'd32, 10'd204) ||  // L C R
                        ui_text2_pixel(6'd57, h_count, v_count, 10'd24, 10'd244) || // Mute
                        ui_text2_pixel(6'd58, h_count, v_count, 10'd92, 10'd244) || // SW2
                        ui_text2_pixel(6'd51, h_count, v_count, 10'd24, 10'd270) || // Pause
                        ui_text2_pixel(6'd52, h_count, v_count, 10'd96, 10'd270) || // SW15
                        ui_text2_pixel(5'd11, h_count, v_count, 10'd24, 10'd306) || // VS1003
                        ui_text2_pixel(6'd54, h_count, v_count, 10'd104, 10'd306) || // SoC
                        ui_text2_pixel(6'd55, h_count, v_count, 10'd24, 10'd334) || // MIDI
                        ui_text2_pixel(5'd14, h_count, v_count, 10'd96, 10'd334) || // ON
                        ui_text2_pixel(5'd5, h_count, v_count, 10'd480, 10'd24) ||  // SPEED
                        ui_text2_pixel(6'd50, h_count, v_count, 10'd548, 10'd24) || // SW3-5
                        ui_text2_pixel(game_speed_text_id, h_count, v_count, 10'd496, 10'd58) ||
                        ui_text2_pixel(5'd31, h_count, v_count, 10'd480, 10'd94) || // Vol
                        ui_text2_pixel(6'd48, h_count, v_count, 10'd536, 10'd94) || // U-D Vol
                        ui_text2_pixel(ui_volume_text_id, h_count, v_count, 10'd496, 10'd128) ||
                        ui_text2_pixel(5'd25, h_count, v_count, 10'd480, 10'd174) || // SCORE
                        ui_bcd5_pixel(ui_score_bcd, h_count, v_count, 10'd496, 10'd206) ||
                        ui_text2_pixel(5'd7, h_count, v_count, 10'd480, 10'd252) || // JUDGE
                        ui_text2_pixel(ui_judgement_text_id, h_count, v_count, 10'd496, 10'd286);
        ui_box_pixel = ((h_count >= 10'd20 && h_count < 10'd156 && v_count >= 10'd48 && v_count < 10'd88) &&
                        (h_count < 10'd23 || h_count >= 10'd153 || v_count < 10'd51 || v_count >= 10'd85)) ||
                       ((h_count >= 10'd20 && h_count < 10'd156 && v_count >= 10'd92 && v_count < 10'd132) &&
                        (h_count < 10'd23 || h_count >= 10'd153 || v_count < 10'd95 || v_count >= 10'd129)) ||
                       ((h_count >= 10'd20 && h_count < 10'd156 && v_count >= 10'd136 && v_count < 10'd166) &&
                        (h_count < 10'd23 || h_count >= 10'd153 || v_count < 10'd139 || v_count >= 10'd163)) ||
                       ((h_count >= 10'd20 && h_count < 10'd156 && v_count >= 10'd194 && v_count < 10'd232) &&
                        (h_count < 10'd23 || h_count >= 10'd153 || v_count < 10'd197 || v_count >= 10'd229)) ||
                       ((h_count >= 10'd20 && h_count < 10'd156 && v_count >= 10'd298 && v_count < 10'd358) &&
                        (h_count < 10'd23 || h_count >= 10'd153 || v_count < 10'd301 || v_count >= 10'd355)) ||
                       ((h_count >= 10'd484 && h_count < 10'd620 && v_count >= 10'd48 && v_count < 10'd82) &&
                        (h_count < 10'd487 || h_count >= 10'd617 || v_count < 10'd51 || v_count >= 10'd79)) ||
                       ((h_count >= 10'd484 && h_count < 10'd620 && v_count >= 10'd118 && v_count < 10'd152) &&
                        (h_count < 10'd487 || h_count >= 10'd617 || v_count < 10'd121 || v_count >= 10'd149)) ||
                       ((h_count >= 10'd484 && h_count < 10'd620 && v_count >= 10'd198 && v_count < 10'd232) &&
                        (h_count < 10'd487 || h_count >= 10'd617 || v_count < 10'd201 || v_count >= 10'd229)) ||
                       ((h_count >= 10'd484 && h_count < 10'd620 && v_count >= 10'd278 && v_count < 10'd320) &&
                        (h_count < 10'd487 || h_count >= 10'd617 || v_count < 10'd281 || v_count >= 10'd317));
        ui_line_pixel = (h_count == 10'd176 || h_count == 10'd463);
        ui_selected_pixel = (ui_song_select == 2'd0 &&
                             h_count >= 10'd24 && h_count < 10'd152 && v_count >= 10'd52 && v_count < 10'd84) ||
                            (ui_song_select == 2'd1 &&
                             h_count >= 10'd24 && h_count < 10'd152 && v_count >= 10'd96 && v_count < 10'd128) ||
                            (ui_song_select == 2'd2 &&
                             h_count >= 10'd24 && h_count < 10'd152 && v_count >= 10'd140 && v_count < 10'd162);

        if (!active_video) begin
            vga_r = 4'h0;
            vga_g = 4'h0;
            vga_b = 4'h0;
        end else if (h_count >= 10'd200 && h_count < 10'd440 &&
                     v_count >= 10'd32 && v_count < 10'd416) begin
            game_row = (v_count - 10'd32) / 10'd12;
            game_lane = (h_count - 10'd200) / 10'd80;
            case (game_lane)
                3'd0: game_lane_mask = ui_note_tracks[31:0];
                3'd1: game_lane_mask = ui_note_tracks[63:32];
                3'd2: game_lane_mask = ui_note_tracks[95:64];
                default: game_lane_mask = 32'd0;
            endcase
            case (game_lane)
                3'd0: game_hold_lane_mask = ui_hold_tracks[31:0];
                3'd1: game_hold_lane_mask = ui_hold_tracks[63:32];
                3'd2: game_hold_lane_mask = ui_hold_tracks[95:64];
                default: game_hold_lane_mask = 32'd0;
            endcase
            game_note_pixel = game_lane_mask[game_row[4:0]];
            game_hold_pixel = game_hold_lane_mask[game_row[4:0]];
            game_button_pixel = ((h_count - 10'd200) % 10'd80 >= 10'd8) &&
                                ((h_count - 10'd200) % 10'd80 < 10'd72) &&
                                (v_count >= 10'd338) && (v_count < 10'd378);

            if (((h_count - 10'd200) % 10'd80 < 10'd3) ||
                h_count == 10'd439) begin
                vga_r = 4'h7;
                vga_g = 4'h7;
                vga_b = 4'h7;
            end else if (v_count >= 10'd358 && v_count < 10'd362) begin
                case (ui_judgement)
                    4'd2: begin vga_r = 4'h2; vga_g = 4'hf; vga_b = 4'h2; end
                    4'd1: begin vga_r = 4'h2; vga_g = 4'h6; vga_b = 4'hf; end
                    4'd0: begin vga_r = 4'hf; vga_g = 4'h1; vga_b = 4'h1; end
                    default: begin vga_r = 4'hc; vga_g = 4'hc; vga_b = 4'hc; end
                endcase
            end else if (game_note_pixel &&
                         ((h_count - 10'd200) % 10'd80 >= 10'd6) &&
                         ((h_count - 10'd200) % 10'd80 < 10'd76) &&
                         ((v_count - 10'd32) % 10'd12 >= 10'd2) &&
                         ((v_count - 10'd32) % 10'd12 < 10'd10)) begin
                vga_r = 4'hf;
                vga_g = 4'hf;
                vga_b = 4'hf;
            end else if (game_hold_pixel &&
                         ((h_count - 10'd200) % 10'd80 >= 10'd6) &&
                         ((h_count - 10'd200) % 10'd80 < 10'd76)) begin
                vga_r = hold_blend_r;
                vga_g = hold_blend_g;
                vga_b = hold_blend_b;
            end else if (game_button_pixel) begin
                if (ui_buttons[game_lane]) begin
                    case (ui_judgement)
                        4'd2: begin vga_r = 4'h2; vga_g = 4'hf; vga_b = 4'h2; end
                        4'd1: begin vga_r = 4'h2; vga_g = 4'h6; vga_b = 4'hf; end
                        4'd0: begin vga_r = 4'hf; vga_g = 4'h1; vga_b = 4'h1; end
                        default: begin vga_r = 4'hf; vga_g = 4'hf; vga_b = 4'hf; end
                    endcase
                end else if (((h_count - 10'd200) % 10'd80 < 10'd12) ||
                             ((h_count - 10'd200) % 10'd80 >= 10'd68) ||
                             (v_count < 10'd342) || (v_count >= 10'd374)) begin
                    vga_r = 4'hd;
                    vga_g = 4'hd;
                    vga_b = 4'hd;
                end else begin
                    vga_r = 4'h0;
                    vga_g = 4'h0;
                    vga_b = 4'h0;
                end
            end else if ((v_count - 10'd32) % 10'd48 < 10'd2) begin
                vga_r = 4'h2;
                vga_g = 4'h2;
                vga_b = 4'h2;
            end else begin
                vga_r = track_bg_r;
                vga_g = track_bg_g;
                vga_b = track_bg_b;
            end
        end else if (!ui_audio_enabled) begin
            if (border) begin
                vga_r = 4'h8;
                vga_g = 4'h8;
                vga_b = 4'h8;
            end else if (h_count < 10'd176 || h_count >= 10'd464) begin
                if (ui_text_pixel) begin
                    vga_r = 4'he; vga_g = 4'he; vga_b = 4'he;
                end else if (ui_box_pixel || ui_line_pixel) begin
                    vga_r = 4'h6; vga_g = 4'h6; vga_b = 4'h6;
                end else begin
                    vga_r = 4'h1;
                    vga_g = 4'h1;
                    vga_b = 4'h1;
                end
            end else if (h_count >= 10'd200 && h_count < 10'd440 &&
                         v_count >= 10'd40 && v_count < 10'd424) begin
                if ((h_count - 10'd200) % 10'd80 < 10'd3 ||
                    (v_count >= 10'd356 && v_count < 10'd364)) begin
                    vga_r = 4'h8;
                    vga_g = 4'h8;
                    vga_b = 4'h8;
                end else begin
                    vga_r = track_bg_r;
                    vga_g = track_bg_g;
                    vga_b = track_bg_b;
                end
            end else if (center_box) begin
                vga_r = 4'hf;
                vga_g = 4'hf;
                vga_b = 4'hf;
            end else begin
                vga_r = 4'h0;
                vga_g = 4'h0;
                vga_b = 4'h0;
            end
        end else if (h_count < 10'd176) begin
            if (ui_text_pixel) begin
                vga_r = 4'hf; vga_g = 4'hf; vga_b = 4'hf;
            end else if (ui_selected_pixel) begin
                vga_r = 4'h5; vga_g = 4'h5; vga_b = 4'h5;
            end else if (ui_box_pixel || ui_line_pixel) begin
                vga_r = 4'h8; vga_g = 4'h8; vga_b = 4'h8;
            end else begin
                vga_r = 4'h1; vga_g = 4'h1; vga_b = 4'h1;
            end
        end else if (h_count >= 10'd464) begin
            if (ui_text_pixel) begin
                vga_r = 4'hf; vga_g = 4'hf; vga_b = 4'hf;
            end else if (v_count >= 10'd284 && v_count < 10'd304 && h_count >= 10'd486 && h_count < 10'd490) begin
                case (ui_judgement)
                    4'd2: begin vga_r = 4'h2; vga_g = 4'hf; vga_b = 4'h2; end
                    4'd1: begin vga_r = 4'h2; vga_g = 4'h6; vga_b = 4'hf; end
                    4'd0: begin vga_r = 4'hf; vga_g = 4'h1; vga_b = 4'h1; end
                    default: begin vga_r = 4'h4; vga_g = 4'h4; vga_b = 4'h4; end
                endcase
            end else if (ui_box_pixel || ui_line_pixel) begin
                vga_r = 4'h8; vga_g = 4'h8; vga_b = 4'h8;
            end else begin
                vga_r = 4'h1; vga_g = 4'h1; vga_b = 4'h1;
            end
        end else if (v_count >= 10'd332 && v_count < 10'd392 &&
                     h_count >= 10'd200 && h_count < 10'd440) begin
            game_row = (v_count - 10'd32) / 10'd12;
            game_lane = (h_count - 10'd200) / 10'd80;
            case (game_lane)
                3'd0: game_lane_mask = ui_note_tracks[31:0];
                3'd1: game_lane_mask = ui_note_tracks[63:32];
                3'd2: game_lane_mask = ui_note_tracks[95:64];
                default: game_lane_mask = 32'd0;
            endcase
            case (game_lane)
                3'd0: game_hold_lane_mask = ui_hold_tracks[31:0];
                3'd1: game_hold_lane_mask = ui_hold_tracks[63:32];
                3'd2: game_hold_lane_mask = ui_hold_tracks[95:64];
                default: game_hold_lane_mask = 32'd0;
            endcase
            game_note_pixel = game_lane_mask[game_row[4:0]];
            game_hold_pixel = game_hold_lane_mask[game_row[4:0]];
            game_button_pixel = ui_buttons[game_lane] &&
                                ((h_count - 10'd200) % 10'd80 >= 10'd8) &&
                                ((h_count - 10'd200) % 10'd80 < 10'd72) &&
                                (v_count >= 10'd346) && (v_count < 10'd374);
            if (ui_text_pixel) begin
                vga_r = 4'hf; vga_g = 4'hf; vga_b = 4'hf;
            end else if (ui_selected_pixel) begin
                vga_r = 4'h5; vga_g = 4'h5; vga_b = 4'h5;
            end else if (ui_box_pixel || ui_line_pixel) begin
                vga_r = 4'h8; vga_g = 4'h8; vga_b = 4'h8;
            end else begin
                vga_r = 4'h1; vga_g = 4'h1; vga_b = 4'h1;
            end
        end else if (h_count >= 10'd464) begin
            if (ui_text_pixel) begin
                vga_r = 4'hf; vga_g = 4'hf; vga_b = 4'hf;
            end else if (v_count >= 10'd284 && v_count < 10'd304 && h_count >= 10'd486 && h_count < 10'd490) begin
                case (ui_judgement)
                    4'd2: begin vga_r = 4'h2; vga_g = 4'hf; vga_b = 4'h2; end
                    4'd1: begin vga_r = 4'h2; vga_g = 4'h6; vga_b = 4'hf; end
                    4'd0: begin vga_r = 4'hf; vga_g = 4'h1; vga_b = 4'h1; end
                    default: begin vga_r = 4'h4; vga_g = 4'h4; vga_b = 4'h4; end
                endcase
            end else if (ui_box_pixel || ui_line_pixel) begin
                vga_r = 4'h8; vga_g = 4'h8; vga_b = 4'h8;
            end else begin
                vga_r = 4'h1; vga_g = 4'h1; vga_b = 4'h1;
            end
        end else if (v_count >= 10'd332 && v_count < 10'd392 &&
                     h_count >= 10'd200 && h_count < 10'd440) begin
            game_row = (v_count - 10'd32) / 10'd12;
            game_lane = (h_count - 10'd200) / 10'd80;
            case (game_lane)
                3'd0: game_lane_mask = ui_note_tracks[31:0];
                3'd1: game_lane_mask = ui_note_tracks[63:32];
                3'd2: game_lane_mask = ui_note_tracks[95:64];
                default: game_lane_mask = 32'd0;
            endcase
            case (game_lane)
                3'd0: game_hold_lane_mask = ui_hold_tracks[31:0];
                3'd1: game_hold_lane_mask = ui_hold_tracks[63:32];
                3'd2: game_hold_lane_mask = ui_hold_tracks[95:64];
                default: game_hold_lane_mask = 32'd0;
            endcase
            game_note_pixel = game_lane_mask[game_row[4:0]];
            game_hold_pixel = game_hold_lane_mask[game_row[4:0]];
            game_button_pixel = ui_buttons[game_lane] &&
                                ((h_count - 10'd200) % 10'd80 >= 10'd8) &&
                                ((h_count - 10'd200) % 10'd80 < 10'd72) &&
                                (v_count >= 10'd346) && (v_count < 10'd374);

            if ((h_count - 10'd200) % 10'd80 < 10'd3) begin
                vga_r = 4'h7; vga_g = 4'h7; vga_b = 4'h7;
            end else if (game_note_pixel) begin
                vga_r = 4'hf; vga_g = 4'hf; vga_b = 4'hf;
            end else if (game_hold_pixel &&
                         ((h_count - 10'd200) % 10'd80 >= 10'd6) &&
                         ((h_count - 10'd200) % 10'd80 < 10'd76)) begin
                vga_r = hold_blend_r;
                vga_g = hold_blend_g;
                vga_b = hold_blend_b;
            end else if (game_button_pixel) begin
                case (ui_judgement)
                    4'd2: begin vga_r = 4'h2; vga_g = 4'hf; vga_b = 4'h2; end
                    4'd1: begin vga_r = 4'h2; vga_g = 4'h6; vga_b = 4'hf; end
                    4'd0: begin vga_r = 4'hf; vga_g = 4'h1; vga_b = 4'h1; end
                    default: begin vga_r = 4'hf; vga_g = 4'hf; vga_b = 4'hf; end
                endcase
            end else if (v_count >= 10'd358 && v_count < 10'd362) begin
                case (ui_judgement)
                    4'd2: begin vga_r = 4'h2; vga_g = 4'hf; vga_b = 4'h2; end
                    4'd1: begin vga_r = 4'h2; vga_g = 4'h6; vga_b = 4'hf; end
                    4'd0: begin vga_r = 4'hf; vga_g = 4'h1; vga_b = 4'h1; end
                    default: begin vga_r = 4'ha; vga_g = 4'ha; vga_b = 4'ha; end
                endcase
            end else begin
                vga_r = track_bg_r;
                vga_g = track_bg_g;
                vga_b = track_bg_b;
            end
        end else if (h_count >= 10'd200 && h_count < 10'd440 &&
                     v_count >= 10'd32 && v_count < 10'd416) begin
            game_row = (v_count - 10'd32) / 10'd12;
            game_lane = (h_count - 10'd200) / 10'd80;
            case (game_lane)
                3'd0: game_lane_mask = ui_note_tracks[31:0];
                3'd1: game_lane_mask = ui_note_tracks[63:32];
                3'd2: game_lane_mask = ui_note_tracks[95:64];
                default: game_lane_mask = 32'd0;
            endcase
            case (game_lane)
                3'd0: game_hold_lane_mask = ui_hold_tracks[31:0];
                3'd1: game_hold_lane_mask = ui_hold_tracks[63:32];
                3'd2: game_hold_lane_mask = ui_hold_tracks[95:64];
                default: game_hold_lane_mask = 32'd0;
            endcase
            game_note_pixel = game_lane_mask[game_row[4:0]];
            game_hold_pixel = game_hold_lane_mask[game_row[4:0]];
            game_button_pixel = ui_buttons[game_lane] &&
                                ((h_count - 10'd200) % 10'd80 >= 10'd8) &&
                                ((h_count - 10'd200) % 10'd80 < 10'd72) &&
                                (v_count >= 10'd346) && (v_count < 10'd374);

            if ((h_count - 10'd200) % 10'd80 < 10'd3) begin
                vga_r = 4'h6;
                vga_g = 4'h6;
                vga_b = 4'h6;
            end else if ((v_count - 10'd32) % 10'd48 < 10'd2) begin
                vga_r = 4'h2;
                vga_g = 4'h2;
                vga_b = 4'h2;
            end else if (game_note_pixel) begin
                vga_r = 4'hf;
                vga_g = 4'hf;
                vga_b = 4'hf;
            end else if (game_hold_pixel &&
                         ((h_count - 10'd200) % 10'd80 >= 10'd6) &&
                         ((h_count - 10'd200) % 10'd80 < 10'd76)) begin
                vga_r = hold_blend_r;
                vga_g = hold_blend_g;
                vga_b = hold_blend_b;
            end else if (game_button_pixel) begin
                case (ui_judgement)
                    4'd2: begin vga_r = 4'h2; vga_g = 4'hf; vga_b = 4'h2; end
                    4'd1: begin vga_r = 4'h2; vga_g = 4'h6; vga_b = 4'hf; end
                    4'd0: begin vga_r = 4'hf; vga_g = 4'h1; vga_b = 4'h1; end
                    default: begin vga_r = 4'hf; vga_g = 4'hf; vga_b = 4'hf; end
                endcase
            end else begin
                vga_r = track_bg_r;
                vga_g = track_bg_g;
                vga_b = track_bg_b;
            end
        end else begin
            vga_r = 4'h0;
            vga_g = 4'h0;
            vga_b = 4'h0;
        end
    end
endmodule

module album_art_track_rom (
    input wire clk,
    input wire [1:0] song_select,
    input wire [9:0] pixel_x,
    input wire [9:0] pixel_y,
    input wire valid,
    output reg [11:0] rgb
);
    // Store three 120x192 indexed covers and scale each pixel by 2x on VGA.
    // The visible area remains 240x384, but the source art has more detail
    // than the previous 80x128 version.
    localparam ART_X0 = 10'd200;
    localparam ART_Y0 = 10'd32;
    localparam ART_WIDTH = 17'd120;
    localparam ART_PIXELS_PER_SONG = 17'd23040;
    localparam ART_PIXELS = 17'd69120;

    (* ram_style = "block" *) reg [3:0] art_index_mem [0:ART_PIXELS-1];
    reg [11:0] canon_palette [0:15];
    reg [11:0] fade_palette [0:15];
    reg [11:0] aphasia_palette [0:15];
    wire [7:0] art_row = (pixel_y - ART_Y0) >> 1;
    wire [6:0] art_col = (pixel_x - ART_X0) >> 1;
    wire [16:0] art_row_times_120 =
        {art_row, 6'b0} + {art_row, 5'b0} + {art_row, 4'b0} + {art_row, 3'b0};
    reg [16:0] art_addr = 17'd0;
    reg [3:0] art_index = 4'd0;
    reg [1:0] song_select_d = 2'd0;

    initial begin
        $readmemh("F:/FPGA/mircoCom/Genneral/Mini_IO/generated/album_art/track_bg_120_all_index.mem", art_index_mem);
        $readmemh("F:/FPGA/mircoCom/Genneral/Mini_IO/generated/album_art/canon_track_bg_120_palette.mem", canon_palette);
        $readmemh("F:/FPGA/mircoCom/Genneral/Mini_IO/generated/album_art/fade_track_bg_120_palette.mem", fade_palette);
        $readmemh("F:/FPGA/mircoCom/Genneral/Mini_IO/generated/album_art/aphasia_track_bg_120_palette.mem", aphasia_palette);
    end

    always @(*) begin
        case (song_select)
            2'd2: art_addr = 17'd46080 + art_row_times_120 + {10'd0, art_col};
            2'd1: art_addr = ART_PIXELS_PER_SONG + art_row_times_120 + {10'd0, art_col};
            default: art_addr = art_row_times_120 + {10'd0, art_col};
        endcase
    end

    always @(posedge clk) begin
        if (valid) begin
            art_index <= art_index_mem[art_addr];
        end
    end

    always @(posedge clk) begin
        song_select_d <= song_select;
        if (!valid || song_select == 2'd3 || song_select_d == 2'd3) begin
            rgb <= 12'h000;
        end else if (song_select_d == 2'd2) begin
            rgb <= aphasia_palette[art_index];
        end else if (song_select_d == 2'd1) begin
            rgb <= fade_palette[art_index];
        end else begin
            rgb <= canon_palette[art_index];
        end
    end
endmodule

module rhythm_mb_sevenseg (
    input wire clk,
    input wire reset,
    input wire [19:0] score_bcd,
    input wire [3:0] judgement,
    input wire ready,
    input wire paused,
    input wire finished,
    output reg [7:0] seg,
    output reg [7:0] an
);
    reg [16:0] refresh = 17'd0;

    function [7:0] digit_seg;
        input [3:0] digit;
        begin
            case (digit)
                4'd0: digit_seg = 8'b1100_0000;
                4'd1: digit_seg = 8'b1111_1001;
                4'd2: digit_seg = 8'b1010_0100;
                4'd3: digit_seg = 8'b1011_0000;
                4'd4: digit_seg = 8'b1001_1001;
                4'd5: digit_seg = 8'b1001_0010;
                4'd6: digit_seg = 8'b1000_0010;
                4'd7: digit_seg = 8'b1111_1000;
                4'd8: digit_seg = 8'b1000_0000;
                4'd9: digit_seg = 8'b1001_0000;
                4'ha: digit_seg = 8'b1000_1000; // A/good
                4'hb: digit_seg = 8'b1000_0011; // b/bad
                4'hc: digit_seg = 8'b1100_0110; // C
                4'hd: digit_seg = 8'b1010_0001; // d/done
                4'he: digit_seg = 8'b1000_0110; // E/finish
                4'hf: digit_seg = 8'b1000_1100; // P/pause
                default: digit_seg = 8'b1111_1111;
            endcase
        end
    endfunction

    function [7:0] grade_seg;
        input [15:0] score;
        begin
            if (score >= 16'h9999) begin
                grade_seg = digit_seg(4'd5); // S
            end else if (score >= 16'h9500) begin
                grade_seg = digit_seg(4'ha); // A
            end else if (score >= 16'h8500) begin
                grade_seg = digit_seg(4'hb); // b
            end else if (score >= 16'h7500) begin
                grade_seg = digit_seg(4'hc); // C
            end else if (score >= 16'h6000) begin
                grade_seg = digit_seg(4'hd); // d
            end else begin
                grade_seg = 8'b1000_1110; // F
            end
        end
    endfunction

    function [7:0] judge_seg;
        input [3:0] value;
        input [1:0] position;
        begin
            case (value)
                4'd2: begin
                    case (position)
                        2'd0: judge_seg = digit_seg(4'hd); // d
                        2'd1: judge_seg = digit_seg(4'd0); // O
                        2'd2: judge_seg = digit_seg(4'd0); // O
                        default: judge_seg = digit_seg(4'd6); // G
                    endcase
                end
                4'd1: begin
                    case (position)
                        2'd0: judge_seg = digit_seg(4'hd); // d
                        2'd1: judge_seg = digit_seg(4'ha); // A
                        2'd2: judge_seg = digit_seg(4'hb); // b
                        default: judge_seg = 8'hff;
                    endcase
                end
                4'd0: begin
                    case (position)
                        2'd0: judge_seg = digit_seg(4'd5); // S
                        2'd1: judge_seg = digit_seg(4'd5); // S
                        2'd2: judge_seg = digit_seg(4'd1); // i
                        default: judge_seg = digit_seg(4'he); // E as M approximation
                    endcase
                end
                default: judge_seg = 8'hff;
            endcase
        end
    endfunction

    always @(posedge clk) begin
        if (reset) begin
            refresh <= 17'd0;
        end else begin
            refresh <= refresh + 17'd1;
        end
    end

    always @(*) begin
        if (ready) begin
            an = 8'hff;
            seg = 8'hff;
        end else begin
            case (refresh[16:14])
                3'd0: begin an = 8'b1111_1110; seg = digit_seg(score_bcd[3:0]); end
                3'd1: begin an = 8'b1111_1101; seg = digit_seg(score_bcd[7:4]); end
                3'd2: begin an = 8'b1111_1011; seg = digit_seg(score_bcd[11:8]); end
                3'd3: begin an = 8'b1111_0111; seg = digit_seg(score_bcd[15:12]); end
                3'd4: begin an = 8'b1110_1111; seg = finished ? grade_seg(score_bcd[15:0]) : judge_seg(judgement, 2'd0); end
                3'd5: begin an = 8'b1101_1111; seg = finished ? grade_seg(score_bcd[15:0]) : judge_seg(judgement, 2'd1); end
                3'd6: begin an = 8'b1011_1111; seg = finished ? grade_seg(score_bcd[15:0]) : judge_seg(judgement, 2'd2); end
                default: begin an = 8'b0111_1111; seg = finished ? grade_seg(score_bcd[15:0]) : judge_seg(judgement, 2'd3); end
            endcase
        end
    end
endmodule


