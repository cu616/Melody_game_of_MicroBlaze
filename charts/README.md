# Rhythm Chart Text Format

Edit `canon_demo.chart` or `fade_demo.chart`, then regenerate the Verilog include:

```powershell
pwsh scripts\generate_charts.ps1
```

Each non-comment line is one chart step:

```text
0 L
1 .
2 C
3 .
4 R
```

Columns:

- First column: step index, `0` to `63`.
- Second column: lanes, using `L`, `C`, `R`; use `.` or `-` for rest.
- Optional third column: hold lane and hold length, written as `lane:length`, for example `C:24`.
- Chords are allowed, for example `LC`, `CR`, `LCR`.

Examples:

```text
12 C C:24   # tap C, and start a 24-row center hold
28 . R:18   # no tap, start an 18-row right hold
```

Lane mapping:

- `L` = left lane = P17 / BTNL.
- `C` = center lane = N17 / BTNC.
- `R` = right lane = M17 / BTNR.

The FPGA currently spawns one chart step every 12 scroll ticks, so the demo density is about one quarter of the previous hard-coded chart.
