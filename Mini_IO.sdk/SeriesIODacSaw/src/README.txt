Main SDK application for the Nexys4 DDR three-lane rhythm game and VS1003B
MicroBlaze audio player.

Keep this project plus HelloWorld_bsp and design_mb_wrapper_hw_platform_0 in
the SDK workspace. The old classroom examples were removed from the workspace
tree so this app is the single software entry point.

Current VS1003B mode:
SW2 = hand VS1003B pins to MicroBlaze and start the software player.
Keep SW2=1 before reset/download, or turn SW2 on and then reset the board.

The MicroBlaze player bit-bangs VS1003B through GPIO0 channel 2:
bit0 XCS, bit1 XDCS, bit2 XRST, bit3 MOSI, bit4 SCLK.
GPIO0 channel 1 exposes VS1003B feedback while in this mode:
bit15 DREQ, bit14 MISO, bits13..0 board switches.

The current built-in audio data is vs1003b_midi_assets.h. It contains compact
Canon, Faded, and Aphasia MIDI byte streams for VS1003B. Faded is clipped from
music/midi_import/faded_perfect.mid, requested source time 0:50-1:50 aligned
outward to complete 4/4 bars as source beats 72-168, about 0:48-1:52 at the
file's own 90 BPM, then merged to MIDI Type 0. Canon uses a
bar-aligned original-MIDI range, beats 72-92. Aphasia is clipped from the
user-provided music/midi_import/Aphasia.mid as a larger phrase, source beats
64-128, exported at 128 BPM as MIDI Type 0. Aphasia's two original piano
layers are remapped to separate VS1003B channels/instruments; the second layer
uses a lead tone with an expression ramp so the entrance is more distinguishable.
The three songs have been loudness-balanced inside the MIDI streams by changing
only note velocity and MIDI CC7/CC11 volume/expression values. Pitch, note
timing, clip range, and melody events are intentionally unchanged.
MP3 frame clips are kept only as historical VS1003B smoke-test material and are
not the active playback source in this build.

In SW2=1 mode the same MicroBlaze program also owns the basic game controls.
SW1:SW0 selects songs: 00 defaults to Faded, 01 selects Canon, 10 selects Faded,
and 11 selects Aphasia. Changing SW1:SW0 restarts the selected chart and MIDI
byte stream. SW13 pauses/resumes the music stream and chart timer together.
BTNU/BTND click up/down through 16 VS1003B volume attenuation steps from very
quiet to maximum. BTNL/BTNC/BTNR are left/center/right lanes. Seven-seg
score/rating and RGB feedback are driven by MicroBlaze through AXI GPIO in this
mode.

Button map for rhythm-game mode:
BTNL = left lane, BTNC = middle lane, BTNR = right lane
BTNU = volume up, BTND = volume down
SW13 = pause/resume music and chart

Legacy rhythm-game switch map:
SW0-SW1 = speed, SW2 = song select, SW4 = audio enable, SW5 = VGA demo assist
