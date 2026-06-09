# Faded 主旋律提取：FL Studio 协作指南

本文用于解决“不会熟练操作 FL Studio，但需要从 Faded 音频中提取主旋律 MIDI”的协作问题。目标不是让用户一次学会 FL Studio，而是把每一步变成可检查的中间状态：用户按步骤操作、截图或导出文件，AI 根据截图继续判断。

## 最推荐路线

优先找现成 MIDI，再清理为单轨主旋律。只有找不到可用 MIDI 时，才从 MP3 用 Stem Separation/NewTone 提取。

原因：
- 现成 MIDI 已经包含音高和节奏，比 MP3 自动扒谱稳定。
- MP3 是混音波形，NewTone 会把人声、混响、伴奏和噪声识别成大量碎音。
- 本项目最终只需要一条单音主旋律，越干净越容易在 VS1003B 上听出来。

## 如果使用 FL Studio 从 MP3 提取

### 第 1 步：导入音频

1. 打开 FL Studio。
2. 把 `music/Alan Walker - Faded.mp3` 拖到 Playlist。
3. 确认它成为一条横向音频片段。

如果不确定是否导入成功，截图给 AI，重点包含 Playlist 区域和音频片段名称。

### 第 2 步：优先分轨

右键音频片段，查找类似菜单：

```text
样本
从样本提取音轨
Extract stems from sample
Stem separation
```

分轨后优先保留：

```text
Vocal / 人声
Lead / 主旋律
Instrument / 乐器中最清楚的一条
```

不要一开始就用完整混音进 NewTone，否则碎音会非常多。

如果你看到多个 stem 轨道，请截图给 AI，我会帮你判断保留哪条。

### 第 3 步：发送到 NewTone

选中最清楚的那条音频后，尝试以下方式之一：

1. 右键音频片段，找 `音高校正样本`、`Edit in pitch corrector` 或 `NewTone`。
2. 或把音频片段直接拖入 NewTone 窗口。

进入 NewTone 后，等待分析完成。你应该看到一堆橙色/白色音符块。

### 第 4 步：先截取范围

不要处理整首歌。先只保留最熟悉的一小段，例如副歌 `Where are you now` 附近。

建议长度：

```text
8 到 16 小节
约 20 到 40 秒以内
课堂演示先控制在 30 到 80 个音符
```

如果 NewTone 里太密，先只截最清楚的一段。截图给 AI，我会告诉你大概从哪到哪保留。

### 第 5 步：删除明显错误音

保留原则：

- 保留主旋律线，不保留低音伴奏。
- 如果同一时间上下有多个音，通常保留最高或最像人声的一条。
- 删除特别短的碎音。
- 删除突然跳到很低的音。
- 删除与旋律方向明显无关的孤立音。

Faded 常见主旋律音域大致应集中在：

```text
F#4 到 C#6 附近
```

明显低于 `C4` 的音多数是伴奏或误识别，优先删掉。明显高到刺耳且孤立的碎音也优先删。

### 第 6 步：发送到 Piano Roll

NewTone 整理到能听出主旋律后，找：

```text
Send to piano roll
发送到钢琴卷帘
```

进入 Piano Roll 后继续检查：

- 不要和弦。
- 不要重叠音。
- 同一时间只留一个主旋律音。
- 量化到 `1/8`，少量快速经过音可保留 `1/16`。

### 第 7 步：导出 MIDI

确认 Piano Roll 中只剩一条旋律后：

```text
File -> Export -> MIDI file
```

导出文件建议命名：

```text
music/midi_import/faded_extracted_lead.mid
```

导出后先在电脑 MIDI 播放器里听。如果电脑播放都不像原曲，就继续清理；不要急着接 VS1003B。

## 交给 AI 的中间材料

如果你不熟练操作，推荐每一步给 AI 以下材料之一：

1. FL Studio Playlist 截图。
2. 分轨后 stem 列表截图。
3. NewTone 音符识别截图。
4. Piano Roll 截图。
5. 导出的 `.mid` 文件。

AI 后续可以继续做：

- 判断哪条 stem 最适合提取。
- 判断哪些音符明显该删。
- 接收导出的 MIDI，并在工程脚本中转为 `faded_main_melody.mem/.COE/.vh`。
- 接入 MicroBlaze VS1003B 软件播放器。

## 接入工程的判断标准

顺序必须是：

```text
电脑 MIDI 听起来像
-> 工程脚本转低内存单轨 MIDI
-> VS1003B 播放
```

如果电脑 MIDI 不像，问题是提取/清理；如果电脑 MIDI 像但 VS1003B 不像，再查音色、音高补偿、DREQ 流控和初始化。
