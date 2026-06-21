/* Display and feedback bridge.
 *
 * MicroBlaze does the gameplay math, and this module packs score, judgement,
 * visible note rows, hold rows and button state into GPIO packets that the RTL
 * VGA bridge latches and renders.
 */
#include "rhythm_game.h"

static const u8 SegHex[16] = {
    0xC0, 0xF9, 0xA4, 0xB0, 0x99, 0x92, 0x82, 0xF8,
    0x80, 0x90, 0x88, 0x83, 0xC6, 0xA1, 0x86, 0x8E
};

void SetRating(u8 rating)
{
    LastRating = rating;
    if (rating == 'A') {
        MbVgaRatingCode = MB_VGA_RATING_GOOD;
    } else if (rating == 'B' || rating == 'C') {
        MbVgaRatingCode = MB_VGA_RATING_BAD;
    } else if (rating == 'M') {
        MbVgaRatingCode = MB_VGA_RATING_MISS;
    } else {
        MbVgaRatingCode = MB_VGA_RATING_NONE;
    }
    Display[0] = 0xFF;
    Display[1] = 0xFF;
    Display[2] = 0xFF;
    Display[3] = 0xFF;

    if (rating == 'A') {
        /* Physical left-to-right order: G O O d. */
        Display[0] = 0xA1;
        Display[1] = 0xC0;
        Display[2] = 0xC0;
        Display[3] = 0x82;
    } else if (rating == 'B') {
        /* Physical left-to-right order: blank b A d. */
        Display[0] = 0xA1;
        Display[1] = 0x88;
        Display[2] = 0x83;
    } else if (rating == 'C') {
        Display[0] = 0xC6;
    } else if (rating == 'M') {
        /* Physical left-to-right approximation: E i S S. */
        Display[0] = 0x92;
        Display[1] = 0x92;
        Display[2] = 0xF9;
        Display[3] = 0x86;
    }
    VsGpioWrite(VsGpioState);
}

void UpdateScoreDisplay(void)
{
    u32 theoretical_max = (u32)CurrentSongLen() * 100U;
    u32 shown = 0U;

    if (theoretical_max != 0U) {
        shown = (Score * 9999U + theoretical_max / 2U) / theoretical_max;
        if (shown > 9999U) {
            shown = 9999U;
        }
    }
    Display[4] = SegHex[(shown / 1000U) % 10U];
    Display[5] = SegHex[(shown / 100U) % 10U];
    Display[6] = SegHex[(shown / 10U) % 10U];
    Display[7] = SegHex[shown % 10U];
}

void ScanSevenSeg(void)
{
    Xil_Out32(GPIO_SEVENSEG_BASEADDR + XGPIO_DATA_OFFSET, (u32)((u8)~(1U << ScanDigit)));
    Xil_Out32(GPIO_SEVENSEG_BASEADDR + XGPIO_DATA2_OFFSET, (u32)Display[ScanDigit]);
    ScanDigit = (ScanDigit + 1U) & 7U;
}

static void MbVgaPacketWrite(u8 packet_id, u8 data)
{
    Xil_Out32(GPIO_SEVENSEG_BASEADDR + XGPIO_DATA_OFFSET, 0xFFU);
    Xil_Out32(GPIO_SEVENSEG_BASEADDR + XGPIO_DATA2_OFFSET, (u32)data);
    Xil_Out32(GPIO_SEVENSEG_BASEADDR + XGPIO_DATA_OFFSET, (u32)(0x20U | (packet_id & 0x1FU)));
}

u16 MbVgaRowMsFromSwitch(u16 sw)
{
    static const u16 row_ms_table[8] = {
        53U, 40U, 32U, 27U, 23U, 20U, 16U, 13U
    };
    return row_ms_table[(sw & SW_SPEED_MASK) >> SW_SPEED_SHIFT];
}

static s16 MbVgaNoteRow(s32 note_time_ms)
{
    s32 future = note_time_ms - (s32)GameTimeMs;
    s32 offset;
    if (future >= 0) {
        offset = (future + ((s32)MbVgaRowMs / 2)) / (s32)MbVgaRowMs;
    } else {
        offset = (future - ((s32)MbVgaRowMs / 2)) / (s32)MbVgaRowMs;
    }
    return (s16)(MB_VGA_JUDGE_ROW - offset);
}

