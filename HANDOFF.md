# Mini_IO Project Handoff

This document is for the next assistant/agent taking over work in this project.

## Current Project Path

Use this path as the active project:

```text
F:\FPGA\mircoCom\Genneral\Mini_IO
```

The old path was:

```text
F:\FPGA\mircoCom\综合\Mini_IO
```

The old Chinese-path directory was not renamed in place because Windows returned
`Access to the path ... is denied`. The project was copied to the new ASCII path
instead. `Mini_IO.xpr` was updated so its project path points to:

```text
F:/FPGA/mircoCom/Genneral/Mini_IO/Mini_IO.xpr
```

The old `综合` directory may still exist. Prefer the `Genneral` copy for all
future work.

## Important Tooling Notes

Vivado version:

```text
D:\Xilinx\Vivado\2018.3\bin\vivado.bat
```

SDK / XSCT version:

```text
D:\Xilinx\SDK\2018.3\bin\xsct.bat
```

Manual SDK build tools:

```text
D:\Xilinx\SDK\2018.3\gnuwin\bin\make.exe
D:\Xilinx\SDK\2018.3\gnu\microblaze\nt\bin\mb-gcc.exe
```

Earlier, Vivado crashed when building under the Chinese path `综合`. Building
under `Genneral` now works directly, so the temporary ASCII mirror
`D:\vivado_ascii_build\Mini_IO` should no longer be needed.

## Build Commands

Run Vivado full synthesis/implementation/bitstream from the project root:

```powershell
cd F:\FPGA\mircoCom\Genneral\Mini_IO
& 'D:\Xilinx\Vivado\2018.3\bin\vivado.bat' -mode batch -source scripts\build_vivado.tcl
```

After build, the generated bitstream is:

```text
F:\FPGA\mircoCom\Genneral\Mini_IO\Mini_IO.runs\impl_1\design_mb_wrapper.bit
```

For SDK programming, copy it to:

```text
F:\FPGA\mircoCom\Genneral\Mini_IO\Mini_IO.sdk\design_mb_wrapper_hw_platform_0\download.bit
```

Manual copy command:

```powershell
Copy-Item -LiteralPath 'F:\FPGA\mircoCom\Genneral\Mini_IO\Mini_IO.runs\impl_1\design_mb_wrapper.bit' `
  -Destination 'F:\FPGA\mircoCom\Genneral\Mini_IO\Mini_IO.sdk\design_mb_wrapper_hw_platform_0\download.bit' -Force
