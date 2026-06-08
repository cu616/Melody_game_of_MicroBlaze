# 2026-06-08 VGA Aphasia 曲绘与三曲目 UI 修改日志

## 本次需求

- 继续推进 VGA 画面模块的 MicroBlaze 化，重点覆盖像素扫描、文字、轨道、曲绘模板相关内容。
- 将 `aphasia_raw_black` 作为 Aphasia 曲绘加入工程。
- 左侧 UI 曲目菜单需要显示 Aphasia 选项卡。
- 检查曲绘处理流程，避免移植到 VGA 画面时横向拉伸导致人物比例变形；允许裁切，但不能改变原图比例。

## 实现说明

- VGA 行/场同步与 25 MHz 像素扫描仍保留在 RTL 中，这是稳定 VGA 输出所需的硬实时逻辑，不适合由 MicroBlaze 软件循环逐像素驱动。
- MicroBlaze 继续负责歌曲选择、游戏状态、判定状态、音量、谱面 note/hold/button 状态，并通过 GPIO 状态包驱动 RTL 的画面模板。
- RTL 画面模板新增 Aphasia 选项卡，并修正了歌曲高亮逻辑：
  - `SW[1:0]=01` 高亮 Canon。
  - `SW[1:0]=10` 或默认 Faded 时高亮 Fade。
  - `SW[1:0]=11` 高亮 Aphasia。
- 曲绘 ROM 从两首歌扩展为三首歌：
  - Canon: `canon_track_bg_*`
  - Fade/Faded: `fade_track_bg_*`
  - Aphasia: `aphasia_track_bg_*`

## 曲绘比例处理

- 中央轨道背景 ROM 固定为 `120x192`，VGA 上以 2 倍显示为 `240x384`，显示比例为 `5:8`。
- `scripts/convert_album_art.py` 当前默认 `--fit cover`，即先按目标比例等比缩放，再中心裁切；不会使用横向或纵向强拉伸。
- 新增 Aphasia 曲绘使用：

```powershell
python scripts\convert_album_art.py scripts\pictures\aphasia_raw_black.png --width 120 --height 192 --colors 64 --mode indexed --fit cover --out-dir generated\album_art --prefix aphasia_track_bg
```

## 已验证

- 已生成 `generated/album_art/aphasia_track_bg_index.mem` 与 `generated/album_art/aphasia_track_bg_palette.mem`。
- 已用 `xvlog` 对 `design_mb_wrapper.v`、`design_mb.v`、`rhythm_video_audio.v` 做语法检查，通过。
- SDK 工程本次无 C 源改动，`make all` 显示无需重编。

## 仍需注意

- 因为新增了曲绘 ROM 和 RTL UI 逻辑，必须重新生成 bitstream 后，板端 VGA 才会显示 Aphasia 曲绘和第三个选项卡。
