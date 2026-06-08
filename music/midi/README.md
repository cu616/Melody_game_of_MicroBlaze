# Compact MIDI assets

These files are generated for VS1003B playback using the same idea as the VGA_hw reference project:
Standard MIDI bytes are packed into 32-bit hex COE words for ROM initialization.

Generated MIDI note numbers include a `-1` semitone compensation for the current VS1003B module, because board testing found the raw output about one semitone sharp.

2026-06-08 loudness balance: the three song MIDI files were adjusted only with
note-on velocity and MIDI CC7/CC11 volume/expression controller values. Melody
notes, note timing, BPM, and clip boundaries were not changed.

| asset | midi bytes | 32-bit words | role |
| --- | ---: | ---: | --- |
| `faded_main_melody` | 13585 | 3397 | default selected VS1003B demo |
| `canon_main_melody` | 1008 | 252 | backup |
| `vs1003_pitch_calibration` | 162 | 41 | backup |
| `aphasia_main_33s_56s` | 2790 | 698 | backup |

The default selected file is `faded_main_melody`, because it is short, recognizable, and much smaller than an embedded MP3 clip.