static void MbVgaSetTrackBit(u32 tracks[3], u8 lane, s16 row)
{
    if (lane < 3U && row >= 0 && row < 32) {
        tracks[lane] |= (1UL << (u8)row);
    }
}

static void MbVgaSetHoldRange(u32 tracks[3], u8 lane, s16 row_a, s16 row_b)
{
    s16 row;
    s16 lo = row_a < row_b ? row_a : row_b;
    s16 hi = row_a < row_b ? row_b : row_a;
    if (lo < 0) {
        lo = 0;
    }
    if (hi > 31) {
        hi = 31;
    }
    for (row = lo; row <= hi; ++row) {
        MbVgaSetTrackBit(tracks, lane, row);
    }
}

static void MbVgaBuildTracks(u32 notes[3], u32 holds[3])
{
    const Note *song = CurrentSong();
    u8 len = CurrentSongLen();
    u8 i;

    notes[0] = 0U;
    notes[1] = 0U;
    notes[2] = 0U;
    holds[0] = 0U;
    holds[1] = 0U;
    holds[2] = 0U;

    if (ActiveHoldValid != 0U && ActiveHoldIndex < len) {
        s16 head = MbVgaNoteRow((s32)song[ActiveHoldIndex].time_ms);
        s16 tail = MbVgaNoteRow((s32)song[ActiveHoldIndex].time_ms +
                                (s32)song[ActiveHoldIndex].length_ms);
        MbVgaSetHoldRange(holds, song[ActiveHoldIndex].lane, head, tail);
    }

    for (i = NextNote; i < len; ++i) {
        s16 row = MbVgaNoteRow((s32)song[i].time_ms);
        if (song[i].hold != 0U && song[i].length_ms > 0U) {
            s16 tail = MbVgaNoteRow((s32)song[i].time_ms + (s32)song[i].length_ms);
            MbVgaSetHoldRange(holds, song[i].lane, row, tail);
            MbVgaSetTrackBit(notes, song[i].lane, row);
        } else {
            MbVgaSetTrackBit(notes, song[i].lane, row);
        }
    }
}

void MbVgaSendFrame(u8 buttons)
{
    u32 notes[3];
    u32 holds[3];
    u8 lane_buttons = 0U;
    u8 lane;
    u8 chunk;

    MbVgaBuildTracks(notes, holds);
    if ((buttons & BTN_L) != 0U) {
        lane_buttons |= 0x01U;
    }
    if ((buttons & BTN_C) != 0U) {
        lane_buttons |= 0x02U;
    }
    if ((buttons & BTN_R) != 0U) {
        lane_buttons |= 0x04U;
    }

    for (lane = 0U; lane < 3U; ++lane) {
        for (chunk = 0U; chunk < 4U; ++chunk) {
            MbVgaPacketWrite((u8)(lane * 4U + chunk), (u8)(notes[lane] >> (chunk * 8U)));
        }
    }
    for (lane = 0U; lane < 3U; ++lane) {
        for (chunk = 0U; chunk < 4U; ++chunk) {
            MbVgaPacketWrite((u8)(12U + lane * 4U + chunk), (u8)(holds[lane] >> (chunk * 8U)));
        }
    }
    MbVgaPacketWrite(24U, lane_buttons);
}

void UpdateFeedback(u8 buttons)
{
    if (LastRating == 'A') {
        Xil_Out32(GPIO_BUTTON_RGB_BASEADDR + XGPIO_DATA2_OFFSET, 0x12U);
    } else if (LastRating == 'B' || LastRating == 'C') {
        Xil_Out32(GPIO_BUTTON_RGB_BASEADDR + XGPIO_DATA2_OFFSET, 0x09U);
    } else if (LastRating == 'M') {
        Xil_Out32(GPIO_BUTTON_RGB_BASEADDR + XGPIO_DATA2_OFFSET, 0x21U);
    } else {
        Xil_Out32(GPIO_BUTTON_RGB_BASEADDR + XGPIO_DATA2_OFFSET, 0x00U);
    }
}
