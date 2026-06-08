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


def midi_event_bytes(delta, status, payload):
    return vlq(delta) + bytes([status]) + bytes(payload)


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


def parse_midi_tracks(path):
    data = path.read_bytes()
    pos = 0
    if data[pos : pos + 4] != b"MThd":
        raise ValueError(f"{path}: not a MIDI file")
    pos += 4
    header_len = int.from_bytes(data[pos : pos + 4], "big")
    pos += 4
    midi_format = int.from_bytes(data[pos : pos + 2], "big")
    track_count = int.from_bytes(data[pos + 2 : pos + 4], "big")
    division = int.from_bytes(data[pos + 4 : pos + 6], "big")
    pos += header_len

    tracks = []
    for _idx in range(track_count):
        if data[pos : pos + 4] != b"MTrk":
            raise ValueError(f"{path}: bad track header")
        pos += 4
        track_len = int.from_bytes(data[pos : pos + 4], "big")
        pos += 4
        track = data[pos : pos + track_len]
        pos += track_len
        tracks.append(track)
    return midi_format, division, tracks


def parse_track_events(track):
    tick = 0
    index = 0
    running = None
    events = []
    while index < len(track):
        delta, index = read_vlq(track, index)
        tick += delta
        status = track[index]
        if status < 0x80:
            if running is None:
                raise ValueError("running status without previous status")
            status = running
        else:
            index += 1
            if status < 0xF0:
                running = status

        if status == 0xFF:
            kind = track[index]
            index += 1
            length, index = read_vlq(track, index)
            payload = track[index : index + length]
            index += length
            events.append((tick, "meta", kind, bytes(payload)))
            if kind == 0x2F:
                break
        elif status in (0xF0, 0xF7):
            length, index = read_vlq(track, index)
            payload = track[index : index + length]
            index += length
            events.append((tick, "sysex", status, bytes(payload)))
        else:
            command = status & 0xF0
            if command in (0x80, 0x90, 0xA0, 0xB0, 0xE0):
                payload = bytes(track[index : index + 2])
                index += 2
                events.append((tick, "midi", status, payload))
            elif command in (0xC0, 0xD0):
                payload = bytes(track[index : index + 1])
                index += 1
                events.append((tick, "midi", status, payload))
    return events


def seconds_to_beat_range(path, start_sec, end_sec):
    _midi_format, division, tracks = parse_midi_tracks(path)
    tempo_events = []
    for track in tracks:
        for tick, kind, tag, payload in parse_track_events(track):
            if kind == "meta" and tag == 0x51 and len(payload) == 3:
                tempo_events.append((tick, int.from_bytes(payload, "big")))
    tempo_events.sort()
    if not tempo_events or tempo_events[0][0] != 0:
        tempo_events.insert(0, (0, 500000))

    def sec_to_tick(target):
        elapsed = 0.0
        prev_tick, tempo = tempo_events[0]
        for tick, next_tempo in tempo_events[1:]:
            seg_sec = (tick - prev_tick) * tempo / division / 1_000_000
            if elapsed + seg_sec >= target:
                return prev_tick + (target - elapsed) * 1_000_000 * division / tempo
            elapsed += seg_sec
            prev_tick, tempo = tick, next_tempo
        return prev_tick + (target - elapsed) * 1_000_000 * division / tempo

    return sec_to_tick(start_sec) / division, sec_to_tick(end_sec) / division


def rewrite_midi_channel(status, payload, target_channel):
    command = status & 0xF0
    if command in (0x80, 0x90, 0xA0, 0xB0, 0xC0, 0xD0, 0xE0):
        return command | target_channel, payload
    return status, payload


