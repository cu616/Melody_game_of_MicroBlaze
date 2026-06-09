#!/usr/bin/env python3
"""Generate playable MicroBlaze charts from the same MIDI files VS1003B plays.

The chart time is the judgement time in game milliseconds. The music stream
starts after AUDIO_START_DELAY_MS, so every MIDI event time gets that offset.
"""

from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
import make_single_track_midi_assets as midi_tools  # noqa: E402

AUDIO_START_DELAY_MS = 2200

CHARTS = [
    {
        "path": ROOT / "music" / "midi" / "canon_main_melody.mid",
        "out": ROOT / "charts" / "canon.mbchart",
        "title": "Canon in D main melody",
        "bpm": 36,
        "channels": {0},
        "min_gap_ms": 450,
        "max_notes": 38,
        "double_count": 4,
    },
    {
        "path": ROOT / "music" / "midi" / "faded_main_melody.mid",
        "out": ROOT / "charts" / "faded.mbchart",
        "title": "Faded main lead",
        "bpm": 90,
        "channels": {1},
        "min_gap_ms": 250,
        "max_notes": 58,
        "double_count": 5,
    },
    {
        "path": ROOT / "music" / "midi" / "aphasia_main_33s_56s.mid",
        "out": ROOT / "charts" / "aphasia.mbchart",
        "title": "Aphasia high lead",
        "bpm": 128,
        "channels": {0},
        "min_gap_ms": 250,
        "max_notes": 53,
        "double_count": 4,
    },
]


def build_tempo_map(tracks):
    events = []
    for track in tracks:
        for tick, kind, tag, payload in midi_tools.parse_track_events(track):
            if kind == "meta" and tag == 0x51:
                events.append((tick, int.from_bytes(payload, "big")))
    events.sort()
    if not events or events[0][0] != 0:
        events.insert(0, (0, 500000))
    return events


def tick_to_ms(tick, division, tempo_map):
    elapsed_us = 0
    prev_tick, tempo = tempo_map[0]
    for next_tick, next_tempo in tempo_map[1:]:
        if tick < next_tick:
            return (elapsed_us + (tick - prev_tick) * tempo / division) / 1000.0
        elapsed_us += (next_tick - prev_tick) * tempo / division
        prev_tick, tempo = next_tick, next_tempo
    return (elapsed_us + (tick - prev_tick) * tempo / division) / 1000.0


def extract_notes(path: Path, channels: set[int]):
    _fmt, division, tracks = midi_tools.parse_midi_tracks(path)
    tempo_map = build_tempo_map(tracks)
    active = {}
    notes = []
    for track in tracks:
        for tick, kind, tag, payload in midi_tools.parse_track_events(track):
            if kind != "midi":
                continue
            command = tag & 0xF0
            channel = tag & 0x0F
            if channel not in channels:
                continue
            if command == 0x90 and payload[1] > 0:
                active[(channel, payload[0])] = tick
            elif command in (0x80, 0x90):
                start_tick = active.pop((channel, payload[0]), None)
                if start_tick is not None:
                    start_ms = tick_to_ms(start_tick, division, tempo_map)
                    end_ms = tick_to_ms(tick, division, tempo_map)
                    notes.append(
                        {
                            "time_ms": int(round(AUDIO_START_DELAY_MS + start_ms)),
                            "length_ms": max(0, int(round(end_ms - start_ms))),
                            "pitch": payload[0],
                            "channel": channel,
                        }
                    )
    notes.sort(key=lambda item: (item["time_ms"], -item["pitch"]))
    return notes


