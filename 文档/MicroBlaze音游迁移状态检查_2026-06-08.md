# MicroBlaze 音游迁移状态检查 2026-06-08

## 结论

当前工程不是纯 RTL 工程，也不是完全 MicroBlaze 化的音游。更准确的描述是：

```text
MicroBlaze SoC + RTL VGA/音游外设的混合实现
```

MicroBlaze 已经承担 VS1003B 播放、曲目选择、音量、暂停、基础按键判定、分数、数码管和 RGB 反馈；但 VGA 扫描、画面绘制和一套旧的 RTL 音游核心仍然保留在 Verilog 中。

## 已经在 MicroBlaze C 程序中的内容

主要文件：

- `Mini_IO.sdk/SeriesIODacSaw/src/rhythm_game.c`
- `Mini_IO.sdk/SeriesIODacSaw/src/vs1003b_midi_assets.h`

已经迁移到软件侧的功能：

- VS1003B 初始化、SCI 寄存器写入、DREQ 流控、MIDI byte-stream 发送。
- `SW1:SW0` 曲目选择：
  - `00` Faded
  - `01` Canon
  - `10` Faded
  - `11` Aphasia
- `SW13` 暂停/继续音乐与软件谱面计时。
- `BTNU/BTND` 控制 VS1003B 音量。
- `BTNL/BTNC/BTNR` 基础三轨按键判定。
- 软件侧分数、miss、结束状态、数码管显示和 RGB 判定反馈。

## 仍然在 RTL/Verilog 中的内容

主要文件：

- `Mini_IO.srcs/sources_1/new/rhythm_video_audio.v`
- `Mini_IO.srcs/sources_1/new/rhythm_charts.vh`

仍在硬件侧自运行的功能：

- VGA 行场同步和像素扫描。
- VGA 轨道、侧边 UI、曲绘、文字和音符绘制。
- `rhythm_game_core` RTL 音游核心。
- RTL 内部谱面表 `rhythm_charts.vh`。
- RTL 侧判定、分数、combo、finish 状态。
- 旧的 J8 PWM 音频合成。
- 旧的 RTL VS1003B ROM 播放器。

## 当前顶层连接状态

主要文件：

- `Mini_IO.srcs/sources_1/bd/design_mb/hdl/design_mb_wrapper.v`

`SW2` 当前用于切换 VS1003B/LED/数码管/RGB 的控制来源：

- `SW2=1`：这些外设切到 MicroBlaze。
- `SW2=0`：这些外设由 RTL 音游模块输出。

但是 VGA 输出始终来自 `rhythm_video_audio.v`，目前没有从 MicroBlaze 直接写入 VGA 画面状态的专用寄存器接口。因此当前 VGA 画面仍是 RTL 自己绘制，而不是 MicroBlaze 生成或完全控制。

## 已发现的问题

软件侧 `SongIndex=2` 选择 Aphasia 音乐时，判定谱面仍复用 `Song1`，因为当前 `CurrentSong()` 只在 `Song0` 和 `Song1` 间选择。若要让 Aphasia 成为完整第三首音游曲，需要新增软件侧 `Song2` 谱面。

## 下一步迁移方向

为了更符合“MicroBlaze 核运行综合项目”，建议按阶段迁移：

1. 在 RTL 中增加 MicroBlaze 可写的 VGA/UI 状态输入。
2. 先让 MicroBlaze 控制 VGA 显示的曲目、分数、判定、暂停、结束状态。
3. 逐步让 RTL 只保留 VGA 扫描和绘制模板，音符位置、判定结果、分数和 UI 状态由 MicroBlaze 传入。
4. 最终弱化或关闭 RTL `rhythm_game_core`，让 MicroBlaze 成为音游逻辑主控。

第一阶段会修改硬件接口，因此需要重新综合/实现并生成 bitstream。
