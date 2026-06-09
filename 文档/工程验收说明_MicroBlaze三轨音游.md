# MicroBlaze 三轨下落式音游工程验收说明

## 1. 项目概述

本项目基于 Nexys4 DDR / Artix-7 开发板和 MicroBlaze SoC，实现一个三轨下落式音乐游戏演示系统。系统支持 VGA 画面显示、三键按键判定、VS1003B 外部音频模块播放 MIDI 主旋律、数码管状态显示、LED 氛围灯和拨码开关运行控制。

工程由 HUSTerCH / FengSheng 的旧 MicroBlaze 示例工程改造而来，当前最终版本只保留本项目需要的 MicroBlaze、VGA、VS1003B、按键、拨码、LED 和数码管相关内容。旧 J8 PWM 音频输出、旧 RTL 音频合成路径和大量无关 SDK 示例已从最终交付路径中移除。

## 2. 系统分工

| 模块 | 实现位置 | 主要职责 |
| --- | --- | --- |
| MicroBlaze 软件 | `Mini_IO.sdk/SeriesIODacSaw/src/rhythm_game.c` | 歌曲选择、VS1003B 初始化和 MIDI 数据发送、音量控制、按键判定、谱面推进、分数、暂停和结束状态 |
| VGA/显示桥 RTL | `Mini_IO.srcs/sources_1/new/rhythm_video_audio.v` | VGA 像素时序、轨道绘制、文字绘制、曲绘 ROM 显示、LED 氛围灯、数码管扫描 |
| MicroBlaze Block Design | `Mini_IO.srcs/sources_1/bd/design_mb/` | MicroBlaze、AXI GPIO、AXI Timer、AXI Interrupt Controller 等 SoC 外设连接 |
| 约束文件 | `Mini_IO.srcs/constrs_1/new/adda.xdc` | VS1003B、VGA、LED、数码管、RGB LED 等引脚约束 |
| 曲目/谱面资源 | `music/midi/`、`charts/`、`generated/album_art/` | MIDI 主旋律、谱面文本、VGA 曲绘 ROM 数据 |

设计原则是：**MicroBlaze 负责游戏状态和音频数据流，RTL 负责高实时性的 VGA 像素扫描和显示模板**。这样既能体现 SoC 方式，又能避免用软件逐像素生成 VGA 导致画面不稳定。

## 3. 最终烧录文件

最终只需要烧录以下两个文件：

| 文件 | 作用 |
| --- | --- |
| `release/design_mb_wrapper.bit` | FPGA 硬件 bitstream，包含 MicroBlaze SoC、VGA 显示桥、接口约束后的硬件逻辑 |
| `release/SeriesIODacSaw.elf` | MicroBlaze 软件程序，包含音游逻辑、VS1003B 播放逻辑、内置 MIDI 数据 |

烧录命令：

```powershell
cd F:\FPGA\mircoCom\Genneral\Mini_IO
& "D:\Xilinx\SDK\2018.3\bin\xsct.bat" scripts\program_bit_and_download_seriesiodacsaw.tcl
```

如 Xilinx 安装路径不同，请将 `D:\Xilinx\SDK\2018.3\bin\xsct.bat` 改为本机实际路径。

## 4. 外设接口说明

### 4.1 VS1003B 音频模块接口

音频输出使用外接 VS1003B / VS1053 音频模块。FPGA 不再通过 J8 直接输出 PWM 方波，而是由 MicroBlaze 将 MIDI byte-stream 按 DREQ 流控送给 VS1003B，VS1003B 负责解码和模拟音频输出。

推荐接到 JA PMOD：

| VS1003B 模块引脚 | FPGA 信号 | PMOD 位置 | Nexys4 DDR 管脚 | 方向 | 说明 |
| --- | --- | --- | --- | --- | --- |
| XDCS | `VS_XDCS` | JA1 | C17 | FPGA 输出 | 数据片选，低有效 |
| XCS | `VS_XCS` | JA2 | D18 | FPGA 输出 | 控制寄存器片选，低有效 |
| DREQ | `VS_DREQ` | JA3 | E18 | FPGA 输入 | VS1003B 请求数据，高电平可继续发送 |
| SCLK | `VS_SCLK` | JA4 | G17 | FPGA 输出 | SPI 时钟 |
| MOSI | `VS_MOSI` | JA7 | D17 | FPGA 输出 | FPGA 写入 VS1003B |
| MISO | `VS_MISO` | JA8 | E17 | FPGA 输入 | VS1003B 回读数据 |
| XRST | `VS_XRST` | JA9 | F18 | FPGA 输出 | VS1003B 硬复位，低有效 |
| GND | GND | JA GND | GND | 电源地 | 必须共地 |
| 5V | 5V | 板上 5V | 5V | 供电 | 按模块要求接板上 5V，不接 PMOD 3.3V 供电脚 |

