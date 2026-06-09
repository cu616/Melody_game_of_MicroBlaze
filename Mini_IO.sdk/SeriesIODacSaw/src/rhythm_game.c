/*
 * Rhythm game demo for Nexys4 DDR + MicroBlaze.
 *
 * GPIO0 channel 1: switches, channel 2: LEDs
 * GPIO1 channel 1: seven-seg anodes, channel 2: seven-seg segments
 * GPIO2 channel 1: buttons, channel 2: RGB LEDs
 *
 * In VS1003B MicroBlaze mode, GPIO0 channel 2 is repurposed as the bit-banged
 * VS1003B bus: bit0 XCS, bit1 XDCS, bit2 XRST, bit3 MOSI, bit4 SCLK.
 */

#include "xparameters.h"
#include "xil_io.h"
#include "xil_printf.h"
#include "xil_types.h"
#include "xgpio_l.h"
#include "xstatus.h"
#include "xintc_l.h"
#include "xtmrctr_l.h"
#include "xuartlite_l.h"
#include "mb_interface.h"
#include "vs1003b_midi_assets.h"

#define VS1003B_MB_STREAM_TEST   1
#define VS1003B_SINE_OUTPUT_TEST 0
#define USB_UART_AUDIO_TEST      0
#define UART_AUDIO_SAMPLE_RATE   800U
#define UART_AUDIO_SAMPLE_US     (1000000U / UART_AUDIO_SAMPLE_RATE)
#define UART_AUDIO_BASEADDR      STDOUT_BASEADDRESS

#define GPIO_SW_LED_BASEADDR     XPAR_AXI_GPIO_0_BASEADDR
#define GPIO_SEVENSEG_BASEADDR   XPAR_AXI_GPIO_1_BASEADDR
#define GPIO_BUTTON_RGB_BASEADDR XPAR_AXI_GPIO_2_BASEADDR
#define TIMER_BASEADDR           XPAR_AXI_TIMER_0_BASEADDR
#define INTC_BASEADDR            XPAR_AXI_INTC_0_BASEADDR

#define TIMER_TICK_US            1000U
#define TIMER_LOAD_VALUE         (XPAR_AXI_TIMER_0_CLOCK_FREQ_HZ / 1000000U * TIMER_TICK_US)
#define INTC_TIMER_MASK          XPAR_AXI_TIMER_0_INTERRUPT_MASK
#define INTC_SW_MASK             XPAR_AXI_GPIO_0_IP2INTC_IRPT_MASK
#define INTC_BUTTON_MASK         XPAR_AXI_GPIO_2_IP2INTC_IRPT_MASK
#define INTC_ENABLE_MASK         (INTC_TIMER_MASK | INTC_SW_MASK | INTC_BUTTON_MASK)

