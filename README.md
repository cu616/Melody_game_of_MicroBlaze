# Melody Game of MicroBlaze

本工程是在 HUSTerCH / FengSheng 的 Nexys4 DDR MicroBlaze 示例工程基础上改造的课堂综合项目。当前目标不是保留所有原始例程，而是交付一个基于 MicroBlaze、VS1003B 音频模块和 VGA 显示的三键下落式音游。

## 当前硬件

- 开发板：Nexys4 DDR / Artix-7
- 处理器：MicroBlaze，负责曲目选择、VS1003B MIDI 播放、音游状态、按键判定、分数和数码管状态
- 音频：VS1003B/VS1053 模块，接在 JA PMOD
- 显示：板载 VGA 接口，RTL 负责稳定像素扫描和画面绘制
- 输入：BTNL/BTNC/BTNR 分别对应左/中/右三轨
- 输出：16 个 LED 做氛围灯，数码管显示判定/状态和百分比得分

旧的 J8 PWM 音频输出已经从最终工程中移除。最终听歌只走 VS1003B 的 PHONE/耳机输出。

## 最终烧录文件

构建完成后只需要使用：

- `release/design_mb_wrapper.bit`
- `release/SeriesIODacSaw.elf`

烧录脚本：

```powershell
& "D:\Xilinx\Vivado\2018.3\bin\xsct.bat" scripts\program_bit_and_download_seriesiodacsaw.tcl
```

如果 Vivado 安装路径不同，请把命令中的路径换成自己的 `xsct.bat`。

## 拨码开关

- `SW[1:0] = 00`：空闲，无音乐，黑背景
- `SW[1:0] = 01`：Canon
- `SW[1:0] = 10`：Faded
- `SW[1:0] = 11`：Aphasia
- `SW2`：静音开关
- `SW[5:3]`：谱面流速
- `SW14`：VS1003B 音高校准音阶测试
- `SW15`：暂停，同时暂停音乐和谱面

音量由 `BTNU` / `BTND` 调整，不负责开始或结束播放。

## 主要目录

- `Mini_IO.xpr`：Vivado 工程入口
- `Mini_IO.srcs/sources_1/bd/design_mb/`：MicroBlaze block design
- `Mini_IO.srcs/sources_1/new/rhythm_video_audio.v`：VGA 扫描、画面组合、LED/数码管显示桥接
- `Mini_IO.sdk/SeriesIODacSaw/src/`：最终 MicroBlaze 程序
- `Mini_IO.sdk/HelloWorld_bsp/`：最终程序仍使用的 BSP，虽然名字来自旧例程，但不能删除
- `music/midi/`：保留的曲目 MIDI 与调音测试资源
- `charts/`：可编辑谱面文本，修改谱面后可重新生成 C 头文件
- `generated/album_art/`：VGA 曲绘 ROM 数据
- `scripts/`：曲绘、谱面、MIDI 资源生成和烧录脚本
- `release/`：最终 bitstream 和 ELF
- `文档/`：项目说明、接线分析、AI 协作修改日志和板卡资料

## 重新生成

生成曲绘和谱面资源：

```powershell
& "C:\Users\lbc\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe" scripts\prepare_track_art_3x4_square.py
& "C:\Users\lbc\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe" scripts\generate_mb_charts_from_midi.py
```

完整综合实现：

```powershell
& "D:\Xilinx\Vivado\2018.3\bin\vivado.bat" -mode batch -source scripts\build_vivado.tcl
& "D:\Xilinx\SDK\2018.3\bin\xsct.bat" scripts\build_sdk.tcl
```

Vivado/SDK 生成的缓存、实现运行目录和 Eclipse 工作区状态不再作为源码保存。仓库只保留可复现工程源文件、必要资源和最终 `release` 成品。

## VS1003B JA 接线

模块从上到下：`XDCS XCS DREQ SCLK MOSI MISO XRST GND 5V`

推荐接到 JA：

| 模块 | FPGA |
| --- | --- |
| XDCS | JA1 |
| XCS | JA2 |
| DREQ | JA3 |
| SCLK | JA4 |
| MOSI | JA7 |
| MISO | JA8 |
| XRST | JA9 |
| GND | JA GND |
| 5V | 板上 5V |

PHONE 接耳机或小音箱，LINE IN 不是输出口。
