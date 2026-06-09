# AI 协作修改日志

本文用于记录本工程每次需求、修改内容、验证结果和后续注意事项，方便其他 AI 或同学继续协作。

### 2026-06-08 Faded 延长到 0:50-1:50

用户要求：
- Faded 改为截取 `0:50~1:50`。

本次修改：
- `scripts/make_single_track_midi_assets.py`
  - Faded 裁剪范围由 `0:50~1:35` 改为 `0:50~1:50`。
  - 仍按 `music/midi_import/faded_perfect.mid` 自身 tempo map 换算，不手动覆盖 BPM。
- `Mini_IO.sdk/SeriesIODacSaw/src/vs1003b_midi_assets.h`
  - 重新生成内置 MIDI 数组。
  - Faded source 标记：`Faded_perfect_50s_110s_source90bpm_type0`。
- `Mini_IO.sdk/SeriesIODacSaw/src/README.txt`
  - 更新 Faded 当前裁剪范围。

验证结果：
```text
faded_main_melody: 13123 bytes, 3281 32-bit words
canon_main_melody: 1000 bytes, 250 32-bit words
vs1003_pitch_calibration: 162 bytes, 41 32-bit words
aphasia_main_33s_56s: 2778 bytes, 695 32-bit words
```

本次只改 MIDI 资源、MicroBlaze 头文件和文档；不需要重新生成 bitstream，但需要重新编译并下载 `SeriesIODacSaw.elf`。

### 2026-06-08 Faded 延长后 15s 与 Canon 尾小节补全

用户反馈：
- Faded 板上播放听起来只有约 `15s`，需要把后面约 `15s` 也加进去，让长度更接近期望。
- Canon 结尾一小节似乎没有截取完整，需要调整裁剪。

本次修改：
- `scripts/make_single_track_midi_assets.py`
  - Faded 由 `0:50~1:20` 扩展为 `0:50~1:35`，仍通过 `seconds_to_beat_range()` 按 `faded_perfect.mid` 自身 `90 BPM` tempo map 换算。
  - Canon 由 source beats `72~88` 扩展为 `72~92`，补上后一小节，避免十六分音符变奏在结尾处突然截断。
- `Mini_IO.sdk/SeriesIODacSaw/src/vs1003b_midi_assets.h`
  - 重新生成内置 MIDI 数组。
  - Faded source 标记：`Faded_perfect_50s_95s_source90bpm_type0`。
  - Canon source 标记：`Canon_main_melody_bar72_92_36bpm`。
- `Mini_IO.sdk/SeriesIODacSaw/src/README.txt`
  - 更新 Faded 和 Canon 当前裁剪范围。

验证结果：
```text
faded_main_melody: 11218 bytes, 2805 32-bit words
canon_main_melody: 1000 bytes, 250 32-bit words
vs1003_pitch_calibration: 162 bytes, 41 32-bit words
aphasia_main_33s_56s: 2778 bytes, 695 32-bit words
```

本次只改 MIDI 资源、MicroBlaze 头文件和文档；不需要重新生成 bitstream，但需要重新编译并下载 `SeriesIODacSaw.elf`。

### 2026-06-08 Faded 完美版 50s-1:20 裁剪与 Aphasia 双声部重配器

用户要求：
- 已下载 `Alan Walker - Faded(完美版).mid`，需要截取 `0:50~1:20`，BPM 参照 MIDI 文件自身。
- Aphasia 当前片段希望开头、结尾再延伸一点，截成更像完整乐句的一大段。
- Aphasia 开头存在高低音轨叠加，但 VS1003B 播放时听起来像同一种声音，需要重新区分；后进入的音轨应逐渐增大，形成后半段旋律。

本次分析：
- `Alan Walker - Faded(完美版).mid`
  - 已复制为 ASCII 路径：`music/midi_import/faded_perfect.mid`。
  - 解析结果：MIDI Format 1，`11 tracks`，`division=480`，主 tempo 为 `90 BPM`，全长约 `208s`。
  - `0:50~1:20` 按文件自身 tempo map 对应 source beats `75~120`。
- `music/midi_import/Aphasia.mid`
  - 解析结果：MIDI Format 1，`3 tracks`，`division=256`，文件内 tempo 为 `100 BPM`。
  - track 1 和 track 2 原始 program 都是 `0`，即 Acoustic Grand Piano，所以 VS1003B 播放时高低音轨缺少音色区分。

本次修改：
- `scripts/make_single_track_midi_assets.py`
  - 新增 `seconds_to_beat_range()`，支持按 MIDI 自身 tempo map 将秒数转换为 beat 范围。
  - Faded 改为从 `music/midi_import/faded_perfect.mid` 裁剪 `0:50~1:20`，不再使用旧的 MIDI DB demo candidate。
  - Faded 输出保持源 MIDI tempo，不强行改 BPM。
  - Aphasia 改为 source beats `64~128`，比原 `33s~56s` 片段前后更完整。
  - `clip_midi()` 增加 track override 能力：
    - Aphasia track 1 -> channel 0，program 0，piano 主声部。
    - Aphasia track 2 -> channel 1，program 80，lead 声部。
    - track 2 增加 CC11 expression ramp：`32 -> 58 -> 88 -> 112`，使后进入声部逐渐变大。
- `Mini_IO.sdk/SeriesIODacSaw/src/vs1003b_midi_assets.h`
  - 重新生成内置 MIDI 数组。
  - Faded source 标记：`Faded_perfect_50s_80s_source90bpm_type0`。
  - Aphasia source 标记：`Aphasia_phrase_bar64_128_dual_tone_crescendo_128bpm`。
- `Mini_IO.sdk/SeriesIODacSaw/src/README.txt`
  - 更新当前 Faded/Aphasia 来源、裁剪范围和 Aphasia 双声部重配器说明。

验证结果：
```text
faded_main_melody: 7574 bytes, 1894 32-bit words
canon_main_melody: 961 bytes, 241 32-bit words
vs1003_pitch_calibration: 162 bytes, 41 32-bit words
aphasia_main_33s_56s: 2778 bytes, 695 32-bit words
```

本次只改 MIDI 资源、MicroBlaze 头文件和文档；不需要重新生成 bitstream，但需要重新编译并下载 `SeriesIODacSaw.elf`。

### 2026-06-07 切歌中途无声修复与 Faded 完整 MIDI 裁剪

用户反馈：
- 一首歌放到一半时切歌，后续歌曲可能放不出来。
- 怀疑 Faded MIDI 是否真的修改，因为听起来片段没有变化。

原因判断：
- 中途切歌无声：
  - 之前切歌只重置 `VsAudioPos` 并把新 MIDI 从头送入。
  - 如果上一首 MIDI 尚未结束，VS1003B 仍在解析旧 MIDI 文件，新文件头 `MThd` 会被塞进旧 MIDI 流中间，不一定被识别为新文件。
  - 因此中途切歌应软复位 VS1003B 解码器，再发送新 MIDI。
- Faded 听起来没变化：
  - 上一版 Faded 截取范围是 beats `29.5~70.25`。
  - 按 `20s~50s` 和完整小节换算后采用 beats `28~76`。
  - 两个范围高度重叠，所以虽然 MIDI 文件确实重新生成，但听感变化很小。
  - 为了让“20s~50s”更符合完整 MIDI 资源而非单旋律抽取，本次改为裁剪完整 MIDI 事件。

本次修改：
- `Mini_IO.sdk/SeriesIODacSaw/src/rhythm_game.c`
  - 新增 `VsResetDecoderForNewMidi()`。
  - 每次 `StartGame()` / 切歌时：
    - 选择目标 MIDI 数组。
    - 对 VS1003B 写入 `SCI_MODE=0x0804` 软复位。
    - 重新写 `CLOCKF`、`DECODE_TIME`、`AUDATA` 和当前音量。
    - 再从新 MIDI 的开头发送数据。
  - 目标：解决歌曲中途切换时新 MIDI 不被识别的问题。
- `scripts/make_single_track_midi_assets.py`
  - Faded 不再只抽 `faded_mididb_AUD_MB1504.mid` 的 channel 3。
  - 改为对完整 Faded MIDI 做 `clip_midi()`，合并为 VS1003B 兼容的 MIDI Type 0。
  - 截取仍为 source beats `28~76`，对应用户要求的 `20s~50s` 并保证完整小节。
  - 输出 BPM 仍为 `112.5`。
  - Faded padded mem 改为 `faded_main_melody_16384.mem`，因为完整 MIDI 片段超过 4KB。
- `Mini_IO.sdk/SeriesIODacSaw/src/vs1003b_midi_assets.h`
  - 重新生成内置 MIDI 数组。
  - Faded source 标记更新为 `Faded_MidiDB_full_20s_50s_bar28_76_type0_112_5bpm`。

验证结果：
```text
faded_main_melody: 8591 bytes, 2148 32-bit words
canon_main_melody: 961 bytes, 241 32-bit words
vs1003_pitch_calibration: 162 bytes, 41 32-bit words
aphasia_main_33s_56s: 2244 bytes, 561 32-bit words
```

注意：
- Faded 由单旋律抽取变成完整 MIDI 裁剪后，ELF 会明显变大，但仍在可接受范围内。
- 本次只改 MIDI 资源和 MicroBlaze C 程序，不需要重新生成 bitstream；需要重新编译并下载 `SeriesIODacSaw.elf`。

### 2026-06-07 Faded/Canon 完整小节截取与 U/D 音量按钮重构

用户要求：
- Faded 改为 `20s~50s` 的那一段，开头结尾都要保证小节完整。
- Canon 也从原 MIDI 里修改，保证开头结尾完整。
- 不需要 `BTNU` / `BTND` 控制音乐开始/结束。
- `BTNU` / `BTND` 只要点击改变音量。
- 可以用一个拨码开关表示音乐与谱面同时运作/暂停。

本次修改：
- `scripts/make_single_track_midi_assets.py`
  - Faded 仍使用 `music/midi_import/faded_mididb_AUD_MB1504.mid` 的 channel 3。
  - Faded 源 MIDI 主体 tempo 约 `90 BPM`，因此 `20s~50s` 约对应 beats `30~75`。
  - 为保证完整 4/4 小节，实际截取改为 beats `28~76`。
  - Faded 导出 BPM 仍保持此前调好的 `112.5 BPM`。
  - Canon 仍从 `music/midi_import/mfiles_pachelbel_canon_in_d.mid` 的 track 1 抽取。
  - Canon 当前范围 `beats 72~88` 本身就是完整 4 小节，继续保留并明确标注为 bar-aligned original-MIDI range。
- `Mini_IO.sdk/SeriesIODacSaw/src/vs1003b_midi_assets.h`
  - 重新生成 Canon/Faded/Aphasia 三首内置 MIDI 数组。
  - Faded source 标记更新为 `Faded_MidiDB_channel3_20s_50s_bar28_76_112_5bpm`。
  - Canon source 标记更新为 `Canon_main_melody_bar72_88_36bpm`。
- `Mini_IO.sdk/SeriesIODacSaw/src/rhythm_game.c`
  - 去掉 `BTNU` 重开歌曲、`BTND` 暂停/继续的功能。
  - `BTNU` 点击：音量增大一档。
  - `BTND` 点击：音量减小一档。
  - 音量仍为 `16` 档，覆盖从很小声到最大音量。
  - 新增 `SW13` 作为 VS1003B/MicroBlaze 模式下的音乐与谱面同步暂停开关：
    - `SW13=1`：暂停谱面计时并停止继续向 VS1003B 送 MIDI byte-stream。
    - `SW13=0`：继续谱面计时和 MIDI byte-stream。
  - `SW1:SW0` 切歌时自动 `StartGame()`，不再需要 `BTNU` 重开。
  - 修正 MicroBlaze VS 模式下的谱面计时：不再用 `SW0/SW1` 同时作为流速加成，避免选歌拨码影响谱面速度。
- `README.md` / `Mini_IO.sdk/SeriesIODacSaw/src/README.txt`
  - 更新 `BTNU/BTND` 仅用于点击调音量。
  - 更新 `SW13` 暂停/继续音乐与谱面。
  - 更新 Faded/Canon/Aphasia 当前截取说明。

验证结果：
```text
faded_main_melody: 375 bytes, 94 32-bit words
canon_main_melody: 961 bytes, 241 32-bit words
vs1003_pitch_calibration: 162 bytes, 41 32-bit words
aphasia_main_33s_56s: 2244 bytes, 561 32-bit words
```

本次只改 MIDI 资源和 MicroBlaze C 程序，不需要重新生成 bitstream；需要重新编译并下载 `SeriesIODacSaw.elf`。

### 2026-06-07 VS1003B 音量长按控制与 Aphasia 33s-56s 小节结束版

用户要求：
- `BTNU` / `BTND` 当前无法修改音量，需要调整按钮设置。
- 每个音量刻度最好覆盖从很小到最大音量。
- Aphasia 改为截取 `33s~56s` 的片段。
- 片段结束需要落到一小节结束，避免突然中断。

本次修改：
- `Mini_IO.sdk/SeriesIODacSaw/src/rhythm_game.c`
  - 新增 `VsVolumeTable[]`，共 `16` 档 VS1003B 衰减值：
    - 从 `0xFE` 极小音量逐步到 `0x00` 最大音量。
  - 新增 `VsApplyVolume()` / `VsAdjustVolume()`。
  - VS1003B 初始化时不再固定写 `SCI_VOL=0x1010`，改为写当前音量档。
  - `BTNU` / `BTND` 改为短按与长按区分：
    - `BTNU` 短按释放：开始/重开当前歌曲。
    - `BTND` 短按释放：暂停/继续。
    - `BTNU` 长按约 `0.4s`：音量增大，随后约每 `140ms` 连续增大一档。
    - `BTND` 长按约 `0.4s`：音量减小，随后约每 `140ms` 连续减小一档。
  - 这样保留原有游戏控制，同时允许用同一组按钮调音量。
- `scripts/make_single_track_midi_assets.py`
  - Aphasia 截取改为 `33s~56s`，仍按 `128 BPM` 解释。
  - `start_beat = 33 * 128 / 60 = 70.4`。
  - `end_raw = 56 * 128 / 60 ~= 119.47`。
  - 结束点向后对齐到下一个 4/4 小节边界：`end_beat = 120.0`。
  - 输出文件改名为 `music/midi/aphasia_main_33s_56s.mid`。
  - 仍导出为 MIDI Type 0、单轨，保持 VS1003B 兼容。
- `Mini_IO.sdk/SeriesIODacSaw/src/vs1003b_midi_assets.h`
  - 重新生成 `Vs1003bAphasiaMidi[]`。
  - `VS1003B_APHASIA_MIDI_SOURCE` 更新为 `Aphasia_MidiShow_33s_56s_bar_end_type0_128bpm`。
- `README.md` / `Mini_IO.sdk/SeriesIODacSaw/src/README.txt`
  - 更新 `BTNU/BTND` 短按/长按功能说明。
  - 更新 Aphasia 截取范围说明。

验证结果：
```text
aphasia_main_33s_56s: 2244 bytes, 561 32-bit words
head = MThd
format = 00-00
ntrks = 00-01
tempo_us = 468750  # 128 BPM
```

本次只改 MIDI 资源和 MicroBlaze C 程序，不需要重新生成 bitstream；需要重新编译并下载 `SeriesIODacSaw.elf`。

### 2026-06-07 Aphasia 按 128 BPM 重新换算截取并导出