def clip_midi(
    path,
    out_path,
    title,
    start_beat,
    end_beat,
    output_bpm=None,
    track_overrides=None,
):
    _midi_format, division, tracks = parse_midi_tracks(path)
    start_tick = int(round(start_beat * division))
    end_tick = int(round(end_beat * division))
    merged_events = []
    seen_prefix = set()
    order = 0
    track_overrides = track_overrides or {}

    for rule in track_overrides.values():
        channel = rule.get("channel")
        if channel is None:
            continue
        if "program" in rule:
            merged_events.append((0, order, "midi", 0xC0 | channel, bytes([rule["program"]])))
            order += 1
        if "volume" in rule:
            merged_events.append((0, order, "midi", 0xB0 | channel, bytes([7, rule["volume"]])))
            order += 1
        expression = rule.get("expression")
        if expression is not None:
            if isinstance(expression, (list, tuple)):
                duration = max(1, end_tick - start_tick)
                for pos, value in expression:
                    tick = int(round(duration * pos))
                    merged_events.append((tick, order, "midi", 0xB0 | channel, bytes([11, value])))
                    order += 1
            else:
                merged_events.append((0, order, "midi", 0xB0 | channel, bytes([11, expression])))
                order += 1

    for track_idx, track in enumerate(tracks):
        events = parse_track_events(track)
        rule = track_overrides.get(track_idx, {})
        for tick, kind, tag, payload in events:
            if kind == "meta" and tag == 0x2F:
                continue
            if kind == "meta" and tag in (0x03,):
                continue
            if kind == "midi" and rule:
                command = tag & 0xF0
                if command in (0xB0, 0xC0) and rule.get("drop_prefix_controls", True):
                    continue
                if rule.get("channel") is not None:
                    tag, payload = rewrite_midi_channel(tag, payload, rule["channel"])
            if kind == "meta" and tag in (0x51, 0x58, 0x59) and tick <= start_tick:
                if tag == 0x51 and output_bpm is not None:
                    payload = int(60_000_000 / output_bpm).to_bytes(3, "big")
                key = (kind, tag, payload)
                if key not in seen_prefix:
                    seen_prefix.add(key)
                    merged_events.append((0, order, kind, tag, payload))
                    order += 1
            elif kind == "midi" and tick <= start_tick and (tag & 0xF0) in (0xB0, 0xC0):
                key = (kind, tag, payload)
                if key not in seen_prefix:
                    seen_prefix.add(key)
                    merged_events.append((0, order, kind, tag, payload))
                    order += 1
            elif start_tick <= tick < end_tick:
                merged_events.append((tick - start_tick, order, kind, tag, payload))
                order += 1

    merged_events.sort(key=lambda event: (event[0], event[1]))
    out = bytearray()
    out += meta(0, 0x03, title.encode("ascii", errors="ignore"))
    if output_bpm is not None and ("meta", 0x51, int(60_000_000 / output_bpm).to_bytes(3, "big")) not in seen_prefix:
        out += meta(0, 0x51, int(60_000_000 / output_bpm).to_bytes(3, "big"))
    cursor = 0
    for tick, _order, kind, tag, payload in merged_events:
        delta = max(0, tick - cursor)
        if kind == "meta":
            out += meta(delta, tag, payload)
        elif kind == "sysex":
            out += vlq(delta) + bytes([tag]) + vlq(len(payload)) + payload
        else:
            out += midi_event_bytes(delta, tag, payload)
        cursor = tick
    out += meta(0, 0x2F, b"")

    data = bytearray()
    data += b"MThd"
    data += (6).to_bytes(4, "big")
    data += (0).to_bytes(2, "big")
    data += (1).to_bytes(2, "big")
    data += division.to_bytes(2, "big")
    data += b"MTrk"
    data += len(out).to_bytes(4, "big")
    data += out
    out_path.write_bytes(data)
    return data