def pick_main_onsets(notes, min_gap_ms: int, max_notes: int):
    picked = []
    last_time = -999999
    index = 0
    while index < len(notes):
        now = notes[index]["time_ms"]
        chord = []
        while index < len(notes) and abs(notes[index]["time_ms"] - now) <= 12:
            chord.append(notes[index])
            index += 1
        note = max(chord, key=lambda item: item["pitch"])
        if note["time_ms"] - last_time >= min_gap_ms:
            picked.append(note)
            last_time = note["time_ms"]
    if len(picked) > max_notes:
        if max_notes <= 1:
            return picked[:max_notes]
        sampled = []
        last_src = len(picked) - 1
        last_dst = max_notes - 1
        for dst in range(max_notes):
            sampled.append(picked[(dst * last_src + last_dst // 2) // last_dst])
        picked = sampled
    return picked


def assign_lanes(notes):
    pitches = [item["pitch"] for item in notes]
    lo = min(pitches)
    hi = max(pitches)
    span = max(1, hi - lo)
    counts = [0, 0, 0]
    lanes = []
    for index, item in enumerate(notes):
        preferred = min(2, max(0, (item["pitch"] - lo) * 3 // (span + 1)))
        previous = lanes[-1] if lanes else -1
        previous2 = lanes[-2] if len(lanes) >= 2 else -1

        def lane_cost(lane):
            return (
                counts[lane] * 6
                + abs(lane - preferred) * 2
                + (10 if lane == previous else 0)
                + (4 if lane == previous2 else 0)
                + ((index + lane) % 3)
            )

        selected = min(range(3), key=lane_cost)
        lanes.append(selected)
        counts[selected] += 1
    return lanes


def pick_double_indices(note_count: int, double_count: int):
    if double_count <= 0 or note_count < 8:
        return set()
    start = int(note_count * 0.62)
    end = max(start, note_count - 3)
    span = max(1, end - start)
    return {
        min(end, start + round(i * span / max(1, double_count - 1)))
        for i in range(double_count)
    }


def add_gameplay_events(notes, lanes, double_count):
    counts = [lanes.count(0), lanes.count(1), lanes.count(2)]
    double_indices = pick_double_indices(len(notes), double_count)
    events = []
    for index, (note, lane) in enumerate(zip(notes, lanes)):
        is_double = index in double_indices
        hold_ms = 0
        if not is_double and note["length_ms"] >= 800:
            hold_ms = min(note["length_ms"], 1800)
        events.append((note["time_ms"], lane, hold_ms))

        if is_double:
            choices = [candidate for candidate in range(3) if candidate != lane]
            extra = min(
                choices,
                key=lambda candidate: (
                    counts[candidate],
                    abs(candidate - lane),
                    (index + candidate) % 3,
                ),
            )
            counts[extra] += 1
            events.append((note["time_ms"], extra, 0))

    events.sort(key=lambda event: (event[0], event[1]))
    return events


def write_chart(cfg):
    source_notes = [
        note
        for note in extract_notes(cfg["path"], cfg["channels"])
        if note["time_ms"] <= 65535
    ]
    notes = pick_main_onsets(
        source_notes,
        min_gap_ms=cfg["min_gap_ms"],
        max_notes=cfg["max_notes"],
    )
    lanes = assign_lanes(notes)
    events = add_gameplay_events(notes, lanes, cfg["double_count"])
    lines = [
        f"# MicroBlaze rhythm chart: {cfg['title']}",
        "# Generated from the same MIDI file used by VS1003B playback.",
        "# Time values are judgement times in game milliseconds.",
        "# Onsets follow the main melody; lanes are gameplay-balanced L/C/R.",
        "# Climax notes may add a simultaneous second lane; long notes may become holds.",
        f"# Source: {cfg['path'].relative_to(ROOT).as_posix()}",
        f"# Channels: {', '.join(str(ch) for ch in sorted(cfg['channels']))}",
        f"# Filter: min_gap_ms={cfg['min_gap_ms']}, base_notes={cfg['max_notes']}, "
        f"doubles={cfg['double_count']}",
        "",
        f"@offset_ms {AUDIO_START_DELAY_MS}",
        f"@bpm {cfg['bpm']}",
        "@beats_per_bar 4",
        "",
    ]
    lane_names = ("L", "C", "R")
    for time_ms, lane, hold_ms in events:
        if hold_ms > 0:
            lines.append(f"{time_ms}ms {lane_names[lane]} hold {hold_ms}ms")
        else:
            lines.append(f"{time_ms}ms {lane_names[lane]}")
    cfg["out"].write_text("\n".join(lines) + "\n", encoding="utf-8")
    lane_totals = [sum(1 for event in events if event[1] == lane) for lane in range(3)]
    print(
        f"{cfg['out'].name}: {len(events)} notes "
        f"(L/C/R={lane_totals[0]}/{lane_totals[1]}/{lane_totals[2]}) "
        f"from {cfg['path'].name}"
    )


def main():
    for cfg in CHARTS:
        write_chart(cfg)


if __name__ == "__main__":
    main()
