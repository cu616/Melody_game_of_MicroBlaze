# AI 协作修改日志

本文用于记录本工程每次需求、修改内容、验证结果和后续注意事项，方便其他 AI 或同学继续协作。

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
