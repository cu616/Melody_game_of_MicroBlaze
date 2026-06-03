from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "music" / "midi"
OUT.mkdir(parents=True, exist_ok=True)

TPQ = 480

# The user's VS1003B module currently sounds about one semitone sharp when
# playing the generated MIDI files, so generated note numbers are compensated
# down by one semitone while tables keep the intended audible pitch names.
VS1003_OUTPUT_TRANSPOSE_SEMITONES = -1


def vlq(value):
    parts = [value & 0x7F]
    value >>= 7
    while value:
        parts.insert(0, 0x80 | (value & 0x7F))
        value >>= 7
    return bytes(parts)


def meta(delta, kind, data):
    return vlq(delta) + bytes([0xFF, kind, len(data)]) + data


def midi_event(delta, status, data1, data2):
    return vlq(delta) + bytes([status, data1, data2])


def note_name_to_midi(name):
    pitch_names = {
        "C": 0,
        "C#": 1,
        "Db": 1,
        "D": 2,
        "D#": 3,
        "Eb": 3,
        "E": 4,
        "F": 5,
        "F#": 6,
        "Gb": 6,
        "G": 7,
        "G#": 8,
        "Ab": 8,
        "A": 9,
        "A#": 10,
        "Bb": 10,
        "B": 11,
    }
    if len(name) >= 2 and name[1] in "#b":
        key, octv = name[:2], int(name[2:])
    else:
        key, octv = name[:1], int(name[1:])
    return (octv + 1) * 12 + pitch_names[key]


def build_midi(path, title, bpm, notes, program=80):
    track = bytearray()
    tempo = int(60_000_000 / bpm)
    track += meta(0, 0x03, title.encode("ascii", errors="ignore"))
    track += meta(0, 0x51, tempo.to_bytes(3, "big"))
    track += meta(0, 0x58, bytes([4, 2, 24, 8]))
    track += midi_event(0, 0xC0, program, 0)[:-1]
    pending_delta = 0
    for note, beats, velocity in notes:
        dur = int(TPQ * beats)
        if note is None:
            pending_delta += dur
            continue
        pitch = note_name_to_midi(note) + VS1003_OUTPUT_TRANSPOSE_SEMITONES
        if pitch < 0 or pitch > 127:
            raise ValueError(f"{note}: transposed MIDI pitch {pitch} is out of range")
        track += midi_event(pending_delta, 0x90, pitch, velocity)
        track += midi_event(dur, 0x80, pitch, 0)
        pending_delta = 0
    track += meta(pending_delta, 0x2F, b"")

    data = bytearray()
    data += b"MThd"
    data += (6).to_bytes(4, "big")
    data += (0).to_bytes(2, "big")
    data += (1).to_bytes(2, "big")
    data += TPQ.to_bytes(2, "big")
    data += b"MTrk"
    data += len(track).to_bytes(4, "big")
    data += track
    path.write_bytes(data)
    return data


def write_mem(path, data):
    with path.open("w", encoding="ascii", newline="\n") as f:
        for b in data:
            f.write(f"{b:02X}\n")


def write_padded_mem(path, data, size=1024):
    if len(data) > size:
        raise ValueError(f"{path.name}: {len(data)} bytes exceeds {size} byte ROM")
    write_mem(path, data + bytes(size - len(data)))


def write_coe(path, data):
    padded = data + bytes((-len(data)) % 4)
    words = [
        int.from_bytes(padded[i : i + 4], "big")
        for i in range(0, len(padded), 4)
    ]
    with path.open("w", encoding="ascii", newline="\n") as f:
        f.write("memory_initialization_radix=16;\n")
        f.write("memory_initialization_vector=\n")
        for i, word in enumerate(words):
            sep = ";" if i == len(words) - 1 else ","
            f.write(f"{word:08X}{sep}\n")


def write_vh(path, stem, data):
    path.write_text(
        "\n".join(
            [
                "// Generated single-track MIDI asset for VS1003B.",
                f"localparam integer {stem.upper()}_MIDI_LEN = {len(data)};",
                "",
            ]
        ),
        encoding="ascii",
    )


def write_note_table(path, title, bpm, notes):
    lines = [
        f"# {title}",
        "",
        f"BPM: {bpm}",
        "",
        "| index | note | beats | velocity |",
        "| ---: | --- | ---: | ---: |",
    ]
    for i, (note, beats, velocity) in enumerate(notes, 1):
        lines.append(f"| {i} | {note or 'REST'} | {beats:g} | {velocity} |")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_pitch_scale_table(path, scale_notes):
    lines = [
        "# VS1003B C major pitch test",
        "",
        "Calibration mode plays this C major scale continuously when `SW14=1` and `SW2=1`.",
        "",
        "| step | note | expected frequency |",
        "| ---: | --- | ---: |",
    ]
    for idx, (note, freq) in enumerate(scale_notes, 1):
        lines.append(f"| {idx} | `{note}` | `{freq:.2f} Hz` |")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def q(seq, velocity=120):
    return [(n, 1.0, velocity) for n in seq]


