# 2026-06-08 MicroBlaze 谱面驱动

## 用户要求

- 接下来做 MicroBlaze 驱动音符/谱面状态。
- 将 UI 与画面绘制进一步 MicroBlaze 化。

## 本次实现

本次完成第二阶段迁移：`SW2=1` 的 MicroBlaze 模式下，VGA 轨道上的可见音符和 hold mask 改为由 MicroBlaze 软件计算并发送给 RTL。

## 数据通路

为了避免立即新增 Block Design IP，本次复用现有 AXI GPIO1 的七段数码管输出作为短 packet 总线：

```text
mb_an_status[7:5] == 000 -> VGA packet
mb_an_status[4:0]        -> packet id
mb_seg_status[7:0]       -> packet data
```

packet 分配：

- `0..11`：三条轨道 note mask，每条轨道 32 bit，按 8 bit 分 4 包。
- `12..23`：三条轨道 hold mask，每条轨道 32 bit，按 8 bit 分 4 包。
- `24`：三轨按键状态。

VGA RTL 在 `mb_mode=1` 时锁存这些 packet，并使用 MicroBlaze 传来的 `ui_note_tracks/ui_hold_tracks/ui_buttons` 绘制轨道；`mb_mode=0` 时仍使用旧 RTL `rhythm_game_core`。

## 修改文件

- `Mini_IO.sdk/SeriesIODacSaw/src/rhythm_game.c`
  - 新增 Aphasia 独立演示谱面 `Song2`。
  - 新增 `MbVgaBuildTracks()`，根据 `GameTimeMs` 和 C 谱面表计算 32 行可见 note/hold mask。
  - 新增 `MbVgaSendFrame()`，每个 timer tick 发送当前谱面 frame packet。

- `Mini_IO.srcs/sources_1/new/rhythm_video_audio.v`
  - 新增 MicroBlaze note/hold/button latch。
  - `SW2=1` 时轨道绘制使用 MicroBlaze packet 状态。

- `Mini_IO.sdk/SeriesIODacSaw/src/lscript.ld`
  - 将 `_HEAP_SIZE` 从 `0x800` 缩小到 `0x100`。
  - 原因：MicroBlaze BRAM 空间接近上限，工程没有动态内存分配，缩小 heap 可为新增谱面/UI 逻辑让出空间。

## 验证

```text
SDK build: OK
xvlog wrapper + rhythm_video_audio: OK
Vivado synth/impl/write_bitstream: OK
XSCT program bit + download ELF: OK
```

ELF size:

```text
text=30828 data=392 bss=1348 dec=32568
```

## 当前限制

- VGA 像素扫描和基本绘制模板仍在 RTL，这是必要的高速时序部分。
- MicroBlaze 目前发送的是 32 行 mask，不是逐像素 framebuffer。
- 复用七段数码管 GPIO 作为 packet 总线，可能让物理数码管在 MicroBlaze 模式下有轻微闪烁；VGA UI 本身会锁存 packet。
- 下一步如果需要更干净的接口，应新增专用 AXI-Lite VGA 状态寄存器，而不是继续复用七段数码管 GPIO。