#define VS_DREQ_GPIO_MASK        0x4000U
#define VS_MISO_GPIO_MASK        0x2000U
#define VS_XCS_GPIO_MASK         0x0001U
#define VS_XDCS_GPIO_MASK        0x0002U
#define VS_XRST_GPIO_MASK        0x0004U
#define VS_MOSI_GPIO_MASK        0x0008U
#define VS_SCLK_GPIO_MASK        0x0010U
#define VS_GPIO_IDLE             (VS_XCS_GPIO_MASK | VS_XDCS_GPIO_MASK | VS_XRST_GPIO_MASK)
#define VS_GPIO_BUS_MASK         (VS_XCS_GPIO_MASK | VS_XDCS_GPIO_MASK | VS_XRST_GPIO_MASK | VS_MOSI_GPIO_MASK | VS_SCLK_GPIO_MASK)
#define MB_VGA_STATE_WAIT        0U
#define MB_VGA_STATE_PLAY        1U
#define MB_VGA_STATE_PAUSE       2U
#define MB_VGA_STATE_DONE        3U
#define MB_VGA_RATING_NONE       0U
#define MB_VGA_RATING_GOOD       1U
#define MB_VGA_RATING_BAD        2U
#define MB_VGA_RATING_MISS       3U
#define VS_LED_INIT              0x8000U
#define VS_LED_DREQ_TIMEOUT      0x4000U
#define VS_LED_SCI_DONE          0x2000U
#define VS_LED_STREAMING         0x1000U
#define VS_LED_LOOP              0x0800U
#define VS_LED_SPI_ERROR         0x0400U
#define VS_LED_SCI_READ_OK       0x0200U
#define VS_LED_SCI_READ_BAD      0x0100U
#define VS_LED_DECODE_TICK       0x0080U
#define VS_LED_DECODE_STUCK      0x0040U
#define VS_SCI_MODE              0x00U
#define VS_SCI_CLOCKF            0x03U
#define VS_SCI_DECODE_TIME       0x04U
#define VS_SCI_AUDATA            0x05U
#define VS_SCI_VOL               0x0BU
#define VS_SM_TESTS              0x0020U
#define VS_SM_SDINEW             0x0800U
#define SW_MUTE_MASK             0x0004U
#define SW_PAUSE_MASK            0x8000U
#define SW_SPEED_SHIFT           3U
#define SW_SPEED_MASK            0x0038U
#define AUDIO_START_DELAY_MS     2200U
#define MB_VGA_ROW_MS            40
#define MB_VGA_JUDGE_ROW         27

#define BTN_C 0x01U
#define BTN_U 0x02U
#define BTN_L 0x04U
#define BTN_R 0x08U
#define BTN_D 0x10U

#define LANE_LEFT  0U
#define LANE_MID   1U
#define LANE_RIGHT 2U
#define HOLD_RELEASE_GRACE_MS 80U

#define GAME_WAIT  0U
#define GAME_PLAY  1U
#define GAME_PAUSE 2U
#define GAME_DONE  3U

#if VS1003B_MB_STREAM_TEST
/* Shared state exposed to the RTL display bridge through GPIO0 channel 2.
 * Low bits drive the VS1003B bus; high bits encode song/state/judge/volume
 * so the VGA and seven-segment logic can render the same software state.
 */
static u32 VsGpioState = VS_GPIO_IDLE;
static u32 VsAudioPos = 0U;
static u8 VsAudioArmed = 0U;
static u8 MbVgaStateCode = MB_VGA_STATE_WAIT;
static u8 MbVgaSongCode = 3U;
static u8 MbVgaRatingCode = MB_VGA_RATING_NONE;
static u8 MbVgaVolumeCode = 13U;
static const u8 *VsAudioData = Vs1003bFadedMidi;
static u32 VsAudioLen = VS1003B_FADED_MIDI_LEN;
static const u8 VsVolumeTable[] = {
    0xFEU, 0xD8U, 0xB8U, 0x98U, 0x78U, 0x60U, 0x48U, 0x34U,
    0x24U, 0x18U, 0x10U, 0x0CU, 0x08U, 0x05U, 0x02U, 0x00U
};
static u8 VsVolumeIndex = 13U;
static u8 VsMuted = 0U;

static void BusyDelay(u32 cycles)
{
    volatile u32 i;
    for (i = 0; i < cycles; ++i) {
    }
}

static u32 MbVgaStatusBits(void)
{
    return ((u32)(MbVgaStateCode & 0x03U) << 14) |
           ((u32)(MbVgaSongCode & 0x03U) << 12) |
           ((u32)(MbVgaRatingCode & 0x03U) << 10) |
           ((u32)(MbVgaVolumeCode & 0x0FU) << 6) |
           ((VsAudioArmed != 0U) ? 0x0020U : 0x0000U);
}

static void VsGpioWrite(u32 value)
{
    VsGpioState = (value & VS_GPIO_BUS_MASK) | MbVgaStatusBits();
    Xil_Out32(GPIO_SW_LED_BASEADDR + XGPIO_DATA2_OFFSET, VsGpioState);
}

static void VsSetStatus(u32 mask)
{
    VsGpioWrite(VsGpioState | mask);
}

