# Melody Game of MicroBlaze

本项目是在 HUSTerCH / FengSheng_Hust 旧版 `Mini_IO` 工程基础上继续开发的 Nexys4 DDR 综合实验工程。当前目标是用 MicroBlaze SoC 工程承载一个 3-key 音游演示，同时保留 RTL VGA、按键判定、J8 音频和 VS1003B 外部音频模块播放能力。

## 项目来源

- 原始基础工程来自 `HUSTerCH/Mini_IO` 相关课程工程。
- 本仓库保留了旧工程历史与部分目录结构，便于追溯来源。
- 当前新增内容集中在 VGA 音游界面、VS1003B 播放、MIDI 资源、曲绘资源、按键判定和协作文档。

## 当前主要功能

- Nexys4 DDR + Vivado 2018.3 + SDK/MicroBlaze 工程。
- VGA 三轨音游界面，左中右轨道对应 `BTNL / BTNC / BTNR`。
- J8 板载 PWM 音频作为备用电子音路径。
- VS1003B 模块通过 JA PMOD 接口播放 MIDI/MP3 等可解码 byte-stream。
- 内置 Canon / Faded 课堂演示 MIDI。
- 支持 VS1003B 标准音校准模式，用手机调音器判断是模块整体走音还是 MIDI 乐谱不准。

## VS1003B 拨码

| 拨码 | 作用 |
| --- | --- |
| `SW1:SW0=00` | 默认选择 Faded |
| `SW1:SW0=01` | 选择 Canon / 曲目 0 |
| `SW1:SW0=10` | 选择 Faded / 曲目 1 |
| `SW1:SW0=11` | 选择 Aphasia / 曲目 2 |
| `SW2` | 启用 VS1003B 播放器 |
| `SW3..SW5` | 普通模式下为音游流速；校音模式下不参与音高选择 |
| `SW13` | VS1003B/MicroBlaze 模式下暂停/继续音乐与谱面 |
| `SW14` | VS1003B 标准音校准模式 |
| `SW15` | 暂停音游 |

VS1003B 模式下，`BTNU/BTND` 只用于音量控制：

| 按键 | 作用 |
| --- | --- |
| `BTNU` | 点击音量增大 |
| `BTND` | 点击音量减小 |

音量为 16 档，覆盖从很小声到最大音量。音乐/谱面暂停由 `SW13` 控制，`BTNL / BTNC / BTNR` 仍用于三轨判定。

校音模式不依赖 VGA 屏幕。打开 `SW14=1` 和 `SW2=1` 后，VS1003B 会连续循环播放 C 大调音阶，用手机调音器或频谱 App 逐个检测即可。当前 MIDI 资源已按实测听感整体下移 1 个半音，用来抵消该 VS1003B 模块约高半音的输出偏差。

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

判断方法：

- 若这些标准音全部整体偏高或偏低，优先排查 VS1003B 晶振、初始化时钟或硬件模块。
- 若标准音基本准确，但歌曲听起来不像，优先修改 MIDI 乐谱和节奏。

## VS1003B 接线

当前约束建议将 VS1003B 模块集中接到 JA PMOD。模块引脚顺序按用户手头模块描述为：

```text
XDCS XCS DREQ SCLK MOSI MISO XRST GND 5V
```

信号连接见 `Mini_IO.srcs/constrs_1/new/adda.xdc`。模块耳机应插 `PHONE` 输出，不是 `LINE IN`。

## 关键文件

- `Mini_IO.srcs/sources_1/new/rhythm_video_audio.v`：VGA、音游、J8 音频、VS1003B RTL 播放器。
- `Mini_IO.srcs/constrs_1/new/adda.xdc`：VGA、J8、JA/VS1003B、SW14/SW15 等管脚约束。
- `scripts/make_single_track_midi_assets.py`：生成 MIDI、mem、COE 和音符表。
- `music/midi/`：Canon/Faded/校音 MIDI 与 ROM 初始化资源。
- `文档/AI_协作修改日志.md`：每次需求、修改、验证和后续注意事项。
- `文档/Verilog迁移为MicroBlaze控制程序方案.md`：说明哪些常改内容应迁到 MicroBlaze C 程序，以减少重新生成 bitstream 的次数。
- `文档/按键与拨码开关作用分析.md`：按键/拨码/校音模式说明。
- `Mini_IO.sdk/design_mb_wrapper_hw_platform_0/download.bit`：当前已同步的下载 bitstream。

## MicroBlaze 迁移方向

当前工程已经是 MicroBlaze SoC + 自定义 RTL 外设的结构，但歌曲 ROM、部分谱面、判定和 VS1003B 播放状态机仍有不少内容写在 Verilog 中。只要这些 Verilog/ROM 初始化内容改变，就通常需要重新综合、实现和生成 bitstream。

VS1003B 的核心作用是解码已有音频/压缩音频数据，而不是让 FPGA 长期手搓音频波形。当前内置短 MIDI 主要用于验证接线、初始化、音量、音高补偿和 SDI 发送链路。后续播放 20-30 秒或更长音乐时，重点应转向参考例程式的数据存储和分块播放：准备 VS1003B 可解码的 MIDI/MP3 数据，MicroBlaze 或硬件播放器按 `DREQ` 将数据流持续送入模块。

后续建议把经常改的内容迁到 MicroBlaze 软件侧：

- 歌曲选择、BPM、音量、暂停、流速、菜单状态。
- 谱面数据、判定窗口、GOOD/BAD/MISS、分数和连击。
- VS1003B 初始化、DREQ 流控和 MIDI/MP3 数据发送。
- LED、RGB、数码管、VGA UI 状态寄存器更新。

硬件侧则尽量固定为可复用外设：

- VGA 行场同步和像素扫描。
- AXI GPIO / AXI SPI / AXI Timer / Interrupt Controller。
- 少量自定义 AXI-Lite 状态寄存器或轻量绘图外设。

这样硬件接口稳定后，改歌、改谱面、调 BPM 和改判定逻辑时优先重新编译 SDK 软件或替换外部数据，不必每次重新跑完整 Vivado bitstream。详细方案见 `文档/Verilog迁移为MicroBlaze控制程序方案.md`。

## 构建

在 `Mini_IO` 目录下运行：

```powershell
& "D:\Xilinx\Vivado\2018.3\bin\vivado.bat" -mode batch -source scripts\build_vivado.tcl
```

生成成功后，将 `Mini_IO.runs/impl_1/design_mb_wrapper.bit` 同步到 SDK 硬件平台目录：

```powershell
Copy-Item Mini_IO.runs\impl_1\design_mb_wrapper.bit Mini_IO.sdk\design_mb_wrapper_hw_platform_0\design_mb_wrapper.bit -Force
Copy-Item Mini_IO.runs\impl_1\design_mb_wrapper.bit Mini_IO.sdk\design_mb_wrapper_hw_platform_0\download.bit -Force
```
