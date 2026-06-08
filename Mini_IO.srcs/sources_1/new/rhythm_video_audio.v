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
    output wire aud_pwm,
    output wire aud_sd,
    input wire vs_dreq,
    input wire vs_miso,
    output wire vs_mosi,
    output wire vs_sclk,
    output wire vs_xcs,
    output wire vs_xdcs,
    output wire vs_xrst
);
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
    reg [16:0] ms_div = 17'd0;
    reg [7:0] canon_tick_ms = 8'd0;
    reg [10:0] canon_step = 11'd0;
    reg [9:0] edm_tick_ms = 10'd0;
    reg [8:0] edm_step = 9'd0;
    reg [11:0] sample_div = 12'd0;
    reg [10:0] pdm_acc = 11'd0;
    reg [31:0] violin1_phase_acc = 32'd0;
    reg [31:0] violin2_phase_acc = 32'd0;
    reg [31:0] violin3_phase_acc = 32'd0;
    reg [31:0] bass_phase_acc = 32'd0;
    reg [31:0] edm_lead_phase_acc = 32'd0;
    reg [31:0] edm_bass_phase_acc = 32'd0;
    reg [9:0] audio_sample = 10'd512;
    reg [9:0] vs_audio_sample = 10'd512;
    reg [9:0] bounded_sample = 10'd512;
    reg signed [11:0] smooth_delta = 12'sd0;
    reg [4:0] violin1_note_d = 5'd0;
    reg [4:0] violin2_note_d = 5'd0;
    reg [4:0] violin3_note_d = 5'd0;
    reg [4:0] bass_note_d = 5'd0;
    reg [4:0] edm_lead_note_d = 5'd0;
    reg [4:0] edm_bass_note_d = 5'd0;
    reg signed [13:0] mixed_sample = 14'sd0;
    reg [2:0] volume_level = 3'd1;
    reg [1:0] volume_button_meta = 2'd0;
    reg [1:0] volume_button_sync = 2'd0;
    reg [1:0] volume_button_prev = 2'd0;
    reg [23:0] volume_cooldown = 24'd0;
    wire [95:0] game_tracks;
    wire [95:0] game_hold_tracks;
    wire [2:0] game_hit_window;
    wire [15:0] game_score;
    wire [7:0] game_combo;
    wire [3:0] game_judgement;
    wire game_finished;
    wire [2:0] game_buttons;
    wire [2:0] button_edges;
    wire [7:0] game_seg;
    wire [7:0] game_an;
    wire [7:0] mb_game_seg;
    wire [7:0] mb_game_an;
    wire [7:0] vs1003_debug;
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

    wire pix_tick = (pix_div == 2'b11);
    wire reset_active = ~reset;
    wire active_video = (h_count < H_VISIBLE) && (v_count < V_VISIBLE);
    wire border = (h_count < 10'd8) || (h_count >= 10'd632) ||
                  (v_count < 10'd8) || (v_count >= 10'd472);
    wire center_box = (h_count >= 10'd280) && (h_count < 10'd360) &&
                      (v_count >= 10'd200) && (v_count < 10'd280);
    wire moving_bar = (v_count >= frame_count[8:0]) &&
                      (v_count < frame_count[8:0] + 10'd16);
    wire sample_tick = (sample_div == 12'd1999);
    wire canon_mode = switches[0] && !switches[1];
    wire edm_mode = switches[1];
    wire audio_enabled = switches[0] || switches[1];
    wire game_paused = switches[15];
    wire audio_playing = audio_enabled && !game_finished && !game_paused;
    wire vs1003_demo_enabled = 1'b0;
    wire vs1003_player_enabled = vs1003_demo_enabled;
    wire [1:0] game_song = edm_mode ? 2'd1 : 2'd0;
    wire vs1003_pitch_test = switches[14];
    wire [1:0] vs1003_song_select = vs1003_pitch_test ? 2'd2 : game_song;
    wire [2:0] game_speed = switches[5:3];
    wire [5:0] game_speed_text_id = 6'd17 + {3'b000, game_speed};
    wire [5:0] volume_text_id = 6'd32 + {3'b000, volume_level};
    wire [1:0] volume_button_edges = volume_button_sync & ~volume_button_prev;
    wire [5:0] game_judgement_text_id = game_paused ? 6'd44 :
                                         game_finished ? 6'd30 :
                                         (game_judgement == 4'd2) ? 6'd8 :
                                         (game_judgement == 4'd1) ? 6'd9 :
                                         (game_judgement == 4'd0) ? 6'd10 : 6'd29;
    wire [19:0] game_score_bcd = bin16_to_bcd5(game_score);
    wire [1:0] mb_game_state = mb_led_status[15:14];
    wire [1:0] mb_song_select = mb_led_status[13:12];
    wire [1:0] mb_rating_code = mb_led_status[11:10];
    wire [3:0] mb_volume_level = mb_led_status[9:6];
    wire [3:0] ui_judgement = mb_mode ? ((mb_rating_code == 2'd1) ? 4'd2 :
                                         (mb_rating_code == 2'd2) ? 4'd1 :
                                         (mb_rating_code == 2'd3) ? 4'd0 : 4'd7) :
                                         game_judgement;
    wire ui_paused = mb_mode ? (mb_game_state == 2'd2) : game_paused;
    wire ui_finished = mb_mode ? (mb_game_state == 2'd3) : game_finished;
    wire ui_audio_enabled = mb_mode ? (mb_game_state != 2'd0) : audio_enabled;
    wire [1:0] ui_song_select = mb_mode ? mb_song_select : game_song;
    wire [19:0] ui_score_bcd = mb_mode ? {4'd0, mb_display_digit3, mb_display_digit2,
                                          mb_display_digit1, mb_display_digit0} :
                                          game_score_bcd;
    wire [95:0] ui_note_tracks = mb_mode ? mb_note_tracks : game_tracks;
    wire [95:0] ui_hold_tracks = mb_mode ? mb_hold_tracks : game_hold_tracks;
    wire [2:0] ui_buttons = mb_mode ? mb_button_tracks : game_buttons;
    wire [5:0] ui_volume_text_id = mb_mode ? (6'd32 + {2'b00, mb_volume_level}) : volume_text_id;
    wire [5:0] ui_judgement_text_id = ui_paused ? 6'd44 :
                                       ui_finished ? 6'd30 :
                                       (ui_judgement == 4'd2) ? 6'd8 :
                                       (ui_judgement == 4'd1) ? 6'd9 :
                                       (ui_judgement == 4'd0) ? 6'd10 : 6'd29;
    // Nexys4 DDR board interface maps BTNC/BTNU/BTNL/BTNR/BTND to [0]/[1]/[2]/[3]/[4].
    // Game lanes use left/center/right = P17/N17/M17.
    wire [2:0] lane_button_raw = {buttons[3], buttons[0], buttons[2]};
    wire [4:0] violin1_note = canon_voice_note(canon_step, 11'd64);
    wire [4:0] violin2_note = canon_voice_note(canon_step, 11'd96);
    wire [4:0] violin3_note = canon_voice_note(canon_step, 11'd128);
    wire [4:0] bass_note = canon_bass_note(canon_step);
    wire [4:0] edm_lead_note = edm_voice_note(edm_step);
    wire [4:0] edm_bass_note = edm_bass_note_func(edm_step);
    wire [31:0] violin1_step = note_phase_step(violin1_note);
    wire [31:0] violin2_step = note_phase_step(violin2_note);
    wire [31:0] violin3_step = note_phase_step(violin3_note);
    wire [31:0] bass_step = note_phase_step(bass_note);
    wire [31:0] edm_lead_step = note_phase_step(edm_lead_note);
    wire [31:0] edm_bass_step = note_phase_step(edm_bass_note);
    wire [6:0] violin1_gain = canon_voice_gain(canon_step, 11'd64);
    wire [6:0] violin2_gain = canon_voice_gain(canon_step, 11'd96);
    wire [6:0] violin3_gain = canon_voice_gain(canon_step, 11'd128);
    wire [6:0] bass_gain = canon_bass_gain(canon_step);
    wire [6:0] edm_lead_gain = edm_voice_gain(edm_step);
    wire [6:0] edm_bass_gain = edm_bass_gain_func(edm_step);
    assign track_art_area = (h_count >= 10'd200) && (h_count < 10'd440) &&
                            (v_count >= 10'd32) && (v_count < 10'd416);
    assign track_bg_r = album_art_rgb[11:8];
    assign track_bg_g = album_art_rgb[7:4];
    assign track_bg_b = album_art_rgb[3:0];

    localparam CANON_TOTAL_STEPS = 11'd1151; // 64 bars plus delayed-voice tail
    localparam FADE_TOTAL_STEPS = 9'd63; // 16-bar opening intro, quarter-note grid
    localparam N_REST = 5'd0;
    localparam N_D3   = 5'd1;
    localparam N_E3   = 5'd2;
    localparam N_FS3  = 5'd3;
    localparam N_G3   = 5'd4;
    localparam N_A3   = 5'd5;
    localparam N_B3   = 5'd6;
    localparam N_CS4  = 5'd7;
    localparam N_D4   = 5'd8;
    localparam N_E4   = 5'd9;
    localparam N_FS4  = 5'd10;
    localparam N_G4   = 5'd11;
    localparam N_A4   = 5'd12;
    localparam N_B4   = 5'd13;
    localparam N_CS5  = 5'd14;
    localparam N_D5   = 5'd15;
    localparam N_E5   = 5'd16;
    localparam N_FS5  = 5'd17;
    localparam N_G5   = 5'd18;
    localparam N_A5   = 5'd19;
    localparam N_B5   = 5'd20;
    localparam N_CS6  = 5'd21;
    localparam N_D6   = 5'd22;
    localparam N_A2   = 5'd23;
    localparam N_C3   = 5'd24;
    localparam N_F3   = 5'd25;
    localparam N_C4   = 5'd26;
    localparam N_F4   = 5'd27;
    localparam N_C5   = 5'd28;
    localparam N_F5   = 5'd29;
    localparam N_G2   = 5'd30;
    localparam N_B2   = 5'd31;

    assign aud_sd = 1'b1;
    assign aud_pwm = pdm_acc[10] ? 1'bz : 1'b0;

    rhythm_game_core game_core_i (
        .clk(clk100),
        .reset(reset_active),
        .enable(audio_enabled),
        .paused(game_paused),
        .song_select(game_song),
        .speed_select(game_speed),
        .buttons(lane_button_raw),
        .mapped_buttons(game_buttons),
        .button_edges(button_edges),
        .tracks(game_tracks),
        .hold_tracks(game_hold_tracks),
        .hit_window(game_hit_window),
        .score(game_score),
        .combo(game_combo),
        .judgement(game_judgement),
        .finished(game_finished)
    );

    rhythm_sevenseg game_sevenseg_i (
        .clk(clk100),
        .reset(reset_active),
        .score(game_score),
        .combo(game_combo),
        .judgement(game_judgement),
        .paused(game_paused),
        .seg(game_seg),
        .an(game_an)
    );

    rhythm_mb_sevenseg mb_sevenseg_i (
        .clk(clk100),
        .reset(reset_active),
        .score_bcd(ui_score_bcd),
        .judgement(ui_judgement),
        .paused(ui_paused),
        .finished(ui_finished),
        .seg(mb_game_seg),
        .an(mb_game_an)
    );

    vs1003b_mp3_rom_player vs1003b_demo_i (
        .clk(clk100),
        .reset(reset_active),
        .enable(vs1003_player_enabled),
        .song_select(vs1003_song_select),
        .dreq(vs_dreq),
        .miso(vs_miso),
        .mosi(vs_mosi),
        .sclk(vs_sclk),
        .xcs(vs_xcs),
        .xdcs(vs_xdcs),
        .xrst(vs_xrst),
        .debug(vs1003_debug)
    );

    album_art_track_rom album_art_track_i (
        .clk(clk100),
        .song_select(ui_song_select),
        .pixel_x(h_count),
        .pixel_y(v_count),
        .valid(track_art_area),
        .rgb(album_art_rgb)
    );

    function [31:0] note_phase_step;
        input [4:0] note;
        begin
            case (note)
                N_D3:  note_phase_step = 32'd12612806; // 146.832 Hz
                N_E3:  note_phase_step = 32'd14157396; // 164.814 Hz
                N_FS3: note_phase_step = 32'd15891139; // 184.997 Hz
                N_G3:  note_phase_step = 32'd16836076; // 195.998 Hz
                N_A3:  note_phase_step = 32'd18897856; // 220.000 Hz
                N_B3:  note_phase_step = 32'd21212126; // 246.942 Hz
                N_CS4: note_phase_step = 32'd23809807; // 277.183 Hz
                N_D4:  note_phase_step = 32'd25225611; // 293.665 Hz
                N_E4:  note_phase_step = 32'd28314792; // 329.628 Hz
                N_FS4: note_phase_step = 32'd31782279; // 369.994 Hz
                N_G4:  note_phase_step = 32'd33672152; // 391.995 Hz
                N_A4:  note_phase_step = 32'd37795712; // 440.000 Hz
                N_B4:  note_phase_step = 32'd42424253; // 493.883 Hz
                N_CS5: note_phase_step = 32'd47619613; // 554.365 Hz
                N_D5:  note_phase_step = 32'd50451223; // 587.330 Hz
                N_E5:  note_phase_step = 32'd56629583; // 659.255 Hz
                N_FS5: note_phase_step = 32'd63564558; // 739.989 Hz
                N_G5:  note_phase_step = 32'd67344303; // 783.991 Hz
                N_A5:  note_phase_step = 32'd75591424; // 880.000 Hz
                N_B5:  note_phase_step = 32'd84848505; // 987.767 Hz
                N_CS6: note_phase_step = 32'd95239227; // 1108.731 Hz
                N_D6:  note_phase_step = 32'd100902446; // 1174.659 Hz
                N_A2:  note_phase_step = 32'd9448928; // 110.000 Hz
                N_C3:  note_phase_step = 32'd11236732; // 130.813 Hz
                N_F3:  note_phase_step = 32'd14999238; // 174.614 Hz
                N_C4:  note_phase_step = 32'd22473465; // 261.626 Hz
                N_F4:  note_phase_step = 32'd29998477; // 349.228 Hz
                N_C5:  note_phase_step = 32'd44946930; // 523.251 Hz
                N_F5:  note_phase_step = 32'd59996953; // 698.456 Hz
                N_G2:  note_phase_step = 32'd8418038;  // 97.999 Hz
                N_B2:  note_phase_step = 32'd10606063; // 123.471 Hz
                default: note_phase_step = 32'd0;
            endcase
        end
    endfunction

    function [7:0] ui_char;
        input [5:0] text_id;
        input [4:0] index;
        begin
            ui_char = " ";
            case (text_id)
                5'd0: begin
                    case (index)
                        5'd0: ui_char = "S"; 5'd1: ui_char = "O"; 5'd2: ui_char = "N"; 5'd3: ui_char = "G";
                        default: ui_char = " ";
                    endcase
                end
                5'd1: begin
                    case (index)
                        5'd0: ui_char = "C"; 5'd1: ui_char = "A"; 5'd2: ui_char = "N"; 5'd3: ui_char = "O"; 5'd4: ui_char = "N";
                        default: ui_char = " ";
                    endcase
                end
                5'd2: begin
                    case (index)
                        5'd0: ui_char = "F"; 5'd1: ui_char = "A"; 5'd2: ui_char = "D"; 5'd3: ui_char = "E";
                        default: ui_char = " ";
                    endcase
                end
                5'd3: begin
                    case (index)
                        5'd0: ui_char = "K"; 5'd1: ui_char = "E"; 5'd2: ui_char = "Y"; 5'd3: ui_char = "S";
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
                        5'd0: ui_char = "S"; 5'd1: ui_char = "P"; 5'd2: ui_char = "E"; 5'd3: ui_char = "E"; 5'd4: ui_char = "D";
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
                        5'd0: ui_char = "J"; 5'd1: ui_char = "U"; 5'd2: ui_char = "D"; 5'd3: ui_char = "G"; 5'd4: ui_char = "E";
                        default: ui_char = " ";
                    endcase
                end
                5'd8: begin
                    case (index)
                        5'd0: ui_char = "G"; 5'd1: ui_char = "O"; 5'd2: ui_char = "O"; 5'd3: ui_char = "D";
                        default: ui_char = " ";
                    endcase
                end
                5'd9: begin
                    case (index)
                        5'd0: ui_char = "B"; 5'd1: ui_char = "A"; 5'd2: ui_char = "D";
                        default: ui_char = " ";
                    endcase
                end
                5'd10: begin
                    case (index)
                        5'd0: ui_char = "M"; 5'd1: ui_char = "I"; 5'd2: ui_char = "S"; 5'd3: ui_char = "S";
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
                        5'd0: ui_char = "S"; 5'd1: ui_char = "C"; 5'd2: ui_char = "O"; 5'd3: ui_char = "R"; 5'd4: ui_char = "E";
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
                        5'd0: ui_char = "R"; 5'd1: ui_char = "E"; 5'd2: ui_char = "A"; 5'd3: ui_char = "D"; 5'd4: ui_char = "Y";
                        default: ui_char = " ";
                    endcase
                end
                5'd30: begin
                    case (index)
                        5'd0: ui_char = "F"; 5'd1: ui_char = "I"; 5'd2: ui_char = "N"; 5'd3: ui_char = "I"; 5'd4: ui_char = "S"; 5'd5: ui_char = "H";
                        default: ui_char = " ";
                    endcase
                end
                5'd31: begin
                    case (index)
                        5'd0: ui_char = "V"; 5'd1: ui_char = "O"; 5'd2: ui_char = "L";
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
                        5'd0: ui_char = "U"; 5'd1: ui_char = "D"; 5'd2: ui_char = " "; 5'd3: ui_char = "V"; 5'd4: ui_char = "O"; 5'd5: ui_char = "L";
                        default: ui_char = " ";
                    endcase
                end
                6'd41: begin
                    case (index)
                        5'd0: ui_char = "S"; 5'd1: ui_char = "W"; 5'd2: ui_char = "0"; 5'd3: ui_char = "-"; 5'd4: ui_char = "1";
                        default: ui_char = " ";
                    endcase
                end
                6'd42: begin
                    case (index)
                        5'd0: ui_char = "S"; 5'd1: ui_char = "W"; 5'd2: ui_char = "5"; 5'd3: ui_char = "-"; 5'd4: ui_char = "3";
                        default: ui_char = " ";
                    endcase
                end
                6'd43: begin
                    case (index)
                        5'd0: ui_char = "S"; 5'd1: ui_char = "W"; 5'd2: ui_char = "2";
                        default: ui_char = " ";
                    endcase
                end
                6'd44: begin
                    case (index)
                        5'd0: ui_char = "P"; 5'd1: ui_char = "A"; 5'd2: ui_char = "U"; 5'd3: ui_char = "S"; 5'd4: ui_char = "E";
                        default: ui_char = " ";
                    endcase
                end
                6'd45: begin
                    case (index)
                        5'd0: ui_char = "S"; 5'd1: ui_char = "W"; 5'd2: ui_char = "1"; 5'd3: ui_char = "5";
                        default: ui_char = " ";
                    endcase
                end
                6'd46: begin
                    case (index)
                        5'd0: ui_char = "A"; 5'd1: ui_char = "P"; 5'd2: ui_char = "H"; 5'd3: ui_char = "A";
                        5'd4: ui_char = "S"; 5'd5: ui_char = "I"; 5'd6: ui_char = "A";
                        default: ui_char = " ";
                    endcase
                end
                6'd47: begin
                    case (index)
                        5'd0: ui_char = "M"; 5'd1: ui_char = "B";
                        default: ui_char = " ";
                    endcase
                end
                6'd48: begin
                    case (index)
                        5'd0: ui_char = "M"; 5'd1: ui_char = "I"; 5'd2: ui_char = "D"; 5'd3: ui_char = "I";
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
            if (x >= x0 && y >= y0 && x < x0 + 10'd60 && y < y0 + 10'd14) begin
                dx = x - x0;
                dy = y - y0;
                char_index = dx / 10'd12;
                glyph_x = (dx >> 1) % 3'd6;
                glyph_y = dy >> 1;
                case (char_index)
                    5'd0: nibble = bcd[19:16];
                    5'd1: nibble = bcd[15:12];
                    5'd2: nibble = bcd[11:8];
                    5'd3: nibble = bcd[7:4];
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

    function [4:0] canon_bass_note;
        input [10:0] step;
        begin
            case ((step / 11'd8) % 11'd8)
                11'd0: canon_bass_note = N_D3;
                11'd1: canon_bass_note = N_A3;
                11'd2: canon_bass_note = N_B3;
                11'd3: canon_bass_note = N_FS3;
                11'd4: canon_bass_note = N_G3;
                11'd5: canon_bass_note = N_D3;
                11'd6: canon_bass_note = N_G3;
                default: canon_bass_note = N_A3;
            endcase
        end
    endfunction

    function [10:0] step_pos_ms;
        input [3:0] sixteenth_pos;
        begin
            step_pos_ms = {7'd0, sixteenth_pos} * 11'd188 + {3'd0, canon_tick_ms};
        end
    endfunction

    function [6:0] envelope_gain;
        input [11:0] pos_ms;
        input [11:0] dur_ms;
        input is_rest;
        reg [11:0] remain_ms;
        reg [11:0] edge_ms;
        begin
            if (is_rest) begin
                envelope_gain = 7'd0;
            end else begin
                remain_ms = (dur_ms > pos_ms) ? (dur_ms - pos_ms) : 10'd0;
                edge_ms = (pos_ms < remain_ms) ? pos_ms : remain_ms;
                if (edge_ms >= 11'd24) begin
                    envelope_gain = 7'd64;
                end else begin
                    envelope_gain = edge_ms[6:0] + (edge_ms[6:0] << 1);
                end
            end
        end
    endfunction

    function [6:0] canon_bass_gain;
        input [10:0] step;
        reg [3:0] pos16;
        begin
            pos16 = step[2:0];
            canon_bass_gain = envelope_gain(step_pos_ms(pos16), 11'd1504, 1'b0);
        end
    endfunction

    function [6:0] canon_voice_gain;
        input [10:0] global_step;
        input [10:0] delay_steps;
        reg [10:0] s;
        reg [5:0] bar;
        reg [3:0] beat16;
        begin
            if (global_step < delay_steps || canon_voice_note(global_step, delay_steps) == N_REST) begin
                canon_voice_gain = 7'd0;
            end else begin
                s = global_step - delay_steps;
                bar = s[9:4];
                beat16 = s[3:0];
                case (bar)
                    6'd0, 6'd1, 6'd2, 6'd3,
                    6'd4, 6'd5, 6'd6, 6'd7,
                    6'd44, 6'd45, 6'd46, 6'd47,
                    6'd48, 6'd49, 6'd50, 6'd51:
                        canon_voice_gain = envelope_gain(step_pos_ms({2'b00, beat16[1:0]}), 11'd752, 1'b0);

                    6'd8, 6'd9, 6'd10, 6'd11,
                    6'd12, 6'd13, 6'd14, 6'd15,
                    6'd32, 6'd33, 6'd34, 6'd35,
                    6'd36, 6'd37, 6'd38, 6'd39,
                    6'd40, 6'd41, 6'd42, 6'd43:
                        canon_voice_gain = envelope_gain(step_pos_ms({3'b000, beat16[0]}), 11'd376, 1'b0);

                    6'd16, 6'd17, 6'd18, 6'd19,
                    6'd20, 6'd21, 6'd22, 6'd23,
                    6'd24, 6'd25, 6'd26, 6'd27,
                    6'd28, 6'd29, 6'd30, 6'd31:
                        canon_voice_gain = envelope_gain({3'd0, canon_tick_ms}, 11'd188, 1'b0);

                    default:
                        canon_voice_gain = envelope_gain(step_pos_ms({1'b0, beat16[2:0]}), 11'd1504, 1'b0);
                endcase
            end
        end
    endfunction

    function [4:0] canon_voice_note;
        input [10:0] global_step;
        input [10:0] delay_steps;
        reg [10:0] s;
        reg [5:0] bar;
        reg [3:0] beat16;
        begin
            if (global_step < delay_steps) begin
                canon_voice_note = N_REST;
            end else begin
                s = global_step - delay_steps;
                bar = s[9:4];
                beat16 = s[3:0];
                case (bar)
                    6'd0, 6'd1, 6'd2, 6'd3: begin
                        case (beat16[3:2]) // quarter notes
                            2'd0: canon_voice_note = N_D5;
                            2'd1: canon_voice_note = N_A4;
                            2'd2: canon_voice_note = N_B4;
                            default: canon_voice_note = N_FS4;
                        endcase
                    end
                    6'd4, 6'd5, 6'd6, 6'd7: begin
                        case (beat16[3:2]) // quarter notes
                            2'd0: canon_voice_note = N_G4;
                            2'd1: canon_voice_note = N_D5;
                            2'd2: canon_voice_note = N_G4;
                            default: canon_voice_note = N_A4;
                        endcase
                    end
                    6'd8, 6'd9, 6'd10, 6'd11: begin
                        case (beat16[3:1]) // eighth notes
                            3'd0: canon_voice_note = N_FS4;
                            3'd1: canon_voice_note = N_G4;
                            3'd2: canon_voice_note = N_A4;
                            3'd3: canon_voice_note = N_FS4;
                            3'd4: canon_voice_note = N_G4;
                            3'd5: canon_voice_note = N_A4;
                            3'd6: canon_voice_note = N_B4;
                            default: canon_voice_note = N_CS5;
                        endcase
                    end
                    6'd12, 6'd13, 6'd14, 6'd15: begin
                        case (beat16[3:1]) // eighth notes
                            3'd0: canon_voice_note = N_D5;
                            3'd1: canon_voice_note = N_CS5;
                            3'd2: canon_voice_note = N_B4;
                            3'd3: canon_voice_note = N_A4;
                            3'd4: canon_voice_note = N_B4;
                            3'd5: canon_voice_note = N_CS5;
                            3'd6: canon_voice_note = N_D5;
                            default: canon_voice_note = N_E5;
                        endcase
                    end
                    6'd16, 6'd17, 6'd18, 6'd19: begin
                        case (beat16) // sixteenth notes
                            4'd0, 4'd6, 4'd9: canon_voice_note = N_D5;
                            4'd1, 4'd5, 4'd8, 4'd10: canon_voice_note = N_FS5;
                            4'd2, 4'd4, 4'd7, 4'd11: canon_voice_note = N_A5;
                            4'd3, 4'd12: canon_voice_note = N_D6;
                            4'd13: canon_voice_note = N_CS6;
                            4'd14: canon_voice_note = N_B5;
                            default: canon_voice_note = N_A5;
                        endcase
                    end
                    6'd20, 6'd21, 6'd22, 6'd23: begin
                        case (beat16) // sixteenth notes
                            4'd0, 4'd6, 4'd9: canon_voice_note = N_CS5;
                            4'd1, 4'd5, 4'd8, 4'd10: canon_voice_note = N_E5;
                            4'd2, 4'd4, 4'd7, 4'd11: canon_voice_note = N_A5;
                            4'd3, 4'd12: canon_voice_note = N_CS6;
                            4'd13: canon_voice_note = N_B5;
                            4'd14: canon_voice_note = N_A5;
                            default: canon_voice_note = N_G5;
                        endcase
                    end
                    6'd24, 6'd25, 6'd26, 6'd27: begin
                        case (beat16) // sixteenth notes
                            4'd0, 4'd6, 4'd9: canon_voice_note = N_B4;
                            4'd1, 4'd5, 4'd8, 4'd10: canon_voice_note = N_D5;
                            4'd2, 4'd4, 4'd7, 4'd11: canon_voice_note = N_FS5;
                            4'd3, 4'd12: canon_voice_note = N_B5;
                            4'd13: canon_voice_note = N_A5;
                            4'd14: canon_voice_note = N_G5;
                            default: canon_voice_note = N_FS5;
                        endcase
                    end
                    6'd28, 6'd29, 6'd30, 6'd31: begin
                        case (beat16) // sixteenth notes
                            4'd0, 4'd6, 4'd9: canon_voice_note = N_A4;
                            4'd1, 4'd5, 4'd8, 4'd10: canon_voice_note = N_CS5;
                            4'd2, 4'd4, 4'd7, 4'd11: canon_voice_note = N_FS5;
                            4'd3, 4'd12: canon_voice_note = N_A5;
                            4'd13: canon_voice_note = N_G5;
                            4'd14: canon_voice_note = N_FS5;
                            default: canon_voice_note = N_E5;
                        endcase
                    end
                    6'd32, 6'd33, 6'd34, 6'd35: begin
                        case (beat16[3:1]) // eighth notes
                            3'd0: canon_voice_note = N_G5;
                            3'd1: canon_voice_note = N_B5;
                            3'd2: canon_voice_note = N_D6;
                            3'd3: canon_voice_note = N_B5;
                            3'd4: canon_voice_note = N_G5;
                            3'd5: canon_voice_note = N_B5;
                            3'd6: canon_voice_note = N_D6;
                            default: canon_voice_note = N_B5;
                        endcase
                    end
                    6'd36, 6'd37, 6'd38, 6'd39: begin
                        case (beat16[3:1]) // eighth notes
                            3'd0: canon_voice_note = N_D5;
                            3'd1: canon_voice_note = N_FS5;
                            3'd2: canon_voice_note = N_A5;
                            3'd3: canon_voice_note = N_D6;
                            3'd4: canon_voice_note = N_A5;
                            3'd5: canon_voice_note = N_FS5;
                            3'd6: canon_voice_note = N_D5;
                            default: canon_voice_note = N_A4;
                        endcase
                    end
                    6'd40, 6'd41, 6'd42, 6'd43: begin
                        case (beat16[3:1]) // eighth notes
                            3'd0: canon_voice_note = N_G5;
                            3'd1: canon_voice_note = N_B5;
                            3'd2: canon_voice_note = N_D6;
                            3'd3: canon_voice_note = N_CS6;
                            3'd4: canon_voice_note = N_B5;
                            3'd5: canon_voice_note = N_A5;
                            3'd6: canon_voice_note = N_G5;
                            default: canon_voice_note = N_FS5;
                        endcase
                    end
                    6'd44, 6'd45, 6'd46, 6'd47: begin
                        case (beat16[3:2]) // quarter notes
                            2'd0: canon_voice_note = N_A5;
                            2'd1: canon_voice_note = N_CS6;
                            2'd2: canon_voice_note = N_D6;
                            default: canon_voice_note = N_E5;
                        endcase
                    end
                    6'd48, 6'd49, 6'd50, 6'd51: begin
                        case (beat16[3:2]) // quarter notes
                            2'd0: canon_voice_note = N_FS5;
                            2'd1: canon_voice_note = N_D5;
                            2'd2: canon_voice_note = N_E5;
                            default: canon_voice_note = N_CS5;
                        endcase
                    end
                    default: begin
                        case (beat16[3:3]) // half notes for cadence
                            1'b0: canon_voice_note = N_D5;
                            default: canon_voice_note = N_REST;
                        endcase
                    end
                endcase
            end
        end
    endfunction

    function [11:0] edm_step_pos_ms;
        input [1:0] beat_pos;
        begin
            edm_step_pos_ms = {10'd0, beat_pos} * 12'd667 + {2'd0, edm_tick_ms};
        end
    endfunction

    function [5:0] fade_bar;
        input [8:0] step;
        begin
            fade_bar = (step >> 2) & 6'd15;
        end
    endfunction

    function [4:0] edm_bass_note_func;
        input [8:0] step;
        reg [5:0] bar;
        begin
            bar = fade_bar(step);
            case (bar)
                6'd0, 6'd2, 6'd4, 6'd6,
                6'd8, 6'd10, 6'd12, 6'd14,
                6'd16, 6'd22, 6'd26, 6'd27:
                    edm_bass_note_func = N_A2; // 6 in A minor
                6'd1, 6'd5, 6'd9, 6'd13, 6'd17, 6'd23:
                    edm_bass_note_func = N_C3; // 1 in A minor fingering
                default:
                    edm_bass_note_func = N_E3; // 3 in A minor fingering
            endcase
        end
    endfunction

    function [4:0] edm_voice_note;
        input [8:0] step;
        reg [1:0] beat;
        reg [5:0] bar;
        begin
            beat = step[1:0];
            bar = fade_bar(step);
            edm_voice_note = N_REST;
            case (bar)
                6'd0, 6'd2, 6'd4, 6'd8, 6'd10, 6'd12: begin // 6 6 5 6
                    case (beat)
                        2'd0, 2'd1, 2'd3: edm_voice_note = N_A4;
                        default: edm_voice_note = N_G4;
                    endcase
                end
                6'd1, 6'd5, 6'd9, 6'd13: begin // 1 1 7 1
                    case (beat)
                        2'd0, 2'd1, 2'd3: edm_voice_note = N_C5;
                        default: edm_voice_note = N_B4;
                    endcase
                end
                6'd3, 6'd11: begin // 3 3 2 3
                    case (beat)
                        2'd0, 2'd1, 2'd3: edm_voice_note = N_E5;
                        default: edm_voice_note = N_D5;
                    endcase
                end
                6'd7, 6'd15: begin // 3 5 3 2
                    case (beat)
                        2'd0, 2'd2: edm_voice_note = N_E5;
                        2'd1: edm_voice_note = N_G5;
                        default: edm_voice_note = N_D5;
                    endcase
                end
                6'd6, 6'd14: begin // 6 6 5 6
                    case (beat)
                        2'd0, 2'd1, 2'd3: edm_voice_note = N_A4;
                        default: edm_voice_note = N_G4;
                    endcase
                end
                6'd16, 6'd22: begin // 6 5 3 2
                    case (beat)
                        2'd0: edm_voice_note = N_A4;
                        2'd1: edm_voice_note = N_G4;
                        2'd2: edm_voice_note = N_E5;
                        default: edm_voice_note = N_D5;
                    endcase
                end
                6'd17, 6'd23: begin // 1 7, 1 2
                    case (beat)
                        2'd0, 2'd2: edm_voice_note = N_C5;
                        2'd1: edm_voice_note = N_B3;
                        default: edm_voice_note = N_D5;
                    endcase
                end
                6'd18, 6'd24: begin // 3 - - -
                    edm_voice_note = N_E5;
                end
                6'd19, 6'd25: begin // 3 2 1 7,
                    case (beat)
                        2'd0: edm_voice_note = N_E5;
                        2'd1: edm_voice_note = N_D5;
                        2'd2: edm_voice_note = N_C5;
                        default: edm_voice_note = N_B3;
                    endcase
                end
                6'd20: begin // 6 5, 6 7
                    case (beat)
                        2'd0, 2'd2: edm_voice_note = N_A4;
                        2'd1: edm_voice_note = N_G3;
                        default: edm_voice_note = N_B4;
                    endcase
                end
                6'd21: begin // 1 - - -
                    edm_voice_note = N_C5;
                end
                6'd26: begin // 6 5, 6 -
                    case (beat)
                        2'd0, 2'd2, 2'd3: edm_voice_note = N_A4;
                        default: edm_voice_note = N_G3;
                    endcase
                end
                6'd27: begin // 6 - - -
                    edm_voice_note = N_A4;
                end
                default: edm_voice_note = N_REST;
            endcase
        end
    endfunction

    function [11:0] edm_voice_pos_ms;
        input [8:0] step;
        reg [1:0] beat;
        reg [5:0] bar;
        begin
            beat = step[1:0];
            bar = fade_bar(step);
            if (bar == 6'd18 || bar == 6'd21 || bar == 6'd24 || bar == 6'd27) begin
                edm_voice_pos_ms = edm_step_pos_ms(beat);
            end else if (bar == 6'd26 && beat >= 2'd2) begin
                edm_voice_pos_ms = edm_step_pos_ms(beat - 2'd2);
            end else begin
                edm_voice_pos_ms = {2'd0, edm_tick_ms};
            end
        end
    endfunction

    function [11:0] edm_voice_dur_ms;
        input [8:0] step;
        reg [1:0] beat;
        reg [5:0] bar;
        begin
            beat = step[1:0];
            bar = fade_bar(step);
            if (bar == 6'd18 || bar == 6'd21 || bar == 6'd24 || bar == 6'd27) begin
                edm_voice_dur_ms = 12'd2668;
            end else if (bar == 6'd26 && beat >= 2'd2) begin
                edm_voice_dur_ms = 12'd1334;
            end else begin
                edm_voice_dur_ms = 12'd520;
            end
        end
    endfunction

    function [6:0] edm_voice_gain;
        input [8:0] step;
        begin
            edm_voice_gain = envelope_gain(edm_voice_pos_ms(step), edm_voice_dur_ms(step), edm_voice_note(step) == N_REST);
        end
    endfunction

    function [6:0] edm_bass_gain_func;
        input [8:0] step;
        begin
            edm_bass_gain_func = envelope_gain({2'd0, edm_tick_ms}, 12'd360, 1'b0);
        end
    endfunction

    function signed [11:0] sine_delta;
        input [5:0] index;
        begin
            case (index)
                6'd0:  sine_delta = 10'sd0;
                6'd1:  sine_delta = 10'sd9;
                6'd2:  sine_delta = 10'sd19;
                6'd3:  sine_delta = 10'sd28;
                6'd4:  sine_delta = 10'sd36;
                6'd5:  sine_delta = 10'sd45;
                6'd6:  sine_delta = 10'sd53;
                6'd7:  sine_delta = 10'sd60;
                6'd8:  sine_delta = 10'sd67;
                6'd9:  sine_delta = 10'sd73;
                6'd10: sine_delta = 10'sd79;
                6'd11: sine_delta = 10'sd84;
                6'd12: sine_delta = 10'sd88;
                6'd13: sine_delta = 10'sd91;
                6'd14: sine_delta = 10'sd93;
                6'd15: sine_delta = 10'sd95;
                6'd16: sine_delta = 10'sd95;
                6'd17: sine_delta = 10'sd95;
                6'd18: sine_delta = 10'sd93;
                6'd19: sine_delta = 10'sd91;
                6'd20: sine_delta = 10'sd88;
                6'd21: sine_delta = 10'sd84;
                6'd22: sine_delta = 10'sd79;
                6'd23: sine_delta = 10'sd73;
                6'd24: sine_delta = 10'sd67;
                6'd25: sine_delta = 10'sd60;
                6'd26: sine_delta = 10'sd53;
                6'd27: sine_delta = 10'sd45;
                6'd28: sine_delta = 10'sd36;
                6'd29: sine_delta = 10'sd28;
                6'd30: sine_delta = 10'sd19;
                6'd31: sine_delta = 10'sd9;
                6'd32: sine_delta = 10'sd0;
                6'd33: sine_delta = -10'sd9;
                6'd34: sine_delta = -10'sd19;
                6'd35: sine_delta = -10'sd28;
                6'd36: sine_delta = -10'sd36;
                6'd37: sine_delta = -10'sd45;
                6'd38: sine_delta = -10'sd53;
                6'd39: sine_delta = -10'sd60;
                6'd40: sine_delta = -10'sd67;
                6'd41: sine_delta = -10'sd73;
                6'd42: sine_delta = -10'sd79;
                6'd43: sine_delta = -10'sd84;
                6'd44: sine_delta = -10'sd88;
                6'd45: sine_delta = -10'sd91;
                6'd46: sine_delta = -10'sd93;
                6'd47: sine_delta = -10'sd95;
                6'd48: sine_delta = -10'sd95;
                6'd49: sine_delta = -10'sd95;
                6'd50: sine_delta = -10'sd93;
                6'd51: sine_delta = -10'sd91;
                6'd52: sine_delta = -10'sd88;
                6'd53: sine_delta = -10'sd84;
                6'd54: sine_delta = -10'sd79;
                6'd55: sine_delta = -10'sd73;
                6'd56: sine_delta = -10'sd67;
                6'd57: sine_delta = -10'sd60;
                6'd58: sine_delta = -10'sd53;
                6'd59: sine_delta = -10'sd45;
                6'd60: sine_delta = -10'sd36;
                6'd61: sine_delta = -10'sd28;
                6'd62: sine_delta = -10'sd19;
                default: sine_delta = -10'sd9;
            endcase
        end
    endfunction

    function signed [13:0] scaled_delta;
        input signed [11:0] sample;
        input [6:0] gain;
        reg signed [18:0] product;
        begin
            product = sample * $signed({1'b0, gain});
            scaled_delta = product >>> 6;
        end
    endfunction

    function [9:0] clamp_audio;
        input signed [13:0] sample;
        begin
            if (sample > 14'sd844) begin
                clamp_audio = 10'd844;
            end else if (sample < 14'sd180) begin
                clamp_audio = 10'd180;
            end else begin
                clamp_audio = sample[9:0];
            end
        end
    endfunction

    function signed [13:0] apply_volume;
        input signed [13:0] sample;
        input [2:0] level;
        reg signed [13:0] delta;
        reg signed [17:0] scaled;
        begin
            delta = sample - 14'sd512;
            case (level)
                3'd0: scaled = 18'sd0;                     // mute
                3'd1: scaled = (delta * 18'sd3) >>> 9;      // 0.59%
                3'd2: scaled = (delta * 18'sd5) >>> 9;      // 0.98%
                3'd3: scaled = (delta * 18'sd6) >>> 9;      // 1.17%
                3'd4: scaled = delta >>> 6;                 // 1.56%
                3'd5: scaled = (delta * 18'sd10) >>> 9;     // 1.95%
                3'd6: scaled = (delta * 18'sd11) >>> 9;     // 2.15%
                default: scaled = (delta * 18'sd13) >>> 9;  // 2.54%
            endcase
            apply_volume = 14'sd512 + scaled[13:0];
        end
    endfunction

    always @(posedge clk100) begin
        if (reset_active) begin
            pix_div <= 2'b00;
            h_count <= 10'd0;
            v_count <= 10'd0;
            frame_count <= 24'd0;
            slow_count <= 27'd0;
            ms_div <= 17'd0;
            canon_tick_ms <= 8'd0;
            canon_step <= 11'd0;
            edm_tick_ms <= 10'd0;
            edm_step <= 9'd0;
            sample_div <= 12'd0;
            pdm_acc <= 11'd0;
            violin1_phase_acc <= 32'd0;
            violin2_phase_acc <= 32'd0;
            violin3_phase_acc <= 32'd0;
            bass_phase_acc <= 32'd0;
            edm_lead_phase_acc <= 32'd0;
            edm_bass_phase_acc <= 32'd0;
            audio_sample <= 10'd512;
            vs_audio_sample <= 10'd512;
            bounded_sample <= 10'd512;
            smooth_delta <= 12'sd0;
            violin1_note_d <= N_REST;
            violin2_note_d <= N_REST;
            violin3_note_d <= N_REST;
            bass_note_d <= N_REST;
            edm_lead_note_d <= N_REST;
            edm_bass_note_d <= N_REST;
            mixed_sample <= 14'sd0;
            volume_level <= 3'd1;
            volume_button_meta <= 2'd0;
            volume_button_sync <= 2'd0;
            volume_button_prev <= 2'd0;
            volume_cooldown <= 24'd0;
        end else begin
            slow_count <= slow_count + 27'd1;
            pdm_acc <= {1'b0, pdm_acc[9:0]} + {1'b0, audio_sample};
            volume_button_meta <= {buttons[1], buttons[4]}; // BTNU raises volume, BTND lowers it.
            volume_button_sync <= volume_button_meta;
            volume_button_prev <= volume_button_sync;

            if (volume_cooldown != 24'd0) begin
                volume_cooldown <= volume_cooldown - 24'd1;
            end else if (volume_button_edges[1] && volume_level != 3'd7) begin
                volume_level <= volume_level + 3'd1;
                volume_cooldown <= 24'd8000000;
            end else if (volume_button_edges[0] && volume_level != 3'd0) begin
                volume_level <= volume_level - 3'd1;
                volume_cooldown <= 24'd8000000;
            end

            if (!audio_enabled || game_finished) begin
                ms_div <= 17'd0;
                canon_tick_ms <= 8'd0;
                canon_step <= 11'd0;
                edm_tick_ms <= 10'd0;
                edm_step <= 9'd0;
            end else if (game_paused) begin
                ms_div <= ms_div;
            end else if (ms_div == 17'd99999) begin
                ms_div <= 17'd0;
                if (canon_tick_ms == 8'd187) begin
                    canon_tick_ms <= 8'd0;
                    if (canon_step < CANON_TOTAL_STEPS) begin
                        canon_step <= canon_step + 11'd1;
                    end else begin
                        canon_step <= 11'd0;
                    end
                end else begin
                    canon_tick_ms <= canon_tick_ms + 8'd1;
                end
                if (edm_tick_ms == 10'd666) begin
                    edm_tick_ms <= 10'd0;
                    if (edm_step < FADE_TOTAL_STEPS) begin
                        edm_step <= edm_step + 9'd1;
                    end else begin
                        edm_step <= 9'd0;
                    end
                end else begin
                    edm_tick_ms <= edm_tick_ms + 10'd1;
                end
            end else begin
                ms_div <= ms_div + 17'd1;
            end

            if (sample_tick) begin
                sample_div <= 12'd0;

                if (!audio_playing) begin
                    violin1_phase_acc <= 32'd0;
                    violin2_phase_acc <= 32'd0;
                    violin3_phase_acc <= 32'd0;
                    bass_phase_acc <= 32'd0;
                    edm_lead_phase_acc <= 32'd0;
                    edm_bass_phase_acc <= 32'd0;
                    mixed_sample = 14'sd512;
                end else if (edm_mode) begin
                    edm_lead_note_d <= edm_lead_note;
                    edm_bass_note_d <= edm_bass_note;

                    if (edm_lead_note != edm_lead_note_d) begin
                        edm_lead_phase_acc <= edm_lead_step;
                    end else begin
                        edm_lead_phase_acc <= edm_lead_phase_acc + edm_lead_step;
                    end

                    if (edm_bass_note != edm_bass_note_d) begin
                        edm_bass_phase_acc <= edm_bass_step;
                    end else begin
                        edm_bass_phase_acc <= edm_bass_phase_acc + edm_bass_step;
                    end

                    mixed_sample = 14'sd512 +
                                   scaled_delta(sine_delta(edm_lead_phase_acc[31:26]), edm_lead_gain) +
                                   (scaled_delta(sine_delta(edm_bass_phase_acc[31:26]), edm_bass_gain) >>> 1);
                end else if (canon_mode) begin
                    violin1_note_d <= violin1_note;
                    violin2_note_d <= violin2_note;
                    violin3_note_d <= violin3_note;
                    bass_note_d <= bass_note;

                    if (violin1_note == N_REST) begin
                        violin1_phase_acc <= 32'd0;
                    end else if (violin1_note != violin1_note_d) begin
                        violin1_phase_acc <= violin1_step;
                    end else begin
                        violin1_phase_acc <= violin1_phase_acc + violin1_step;
                    end

                    if (violin2_note == N_REST) begin
                        violin2_phase_acc <= 32'd0;
                    end else if (violin2_note != violin2_note_d) begin
                        violin2_phase_acc <= violin2_step;
                    end else begin
                        violin2_phase_acc <= violin2_phase_acc + violin2_step;
                    end

                    if (violin3_note == N_REST) begin
                        violin3_phase_acc <= 32'd0;
                    end else if (violin3_note != violin3_note_d) begin
                        violin3_phase_acc <= violin3_step;
                    end else begin
                        violin3_phase_acc <= violin3_phase_acc + violin3_step;
                    end

                    if (bass_note != bass_note_d) begin
                        bass_phase_acc <= bass_step;
                    end else begin
                        bass_phase_acc <= bass_phase_acc + bass_step;
                    end

                    mixed_sample = 14'sd512 +
                                   scaled_delta(sine_delta(violin1_phase_acc[31:26]), violin1_gain) +
                                   scaled_delta(sine_delta(violin2_phase_acc[31:26]), violin2_gain) +
                                   scaled_delta(sine_delta(violin3_phase_acc[31:26]), violin3_gain) +
                                   (scaled_delta(sine_delta(bass_phase_acc[31:26]), bass_gain) >>> 1);
                end else begin
                    mixed_sample = 14'sd512;
                end
                vs_audio_sample <= clamp_audio(mixed_sample);
                bounded_sample = clamp_audio(apply_volume(mixed_sample, volume_level));
                smooth_delta = $signed({1'b0, bounded_sample}) - $signed({1'b0, audio_sample});
                audio_sample <= $signed({1'b0, audio_sample}) + (smooth_delta >>> 2);
            end else begin
                sample_div <= sample_div + 12'd1;
            end

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
        if (mb_mode) begin
            if (mb_an_status[7:5] == 3'b000) begin
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
        diag_led[2:0] = ui_buttons;
        diag_led[4:3] = mb_game_state;
        diag_led[5] = |(ui_note_tracks[31:29] | ui_note_tracks[63:61] | ui_note_tracks[95:93]);
        diag_led[7:6] = 2'b00;
        diag_led[9:8] = ui_song_select;
        diag_led[11:10] = mb_rating_code;
        diag_led[15:12] = mb_volume_level;
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
                        ui_text2_pixel(6'd41, h_count, v_count, 10'd92, 10'd24) ||  // SW0-1
                        ui_text2_pixel(5'd1, h_count, v_count, 10'd32, 10'd58) ||   // CANON
                        ui_text2_pixel(5'd2, h_count, v_count, 10'd32, 10'd102) ||  // FADE
                        ui_text2_pixel(6'd46, h_count, v_count, 10'd32, 10'd140) || // APHASIA
                        ui_text2_pixel(5'd3, h_count, v_count, 10'd24, 10'd170) ||  // KEYS
                        ui_text2_pixel(5'd4, h_count, v_count, 10'd32, 10'd204) ||  // L C R
                        ui_text2_pixel(5'd11, h_count, v_count, 10'd24, 10'd288) || // VS1003
                        ui_text2_pixel(6'd47, h_count, v_count, 10'd104, 10'd288) || // MB
                        ui_text2_pixel(6'd48, h_count, v_count, 10'd24, 10'd322) || // MIDI
                        ui_text2_pixel(5'd14, h_count, v_count, 10'd96, 10'd322) || // ON
                        ui_text2_pixel(5'd5, h_count, v_count, 10'd480, 10'd24) ||  // SPEED
                        ui_text2_pixel(6'd42, h_count, v_count, 10'd548, 10'd24) || // SW5-3
                        ui_text2_pixel(game_speed_text_id, h_count, v_count, 10'd496, 10'd58) ||
                        ui_text2_pixel(5'd15, h_count, v_count, 10'd480, 10'd94) || // BPM
                        ui_text2_pixel(5'd16, h_count, v_count, 10'd496, 10'd128) || // 90
                        ui_text2_pixel(5'd31, h_count, v_count, 10'd548, 10'd94) || // VOL
                        ui_text2_pixel(ui_volume_text_id, h_count, v_count, 10'd588, 10'd128) ||
                        ui_text2_pixel(5'd25, h_count, v_count, 10'd480, 10'd174) || // SCORE
                        ui_bcd5_pixel(ui_score_bcd, h_count, v_count, 10'd496, 10'd206) ||
                        ui_text2_pixel(5'd7, h_count, v_count, 10'd480, 10'd252) || // JUDGE
                        ui_text2_pixel(ui_judgement_text_id, h_count, v_count, 10'd496, 10'd286) ||
                        ui_text2_pixel(6'd44, h_count, v_count, 10'd480, 10'd330) || // PAUSE
                        ui_text2_pixel(6'd45, h_count, v_count, 10'd548, 10'd330) || // SW15
                        ui_text2_pixel(5'd3, h_count, v_count, 10'd480, 10'd360) || // KEYS
                        ui_text2_pixel(5'd26, h_count, v_count, 10'd496, 10'd388) || // P17 L
                        ui_text2_pixel(5'd27, h_count, v_count, 10'd496, 10'd416) || // N17 C
                        ui_text2_pixel(5'd28, h_count, v_count, 10'd496, 10'd436) || // M17 R
                        ui_text2_pixel(6'd40, h_count, v_count, 10'd496, 10'd456);   // UD VOL
        ui_box_pixel = ((h_count >= 10'd20 && h_count < 10'd156 && v_count >= 10'd48 && v_count < 10'd88) &&
                        (h_count < 10'd23 || h_count >= 10'd153 || v_count < 10'd51 || v_count >= 10'd85)) ||
                       ((h_count >= 10'd20 && h_count < 10'd156 && v_count >= 10'd92 && v_count < 10'd132) &&
                        (h_count < 10'd23 || h_count >= 10'd153 || v_count < 10'd95 || v_count >= 10'd129)) ||
                       ((h_count >= 10'd20 && h_count < 10'd156 && v_count >= 10'd136 && v_count < 10'd166) &&
                        (h_count < 10'd23 || h_count >= 10'd153 || v_count < 10'd139 || v_count >= 10'd163)) ||
                       ((h_count >= 10'd20 && h_count < 10'd156 && v_count >= 10'd194 && v_count < 10'd232) &&
                        (h_count < 10'd23 || h_count >= 10'd153 || v_count < 10'd197 || v_count >= 10'd229)) ||
                       ((h_count >= 10'd20 && h_count < 10'd156 && v_count >= 10'd312 && v_count < 10'd354) &&
                        (h_count < 10'd23 || h_count >= 10'd153 || v_count < 10'd315 || v_count >= 10'd351)) ||
                       ((h_count >= 10'd484 && h_count < 10'd620 && v_count >= 10'd48 && v_count < 10'd82) &&
                        (h_count < 10'd487 || h_count >= 10'd617 || v_count < 10'd51 || v_count >= 10'd79)) ||
                       ((h_count >= 10'd484 && h_count < 10'd620 && v_count >= 10'd118 && v_count < 10'd152) &&
                        (h_count < 10'd487 || h_count >= 10'd617 || v_count < 10'd121 || v_count >= 10'd149)) ||
                       ((h_count >= 10'd484 && h_count < 10'd620 && v_count >= 10'd198 && v_count < 10'd232) &&
                        (h_count < 10'd487 || h_count >= 10'd617 || v_count < 10'd201 || v_count >= 10'd229)) ||
                       ((h_count >= 10'd484 && h_count < 10'd620 && v_count >= 10'd278 && v_count < 10'd320) &&
                        (h_count < 10'd487 || h_count >= 10'd617 || v_count < 10'd281 || v_count >= 10'd317)) ||
                       ((h_count >= 10'd484 && h_count < 10'd620 && v_count >= 10'd382 && v_count < 10'd470) &&
                        (h_count < 10'd487 || h_count >= 10'd617 || v_count < 10'd385 || v_count >= 10'd467));
        ui_line_pixel = (h_count == 10'd176 || h_count == 10'd463);
        ui_selected_pixel = (((mb_mode && ui_song_select == 2'd0) || (!mb_mode && canon_mode)) &&
                             h_count >= 10'd24 && h_count < 10'd152 && v_count >= 10'd52 && v_count < 10'd84) ||
                            (((mb_mode && ui_song_select == 2'd1) || (!mb_mode && edm_mode)) &&
                             h_count >= 10'd24 && h_count < 10'd152 && v_count >= 10'd96 && v_count < 10'd128) ||
                            (mb_mode && ui_song_select == 2'd2 &&
                             h_count >= 10'd24 && h_count < 10'd152 && v_count >= 10'd140 && v_count < 10'd162) ||
                            (vs1003_demo_enabled && h_count >= 10'd24 && h_count < 10'd152 && v_count >= 10'd316 && v_count < 10'd350);

        if (!active_video) begin
            vga_r = 4'h0;
            vga_g = 4'h0;
            vga_b = 4'h0;
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
        end else if (border) begin
            vga_r = 4'hf;
            vga_g = 4'hf;
            vga_b = 4'hf;
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
                                ((h_count - 10'd200) % 10'd80 >= 10'd26) &&
                                ((h_count - 10'd200) % 10'd80 < 10'd54) &&
                                (v_count >= 10'd346) && (v_count < 10'd374);

            if ((h_count - 10'd200) % 10'd80 < 10'd3) begin
                vga_r = 4'h7; vga_g = 4'h7; vga_b = 4'h7;
            end else if (game_note_pixel) begin
                vga_r = 4'hf; vga_g = 4'hf; vga_b = 4'hf;
            end else if (game_hold_pixel) begin
                vga_r = 4'he; vga_g = 4'he; vga_b = 4'he;
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
                                ((h_count - 10'd200) % 10'd80 >= 10'd26) &&
                                ((h_count - 10'd200) % 10'd80 < 10'd54) &&
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
            end else if (game_hold_pixel) begin
                vga_r = 4'he;
                vga_g = 4'he;
                vga_b = 4'he;
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
        end else if (v_count >= 10'd424 && v_count < 10'd448 &&
                     h_count >= 10'd200 && h_count < 10'd440) begin
            game_lane = (h_count - 10'd200) / 10'd80;
            if (ui_buttons[game_lane]) begin
                case (ui_judgement)
                    4'd2: begin vga_r = 4'h2; vga_g = 4'hf; vga_b = 4'h2; end
                    4'd1: begin vga_r = 4'h2; vga_g = 4'h6; vga_b = 4'hf; end
                    4'd0: begin vga_r = 4'hf; vga_g = 4'h1; vga_b = 4'h1; end
                    default: begin vga_r = 4'hf; vga_g = 4'hf; vga_b = 4'hf; end
                endcase
            end else begin
                vga_r = 4'h1;
                vga_g = 4'h1;
                vga_b = 4'h1;
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
    localparam ART_X0 = 10'd200;
    localparam ART_Y0 = 10'd32;
    localparam ART_WIDTH = 17'd120;
    localparam ART_PIXELS = 17'd23040;

    (* rom_style = "block" *) reg [7:0] canon_index [0:ART_PIXELS-1];
    (* rom_style = "block" *) reg [7:0] fade_index [0:ART_PIXELS-1];
    (* rom_style = "block" *) reg [7:0] aphasia_index [0:ART_PIXELS-1];
    reg [11:0] canon_palette [0:63];
    reg [11:0] fade_palette [0:63];
    reg [11:0] aphasia_palette [0:63];
    wire [8:0] art_row = (pixel_y - ART_Y0) >> 1;
    wire [6:0] art_col = (pixel_x - ART_X0) >> 1;
    wire [16:0] art_row_times_120 =
        {1'b0, art_row, 7'b0} - {5'b0, art_row, 3'b0};
    reg [16:0] art_addr = 17'd0;
    reg [5:0] art_index = 6'd0;

    initial begin
        $readmemh("F:/FPGA/mircoCom/Genneral/Mini_IO/generated/album_art/canon_track_bg_index.mem", canon_index);
        $readmemh("F:/FPGA/mircoCom/Genneral/Mini_IO/generated/album_art/canon_track_bg_palette.mem", canon_palette);
        $readmemh("F:/FPGA/mircoCom/Genneral/Mini_IO/generated/album_art/fade_track_bg_index.mem", fade_index);
        $readmemh("F:/FPGA/mircoCom/Genneral/Mini_IO/generated/album_art/fade_track_bg_palette.mem", fade_palette);
        $readmemh("F:/FPGA/mircoCom/Genneral/Mini_IO/generated/album_art/aphasia_track_bg_index.mem", aphasia_index);
        $readmemh("F:/FPGA/mircoCom/Genneral/Mini_IO/generated/album_art/aphasia_track_bg_palette.mem", aphasia_palette);
    end

    always @(*) begin
        art_addr = art_row_times_120 + {10'd0, art_col};
    end

    always @(posedge clk) begin
        if (!valid) begin
            art_index <= 6'd0;
            rgb <= 12'h000;
        end else if (song_select == 2'd2) begin
            art_index <= aphasia_index[art_addr][5:0];
            rgb <= aphasia_palette[art_index];
        end else if (song_select == 2'd1) begin
            art_index <= fade_index[art_addr][5:0];
            rgb <= fade_palette[art_index];
        end else begin
            art_index <= canon_index[art_addr][5:0];
            rgb <= canon_palette[art_index];
        end
    end
endmodule

module vs1003b_mp3_rom_player (
    input wire clk,
    input wire reset,
    input wire enable,
    input wire [1:0] song_select,
    input wire dreq,
    input wire miso,
    output reg mosi,
    output reg sclk,
    output reg xcs,
    output reg xdcs,
    output reg xrst,
    output wire [7:0] debug
);
    localparam ST_OFF             = 5'd0;
    localparam ST_RESET_LOW       = 5'd1;
    localparam ST_RESET_HIGH      = 5'd2;
    localparam ST_WAIT_DREQ       = 5'd3;
    localparam ST_SCI_MODE        = 5'd4;
    localparam ST_SOFT_RESET_WAIT = 5'd5;
    localparam ST_SCI_CLOCK       = 5'd6;
    localparam ST_SCI_AUDATA      = 5'd7;
    localparam ST_SCI_BASS        = 5'd8;
    localparam ST_SCI_VOL         = 5'd9;
    localparam ST_POST_INIT_WAIT  = 5'd10;
    localparam ST_START_ZERO      = 5'd11;
    localparam ST_PLAY            = 5'd12;
    localparam ST_FLUSH           = 5'd13;
    localparam ST_DONE            = 5'd14;
    localparam ST_SEND            = 5'd15;
    localparam ST_PLAY_SEND       = 5'd16;
    localparam ST_PLAY_BURST      = 5'd17;

    localparam CMD_NONE       = 4'd0;
    localparam CMD_SCI_MODE   = 4'd1;
    localparam CMD_SCI_CLOCK  = 4'd2;
    localparam CMD_SCI_VOL    = 4'd3;
    localparam CMD_MP3_BYTE   = 4'd4;
    localparam CMD_FLUSH      = 4'd5;
    localparam CMD_SCI_AUDATA = 4'd6;
    localparam CMD_SCI_BASS   = 4'd7;
    localparam CMD_DUMMY_FF   = 4'd8;

    localparam integer MP3_LEN = 1024;
    localparam [17:0] CANON_LAST = 18'd960;
    localparam [17:0] FADE_LAST = 18'd451;
    localparam [17:0] PITCH_LAST = 18'd161;
    localparam [12:0] FLUSH_BYTES = 13'd0;
    localparam [5:0] BURST_BYTES = 6'd32;
    localparam [32:0] CANON_LOOP_WAIT = 33'd2000000000;
    localparam [32:0] FADE_LOOP_WAIT = 33'd3000000000;
    localparam [32:0] PITCH_LOOP_WAIT = 33'd2500000000;

    reg [4:0] state = ST_OFF;
    reg [4:0] return_state = ST_OFF;
    reg [3:0] command = CMD_NONE;
    reg [2:0] byte_index = 3'd0;
    reg [2:0] bit_index = 3'd0;
    reg [7:0] shifter = 8'hff;
    reg [6:0] spi_div = 7'd0;
    reg [32:0] wait_count = 33'd0;
    reg [17:0] mp3_addr = 18'd0;
    reg [7:0] mp3_byte = 8'h00;
    reg [12:0] flush_count = 13'd0;
    reg [5:0] burst_count = 6'd0;
    reg dreq_meta = 1'b0;
    reg dreq_sync = 1'b0;
    reg spi_busy = 1'b0;
    reg [1:0] active_song = 2'd0;

    (* ram_style = "block" *) reg [7:0] canon_rom [0:MP3_LEN-1];
    (* ram_style = "block" *) reg [7:0] fade_rom [0:MP3_LEN-1];
    (* ram_style = "block" *) reg [7:0] pitch_rom [0:MP3_LEN-1];

    initial begin
        $readmemh("F:/FPGA/mircoCom/Genneral/Mini_IO/music/midi/canon_main_melody_1024.mem", canon_rom);
        $readmemh("F:/FPGA/mircoCom/Genneral/Mini_IO/music/midi/faded_main_melody_1024.mem", fade_rom);
        $readmemh("F:/FPGA/mircoCom/Genneral/Mini_IO/music/midi/vs1003_pitch_calibration_1024.mem", pitch_rom);
    end

    wire _unused_miso = miso;
    wire dreq_ready = dreq_sync;
    wire pitch_mode = (active_song == 2'd2);
    wire [17:0] selected_last = pitch_mode ? PITCH_LAST : (active_song[0] ? FADE_LAST : CANON_LAST);
    wire [32:0] selected_loop_wait = pitch_mode ? PITCH_LOOP_WAIT : (active_song[0] ? FADE_LOOP_WAIT : CANON_LOOP_WAIT);
    assign debug = {dreq_ready, enable, state[3:0], ~xdcs, ~xcs};

    function [7:0] selected_rom_byte;
        input [17:0] addr;
        begin
            if (pitch_mode) begin
                selected_rom_byte = pitch_rom[addr];
            end else begin
                selected_rom_byte = active_song[0] ? fade_rom[addr] : canon_rom[addr];
            end
        end
    endfunction

    function [7:0] command_byte;
        input [3:0] cmd;
        input [2:0] idx;
        begin
            case (cmd)
                CMD_SCI_MODE: begin
                    case (idx)
                        3'd0: command_byte = 8'h02;
                        3'd1: command_byte = 8'h00; // SCI_MODE
                        3'd2: command_byte = 8'h08;
                        3'd3: command_byte = 8'h04; // SM_SDINEW + SM_RESET, as in the reference MP3 demo
                        default: command_byte = 8'h00;
                    endcase
                end
                CMD_SCI_CLOCK: begin
                    case (idx)
                        3'd0: command_byte = 8'h02;
                        3'd1: command_byte = 8'h03; // SCI_CLOCKF
                        3'd2: command_byte = 8'h98;
                        3'd3: command_byte = 8'h00;
                        default: command_byte = 8'h00;
                    endcase
                end
                CMD_SCI_AUDATA: begin
                    case (idx)
                        3'd0: command_byte = 8'h02;
                        3'd1: command_byte = 8'h05; // SCI_AUDATA
                        3'd2: command_byte = 8'hbb; // 48 kHz stereo, from vendor demo
                        3'd3: command_byte = 8'h81;
                        default: command_byte = 8'h00;
                    endcase
                end
                CMD_SCI_BASS: begin
                    case (idx)
                        3'd0: command_byte = 8'h02;
                        3'd1: command_byte = 8'h02; // SCI_BASS
                        3'd2: command_byte = 8'h00;
                        3'd3: command_byte = 8'h55; // from vendor demo
                        default: command_byte = 8'h00;
                    endcase
                end
                CMD_SCI_VOL: begin
                    case (idx)
                        3'd0: command_byte = 8'h02;
                        3'd1: command_byte = 8'h0b; // SCI_VOL
                        3'd2: command_byte = 8'h00;
                        3'd3: command_byte = 8'h00;
                        default: command_byte = 8'h00;
                    endcase
                end
                CMD_MP3_BYTE: command_byte = mp3_byte;
                CMD_FLUSH: command_byte = 8'h00;
                CMD_DUMMY_FF: command_byte = 8'hff;
                default: command_byte = 8'hff;
            endcase
        end
    endfunction

    function [3:0] command_len;
        input [3:0] cmd;
        begin
            case (cmd)
                CMD_SCI_MODE, CMD_SCI_CLOCK, CMD_SCI_AUDATA, CMD_SCI_BASS, CMD_SCI_VOL: command_len = 4'd4;
                CMD_MP3_BYTE, CMD_FLUSH, CMD_DUMMY_FF: command_len = 4'd1;
                default: command_len = 4'd0;
            endcase
        end
    endfunction

    function command_msb;
        input [3:0] cmd;
        input [2:0] idx;
        reg [7:0] value;
        begin
            value = command_byte(cmd, idx);
            command_msb = value[7];
        end
    endfunction

    task start_command;
        input [3:0] cmd;
        input [4:0] ret;
        begin
            command <= cmd;
            return_state <= ret;
            byte_index <= 3'd0;
            bit_index <= 3'd7;
            shifter <= command_byte(cmd, 3'd0);
            spi_busy <= 1'b1;
            spi_div <= 7'd0;
            wait_count <= 33'd0;
            sclk <= 1'b0;
            mosi <= command_msb(cmd, 3'd0);
            if (cmd == CMD_SCI_MODE || cmd == CMD_SCI_CLOCK || cmd == CMD_SCI_AUDATA || cmd == CMD_SCI_BASS || cmd == CMD_SCI_VOL) begin
                xcs <= 1'b0;
                xdcs <= 1'b1;
            end else if (cmd == CMD_DUMMY_FF) begin
                xcs <= 1'b1;
                xdcs <= 1'b1;
            end else begin
                xcs <= 1'b1;
                xdcs <= 1'b0;
            end
            state <= ST_SEND;
        end
    endtask

    always @(posedge clk) begin
        dreq_meta <= dreq;
        dreq_sync <= dreq_meta;

        if (reset || !enable || active_song != song_select) begin
            state <= ST_OFF;
            active_song <= song_select;
            xrst <= 1'b0;
            xcs <= 1'b1;
            xdcs <= 1'b1;
            sclk <= 1'b0;
            mosi <= 1'b1;
            wait_count <= 33'd0;
            mp3_addr <= 18'd0;
            mp3_byte <= 8'h00;
            flush_count <= 13'd0;
            burst_count <= 6'd0;
            spi_busy <= 1'b0;
        end else begin
            case (state)
                ST_OFF: begin
                    xrst <= 1'b0;
                    xcs <= 1'b1;
                    xdcs <= 1'b1;
                    sclk <= 1'b0;
                    mosi <= 1'b1;
                    wait_count <= 33'd0;
                    active_song <= song_select;
                    mp3_addr <= 18'd0;
                    mp3_byte <= 8'h00;
                    flush_count <= 13'd0;
                    burst_count <= 6'd0;
                    state <= ST_RESET_LOW;
                end
                ST_RESET_LOW: begin
                    if (wait_count == 33'd9999999) begin
                        wait_count <= 33'd0;
                        xrst <= 1'b1;
                        state <= ST_RESET_HIGH;
                    end else begin
                        wait_count <= wait_count + 33'd1;
                    end
                end
                ST_RESET_HIGH: begin
                    if (wait_count == 33'd19999999) begin
                        wait_count <= 33'd0;
                        start_command(CMD_DUMMY_FF, ST_WAIT_DREQ);
                    end else begin
                        wait_count <= wait_count + 33'd1;
                    end
                end
                ST_WAIT_DREQ: begin
                    if (dreq_ready) start_command(CMD_SCI_MODE, ST_SOFT_RESET_WAIT);
                end
                ST_SOFT_RESET_WAIT: begin
                    if (wait_count == 33'd199999) begin
                        wait_count <= 33'd0;
                        state <= ST_SCI_CLOCK;
                    end else begin
                        wait_count <= wait_count + 33'd1;
                    end
                end
                ST_SCI_CLOCK: begin
                    if (dreq_ready) start_command(CMD_SCI_CLOCK, ST_SCI_AUDATA);
                end
                ST_SCI_AUDATA: begin
                    if (dreq_ready) start_command(CMD_SCI_AUDATA, ST_SCI_BASS);
                end
                ST_SCI_BASS: begin
                    if (dreq_ready) start_command(CMD_SCI_BASS, ST_SCI_VOL);
                end
                ST_SCI_VOL: begin
                    if (dreq_ready) begin
                        flush_count <= 13'd0;
                        start_command(CMD_SCI_VOL, ST_POST_INIT_WAIT);
                    end
                end
                ST_POST_INIT_WAIT: begin
                    if (wait_count == 33'd99999) begin
                        wait_count <= 33'd0;
                        state <= ST_START_ZERO;
                    end else begin
                        wait_count <= wait_count + 33'd1;
                    end
                end
                ST_START_ZERO: begin
                    if (flush_count == 13'd4) begin
                        flush_count <= 13'd0;
                        state <= ST_PLAY;
                    end else if (dreq_ready) begin
                        start_command(CMD_FLUSH, ST_START_ZERO);
                    end
                end
                ST_PLAY: begin
                    if (mp3_addr > selected_last) begin
                        state <= ST_FLUSH;
                    end else if (dreq_ready) begin
                        burst_count <= 6'd0;
                        mp3_byte <= selected_rom_byte(mp3_addr);
                        state <= ST_PLAY_SEND;
                    end
                end
                ST_PLAY_SEND: begin
                    start_command(CMD_MP3_BYTE, ST_PLAY_BURST);
                end
                ST_PLAY_BURST: begin
                    if (mp3_addr > selected_last) begin
                        xdcs <= 1'b1;
                        state <= ST_FLUSH;
                    end else if (!dreq_ready || burst_count == BURST_BYTES - 6'd1) begin
                        xdcs <= 1'b1;
                        state <= ST_PLAY;
                    end else begin
                        burst_count <= burst_count + 6'd1;
                        mp3_byte <= selected_rom_byte(mp3_addr);
                        state <= ST_PLAY_SEND;
                    end
                end
                ST_FLUSH: begin
                    if (flush_count == FLUSH_BYTES) begin
                        state <= ST_DONE;
                    end else if (dreq_ready) begin
                        start_command(CMD_FLUSH, ST_FLUSH);
                    end
                end
                ST_DONE: begin
                    xcs <= 1'b1;
                    xdcs <= 1'b1;
                    sclk <= 1'b0;
                    mosi <= 1'b1;
                    if (wait_count == selected_loop_wait) begin
                        wait_count <= 33'd0;
                        mp3_addr <= 18'd0;
                        flush_count <= 13'd0;
                        state <= ST_PLAY;
                    end else begin
                        wait_count <= wait_count + 33'd1;
                    end
                end
                ST_SEND: begin
                    if (spi_busy) begin
                        if (spi_div == 7'd99) begin
                            spi_div <= 7'd0;
                            if (!sclk) begin
                                sclk <= 1'b1;
                            end else begin
                                sclk <= 1'b0;
                                if (bit_index == 3'd0) begin
                                    if (byte_index == command_len(command) - 4'd1) begin
                                        spi_busy <= 1'b0;
                                        xcs <= 1'b1;
                                        xdcs <= 1'b1;
                                        sclk <= 1'b0;
                                        if (command == CMD_MP3_BYTE) begin
                                            mp3_addr <= mp3_addr + 18'd1;
                                            if (return_state == ST_PLAY_BURST) begin
                                                xdcs <= 1'b0;
                                            end
                                        end else if (command == CMD_FLUSH) begin
                                            flush_count <= flush_count + 13'd1;
                                        end
                                        state <= return_state;
                                    end else begin
                                        byte_index <= byte_index + 3'd1;
                                        bit_index <= 3'd7;
                                        shifter <= command_byte(command, byte_index + 3'd1);
                                        mosi <= command_msb(command, byte_index + 3'd1);
                                    end
                                end else begin
                                    bit_index <= bit_index - 3'd1;
                                    mosi <= shifter[bit_index - 3'd1];
                                end
                            end
                        end else begin
                            spi_div <= spi_div + 7'd1;
                        end
                    end
                end
                default: state <= ST_OFF;
            endcase
        end
    end
endmodule

module vs1003b_pcm_player (
    input wire clk,
    input wire reset,
    input wire enable,
    input wire [9:0] pcm_sample,
    input wire dreq,
    input wire miso,
    output reg mosi,
    output reg sclk,
    output reg xcs,
    output reg xdcs,
    output reg xrst,
    output wire [7:0] debug
);
    localparam ST_OFF        = 4'd0;
    localparam ST_RESET_LOW  = 4'd1;
    localparam ST_RESET_HIGH = 4'd2;
    localparam ST_WAIT_DREQ  = 4'd3;
    localparam ST_SCI_MODE   = 4'd4;
    localparam ST_SCI_CLOCK  = 4'd5;
    localparam ST_SCI_VOL    = 4'd6;
    localparam ST_HEADER     = 4'd7;
    localparam ST_WAIT_PCM   = 4'd8;
    localparam ST_SEND       = 4'd9;

    localparam CMD_NONE      = 3'd0;
    localparam CMD_SCI_MODE  = 3'd1;
    localparam CMD_SCI_CLOCK = 3'd2;
    localparam CMD_SCI_VOL   = 3'd3;
    localparam CMD_HEADER    = 3'd4;
    localparam CMD_PCM       = 3'd5;

    reg [3:0] state = ST_OFF;
    reg [3:0] return_state = ST_OFF;
    reg [2:0] command = CMD_NONE;
    reg [5:0] byte_index = 6'd0;
    reg [2:0] bit_index = 3'd0;
    reg [7:0] shifter = 8'hff;
    reg [5:0] spi_div = 6'd0;
    reg [24:0] wait_count = 25'd0;
    reg [5:0] header_index = 6'd0;
    reg [13:0] pcm_div = 14'd0;
    reg [7:0] pcm_latched = 8'd128;
    reg sample_ready = 1'b0;
    reg spi_busy = 1'b0;

    wire _unused_miso = miso;
    assign debug = {state != ST_OFF, spi_busy, sclk, ~xdcs, ~xcs, xrst, dreq, enable};

    function [7:0] wav_header_byte;
        input [5:0] idx;
        begin
            case (idx)
                6'd0:  wav_header_byte = "R";
                6'd1:  wav_header_byte = "I";
                6'd2:  wav_header_byte = "F";
                6'd3:  wav_header_byte = "F";
                6'd4:  wav_header_byte = 8'hff;
                6'd5:  wav_header_byte = 8'hff;
                6'd6:  wav_header_byte = 8'hff;
                6'd7:  wav_header_byte = 8'h7f;
                6'd8:  wav_header_byte = "W";
                6'd9:  wav_header_byte = "A";
                6'd10: wav_header_byte = "V";
                6'd11: wav_header_byte = "E";
                6'd12: wav_header_byte = "f";
                6'd13: wav_header_byte = "m";
                6'd14: wav_header_byte = "t";
                6'd15: wav_header_byte = " ";
                6'd16: wav_header_byte = 8'h10;
                6'd17: wav_header_byte = 8'h00;
                6'd18: wav_header_byte = 8'h00;
                6'd19: wav_header_byte = 8'h00;
                6'd20: wav_header_byte = 8'h01;
                6'd21: wav_header_byte = 8'h00;
                6'd22: wav_header_byte = 8'h01;
                6'd23: wav_header_byte = 8'h00;
                6'd24: wav_header_byte = 8'h40; // 8000 Hz
                6'd25: wav_header_byte = 8'h1f;
                6'd26: wav_header_byte = 8'h00;
                6'd27: wav_header_byte = 8'h00;
                6'd28: wav_header_byte = 8'h40; // byte rate: 8000
                6'd29: wav_header_byte = 8'h1f;
                6'd30: wav_header_byte = 8'h00;
                6'd31: wav_header_byte = 8'h00;
                6'd32: wav_header_byte = 8'h01; // block align
                6'd33: wav_header_byte = 8'h00;
                6'd34: wav_header_byte = 8'h08; // 8-bit unsigned PCM
                6'd35: wav_header_byte = 8'h00;
                6'd36: wav_header_byte = "d";
                6'd37: wav_header_byte = "a";
                6'd38: wav_header_byte = "t";
                6'd39: wav_header_byte = "a";
                6'd40: wav_header_byte = 8'hff;
                6'd41: wav_header_byte = 8'hff;
                6'd42: wav_header_byte = 8'hff;
                6'd43: wav_header_byte = 8'h7f;
                default: wav_header_byte = 8'h00;
            endcase
        end
    endfunction

    function [7:0] command_byte;
        input [2:0] cmd;
        input [5:0] idx;
        begin
            case (cmd)
                CMD_SCI_MODE: begin
                    case (idx)
                        6'd0: command_byte = 8'h02;
                        6'd1: command_byte = 8'h00; // SCI_MODE
                        6'd2: command_byte = 8'h08;
                        6'd3: command_byte = 8'h00; // SM_SDINEW, normal decode mode
                        default: command_byte = 8'h00;
                    endcase
                end
                CMD_SCI_CLOCK: begin
                    case (idx)
                        6'd0: command_byte = 8'h02;
                        6'd1: command_byte = 8'h03; // SCI_CLOCKF
                        6'd2: command_byte = 8'h60;
                        6'd3: command_byte = 8'h00;
                        default: command_byte = 8'h00;
                    endcase
                end
                CMD_SCI_VOL: begin
                    case (idx)
                        6'd0: command_byte = 8'h02;
                        6'd1: command_byte = 8'h0b; // SCI_VOL
                        6'd2: command_byte = 8'h00;
                        6'd3: command_byte = 8'h00;
                        default: command_byte = 8'h00;
                    endcase
                end
                CMD_HEADER: command_byte = wav_header_byte(header_index);
                CMD_PCM: command_byte = pcm_latched;
                default: command_byte = 8'hff;
            endcase
        end
    endfunction

    function [5:0] command_len;
        input [2:0] cmd;
        begin
            case (cmd)
                CMD_SCI_MODE, CMD_SCI_CLOCK, CMD_SCI_VOL: command_len = 6'd4;
                CMD_HEADER, CMD_PCM: command_len = 6'd1;
                default: command_len = 6'd0;
            endcase
        end
    endfunction

    task start_command;
        input [2:0] cmd;
        input [3:0] ret;
        begin
            command <= cmd;
            return_state <= ret;
            byte_index <= 6'd0;
            bit_index <= 3'd7;
            shifter <= command_byte(cmd, 6'd0);
            spi_busy <= 1'b1;
            spi_div <= 6'd0;
            sclk <= 1'b0;
            if (cmd == CMD_SCI_MODE || cmd == CMD_SCI_CLOCK || cmd == CMD_SCI_VOL) begin
                xcs <= 1'b0;
                xdcs <= 1'b1;
            end else begin
                xcs <= 1'b1;
                xdcs <= 1'b0;
            end
            state <= ST_SEND;
        end
    endtask

    always @(posedge clk) begin
        if (reset || !enable) begin
            state <= ST_OFF;
            xrst <= 1'b0;
            xcs <= 1'b1;
            xdcs <= 1'b1;
            sclk <= 1'b0;
            mosi <= 1'b1;
            wait_count <= 33'd0;
            header_index <= 6'd0;
            pcm_div <= 14'd0;
            pcm_latched <= 8'd128;
            sample_ready <= 1'b0;
            spi_busy <= 1'b0;
        end else begin
            if (state >= ST_HEADER) begin
                if (pcm_div == 14'd12499) begin
                    pcm_div <= 14'd0;
                    pcm_latched <= pcm_sample[9:2];
                    sample_ready <= 1'b1;
                end else begin
                    pcm_div <= pcm_div + 14'd1;
                end
            end

            case (state)
                ST_OFF: begin
                    xrst <= 1'b0;
                    xcs <= 1'b1;
                    xdcs <= 1'b1;
                    sclk <= 1'b0;
                    mosi <= 1'b1;
                    wait_count <= 33'd0;
                    header_index <= 6'd0;
                    sample_ready <= 1'b0;
                    state <= ST_RESET_LOW;
                end
                ST_RESET_LOW: begin
                    if (wait_count == 25'd999999) begin
                        wait_count <= 25'd0;
                        xrst <= 1'b1;
                        state <= ST_RESET_HIGH;
                    end else begin
                        wait_count <= wait_count + 25'd1;
                    end
                end
                ST_RESET_HIGH: begin
                    if (wait_count == 25'd1999999) begin
                        wait_count <= 25'd0;
                        state <= ST_WAIT_DREQ;
                    end else begin
                        wait_count <= wait_count + 25'd1;
                    end
                end
                ST_WAIT_DREQ: begin
                    if (dreq) start_command(CMD_SCI_MODE, ST_SCI_CLOCK);
                end
                ST_SCI_CLOCK: begin
                    if (dreq) start_command(CMD_SCI_CLOCK, ST_SCI_VOL);
                end
                ST_SCI_VOL: begin
                    if (dreq) start_command(CMD_SCI_VOL, ST_HEADER);
                end
                ST_HEADER: begin
                    if (header_index == 6'd44) begin
                        state <= ST_WAIT_PCM;
                    end else if (dreq) begin
                        start_command(CMD_HEADER, ST_HEADER);
                        header_index <= header_index + 6'd1;
                    end
                end
                ST_WAIT_PCM: begin
                    if (sample_ready && dreq) begin
                        sample_ready <= 1'b0;
                        start_command(CMD_PCM, ST_WAIT_PCM);
                    end
                end
                ST_SEND: begin
                    mosi <= shifter[bit_index];
                    if (spi_busy) begin
                        if (spi_div == 6'd31) begin
                            spi_div <= 6'd0;
                            sclk <= ~sclk;
                            if (sclk) begin
                                if (bit_index == 3'd0) begin
                                    if (byte_index == command_len(command) - 6'd1) begin
                                        spi_busy <= 1'b0;
                                        xcs <= 1'b1;
                                        xdcs <= 1'b1;
                                        sclk <= 1'b0;
                                        state <= return_state;
                                    end else begin
                                        byte_index <= byte_index + 6'd1;
                                        bit_index <= 3'd7;
                                        shifter <= command_byte(command, byte_index + 6'd1);
                                    end
                                end else begin
                                    bit_index <= bit_index - 3'd1;
                                end
                            end
                        end else begin
                            spi_div <= spi_div + 6'd1;
                        end
                    end
                end
                default: state <= ST_OFF;
            endcase
        end
    end
endmodule

module vs1003b_sine_demo (
    input wire clk,
    input wire reset,
    input wire enable,
    input wire dreq,
    input wire miso,
    output reg mosi,
    output reg sclk,
    output reg xcs,
    output reg xdcs,
    output reg xrst,
    output wire [7:0] debug
);
    localparam ST_OFF        = 5'd0;
    localparam ST_RESET_LOW  = 5'd1;
    localparam ST_RESET_HIGH = 5'd2;
    localparam ST_WAIT_DREQ  = 5'd3;
    localparam ST_SCI_MODE   = 5'd4;
    localparam ST_SCI_CLOCK  = 5'd5;
    localparam ST_SCI_VOL    = 5'd6;
    localparam ST_NOTE_START = 5'd7;
    localparam ST_NOTE_HOLD  = 5'd8;
    localparam ST_NOTE_STOP  = 5'd9;
    localparam ST_GAP        = 5'd10;
    localparam ST_SEND       = 5'd11;
    localparam [24:0] DREQ_TIMEOUT = 25'd4999999;

    localparam CMD_NONE      = 3'd0;
    localparam CMD_SCI_MODE  = 3'd1;
    localparam CMD_SCI_CLOCK = 3'd2;
    localparam CMD_SCI_VOL   = 3'd3;
    localparam CMD_SINE_ON   = 3'd4;
    localparam CMD_SINE_OFF  = 3'd5;

    reg [4:0] state = ST_OFF;
    reg [4:0] return_state = ST_OFF;
    reg [2:0] command = CMD_NONE;
    reg [2:0] byte_index = 3'd0;
    reg [2:0] bit_index = 3'd0;
    reg [7:0] tx_byte = 8'hff;
    reg [7:0] shifter = 8'hff;
    reg [5:0] spi_div = 6'd0;
    reg [24:0] wait_count = 25'd0;
    reg [4:0] note_index = 5'd0;
    reg spi_busy = 1'b0;

    wire _unused_miso = miso;
    assign debug = {state != ST_OFF, spi_busy, sclk, ~xdcs, ~xcs, xrst, dreq, enable};

    function [7:0] command_byte;
        input [2:0] cmd;
        input [2:0] idx;
        input [4:0] note;
        begin
            case (cmd)
                CMD_SCI_MODE: begin
                    case (idx)
                        3'd0: command_byte = 8'h02; // write SCI
                        3'd1: command_byte = 8'h00; // MODE
                        3'd2: command_byte = 8'h08; // SM_SDINEW
                        3'd3: command_byte = 8'h20; // SM_TESTS
                        default: command_byte = 8'h00;
                    endcase
                end
                CMD_SCI_CLOCK: begin
                    case (idx)
                        3'd0: command_byte = 8'h02;
                        3'd1: command_byte = 8'h03; // CLOCKF
                        3'd2: command_byte = 8'h60;
                        3'd3: command_byte = 8'h00;
                        default: command_byte = 8'h00;
                    endcase
                end
                CMD_SCI_VOL: begin
                    case (idx)
                        3'd0: command_byte = 8'h02;
                        3'd1: command_byte = 8'h0b; // VOL
                        3'd2: command_byte = 8'h00;
                        3'd3: command_byte = 8'h00;
                        default: command_byte = 8'h00;
                    endcase
                end
                CMD_SINE_ON: begin
                    case (idx)
                        3'd0: command_byte = 8'h53;
                        3'd1: command_byte = 8'hef;
                        3'd2: command_byte = 8'h6e;
                        3'd3: command_byte = sine_note(note);
                        default: command_byte = 8'h00;
                    endcase
                end
                CMD_SINE_OFF: begin
                    case (idx)
                        3'd0: command_byte = 8'h45;
                        3'd1: command_byte = 8'h78;
                        3'd2: command_byte = 8'h69;
                        3'd3: command_byte = 8'h74;
                        default: command_byte = 8'h00;
                    endcase
                end
                default: command_byte = 8'hff;
            endcase
        end
    endfunction

    function command_msb;
        input [2:0] cmd;
        input [2:0] idx;
        input [4:0] note;
        reg [7:0] value;
        begin
            value = command_byte(cmd, idx, note);
            command_msb = value[7];
        end
    endfunction

    function [3:0] command_len;
        input [2:0] cmd;
        begin
            case (cmd)
                CMD_SCI_MODE, CMD_SCI_CLOCK, CMD_SCI_VOL: command_len = 4'd4;
                CMD_SINE_ON, CMD_SINE_OFF: command_len = 4'd8;
                default: command_len = 4'd0;
            endcase
        end
    endfunction

    function [7:0] sine_note;
        input [4:0] idx;
        begin
            case (idx)
                5'd0:  sine_note = 8'd131;
                5'd1:  sine_note = 8'd132;
                5'd2:  sine_note = 8'd133;
                5'd3:  sine_note = 8'd134;
                5'd4:  sine_note = 8'd135;
                5'd5:  sine_note = 8'd134;
                5'd6:  sine_note = 8'd133;
                5'd7:  sine_note = 8'd132;
                5'd8:  sine_note = 8'd129;
                5'd9:  sine_note = 8'd130;
                5'd10: sine_note = 8'd131;
                5'd11: sine_note = 8'd132;
                5'd12: sine_note = 8'd133;
                5'd13: sine_note = 8'd132;
                5'd14: sine_note = 8'd131;
                default: sine_note = 8'd130;
            endcase
        end
    endfunction

    task start_command;
        input [2:0] cmd;
        input [4:0] ret;
        begin
            command <= cmd;
            return_state <= ret;
            byte_index <= 3'd0;
            bit_index <= 3'd7;
            tx_byte <= command_byte(cmd, 3'd0, note_index);
            shifter <= command_byte(cmd, 3'd0, note_index);
            spi_busy <= 1'b1;
            spi_div <= 6'd0;
            wait_count <= 25'd0;
            sclk <= 1'b0;
            mosi <= command_msb(cmd, 3'd0, note_index);
            if (cmd == CMD_SCI_MODE || cmd == CMD_SCI_CLOCK || cmd == CMD_SCI_VOL) begin
                xcs <= 1'b0;
                xdcs <= 1'b1;
            end else begin
                xcs <= 1'b1;
                xdcs <= 1'b0;
            end
            state <= ST_SEND;
        end
    endtask

    always @(posedge clk) begin
        if (reset || !enable) begin
            state <= ST_OFF;
            xrst <= 1'b0;
            xcs <= 1'b1;
            xdcs <= 1'b1;
            sclk <= 1'b0;
            mosi <= 1'b1;
            wait_count <= 25'd0;
            note_index <= 5'd0;
            spi_busy <= 1'b0;
        end else begin
            case (state)
                ST_OFF: begin
                    xrst <= 1'b0;
                    xcs <= 1'b1;
                    xdcs <= 1'b1;
                    sclk <= 1'b0;
                    mosi <= 1'b1;
                    wait_count <= 25'd0;
                    state <= ST_RESET_LOW;
                end
                ST_RESET_LOW: begin
                    if (wait_count == 25'd999999) begin
                        wait_count <= 25'd0;
                        xrst <= 1'b1;
                        state <= ST_RESET_HIGH;
                    end else begin
                        wait_count <= wait_count + 25'd1;
                    end
                end
                ST_RESET_HIGH: begin
                    if (wait_count == 25'd1999999) begin
                        wait_count <= 25'd0;
                        state <= ST_WAIT_DREQ;
                    end else begin
                        wait_count <= wait_count + 25'd1;
                    end
                end
                ST_WAIT_DREQ: begin
                    if (dreq || wait_count >= DREQ_TIMEOUT) begin
                        start_command(CMD_SCI_MODE, ST_SCI_CLOCK);
                    end else begin
                        wait_count <= wait_count + 25'd1;
                    end
                end
                ST_SCI_CLOCK: begin
                    if (dreq || wait_count >= DREQ_TIMEOUT) begin
                        start_command(CMD_SCI_CLOCK, ST_SCI_VOL);
                    end else begin
                        wait_count <= wait_count + 25'd1;
                    end
                end
                ST_SCI_VOL: begin
                    if (dreq || wait_count >= DREQ_TIMEOUT) begin
                        start_command(CMD_SCI_VOL, ST_NOTE_START);
                    end else begin
                        wait_count <= wait_count + 25'd1;
                    end
                end
                ST_NOTE_START: begin
                    if (dreq || wait_count >= DREQ_TIMEOUT) begin
                        start_command(CMD_SINE_ON, ST_NOTE_HOLD);
                    end else begin
                        wait_count <= wait_count + 25'd1;
                    end
                end
                ST_NOTE_HOLD: begin
                    if (wait_count == 25'd24999999) begin
                        wait_count <= 25'd0;
                        start_command(CMD_SINE_OFF, ST_GAP);
                    end else begin
                        wait_count <= wait_count + 25'd1;
                    end
                end
                ST_GAP: begin
                    if (wait_count == 25'd4999999) begin
                        wait_count <= 25'd0;
                        if (note_index == 5'd15) note_index <= 5'd0;
                        else note_index <= note_index + 5'd1;
                        state <= ST_NOTE_START;
                    end else begin
                        wait_count <= wait_count + 25'd1;
                    end
                end
                ST_SEND: begin
                    if (spi_busy) begin
                        if (spi_div == 6'd31) begin
                            spi_div <= 6'd0;
                            if (!sclk) begin
                                sclk <= 1'b1;
                            end else begin
                                sclk <= 1'b0;
                                if (bit_index == 3'd0) begin
                                    if ({1'b0, byte_index} == command_len(command) - 4'd1) begin
                                        spi_busy <= 1'b0;
                                        xcs <= 1'b1;
                                        xdcs <= 1'b1;
                                        sclk <= 1'b0;
                                        state <= return_state;
                                    end else begin
                                        byte_index <= byte_index + 3'd1;
                                        bit_index <= 3'd7;
                                        tx_byte <= command_byte(command, byte_index + 3'd1, note_index);
                                        shifter <= command_byte(command, byte_index + 3'd1, note_index);
                                        mosi <= command_msb(command, byte_index + 3'd1, note_index);
                                    end
                                end else begin
                                    bit_index <= bit_index - 3'd1;
                                    mosi <= shifter[bit_index - 3'd1];
                                end
                            end
                        end else begin
                            spi_div <= spi_div + 6'd1;
                        end
                    end
                end
                default: state <= ST_OFF;
            endcase
        end
    end
endmodule

module rhythm_game_core (
    input wire clk,
    input wire reset,
    input wire enable,
    input wire paused,
    input wire [1:0] song_select,
    input wire [2:0] speed_select,
    input wire [2:0] buttons,
    output wire [2:0] mapped_buttons,
    output reg [2:0] button_edges,
    output wire [95:0] tracks,
    output wire [95:0] hold_tracks,
    output wire [2:0] hit_window,
    output reg [15:0] score,
    output reg [7:0] combo,
    output reg [3:0] judgement,
    output reg finished
);
    reg [2:0] button_meta = 3'd0;
    reg [2:0] button_sync = 3'd0;
    reg [2:0] button_prev = 3'd0;
    reg [31:0] lane0 = 32'd0;
    reg [31:0] lane1 = 32'd0;
    reg [31:0] lane2 = 32'd0;
    reg [31:0] hold_lane0 = 32'd0;
    reg [31:0] hold_lane1 = 32'd0;
    reg [31:0] hold_lane2 = 32'd0;
    reg [22:0] scroll_div = 23'd0;
    reg [3:0] chart_subdiv = 4'd0;
    reg [7:0] chart_step = 8'd0;
    reg [1:0] prev_song = 2'd0;
    reg [22:0] judgement_timer = 23'd0;
    reg chart_done = 1'b0;
    reg [2:0] spawn_notes = 3'd0;
    reg [2:0] spawn_holds = 3'd0;
    reg [5:0] hold_spawn0 = 6'd0;
    reg [5:0] hold_spawn1 = 6'd0;
    reg [5:0] hold_spawn2 = 6'd0;
    reg [2:0] hold_starts = 3'd0;
    reg [5:0] hold_len = 6'd0;
    reg [2:0] hold_hits = 3'd0;
    reg [9:0] cycle_points = 10'd0;
    reg [2:0] cycle_hits = 3'd0;
    reg [3:0] cycle_judgement = 4'd7;
    reg cycle_miss = 1'b0;

    assign mapped_buttons = button_sync;
    assign tracks = {lane2, lane1, lane0};
    assign hold_tracks = {hold_lane2, hold_lane1, hold_lane0};
    assign hit_window = {
        |lane2[31:24],
        |lane1[31:24],
        |lane0[31:24]
    };

    `include "rhythm_charts.vh"

    function [22:0] scroll_div_max_for_speed;
        input [2:0] speed;
        begin
            case (speed)
                3'b000: scroll_div_max_for_speed = 23'd6666665; // 0.75x
                3'b001: scroll_div_max_for_speed = 23'd4999999; // 1.00x
                3'b010: scroll_div_max_for_speed = 23'd3999999; // 1.25x
                3'b011: scroll_div_max_for_speed = 23'd3333332; // 1.50x
                3'b100: scroll_div_max_for_speed = 23'd2857142; // 1.75x
                3'b101: scroll_div_max_for_speed = 23'd2499999; // 2.00x
                3'b110: scroll_div_max_for_speed = 23'd1999999; // 2.50x
                default: scroll_div_max_for_speed = 23'd1666666; // 3.00x
            endcase
        end
    endfunction

    function [3:0] lane_quality;
        input [31:0] lane;
        begin
            if (lane[26] || lane[27] || lane[28]) begin
                lane_quality = 4'd2;
            end else if (lane[24] || lane[25] || lane[29] || lane[30] || lane[31]) begin
                lane_quality = 4'd1;
            end else begin
                lane_quality = 4'd0;
            end
        end
    endfunction

    function hold_requires_press;
        input [31:0] hold_lane;
        begin
            hold_requires_press = hold_lane[31] && (|hold_lane[30:24]);
        end
    endfunction

    task score_lane;
        input [3:0] quality;
        begin
            case (quality)
                4'd2: begin
                    cycle_points = cycle_points + 10'd100;
                    cycle_hits = cycle_hits + 3'd1;
                    if (cycle_judgement == 4'd7) begin
                        cycle_judgement = 4'd2;
                    end
                end
                4'd1: begin
                    cycle_points = cycle_points + 10'd40;
                    cycle_hits = cycle_hits + 3'd1;
                    cycle_judgement = 4'd1;
                end
                default: begin
                    cycle_judgement = 4'd1;
                end
            endcase
        end
    endtask

    always @(posedge clk) begin
        button_meta <= buttons;
        button_sync <= button_meta;
        button_prev <= button_sync;
        button_edges <= button_sync & ~button_prev;

        if (reset || !enable || prev_song != song_select) begin
            lane0 <= 32'd0;
            lane1 <= 32'd0;
            lane2 <= 32'd0;
            hold_lane0 <= 32'd0;
            hold_lane1 <= 32'd0;
            hold_lane2 <= 32'd0;
            scroll_div <= 23'd0;
            chart_subdiv <= 4'd0;
            chart_step <= 8'd0;
            prev_song <= song_select;
            score <= 16'd0;
            combo <= 8'd0;
            judgement <= 4'd7;
            judgement_timer <= 23'd0;
            chart_done <= 1'b0;
            finished <= 1'b0;
            hold_spawn0 <= 6'd0;
            hold_spawn1 <= 6'd0;
            hold_spawn2 <= 6'd0;
        end else if (!paused) begin
            cycle_points = 10'd0;
            cycle_hits = 3'd0;
            cycle_judgement = 4'd7;
            cycle_miss = 1'b0;
            spawn_holds = 3'd0;
            hold_starts = 3'd0;
            hold_len = 6'd0;
            hold_hits = 3'd0;

            if (finished) begin
                scroll_div <= 23'd0;
            end else if (scroll_div >= scroll_div_max_for_speed(speed_select)) begin
                scroll_div <= 23'd0;
                cycle_miss = lane0[31] || lane1[31] || lane2[31];
                if (hold_lane0[31] && button_sync[0]) hold_hits = hold_hits + 3'd1;
                if (hold_lane1[31] && button_sync[1]) hold_hits = hold_hits + 3'd1;
                if (hold_lane2[31] && button_sync[2]) hold_hits = hold_hits + 3'd1;
                if (hold_requires_press(hold_lane0) && !button_sync[0]) cycle_miss = 1'b1;
                if (hold_requires_press(hold_lane1) && !button_sync[1]) cycle_miss = 1'b1;
                if (hold_requires_press(hold_lane2) && !button_sync[2]) cycle_miss = 1'b1;

                if (chart_subdiv == 4'd11) begin
                    chart_subdiv <= 4'd0;
                    if (chart_done) begin
                        spawn_notes = 3'd0;
                    end else if (chart_step == 8'd63) begin
                        chart_done <= 1'b1;
                        spawn_notes = chart_row(song_select, chart_step);
                    end else begin
                        chart_step <= chart_step + 8'd1;
                        spawn_notes = chart_row(song_select, chart_step);
                    end
                    hold_starts = chart_hold_row(song_select, chart_step);
                    hold_len = chart_hold_len(song_select, chart_step);
                    if (hold_starts[0] && hold_len != 6'd0) hold_spawn0 <= hold_len;
                    if (hold_starts[1] && hold_len != 6'd0) hold_spawn1 <= hold_len;
                    if (hold_starts[2] && hold_len != 6'd0) hold_spawn2 <= hold_len;
                end else begin
                    chart_subdiv <= chart_subdiv + 4'd1;
                    spawn_notes = 3'd0;
                end

                if (hold_spawn0 != 6'd0) begin
                    spawn_holds[0] = 1'b1;
                    hold_spawn0 <= hold_spawn0 - 6'd1;
                end
                if (hold_spawn1 != 6'd0) begin
                    spawn_holds[1] = 1'b1;
                    hold_spawn1 <= hold_spawn1 - 6'd1;
                end
                if (hold_spawn2 != 6'd0) begin
                    spawn_holds[2] = 1'b1;
                    hold_spawn2 <= hold_spawn2 - 6'd1;
                end

                lane0 <= {lane0[30:0], spawn_notes[0]};
                lane1 <= {lane1[30:0], spawn_notes[1]};
                lane2 <= {lane2[30:0], spawn_notes[2]};
                hold_lane0 <= {hold_lane0[30:0], spawn_holds[0]};
                hold_lane1 <= {hold_lane1[30:0], spawn_holds[1]};
                hold_lane2 <= {hold_lane2[30:0], spawn_holds[2]};

                if (cycle_miss) begin
                    combo <= 8'd0;
                    judgement <= 4'd0;
                end else if (hold_hits != 3'd0) begin
                    case (hold_hits)
                        3'd1: score <= score + 16'd10;
                        3'd2: score <= score + 16'd20;
                        default: score <= score + 16'd30;
                    endcase
                    judgement <= 4'd2;
                end

                if (chart_done &&
                    lane0 == 32'd0 && lane1 == 32'd0 && lane2 == 32'd0 &&
                    hold_lane0 == 32'd0 && hold_lane1 == 32'd0 && hold_lane2 == 32'd0 &&
                    hold_spawn0 == 6'd0 && hold_spawn1 == 6'd0 && hold_spawn2 == 6'd0) begin
                    finished <= 1'b1;
                end
            end else begin
                scroll_div <= scroll_div + 23'd1;

                if (button_edges[0]) begin
                    score_lane(lane_quality(lane0));
                    if (lane_quality(lane0) != 4'd0) lane0[31:24] <= 8'd0;
                end
                if (button_edges[1]) begin
                    score_lane(lane_quality(lane1));
                    if (lane_quality(lane1) != 4'd0) lane1[31:24] <= 8'd0;
                end
                if (button_edges[2]) begin
                    score_lane(lane_quality(lane2));
                    if (lane_quality(lane2) != 4'd0) lane2[31:24] <= 8'd0;
                end
                if (button_edges != 3'd0) begin
                    score <= score + {6'd0, cycle_points};
                    if (cycle_hits != 3'd0) begin
                        combo <= combo + {5'd0, cycle_hits};
                    end
                    judgement <= cycle_judgement;
                end
            end
        end else begin
            scroll_div <= scroll_div;
        end
    end
endmodule

module rhythm_mb_sevenseg (
    input wire clk,
    input wire reset,
    input wire [19:0] score_bcd,
    input wire [3:0] judgement,
    input wire paused,
    input wire finished,
    output reg [7:0] seg,
    output reg [7:0] an
);
    reg [16:0] refresh = 17'd0;
    reg [3:0] nibble = 4'd0;

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
                4'hc: digit_seg = 8'b1100_1000; // M/miss
                4'hd: digit_seg = 8'b1010_0001; // d/done
                4'he: digit_seg = 8'b1000_0110; // E/finish
                4'hf: digit_seg = 8'b1000_1100; // P/pause
                default: digit_seg = 8'b1111_1111;
            endcase
        end
    endfunction

    function [3:0] judge_digit;
        input [3:0] value;
        begin
            case (value)
                4'd2: judge_digit = 4'ha;
                4'd1: judge_digit = 4'hb;
                4'd0: judge_digit = 4'hc;
                default: judge_digit = 4'd0;
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
        case (refresh[16:14])
            3'd0: begin an = 8'b1111_1110; nibble = score_bcd[3:0]; end
            3'd1: begin an = 8'b1111_1101; nibble = score_bcd[7:4]; end
            3'd2: begin an = 8'b1111_1011; nibble = score_bcd[11:8]; end
            3'd3: begin an = 8'b1111_0111; nibble = score_bcd[15:12]; end
            3'd4: begin an = 8'b1110_1111; nibble = score_bcd[19:16]; end
            3'd5: begin an = 8'b1101_1111; nibble = judge_digit(judgement); end
            3'd6: begin an = 8'b1011_1111; nibble = finished ? 4'he : 4'd0; end
            default: begin an = 8'b0111_1111; nibble = paused ? 4'hf : 4'd0; end
        endcase
        seg = digit_seg(nibble);
    end
endmodule

module rhythm_sevenseg (
    input wire clk,
    input wire reset,
    input wire [15:0] score,
    input wire [7:0] combo,
    input wire [3:0] judgement,
    input wire paused,
    output reg [7:0] seg,
    output reg [7:0] an
);
    reg [16:0] refresh = 17'd0;
    reg [3:0] nibble = 4'd0;
    reg [19:0] score_bcd = 20'd0;

    function [19:0] bin16_to_bcd5;
        input [15:0] value;
        integer i;
        reg [35:0] shift;
        begin
            shift = 36'd0;
            shift[15:0] = value;
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

    function [7:0] digit_seg;
        input [3:0] value;
        begin
            case (value)
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
                4'ha: digit_seg = 8'b1000_1000;
                4'hb: digit_seg = 8'b1000_0011;
                4'hc: digit_seg = 8'b1100_0110;
                4'hd: digit_seg = 8'b1010_0001;
                4'he: digit_seg = 8'b1000_0110;
                4'hf: digit_seg = 8'b1000_1100; // P
                default: digit_seg = 8'b1000_1110;
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
        score_bcd = bin16_to_bcd5(score);
        case (refresh[16:14])
            3'd0: begin an = 8'b1111_1110; nibble = score_bcd[3:0]; end
            3'd1: begin an = 8'b1111_1101; nibble = score_bcd[7:4]; end
            3'd2: begin an = 8'b1111_1011; nibble = score_bcd[11:8]; end
            3'd3: begin an = 8'b1111_0111; nibble = score_bcd[15:12]; end
            3'd4: begin an = 8'b1110_1111; nibble = combo[3:0]; end
            3'd5: begin an = 8'b1101_1111; nibble = combo[7:4]; end
            3'd6: begin an = 8'b1011_1111; nibble = judgement; end
            default: begin an = 8'b0111_1111; nibble = paused ? 4'hf : 4'd0; end
        endcase
        seg = digit_seg(nibble);
    end
endmodule