static void VsToggleStatus(u32 mask)
{
    VsGpioWrite(VsGpioState ^ mask);
}

static void VsSetBus(u32 bus_bits)
{
    VsGpioWrite((VsGpioState & ~VS_GPIO_BUS_MASK) | bus_bits | (VsGpioState & 0xFFC0U));
}

static int VsWaitDreq(u32 timeout)
{
    while (timeout-- != 0U) {
        if ((Xil_In32(GPIO_SW_LED_BASEADDR + XGPIO_DATA_OFFSET) & VS_DREQ_GPIO_MASK) != 0U) {
            return 1;
        }
    }
    return 0;
}

static int VsReadMiso(void)
{
    return (Xil_In32(GPIO_SW_LED_BASEADDR + XGPIO_DATA_OFFSET) & VS_MISO_GPIO_MASK) != 0U;
}

static void VsBitDelay(void)
{
    volatile u32 i;
    for (i = 0; i < 20U; ++i) {
    }
}

static u8 VsBitBangTransferByte(u8 data)
{
    u8 bit;
    u8 rx = 0U;
    u32 base = VsGpioState & ~VS_SCLK_GPIO_MASK;

    for (bit = 0; bit < 8U; ++bit) {
        if ((data & 0x80U) != 0U) {
            VsGpioWrite((base | VS_MOSI_GPIO_MASK) & ~VS_SCLK_GPIO_MASK);
            VsBitDelay();
            VsGpioWrite(base | VS_MOSI_GPIO_MASK | VS_SCLK_GPIO_MASK);
        } else {
            VsGpioWrite((base & ~VS_MOSI_GPIO_MASK) & ~VS_SCLK_GPIO_MASK);
            VsBitDelay();
            VsGpioWrite((base & ~VS_MOSI_GPIO_MASK) | VS_SCLK_GPIO_MASK);
        }
        VsBitDelay();
        rx <<= 1;
        if (VsReadMiso()) {
            rx |= 1U;
        }
        VsGpioWrite(VsGpioState & ~VS_SCLK_GPIO_MASK);
        VsBitDelay();
        data <<= 1;
        base = VsGpioState & ~VS_SCLK_GPIO_MASK;
    }

    return rx;
}

static void VsBitBangByte(u8 data)
{
    (void)VsBitBangTransferByte(data);
}

static void VsBitBangBytes(const u8 *data, u32 len)
{
    u32 i;
    for (i = 0; i < len; ++i) {
        VsBitBangByte(data[i]);
    }
}

/* Bit-banged VS1003B setup.  The module decodes MIDI internally, so the
 * MicroBlaze only streams bytes and updates SCI control registers.
 */
static int VsSpiInit(void)
{
    Xil_Out32(GPIO_SW_LED_BASEADDR + XGPIO_TRI_OFFSET, 0xFFFFU);
    Xil_Out32(GPIO_SW_LED_BASEADDR + XGPIO_TRI2_OFFSET, 0x0000U);
    VsSetStatus(VS_LED_INIT);
    VsSetBus(VS_XCS_GPIO_MASK | VS_XDCS_GPIO_MASK);
    BusyDelay(200000U);
    VsSetBus(VS_GPIO_IDLE);
    BusyDelay(2000000U);
    return XST_SUCCESS;
}

static void VsSciWrite(u8 addr, u16 data)
{
    u8 cmd[4];
    cmd[0] = 0x02U;
    cmd[1] = addr;
    cmd[2] = (u8)(data >> 8);
    cmd[3] = (u8)data;

    (void)VsWaitDreq(8000000U);
    VsSetBus(VS_XDCS_GPIO_MASK | VS_XRST_GPIO_MASK);
    VsBitBangBytes(cmd, sizeof(cmd));
    VsSetBus(VS_GPIO_IDLE);
    (void)VsWaitDreq(8000000U);
}