def transform_midi_dynamics(
    data,
    channel_volumes=None,
    channel_expressions=None,
    velocity_scale=1.0,
    velocity_offset=0,
):
    channel_volumes = channel_volumes or {}
    channel_expressions = channel_expressions or {}
    midi_format, division, tracks = parse_midi_tracks_from_bytes(data)
    if midi_format != 0 or len(tracks) != 1:
        raise ValueError("dynamic transform expects a generated MIDI Type 0 file")

    events = []
    order = 0
    for channel, volume in channel_volumes.items():
        events.append((0, order, "midi", 0xB0 | (channel - 1), bytes([7, volume])))
        order += 1
    for channel, expression in channel_expressions.items():
        events.append((0, order, "midi", 0xB0 | (channel - 1), bytes([11, expression])))
        order += 1

    for event in parse_track_events(tracks[0]):
        tick, kind, tag, payload = event
        if kind == "midi":
            command = tag & 0xF0
            channel = (tag & 0x0F) + 1
            if command == 0x90 and len(payload) == 2 and payload[1] > 0:
                velocity = int(round(payload[1] * velocity_scale)) + velocity_offset
                velocity = max(1, min(127, velocity))
                payload = bytes([payload[0], velocity])
            elif command == 0xB0 and len(payload) == 2:
                if payload[0] == 7 and channel in channel_volumes:
                    payload = bytes([7, channel_volumes[channel]])
                elif payload[0] == 11 and channel in channel_expressions:
                    payload = bytes([11, channel_expressions[channel]])
        events.append((tick, order, kind, tag, payload))
        order += 1

    events.sort(key=lambda event: (event[0], event[1]))
    track = bytearray()
    cursor = 0
    for tick, _order, kind, tag, payload in events:
        delta = max(0, tick - cursor)
        if kind == "meta":
            track += meta(delta, tag, payload)
        elif kind == "sysex":
            track += vlq(delta) + bytes([tag]) + vlq(len(payload)) + payload
        else:
            track += midi_event_bytes(delta, tag, payload)
        cursor = tick

    out = bytearray()
    out += b"MThd"
    out += (6).to_bytes(4, "big")
    out += (0).to_bytes(2, "big")
    out += (1).to_bytes(2, "big")
    out += division.to_bytes(2, "big")
    out += b"MTrk"
    out += len(track).to_bytes(4, "big")
    out += track
    return out


def parse_midi_tracks_from_bytes(data):
    pos = 0
    if data[pos : pos + 4] != b"MThd":
        raise ValueError("not a MIDI file")
    pos += 4
    header_len = int.from_bytes(data[pos : pos + 4], "big")
    pos += 4
    midi_format = int.from_bytes(data[pos : pos + 2], "big")
    track_count = int.from_bytes(data[pos + 2 : pos + 4], "big")
    division = int.from_bytes(data[pos + 4 : pos + 6], "big")
    pos += header_len
    tracks = []
    for _idx in range(track_count):
        if data[pos : pos + 4] != b"MTrk":
            raise ValueError("bad track header")
        pos += 4
        track_len = int.from_bytes(data[pos : pos + 4], "big")
        pos += 4
        tracks.append(data[pos : pos + track_len])
        pos += track_len
    return midi_format, division, tracks


def extract_midi_channel_notes(path, channel, quant=0.25, velocity=120, start_beat=None, end_beat=None):
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

    raw_notes = []
    for _idx in range(track_count):
        if data[pos : pos + 4] != b"MTrk":
            raise ValueError(f"{path}: bad track header")
        pos += 4
        track_len = int.from_bytes(data[pos : pos + 4], "big")
        pos += 4
        track = data[pos : pos + track_len]
        pos += track_len

        tick = 0
        index = 0
        running = None
        active = {}
        while index < len(track):
            delta, index = read_vlq(track, index)
            tick += delta
            status = track[index]
            if status < 0x80:
                status = running
            else:
                index += 1
                if status < 0xF0:
                    running = status
            if status == 0xFF:
                kind = track[index]
                index += 1
                length, index = read_vlq(track, index)
                index += length
                if kind == 0x2F:
                    break
            elif status in (0xF0, 0xF7):
                length, index = read_vlq(track, index)
                index += length
            else:
                command = status & 0xF0
                event_channel = status & 0x0F
                if command in (0x80, 0x90, 0xA0, 0xB0, 0xE0):
                    note = track[index]
                    vel = track[index + 1]
                    index += 2
                    if event_channel != channel:
                        continue
                    if command == 0x90 and vel > 0:
                        active[(event_channel, note)] = tick
                    elif command in (0x80, 0x90):
                        start_tick = active.pop((event_channel, note), None)
                        if start_tick is not None:
                            raw_notes.append((start_tick / division, tick / division, note))
                elif command in (0xC0, 0xD0):
                    index += 1

    if not raw_notes:
        raise ValueError(f"{path}: channel {channel} has no notes")

    raw_notes.sort()
    if start_beat is None:
        start_beat = raw_notes[0][0]
    if end_beat is None:
        end_beat = raw_notes[-1][1]
    raw_notes = [
        (max(start, start_beat), min(end, end_beat), note)
        for start, end, note in raw_notes
        if start < end_beat and end > start_beat
    ]
    if not raw_notes:
        raise ValueError(f"{path}: channel {channel} has no notes in selected range")

    result = []
    cursor = start_beat
    for start, end, note in raw_notes:
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