用户反馈：
- Aphasia 听起来 BPM 不太对。
- 确认应按照 `128 BPM` 换算 `0:52~1:22` 的截取位置并修改。

原因：
- 用户保存的 `music/midi_import/Aphasia.mid` 文件内部 tempo 是 `100 BPM`。
- 之前按 `100 BPM` 把 `0:52~1:22` 换算为 beat 范围，导致截取位置和听感不符合用户记忆中的 `128 BPM` 版本。

本次修改：
- `scripts/make_single_track_midi_assets.py`
  - `clip_midi()` 新增 `output_bpm` 参数。
  - Aphasia 截取改为按 `128 BPM` 换算：
    - `start_beat = 52 * 128 / 60 ~= 110.93`
    - `end_beat = 82 * 128 / 60 ~= 174.93`
  - 导出的 `aphasia_main_52s_82s.mid` tempo meta event 改为 `128 BPM`。
  - 仍输出 MIDI Type 0、单轨，保持 VS1003B 兼容性。
- `Mini_IO.sdk/SeriesIODacSaw/src/vs1003b_midi_assets.h`
  - 重新生成 `Vs1003bAphasiaMidi[]`。
  - `VS1003B_APHASIA_MIDI_SOURCE` 更新为 `Aphasia_MidiShow_52s_82s_type0_128bpm`。
- `Mini_IO.sdk/SeriesIODacSaw/src/README.txt`
  - 更新 Aphasia 说明：`0:52~1:22` 按 `128 BPM` 解释，并导出为 MIDI Type 0。

验证结果：
```text
aphasia_main_52s_82s: 2843 bytes, 711 32-bit words
fmt = 0
ntrks = 1
tempo = 468750 us/qn = 128 BPM
```

本次只改 MIDI 资源和 MicroBlaze ELF，不需要重新生成 bitstream。

### 2026-06-07 Aphasia 无声排查：转换为 VS1003B 支持的 MIDI Type 0

用户反馈：
- `SW1:SW0=11` 选择 Aphasia 后没有声音。
- 询问是否因为没有重新生成 bitstream。

原因判断：
- 本次 Aphasia 只改了 MicroBlaze ELF 内置 MIDI 数据和 C 选择逻辑，理论上不需要重新生成 bitstream。
- 若开发板断电或 bitstream 丢失，需要重新下载已有 bitstream；但在 bitstream 已运行、Faded/Canon 可播放的前提下，Aphasia 无声更可能是 MIDI 格式问题。
- 查阅 VS1003B MIDI 支持资料后确认：VS1003B 播放 General MIDI / SP-MIDI format 0 文件；Format 1/2 需要转换。
- 上一版 `aphasia_main_52s_82s.mid` 保留了原始 MIDI Format 1 的多轨结构，这可能导致 VS1003B 不播放。

本次修改：
- `scripts/make_single_track_midi_assets.py`
  - 修改 `clip_midi()`，将裁剪出的多轨事件合并输出为 SMF Type 0。
  - 保留 tempo、time/key signature、program/control change 等必要前置事件。
  - 合并所有轨道中 `0:52~1:22` 范围内的 MIDI 事件到单一 track。
- 重新生成：
  - `music/midi/aphasia_main_52s_82s.mid`
  - `.mem`
  - `_4096.mem`
  - `.COE`
  - `.vh`
- `Mini_IO.sdk/SeriesIODacSaw/src/vs1003b_midi_assets.h`
  - 重新生成 `Vs1003bAphasiaMidi[]`。
  - `VS1003B_APHASIA_MIDI_SOURCE` 更新为 `Aphasia_MidiShow_52s_82s_type0_100bpm`。

验证结果：
```text
aphasia_main_52s_82s: 2078 bytes, 520 32-bit words
head = MThd
format = 00-00
ntrks = 00-01
```

结论：
- 本次问题不优先归因于未生成 bitstream。
- 更关键的修复是将 Aphasia 从 MIDI Type 1 裁剪结果改为 VS1003B 更稳妥支持的 MIDI Type 0。
- 本次仍只需重新编译并下载 `SeriesIODacSaw.elf`；若板子断电或未加载硬件设计，才需要重新下载已有 bitstream。

### 2026-06-07 Aphasia 0:52-1:22 接入为歌曲 3

用户要求：
- 已下载并保存 `Aphasia.mid`。
- 需要截取 `0:52~1:22` 这一段。
- 将这一段设置为歌曲 3。
- 可以考虑 `SW[1:0]=11` 时播放。

本次修改：
- 验证 `music/midi_import/Aphasia.mid`
  - 文件头为 `MThd`，确认为标准 MIDI。
  - 文件大小 `9209 bytes`。
  - MIDI Format 1。
  - 3 个 track。
  - division 为 `256`。
  - tempo 为 `100 BPM`。
  - channel 0 / channel 1 均为钢琴内容。
- `scripts/make_single_track_midi_assets.py`
  - 新增 `parse_midi_tracks()` / `parse_track_events()` / `clip_midi()`。
  - 新增对原始 MIDI 指定时间段的裁剪能力，保留多轨 MIDI 事件，而不是强行抽成单音旋律。
  - `0:52~1:22` 按 `100 BPM` 换算为：
    - `start_beat = 52 * 100 / 60 ~= 86.67`
    - `end_beat = 82 * 100 / 60 ~= 136.67`
  - 生成 `music/midi/aphasia_main_52s_82s.mid`。
  - 同步生成 `.mem`、`_4096.mem`、`.COE`、`.vh`。
  - 资源目录说明从 `Single-track MIDI assets` 改为 `Compact MIDI assets`，因为 Aphasia 现在保留多轨 MIDI。
- `Mini_IO.sdk/SeriesIODacSaw/src/vs1003b_midi_assets.h`
  - 新增 `Vs1003bAphasiaMidi[]`。
  - 新增 `VS1003B_APHASIA_MIDI_LEN`。
  - 新增 `VS1003B_APHASIA_MIDI_SOURCE "Aphasia_MidiShow_52s_82s_100bpm"`。
- `Mini_IO.sdk/SeriesIODacSaw/src/rhythm_game.c`
  - `VsSelectSong()` 新增 `song == 2` 分支，播放 Aphasia。
  - `StartGame()` 歌曲选择改为读取 `SW[1:0]`：
    - `00`：默认 Faded
    - `01`：Canon
    - `10`：Faded
    - `11`：Aphasia
- `README.md`
  - 更新 VS1003B 拨码表，加入 `SW1:SW0=11` 选择 Aphasia。
- `Mini_IO.sdk/SeriesIODacSaw/src/README.txt`
  - 更新内置歌曲说明和 `SW1:SW0` 歌曲选择表。

验证结果：
```text
faded_main_melody: 365 bytes, 92 32-bit words
canon_main_melody: 961 bytes, 241 32-bit words
vs1003_pitch_calibration: 162 bytes, 41 32-bit words
aphasia_main_52s_82s: 2220 bytes, 555 32-bit words
```

注意：
- 本次只是把 Aphasia 作为第三首 VS1003B MIDI 音频播放源接入。
- 音游谱面/判定节奏暂未为 Aphasia 单独制作，当前 `SongIndex=2` 时游戏谱面仍复用现有逻辑。
- 本次只改 MIDI 资源和 MicroBlaze C 程序，不需要重新生成 bitstream；需要重新编译并下载 `SeriesIODacSaw.elf`。

### 2026-06-07 Aphasia 主旋律 MIDI 查询与下载状态

用户要求：
- 记得 `Aphasia` 前面主旋律重复很多。
- 希望截取主旋律到高潮开头的一段，约 `30s` 左右。

本次查询：
- 继续搜索闫东炜 `Aphasia` MIDI 资源。
- 找到一个更适合“主旋律截取”的 MidiShow 页面：
  - `https://www.midishow.com/midi/aphasia-midi-download-139960`
  - 页面简介明确写有：`这是aphasia的主旋律部分的midi`
  - 页面信息：
    - 文件大小约 `5.53 KB`
    - 时长约 `03:37`
    - BPM `128`
    - MIDI TYPE 1
    - GM1
    - 约 `686` 个音符
    - 使用 channel 1 主旋律，另有 channel 10 打击乐和 channel 11 钢琴片段
- 也保留此前查到的钢琴独奏页面：
  - `https://www.midishow.com/midi/aphasia-midi-download-148095`
  - 文件大小约 `8.99 KB`
  - BPM `100`
  - MIDI TYPE 1
  - 钢琴独奏谱风格

下载尝试：
- 已保存页面 HTML：
  - `music/midi_import/aphasia_main_midishow_page.html`
  - `music/midi_import/aphasia_midishow_page.html`
- 尝试访问普通下载接口：
  - `/midi/download?id=139960`
  - `/midi/download?id=148095`
- 尝试访问页面播放器 `data-mid` token 链接。
- 结果：下载到的文件均为 HTML 页面，文件头为 `<!DOCTYPE html>`，不是标准 MIDI 的 `MThd`。
- 推断：MidiShow 下载接口可能需要登录、积分、浏览器态校验或其它限制；当前无法直接取得可用 `.mid` 文件。

后续可执行方案：
- 用户若能手动登录 MidiShow 下载 `aphasia.mid`，请放到：
  - `music/midi_import/aphasia_midishow_139960.mid`
- 下载后必须先验证文件头为 `MThd`。
- 若验证成功，建议处理策略：
  - 使用 139960 主旋律版本优先于 148095 钢琴独奏版本。
  - 解析 channel 1。
  - 按 `128 BPM` 估算，约 `30s` 对应 `64 beats`。
  - 截取 `start_beat=0` 到约 `end_beat=64`，必要时根据音符密度微调到高潮入口前。
  - 生成单轨 MIDI byte-stream 给 VS1003B 播放。
- 本地已有 `music/闫东炜 - Aphasia.mp3`，但这不是 MIDI；若改走 MP3 流播放，需要另一条 VS1003B 大文件流方案。

### 2026-06-07 Faded 回退到上一版 first_where 截取段，并查询 Aphasia MIDI

用户要求：
- 将 Faded 改回上一版截取的那段。
- 询问闫东炜的 `Aphasia` 是否能上网找到 MIDI。

本次修改：
- `scripts/make_single_track_midi_assets.py`
  - Faded 仍使用 `music/midi_import/faded_mididb_AUD_MB1504.mid`。
  - Faded 仍使用 channel 3。
  - 截取范围从 `start_beat=4.5`、`end_beat=28.75` 改回上一版 `start_beat=29.5`、`end_beat=70.25`。
  - BPM 保持 `112.5`。
- `music/midi/`
  - 重新生成 Faded MIDI、mem、COE、1024 mem、vh 和音符表。
- `Mini_IO.sdk/SeriesIODacSaw/src/vs1003b_midi_assets.h`
  - 重新生成 MicroBlaze 内置 MIDI 数组。
  - `VS1003B_FADED_MIDI_SOURCE` 改回 `Faded_MidiDB_channel3_first_where_112_5bpm`。
- `Mini_IO.sdk/SeriesIODacSaw/src/README.txt`
  - 当前 Faded 说明改回 MIDI DB channel 3，beats `29.5-70.25`。

Aphasia MIDI 查询结果：
- 搜到 MidiShow 资源页：`https://www.midishow.com/midi/aphasia-midi-download-148095`
- 页面说明：
  - 曲名：`Aphasia`
  - 作曲：闫东炜
  - 风格：动漫/游戏音乐
  - 编制：大钢琴独奏
  - 全曲约 `2分28秒`
  - 约 `1075` 个音符
  - `3` 个音轨
  - 单一曲速 `100bpm`
  - GM1 标准
  - MIDI TYPE 1
  - 文件大小约 `8.99 KB`
- 该大小明显大于当前 Faded/Canon 小片段，但仍可能作为 VS1003B MIDI byte-stream 候选。
- 后续如果要接入 Aphasia，需实际下载并验证文件头为 `MThd`，再决定是完整内置、截取主旋律，还是另做外部数据流。

验证结果：
```text
faded_main_melody: 365 bytes, 92 32-bit words
canon_main_melody: 961 bytes, 241 32-bit words
vs1003_pitch_calibration: 162 bytes, 41 32-bit words
```

本次只改 MIDI 资源和 SDK 内置数组，不需要重新生成 bitstream；需要重新编译并下载 `SeriesIODacSaw.elf`。

### 2026-06-07 Faded 改为 1113 6665 偏好的资源开头段

用户要求：
- 反馈最喜欢的是 `1113 6665` 开头的那一段。
- 要求修改当前 Faded 播放段。

本次修改：
- 仍然保持“网上 MIDI 资源抽取版”，不手写新的 Faded MIDI。
- `scripts/make_single_track_midi_assets.py`
  - Faded 继续使用 `music/midi_import/faded_mididb_AUD_MB1504.mid`。
  - Faded 继续使用 channel 3。
  - 将截取范围从上一版 `start_beat=29.5`、`end_beat=70.25` 改为 `start_beat=4.5`、`end_beat=28.75`。
  - 该范围保留 MIDI 资源里重复起句的开头段，更接近用户描述的 `1113 6665` 听感偏好。
  - BPM 保持 `112.5`。
- `music/midi/`
  - 重新生成 `faded_main_melody.mid`、`.mem`、`.COE`、`_1024.mem`、`.vh` 和音符表。
  - 新的 `faded_main_melody_notes.md` 开头为 `A#4` 重复起句，随后进入 `F#4 D#4 C#4...`。
- `Mini_IO.sdk/SeriesIODacSaw/src/vs1003b_midi_assets.h`
  - 重新生成 MicroBlaze 内置 MIDI 数组。
  - `VS1003B_FADED_MIDI_SOURCE` 更新为 `Faded_MidiDB_channel3_1113_6665_like_112_5bpm`。
- `Mini_IO.sdk/SeriesIODacSaw/src/README.txt`
  - 当前 Faded 说明更新为 MIDI DB channel 3，beats `4.5-28.75`，目标为用户偏好的 `1113 6665` 起句段。

验证结果：
```text
faded_main_melody: 265 bytes, 67 32-bit words
canon_main_melody: 961 bytes, 241 32-bit words
vs1003_pitch_calibration: 162 bytes, 41 32-bit words
```

注意：
- 本地 MIDI DB 候选文件中没有找到严格连续等价于 `1 1 1 3 | 6 6 6 5` 的八音音程序列。
- 本次采用的是该资源里最接近“重复开头动机”的 channel 3 开头段；若用户继续指出具体听感差异，应再换 MIDI 源或换 channel/beat 范围。
- 本次只改 MIDI 资源和 SDK 内置数组，不需要重新生成 bitstream；需要重新编译并下载 `SeriesIODacSaw.elf`。

### 2026-06-07 Faded MIDI 资源版截取第一次 Where are you now 段落

用户要求：
- 继续使用网上 MIDI 资源抽取版，不要手写 MIDI。
- 将当前偏高潮的 Faded 截取段改为第一次 `Where are you now?` 经典段落。
- 目标歌词范围：
  - `Where are you now?`
  - `Where are you now?`
  - `Where are you now?`
  - `Was it all in my fantasy?`
  - `Where are you now?`
  - `Were you only imaginary?`

本次修改：
- `scripts/make_single_track_midi_assets.py`
  - `extract_midi_channel_notes()` 新增 `start_beat` / `end_beat` 参数，支持从 MIDI channel 中截取指定 beat 范围。
  - Faded 仍使用 `music/midi_import/faded_mididb_AUD_MB1504.mid`。
  - Faded 仍使用 channel 3，不手写音符。
  - 本次截取范围设为 `start_beat=29.5`、`end_beat=70.25`。
  - 该范围跳过前面的 lead-in phrase，目标是第一次可辨识的 `Where are you now` 副歌段。
  - BPM 保持 `112.5`。