```

Current latest bit at handoff:

```text
F:\FPGA\mircoCom\Genneral\Mini_IO\Mini_IO.sdk\design_mb_wrapper_hw_platform_0\download.bit
LastWriteTime: 2026-05-30 20:39:34
Size: 3825902 bytes
```

Current last Vivado timing result:

```text
VIVADO_BUILD_OK
WNS=1.378
TNS=0.000
WHS=0.031
THS=0.000
```

## Hardware/RTL Status

Main custom RTL:

```text
Mini_IO.srcs\sources_1\new\rhythm_video_audio.v
```

Top wrapper modified:

```text
Mini_IO.srcs\sources_1\bd\design_mb\hdl\design_mb_wrapper.v
```

Constraints modified:

```text
Mini_IO.srcs\constrs_1\new\adda.xdc
```

The design instantiates `rhythm_video_audio` in the wrapper. It drives:

- VGA test output
- diagnostic LEDs/seven-seg/RGB
- J8 mono audio output through `AUD_PWM` and `AUD_SD`

The MicroBlaze GPIO outputs for LEDs/seven-seg/RGB were routed to unused `mb_*`
wires so the hardware self-test can drive them directly.

Reset polarity was fixed in the RTL:

```verilog
wire reset_active = ~reset;
```

Do not undo this unless the block design reset polarity is changed.

## VGA / Display Notes

The Nexys4DDR board has VGA, not HDMI. The user's HDMI/miniHDMI monitor cannot
be driven by passive VGA-to-HDMI cabling. VGA-to-HDMI and HDMI-to-VGA adapters
are directional and need active conversion. For HDMI display, use either:

- active powered VGA input to HDMI output converter, or
- a real VGA monitor, or
- a future HDMI/TMDS/Pmod HDMI design.

The current VGA hardware test still exists in `rhythm_video_audio.v`, but the
user's display chain may not show anything unless conversion is correct.

## J8 Audio Status

The current audio engine intentionally reverted away from the noisy PDM attempt.

Current stable audio method:

- J8 mono audio output
- 10-bit PWM sample
- 50 kHz audio sample update
- 64-point sine lookup table
- open-drain style output for `AUD_PWM`

Current output line:

```verilog
assign aud_pwm = (pwm_count < audio_sample) ? 1'bz : 1'b0;
```

This follows the Nexys4DDR reference manual's requirement that `AUD_PWM` be
driven open-drain/open-collector style, with the board's analog circuit pulling
the line up and low-pass filtering the PWM/PDM signal.

Previous experiment, now reverted:

- 100 MHz first-order sigma-delta/PDM
- 12-bit target sample
- 128-phase sine table
- attack/release envelope

The user reported this version had too much noise and mechanical sound. Do not
restore it unless explicitly requested.

## Current Music

The current RTL melody is a Gigue-style 12/8 section, not a faithful note-for-
note transcription.

Timing:

- `music_slot = music_ms / 150`
- 12 short notes per bar
- 8 bars
- total loop about 14.4 seconds

Harmony/bass progression:

```text
D -> A -> Bm -> F#m -> G -> D -> G -> A
```

The melody is generated in `melody_phase_step()` using D-major arpeggio-like
patterns. It is a simplified Gigue-feel test, not a real MIDI/score import.

## Audio Hardware Reality

J8 audio is useful for simple sound but not high fidelity. It is mono and based
on filtered FPGA digital output. For recognisable real music, better future
routes are:

1. External I2S DAC or Pmod audio DAC.
2. PCM/WAV sample playback from BRAM/DDR/SD through an external DAC.
3. HDMI audio only if a real HDMI/TMDS output design is added.

USB audio direct to the user's Type-C monitor is not feasible with the existing
Nexys4DDR USB port. The board's USB is JTAG/UART, not USB Audio Class.

## SDK Project Status

Relevant SDK app:

```text
Mini_IO.sdk\SeriesIODacSaw
```

Source:

```text
Mini_IO.sdk\SeriesIODacSaw\src\rhythm_game.c
```

Current ELF:

```text
Mini_IO.sdk\SeriesIODacSaw\Debug\SeriesIODacSaw.elf
LastWriteTime: 2026-05-30 20:56:12
```

Important: `rhythm_game.c` is currently in USB-UART PCM experiment mode:

```c
#define USB_UART_AUDIO_TEST      1
```

When this macro is `1`, the original rhythm game loop is bypassed and the app
sends a raw low-rate PCM stream through STDOUT UART.

To restore the original software rhythm game behavior, set:

```c
#define USB_UART_AUDIO_TEST      0
```

and rebuild the ELF.

## USB-UART PCM Experiment

This experiment does not make the board a USB sound card. It only sends bytes
over the board's USB-UART link to a PC.

UART settings from BSP:

```text
STDOUT_BASEADDRESS = 0x40600000
AXI_UARTLITE_0_BAUDRATE = 9600
```

Because the baud rate is only 9600, the stream is intentionally very low rate:

```text
800 Hz, 8-bit, mono PCM
```

PC receive script:

```text
scripts\capture_uart_pcm.ps1
```

Usage example:

```powershell
cd F:\FPGA\mircoCom\Genneral\Mini_IO
powershell -ExecutionPolicy Bypass -File scripts\capture_uart_pcm.ps1 -PortName COM5 -Seconds 10
```

Replace `COM5` with the actual Nexys4DDR COM port shown in Device Manager.
The script waits for `ENDHDR`, captures raw PCM bytes, writes
`uart_pcm_capture.wav`, and opens it.

## Manual SDK Build

`xsct scripts\build_sdk.tcl` reported `Workspace already in use` during this
session, likely because SDK/Eclipse metadata was locked. The ELF was built
successfully with the generated makefile instead:

```powershell
cd F:\FPGA\mircoCom\Genneral\Mini_IO\Mini_IO.sdk\SeriesIODacSaw\Debug
$env:Path='D:\Xilinx\SDK\2018.3\gnu\microblaze\nt\bin;D:\Xilinx\SDK\2018.3\gnuwin\bin;' + $env:Path
& 'D:\Xilinx\SDK\2018.3\gnuwin\bin\make.exe' clean
& 'D:\Xilinx\SDK\2018.3\gnuwin\bin\make.exe' all
```

Expected warnings when `USB_UART_AUDIO_TEST == 1`:

- `HandleButtons` unused
- `UpdateFeedback` unused
- other original game functions unused

These warnings are expected because experiment mode bypasses the original game.

## User Preferences / Recent Decisions

- User wants practical hardware tests first.
- User hears PDM version as noisy/mechanical, so keep stable PWM unless asked.
- User is experimenting with J8 earphone output and USB-UART audio data.
- User asked to move away from Chinese path; use `Genneral`.
- User spelled the target folder as `Genneral`, not `General`; preserve that
  exact spelling.

## Files Added/Changed Recently

Important added file:

```text
HANDOFF.md
scripts\capture_uart_pcm.ps1
```

Important modified files:

```text
Mini_IO.xpr
Mini_IO.srcs\sources_1\new\rhythm_video_audio.v
Mini_IO.srcs\sources_1\bd\design_mb\hdl\design_mb_wrapper.v
Mini_IO.srcs\constrs_1\new\adda.xdc
Mini_IO.sdk\SeriesIODacSaw\src\rhythm_game.c
```

Generated artifacts:

```text
Mini_IO.runs\impl_1\design_mb_wrapper.bit
Mini_IO.sdk\design_mb_wrapper_hw_platform_0\download.bit
Mini_IO.sdk\SeriesIODacSaw\Debug\SeriesIODacSaw.elf
```

Avoid treating generated Vivado run files and SDK metadata as hand-authored
source unless you specifically need them.

