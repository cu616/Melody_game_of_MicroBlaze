# MicroBlaze SoC 实现说明

本文用于说明当前 `Mini_IO` 工程为什么属于基于 MicroBlaze 的 SoC 综合项目，以及后续答辩时应如何描述系统分工。

## 当前工程定位

当前工程顶层为 `design_mb_wrapper`，内部包含 Vivado Block Design 生成的 `design_mb` 系统。该系统集成了 MicroBlaze 软核、AXI 总线、BRAM、AXI GPIO、AXI UARTLite、AXI Quad SPI、Timer、Interrupt Controller 等模块，因此硬件平台本身属于典型的 FPGA 软核 SoC 架构。

自定义音游逻辑目前主要位于：

```text
Mini_IO.srcs/sources_1/new/rhythm_video_audio.v
```

也就是说，当前实现是：

```text
MicroBlaze SoC 平台 + 自定义 Verilog 音游/VGA/音频外设逻辑
```

这不是纯 VHDL 工程。工程中存在的 `.vhd/.vhdl` 文件大多来自 Vivado/Xilinx IP 自动生成，例如 MicroBlaze、AXI 外设、BRAM 控制器等。

## 推荐答辩表述

可采用如下表述：

```text
本项目采用基于 MicroBlaze 的软核 SoC 架构。Vivado Block Design 中 MicroBlaze 作为系统控制核心，通过 AXI 总线连接 GPIO、UART、SPI、BRAM、Timer、Interrupt Controller 以及自定义音游显示/音频逻辑。实时性要求高的 VGA 扫描和部分音频时序由硬件外设完成，MicroBlaze 负责系统级控制，包括模式选择、歌曲选择、流速配置、开始暂停、按键中断处理、判定状态管理、分数统计和 VS1003B 播放控制。
```

如果老师强调“必须用 SoC 方式实现”，应重点强调：

1. MicroBlaze 是系统控制核心。
2. AXI 总线连接各类外设。
3. 按键、拨码、VGA、VS1003B、数码管、LED 等均通过 SoC 外设或自定义 AXI 外设进行统一管理。
4. Verilog 不再被描述为独立顶层工程，而是作为 SoC 中的硬件外设或硬件加速模块。

## 当前实现的不足

当前音游主体逻辑仍有较多内容在 `rhythm_video_audio.v` 中自运行，包括：

- VGA 画面生成。
- 谱面推进。
- 按键判定。
- 分数和评价更新。
- VS1003B 内置 MP3 ROM 播放状态机。

这说明当前工程已经有 SoC 平台，但 MicroBlaze 对音游主体的控制参与度还可以继续加强。若要更符合“MicroBlaze 核运行综合项目”的实验要求，建议逐步把控制逻辑迁移到 MicroBlaze C 程序中，Verilog 只保留高速时序和接口适配部分。

## 建议目标架构

```text
+--------------------------+
| MicroBlaze C 程序         |
| - 菜单/模式/暂停          |
| - 歌曲/谱面/流速          |
| - 按键中断判定            |
| - 分数和评价              |
| - VS1003B 播放控制        |
+------------+-------------+
             |
             | AXI
             |
+------------v-------------+
| 自定义 AXI 外设/BRAM      |
| - VGA framebuffer/寄存器  |
| - 音游状态寄存器          |
| - VS1003B 控制 GPIO/SPI   |
| - 数码管/LED/RGB 输出     |
+------------+-------------+
             |
             | 实时硬件时序
             |
+------------v-------------+
| VGA/VS1003B/LED/按键硬件  |
+--------------------------+
```

在该架构中，MicroBlaze 负责“做什么”和“什么时候做”，硬件外设负责“稳定、准时地输出信号”。这比让全部 Verilog 自行运行更符合 SoC 课程目标。

## 与 bitstream 生成时间的关系

当前 Vivado 生成 bitstream 慢，主要慢在综合、布局布线和写 bitstream。只要修改内容进入 Verilog、XDC、Block Design、ROM 初始化或硬件顶层连接，Vivado 都需要重新处理硬件实现。

因此后续应把常见演示内容迁到 MicroBlaze 软件侧：

- 歌曲表、MIDI/MP3 数据索引、BPM 和音量。
- 谱面、流速、判定窗口、分数和结束机制。
- VS1003B 初始化、DREQ 判断和音频块发送。
- 菜单、暂停、READY/FINISH 状态、LED/RGB/数码管显示内容。

硬件 bitstream 应尽量只固定接口和实时外设：VGA 扫描、AXI GPIO、AXI SPI、Timer、中断控制器和必要的自定义 AXI-Lite 寄存器。这样改歌或改规则时只需重新编译 SDK 程序或替换外部数据，不必每次完整运行 Vivado。