- `music/midi/`
  - 重新生成 `faded_main_melody.mid`、`.mem`、`.COE`、`_1024.mem`、`.vh` 和音符表。
  - 新的 `faded_main_melody_notes.md` 开头为 `C#5 A#4 C#5 A#4...`，不再从前置的 `A#4 A#4 A#4...` 铺垫开始。
- `Mini_IO.sdk/SeriesIODacSaw/src/vs1003b_midi_assets.h`
  - 重新生成 MicroBlaze 内置 MIDI 数组。
  - `VS1003B_FADED_MIDI_SOURCE` 更新为 `Faded_MidiDB_channel3_first_where_112_5bpm`。
- `Mini_IO.sdk/SeriesIODacSaw/src/README.txt`
  - 当前 Faded 说明更新为 MIDI DB channel 3，beats `29.5-70.25`，目标为第一次 `Where are you now` 副歌。

验证结果：
```text
faded_main_melody: 365 bytes, 92 32-bit words
canon_main_melody: 961 bytes, 241 32-bit words
vs1003_pitch_calibration: 162 bytes, 41 32-bit words
```

本次只改 MIDI 资源和 SDK 内置数组，不需要重新生成 bitstream；需要重新编译并下载 `SeriesIODacSaw.elf`。

### 2026-06-07 Faded 恢复为网上 MIDI 资源抽取版

用户要求：
- 修改计划：工程只用 MIDI 驱动 VS1003B 播放。
- 不要由 AI 自己手写制作 Faded MIDI。
- 重新上网查找/使用 Faded MIDI 资源，像之前截取高潮段一样替换当前 Faded 声音。

本次修改：
- `scripts/make_single_track_midi_assets.py`
  - 取消当前播放用 Faded 的手写 `faded_first_where_are_you_now()` 路径。
  - 恢复从 `music/midi_import/faded_mididb_AUD_MB1504.mid` 抽取 channel 3。
  - 保持 `quant=0.25`、`velocity=122`、`BPM=112.5`。
- `music/midi/`
  - 重新生成 `faded_main_melody.mid`、`.mem`、`.COE`、`_1024.mem`、`.vh` 和音符表。
  - 当前 Faded 回到 MIDI DB 候选资源抽取版本，大小为 `566 bytes`。
- `Mini_IO.sdk/SeriesIODacSaw/src/vs1003b_midi_assets.h`
  - 重新生成 MicroBlaze 内置 MIDI 数组。
  - `VS1003B_FADED_MIDI_SOURCE` 恢复为 `Faded_MidiDB_channel3_main_melody_112_5bpm`。
- `Mini_IO.sdk/SeriesIODacSaw/src/README.txt`
  - 当前 Faded 说明改回：下载的 MIDI DB demo candidate，channel 3 抽取，`112.5 BPM`。

资源说明：
- 本轮重新查询了 Faded MIDI 相关资源。结合之前已验证结果，继续使用本地已有的 MIDI DB 候选文件。
- 该文件此前已确认是标准 MIDI 文件，文件头为 `MThd`；相比一些直接下载得到 HTML/错误页的候选，它更适合作为当前工程输入。
- 这仍然不是 MP3 音频，而是 MIDI 乐谱指令流；VS1003B 接收 MIDI byte-stream 后内部合成播放。

验证结果：
```text
faded_main_melody: 566 bytes, 142 32-bit words
canon_main_melody: 961 bytes, 241 32-bit words
vs1003_pitch_calibration: 162 bytes, 41 32-bit words
```

本次只改 MIDI 资源和 SDK 内置数组，不需要重新生成 bitstream；需要重新编译并下载 `SeriesIODacSaw.elf`。

### 2026-06-07 Faded 改为第一次 Where are you now 副歌

用户要求：
- 当前 Faded 听起来像高潮段落的 `Where are you now`。
- 希望换成第一次进入副歌时更经典的人声旋律，对应歌词：
  - `Where are you now?`
  - `Where are you now?`
  - `Where are you now?`
  - `Was it all in my fantasy?`
  - `Where are you now?`
  - `Were you only imaginary?`

本次修改：
- `scripts/make_single_track_midi_assets.py`
  - 新增 `faded_first_where_are_you_now()`，不再把当前播放用 Faded 从 MIDI DB channel 3 自动抽取。
  - 按用户之前给出的简谱思路手写第一次副歌旋律。
  - 采用 A 小调/C 大调首调映射：`6=A`、`5=G`、`3=E`、`2=D`、`1=C`、`7,=B3`。
  - `Where are you now?` 使用：
    - `A4 G4 E4 D4 | C4 B3 C4 D4 | E4 - - -`
  - `Was it all in my fantasy?` 使用：
    - `E4 D4 C4 B3 | A3 G3 A3 B3 | C4 - - -`
  - `Were you only imaginary?` 使用：
    - `E4 D4 C4 B3 | A3 G3 A3 - | A3 - - -`
  - BPM 保持上一轮要求的 `112.5`，即 `90 BPM` 的 `1.25` 倍速。
- `music/midi/`
  - 重新生成 Faded MIDI、mem、COE、1024 mem、vh 和音符表。
  - 当前 `faded_main_melody_notes.md` 共 `53` 个音符/延长事件。
- `Mini_IO.sdk/SeriesIODacSaw/src/vs1003b_midi_assets.h`
  - 重新生成 MicroBlaze 内置 MIDI 数组。
  - `VS1003B_FADED_MIDI_SOURCE` 更新为 `Faded_first_where_are_you_now_112_5bpm`。
- `Mini_IO.sdk/SeriesIODacSaw/src/README.txt`
  - 当前 Faded 说明改为手写第一次 `Where are you now` 副歌。

验证结果：
```text
faded_main_melody: 542 bytes, 136 32-bit words
canon_main_melody: 961 bytes, 241 32-bit words
vs1003_pitch_calibration: 162 bytes, 41 32-bit words
```

本次只改变 MIDI 资源和 SDK 内置数组，不需要重新生成 bitstream；需要重新编译并下载 `SeriesIODacSaw.elf`。

### 2026-06-07 Faded 1.25 倍速与 MIDI 来源说明

用户要求：
- 将 Faded 从上一版 `1.5` 倍速改为 `1.25` 倍速。
- 确认当前 Faded 的 MIDI 是怎么获得的。

本次修改：
- `scripts/make_single_track_midi_assets.py`
  - 将 `faded_main_melody` BPM 从 `135` 改为 `112.5`，即以原先课堂设定 `90 BPM` 为基准的 `1.25` 倍速。
  - 保持 Faded 的音符来源不变，仍从 `music/midi_import/faded_mididb_AUD_MB1504.mid` 的 channel 3 抽取。
- `music/midi/`
  - 重新生成 `faded_main_melody.mid`、`.mem`、`.COE`、`_1024.mem`、`.vh` 和音符表。
  - `faded_main_melody_notes.md` 当前显示 `BPM: 112.5`。
- `Mini_IO.sdk/SeriesIODacSaw/src/vs1003b_midi_assets.h`
  - 重新生成 MicroBlaze 内置 MIDI 数组。
  - `VS1003B_FADED_MIDI_SOURCE` 更新为 `Faded_MidiDB_channel3_main_melody_112_5bpm`。
- `Mini_IO.sdk/SeriesIODacSaw/src/README.txt`
  - 将 Faded 说明从 `135 BPM` 改为 `112.5 BPM`。

Faded MIDI 来源说明：
- 当前 Faded 不是由用户在 FL Studio 中手工提取，也不是直接从本地 MP3 自动转出来的。
- 曾检查多个在线候选：
  - MidiShow 候选页面提供了曲目信息，但直接下载得到的不是可用 MIDI 文件，因此未采用。
  - MIDIWorld 候选下载得到站点错误内容，因此未采用。
  - MIDI DB 的 `Alan Walker - Faded MIDI` 候选下载成功，文件头为 `MThd`，确认为标准 MIDI 文件。
- 已保存到本地：
  - `music/midi_import/faded_mididb_AUD_MB1504.mid`
- 该文件解析为单轨、多通道 MIDI。筛选时看到 channel 3 音符数量较少、音域约在 MIDI note `61..73`，更像主唱/Lead 主旋律；而其它若干 channel 更像低音、鼓、琶音或密集伴奏。
- 因此当前工程采用 channel 3，经量化后生成单轨 SMF MIDI 给 VS1003B 播放。
- 注意：这不是官方原版工程 MIDI，只是一个现成 MIDI 候选中的主旋律抽取版；若听感仍不像，下一步应换更准确的 MIDI 候选，或由 FL Studio/NewTone 人工整理后交给脚本打包。

验证结果：
```text
faded_main_melody: 566 bytes, 142 32-bit words
canon_main_melody: 961 bytes, 241 32-bit words
vs1003_pitch_calibration: 162 bytes, 41 32-bit words
```

本次不需要重新生成 bitstream；后续只需重新编译并下载 `SeriesIODacSaw.elf`。

### 2026-06-07 Faded 1.5 倍速与 SW0/SW1 曲目分支

用户要求：
- Faded 目前似乎可以，要求 BPM 改为当前的 `1.5` 倍。
- 希望更完整一点。
- 需要 `SW0` 和 `SW1` 控制 Canon 与 Faded 的分支。

本次修改：
- `scripts/make_single_track_midi_assets.py`
  - 将 `faded_main_melody` BPM 从 `90` 改为 `135`。
  - 重新生成 `music/midi/faded_main_melody.mid`、`.mem`、`.COE`、`_1024.mem`、音符表等。
  - Faded 仍使用 MIDI DB 候选文件的 channel 3 主旋律，完整保留该 channel 抽取出的主线。
- `Mini_IO.sdk/SeriesIODacSaw/src/vs1003b_midi_assets.h`
  - 重新生成 C 头文件。
  - 同时包含 `Vs1003bCanonMidi` 和 `Vs1003bFadedMidi`。
- `Mini_IO.sdk/SeriesIODacSaw/src/rhythm_game.c`
  - 增加 `VsSelectSong()`。
  - `SW1=1` 选择 Faded。
  - `SW1=0, SW0=1` 选择 Canon。
  - `SW0=0, SW1=0` 默认 Faded，避免无声。
  - `BTNU` 重新开始时会按当前拨码重新选择歌曲并从头发送 MIDI。
- `Mini_IO.sdk/SeriesIODacSaw/src/README.txt`
  - 更新当前曲目选择说明和 Faded 135 BPM 说明。

验证结果：
```text
faded_main_melody: 566 bytes, 142 32-bit words
canon_main_melody: 961 bytes, 241 32-bit words

SDK make all:
text=11072, data=380, bss=3132, dec=14584
```

已下载：
- 已运行 `scripts/download_seriesiodacsaw.tcl`，成功下载新的 `SeriesIODacSaw.elf`。
- 本次只改 MIDI 资源和 MicroBlaze C 程序，没有重新生成 bitstream。

### 2026-06-07 SW2=1 后数码管不亮与无声排查

用户反馈：
- `SW2=1` 后数码管后四位不亮。
- 同时没有声音。

原因判断：
- `SW2=1` 后数码管已经被切到 MicroBlaze 输出，但 C 程序原先使用 `Xil_Out8` 写 AXI GPIO；AXI GPIO 是 32 位寄存器，8 位写在当前总线上不够稳妥，可能导致段选/位选没有真正写出。
- C 主程序在进入数码管扫描循环前先执行 VS1003B 初始化和 SCI 读回；如果 DREQ/MISO 读回不顺，程序会卡在初始化阶段，导致数码管扫描、按键和 MIDI 服务都不运行。
- 之前设计为 `BTNU` 后才开始发送 MIDI，用户只打开 `SW2` 时会误以为无声。

本次修改：
- `Mini_IO.sdk/SeriesIODacSaw/src/rhythm_game.c`
  - 数码管扫描从 `Xil_Out8` 改为 `Xil_Out32`。
  - VS1003B 初始化保留寄存器写入，但不再以 SCI 读回作为主流程门槛，避免 MISO/DREQ 读回异常拖死主循环。
  - `SW2=1` 且 ELF 启动后自动 `StartGame()`，自动从头发送 Faded 主 MIDI；`BTNU` 仍可手动重开。

验证结果：
```text
SDK make all:
text=12932, data=376, bss=3132, dec=16440
```

已下载：
- 已运行 `scripts/download_seriesiodacsaw.tcl`，成功下载新的 `SeriesIODacSaw.elf`。
- 本次只改 C 程序，没有重新生成 bitstream。

### 2026-06-07 路线纠正：Faded 主 MIDI + MicroBlaze 控制逻辑

用户重申：
- 不要乱改音频主线。
- 音频播放路径应一直是 Faded 的主 MIDI 截取播放。
- 需要移植按键控制逻辑，使整体工程体现为 MicroBlaze 控制，而不是继续主要由 Verilog 自运行。

本次修正：
- `Mini_IO.sdk/SeriesIODacSaw/src/rhythm_game.c`
  - 移除当前活动播放路径对 `vs1003b_clip.h` MP3 烟测片段的依赖。
  - VS1003B 播放源恢复为 `vs1003b_midi_assets.h` 中的 `Vs1003bFadedMidi`。
  - 将原来的无限 VS1003B 播放器改为可被主循环调用的 `VsServiceFadedMidi()`。
  - `BTNU` 开始/重开游戏时同步从头发送 Faded MIDI。
  - `BTND` 暂停/继续游戏计时。
  - 修正 MicroBlaze 按键位定义：
    - `BTNL` 左轨。
    - `BTNC` 中轨。
    - `BTNR` 右轨。
  - 启用 MicroBlaze 主循环中的按键判定、分数、GOOD/BAD/MISS、数码管和 RGB 反馈。
  - 在 VS1003B 模式下避免普通 LED 刷新覆盖 GPIO0 channel 2 的 VS1003B bit-bang 总线。
- `Mini_IO.srcs/sources_1/bd/design_mb/hdl/design_mb_wrapper.v`
  - `SW2=1` 时，除 VS1003B 引脚外，数码管段选、位选和 RGB LED 也切换到 MicroBlaze AXI GPIO 输出。
  - `SW2=0` 时保留 RTL VGA/旧调试路径。
- `Mini_IO.sdk/SeriesIODacSaw/src/README.txt`
  - 明确当前正式音频源为 Faded 主 MIDI。
  - 明确 MP3 片段仅作为历史 VS1003B 烟测材料，不是当前播放源。

验证结果：
```text
SDK make all:
text=13380, data=376, bss=3132, dec=16888

Vivado impl:
VIVADO_BUILD_OK
Bitgen Completed Successfully
Route WNS ~= 1.917 ns
Route TNS = 0.000 ns
SHA256 = BA5AF5BB20650FD08AD9FBDA229A0CA5EBCF6CDCA5B21B78AE42CAD9AC6CE04D
```

已同步并下载：
- 新 bitstream 已复制到 `Mini_IO.sdk/design_mb_wrapper_hw_platform_0/download.bit`。
- 已运行 `scripts/program_bit_and_download_seriesiodacsaw.tcl`，成功下载新 bit + `SeriesIODacSaw.elf`。

