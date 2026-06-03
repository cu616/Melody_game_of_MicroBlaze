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
- VS1003B 模块通过 JA PMOD 接口播放内置 MIDI byte-stream。
- 内置 Canon / Faded 课堂演示 MIDI。
- 支持 VS1003B 标准音校准模式，用手机调音器判断是模块整体走音还是 MIDI 乐谱不准。

## VS1003B 拨码

| 拨码 | 作用 |
| --- | --- |
| `SW0` | 选择 Canon / 曲目 0 |
| `SW1` | 选择 Faded / 曲目 1，优先于 `SW0` |
| `SW2` | 启用 VS1003B 播放器 |
| `SW3..SW5` | 普通模式下为音游流速；`SW14=1` 时为校音音名选择 |
| `SW14` | VS1003B 标准音校准模式 |
| `SW15` | 暂停音游 |

校音模式不依赖 VGA 屏幕。打开 `SW14=1` 和 `SW2=1`，再用 `SW5..SW3` 选择固定标准音，用手机调音器检测即可。

| `SW5 SW4 SW3` | 音名 | 理论频率 |
| --- | --- | ---: |
| `000` | `A3` | `220.00 Hz` |
| `001` | `C4` | `261.63 Hz` |
| `010` | `E4` | `329.63 Hz` |
| `011` | `A4` | `440.00 Hz` |
| `100` | `C5` | `523.25 Hz` |
| `101` | `E5` | `659.25 Hz` |
| `110` | `A5` | `880.00 Hz` |
| `111` | `C6` | `1046.50 Hz` |

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
- `文档/按键与拨码开关作用分析.md`：按键/拨码/校音模式说明。
- `Mini_IO.sdk/design_mb_wrapper_hw_platform_0/download.bit`：当前已同步的下载 bitstream。

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