耳机或小音箱插在模块的 `PHONE` 输出口，`LINE IN` 不是输出口。

### 4.2 VGA 显示接口

VGA 使用 Nexys4 DDR 板载 12-bit VGA 接口，分辨率为 640x480。RGB 每色 4 bit，行同步和场同步由 RTL 硬件扫描产生。

| 信号 | 管脚 |
| --- | --- |
| `VGA_R[0]` | A3 |
| `VGA_R[1]` | B4 |
| `VGA_R[2]` | C5 |
| `VGA_R[3]` | A4 |
| `VGA_G[0]` | C6 |
| `VGA_G[1]` | A5 |
| `VGA_G[2]` | B6 |
| `VGA_G[3]` | A6 |
| `VGA_B[0]` | B7 |
| `VGA_B[1]` | C7 |
| `VGA_B[2]` | D7 |
| `VGA_B[3]` | D8 |
| `VGA_HS` | B11 |
| `VGA_VS` | B12 |

画面内容包括：

- 中间三条下落轨道；
- 左侧菜单/状态栏；
- 右侧分数、判定和状态显示；
- 曲绘背景，当前为 120x192 ROM 源图，VGA 上 2 倍显示；
- 音符和 hold 长条；
- READY / PAUSE / FINISH 等状态提示。

### 4.3 按键接口

音游为 3 key 模式，三个轨道从左到右对应：

| 游戏轨道 | 按键 | 板卡管脚 | 软件/RTL 映射 |
| --- | --- | --- | --- |
| 左轨 | BTNL | P17 | Left |
| 中轨 | BTNC | N17 | Center |
| 右轨 | BTNR | M17 | Right |

其它按键：

| 按键 | 功能 |
| --- | --- |
| BTNU | 音量增加一档 |
| BTND | 音量降低一档 |

按键事件由 MicroBlaze 软件读取并处理，判定结果分为 GOOD、BAD、MISS。GOOD 显示绿色，BAD 显示蓝色，MISS 显示红色。

### 4.4 拨码开关接口

| 拨码 | 功能 |
| --- | --- |
| `SW[1:0] = 00` | 空闲，无音乐，黑背景 |
| `SW[1:0] = 01` | 播放 Canon，对应 Canon 曲目和谱面 |
| `SW[1:0] = 10` | 播放 Faded，对应 Faded 曲目和谱面 |
| `SW[1:0] = 11` | 播放 Aphasia，对应 Aphasia 曲目和谱面 |
| `SW2` | 静音开关，打开后音乐静音 |
| `SW[5:3]` | 谱面流速选择 |
| `SW14` | VS1003B 音高校准音阶测试 |
| `SW15` | 暂停开关，同时暂停音乐与谱面 |

说明：早期版本中 `SW2` 曾用于切换 RTL / MicroBlaze 模式。最终版本已经固定为 MicroBlaze SoC 方案，`SW2` 只作为静音开关使用。

### 4.5 LED、RGB LED 与数码管

| 外设 | 功能 |
| --- | --- |
| 16 个单色 LED | 氛围呼吸灯和音符/节奏可视化，不再作为主要调试灯使用 |
| RGB LED | 显示判定状态色，GOOD 绿色、BAD 蓝色、MISS 红色，READY/FINISH 类状态偏白色提示 |
| 八位数码管前四位 | 显示最近判定或结束评级，如 GOOD、BAD、MISS/等级 |
| 八位数码管后四位 | 显示百分比得分，满分为 9999，即 99.99% |

数码管和 LED 的物理扫描由 RTL 负责，显示内容来自 MicroBlaze 软件状态。

### 4.6 UART 与调试接口

工程中仍保留 MicroBlaze UART 和 MDM/JTAG 调试接口，主要用于 SDK/XSCT 下载 ELF、暂停 CPU、读取寄存器和调试运行状态。课堂演示时不依赖 UART 输出。

## 5. 音频播放方案

本项目最终音频路径为：

```text
MIDI 主旋律数据
  -> 编译进 MicroBlaze ELF 的 C 数组
  -> MicroBlaze 按 VS1003B DREQ 流控分块发送
  -> VS1003B 解码 MIDI
  -> PHONE 口输出模拟音频
```

相比 J8 PWM 方波输出，VS1003B 的优点是：