当前测试方式：
- 打开 `SW2=1`，进入 MicroBlaze 控制模式。
- 按 `BTNU` 开始/重开 Faded chart，同时从头发送 Faded MIDI。
- 按 `BTND` 暂停/继续游戏计时。
- 使用 `BTNL/BTNC/BTNR` 控制左/中/右轨道。
- 数码管和 RGB 在 `SW2=1` 时来自 MicroBlaze。

后续注意：
- VGA 像素扫描/绘制仍由 RTL 保持稳定输出，这是 SoC 外设层；当前迁移重点是控制逻辑、按键判定、分数显示、RGB 反馈和 VS1003B 数据发送。
- 若后续要让 VGA 上的分数/判定文字也完全显示 MicroBlaze 状态，需要增加 AXI-Lite 寄存器或 framebuffer/tile buffer，而不是让 C 程序逐像素生成 VGA。

### 2026-06-07 VS1003B：MicroBlaze Faded MIDI 无声后切回 MP3 帧流

用户反馈：
- 下载/测试后似乎没有声音。

原因判断：
- 硬件 mux、SW2 接管和 SDK 编译链路没有明显断点。
- 最可疑变化是上一版把已验证较稳定的 MP3 帧流替换成了 `566 bytes` 的 Faded MIDI。
- 虽然 VS1003B 理论上可接收 MIDI byte-stream，但当前模块/初始化路径对 MIDI 播放不如 MP3 烟测稳定；课堂调试应优先恢复“确定有声”的 MP3 数据格式。

本次修改：
- 重新生成 `Mini_IO.sdk/SeriesIODacSaw/src/vs1003b_clip.h`
  - 数据源改为 `music/processed/Faded_20s_30s_first16k_vs1003b.mem`。
  - 长度 `16000 bytes`，文件头为 MP3 帧同步字节 `FF FB`。
- 修改 `Mini_IO.sdk/SeriesIODacSaw/src/rhythm_game.c`
  - MicroBlaze VS1003B 播放器重新发送 `Vs1003bClip`。
  - 保留 `vs1003b_midi_assets.h` 作为后续 Faded 主旋律 MIDI 研究资源，但当前板上播放不使用它。
  - 初始化增加 `SCI_AUDATA=0xBB81`，更贴近此前能发声的 VS1003B 初始化流程。
  - `SCI_VOL` 设置为 `0x1010`，比 `0x2020` 更响，但仍非最大音量。
- 更新 `Mini_IO.sdk/SeriesIODacSaw/src/README.txt`，明确当前活动播放源是 Faded MP3 16KB 片段。

验证结果：
```text
SDK make all:
text=21492, data=364, bss=3112, dec=24968
```

后续注意：
- 本次只改 MicroBlaze C/头文件，未改硬件；不需要重新生成 bitstream。
- 板上需要重新下载 `Mini_IO.sdk/SeriesIODacSaw/Debug/SeriesIODacSaw.elf`，否则仍运行旧的 MIDI 版或 bootloop。
- 若 Faded MP3 16KB 能恢复声音，再继续讨论如何把更长 MP3/MIDI 放入外部存储或由 MicroBlaze 分块读取。

### 2026-06-07 VS1003B：生成新 bitstream 并接入 Faded MIDI 候选

用户要求：
- 继续生成 bitstream。
- Faded 暂时不要求用户手动操作 FL Studio，先由 AI 尝试查找现成 MIDI，或用本地 MP3 作修改。

本次修改：
- Vivado 实现结果已生成新 bitstream：
  - `Mini_IO.runs/impl_1/design_mb_wrapper.bit`
  - `Mini_IO.sdk/design_mb_wrapper_hw_platform_0/design_mb_wrapper.bit`
  - `Mini_IO.sdk/design_mb_wrapper_hw_platform_0/download.bit`
  - 三者 SHA256 均为 `E2672B24216D1FA6BC273BA7EC6CC091F190A106DA137DEB6E64F98EE5BA654A`。
- 保留硬件侧 `SW2` 控制 VS1003B 引脚所有权的方案：
  - `SW2=1` 时由 MicroBlaze GPIO bit-bang 控制 VS1003B。
  - `SW2=0` 时回退旧 RTL VS1003B 播放器。
- 查找 Faded MIDI：
  - MidiShow 页面可看到 Faded 候选 MIDI 的轨道信息，但下载端返回 HTML，未作为工程资源使用。
  - MIDIWorld 尝试返回站点错误内容，未作为工程资源使用。
  - MIDI DB 成功下载 `faded_mididb_AUD_MB1504.mid`，文件头为 `MThd`，确认是标准 MIDI。
- 解析 `faded_mididb_AUD_MB1504.mid`：
  - Format 0，单轨多通道，原文件 `12161 bytes`。
  - 通道 3：`56` 个音，音域 MIDI `61-73`，较像主旋律/人声线。
  - 通道 7/11 是更密集的 saw lead/arpeggio，不适合课堂低密度演示。
- 修改 `scripts/make_single_track_midi_assets.py`：
  - 新增按 channel 抽取 MIDI 音符的函数。
  - 将 `faded_main_melody` 改为从 MIDI DB 候选文件的 channel 3 抽取。
  - 重新生成后 `faded_main_melody.mid` 为 `566 bytes`。
- 新增 `Mini_IO.sdk/SeriesIODacSaw/src/vs1003b_midi_assets.h`：
  - 将 566 字节 Faded MIDI 转为 MicroBlaze C 数组。
- 修改 `Mini_IO.sdk/SeriesIODacSaw/src/rhythm_game.c`：
  - MicroBlaze VS1003B 播放器改为发送 `Vs1003bFadedMidi`。
  - 修正发送循环，最后不足 `32 bytes` 的尾块也会发送，避免 MIDI 结尾事件丢失。
  - 移除原 16KB Canon MP3 烟测头文件引用，降低 ELF 体积。

验证结果：
```text
Vivado bitstream:
Bitgen Completed Successfully
SHA256 = E2672B24216D1FA6BC273BA7EC6CC091F190A106DA137DEB6E64F98EE5BA654A

SDK make all:
text=6034, data=364, bss=3114, dec=9512
```

后续注意：
- 当前 bitstream 里 MicroBlaze BRAM 仍是 `mb_bootloop_le.elf`，不是 `SeriesIODacSaw.elf`。
- 板上测试 MicroBlaze 播放器时，需要先下载新 bitstream，再通过 SDK/XSCT 下载 `Mini_IO.sdk/SeriesIODacSaw/Debug/SeriesIODacSaw.elf`。
- 可直接使用 `scripts/program_bit_and_download_seriesiodacsaw.tcl` 完成 bit + ELF 下载。
- 之后若只改 Faded MIDI、音量、发送逻辑或歌曲选择，优先重新编译并下载 ELF，不需要重新生成 bitstream；只有改管脚、AXI/BD、顶层 mux、RTL ROM 初始化等硬件内容才需要重新跑 Vivado。

### 2026-06-07 VS1003B：迁移到 MicroBlaze 软件播放器

用户要求：
- 将 VS1003B 音乐模块代码迁移为 MicroBlaze 核运行的软件控制。
- 用户明确表示不熟悉 FL Studio，提取 Faded 主音轨需要 AI 协助。

本次修改：
- `design_mb_wrapper.v`
  - 将 `vs_mb_mode` 从固定 `1'b0` 改为 `dip_switches_16bits_tri_i[2]`。
  - `SW2=1` 时，VS1003B 的 `XCS/XDCS/XRST/MOSI/SCLK` 由 MicroBlaze GPIO0 channel 2 控制。
  - `SW2=0` 时，仍保留旧 RTL VS1003B 播放器输出，便于回退。
- `Mini_IO.sdk/SeriesIODacSaw/src/rhythm_game.c`
  - 关闭 VS1003B 正弦测试：`VS1003B_SINE_OUTPUT_TEST=0`。
  - 进入 MicroBlaze VS1003B 播放器后等待 `SW2=1` 再初始化模块。
  - 使用 GPIO bit-bang 方式发送 SCI/SDI，按 `DREQ` 每次发送 `32 bytes`。
  - 当前播放数据源为 `vs1003b_clip.h` 中的短 MP3 byte-stream。
  - 音量寄存器 `SCI_VOL` 设置为 `0x2020`。
- `Mini_IO.sdk/SeriesIODacSaw/src/README.txt`
  - 补充 MicroBlaze VS1003B 模式的 SW2 用法和 GPIO 位分配。
- 新增 `文档/Faded主旋律提取_FLStudio协作指南.md`
  - 给出用户不熟悉 FL Studio 时的逐步协作流程：导入、分轨、NewTone、清理、Piano Roll、导出 MIDI、交给 AI 转工程资源。

验证结果：
- 已运行 SDK `make all`，`SeriesIODacSaw.elf` 编译通过。
- ELF size：`text=21432, data=364, bss=3108, dec=24904`。
- 未重新生成 Vivado bitstream；由于 `design_mb_wrapper.v` 的 VS1003B 引脚 mux 已改变，若要板上真正由 MicroBlaze 接管 VS1003B，后续需要重新生成并下载 bitstream。

### 2026-06-07 Canon 降速与 Faded 主 MIDI 提取路线

用户反馈：
- 当前 Canon 版本听感不错，但希望 BPM 从 `72` 改为 `36`。
- 需要分析如何把 Faded 的音乐提取为主 MIDI 并播放。

本次修改：
- 将 `scripts/make_single_track_midi_assets.py` 中 `canon_main_melody` 的 BPM 从 `72` 改为 `36`。
- 重新生成 `music/midi/` 中 Canon/Faded/校音相关 MIDI、mem、COE、vh 和音符表。
- 生成结果中 `canon_main_melody` 仍为 `961 bytes`，因此 `CANON_LAST=18'd960` 不需要修改。
- 在 `文档/主旋律MIDI加工与VS1003B播放说明.md` 中新增 Faded 主旋律 MIDI 提取方案：
  - 优先使用现成 MIDI 并清理为单轨主旋律。
  - 只有 MP3 时，用 FL Studio Stem Separation/NewTone 提取，再人工删除碎音、和声和伴奏。
  - 先在电脑上试听 MIDI，再接入 VS1003B，避免把扒谱问题误判成硬件协议问题。

验证结果：
- 已运行 `scripts/make_single_track_midi_assets.py`。
- 本次未重新生成 bitstream；若仍使用 RTL ROM 播放，更新后的 MIDI/ROM 要进入板卡仍需重新跑 Vivado 或后续迁移到 MicroBlaze 软件播放。

### 2026-06-07 VS1003B：校正音频主线为已有文件流式播放

用户补充：
- VS1003B 本身就是播放/解码音频文件的模块。
- 后续不应把主线放在 FPGA 纯手搓音频或人工捏波形上。
- 主要问题是如何把内存较大的音乐播放出来，需要学习参考例程的数据存储和分块播放思路。

本次修改：
- 在 `文档/主旋律MIDI加工与VS1003B播放说明.md` 增加“方向校正”和“大文件播放问题”。
- 明确短 MIDI 只是验证 VS1003B 链路的阶段性资源，后续主线应为已有 MIDI/MP3 等可解码数据的流式播放。
- 在 `README.md` 和 `文档/Verilog迁移为MicroBlaze控制程序方案.md` 中补充：MicroBlaze/硬件播放器应按 `DREQ` 分块发送 VS1003B 可解码 byte-stream。
- 记录参考例程的要点：`MP3.v` 负责 VS1003B 初始化和 SDI 发送，`track*.COE` 提供音乐数据，播放时必须遵守 `DREQ` 流控。

验证结果：
- 本次为方向性文档修正，未重新综合或生成 bitstream。

### 2026-06-04 MicroBlaze：补充常见内容迁移与免 bitstream 策略

用户要求：
- 把常见内容移植 MicroBlaze 的方案写进文档。
- 同步信息到 GitHub。

本次修改：
- 在 `README.md` 增加 MicroBlaze 迁移方向入口，说明哪些内容应从 RTL/ROM 转到 C 程序或外部数据。
- 在 `文档/Verilog迁移为MicroBlaze控制程序方案.md` 增加“常见内容迁移清单”和“避免反复生成 bitstream 的工作流”。
- 在 `文档/MicroBlaze_SoC实现说明.md` 增加 bitstream 生成慢的原因，以及如何通过软件侧迁移减少 Vivado 重跑。

验证结果：
- 本次为纯文档修改，未重新综合或生成 bitstream。

### 2026-06-04 Canon：十六分变奏降速

用户反馈：
- Canon 十六分变奏节奏太快。

本次修改：
- 保留完整十六分/快板变奏音符，不删音、不截短。
- 仅将 `canon_main_melody` 的 BPM 从 `96` 降为 `72`。
- MIDI 长度仍为 `961 bytes`，因此 `rhythm_video_audio.v` 中 `CANON_LAST=18'd960` 不需要修改。

验证结果：
```text
Vivado 2018.3 batch build passed
VIVADO_BUILD_OK
Bitgen Completed Successfully
Route WNS ~= 1.641 ns
Route TNS = 0.000 ns
SHA256 = 9B8050C43668CCDED135F4A7E75FEBE457468FD8B1F7985221C8A7191A1EE9E1
```

bitstream 已同步覆盖：
- `Mini_IO.runs/impl_1/design_mb_wrapper.bit`
- `Mini_IO.sdk/design_mb_wrapper_hw_platform_0/design_mb_wrapper.bit`
- `Mini_IO.sdk/design_mb_wrapper_hw_platform_0/download.bit`

### 2026-06-03 Canon：改为完整十六分音符快板变奏

用户反馈：
- 需要 Canon 的十六分音符变奏/快板部分。
- 要截取完整，不要只截普通欢快段。

本次修改：
- 发现 Mutopia 的 `mutopia_canon_in_d.mid` 只有简化旋律，没有真正完整的 0.25/0.125 拍快板变奏。
- 下载 mfiles 的原版 Canon MIDI：
  - `music/midi_import/mfiles_pachelbel_canon_in_d.mid`
- 在 `scripts/make_single_track_midi_assets.py` 中新增轻量 MIDI 解析器：
  - `extract_midi_track_notes(...)`
  - 可按 track 与 beat 区间截取旋律，并量化为小内存单轨 MIDI。
- Canon 当前截取：
  - 来源：mfiles MIDI 的 `Violin 1`
  - 区间：beat `72` 到 `88`
  - 内容：完整一轮十六分/快板变奏，保留单轨单音，不叠加 Violin 2/3 的延迟进入。
  - 音符数：`112`
  - 最短时值：`0.125 beat`
- 重新生成 Canon MIDI/ROM：
  - `canon_main_melody: 961 bytes, 241 32-bit words`
- `rhythm_video_audio.v`
  - `CANON_LAST` 更新为 `18'd960`。

验证结果：
```text
Vivado 2018.3 batch build passed
VIVADO_BUILD_OK
Bitgen Completed Successfully
Route WNS ~= 1.583 ns
Route TNS = 0.000 ns
SHA256 = 783E14FA8A5260C707373DC298EF0677B7EF999D1F9A8863BA90226C038DE425
```

bitstream 已同步覆盖：
- `Mini_IO.runs/impl_1/design_mb_wrapper.bit`
- `Mini_IO.sdk/design_mb_wrapper_hw_platform_0/design_mb_wrapper.bit`
- `Mini_IO.sdk/design_mb_wrapper_hw_platform_0/download.bit`

### 2026-06-03 Canon：从 Mutopia MIDI 提取欢快高潮主旋律