def main():
    # Alan Walker - Faded: classroom single-line lead. The user's numbered
    # notation was in A minor for easy keyboard fingering; this version is
    # transposed down a minor third to F# minor, closer to the familiar record.
    faded_phrase_a = q(
        [
            "F#4",
            "F#4",
            "E4",
            "F#4",
            "A4",
            "A4",
            "G#4",
            "A4",
            "F#4",
            "F#4",
            "E4",
            "F#4",
            "C#5",
            "C#5",
            "B4",
            "C#5",
        ],
        124,
    )
    faded_phrase_b = q(
        [
            "F#4",
            "E4",
            "C#4",
            "B3",
            "A3",
            "G#3",
            "A3",
            "B3",
        ],
        122,
    ) + [("C#4", 4.0, 122)]
    faded_phrase_c = q(
        [
            "C#4",
            "B3",
            "A3",
            "G#3",
            "F#3",
            "E3",
            "F#3",
            "G#3",
        ],
        122,
    ) + [("A3", 4.0, 122)]
    faded_phrase_d = q(
        [
            "F#4",
            "E4",
            "C#4",
            "B3",
            "A3",
            "G#3",
            "A3",
            "B3",
            "C#4",
            "B3",
            "A3",
            "G#3",
            "F#3",
            "E3",
            "F#3",
        ],
        122,
    ) + [("F#3", 5.0, 122)]
    faded = faded_phrase_a + faded_phrase_a + faded_phrase_b + faded_phrase_c + faded_phrase_b + faded_phrase_d

    # Canon in D: compact classroom demo melody, not default-selected.
    canon = []
    canon += q(["F#4", "E4", "D4", "C#4", "B3", "A3", "B3", "C#4"], 118)
    canon += q(["D4", "F#4", "A4", "G4", "F#4", "E4", "F#4", "D4"], 120)
    canon += q(["A4", "B4", "C#5", "D5", "C#5", "B4", "A4", "G4"], 120)
    canon += q(["F#4", "E4", "D4", "A3", "B3", "C#4", "D4", None], 118)

    c_major_scale = [
        ("C4", 261.63),
        ("D4", 293.66),
        ("E4", 329.63),
        ("F4", 349.23),
        ("G4", 392.00),
        ("A4", 440.00),
        ("B4", 493.88),
        ("C5", 523.25),
    ]
    calibration = []
    for note, _freq in c_major_scale:
        calibration.append((note, 1.0, 118))
        calibration.append((None, 0.08, 0))
    calibration.append(("C5", 2.0, 118))

    assets = {
        "faded_main_melody": ("Faded main melody", 90, faded, 0),
        "canon_main_melody": ("Canon main melody", 96, canon, 0),
        "vs1003_pitch_calibration": ("VS1003B C major pitch calibration", 72, calibration, 0),
    }

    report = []
    for stem, (title, bpm, notes, program) in assets.items():
        data = build_midi(OUT / f"{stem}.mid", title, bpm, notes, program)
        write_mem(OUT / f"{stem}.mem", data)
        write_padded_mem(OUT / f"{stem}_1024.mem", data)
        write_coe(OUT / f"{stem}_hex.COE", data)
        write_vh(OUT / f"{stem}.vh", stem, data)
        write_note_table(OUT / f"{stem}_notes.md", title, bpm, notes)
        report.append((stem, len(data), (len(data) + 3) // 4))
    write_pitch_scale_table(OUT / "vs1003_pitch_test_table.md", c_major_scale)

    (OUT / "README.md").write_text(
        "\n".join(
            [
                "# Single-track MIDI assets",
                "",
                "These files are generated for VS1003B playback using the same idea as the VGA_hw reference project:",
                "single-track Standard MIDI bytes are packed into 32-bit hex COE words for ROM initialization.",
                "",
                f"Generated MIDI note numbers include a `{VS1003_OUTPUT_TRANSPOSE_SEMITONES}` semitone compensation for the current VS1003B module, because board testing found the raw output about one semitone sharp.",
                "",
                "| asset | midi bytes | 32-bit words | role |",
                "| --- | ---: | ---: | --- |",
                *[
                    f"| `{stem}` | {size} | {words} | {'default selected VS1003B demo' if stem == 'faded_main_melody' else 'backup'} |"
                    for stem, size, words in report
                ],
                "",
                "The default selected file is `faded_main_melody`, because it is short, recognizable, and much smaller than an embedded MP3 clip.",
                "",
            ]
        ),
        encoding="ascii",
    )

    for stem, size, words in report:
        print(f"{stem}: {size} bytes, {words} 32-bit words")


if __name__ == "__main__":
    main()