- 支持 MIDI/MP3 等压缩或音乐数据格式；
- 模块内部完成音频解码和 DAC 输出；
- 音色和音乐表现力明显优于 FPGA 直接输出方波；
- 适合课堂演示真实旋律。

当前三首曲目均为较小的 MIDI 主旋律片段，适合放入 MicroBlaze 本地存储并随 ELF 下载。若未来要播放完整 MP3 或更长歌曲，应使用外部 Flash、SD 卡或串口缓存等方式，不建议把完整音频硬塞进 RTL ROM。

## 6. 谱面与游戏机制

游戏为三轨下落式音游：

- 音符从上方向判定线下落；
- 玩家按 BTNL / BTNC / BTNR 击打左中右三轨；
- 判定窗口按时间差划分 GOOD、BAD、MISS；
- hold 长条需要保持到尾部结束，提前错过或未按会判定失败；
- 歌曲结束后进入 FINISH 状态，并根据百分比得分显示评级；
- `SW15` 可暂停音乐和谱面；
- `SW[5:3]` 可调整流速。

谱面文本位于 `charts/` 目录，生成后的 C 头文件位于 `Mini_IO.sdk/SeriesIODacSaw/src/generated_charts.h`。修改谱面通常只需要重新生成资源并重新下载 ELF，不一定需要重新生成 bitstream。

## 7. 验收演示步骤

1. 检查硬件连接：
   - VGA 线连接显示器；
   - VS1003B 模块按 JA 接线表连接；
   - 耳机或小音箱插 PHONE；
   - Nexys4 DDR USB 连接电脑并上电。

2. 烧录工程：

```powershell
cd F:\FPGA\mircoCom\Genneral\Mini_IO
& "D:\Xilinx\SDK\2018.3\bin\xsct.bat" scripts\program_bit_and_download_seriesiodacsaw.tcl
```

3. 设置拨码：
   - `SW2 = 0`，取消静音；
   - `SW15 = 0`，取消暂停；
   - `SW[1:0] = 01/10/11` 选择 Canon/Faded/Aphasia。

4. 观察 VGA：
   - 中间显示三轨；
   - 左右侧显示曲目、流速、静音/暂停、分数、判定等 UI；
   - 有音符下落；
   - 切换曲目时曲绘和谱面随之变化。

5. 测试音频：
   - 选择曲目后，VS1003B PHONE 口应输出对应 MIDI 主旋律；
   - `BTNU/BTND` 应能调整音量；
   - `SW2=1` 后静音。

6. 测试判定：
   - 按 BTNL/BTNC/BTNR 对应左中右轨；
   - 命中显示 GOOD/BAD/MISS；
   - 数码管后四位显示百分比得分；
   - LED/RGB LED 随状态变化。

7. 测试暂停与结束：
   - `SW15=1` 后音乐和谱面同时暂停；
   - `SW15=0` 恢复；
   - 歌曲结束后进入 FINISH，并显示评级。

## 8. 已验证状态

最近一次验证中：

- `release/design_mb_wrapper.bit` 已成功生成；
- `release/SeriesIODacSaw.elf` 已成功下载；
- XSCT 能识别 `xc7a100t` 和 `MicroBlaze #0`；
- MicroBlaze 状态为 Running；
- 暂停读取时 PC 不为 0，程序正文已写入 BRAM；
- GPIO 状态能看到 MicroBlaze 正在写 VS1003B/显示状态总线。

这说明当前 bitstream 与 ELF 文件配套，MicroBlaze 程序能够在板上运行。

## 9. 验收时可强调的创新点

- 使用 MicroBlaze SoC 方式组织游戏逻辑，而不是单纯 RTL 小实验；
- VS1003B 外部音频模块负责解码播放，音频质量优于 J8 PWM 方波；
- VGA 画面有三轨音游 UI、曲绘、判定、分数和状态栏；
- 谱面和 MIDI 资源与硬件分离，后续可主要通过软件/资源文件调整；
- 按键、拨码、LED、数码管、VGA、音频模块均接入同一综合系统。

## 10. 注意事项

- FPGA bitstream 和 MicroBlaze ELF 都是易失的，板子断电后需要重新烧录。
- VS1003B 的 PHONE 是音频输出口，LINE IN 不是输出口。
- 修改 PMOD 引脚、VGA 硬件绘制、曲绘 ROM 尺寸等硬件内容需要重新生成 bitstream。
- 只修改谱面逻辑、判定窗口、音量表或 MIDI C 数组时，通常只需重新编译/下载 ELF。
- 若烧录后无声音，优先检查 `SW2` 是否静音、`SW15` 是否暂停、耳机是否插 PHONE、JA 接线和 VS1003B 供电是否正确。