用户反馈：
- 手写 Canon 仍有点不像。
- 希望能由 AI 直接提取卡农主旋律 MIDI，或从网上找合适 MIDI，而不是继续手动在 FL Studio 中删音符。

本次修改：
- 下载公开 MIDI 来源：
  - `music/midi_import/mutopia_canon_in_d.mid`
  - 来源：Mutopia Project 的 Pachelbel Canon in D MIDI。
- 自动解析该 MIDI：
  - MIDI 格式 1，2 个 track。
  - 有效音乐轨 1 条，共 `138` 个音符。
  - 音域约 `F#3` 到 `F#5`。
- 选择更像“欢快高潮”的片段：
  - 取 beat `48.0` 到 `64.0` 左右的快速 1/8 音符段。
  - 保留单轨单音旋律，避免和弦/伴奏占用 ROM。
- `scripts/make_single_track_midi_assets.py`
  - Canon 改为这段提取旋律。
  - 保留 VS1003B 全局 `-1` 半音补偿。
- 重新生成 Canon MIDI/ROM：
  - `canon_main_melody: 362 bytes, 91 32-bit words`
- `rhythm_video_audio.v`
  - `CANON_LAST` 更新为 `18'd361`。

验证结果：
```text
Vivado 2018.3 batch build passed
VIVADO_BUILD_OK
Bitgen Completed Successfully
Route WNS ~= 1.348 ns
Route TNS = 0.000 ns
SHA256 = 28AC2EAEF145210195EC633112F960F5C27AB01BE9EACF50A84E2A1ABDF4C0D3
```

bitstream 已同步覆盖：
- `Mini_IO.runs/impl_1/design_mb_wrapper.bit`
- `Mini_IO.sdk/design_mb_wrapper_hw_platform_0/design_mb_wrapper.bit`
- `Mini_IO.sdk/design_mb_wrapper_hw_platform_0/download.bit`

### 2026-06-03 Faded/Canon：改为手写小内存主旋律 MIDI

用户要求：
- 保留 VS1003B C 大调校准方案。
- 根据用户提供的简谱和本地 MP3 参考，手写 Faded 与 Canon 主旋律。
- 注意内存占用要小。

本次修改：
- 保留 `SW14=1, SW2=1` 的 C 大调校音模式和 `VS1003_OUTPUT_TRANSPOSE_SEMITONES = -1` 半音补偿。
- `scripts/make_single_track_midi_assets.py`
  - Faded 改为按用户简谱整理的 A 小调单轨主旋律：前奏片段 + 副歌片段。
  - Canon 改为小体积单轨版本：先播放 D-A-Bm-F#m-G-D-G-A 的可识别低音走向，再进入上方旋律。
  - 两首都保持单音线条，不嵌入 MP3/PCM，不加多声部和弦，以减少 ROM 占用。
- 重新生成 `music/midi/` 中 Faded/Canon 的 `.mid`、`.mem`、`_1024.mem`、`.COE`、`.vh`、`_notes.md`。
- `rhythm_video_audio.v`
  - `FADE_LAST` 更新为 `18'd451`，对应 `faded_main_melody` 长度 `452 bytes`。
  - `CANON_LAST` 更新为 `18'd379`，对应 `canon_main_melody` 长度 `380 bytes`。

当前资源大小：
```text
faded_main_melody: 452 bytes, 113 32-bit words
canon_main_melody: 380 bytes, 95 32-bit words
vs1003_pitch_calibration: 162 bytes, 41 32-bit words
```

验证结果：
```text
Vivado 2018.3 batch build passed
VIVADO_BUILD_OK
Bitgen Completed Successfully
Route WNS ~= 1.212 ns
Route TNS = 0.000 ns
SHA256 = 7A00E8E38E226FD910B4F0183C47BA67B22E8400E351009987203BC6AD12E42E
```

bitstream 已同步覆盖：
- `Mini_IO.runs/impl_1/design_mb_wrapper.bit`
- `Mini_IO.sdk/design_mb_wrapper_hw_platform_0/design_mb_wrapper.bit`
- `Mini_IO.sdk/design_mb_wrapper_hw_platform_0/download.bit`

### 2026-06-03 VS1003B：按实测高半音加入全局 MIDI 补偿

用户反馈：
- 连续 C 大调校音音阶中，每个音听起来都比理论音高了半个音。

判断：
- 因为所有音都是统一高半音，这不像是单个音符频率表错误，而是 VS1003B 当前 MIDI 播放链路存在全局转调偏差。
- 处理策略是对生成进 ROM 的 MIDI note number 整体下移 1 个半音，让实际听感回到目标理论音高。

本次修改：
- `scripts/make_single_track_midi_assets.py`
  - 新增 `VS1003_OUTPUT_TRANSPOSE_SEMITONES = -1`。
  - `build_midi()` 在写入 Note On/Off 前对 MIDI note number 加该补偿。
  - 该补偿同时作用于 `faded_main_melody`、`canon_main_melody` 和 `vs1003_pitch_calibration`。
- 重新生成 `music/midi/` 下三组 MIDI/ROM/COE/音符说明文件。
- `README.md`、`music/midi/README.md`、`文档/按键与拨码开关作用分析.md` 已记录该补偿。

注意：
- 文档中的 C4/D4/... 仍表示“希望最终听到/测到”的目标音高。
- ROM 内实际 MIDI note number 已低半音，用来抵消当前模块实测高半音。
- 若后续手机调音器显示不是正好半音偏差，只需调整 `VS1003_OUTPUT_TRANSPOSE_SEMITONES` 或进一步引入 cents 级 pitch bend 补偿。

验证结果：
```text
Vivado 2018.3 batch build passed
VIVADO_BUILD_OK
Bitgen Completed Successfully
Route WNS ~= 1.121 ns
Route TNS = 0.000 ns
SHA256 = DB43B4C407706EB74F756AA69B1C54B79CD7B7BF41DBB3AD6AF663BAE9308A2E
```

bitstream 已同步覆盖：
- `Mini_IO.runs/impl_1/design_mb_wrapper.bit`
- `Mini_IO.sdk/design_mb_wrapper_hw_platform_0/design_mb_wrapper.bit`
- `Mini_IO.sdk/design_mb_wrapper_hw_platform_0/download.bit`

### 2026-06-03 VS1003B：校音模式改为连续 C 大调音阶

用户要求：
- 将上一次“拨码选择单个标准音”的方案改成一次生成并播放连续的 C 大调音阶。

本次修改：
- `scripts/make_single_track_midi_assets.py`
  - 将 `vs1003_pitch_calibration` 改为连续音阶 `C4 D4 E4 F4 G4 A4 B4 C5`。
  - BPM 改为 `72`，每个音约 1 拍，音符之间加入很短休止，便于调音器/频谱 App 分辨。
  - 重新生成 `music/midi/vs1003_pitch_calibration.mid`、`.mem`、`_1024.mem`、`.COE`、`.vh`、`_notes.md`。
  - `vs1003_pitch_calibration` 当前长度为 `162 bytes`，RTL 最后地址为 `18'd161`。
- `rhythm_video_audio.v`
  - VS1003B 校音模式固定读取 `vs1003_pitch_calibration_1024.mem`。
  - 移除运行路径中 `SW5..SW3` 作为 `pitch_select` 选择八个单音的逻辑。
  - 校音模式不再因 `SW5..SW3` 改变而重新初始化；`SW5..SW3` 继续只用于普通音游流速。
- `README.md` 与 `文档/按键与拨码开关作用分析.md`
  - 更新说明为：`SW14=1` 且 `SW2=1` 时连续循环播放 C 大调校音音阶。

最新校音方法：
- 打开 `SW14=1`、`SW2=1`。
- 不需要看 VGA，也不需要调 `SW5..SW3`。
- PHONE 输出应循环播放：

| 顺序 | 音名 | 理论频率 |
| ---: | --- | ---: |
| 1 | `C4` | `261.63 Hz` |
| 2 | `D4` | `293.66 Hz` |
| 3 | `E4` | `329.63 Hz` |
| 4 | `F4` | `349.23 Hz` |
| 5 | `G4` | `392.00 Hz` |
| 6 | `A4` | `440.00 Hz` |
| 7 | `B4` | `493.88 Hz` |
| 8 | `C5` | `523.25 Hz` |

验证结果：
```text
Vivado 2018.3 batch build passed
VIVADO_BUILD_OK
Bitgen Completed Successfully
Route WNS ~= 1.345 ns
Route TNS = 0.000 ns
SHA256 = EEC5D18D8D6028355151619F8D0BCC6EAD5774875439EDA47854461B23F9B694
```

bitstream 已同步覆盖：
- `Mini_IO.runs/impl_1/design_mb_wrapper.bit`
- `Mini_IO.sdk/design_mb_wrapper_hw_platform_0/design_mb_wrapper.bit`
- `Mini_IO.sdk/design_mb_wrapper_hw_platform_0/download.bit`

### 2026-06-03 README 与 VS1003B 多输入口校音模式

用户要求：
- 补充项目说明 README，并提交远程仓库。
- 设计几个输入口，用于检查频率/音调准不准，不依赖屏幕提示，直接分析。

本次修改：
- 新增 `README.md`：
  - 说明本项目基于 HUSTerCH / FengSheng_Hust 旧版 `Mini_IO` 工程继续开发。
  - 说明当前 MicroBlaze/VGA/VS1003B/J8 音频/音游功能。
  - 说明 VS1003B 接线、拨码、校音方法和关键文件。
- `scripts/make_single_track_midi_assets.py`
  - 新增 8 个固定标准音 MIDI：
    - `vs1003_pitch_0..7.mid`
    - `vs1003_pitch_0..7_1024.mem`
    - `vs1003_pitch_0..7_hex.COE`
    - `vs1003_pitch_0..7_notes.md`
  - 新增 `music/midi/vs1003_pitch_test_table.md`，记录拨码到频率的对应关系。
- `rhythm_video_audio.v`
  - `SW14=1` 时进入 VS1003B 校音模式。
  - `SW5..SW3` 在校音模式下作为 `pitch_select`，直接选择固定标准音。
  - `SW2=1` 负责启用 VS1003B 播放器。
  - 切换 `SW5..SW3` 时播放器会重新初始化并播放新标准音，便于手机调音器稳定测量。
- `文档/按键与拨码开关作用分析.md`
  - 更新 `SW14 + SW5..SW3 + SW2` 的校音模式说明。

校音输入口表：

| `SW14` | `SW2` | `SW5 SW4 SW3` | 输出 |
| --- | --- | --- | --- |
| `1` | `1` | `000` | `A3 = 220.00 Hz` |
| `1` | `1` | `001` | `C4 = 261.63 Hz` |
| `1` | `1` | `010` | `E4 = 329.63 Hz` |
| `1` | `1` | `011` | `A4 = 440.00 Hz` |
| `1` | `1` | `100` | `C5 = 523.25 Hz` |
| `1` | `1` | `101` | `E5 = 659.25 Hz` |
| `1` | `1` | `110` | `A5 = 880.00 Hz` |
| `1` | `1` | `111` | `C6 = 1046.50 Hz` |

分析方法：
- 不看 VGA 屏幕，只听 VS1003B 的 PHONE 输出。
- 用手机调音器测 `SW14=1, SW2=1` 下的固定音。
- 若所有固定音整体偏高/偏低，优先怀疑 VS1003B 模块晶振、时钟寄存器或初始化。
- 若固定音基本准确，但歌曲不像，优先修改 MIDI 乐谱/节奏。

验证结果：
```text
Vivado 2018.3 batch build passed
VIVADO_BUILD_OK
Bitgen Completed Successfully
Route WNS ~= 1.547 ns
Route TNS = 0.000 ns
SHA256 = E28866A65A829585E448953705039CD539A99202200AFA87002258EE6BF1E97B
```

bitstream 已同步覆盖：
- `Mini_IO.runs/impl_1/design_mb_wrapper.bit`
- `Mini_IO.sdk/design_mb_wrapper_hw_platform_0/design_mb_wrapper.bit`
- `Mini_IO.sdk/design_mb_wrapper_hw_platform_0/download.bit`

### 2026-06-03 VS1003B：新增标准音校准模式用于判断走音来源

用户反馈：
- 当前听感仍然音不准，询问是 MIDI 提取/乐谱问题还是 VS1003B 模块走音问题。
- 要求完善这部分内容，并完善日志。

本次判断：
- 如果所有音整体等比例偏高或偏低，才更像 VS1003B 模块时钟/合成走音。
- 如果只是旋律听起来不像、个别音走向不对、节奏不对，则更可能是 MIDI 乐谱/手工生成问题。
- 当前 Faded MIDI 不是从 MP3 中真实分离出来的主音轨，而是手工课堂单轨，因此“像不像原曲”首先应怀疑谱面。

本次修改：
- 新增 VS1003B 标准音校准 MIDI：
  - `music/midi/vs1003_pitch_calibration.mid`
  - `music/midi/vs1003_pitch_calibration_1024.mem`
  - `music/midi/vs1003_pitch_calibration_notes.md`
- 校准音序列：
  - `A4`，理论频率 `440.00 Hz`，持续 4 拍。
  - `C5`，理论频率约 `523.25 Hz`，持续 4 拍。
  - `E5`，理论频率约 `659.25 Hz`，持续 4 拍。
  - `A5`，理论频率 `880.00 Hz`，持续 4 拍。
  - 最后回到 `A4`，持续 8 拍。
- `rhythm_video_audio.v`
  - 新增 `vs1003_pitch_test = switches[14]`。
  - 新增 `vs1003_song_select`，当 `SW14=1` 时强制选择校准音 MIDI。
  - `vs1003b_mp3_rom_player` 新增第三个 ROM：`pitch_rom`。
  - 当 `song_select=2` 时，播放标准音校准 MIDI。

拨码使用：
- `SW2=1`：启用 VS1003B 播放。
- `SW14=1, SW2=1`：播放标准音校准序列。
- `SW14=0, SW2=1`：按 `SW0/SW1` 播放 Canon/Faded MIDI。

测试方法：
- 使用手机调音器靠近耳机/音箱听 `SW14=1, SW2=1` 的标准音。
- 若 `A4/C5/E5/A5` 都整体偏同一个方向，优先怀疑 VS1003B 时钟/初始化/模块晶振。
- 若标准音基本准，但 Faded/Canon 不像，优先修改 MIDI 乐谱本身，而不是继续排查 VS1003B 协议。

验证结果：
```text
Vivado 2018.3 batch build passed
VIVADO_BUILD_OK
Bitgen Completed Successfully
Route WNS ~= 1.751 ns
Route TNS = 0.000 ns
SHA256 = FBAF23ED223D20D5AFE64507C0A36361D5D00703CF6F27BCA53E652418F3F98C
```

bitstream 已同步覆盖：
- `Mini_IO.runs/impl_1/design_mb_wrapper.bit`
- `Mini_IO.sdk/design_mb_wrapper_hw_platform_0/design_mb_wrapper.bit`
- `Mini_IO.sdk/design_mb_wrapper_hw_platform_0/download.bit`

### 2026-06-03 VS1003B：导出音符表、提高音量、重写 Faded 课堂单轨

用户反馈：
- 当前音乐听着不像，要求说明音轨是如何提取的。
- 要求“解析当前 MIDI”和“重新生成更接近的 MIDI”同步进行。
- 要求音量调大到原来的约 3 倍。

