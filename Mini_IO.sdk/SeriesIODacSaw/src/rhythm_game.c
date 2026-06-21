/* Main loop for the final MicroBlaze rhythm game. */
#include "rhythm_game.h"

int main(void)
{
    u8 buttons;
    u8 pressed;
    u8 vga_frame_div = 0U;

    /* Final build path: MicroBlaze game logic streams compact MIDI data to
     * VS1003B.  Earlier UART/J8/PWM audio tests were removed after acceptance
     * because they are not part of the submitted running path.
     */
    InitHardware();
    SetRating(' ');
    UpdateScoreDisplay();
    VsInitFadedMidiPlayer();
    StartGame();
    InitInterrupts();

    while (1) {
        pressed = PopButtonEvents();
        if (pressed != 0U) {
            HandleButtonPresses(pressed);
        }

        if (PopTimerTick()) {
            u16 sw = (u16)Xil_In32(GPIO_SW_LED_BASEADDR + XGPIO_DATA_OFFSET);
            u16 song_sw = sw & 0x0003U;
            u8 paused_by_switch = (sw & SW_PAUSE_MASK) != 0U;
            u8 muted_by_switch = (sw & SW_MUTE_MASK) != 0U;
            buttons = CurrentButtons;
            if (song_sw != LastSongSwitch) {
                StartGame();
            }
            MbVgaRowMs = MbVgaRowMsFromSwitch(sw);
            if (paused_by_switch && GameState == GAME_PLAY) {
                GameState = GAME_PAUSE;
                MbVgaStateCode = MB_VGA_STATE_PAUSE;
                VsGpioWrite(VsGpioState);
            } else if (!paused_by_switch && GameState == GAME_PAUSE) {
                GameState = GAME_PLAY;
                MbVgaStateCode = MB_VGA_STATE_PLAY;
                VsGpioWrite(VsGpioState);
            }
            VsSetMuted(muted_by_switch || paused_by_switch || song_sw == 0U);

            if (GameState == GAME_PLAY) {
                GameTimeMs += 1U;
                UpdateMisses();
                if (GameTimeMs >= AUDIO_START_DELAY_MS) {
                    VsServiceFadedMidi();
                }
            }
            ++vga_frame_div;
            if (vga_frame_div >= 8U) {
                vga_frame_div = 0U;
                MbVgaSendFrame(buttons);
            }
            UpdateFeedback(buttons);
            ScanSevenSeg();
        } else if (GameState == GAME_PLAY && GameTimeMs >= AUDIO_START_DELAY_MS) {
            VsServiceFadedMidi();
        } else if (PopSwitchEvent()) {
            u16 sw = (u16)Xil_In32(GPIO_SW_LED_BASEADDR + XGPIO_DATA_OFFSET);
            u16 song_sw = sw & 0x0003U;
            if (song_sw != LastSongSwitch) {
                StartGame();
            }
            MbVgaRowMs = MbVgaRowMsFromSwitch(sw);
            VsSetMuted(((sw & SW_MUTE_MASK) != 0U) ||
                       ((sw & SW_PAUSE_MASK) != 0U) ||
                       song_sw == 0U);
        }
    }
}