def faded_first_where_are_you_now(velocity=122):
    # First vocal chorus from the user's numbered-notation request.
    # Use A minor / C major fingering: 6=A, 5=G, 3=E, 2=D, 1=C, 7,=B3.
    where_are_you_now = [
        ("A4", 1.0, velocity),
        ("G4", 1.0, velocity),
        ("E4", 1.0, velocity),
        ("D4", 1.0, velocity),
        ("C4", 1.0, velocity),
        ("B3", 1.0, velocity),
        ("C4", 1.0, velocity),
        ("D4", 1.0, velocity),
        ("E4", 4.0, velocity),
    ]
    was_it_all = [
        ("E4", 1.0, velocity),
        ("D4", 1.0, velocity),
        ("C4", 1.0, velocity),
        ("B3", 1.0, velocity),
        ("A3", 1.0, velocity),
        ("G3", 1.0, velocity),
        ("A3", 1.0, velocity),
        ("B3", 1.0, velocity),
        ("C4", 4.0, velocity),
    ]
    were_you_only = [
        ("E4", 1.0, velocity),
        ("D4", 1.0, velocity),
        ("C4", 1.0, velocity),
        ("B3", 1.0, velocity),
        ("A3", 1.0, velocity),
        ("G3", 1.0, velocity),
        ("A3", 2.0, velocity),
        ("A3", 4.0, velocity),
    ]
    notes = []
    for _ in range(3):
        notes.extend(where_are_you_now)
    notes.extend(was_it_all)
    notes.extend(where_are_you_now)
    notes.extend(were_you_only)
    return notes