static void VsApplyVolume(void)
{
    u8 attenuation = VsMuted ? 0xFEU : VsVolumeTable[VsVolumeIndex];
    VsSciWrite(VS_SCI_VOL, ((u16)attenuation << 8) | attenuation);
}

static void VsSetMuted(u8 muted)
{
    muted = muted ? 1U : 0U;
    if (muted != VsMuted) {
        VsMuted = muted;
        VsApplyVolume();
    }
}

static void VsAdjustVolume(int delta)
{
    if (delta > 0) {
        if (VsVolumeIndex < (u8)(sizeof(VsVolumeTable) - 1U)) {
            ++VsVolumeIndex;
        }
    } else if (delta < 0) {
        if (VsVolumeIndex > 0U) {
            --VsVolumeIndex;
        }
    }
    MbVgaVolumeCode = VsVolumeIndex;
    VsApplyVolume();
}

static void VsSendMp3Chunk(const u8 *data, u32 len)
{
    (void)VsWaitDreq(8000000U);
    VsSetBus(VS_XCS_GPIO_MASK | VS_XRST_GPIO_MASK);
    VsBitBangBytes(data, len);
    VsSetBus(VS_GPIO_IDLE);
}

#if VS1003B_SINE_OUTPUT_TEST
static void VsStartSineTest(void)
{
    static const u8 sine_start[] = {0x53U, 0xEFU, 0x6EU, 0x44U, 0x00U, 0x00U, 0x00U, 0x00U};

    VsSciWrite(VS_SCI_MODE, VS_SM_SDINEW | VS_SM_TESTS);
    VsSendMp3Chunk(sine_start, sizeof(sine_start));
}
#endif

static int VsDreqReady(void)
{
    return (Xil_In32(GPIO_SW_LED_BASEADDR + XGPIO_DATA_OFFSET) & VS_DREQ_GPIO_MASK) != 0U;
}

static void VsInitFadedMidiPlayer(void)
{
    int status;

    Xil_Out32(GPIO_SW_LED_BASEADDR + XGPIO_TRI_OFFSET, 0xFFFFU);
    Xil_Out32(GPIO_SW_LED_BASEADDR + XGPIO_TRI2_OFFSET, 0x0000U);

    VsGpioWrite(VS_GPIO_IDLE | VS_LED_INIT);

    status = VsSpiInit();
    if (status != XST_SUCCESS) {
        VsSetStatus(VS_LED_SPI_ERROR);
        while (1) {
        }
    }

    if (!VsWaitDreq(12000000U)) {
        VsSetStatus(VS_LED_DREQ_TIMEOUT);
    }

    VsSciWrite(VS_SCI_MODE, 0x0804U);
    VsSciWrite(VS_SCI_CLOCKF, 0x9800U);
    VsSciWrite(VS_SCI_DECODE_TIME, 0x0000U);
    VsSciWrite(VS_SCI_DECODE_TIME, 0x0000U);
    VsSciWrite(VS_SCI_AUDATA, 0xBB81U);
    VsApplyVolume();
    VsSetStatus(VS_LED_SCI_DONE | VS_LED_STREAMING | VS_LED_SCI_READ_OK);
    VsAudioPos = 0U;
    VsAudioArmed = 1U;
}

static void VsResetDecoderForNewMidi(void)
{
    if (!VsWaitDreq(1200000U)) {
        VsSetStatus(VS_LED_DREQ_TIMEOUT);
    }
    VsSciWrite(VS_SCI_MODE, 0x0804U);
    BusyDelay(200000U);
    if (!VsWaitDreq(1200000U)) {
        VsSetStatus(VS_LED_DREQ_TIMEOUT);
    }
    VsSciWrite(VS_SCI_CLOCKF, 0x9800U);
    VsSciWrite(VS_SCI_DECODE_TIME, 0x0000U);
    VsSciWrite(VS_SCI_DECODE_TIME, 0x0000U);
    VsSciWrite(VS_SCI_AUDATA, 0xBB81U);
    VsApplyVolume();
}

