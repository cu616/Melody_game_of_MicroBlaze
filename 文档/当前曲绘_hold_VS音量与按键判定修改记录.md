# 当前曲绘、hold、VS1003B 音量与按键判定修改记录

记录时间：2026-06-02

本文记录最近对 `Mini_IO` 音游工程的 RTL 修改、验证结果，以及这些修改与“Verilog 迁移为 MicroBlaze 控制程序方案”的关系。

## 涉及文件

主要修改文件：

```text
Mini_IO.srcs/sources_1/new/rhythm_video_audio.v
```

相关素材与 bitstream：

```text
generated/album_art/canon_track_bg_index.mem
generated/album_art/canon_track_bg_palette.mem
generated/album_art/fade_track_bg_index.mem
generated/album_art/fade_track_bg_palette.mem
Mini_IO.runs/impl_1/design_mb_wrapper.bit
```

最新 bitstream：

```text
F:/FPGA/mircoCom/Genneral/Mini_IO/Mini_IO.runs/impl_1/design_mb_wrapper.bit
LastWriteTime: 2026-06-02 22:32:48
Size: 3825902 bytes
```

## 曲绘显示修改

当前工程已经把 `scripts/pictures` 中的曲绘转换为 FPGA 可读的 indexed ROM 数据，并在 `rhythm_video_audio.v` 中通过 `album_art_track_rom` 读取。

轨道曲绘显示范围：

```text
x = 200..439
y = 32..415
```

也就是中间三轨下落区域，不是全屏背景。

当前显示策略：

1. 待机状态和打歌状态的中间轨道区域都会显示曲绘，便于确认曲绘是否真的接入。
2. 曲绘先转换为灰度，再作为轨道背景显示。
3. 音符、hold、判定线、按键反馈仍覆盖在曲绘之上。

这样做的目的：

- 保留歌曲曲绘氛围；
- 避免全彩曲绘喧宾夺主；
- 避免黑色蒙版过重导致用户以为曲绘没有显示。

当前灰度逻辑位于 `rhythm_video_audio.v`：

```verilog
wire [5:0] album_gray_sum =
    {2'b00, album_art_rgb[11:8]} +
    {2'b00, album_art_rgb[7:4]} +
    {2'b00, album_art_rgb[3:0]};
wire [3:0] album_gray = album_gray_sum[5:2];

assign track_bg_r = album_gray;
assign track_bg_g = album_gray;
assign track_bg_b = album_gray;
```

说明：这里使用简单平均近似灰度，硬件开销较低。若后续希望曲绘更暗，可以再右移一位或减小输出比例。

## VS1003B 音量修改

VS1003B 的 `SCI_VOL` 寄存器是衰减量，数值越小，输出越响。

当前已把相关 VS1003B 播放模块中的音量从早期值：

```text
SCI_VOL = 0x58/0x58
```

先调整到：

```text
SCI_VOL = 0x40/0x40
```

这大约相当于提高约 12 dB，接近 4 倍幅度。

在继续排查“仍然没有声音”后，进一步调整为：

```text
SCI_VOL = 0x00/0x00
```

`0x00/0x00` 是 VS1003B 的最大音量设置，用于先排除音量衰减过大导致听不到的问题。若后续确认声音过大，可再回退到 `0x20/0x20` 或 `0x40/0x40`。

涉及模块包括：

- `vs1003b_mp3_rom_player`
- `vs1003b_pcm_player`
- `vs1003b_sine_demo`

当前实际顶层接入的是 `vs1003b_mp3_rom_player`，另外两个模块保留作为后续测试或回退参考。

### 2026-06-02 22:32：VS1003B 播放调度排查

排查结论：

1. `music/processed/The_O_Neill_Brothers_-_Canon_In_D__Piano__20s_30s_vs1003b.mem` 的开头为 `ff fb ...`，是可供 VS1003B 解码的 MP3 帧数据。
2. Vivado synthesis log 显示该 `.mem` 已被 `$readmemh` 成功读入。
3. 旧启动条件为 `SW2 && canon_mode`，也就是必须 `SW0=1, SW1=0, SW2=1` 才会启动 VS1003B。若只打开 `SW2`，VS1003B 不会播放。
4. 旧调度每次 `DREQ=1` 只发送 1 个 MP3 字节，并在字节之间反复释放 `XDCS`，不如 VS1003B 推荐的 DREQ burst 方式稳。

本次修改：

```verilog
wire vs1003_player_enabled = vs1003_demo_enabled;
```

现在只要 `SW2=1`，VS1003B 播放器就会启动，不再要求同时打开 `SW0`。

播放器内部新增：

- DREQ 两级同步；
- `ST_PLAY_BURST` 状态；
- 每次 DREQ ready 时最多连续发送 `32` 个 MP3 字节；
- burst 过程中保持 `XDCS` 有效，减少片选抖动；
- debug LED 改为显示 `DREQ`、`enable`、播放器 `state`、`XDCS/XCS` 活动状态。

验证：

```text
xvlog rhythm_video_audio.v: pass
VIVADO_BUILD_OK
write_bitstream completed successfully
```

## hold 判定修改

