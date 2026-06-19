# Rhythm Chart Text Format

## MicroBlaze charts

Current playable charts are edited in:

- `canon.mbchart`
- `faded.mbchart`
- `aphasia.mbchart`

Current on-screen switch mapping:

- `SW1..SW0`: song select, `01=Canon`, `10=Faded`, `11=Aphasia`, `00=idle/black`.
- `SW5..SW3`: visual scroll speed, shown as `SW3-5` on VGA.
- `SW2`: mute only. Music streaming and chart timing continue while muted.
- `SW15`: pause/resume both VS1003B music and chart timing.
- `BTNL/BTNC/BTNR`: left/center/right lanes, mapped to `P17/N17/M17`.
- `BTNU/BTND`: volume up/down, shown as `U-D Vol`.

`SW13` and `SW14` are not player controls in the main MicroBlaze path. Their
GPIO input slots carry VS1003B MISO and DREQ so that physical `SW15` remains
available as the unified pause switch.

Then regenerate the SDK header and rebuild/download the ELF:

```powershell
python scripts\generate_mb_charts_from_midi.py
python scripts\generate_mb_charts.py
```

`generate_mb_charts_from_midi.py` rebuilds the text charts from the same MIDI
files used by VS1003B playback. It extracts selected main-melody channels,
keeps one highest note for near-simultaneous chords, applies a per-song minimum
gap for playability, and maps pitch height to lanes:

- low pitch = `L`
- middle pitch = `C`
- high pitch = `R`

The current demo charts intentionally use a lower density than the source MIDI.
The generator samples across the whole selected MIDI phrase instead of stopping
when `max_notes` is reached, so the chart duration stays aligned with the song:

- Canon: `min_gap_ms=1000`, `max_notes=28`
- Faded: `min_gap_ms=600`, `max_notes=42`
- Aphasia: `min_gap_ms=440`, `max_notes=38`

If you want to hand-tune the chart after MIDI extraction, edit the `.mbchart`
file directly, then run only `generate_mb_charts.py`.

Each non-comment line is one note. The first column can be absolute
milliseconds, milliseconds with an `ms` suffix, absolute beats with a `b`
suffix, or `bar:beat`:

```text
time_ms lane [hold length_ms]
bar:beat lane [hold beat_duration]
```

Examples:

```text
1200 L
2200ms C
8b R
4:2 C
7868 L hold 1200
6:0 R hold 2b
```

Columns:

- `time`: note head time after song/game start.
- `lane`: `L`, `C`, or `R`.
- `hold length`: optional long note body length, in milliseconds or beats.

Timing model:

- `.mbchart` stores the judgement time, not the spawn time.
- VS1003B music starts after `AUDIO_START_DELAY_MS = 2200 ms`.
- MicroBlaze computes the visible row as:

```text
row = MB_VGA_JUDGE_ROW - round((note_time_ms - GameTimeMs) / row_ms)
```

- Current judgement row is `27`.
- `row_ms` comes from speed switches `SW5..SW3`:

```text
000 = 53 ms/row  (0.75x)
001 = 40 ms/row  (1.00x)
010 = 32 ms/row  (1.25x)
011 = 27 ms/row  (1.50x)
100 = 23 ms/row  (1.75x)
101 = 20 ms/row  (2.00x)
110 = 16 ms/row  (2.50x)
111 = 13 ms/row  (3.00x)
```

The judgement windows are independent from scroll speed. Changing `SW5..SW3`
only changes how early notes appear and how fast they fall.

Optional directives at the top of a chart:

```text
@offset_ms 2200
@bpm 128
@beats_per_bar 4
```

For `bar:beat`, bars are zero-based and beats are zero-based. For example,
`4:2` means bar 4, beat 2. The generated time is:

```text
offset_ms + (bar * beats_per_bar + beat) * 60000 / bpm
```

Lane mapping:

- `L` = left lane = P17 / BTNL.
- `C` = center lane = N17 / BTNC.
- `R` = right lane = M17 / BTNR.

This path only changes the MicroBlaze ELF, so chart timing/density can be tuned without regenerating the Vivado bitstream.

## Removed Legacy RTL Charts

The older RTL chart flow (`canon_demo.chart`, `fade_demo.chart`,
`rhythm_charts.vh`, and `scripts/generate_charts.ps1`) was removed after the
final MicroBlaze path was backed up.  Final chart editing should use only the
`.mbchart` files and the MicroBlaze header generator above.
