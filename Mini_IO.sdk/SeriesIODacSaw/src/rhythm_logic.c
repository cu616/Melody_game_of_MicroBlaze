/* Rhythm-game rules.
 *
 * This file handles song reset, hit/miss scoring, hold release checks and
 * finish detection.
 */
#include "rhythm_game.h"

void StartGame(void)
{
    u16 sw = (u16)Xil_In32(GPIO_SW_LED_BASEADDR + XGPIO_DATA_OFFSET);
    u16 song_sw = sw & 0x0003U;
    LastSongSwitch = song_sw;

    if (song_sw == 0U) {
        SongIndex = 3U;
        MbVgaSongCode = 3U;
        MbVgaStateCode = MB_VGA_STATE_WAIT;
        MbVgaRatingCode = MB_VGA_RATING_NONE;
        GameState = GAME_WAIT;
        GameTimeMs = 0U;
        Score = 0U;
        Combo = 0U;
        MaxCombo = 0U;
        NextNote = 0U;
        ActiveHoldValid = 0U;
        ActiveHoldIndex = 0U;
        SetRating(' ');
        UpdateScoreDisplay();
        VsAudioArmed = 0U;
        VsSetMuted(1U);
        VsGpioWrite(VsGpioState);
        return;
    } else if (song_sw == 0x0003U) {
        SongIndex = 2U;
    } else if (song_sw == 0x0002U) {
        SongIndex = 1U;
    } else if (song_sw == 0x0001U) {
        SongIndex = 0U;
    }
    MbVgaSongCode = SongIndex;
    MbVgaStateCode = MB_VGA_STATE_PLAY;
    MbVgaRatingCode = MB_VGA_RATING_NONE;
    MbVgaVolumeCode = VsVolumeIndex;
    MbVgaRowMs = MbVgaRowMsFromSwitch(sw);
    GameState = GAME_PLAY;
    GameTimeMs = 0;
    Score = 0;
    Combo = 0;
    MaxCombo = 0;
    NextNote = 0;
    ActiveHoldValid = 0U;
    ActiveHoldIndex = 0U;
    SetRating(' ');
    UpdateScoreDisplay();
    VsSelectSong(SongIndex);
    VsResetDecoderForNewMidi();
    VsRestartMidi();
    VsSetMuted((sw & SW_MUTE_MASK) != 0U);
}

static void AddHit(u8 rating)
{
    Combo++;
    if (Combo > MaxCombo) {
        MaxCombo = Combo;
    }
    if (rating == 'A') {
        Score += 100U;
    } else if (rating == 'B') {
        Score += 50U;
    } else {
        Score += 0U;
    }
    SetRating(rating);
    UpdateScoreDisplay();
}

static void AddMiss(void)
{
    Combo = 0;
    SetRating('M');
    UpdateScoreDisplay();
}

void JudgeLane(u8 lane)
{
    const Note *song = CurrentSong();
    u8 len = CurrentSongLen();
    u8 i;

    for (i = NextNote; i < len; ++i) {
        s32 diff = (s32)GameTimeMs - (s32)song[i].time_ms;
        if (diff < -200) {
            break;
        }
        if (song[i].lane == lane && diff >= -200 && diff <= 200) {
            if (song[i].hold != 0U && song[i].length_ms > 0U) {
                ActiveHoldValid = 1U;
                ActiveHoldIndex = i;
            }
            NextNote = i + 1U;
            if (diff < 0) {
                diff = -diff;
            }
            if ((u32)diff <= 70U) {
                AddHit('A');
            } else if ((u32)diff <= 130U) {
                AddHit('B');
            } else {
                AddHit('B');
            }
            return;
        }
    }
    AddMiss();
}

void UpdateMisses(void)
{
    const Note *song = CurrentSong();
    u8 len = CurrentSongLen();

    if (ActiveHoldValid != 0U) {
        const Note *active = &song[ActiveHoldIndex];
        u32 hold_end = (u32)active->time_ms + (u32)active->length_ms;
        if (GameTimeMs >= hold_end) {
            ActiveHoldValid = 0U;
        } else if (GameTimeMs > (u32)active->time_ms + HOLD_RELEASE_GRACE_MS &&
                   (CurrentButtons & LaneButtonMask(active->lane)) == 0U) {
            ActiveHoldValid = 0U;
            AddMiss();
        }
    }

    while (NextNote < len && GameTimeMs > (u32)song[NextNote].time_ms + 220U) {
        NextNote++;
        AddMiss();
    }
    if (NextNote >= len && ActiveHoldValid == 0U &&
        GameTimeMs > (u32)song[len - 1U].time_ms + 1200U) {
        GameState = GAME_DONE;
        MbVgaStateCode = MB_VGA_STATE_DONE;
        VsGpioWrite(VsGpioState);
        UpdateScoreDisplay();
    }
}

void HandleButtonPresses(u8 pressed)
{
    if ((pressed & BTN_U) != 0U && (pressed & BTN_D) == 0U) {
        VsAdjustVolume(1);
    }
    if ((pressed & BTN_D) != 0U && (pressed & BTN_U) == 0U) {
        VsAdjustVolume(-1);
    }
    if (GameState != GAME_PLAY) {
        return;
    }
    if ((pressed & BTN_L) != 0U) {
        JudgeLane(LANE_LEFT);
    }
    if ((pressed & BTN_C) != 0U) {
        JudgeLane(LANE_MID);
    }
    if ((pressed & BTN_R) != 0U) {
        JudgeLane(LANE_RIGHT);
    }
}
