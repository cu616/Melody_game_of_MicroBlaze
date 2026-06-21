/* VS1003B MIDI playback backend.
 *
 * This file owns the bit-banged VS1003B transport over GPIO0 channel 2:
 * SCI register writes, SDI byte streaming, DREQ polling, mute and volume.
 */
#include "rhythm_game.h"

/* Shared state exposed to the RTL display bridge through GPIO0 channel 2.
 * Low bits drive the VS1003B bus; high bits encode song/state/judge/volume
 * so the VGA and seven-segment logic can render the same software state.
 */
u32 VsGpioState = VS_GPIO_IDLE;
u32 VsAudioPos = 0U;
u8 VsAudioArmed = 0U;
u8 MbVgaStateCode = MB_VGA_STATE_WAIT;
u8 MbVgaSongCode = 3U;
u8 MbVgaRatingCode = MB_VGA_RATING_NONE;
u8 MbVgaVolumeCode = 13U;
const u8 *VsAudioData = Vs1003bFadedMidi;
u32 VsAudioLen = VS1003B_FADED_MIDI_LEN;
static const u8 VsVolumeTable[] = {
    0xFEU, 0xD8U, 0xB8U, 0x98U, 0x78U, 0x60U, 0x48U, 0x34U,
    0x24U, 0x18U, 0x10U, 0x0CU, 0x08U, 0x05U, 0x02U, 0x00U
};
u8 VsVolumeIndex = 13U;
u8 VsMuted = 0U;

void BusyDelay(u32 cycles)
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

void VsGpioWrite(u32 value)
{
    VsGpioState = (value & VS_GPIO_BUS_MASK) | MbVgaStatusBits();
    Xil_Out32(GPIO_SW_LED_BASEADDR + XGPIO_DATA2_OFFSET, VsGpioState);
}

void VsSetStatus(u32 mask)
{
    VsGpioWrite(VsGpioState | mask);
}

void VsToggleStatus(u32 mask)
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

void VsSetMuted(u8 muted)
{
    muted = muted ? 1U : 0U;
    if (muted != VsMuted) {
        VsMuted = muted;
        VsApplyVolume();
    }
}

void VsAdjustVolume(int delta)
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

static int VsDreqReady(void)
{
    return (Xil_In32(GPIO_SW_LED_BASEADDR + XGPIO_DATA_OFFSET) & VS_DREQ_GPIO_MASK) != 0U;
}

void VsInitFadedMidiPlayer(void)
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

void VsResetDecoderForNewMidi(void)
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
void VsSelectSong(u8 song)
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

void VsRestartMidi(void)
{
    VsAudioPos = 0U;
    VsAudioArmed = 1U;
}

void VsServiceFadedMidi(void)
{
    u32 remaining;

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
}