本次说明：
- 当前 MIDI 不是从 MP3 中真正分离/提取出来的主音轨。
- 当前路线仍是参考工程式“单轨 MIDI -> ROM/mem -> VS1003B 播放”。
- 原先 `faded_main_melody` 是按用户简谱思路手写的 A 小调课堂演示版，因此听感不像原曲是正常现象。
- 本次先做更可控的手工校正版：把 Faded 从 A 小调课堂指法版转为 F# 小调钢琴单轨版，更接近熟悉的原曲调性感觉。

本次修改：
- `scripts/make_single_track_midi_assets.py`
  - 新增 `write_note_table()`，每次生成 MIDI 时同步导出可读音符表。
  - 新增 `write_padded_mem()`，每次生成 MIDI 时同步生成 RTL 实际读取的 1024 字节对齐 `.mem`。
  - Faded 音色从 GM program `80` 改为 `0`，即钢琴音色。
  - Faded 音符从 A 小调版改为 F# 小调版，例如开头为 `F#4 F#4 E4 F#4 A4 A4 G#4 A4 ...`。
  - MIDI velocity 提高到 `122..124`，接近满力度。
- 新增/更新可读音符表：
  - `music/midi/faded_main_melody_notes.md`
  - `music/midi/canon_main_melody_notes.md`
- `rhythm_video_audio.v`
  - VS1003B `SCI_VOL` 从 `0x0A0A` 改为 `0x0000`。
  - 注意：`SCI_VOL=0x0000` 是 VS1003B 寄存器意义上的最大音量，因此寄存器层面已没有继续放大的空间。

音量说明：
- VS1003B 的 `SCI_VOL` 每声道数值越小音量越大。
- 从 `0x0A0A` 到 `0x0000` 约等于增加 5 dB，不到严格 3 倍电压幅度。
- 同时提高 MIDI velocity 后，整体听感会明显大于上一版，但如果仍嫌小，只能通过外接音箱/耳放、模块模拟输出端或更改素材响度继续补偿。

验证结果：
```text
Vivado 2018.3 batch build passed
VIVADO_BUILD_OK
Bitgen Completed Successfully
Route WNS ~= 1.218 ns
Route TNS = 0.000 ns
SHA256 = 30855A6906616EFDAD89D8F3C849AB10C0E548B86ABCEDFC3D8D093932DD61A4
```

bitstream 已同步覆盖：
- `Mini_IO.runs/impl_1/design_mb_wrapper.bit`
- `Mini_IO.sdk/design_mb_wrapper_hw_platform_0/design_mb_wrapper.bit`
- `Mini_IO.sdk/design_mb_wrapper_hw_platform_0/download.bit`

### 2026-06-03 VS1003B：切换为参考例程式 MIDI 长旋律播放

用户反馈：
- 当前 Canon/Fade 各只能听到不到 1 秒，希望参考例程方式实现 20 到 30 秒左右的主旋律播放。
- 询问能否利用 FL Studio 21 完成 MP3 转 MIDI 并提取主旋律。

本次分析：
- 已确认 FL Studio 21 位于 `E:/music/FL64.exe`，但 FL/NewTone 的 MP3 转 MIDI 和主旋律提取属于 GUI/人工校音工作流，自动盲操作容易留下和弦、鼓点或错误音高。
- 参考 `文档/VGA_hw/MP3/*.COE` 的文件头为 `4D546864`，也就是 Standard MIDI 的 `MThd`，参考例程虽然目录叫 MP3，但核心思路实际是把很小的 MIDI byte-stream 放进 ROM 后送给 VS1003B。
- 当前 `music/midi/faded_main_melody.mid` 为 740 字节，PPQ=480，tempo=666666 us/qn，整体约 58.7 秒。
- 当前 `music/midi/canon_main_melody.mid` 为 345 字节，PPQ=480，tempo=625000 us/qn，整体约 20 秒。
- MIDI 文件很小不代表只能响一瞬间；VS1003B 会按 MIDI 事件里的 tempo/delta time 自己合成并保持音符时值。

本次修改：
- 新增并接入 1024 字节对齐的 MIDI ROM 数据：
  - `music/midi/canon_main_melody_1024.mem`
  - `music/midi/faded_main_melody_1024.mem`
- `rhythm_video_audio.v` 中 `vs1003b_mp3_rom_player` 保留原模块名，但实际数据源改为上述两个 MIDI ROM。
- `MP3_LEN` 改为 `1024`，`CANON_LAST=344`，`FADE_LAST=739`。
- `song_select` 接入 VS1003B 播放器，`active_song[0]=0` 播放 Canon，`active_song[0]=1` 播放 Fade。
- `SW2` 仍作为 VS1003B 播放使能；切换歌曲时播放器会重新复位并初始化 VS1003B。
- MIDI 数据发送完成后不再马上循环：Canon 使用约 20 秒等待，Fade 使用约 30 秒等待，避免不断重复发送 MIDI 头导致听感像短促碎片。
- 初始化保持当前已验证有声的慢速 VS1003B 流程：硬复位等待、`SCI_MODE=0x0804`、`SCI_CLOCKF=0x9800`、`SCI_AUDATA=0xBB81`、`SCI_BASS=0x0055`、`SCI_VOL=0x0A0A`。

验证结果：
```text
Vivado 2018.3 batch build passed
VIVADO_BUILD_OK
Bitgen Completed Successfully
Route WNS ~= 1.164 ns
Route TNS = 0.000 ns
SHA256 = E10C92C9FF813A123443814F4A7E1DF57F8A28FE7474680D8419509E4FA2F59C
```

bitstream 已同步覆盖：
- `Mini_IO.runs/impl_1/design_mb_wrapper.bit`
- `Mini_IO.sdk/design_mb_wrapper_hw_platform_0/design_mb_wrapper.bit`
- `Mini_IO.sdk/design_mb_wrapper_hw_platform_0/download.bit`

上板测试说明：
- 下载最新 `Mini_IO.sdk/design_mb_wrapper_hw_platform_0/download.bit`。
- 打开 `SW2` 启用 VS1003B。
- `SW0=1, SW1=0` 时选择 Canon MIDI 主旋律。
- `SW1=1` 时选择 Fade MIDI 主旋律。
- 若听到开头后后续安静，不一定是停止播放，可能是 MIDI 主旋律本身留有长拍/休止；需要听完整约 20 到 30 秒窗口再判断。

### 2026-06-03：主旋律单轨 MIDI 资源生成与 VS1003B 接入

用户要求：
- 自动完成 MIDI 生成选择，并完成后续操作。
- 目标是只听歌曲主旋律/主音轨部分，参考 `文档/VGA_hw` 完整工程的加工方式。

参考工程结论：
- `文档/VGA_hw/MP3/*.COE` 开头为 `4D546864`，即 MIDI 文件头 `MThd`。
- 参考工程报告提到：直接将 MP3 转 COE 体积太大，最终使用单音轨 MIDI。
- 因此本工程后续优先采用“单轨 MIDI -> COE/mem -> VS1003B 播放”的路线。

本次新增：
- `scripts/make_single_track_midi_assets.py`
- `music/midi/faded_main_melody.mid`
- `music/midi/faded_main_melody.mem`
- `music/midi/faded_main_melody_hex.COE`
- `music/midi/canon_main_melody.mid`
- `music/midi/canon_main_melody.mem`
- `music/midi/canon_main_melody_hex.COE`
- `music/midi/README.md`
- `文档/主旋律MIDI加工与VS1003B播放说明.md`

RTL 修改：
- `Mini_IO.srcs/sources_1/new/rhythm_video_audio.v` 中 `vs1003b_mp3_rom_player` 的 ROM 数据源切换为 `music/midi/faded_main_melody.mem`。
- `MP3_LEN` 从 `160079` 改为 `740`。
- `SCI_VOL` 设置为 `0x7070`，降低 VS1003B 输出音量。
- `CMD_MP3_BYTE` 保留原名，但现在也用于发送 VS1003B MIDI byte-stream。

注意：
- 本次不是从混音 MP3 自动扒谱，而是生成课堂演示用的单轨主旋律 MIDI。
- 若后续追求更接近原曲，需要用 FL Studio/Cubase/Melodyne 等工具从音频转谱并人工校正后，再导出单轨 MIDI。

验证：
- 中断恢复后已检查资源和 RTL 修改落盘。
- 已运行轻量综合：
  - 命令：`vivado.bat -mode batch -source scripts/synth_rhythm_only.tcl`
  - 结果：`RHYTHM_ONLY_SYNTH_OK`
  - `faded_main_melody.mem` 被 `$readmemh` 成功读取。
  - 综合结果：0 errors, 0 critical warnings。
- 已运行完整 bitstream：
  - 命令：`vivado.bat -mode batch -source scripts/build_vivado.tcl`
  - 结果：`VIVADO_BUILD_OK`
  - `Bitgen Completed Successfully`
  - bitstream 已复制到 `Mini_IO.sdk/design_mb_wrapper_hw_platform_0/download.bit`
  - `download.bit` 时间：2026-06-03 10:09:58
  - 文件大小：3825902 bytes
  - 时序：WNS 1.217 ns，TNS 0.000 ns，WHS 0.038 ns，THS 0.000 ns。
  - 资源摘要：Slice LUTs 11852/63400 = 18.69%，Slice Registers 5473/126800 = 4.32%，Block RAM Tile 8/135 = 5.93%。

### 2026-06-02：补充 MicroBlaze SoC 文档与迁移方案

用户要求：
- 明确把“使用 MicroBlaze”写入项目文档。
- 额外准备一份文档，描述如何把当前 Verilog 音游逻辑迁移为 MicroBlaze 核程序控制。
- 方案中必须覆盖 VGA、VS1003B 模块控制、按键中断，并体现这些功能由 MicroBlaze 统一实现/管理。

新增文档：
- `文档/MicroBlaze_SoC实现说明.md`
- `文档/Verilog迁移为MicroBlaze控制程序方案.md`

主要结论：
- 当前工程顶层为 `design_mb_wrapper`，内部包含 `design_mb` MicroBlaze Block Design，具备 SoC 架构基础。
- 后续答辩建议表述为：MicroBlaze 作为系统控制核心，通过 AXI 管理 GPIO、SPI、Timer、中断、VGA/音频自定义外设。
- 迁移目标不是让 C 程序逐像素产生 VGA，而是由 MicroBlaze 控制画面内容和游戏状态，硬件外设保持 VGA 扫描时序。
- VS1003B 推荐迁移为 MicroBlaze 通过 AXI Quad SPI + GPIO 软件驱动。
- BTNL(P17)、BTNC(N17)、BTNR(M17) 建议通过 AXI GPIO 中断进入 MicroBlaze，并由 Timer tick 统一完成 GOOD/BAD/MISS 判定。

验证：
- 本次仅新增/更新文档，未修改 RTL、XDC、SDK，也未重新综合或生成 bitstream。

## 工程定位

- 当前工程根目录：`F:\FPGA\mircoCom\Genneral\Mini_IO`
- 主要 RTL：`Mini_IO.srcs\sources_1\new\rhythm_video_audio.v`
- 顶层封装：`Mini_IO.srcs\sources_1\bd\design_mb\hdl\design_mb_wrapper.v`
- 约束文件：`Mini_IO.srcs\constrs_1\new\adda.xdc`
- 谱面文本目录：`charts`
- 谱面生成脚本：`scripts\generate_charts.ps1`
- 最新下载 bitstream：`Mini_IO.sdk\design_mb_wrapper_hw_platform_0\download.bit`

## 构建与验证命令

轻量 RTL 综合：

```powershell
cd F:\FPGA\mircoCom\Genneral\Mini_IO
& "D:\Xilinx\Vivado\2018.3\bin\vivado.bat" -mode batch -source scripts\synth_rhythm_only.tcl
```

完整生成 bitstream：

```powershell
cd F:\FPGA\mircoCom\Genneral\Mini_IO
& "D:\Xilinx\Vivado\2018.3\bin\vivado.bat" -mode batch -source scripts\build_vivado.tcl
```

同步 bitstream 到 SDK 下载路径：

```powershell
Copy-Item -LiteralPath Mini_IO.runs\impl_1\design_mb_wrapper.bit -Destination Mini_IO.sdk\design_mb_wrapper_hw_platform_0\download.bit -Force
Copy-Item -LiteralPath Mini_IO.runs\impl_1\design_mb_wrapper.bit -Destination Mini_IO.sdk\design_mb_wrapper_hw_platform_0\design_mb_wrapper.bit -Force
```

## 当前硬件交互约定

### 拨码开关

| 开关 | 当前作用 |
| --- | --- |
| `SW0` | 选择并启用 Canon 音乐/谱面，前提是 `SW1=0` |
| `SW1` | 选择并启用 Fade 音乐/谱面，优先级高于 `SW0` |
| `SW2` | 启用 VS1003B sine demo/debug |
| `SW3..SW5` | 音游流速选择，`SW5` 为高位，`SW3` 为低位 |
| `SW15` | 暂停，拨上暂停，拨下继续 |

流速表：

| `SW5 SW4 SW3` | 流速 |
| --- | --- |
| `000` | 0.75x |
| `001` | 1.00x |
| `010` | 1.25x |
| `011` | 1.50x |
| `100` | 1.75x |
| `101` | 2.00x |
| `110` | 2.50x |
| `111` | 3.00x |

### 按键

| 物理按键 | 管脚 | 当前作用 |
| --- | --- | --- |
| `BTNL` | `P17` | 左轨道 |
| `BTNC` | `N17` | 中轨道 |
| `BTNR` | `M17` | 右轨道 |
| `BTNU` | `M18` | 音量加 |
| `BTND` | `P18` | 音量减 |

RTL 中的三轨映射：

```verilog
wire [2:0] lane_button_raw = {buttons[3], buttons[0], buttons[2]};
```

即 `game_buttons[0] = BTNL`，`game_buttons[1] = BTNC`，`game_buttons[2] = BTNR`。

## 修改流水

### 2026-06-02 早期：阅读参考例程与 VS1003B

用户要求：

- 阅读当前工作区和文档区 `Digital_Logic_FPGA_final_hw`。
- 分析参考例程音频输出方式。
- 确认是否使用 VS1003B 外部音频模块、接口与连线。

结论：

- 参考例程使用外部 VS1003B 音频解码模块，不是单纯 FPGA 管脚直接模拟高保真音频。
- VS1003B 需要 SPI/SCI/SDI 控制线，并需要模块自身耳机/音频输出端接耳机或音箱。
- 用户手头模块引脚顺序为：`XDCS XCS DREQ SCLK MOSI MISO XRST GND 5V`。
- 已调整为尽量集中、有序地使用一组 PMOD 线连接 VS1003B。

VS1003B 相关注意：

- `XCS` 用于 SCI 寄存器访问。
- `XDCS` 用于 SDI 数据/测试命令传输。
- `DREQ` 必须等待为高后再继续发送数据或命令。
- `MOSI/SCLK/MISO` 为 SPI。
- `XRST` 为硬件复位。
- `GND` 必须共地。
- `5V` 需要从板上可用 5V 电源针脚接入，不能从普通 FPGA IO 当电源。

### 2026-06-02：J8 音频、Canon 与 Fade

用户要求：

- 将当前音频改为播放完整版 Canon。
- 音调要严格按资料确认音阶频率。
- 后续加入 Fade，使用拨码选择歌曲。
- 音色刺耳，需要优化。

已实现：

