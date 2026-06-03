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


def midi_to_note_name(pitch):
    names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    return f"{names[pitch % 12]}{pitch // 12 - 1}"


def read_vlq(data, index):
    value = 0
    while True:
        byte = data[index]
        index += 1
        value = (value << 7) | (byte & 0x7F)
        if not (byte & 0x80):
            return value, index


def extract_midi_track_notes(path, track_index, start_beat, end_beat, quant=0.125, velocity=120):
    data = path.read_bytes()
    pos = 0
    if data[pos : pos + 4] != b"MThd":
        raise ValueError(f"{path}: not a MIDI file")
    pos += 4
    header_len = int.from_bytes(data[pos : pos + 4], "big")
    pos += 4
    track_count = int.from_bytes(data[pos + 2 : pos + 4], "big")
    division = int.from_bytes(data[pos + 4 : pos + 6], "big")
    pos += header_len
    if track_index >= track_count:
        raise ValueError(f"{path}: track {track_index} does not exist")

    selected_track = None
    for idx in range(track_count):
        if data[pos : pos + 4] != b"MTrk":
            raise ValueError(f"{path}: bad track header")
        pos += 4
        track_len = int.from_bytes(data[pos : pos + 4], "big")
        pos += 4
        track = data[pos : pos + track_len]
        pos += track_len
        if idx == track_index:
            selected_track = track

    tick = 0
    index = 0
    running = None
    active = {}
    notes = []
    while index < len(selected_track):
        delta, index = read_vlq(selected_track, index)
        tick += delta
        status = selected_track[index]
        if status < 0x80:
            status = running
        else:
            index += 1
            if status < 0xF0:
                running = status
        if status == 0xFF:
            _kind = selected_track[index]
            index += 1
            length, index = read_vlq(selected_track, index)
            index += length
        elif status in (0xF0, 0xF7):
            length, index = read_vlq(selected_track, index)
            index += length
        else:
            command = status & 0xF0
            channel = status & 0x0F
            if command in (0x80, 0x90, 0xA0, 0xB0, 0xE0):
                note = selected_track[index]
                vel = selected_track[index + 1]
                index += 2
                if command == 0x90 and vel > 0:
                    active[(channel, note)] = tick
                elif command in (0x80, 0x90):
                    start_tick = active.pop((channel, note), None)
                    if start_tick is not None:
                        start = start_tick / division
                        end = tick / division
                        if start_beat <= start < end_beat:
                            notes.append((start, end, note))
            elif command in (0xC0, 0xD0):
                index += 1

    notes.sort()
    result = []
    cursor = start_beat
    for start, end, note in notes:
        q_start = round((start - start_beat) / quant) * quant + start_beat
        q_end = max(q_start + quant, round((end - start_beat) / quant) * quant + start_beat)
        if q_start > cursor:
            result.append((None, q_start - cursor, 0))
        result.append((midi_to_note_name(note), q_end - q_start, velocity))
        cursor = q_end
    return result


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


def melody(seq, velocity=120):
    return [(note, beats, velocity) for note, beats in seq]


def main():
    # Faded: compact hand-written lead from the user's numbered notation.
    # Single-note only keeps the embedded VS1003B MIDI ROM small.
    faded_intro = q(
        [
            "A4",
            "A4",
            "G4",
            "A4",
            "C5",
            "C5",
            "B4",
            "C5",
            "A4",
            "A4",
            "G4",
            "A4",
            "E5",
            "E5",
            "D5",
            "E5",
        ],
        120,
    )
    faded_chorus = melody(
        [
            ("A4", 1.0),
            ("G4", 1.0),
            ("E4", 1.0),
            ("D4", 1.0),
            ("C4", 1.0),
            ("B3", 1.0),
            ("C4", 1.0),
            ("D4", 1.0),
            ("E4", 4.0),
            ("E4", 1.0),
            ("D4", 1.0),
            ("C4", 1.0),
            ("B3", 1.0),
            ("A3", 1.0),
            ("G3", 1.0),
            ("A3", 1.0),
            ("B3", 1.0),
            ("C4", 4.0),
            ("A4", 1.0),
            ("G4", 1.0),
            ("E4", 1.0),
            ("D4", 1.0),
            ("C4", 1.0),
            ("B3", 1.0),
            ("C4", 1.0),
            ("D4", 1.0),
            ("E4", 4.0),
        ],
        122,
    )
    faded = faded_intro + faded_chorus

    # Canon in D: complete fast variation from the mfiles original MIDI.
    # Track 1 is Violin 1; beats 72-88 contain the full sixteenth-note
    # allegro-like variation before the delayed canon entries repeat it.
    canon = extract_midi_track_notes(
        ROOT / "music" / "midi_import" / "mfiles_pachelbel_canon_in_d.mid",
        track_index=1,
        start_beat=72,
        end_beat=88,
        quant=0.125,
        velocity=120,
    )

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
