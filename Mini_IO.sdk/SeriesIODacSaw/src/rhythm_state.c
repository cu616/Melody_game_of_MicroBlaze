/* Shared game state and chart selection.
 *
 * The generated chart arrays live only in this file; other modules access the
 * selected chart through CurrentSong() and CurrentSongLen().
 */
#include "rhythm_game.h"

#include "generated_charts.h"

u8 Display[8] = {0xFF, 0xFF, 0xFF, 0xFF, 0xC0, 0xC0, 0xC0, 0xC0};
u8 ScanDigit = 0;
u8 GameState = GAME_WAIT;
u8 LastRating = 0;
u8 SongIndex = 3U;
u16 LastSongSwitch = 0xFFFFU;
u8 NextNote = 0;
u8 ActiveHoldValid = 0;
u8 ActiveHoldIndex = 0;
u8 LastButtons = 0;
u32 GameTimeMs = 0;
u32 Score = 0;
u16 Combo = 0;
u16 MaxCombo = 0;
u16 MbVgaRowMs = MB_VGA_ROW_MS;
volatile u32 TimerTicksPending = 0U;
volatile u8 ButtonPressedEvents = 0U;
volatile u8 SwitchEventPending = 0U;
volatile u8 CurrentButtons = 0U;

const Note *CurrentSong(void)
{
    if (SongIndex == 2U) {
        return Song2;
    }
    if (SongIndex == 1U) {
        return Song1;
    }
    return Song0;
}

u8 CurrentSongLen(void)
{
    if (SongIndex == 2U) {
        return SONG2_LEN;
    }
    if (SongIndex == 1U) {
        return SONG1_LEN;
    }
    if (SongIndex == 0U) {
        return SONG0_LEN;
    }
    return 0U;
}

u8 LaneButtonMask(u8 lane)
{
    if (lane == LANE_LEFT) {
        return BTN_L;
    }
    if (lane == LANE_RIGHT) {
        return BTN_R;
    }
    return BTN_C;
}