- 在 `rhythm_video_audio.v` 内置 DDS/sine 方式发声。
- 使用 50 kHz 音频 sample tick，按 `phase_step = freq * 2^32 / 50000` 计算音高。
- 内置 Canon 与 Fade 两套音乐逻辑。
- `SW0` 选择 Canon，`SW1` 选择 Fade。
- J8 输出为单声道 PWM/PDM 风格音频。

重要判断：

- J8 适合简单电子音，不适合高保真真实音乐。
- 如果听起来“不像原曲”，原因通常不是音高表随机错误，而是音色、和声、伴奏简化、PWM 滤波和耳机负载造成的失真。
- 若整体音高等比例偏移，要优先确认板上实际输入时钟是否为 100 MHz。

### 2026-06-02：版权与 Fade 简谱处理

用户要求：

- 使用 Fade/Faded 熟悉主旋律。
- 用户提供了简谱文本和图片。

处理原则：

- 避免直接完整复刻受版权保护的商业歌曲长段内容。
- 使用用户给出的课堂演示简谱思路，做简化电子旋律。
- 重点保证课堂演示能听出主题轮廓，而不是做商业级还原。

### 2026-06-02：音游 VGA 方案

用户要求：

- 即使暂时没有 VGA 屏幕，也先按音游方案完成相关模块。
- 音游改为 3key。
- 左中右分别对应 `BTNL/BTNC/BTNR`，其中 `BTNL=P17`，`BTNC=N17`，`BTNR=M17`。
- 判定分为 `GOOD/BAD/MISS`。
- 颜色：`GOOD=绿`，`BAD=蓝`，`MISS=红`。
- 画面中间三轨，两侧类似菜单栏，包含选歌、流速、分数、按键提示等。

已实现：

- VGA 三轨音游界面。
- 左侧 UI：歌曲选择、按键说明、VS1003B demo 状态。
- 右侧 UI：流速、BPM、音量、分数、判定、按键功能提示。
- 中间三轨显示 note 与 hold。
- 判定线只保留一条准线。
- RGB LED 也按判定显示：绿/蓝/红。

当前画面注意：

- 左中右按键统一黑白，不再按三轨分别上色。
- 判定颜色只用于判定线、右侧 judge 指示和 RGB LED。

### 2026-06-02：谱面文本化

用户要求：

- 谱面可由玩家自制修改。
- 专门提供可编辑的文本谱面。
- 演示产品谱面密度降低到原来的约 1/4。

已实现：

- 新增 `charts\canon_demo.chart`
- 新增 `charts\fade_demo.chart`
- 新增 `charts\README.md`
- 新增生成脚本 `scripts\generate_charts.ps1`
- 生成 Verilog include：`Mini_IO.srcs\sources_1\new\rhythm_charts.vh`

谱面格式：

```text
step lanes [hold]
```

示例：

```text
12 C C:24
28 . R:18
```

含义：

- 第一列：step，范围 `0..63`。
- 第二列：轨道，`L/C/R`，可写和弦如 `LC`、`CR`、`LCR`，休止用 `.` 或 `-`。
- 第三列可选：hold，格式为 `lane:length`。

修改谱面后需要运行：

```powershell
pwsh scripts\generate_charts.ps1
```

### 2026-06-02：hold 长条

用户要求：

- 加入 hold 长条功能。
- hold 读条不要被按键反馈影响。

已实现：

- `rhythm_game_core` 新增 `hold_tracks`。
- 谱面文本支持 `C:24`、`R:18` 等 hold 定义。
- hold 到判定线时，按住对应按键可持续得少量分；松开或未按会 miss。
- 双押或多轨同时判定时，会取较差的总体判定，避免灯光冲突。

最新视觉调整：

- hold 颜色改为更白的浅灰，便于看清。
- 按键按下不再刷亮整条轨道，只在判定线上下显示小方块。

### 2026-06-02：暂停功能

用户要求：

- 加入暂停功能和对应数码显示。

已实现：

- `SW15` 暂停。
- 暂停时谱面滚动、判定、分数、combo、歌曲进度冻结。
- 暂停时音频静音，但不会清零歌曲进度；恢复后继续播放。
- VGA 右侧显示 `PAUSE` 与 `SW15`。
- 七段数码管最左侧暂停时显示 `P`。

源码位置：

- `game_paused = switches[15]`
- `audio_playing = audio_enabled && !game_finished && !game_paused`
- `rhythm_game_core` 新增 `paused` 输入。
- `rhythm_sevenseg` 新增 `paused` 输入。

### 2026-06-02：音量控制

用户反馈：

- VOL1 仍然很大。
- 需要先降到原来的 10%，随后又要求再变成原来的 1/4。

已实现：

- `BTNU` 音量加。
- `BTND` 音量减。
- 默认上电为 `VOL1`。
- 最新音量表已非常低：

| 档位 | 幅度比例 |
| --- | --- |
| `VOL0` | 静音 |
| `VOL1` | 约 0.59% |
| `VOL2` | 约 0.98% |
| `VOL3` | 约 1.17% |
| `VOL4` | 约 1.56% |
| `VOL5` | 约 1.95% |
| `VOL6` | 约 2.15% |
| `VOL7` | 约 2.54% |

注意：

- 这里的比例是对 RTL 内部 sample delta 的缩放，不等同于人耳听感线性比例。
- 如果仍然太响，可以继续降低 `apply_volume()` 中的缩放项。
- 如果耳机插入方式不稳定，可能导致左右声道/地线接触异常，听感会严重失真。

### 2026-06-02：VS1003B 内置短 demo

用户要求：

- 先制作内置短 demo。
- 完成 VS1003B 模块布线调整和代码撰写。
- 确认是否需要其他文件。

已实现：

- `rhythm_video_audio.v` 中加入 `vs1003b_sine_demo`。
- `SW2` 启用 VS1003B demo/debug。
- 使用 SCI 写 `MODE`、`CLOCKF`、`VOL`。
- 使用 sine test 命令产生短音 demo。

排查结论：

- 当前 VS1003B demo 是 sine test，不是 MP3/PCM 正式播放。
- sine test 的 `n` 不是 MIDI 音符号，不能精确表达完整 Canon/Fade。
- 若要让 VS1003B 播放真正音乐，建议后续发送 PCM/MP3/MIDI-like 数据，而不是继续靠 sine test 拼旋律。

已调低 VS1003B 音量：

- `SCI_VOL = 0x58/0x58`

### 2026-06-02：数码管含义

当前七段数码管扫描逻辑：

| 扫描位 | 内容 |
| --- | --- |
| `an[0]..an[3]` | score 的低 4 位 BCD 十进制数字 |
| `an[4]..an[5]` | combo 的低/高 nibble |
| `an[6]` | judgement 数值 |
| `an[7]` | 普通状态为 0，暂停时显示 `P` |

如果用户说“前 4 位”指物理左侧 4 位，则它们主要是调试状态：暂停/判定/combo。

## 最新构建记录

### 2026-06-02 21:53：VS1003B 内置 MP3 播放

用户要求：

- 继续实现，让 VS1003B 播放前面加工好的 MP3 文件。

已实现：

- 新增并接入 `vs1003b_mp3_rom_player`。
- 顶层 VS1003B 实例由旧的 PCM/WAV 流播放器切换为 MP3 ROM 播放器。
- 使用 `music\processed\The_O_Neill_Brothers_-_Canon_In_D__Piano__20s_30s_vs1003b.mem` 作为内置 MP3 字节 ROM。
- MP3 片段长度：`160079` bytes。
- VS1003B 初始化流程：
  - 硬复位 `XRST`。
  - 等待 `DREQ`。
  - SCI 写 `MODE = 0x0800`，普通 decode 模式。
  - SCI 写 `CLOCKF = 0x6000`。
  - SCI 写 `VOL = 0x5858`。
  - 进入 MP3 byte-stream 发送。
- 播放流程：
  - 仅在 `DREQ=1` 时向 `XDCS/MOSI/SCLK` 发送一个 MP3 字节。
  - MP3 数据发完后额外发送 `2048` 个 `0x00` flush 字节。
  - 播放完成后进入 `ST_DONE`。

当前开关：

| 开关组合 | VS1003B 行为 |
| --- | --- |
| `SW0=1, SW1=0, SW2=1` | 播放 Canon 20s 到 30s MP3 片段 |
| 仅 `SW2=1` | 不播放，避免单独测试音误响 |
| `SW1=1, SW2=1` | 暂不播放 Faded，避免内置 399 KB ROM 资源压力 |

注意：

- 当前只接入 Canon MP3 片段；Faded 片段已加工但尚未内置。
- 源码中旧的 `vs1003b_pcm_player` 和 `vs1003b_sine_demo` 模块仍保留但未接入顶层，后续可清理。
- 轻量综合中间报告曾显示大 ROM 为 LUT，但完整实现结果显示最终使用了 BRAM。

验证：

```text
RHYTHM_ONLY_SYNTH_OK
VIVADO_BUILD_OK
Bitgen Completed Successfully
```

实现资源摘要：

```text
Slice LUTs: 34633 / 63400 = 54.63%
Block RAM Tile: 8 / 135 = 5.93%
Route WNS: 1.470
Route TNS: 0.000
```

最新 bitstream：

```text
F:\FPGA\mircoCom\Genneral\Mini_IO\Mini_IO.sdk\design_mb_wrapper_hw_platform_0\download.bit
LastWriteTime: 2026-06-02 21:53:50
Size: 3825902 bytes
```

### 2026-06-02 17:31 后：MP3 片段加工

用户要求：

- `music` 目录里已有 MP3 文件。
- 截取 20s 到 30s，并加工成能给 VS1003B 播放的文件。

已处理文件：

```text
music\Alan Walker - Faded.mp3
music\The O'Neill Brothers - Canon In D (Piano).mp3
```

输出目录：

```text
music\processed
```

输出内容：

| 文件 | 大小 | 说明 |
| --- | ---: | --- |
| `Alan_Walker_-_Faded_20s_30s_vs1003b.mp3` | 399360 bytes | 20s 到 30s 帧级截取，320 kbps |
| `The_O_Neill_Brothers_-_Canon_In_D__Piano__20s_30s_vs1003b.mp3` | 160079 bytes | 20s 到 30s 帧级截取，128 kbps |

同时生成：

- `.mem`：一行一个十六进制字节，可供 `$readmemh` 使用。
- `.vh`：长度常量和来源说明。
- `processing_report.json`：机器可读处理报告。
- `README.md`：本次音频处理说明。

注意：

- 当前环境没有 `ffmpeg/ffprobe` 或 MP3 编码库，所以本次没有重编码降码率，只做 MP3 帧级截取。
- 这些 MP3 片段可作为 VS1003B SDI byte-stream 播放素材，但尚未接入 RTL 播放器。
- 若要内置进 FPGA ROM/BRAM，Faded 的 399 KB 仍然偏大；Canon 的 160 KB 相对更可行，但仍需评估资源。
- 后续若能使用编码器，建议转为 mono、16 kbps 到 32 kbps 的短 MP3 demo。

### 2026-06-02 17:03

修改内容：

- hold 颜色更白。
- 按键反馈只显示判定线附近小方块。
- 新增 `SW15` 暂停。
- 暂停时数码管显示 `P`。
- 音量整体降到上一版约 1/4。

验证：

```text
RHYTHM_ONLY_SYNTH_OK
VIVADO_BUILD_OK
```

最新 bitstream：

```text
F:\FPGA\mircoCom\Genneral\Mini_IO\Mini_IO.runs\impl_1\design_mb_wrapper.bit
F:\FPGA\mircoCom\Genneral\Mini_IO\Mini_IO.sdk\design_mb_wrapper_hw_platform_0\download.bit
```

文件大小：

```text
3825902 bytes
```

时间：

```text
2026-06-02 17:03:04
```

## 后续协作注意事项

- 不要把 `BTNL/BTNC/BTNR` 映射改反，用户反复强调 `P17` 是左键，`M17` 是右键。
- 不要把 GOOD/BAD/MISS 三色用于轨道本身；三色用于判定。
- 不要让按键反馈覆盖整条轨道，这会影响 hold 读条。
- 修改谱面应优先改 `charts/*.chart`，再运行生成脚本，不要直接手改 `rhythm_charts.vh`。
- J8 音频的音质有限，若追求真正音乐，应优先走 VS1003B 的真实音频数据流或外部 DAC。
- VS1003B sine test 只能做短 demo，不适合精确旋律播放。
- 每次重要修改后，请在本文件追加一条日志，并记录是否跑过轻量综合和完整 bitstream。

### 2026-06-03 VS1003B 无声排查

现象：
- 用户反馈 VS1003B 依旧没有声音。

当前代码分析：
- `rhythm_video_audio.v` 中 `switches[2]` 用作 `vs1003_player_enabled`，即 `SW2=1` 时启动 RTL 内置 MIDI/MP3 byte-stream 播放器。
- `design_mb_wrapper.v` 中同一个 `dip_switches_16bits_tri_i[2]` 又被用作 `vs_mb_mode`，并在 `vs_mb_mode=1` 时把 `VS_MOSI/VS_SCLK/VS_XCS/VS_XDCS/VS_XRST` 从 RTL 播放器切换到 `mb_led_16bits_tri_o`。
- 因此打开 `SW2` 后，RTL 播放器虽然启动，但 VS1003B 物理引脚被切到 MicroBlaze LED GPIO 输出，当前 MicroBlaze 软件并没有实现 VS1003B SPI 协议，导致模块收不到有效初始化和音频数据。
- 同时发现 `Mini_IO.sdk/design_mb_wrapper_hw_platform_0/download.bit` 与 `Mini_IO.runs/impl_1/design_mb_wrapper.bit` 哈希不一致，存在下载到板上的 bitstream 不是最新实现结果的风险。

本次修改：
- 在 `Mini_IO.srcs/sources_1/bd/design_mb/hdl/design_mb_wrapper.v` 中将 `vs_mb_mode` 固定为 `1'b0`。
- 保留 MicroBlaze 相关线网，但在没有真实 MicroBlaze VS1003B 驱动前，VS1003B 物理引脚始终由 RTL 播放器驱动。

验证结果：
- 已重新运行完整 Vivado bitstream 生成，结果为 `VIVADO_BUILD_OK`。
- 新 bitstream 已同步到：
  - `Mini_IO.runs/impl_1/design_mb_wrapper.bit`
  - `Mini_IO.sdk/design_mb_wrapper_hw_platform_0/design_mb_wrapper.bit`
  - `Mini_IO.sdk/design_mb_wrapper_hw_platform_0/download.bit`
- 三个 bit 文件 SHA256 均为 `4FF4FC18EB059E6B28A2701E6D94D3C7EACED4647566232A8F41C3C381B027D7`。
- 时序满足：`WNS=1.189ns`，`TNS=0.000ns`，`WHS=0.027ns`，`THS=0.000ns`。
- 资源摘要：`Slice LUTs=11853`，`Slice Registers=5473`，`Block RAM Tile=8`。

后续要求：
- `SW2=1` 只表示启动当前 RTL VS1003B 播放器，不再切换引脚所有权。
- 若未来要改成 MicroBlaze/SOC 方式控制 VS1003B，需要先实现 MicroBlaze 侧 SPI/GPIO/DREQ 驱动，再重新设计引脚所有权切换，不要直接复用 `SW2` 抢线。
- 完整 bitstream 生成后，应把新的 `design_mb_wrapper.bit` 同步复制到 SDK 平台目录中的 `design_mb_wrapper.bit` 和 `download.bit`，并核对哈希一致。

### 2026-06-03 VS1003B 二次无声排查、black 曲绘与 RGB 判定灯修正

