# 主旋律 MIDI 加工与 VS1003B 播放说明

本文记录本次将“完整 MP3 歌曲”精简为“单轨主旋律 MIDI”并接入 VS1003B 播放器的处理方法。

## 方向校正

VS1003B 本身就是音频解码模块，优势是接收已有音频/压缩音频数据流并完成解码输出。因此本项目的音频主线不应长期停留在 FPGA 内部手搓方波、PWM 音色或人工捏音符波形。

正确的大方向应为：

```text
已有音频/已有 MIDI/加工后的主旋律文件
  -> 压缩或精简为 VS1003B 可解码的数据
  -> 由 FPGA/MicroBlaze 按 DREQ 分块送入 VS1003B
  -> VS1003B 负责解码和耳机输出
```

当前手写或提取的短 MIDI 只能作为阶段性验证资源，用于确认 VS1003B 接线、初始化、音量、音高补偿和 SDI 发送链路是通的。后续若要播放更像原曲、时长 20-30 秒甚至完整歌曲的内容，应学习参考例程的大文件播放思路，而不是继续在 RTL 中手动合成音频。

## 参考工程方法

完整参考工程 `文档/VGA_hw` 的 `MP3` 目录中，歌曲 COE 文件并不是普通 MP3 数据。其开头为：

```text
4D546864
```

该值对应 ASCII 字符串 `MThd`，说明参考工程实际存放的是 Standard MIDI 文件数据。参考工程报告中也提到，直接将 MP3 转 COE 体积太大，最终使用的是单音轨 MIDI 文件。

因此适合课堂演示的精简路线是：

```text
主旋律/单轨 MIDI -> 32-bit hex COE 或 byte mem -> VS1003B SDI byte-stream 播放
```

`文档/Digital_Logic_FPGA_final_hw` 中的参考例程也采用了类似思路：

- `MP3.v` 负责 VS1003B 复位、SCI 寄存器配置、音量设置和 SDI 数据发送。
- 音乐数据从 `track*.COE` 初始化的 ROM/BRAM 中按地址读取。
- 发送音频数据时观察 `DREQ`，只有 VS1003B 能继续接收时才送入后续字节。
- 参考 README 特别提醒：若模块代码看似正确但无法播放，应检查 MIDI 文件是否为单轨。

这说明参考例程关注的重点不是 FPGA 自己合成声音，而是：

```text
准备 VS1003B 能解码的数据文件
解决数据如何存储
解决数据如何按 DREQ 稳定送入模块
```

本项目后续也应沿着这条线继续推进。

## 大文件播放问题

目前最大的矛盾不是“VS1003B 能不能播”，而是“较大的音乐文件放在哪里、怎么持续送出去”。

可选路线如下：

| 路线 | 适合内容 | 是否推荐 | 说明 |
| --- | --- | --- | --- |
| RTL ROM/COE 内置 | 几百字节到几 KB 的 MIDI demo | 阶段性可用 | 简单但改歌要重新 bitstream，容量也有限 |
| MicroBlaze C 数组 | 较短 MIDI/短 MP3 片段 | 推荐过渡 | 改数据主要重编译 ELF，不必完整跑 Vivado |
| BRAM/Block Memory | 中等大小片段 | 可用但容量有限 | 仍受片上存储限制 |
| SPI Flash / SD 卡 | 20-30 秒或更长音频 | 后续主线 | 文件可替换，适合真正播放已有音频 |
| UART/串口加载 | 调试和临时导入 | 辅助 | 方便验证，但演示时不如本地存储稳定 |

因此，后续应把 VS1003B 播放器迁到 MicroBlaze 软件侧，并准备文件读取或分块缓存机制。MicroBlaze 负责从 C 数组、Flash、SD 卡或串口缓存读取数据，按 `DREQ` 每次发送最多 32 字节给 VS1003B。这样才能播放更长音乐，而不是把完整音频硬塞进 Verilog ROM。

## 本次生成的资源

生成脚本：

```text
scripts/make_single_track_midi_assets.py
```

输出目录：

```text
music/midi
```

当前默认接入 VS1003B 播放的是：

```text
music/midi/faded_main_melody.mem
```

文件大小：

```text
faded_main_melody.mid: 740 bytes
faded_main_melody_hex.COE: 185 个 32-bit word
canon_main_melody.mid: 345 bytes
canon_main_melody_hex.COE: 87 个 32-bit word
```

相比之前内置 160079 bytes 的 MP3 片段，单轨 MIDI 数据非常小，更适合内置 ROM 和快速综合。

## 当前 RTL 接入点

当前 `rhythm_video_audio.v` 中的 `vs1003b_mp3_rom_player` 名称暂未重命名，但它发送的是 VS1003B 可识别的 MIDI byte-stream。

关键修改：

```text
MP3_LEN = 740
$readmemh(".../music/midi/faded_main_melody.mem", mp3_rom)
SCI_VOL = 0x7070
```

说明：

- `CMD_MP3_BYTE` 仍作为“向 VS1003B SDI 发送一个数据字节”的通用命令使用。
- VS1003B 可以接收 MIDI 文件字节流，不要求该状态机只播放 MP3。
- 音量设置为 `0x7070`，避免模块输出过大。

## 局限

本次没有真正从混音 MP3 中自动扒谱。原因是 MP3 是已经混合后的波形，不含独立“主音轨”事件数据；从 MP3 自动转 MIDI 属于音高识别/扒谱问题，通常需要 FL Studio、Cubase、Melodyne 等工具人工校正。

本次采用的是课堂演示更稳的方案：根据已知主旋律直接生成单轨 MIDI。它能满足“主旋律可听、数据小、适合 VS1003B”的目标，但不是对原 MP3 的自动精准还原。

后续如果需要更接近原曲，可以用 FL Studio/Edison 的音频转钢琴卷帘功能先生成初稿，再人工删除杂音符，最后重新导出单轨 MIDI 并用本脚本转 COE/mem。