def main():
    faded_source = ROOT / "music" / "midi_import" / "faded_perfect.mid"
    faded_bpm = None
    # User requested roughly 0:50-1:50, but the section should begin/end on
    # complete 4/4 bar boundaries. The source is 90 BPM, so 0:50 is beat 75 and
    # 1:50 is beat 165; align outward to beats 72-168, about 0:48-1:52.
    faded_start = 72.0
    faded_end = 168.0

    # Canon in D: complete bar-aligned fast variation from the mfiles original MIDI.
    # Track 1 is Violin 1; beats 72-92 keep the sixteenth-note variation plus
    # the following bar so the phrase does not stop before its cadence.
    canon = extract_midi_track_notes(
        ROOT / "music" / "midi_import" / "mfiles_pachelbel_canon_in_d.mid",
        track_index=1,
        start_beat=72,
        end_beat=92,
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

    aphasia_bpm = 128.0
    aphasia_start = 64.0
    aphasia_end = 128.0

    assets = {
        "canon_main_melody": ("Canon main melody", 36, canon, 0),
        "vs1003_pitch_calibration": ("VS1003B C major pitch calibration", 72, calibration, 0),
    }

    report = []
    faded_data = clip_midi(
        faded_source,
        OUT / "faded_main_melody.mid",
        "Faded 48s-112s",
        faded_start,
        faded_end,
        output_bpm=faded_bpm,
    )
    faded_data = transform_midi_dynamics(
        faded_data,
        channel_volumes={
            1: 76,
            2: 66,
            3: 64,
            10: 48,
            12: 72,
            13: 72,
            14: 62,
            15: 62,
        },
        velocity_scale=0.76,
    )
    (OUT / "faded_main_melody.mid").write_bytes(faded_data)
    write_mem(OUT / "faded_main_melody.mem", faded_data)
    write_padded_mem(OUT / "faded_main_melody_16384.mem", faded_data, size=16384)
    write_coe(OUT / "faded_main_melody_hex.COE", faded_data)
    write_vh(OUT / "faded_main_melody.vh", "faded_main_melody", faded_data)
    (OUT / "faded_main_melody_notes.md").write_text(
        "\n".join(
            [
                "# Faded main melody",
                "",
                "Source: `music/midi_import/faded_perfect.mid`",
                "",
                "Mode: full-MIDI clip merged to VS1003B-friendly MIDI Type 0.",
                "",
                "Range: requested 50s-110s, aligned outward to full 4/4 bars as source beats 72-168.",
                "",
                "Output BPM: preserved from source MIDI.",
                "",
                "Dynamics: channel volumes and velocities are reduced to balance against Canon/Aphasia without changing melody timing or pitch.",
                "",
            ]
        ),
        encoding="utf-8",
    )
    report.append(("faded_main_melody", len(faded_data), (len(faded_data) + 3) // 4))

    for stem, (title, bpm, notes, program) in assets.items():
        data = build_midi(OUT / f"{stem}.mid", title, bpm, notes, program)
        if stem == "canon_main_melody":
            data = transform_midi_dynamics(
                data,
                channel_volumes={1: 124},
                channel_expressions={1: 127},
                velocity_scale=1.0,
            )
            (OUT / f"{stem}.mid").write_bytes(data)
        write_mem(OUT / f"{stem}.mem", data)
        write_padded_mem(OUT / f"{stem}_1024.mem", data)
        write_coe(OUT / f"{stem}_hex.COE", data)
        write_vh(OUT / f"{stem}.vh", stem, data)
        write_note_table(OUT / f"{stem}_notes.md", title, bpm, notes)
        report.append((stem, len(data), (len(data) + 3) // 4))

    aphasia_data = clip_midi(
        ROOT / "music" / "midi_import" / "Aphasia.mid",
        OUT / "aphasia_main_33s_56s.mid",
        "Aphasia phrase 64-128",
        aphasia_start,
        aphasia_end,
        output_bpm=aphasia_bpm,
        track_overrides={
            # The source file uses the same piano program for both musical
            # layers. Give the second layer a distinct lead tone and a
            # gradual expression ramp so the entrance is audible on VS1003B.
            1: {"channel": 0, "program": 0, "volume": 102, "expression": 118},
            2: {"channel": 1, "program": 80, "volume": 110, "expression": [(0.0, 32), (0.25, 58), (0.50, 88), (0.75, 112)]},
        },
    )
    aphasia_data = transform_midi_dynamics(
        aphasia_data,
        channel_volumes={1: 118, 2: 94},
        channel_expressions={1: 127},
        velocity_scale=1.05,
    )
    (OUT / "aphasia_main_33s_56s.mid").write_bytes(aphasia_data)
    write_mem(OUT / "aphasia_main_33s_56s.mem", aphasia_data)
    write_padded_mem(OUT / "aphasia_main_33s_56s_4096.mem", aphasia_data, size=4096)
    write_coe(OUT / "aphasia_main_33s_56s_hex.COE", aphasia_data)
    write_vh(OUT / "aphasia_main_33s_56s.vh", "aphasia_main_33s_56s", aphasia_data)
    report.append(("aphasia_main_33s_56s", len(aphasia_data), (len(aphasia_data) + 3) // 4))
    write_pitch_scale_table(OUT / "vs1003_pitch_test_table.md", c_major_scale)

    (OUT / "README.md").write_text(
        "\n".join(
            [
                "# Compact MIDI assets",
                "",
                "These files are generated for VS1003B playback using the same idea as the VGA_hw reference project:",
                "Standard MIDI bytes are packed into 32-bit hex COE words for ROM initialization.",
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