用户反馈：
- 修正顶层抢线后 VS1003B 依旧没有声音。
- `scripts/pictures` 中已提供带 `black` 后缀的新曲绘图片，需要替换轨道背景曲绘。
- 用户已自行处理图片变暗，不希望 RTL 再对轨道背景做蒙黑/灰度处理。
- 实测三色判定灯中 `MISS` 显示为蓝色，`BAD` 显示为红色，需要修正。

本次分析：
- 当前 VS1003B 播放路径原本接入的是 `music/midi/faded_main_melody.mem`，这不是 MP3 帧，而是 740 字节 MIDI byte-stream。
- 如果具体 VS1003B 模块/初始化路径不接受 MIDI，或 MIDI 播放太短太轻，就会表现为“无声”。
- 为了先排除硬件接线、供电、DREQ、SPI 时序问题，本次把 `SW2` 下的 VS1003B 输出临时切换为芯片内建 sine test。该测试不依赖 MP3/MIDI 文件，适合作为硬件通断测试。
- 轨道背景原 RTL 使用 `album_gray` 将曲绘转成灰度，这会覆盖用户 black 图片中的颜色处理。
- RGB 灯物理通道与代码原假设相反：原代码 `BAD=001`、`MISS=100` 时，用户实测为 `BAD` 红、`MISS` 蓝，所以需要交换 bad/miss 的输出码。

本次修改：
- `rhythm_video_audio.v` 顶层 VS1003B 实例由 `vs1003b_mp3_rom_player` 改为 `vs1003b_sine_demo`，`SW2=1` 时播放 VS1003B 内建测试音。
- `track_bg_r/g/b` 改为直接取 `album_art_rgb[11:8] / [7:4] / [3:0]`，不再转灰度。
- `diag_rgb` 判定灯修正为：`GOOD=010`，`BAD=100`，`MISS=001`，以匹配当前板上实际颜色。
- 使用 `scripts/pictures/canon_raw_black.png` 和 `scripts/pictures/fade_raw_black.png` 重新生成：
  - `generated/album_art/canon_track_bg_index.mem`
  - `generated/album_art/canon_track_bg_palette.mem`
  - `generated/album_art/fade_track_bg_index.mem`
  - `generated/album_art/fade_track_bg_palette.mem`
- 转换规格仍为 `120x192`、`64` 色 indexed、`fit=cover`，保持原比例并居中裁切为音轨背景所需的竖向区域。

验证结果：
- 已重新运行完整 Vivado bitstream 生成，结果为 `VIVADO_BUILD_OK`。
- 新 bitstream 已同步到：
  - `Mini_IO.runs/impl_1/design_mb_wrapper.bit`
  - `Mini_IO.sdk/design_mb_wrapper_hw_platform_0/design_mb_wrapper.bit`
  - `Mini_IO.sdk/design_mb_wrapper_hw_platform_0/download.bit`
- 三个 bit 文件 SHA256 均为 `3EF6FBF5361BF866F6C0B701E178645E6E48E982143E18ABAE15CD0B42EF618B`。
- 时序满足：`WNS=0.858ns`，`TNS=0.000ns`，`WHS=0.073ns`，`THS=0.000ns`。
- 资源摘要：`Slice LUTs=11688`，`Slice Registers=5421`，`Block RAM Tile=8`。

上板测试说明：
- 打开 `SW2` 后应听到 VS1003B 的内建测试音序列。
- 若仍然完全无声，优先检查模块供电、GND、耳机/音频口、`DREQ` 是否为高、`XRST` 是否拉高，以及 PMOD 引脚顺序是否与 `XDCS XCS DREQ SCLK MOSI MISO XRST GND 5V` 一致。
- 若 sine test 有声音，再切回 MP3/MIDI 数据流；若 sine test 无声，不应继续优先怀疑乐谱或 MIDI 文件。

### 2026-06-03 VS1003B DREQ 容错诊断版

用户反馈：
- 已确认 JA 接线和线序没有问题，但 `SW2` 下 VS1003B 仍无反应。

本次分析：
- 当前 `vs1003b_sine_demo` 原逻辑会在 `ST_WAIT_DREQ`、`ST_SCI_CLOCK`、`ST_SCI_VOL`、`ST_NOTE_START` 等状态等待 `DREQ=1` 后才发送 SPI 命令。
- 如果 `DREQ` 因模块未响应、输入电平不稳、模块未初始化或 DREQ 线虽然接对但一直低，状态机会完全不输出 `SCLK/MOSI`，现场表现就是“没有任何反应”。

本次修改：
- 在 `vs1003b_sine_demo` 中新增 `DREQ_TIMEOUT = 25'd4999999`。
- 等待 `DREQ` 的状态现在改为：`DREQ=1` 时立即发送；若等待超时，也强制发送一轮 SCI 初始化和 sine test 命令。
- `start_command` 中会清零 `wait_count`，避免各阶段 timeout 互相污染。
- `ST_NOTE_HOLD` 结束后不再等待 DREQ 才发送 sine off，而是直接发送退出命令，便于循环测试。

验证结果：
- 已重新运行完整 Vivado bitstream 生成，结果为 `VIVADO_BUILD_OK`。
- 新 bitstream 已同步到：
  - `Mini_IO.runs/impl_1/design_mb_wrapper.bit`
  - `Mini_IO.sdk/design_mb_wrapper_hw_platform_0/design_mb_wrapper.bit`
  - `Mini_IO.sdk/design_mb_wrapper_hw_platform_0/download.bit`
- 三个 bit 文件 SHA256 均为 `03652BF777189157ACAE26977DAACA243375EFDD00CA3A7D77DD21C5608D2614`。
- 时序满足：`WNS=1.159ns`，`TNS=0.000ns`，`WHS=0.035ns`，`THS=0.000ns`。

上板测试说明：
- 下载最新 `download.bit` 后打开 `SW2`。
- 如果 DREQ 正常，应该很快听到 sine test。
- 如果 DREQ 一直低，约 50ms 后 FPGA 也会强制发 SPI。此时若仍无声，请看板上 LED：`SW2=1` 时 LED 会显示 VS1003B debug，重点看 `DREQ/XRST/SCLK/MOSI` 是否变化。
### 2026-06-03 VS1003B 无声排查：改回真实 MP3 帧流测试

用户反馈：
- 线序已确认无误，`SW2=1` 时仍无声。
- LED 状态大致为 `LED15/13` 常亮、`LED14/12` 常暗、`LED0/1/6/7` 偏暗闪烁，其余多为常亮。
- 昨天同样接线下，使用“随机生成的测试音频”时曾经能发声，因此怀疑当前响度或音频流类型有问题。

本次分析：
- 当前顶层 `design_mb_wrapper.v` 中 `vs_mb_mode` 固定为 `1'b0`，VS1003B 物理引脚由 RTL `rhythm_video_audio.v` 驱动，不由 `Mini_IO.sdk/SeriesIODacSaw/src/rhythm_game.c` 驱动。
- 用户描述的 LED 状态符合 RTL VS debug 编码：`LED15..12 = 4'ha`，`LED0/LED1` 分别显示 `MOSI/SCLK` 活动，说明 FPGA 端确实在输出 SPI 波形。
- 上一版实例化的是 `vs1003b_sine_demo`，发送 VS1003B 内建 sine test 命令；若该命令序列、测试模式或模块兼容性不合适，会出现 SPI 在动但耳机无声。
- 保留的 `vs1003b_mp3_rom_player` 原先读的是 `music/midi/faded_main_melody.mem`，长度仅 740 字节，属于 MIDI byte-stream，不是 MP3 帧流，也不适合作为当前硬件通断验证。
- 之前 `download.bit` 与 `impl_1/design_mb_wrapper.bit` 哈希不一致，存在下载旧 bitstream 的风险。

本次修改：
- 顶层 VS1003B 实例由 `vs1003b_sine_demo` 改为 `vs1003b_mp3_rom_player`。
- 新增 `music/processed/Canon_20s_30s_first16k_vs1003b.mem`，内容为 Canon 20s-30s MP3 片段的前 16000 字节，开头为合法 MP3 帧同步 `ff fb 92 64`。
- `vs1003b_mp3_rom_player` 的 `MP3_LEN` 改为 `16000`，`$readmemh` 改为读取上述 16KB Canon MP3 测试片段。
- VS1003B `SCI_VOL` 从 `0x7070` 改为 `0x4040`，避免此前衰减过大导致听感接近无声，同时仍不是最大音量。
- `ST_DONE` 改为短暂停顿后循环播放 16KB 测试片段，方便现场确认是否有声音。
- 重新生成完整 bitstream，并同步覆盖：
  - `Mini_IO.runs/impl_1/design_mb_wrapper.bit`
  - `Mini_IO.sdk/design_mb_wrapper_hw_platform_0/design_mb_wrapper.bit`
  - `Mini_IO.sdk/design_mb_wrapper_hw_platform_0/download.bit`

验证结果：
```text
VIVADO_BUILD_OK
Bitgen Completed Successfully
Route WNS ~= 1.731 ns
Route TNS = 0.000 ns
SHA256 = FF69214D6B6A22FA12BC0D0A87C17A4A4FC0A0372AE52F228AA5FEC2E6DA33B7
```

上板测试说明：
- 下载最新 `Mini_IO.sdk/design_mb_wrapper_hw_platform_0/download.bit`。
- 打开 `SW2`，应循环播放 Canon MP3 的短测试片段。
- 此版 SW2 播放的是真实 MP3 帧流，不再是 sine test，也不是 MIDI。
- 若仍无声但 `LED0/LED1` 在闪、`LED8(XRST)` 与 `LED9(DREQ)` 为亮，下一步应优先怀疑 VS1003B 模块的耳机/音频输出端、供电电压、电平兼容或模块是否需要额外控制引脚，而不是乐谱音准问题。

### 2026-06-03 VS1003B 无声排查：最大音量与 SPI 边沿修复

用户反馈：
- 仍然没有声音。
- 希望音量再调大约 10 倍。
- LED 状态为 `LED0/1/3/4/5/6` 交替闪烁，`LED15..7` 除 `LED14/12` 外基本常亮，`LED2` 暗。

本次分析：
- `LED15..12 = 4'ha` 是 RTL 固定调试前缀，`LED14/12` 暗属正常。
- `LED8` 亮表示 `XRST` 已拉高，`LED9` 亮表示 `DREQ` 为高，`LED0/1` 闪表示 `MOSI/SCLK` 在活动。
- 这说明 FPGA 正在向 VS1003B 发数据，问题更可能是 VS1003B 没正确采样 SPI 或初始化序列不够贴近参考例程。
- 对比参考 `MP3.v` 后，参考例程初始化会写 `SCI_MODE = 0x0804`，即 `SM_SDINEW + SM_RESET`，并使用 `SCI_VOL = 0x0000` 最大音量。
- 当前 `vs1003b_mp3_rom_player` 的 SPI 发送在 `SCLK` 上升沿附近同时更新 `MOSI`，存在 VS1003B 采样建立时间不足的风险。

本次修改：
- `CMD_SCI_MODE` 从 `0x0800` 改为 `0x0804`，贴近参考例程软复位流程。
- `CMD_SCI_VOL` 从 `0x4040` 改为 `0x0000`，VS1003B 寄存器意义上的最大音量。
- 新增 `command_msb()`，`start_command()` 时提前输出当前字节 MSB。
- 修改 `ST_SEND` SPI 发送逻辑：先保持 `MOSI` 稳定，再拉高 `SCLK`；在 `SCLK` 下降沿后才切换到下一位或下一字节，避免数据与采样边沿同时变化。
- 重新生成完整 bitstream，并同步覆盖：
  - `Mini_IO.runs/impl_1/design_mb_wrapper.bit`
  - `Mini_IO.sdk/design_mb_wrapper_hw_platform_0/design_mb_wrapper.bit`
  - `Mini_IO.sdk/design_mb_wrapper_hw_platform_0/download.bit`

验证结果：
```text
VIVADO_BUILD_OK
Bitgen Completed Successfully
Route WNS ~= 1.636 ns
Route TNS = 0.000 ns
SHA256 = D2C80DEA8C3B6D0267F172B1441EA47BEC4AD9050E488003BB5DCE4D3718376E
```

上板测试说明：
- 下载最新 `Mini_IO.sdk/design_mb_wrapper_hw_platform_0/download.bit`。
- 打开 `SW2`，应循环播放 Canon MP3 16KB 测试片段。
- 由于本版 `SCI_VOL=0x0000` 为最大音量，测试时建议先不要把耳机完全戴紧，确认有声后再调整。

### 2026-06-03 VS1003B 无声排查：切换到商家例程 MP3 数据

用户反馈：
- 最新版本依旧无声，并补充 `文档/VS1003&1053模块` 中有商家 STM32/51 参考例程。

本次分析：
- 商家 `TestVS1003B/vs1003.c` 的 SPI 位序为 MSB first，时序为 `CLK=0 -> 设置 SI -> CLK=1`，与当前 RTL 修正后的发送时序一致。
- 商家 `Mp3SoftReset()` 写入 `SCI_MODE=0x0804`、`SCI_CLOCKF=0x9800`、`SCI_AUDATA=0xBB81`、`SCI_BASS=0x0055`，并发送 4 个 `0x00` 数据字节；当前 RTL 已按这个初始化顺序靠拢。
- 为排除 Canon/Fade 自制 MP3 片段兼容性问题，本次直接把商家例程自带 `MusicDataMP3.c` 转成 FPGA ROM 数据。

本次修改：
- 新增 `music/processed/vendor_vs1003b_musicdata_mp3.mem`，由 `文档/VS1003&1053模块/测试程序/TestVS1003B/MusicDataMP3.c` 中的 `0x..` 数据转换得到。
- `vendor_vs1003b_musicdata_mp3.mem` 长度为 `12923` 字节，开头为 `49 44 33 03 ...`，即商家样例 MP3/ID3 数据。
- `rhythm_video_audio.v` 中 `vs1003b_mp3_rom_player` 的 `MP3_LEN` 改为 `12923`。
- `$readmemh` 数据源改为 `F:/FPGA/mircoCom/Genneral/Mini_IO/music/processed/vendor_vs1003b_musicdata_mp3.mem`。

验证结果：
```text
VIVADO_BUILD_OK
Bitgen Completed Successfully
Route WNS ~= 1.465 ns
Route TNS = 0.000 ns
SHA256 = 4CB5DDB25799DC12FE8FDCE9A174FC8B1090FD1A5CEB09C4C5097B647DE34BEA
```

bitstream 已同步覆盖：
- `Mini_IO.runs/impl_1/design_mb_wrapper.bit`
- `Mini_IO.sdk/design_mb_wrapper_hw_platform_0/design_mb_wrapper.bit`
- `Mini_IO.sdk/design_mb_wrapper_hw_platform_0/download.bit`

上板测试说明：
- 下载最新 `Mini_IO.sdk/design_mb_wrapper_hw_platform_0/download.bit` 后打开 `SW2`。
- 此版本播放的是商家参考例程自带 MP3 测试数据，不是 Canon/Fade，也不是 MIDI。
- 若此版本仍无声，但 `LED9(DREQ)` 亮、`LED8(XRST)` 亮、`LED0/LED1(MOSI/SCLK)` 闪烁，则下一步应做 SCI 读回或示波器/逻辑分析仪级别验证，重点确认 VS 芯片是否真正接收并响应 SCI 写寄存器。