原逻辑的问题：

```verilog
if (hold_lane0[31] && !button_sync[0]) cycle_miss = 1'b1;
```

当 hold 的最后一格经过判定线时，如果玩家已经松手，即使这是合理的尾端释放，也会被判为 miss。因此用户体验上表现为“松手后几乎一定 miss”。

当前修改：

```verilog
function hold_requires_press;
    input [31:0] hold_lane;
    begin
        hold_requires_press = hold_lane[31] && (|hold_lane[30:24]);
    end
endfunction
```

新的 miss 判断：

```verilog
if (hold_requires_press(hold_lane0) && !button_sync[0]) cycle_miss = 1'b1;
if (hold_requires_press(hold_lane1) && !button_sync[1]) cycle_miss = 1'b1;
if (hold_requires_press(hold_lane2) && !button_sync[2]) cycle_miss = 1'b1;
```

含义：

- hold 中段仍要求持续按住；
- 当判定线处是 hold 尾端，且后续判定窗口内已经没有 hold 段时，允许玩家松手；
- 不改普通 tap note 的 GOOD/BAD/MISS 判定。

这个修改没有增加按键输入延迟。

## 按键同步与消抖现状

当前游戏三键使用如下映射：

```verilog
wire [2:0] lane_button_raw = {buttons[3], buttons[0], buttons[2]};
```

对应关系：

```text
game_buttons[0] = BTNL / P17 / 左轨
game_buttons[1] = BTNC / N17 / 中轨
game_buttons[2] = BTNR / M17 / 右轨
```

`rhythm_game_core` 内部目前只有两级同步和上升沿检测：

```verilog
button_meta <= buttons;
button_sync <= button_meta;
button_prev <= button_sync;
button_edges <= button_sync & ~button_prev;
```

结论：

- 当前没有传统毫秒级按键消抖；
- 两级同步只带来约 2 个 `clk100` 周期级延迟；
- 对音游判定手感友好；
- 但机械按键抖动仍可能产生重复边沿。

当前没有加入慢速消抖，原因是普通消抖可能引入毫秒级延迟。若后续确实需要抑制抖动，建议采用“短 edge lockout”方式，只限制同一按键在极短时间内重复触发，不延迟按键电平本身，也不影响 hold 持续按住状态。

## 验证结果

已完成：

```text
xvlog rhythm_video_audio.v: pass
Vivado build_vivado.tcl: VIVADO_BUILD_OK
write_bitstream completed successfully
```

Vivado 最终生成 bitstream，无 error。存在若干 warning/critical warning，主要为工程既有的 Vivado/IP/配置提示，不是本次曲绘、hold 或音量修改直接引入的功能性报错。

## 与 MicroBlaze 迁移方案的关系

已阅读本地文档：

```text
文档/MicroBlaze_SoC实现说明.md
文档/Verilog迁移为MicroBlaze控制程序方案.md
```

这两份文档的核心观点是：

```text
MicroBlaze 软件负责游戏逻辑；
Verilog/AXI 外设负责实时信号输出。
```

建议迁移方向不是让 MicroBlaze 逐像素生成 VGA，而是保留硬件 VGA 扫描和绘制模块，让 MicroBlaze 通过 AXI GPIO 或自定义 AXI-Lite 寄存器写入游戏状态。

对当前修改的影响：

1. 曲绘显示适合保留在硬件侧，因为 VGA 像素输出需要稳定时序。MicroBlaze 后续可以只控制 `song_id`、背景选择、灰度强度等寄存器。
2. hold 判定当前仍在 RTL 内部。若后续迁移，建议把 GOOD/BAD/MISS 和 hold 起止判定移到 MicroBlaze Timer tick 中，用软件时间戳处理，更容易调节手感。
3. 按键目前是 RTL 两级同步。迁移后可改为 AXI GPIO + 中断，但中断里只记录边沿时间，不做复杂计算；真正判定放在 Timer tick 中完成。
4. VS1003B 当前由 RTL 状态机播放内置 MP3 ROM。迁移方案建议改为 MicroBlaze 通过 AXI Quad SPI + GPIO 控制 `XCS/XDCS/XRST/DREQ`，从 BRAM/Flash/SD 读取 MP3 数据并按 DREQ 发送。

## 建议的下一步迁移顺序

为了降低风险，建议不要一次性把 `rhythm_video_audio.v` 全部改成 MicroBlaze 控制，而是分阶段迁移：

1. MicroBlaze 接管菜单、歌曲选择、暂停、流速等低实时性状态。
2. 保留 VGA 硬件扫描，但新增一组状态寄存器，由 MicroBlaze 写入 score/combo/judge/song/speed。
3. MicroBlaze 接管按键事件时间戳和 GOOD/BAD/MISS 判定，RTL 只负责显示可见音符。
4. MicroBlaze 接管 VS1003B 初始化和 MP3 数据发送，RTL 不再内置大 MP3 ROM。
5. 最后逐步停用 RTL 内部自运行谱面推进、判定和音频播放状态机。

这个方向最符合当前文档里的 SoC 表述，也能减少后续每换歌、换谱、换判定都必须重新生成 bitstream 的成本。