/* SW[1:0] selects the active MIDI payload.  Song code 3 is intentionally
 * treated as idle/black screen when both song switches are off.
 */
static void VsSelectSong(u8 song)
{
    if (song == 0U) {
        VsAudioData = Vs1003bCanonMidi;
        VsAudioLen = VS1003B_CANON_MIDI_LEN;
    } else if (song == 2U) {
        VsAudioData = Vs1003bAphasiaMidi;
        VsAudioLen = VS1003B_APHASIA_MIDI_LEN;
    } else {
        VsAudioData = Vs1003bFadedMidi;
        VsAudioLen = VS1003B_FADED_MIDI_LEN;
    }
}

static void VsRestartMidi(void)
{
    VsAudioPos = 0U;
    VsAudioArmed = 1U;
}

static void VsServiceFadedMidi(void)
{
    u32 remaining;

#if VS1003B_SINE_OUTPUT_TEST
    VsStartSineTest();
    while (1) {
        VsToggleStatus(VS_LED_LOOP);
        BusyDelay(8000000U);
    }
#else
    if (VsAudioArmed == 0U || !VsDreqReady()) {
        return;
    }
    if (VsAudioPos >= VsAudioLen) {
        VsAudioArmed = 0U;
        VsToggleStatus(VS_LED_LOOP);
        return;
    }
    remaining = VsAudioLen - VsAudioPos;
    if (remaining > 32U) {
        remaining = 32U;
    }
    VsSendMp3Chunk(&VsAudioData[VsAudioPos], remaining);
    VsAudioPos += remaining;
    VsSetStatus(VS_LED_DECODE_TICK);
#endif
}
#endif

#if USB_UART_AUDIO_TEST
static void BusyDelay(u32 cycles)
{
    volatile u32 i;
    for (i = 0; i < cycles; ++i) {
    }
}

static void UartSendByte(u8 data)
{
    XUartLite_SendByte(UART_AUDIO_BASEADDR, data);
}

static void UartSendText(const char *text)
{
    while (*text != '\0') {
        UartSendByte((u8)*text);
        ++text;
    }
}

static u8 TriangleSample(u32 phase, u8 amplitude)
{
    u8 ramp = (u8)(phase >> 24);
    u8 tri = (ramp < 128U) ? (u8)(ramp << 1) : (u8)(255U - ((ramp - 128U) << 1));
    s16 centered = (s16)tri - 128;
    centered = (centered * (s16)amplitude) >> 7;
    return (u8)(128 + centered);
}

static u32 NoteStep(u16 hz)
{
    return (u32)(((u64)hz << 32) / UART_AUDIO_SAMPLE_RATE);
}

static void RunUsbUartAudioTest(void)
{
    static const u16 notes_hz[] = {
        587, 740, 880, 1175, 880, 740, 587, 740,
        659, 880, 1109, 1319, 1109, 880, 659, 880,
        494, 587, 740, 988, 740, 587, 494, 587,
        440, 554, 740, 880, 740, 554, 440, 554
    };
    u32 phase = 0;
    u32 sample_count = 0;
    u32 note_index = 0;
    u32 samples_in_note = 0;
    u32 step = NoteStep(notes_hz[0]);
    const u32 samples_per_note = UART_AUDIO_SAMPLE_RATE / 4U;

    UartSendText("N4PCM8 800Hz unsigned mono, raw bytes after ENDHDR\r\nENDHDR\r\n");

    while (1) {
        u8 amp = 90U;
        u32 edge = samples_in_note;
        if (edge < 16U) {
            amp = (u8)(edge * 6U);
        } else if (edge > samples_per_note - 16U) {
            amp = (u8)((samples_per_note - edge) * 6U);
        }

        phase += step;
        UartSendByte(TriangleSample(phase, amp));

        ++sample_count;
        ++samples_in_note;
        if (samples_in_note >= samples_per_note) {
            samples_in_note = 0;
            note_index = (note_index + 1U) % (sizeof(notes_hz) / sizeof(notes_hz[0]));
            step = NoteStep(notes_hz[note_index]);
        }

        BusyDelay(7600U);
    }
}
#endif

