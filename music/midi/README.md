# Single-track MIDI assets

These files are generated for VS1003B playback using the same idea as the VGA_hw reference project:
single-track Standard MIDI bytes are packed into 32-bit hex COE words for ROM initialization.

Generated MIDI note numbers include a `-1` semitone compensation for the current VS1003B module, because board testing found the raw output about one semitone sharp.

| asset | midi bytes | 32-bit words | role |
| --- | ---: | ---: | --- |
| `faded_main_melody` | 740 | 185 | default selected VS1003B demo |
| `canon_main_melody` | 345 | 87 | backup |
| `vs1003_pitch_calibration` | 162 | 41 | backup |

The default selected file is `faded_main_melody`, because it is short, recognizable, and much smaller than an embedded MP3 clip.
