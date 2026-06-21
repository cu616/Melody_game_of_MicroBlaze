/*
 * Shared declarations for the final MicroBlaze rhythm-game application.
 *
 * The submitted build has one active running path:
 * MicroBlaze owns game state and streams compact MIDI data to VS1003B; RTL
 * keeps VGA timing, cover ROM lookup, LEDs, RGB and seven-segment scanning.
 */
#ifndef RHYTHM_GAME_H
#define RHYTHM_GAME_H

#include "xparameters.h"
#include "xil_io.h"
#include "xil_types.h"
#include "xgpio_l.h"
#include "xstatus.h"
#include "xintc_l.h"
#include "xtmrctr_l.h"
#include "mb_interface.h"
#include "vs1003b_midi_assets.h"

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

typedef struct {
    u16 time_ms;
    u8 lane;
    u8 hold;
    u16 length_ms;
} Note;

extern u32 VsGpioState;
extern u32 VsAudioPos;
extern u8 VsAudioArmed;
extern u8 MbVgaStateCode;
extern u8 MbVgaSongCode;
extern u8 MbVgaRatingCode;
extern u8 MbVgaVolumeCode;
extern const u8 *VsAudioData;
extern u32 VsAudioLen;
extern u8 VsVolumeIndex;
extern u8 VsMuted;

extern u8 Display[8];
extern u8 ScanDigit;
extern u8 GameState;
extern u8 LastRating;
extern u8 SongIndex;
extern u16 LastSongSwitch;
extern u8 NextNote;
extern u8 ActiveHoldValid;
extern u8 ActiveHoldIndex;
extern u8 LastButtons;
extern u32 GameTimeMs;
extern u32 Score;
extern u16 Combo;
extern u16 MaxCombo;
extern u16 MbVgaRowMs;
extern volatile u32 TimerTicksPending;
extern volatile u8 ButtonPressedEvents;
extern volatile u8 SwitchEventPending;
extern volatile u8 CurrentButtons;

void BusyDelay(u32 cycles);
void VsGpioWrite(u32 value);
void VsSetStatus(u32 mask);
void VsToggleStatus(u32 mask);
void VsSetMuted(u8 muted);
void VsAdjustVolume(int delta);
void VsInitFadedMidiPlayer(void);
void VsResetDecoderForNewMidi(void);
void VsSelectSong(u8 song);
void VsRestartMidi(void);
void VsServiceFadedMidi(void);

const Note *CurrentSong(void);
u8 CurrentSongLen(void);
u8 LaneButtonMask(u8 lane);

void InitHardware(void);
void InitInterrupts(void);
u8 PopTimerTick(void);
u8 PopButtonEvents(void);
u8 PopSwitchEvent(void);

void SetRating(u8 rating);
void UpdateScoreDisplay(void);
void ScanSevenSeg(void);
u16 MbVgaRowMsFromSwitch(u16 sw);
void MbVgaSendFrame(u8 buttons);
void UpdateFeedback(u8 buttons);

void StartGame(void);
void JudgeLane(u8 lane);
void UpdateMisses(void);
void HandleButtonPresses(u8 pressed);

#endif