typedef struct {
    u16 time_ms;
    u8 lane;
    u8 hold;
    u16 length_ms;
} Note;

#include "generated_charts.h"

static const u8 SegHex[16] = {
    0xC0, 0xF9, 0xA4, 0xB0, 0x99, 0x92, 0x82, 0xF8,
    0x80, 0x90, 0x88, 0x83, 0xC6, 0xA1, 0x86, 0x8E
};

static u8 Display[8] = {0xFF, 0xFF, 0xFF, 0xFF, 0xC0, 0xC0, 0xC0, 0xC0};
static u8 ScanDigit = 0;
static u8 GameState = GAME_WAIT;
static u8 LastRating = 0;
static u8 SongIndex = 3U;
static u16 LastSongSwitch = 0xFFFFU;
static u8 NextNote = 0;
static u8 ActiveHoldValid = 0;
static u8 ActiveHoldIndex = 0;
static u8 LastButtons = 0;
static u32 GameTimeMs = 0;
static u32 Score = 0;
static u16 Combo = 0;
static u16 MaxCombo = 0;
static u16 MbVgaRowMs = MB_VGA_ROW_MS;
static volatile u32 TimerTicksPending = 0U;
static volatile u8 ButtonPressedEvents = 0U;
static volatile u8 SwitchEventPending = 0U;
static volatile u8 CurrentButtons = 0U;

static const Note *CurrentSong(void)
{
    if (SongIndex == 2U) {
        return Song2;
    }
    if (SongIndex == 1U) {
        return Song1;
    }
    return Song0;
}

static u8 CurrentSongLen(void)
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

static u8 LaneButtonMask(u8 lane)
{
    if (lane == LANE_LEFT) {
        return BTN_L;
    }
    if (lane == LANE_RIGHT) {
        return BTN_R;
    }
    return BTN_C;
}

static void InitHardware(void)
{
    Xil_Out32(GPIO_SW_LED_BASEADDR + XGPIO_TRI_OFFSET, 0xFFFFU);
    Xil_Out32(GPIO_SW_LED_BASEADDR + XGPIO_TRI2_OFFSET, 0x0000U);
    Xil_Out32(GPIO_SW_LED_BASEADDR + XGPIO_DATA2_OFFSET, VS_GPIO_IDLE | VS_LED_INIT);
    Xil_Out32(GPIO_SEVENSEG_BASEADDR + XGPIO_TRI_OFFSET, 0x0000U);
    Xil_Out32(GPIO_SEVENSEG_BASEADDR + XGPIO_TRI2_OFFSET, 0x0000U);
    Xil_Out32(GPIO_SEVENSEG_BASEADDR + XGPIO_DATA_OFFSET, 0xFFU);
    Xil_Out32(GPIO_SEVENSEG_BASEADDR + XGPIO_DATA2_OFFSET, 0xFFU);
    Xil_Out32(GPIO_BUTTON_RGB_BASEADDR + XGPIO_TRI_OFFSET, 0x001FU);
    Xil_Out32(GPIO_BUTTON_RGB_BASEADDR + XGPIO_TRI2_OFFSET, 0x0000U);
    Xil_Out32(GPIO_BUTTON_RGB_BASEADDR + XGPIO_DATA2_OFFSET, 0x12U);
    CurrentButtons = (u8)(Xil_In32(GPIO_BUTTON_RGB_BASEADDR + XGPIO_DATA_OFFSET) & 0x1FU);
    LastButtons = CurrentButtons;

    Xil_Out32(TIMER_BASEADDR + XTC_TCSR_OFFSET, 0);
    Xil_Out32(TIMER_BASEADDR + XTC_TLR_OFFSET, TIMER_LOAD_VALUE);
    Xil_Out32(TIMER_BASEADDR + XTC_TCSR_OFFSET, XTC_CSR_LOAD_MASK);
    Xil_Out32(TIMER_BASEADDR + XTC_TCSR_OFFSET,
              XTC_CSR_ENABLE_TMR_MASK |
              XTC_CSR_ENABLE_INT_MASK |
              XTC_CSR_AUTO_RELOAD_MASK |
              XTC_CSR_DOWN_COUNT_MASK);
}

