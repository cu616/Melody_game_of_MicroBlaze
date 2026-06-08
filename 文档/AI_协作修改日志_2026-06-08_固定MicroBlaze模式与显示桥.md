# 2026-06-08 固定 MicroBlaze 模式与显示桥修改日志

## 本次需求

- 用户反馈 `SW=2` 或 `SW2=1` 后出现数码管全亮、LED 全灭，怀疑 `SW2` 仍在控制 MicroBlaze/RTL 模式切换。
- 作业目标要求突出 MicroBlaze SoC 实现，不再保留可切换的旧 RTL 音游模式。
- 希望 VGA 像素扫描、文字、轨道、曲绘模板继续向 MicroBlaze 控制方向迁移。

## 修改内容

- `design_mb_wrapper.v` 中去掉 `SW2` 对 MicroBlaze/RTL 的模式选择：
  - VS1003B 控制线始终由 MicroBlaze GPIO 输出驱动。
  - VGA/UI/LED/数码管显示由 RTL 显示桥根据 MicroBlaze 状态稳定输出。
- `rhythm_video_audio.v` 中固定 UI 使用 MicroBlaze 状态，不再让 `SW2` 触发 VS1003B RTL demo。
- 修复物理数码管显示冲突：
  - MicroBlaze 的 GPIO1 仍用于向 RTL 发送 VGA 谱面 packet。
  - 新增 `rhythm_mb_sevenseg`，把 RTL 已捕获的 MicroBlaze 分数、判定、暂停/结束状态重新扫描到物理数码管。
  - 避免物理数码管直接显示 GPIO1 packet 导致全亮或乱亮。
- UI 左侧 VS1003B 区域从 `SW2/DEMO OFF` 改成 `MB/MIDI ON`，避免误导用户继续拨 `SW2`。

## 关于 VGA 扫描的边界

- VGA `HS/VS` 与 RGB 像素扫描仍保留在 RTL 中。
- 原因：640x480 VGA 需要约 25 MHz 像素时序，MicroBlaze 软件循环无法可靠逐像素输出同步信号。
- 当前工程采用的 SoC 方案是：
  - MicroBlaze 负责歌曲选择、暂停、音量、判定、分数、谱面 note/hold/button 状态、VS1003B 播放。
  - RTL 负责 VGA 行场同步、像素级文字/轨道/曲绘合成、数码管扫描等硬实时显示桥。

## 需要重新生成 bitstream

- 本次修改包含 wrapper 与 RTL 逻辑，必须重新生成并下载 bitstream。
- 只重新下载 ELF 不会改变 `SW2` 模式选择或 VGA/数码管显示桥。
