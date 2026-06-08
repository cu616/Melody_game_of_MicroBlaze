# 2026-06-08 VGA/UI MicroBlaze 迁移一期

## 用户要求

- 在提交当前版本和迁移状态分析后，开始 VGA 接口和 UI 绘制的 MicroBlaze 迁移。

## 本次迁移范围

本次是第一阶段迁移，不取消 VGA 硬件扫描，也不一次性删除 RTL 音游核心。目标是先建立 MicroBlaze 到 VGA UI 的状态通路：

- VGA 像素时序仍由 RTL 保证。
- MicroBlaze 通过现有 AXI GPIO 输出把软件侧状态送给 VGA RTL。
- VGA 右侧 UI 开始读取 MicroBlaze 的曲目、判定、音量、暂停/结束和分数显示状态。

## 修改内容

- `Mini_IO.srcs/sources_1/bd/design_mb/hdl/design_mb_wrapper.v`
  - 将 MicroBlaze 的 LED、RGB、七段数码管输出同步接入 `rhythm_video_audio`。
  - 不新增 Block Design IP，只复用现有 AXI GPIO 输出线。

- `Mini_IO.srcs/sources_1/new/rhythm_video_audio.v`
  - 新增 `mb_mode`、`mb_led_status`、`mb_rgb_status`、`mb_seg_status`、`mb_an_status` 输入。
  - `SW2=1` 时，VGA UI 的曲目/判定/分数/暂停/结束/音量优先显示 MicroBlaze 软件侧状态。
  - 从 MicroBlaze 七段数码管扫描信号中锁存后四位分数，供 VGA 右侧 SCORE 显示。
  - `SW2=1, SW1:SW0=00` 时，VGA 不再因为 RTL 的 `audio_enabled=0` 而停在 ready 画面。

- `Mini_IO.sdk/SeriesIODacSaw/src/rhythm_game.c`
  - 在 GPIO0 channel 2 高位编码 MicroBlaze 软件 UI 状态：
    - `[15:14]` 游戏状态：wait/play/pause/done
    - `[13:12]` 曲目
    - `[11:10]` 判定：none/good/bad/miss
    - `[9:6]` 音量档
    - `[4:0]` 仍保留给 VS1003B bit-bang 总线
  - 低 5 位仍用于 VS1003B 的 `XCS/XDCS/XRST/MOSI/SCLK`，避免影响发声。

## 验证结果

```text
SDK build: OK
xvlog syntax check: OK
Vivado synth/impl/write_bitstream: OK
Generated bitstream: Mini_IO.runs/impl_1/design_mb_wrapper.bit
XSCT program bit + download ELF: OK
```

Vivado 报告中有既有 warning/critical warning，包括 CFGBVS/CONFIG_VOLTAGE 提示和 Xilinx IP 相关提示；本次没有 error，bitgen 成功。

## 当前限制

- VGA 轨道音符本身仍来自 RTL `rhythm_game_core`，尚未完全由 MicroBlaze 驱动。
- MicroBlaze 软件侧 Aphasia 仍复用 `Song1` 判定谱面，后续需要新增 `Song2`。
- 物理 LED 高位现在更偏向 MicroBlaze UI 状态编码，不再完全等同早期 VS1003B 调试灯。

## 下一步

建议第二阶段新增更明确的 MicroBlaze-to-VGA 状态寄存器或自定义 AXI-Lite 外设，让音符位置、谱面事件、combo、判定线效果都由 MicroBlaze 写入，而 RTL 只负责稳定绘制。