static void TimerInterruptHandler(void *CallbackRef)
{
    (void)CallbackRef;
    u32 status = Xil_In32(TIMER_BASEADDR + XTC_TCSR_OFFSET);
    if ((status & XTC_CSR_INT_OCCURED_MASK) != 0U) {
        Xil_Out32(TIMER_BASEADDR + XTC_TCSR_OFFSET, status | XTC_CSR_INT_OCCURED_MASK);
        ++TimerTicksPending;
    }
}

static void ButtonInterruptHandler(void *CallbackRef)
{
    u8 buttons;
    u8 pressed;

    (void)CallbackRef;
    Xil_Out32(GPIO_BUTTON_RGB_BASEADDR + XGPIO_ISR_OFFSET, XGPIO_IR_CH1_MASK);
    buttons = (u8)(Xil_In32(GPIO_BUTTON_RGB_BASEADDR + XGPIO_DATA_OFFSET) & 0x1FU);
    pressed = buttons & (u8)~LastButtons;
    LastButtons = buttons;
    CurrentButtons = buttons;
    ButtonPressedEvents |= pressed;
}

static void SwitchInterruptHandler(void *CallbackRef)
{
    (void)CallbackRef;
    Xil_Out32(GPIO_SW_LED_BASEADDR + XGPIO_ISR_OFFSET, XGPIO_IR_CH1_MASK);
    SwitchEventPending = 1U;
}

static void InitInterrupts(void)
{
    TimerTicksPending = 0U;
    ButtonPressedEvents = 0U;
    SwitchEventPending = 0U;
    Xil_Out32(TIMER_BASEADDR + XTC_TCSR_OFFSET,
              Xil_In32(TIMER_BASEADDR + XTC_TCSR_OFFSET) | XTC_CSR_INT_OCCURED_MASK);

    Xil_Out32(GPIO_BUTTON_RGB_BASEADDR + XGPIO_IER_OFFSET, XGPIO_IR_CH1_MASK);
    Xil_Out32(GPIO_BUTTON_RGB_BASEADDR + XGPIO_ISR_OFFSET, XGPIO_IR_CH1_MASK);
    Xil_Out32(GPIO_BUTTON_RGB_BASEADDR + XGPIO_GIE_OFFSET, XGPIO_GIE_GINTR_ENABLE_MASK);

    Xil_Out32(GPIO_SW_LED_BASEADDR + XGPIO_IER_OFFSET, XGPIO_IR_CH1_MASK);
    Xil_Out32(GPIO_SW_LED_BASEADDR + XGPIO_ISR_OFFSET, XGPIO_IR_CH1_MASK);
    Xil_Out32(GPIO_SW_LED_BASEADDR + XGPIO_GIE_OFFSET, XGPIO_GIE_GINTR_ENABLE_MASK);

    XIntc_RegisterHandler(INTC_BASEADDR,
                          XPAR_AXI_INTC_0_AXI_TIMER_0_INTERRUPT_INTR,
                          TimerInterruptHandler,
                          0);
    XIntc_RegisterHandler(INTC_BASEADDR,
                          XPAR_AXI_INTC_0_AXI_GPIO_2_IP2INTC_IRPT_INTR,
                          ButtonInterruptHandler,
                          0);
    XIntc_RegisterHandler(INTC_BASEADDR,
                          XPAR_AXI_INTC_0_AXI_GPIO_0_IP2INTC_IRPT_INTR,
                          SwitchInterruptHandler,
                          0);
    XIntc_EnableIntr(INTC_BASEADDR, INTC_ENABLE_MASK);
    XIntc_MasterEnable(INTC_BASEADDR);
    microblaze_register_handler((XInterruptHandler)XIntc_DeviceInterruptHandler,
                                (void *)XPAR_AXI_INTC_0_DEVICE_ID);
    microblaze_enable_interrupts();
}

static void SetRating(u8 rating)
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
#if VS1003B_MB_STREAM_TEST
    VsGpioWrite(VsGpioState);
#endif
}

static void UpdateScoreDisplay(void)
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

static void ScanSevenSeg(void)
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

static u16 MbVgaRowMsFromSwitch(u16 sw)
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

static void MbVgaSendFrame(u8 buttons)
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

static void StartGame(void)
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
#if VS1003B_MB_STREAM_TEST
        VsAudioArmed = 0U;
        VsSetMuted(1U);
        VsGpioWrite(VsGpioState);
#endif
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
#if VS1003B_MB_STREAM_TEST
    VsSelectSong(SongIndex);
    VsResetDecoderForNewMidi();
    VsRestartMidi();
    VsSetMuted((sw & SW_MUTE_MASK) != 0U);
#endif
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

static void JudgeLane(u8 lane)
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

static void UpdateMisses(void)
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

static void UpdateFeedback(u8 buttons)
{
#if !VS1003B_MB_STREAM_TEST
    u32 leds = 0;
    if (GameState == GAME_PLAY) {
        leds |= 0x0001U << (GameTimeMs / 125U % 16U);
    }
    leds |= ((u32)buttons & 0x1FU) << 8;
    leds |= ((u32)(Combo & 0x7U)) << 5;
    Xil_Out32(GPIO_SW_LED_BASEADDR + XGPIO_DATA2_OFFSET, leds);
#endif

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

static u8 PopTimerTick(void)
{
    u8 has_tick;
    microblaze_disable_interrupts();
    has_tick = (TimerTicksPending != 0U);
    if (has_tick) {
        --TimerTicksPending;
    }
    microblaze_enable_interrupts();
    return has_tick;
}

static u8 PopButtonEvents(void)
{
    u8 pressed;
    microblaze_disable_interrupts();
    pressed = ButtonPressedEvents;
    ButtonPressedEvents = 0U;
    microblaze_enable_interrupts();
    return pressed;
}

static u8 PopSwitchEvent(void)
{
    u8 pending;
    microblaze_disable_interrupts();
    pending = SwitchEventPending;
    SwitchEventPending = 0U;
    microblaze_enable_interrupts();
    return pending;
}

static void HandleButtonPresses(u8 pressed)
{
    if ((pressed & BTN_U) != 0U && (pressed & BTN_D) == 0U) {
#if VS1003B_MB_STREAM_TEST
        VsAdjustVolume(1);
#endif
    }
    if ((pressed & BTN_D) != 0U && (pressed & BTN_U) == 0U) {
#if VS1003B_MB_STREAM_TEST
        VsAdjustVolume(-1);
#endif
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

int main(void)
{
#if VS1003B_MB_STREAM_TEST
    u8 buttons;
    u8 pressed;
    u8 vga_frame_div = 0U;

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
#elif USB_UART_AUDIO_TEST
    RunUsbUartAudioTest();
    return 0;
#else
    u8 buttons;

    xil_printf("Nexys4 DDR three-lane rhythm game start\r\n");
    InitHardware();
    SetRating(' ');
    UpdateScoreDisplay();
    InitInterrupts();

    while (1) {
        u8 pressed = PopButtonEvents();
        if (pressed != 0U) {
            HandleButtonPresses(pressed);
        }
        if (PopTimerTick()) {
            ScanSevenSeg();
            buttons = CurrentButtons;
            if (GameState == GAME_PLAY) {
                u16 sw = (u16)Xil_In32(GPIO_SW_LED_BASEADDR + XGPIO_DATA_OFFSET);
                GameTimeMs += 1U + (sw & 0x0003U);
                UpdateMisses();
            }
            UpdateFeedback(buttons);
        }
    }
#endif
}
