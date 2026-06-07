# Verilog 迁移为 MicroBlaze 控制程序方案

本文描述如何把当前 `rhythm_video_audio.v` 中较多自运行的 Verilog 音游逻辑，逐步迁移为以 MicroBlaze C 程序为核心控制的 SoC 实现。目标不是完全取消硬件逻辑，而是让 MicroBlaze 负责系统控制、菜单、判定、音频播放调度和按键中断；硬件只保留必须实时稳定输出的接口时序。

## 总体原则

MicroBlaze 适合处理：

- 菜单状态机。
- 歌曲选择。
- 流速和 BPM 配置。
- 谱面读取和事件调度。
- 按键中断处理。
- 分数、连击、GOOD/BAD/MISS 判定。
- VS1003B 初始化和音频数据发送调度。
- 数码管、LED、VGA UI 状态寄存器更新。

MicroBlaze 不适合直接逐像素实时产生 VGA 行场同步，因为 VGA 像素时钟要求稳定，软件循环无法保证每个像素周期都准确。因此 VGA 的 `hsync/vsync/rgb` 扫描时序仍应由硬件模块完成，但画面内容可以由 MicroBlaze 写入 framebuffer 或画面寄存器。

最终目标：

```text
MicroBlaze 软件负责游戏逻辑
Verilog/AXI 外设负责实时信号输出
```

## 模块迁移分工

| 功能 | 当前方式 | 迁移目标 |
| --- | --- | --- |
| 按键读取 | RTL 直接读取 `buttons` | AXI GPIO 输入 + 中断 |
| 按键判定 | RTL 计算 GOOD/BAD/MISS | MicroBlaze 在中断/定时器中计算 |
| 谱面推进 | RTL 内部计数 | MicroBlaze Timer tick 推进 |
| 分数/连击 | RTL 内部寄存器 | MicroBlaze 全局变量维护 |
| 数码管/LED | RTL 输出 | AXI GPIO 或自定义显示外设输出 |
| VGA 同步 | RTL 扫描 | 保留硬件 VGA 扫描 |
| VGA 内容 | RTL 绘制 | MicroBlaze 写 framebuffer/寄存器 |
| VS1003B 初始化 | RTL 状态机 | MicroBlaze 通过 AXI SPI/GPIO 初始化 |
| VS1003B 播放 | RTL ROM 播放 | MicroBlaze 从 BRAM/Flash/SD 读 MP3 并按 DREQ 发送 |

## VGA 控制方案

### 推荐方案 A：字符/图形寄存器外设

保留一个轻量 VGA 硬件模块，模块负责：

- 产生 VGA `hsync/vsync`。
- 输出 RGB。
- 绘制三轨道、判定线、音符、侧边 UI。

MicroBlaze 通过 AXI GPIO 或自定义 AXI-Lite 寄存器写入：

```text
game_state
song_id
speed_level
score
combo
last_judge
lane_note_y[0..N]
lane_note_type[0..N]
hold_state
pause_flag
```

优点是硬件资源少，软件只写状态，不需要大 framebuffer。

### 推荐方案 B：Framebuffer

使用 BRAM 或外部存储作为 framebuffer：

```text
MicroBlaze 写像素/字符缓冲
VGA 硬件按像素时钟读取 framebuffer 输出
```

优点是 MicroBlaze 对画面控制更自由；缺点是 BRAM 占用较大，刷新整屏较慢。对 640x480 全彩 framebuffer 不现实，建议只做低分辨率 tile buffer 或字符 buffer。

### 建议选择

课堂音游演示建议使用方案 A：MicroBlaze 写状态寄存器，VGA 硬件按寄存器绘制。这样既体现 SoC 控制，又能保证 VGA 稳定。

## VS1003B 控制方案

VS1003B 应从 RTL 播放状态机迁移为 MicroBlaze 软件驱动。硬件连接建议如下：

需要明确的是，VS1003B 的价值在于播放已有音频/压缩音频文件。J8 PWM 或手写音符只能作为备用提示音、校音或早期调试方式，不应成为正式音乐播放主线。正式路线应学习参考例程：把 MIDI/MP3 等 VS1003B 可识别数据存入 ROM、BRAM、Flash、SD 卡或软件数组，再按 `DREQ` 分块送入 VS1003B。

```text
AXI Quad SPI:
  SCLK -> VS1003B SCLK
  MOSI -> VS1003B MOSI
  MISO -> VS1003B MISO

AXI GPIO output:
  XCS
  XDCS
  XRST

AXI GPIO input:
  DREQ
```

软件流程：

1. `XRST=0`，延时，`XRST=1`。
2. 等待 `DREQ=1`。
3. 拉低 `XCS`，通过 SPI 写 SCI 寄存器。
4. 配置 `SCI_MODE`、`SCI_CLOCKF`、`SCI_VOL`。
5. 播放时拉低 `XDCS`。
6. 每次 `DREQ=1` 时发送最多 32 字节 MP3 数据。
7. 音频数据结束后发送若干 zero/end fill bytes。

对于 MIDI 文件也采用同样的 SDI byte-stream 发送方式。VS1003B 会根据文件头识别数据格式，因此软件层不应把 MIDI/MP3 当成“音符波形”重新合成，而应把它们当作待解码的连续字节流。

伪代码：

```c
void vs1003_write_sci(uint8_t addr, uint16_t data);
void vs1003_send_audio_block(const uint8_t *buf, int len);

void vs1003_init(void) {
    gpio_set(XRST, 0);
    delay_ms(10);
    gpio_set(XRST, 1);
    wait_dreq();

    vs1003_write_sci(SCI_MODE, 0x0800);
    vs1003_write_sci(SCI_CLOCKF, 0x6000);
    vs1003_write_sci(SCI_VOL, 0x7070);
}

void vs1003_play_loop(void) {
    while (!audio_eof) {
        if (gpio_get(DREQ)) {
            read_next_audio_bytes(audio_buf, 32);
            vs1003_send_audio_block(audio_buf, 32);
        }
        rhythm_game_tick_if_due();
    }
}
```

这样做的好处是：更换 MP3/MIDI/谱面时不一定需要重新生成 bitstream，只需要替换软件或存储数据。

### 大文件播放实施路线

参考例程的思路是“数据文件 + VS1003B 流式发送”，而不是 FPGA 内部实时合成完整音乐。迁移到 MicroBlaze 后，建议按容量分阶段实现：

1. 小文件阶段：把单轨 MIDI 或短 MP3 片段放入 `const uint8_t song[]`，MicroBlaze 从数组中每次取 32 字节发送。
2. 中等文件阶段：把数据放入 BRAM 或独立数据段，仍由 MicroBlaze 按 `DREQ` 拉取发送。
3. 大文件阶段：增加 SD 卡或 SPI Flash 文件读取，MicroBlaze 用小缓冲区循环读取，例如 512 字节缓存，每次 `DREQ=1` 发送 32 字节。
4. 音游同步：播放开始时记录 `game_time_ms=0`，谱面事件按同一软件 Timer 推进，音频发送循环中不能阻塞 Timer 和按键中断。

大文件播放的关键不是音频合成算法，而是：

```text
文件来源稳定
缓冲区不断流
DREQ 流控正确
SPI 时序可靠
游戏 Timer 不被播放循环卡住
```

## 按键中断方案

三个音游按键固定为：

```text
BTNL(P17) -> 左轨
BTNC(N17) -> 中轨
BTNR(M17) -> 右轨
```

迁移后应使用 AXI GPIO 读取按键，并接入 AXI Interrupt Controller。建议中断源包括：

- GPIO 按键边沿中断。
- AXI Timer 周期中断。

按键中断只记录事件，不做过长计算：

```c
volatile uint32_t key_event_flags;
volatile uint32_t key_event_time_ms[3];

void button_isr(void) {
    uint32_t keys = gpio_read_buttons();
    uint32_t now = game_time_ms;

    if (rising_edge_left(keys)) {
        key_event_flags |= KEY_LEFT;
        key_event_time_ms[0] = now;
    }
    if (rising_edge_center(keys)) {
        key_event_flags |= KEY_CENTER;
        key_event_time_ms[1] = now;
    }
    if (rising_edge_right(keys)) {
        key_event_flags |= KEY_RIGHT;
        key_event_time_ms[2] = now;
    }

    clear_gpio_interrupt();
}
```

Timer 中断负责推进游戏时间：

```c
void timer_isr(void) {
    game_time_ms += TICK_MS;
    update_chart_scroll();
    resolve_pending_key_events();
    resolve_miss_notes();
    update_vga_registers();
    update_led_and_sevenseg();
    clear_timer_interrupt();
}
```

判定规则建议仍保持：

```text
GOOD: abs(key_time - note_time) <= good_window_ms
BAD : abs(key_time - note_time) <= bad_window_ms
MISS: 音符超过 bad_window_ms 仍未命中
```

双押或多键同时命中时，若多个轨道得到不同评价，按较差结果显示，避免 RGB/判定显示冲突。

## 谱面数据迁移方案

当前谱面可以继续保持文本化，便于玩家自制：

```text
time_ms,lane,type,duration_ms
1200,L,tap,0
1800,C,hold,600
2400,R,tap,0
```

构建时转换为 C 数组或 BRAM 初始化数据：

```c
typedef struct {
    uint32_t time_ms;
    uint8_t lane;
    uint8_t type;
    uint16_t duration_ms;
} NoteEvent;
```

MicroBlaze 程序按 `game_time_ms` 查询即将出现的音符，并把当前可见音符列表写给 VGA 外设。

## 推荐迁移阶段

### 阶段 1：MicroBlaze 接管菜单和状态

- 歌曲选择由 MicroBlaze 管理。
- 流速、暂停、开始由 MicroBlaze 管理。
- VGA 仍由当前 RTL 绘制，但读取 MicroBlaze 写入的寄存器。

### 阶段 2：MicroBlaze 接管按键和判定

- 按键进入 AXI GPIO 中断。
- Timer 产生固定游戏 tick。
- GOOD/BAD/MISS 和分数由 C 程序计算。
- RGB/数码管显示由 C 程序输出。

### 阶段 3：MicroBlaze 接管 VS1003B

- 使用 AXI Quad SPI + GPIO 控制 VS1003B。
- MP3 数据从 BRAM、Flash 或 SD 卡读取。
- 播放和音游时间轴由同一个软件时钟协调。

### 阶段 4：减少 RTL 自运行逻辑

- `rhythm_video_audio.v` 保留 VGA 扫描、图形绘制、接口寄存器。
- 删除或停用 RTL 内部的谱面推进、判定、分数和音频播放状态机。
- 项目形态变为真正的 MicroBlaze SoC 应用。

## 预期收益

- 更符合“使用 MicroBlaze 核运行综合项目”的要求。
- 改谱面、歌曲、菜单逻辑时可以主要改 C 程序，不必每次完整生成 bitstream。
- VS1003B 播放更接近参考例程的软件/外设协作方式。
- VGA、音频、按键、显示都能通过 SoC 统一调度，答辩逻辑更清晰。

## 常见内容迁移清单

下表用于后续协作时判断“这次修改是否应该重新生成 bitstream”。原则是：频繁调整、课堂演示时需要反复试的内容尽量放到 MicroBlaze 软件或外部数据；只有管脚、时钟、AXI 外设结构、VGA 像素扫描这类硬件边界变化才重新跑 Vivado。

| 内容 | 建议放置位置 | 改动后是否需要重新 bitstream | 说明 |
| --- | --- | --- | --- |
| 歌曲选择逻辑 | MicroBlaze C | 否 | 由拨码/菜单读入后选择数据源 |
| BPM、整体速度、流速档位 | MicroBlaze C | 否 | 作为运行时变量，不写死在 RTL |
| VS1003B 音量 | MicroBlaze C | 否 | 通过 SCI_VOL 写寄存器即可 |
| VS1003B 初始化参数 | MicroBlaze C | 否 | 例如 SCI_MODE、SCI_CLOCKF、SCI_VOL |
| MIDI/MP3 字节流 | C 数组、BRAM 数据、SD/Flash 文件 | 通常否 | 若仍用 Verilog ROM 初始化，则需要 bitstream |
| 谱面文本 | 外部文本或构建生成的 C 数组 | 否 | 玩家自制谱面应避免进入 RTL |
| 判定窗口 | MicroBlaze C | 否 | GOOD/BAD/MISS 时间窗用变量/宏管理 |
| 分数、连击、结束机制 | MicroBlaze C | 否 | 属于游戏规则，适合软件 |
| 按键去抖和边沿检测 | MicroBlaze C + AXI GPIO 中断 | 否 | 中断只记事件，Timer 统一判定 |
| LED/RGB/数码管显示内容 | MicroBlaze C | 否 | 写 AXI GPIO 或显示寄存器 |
| VGA 菜单文字和 UI 状态 | MicroBlaze C 写寄存器 | 否 | RTL 负责绘制模板，软件写状态 |
| VGA 行场同步、像素时钟 | Verilog 外设 | 是 | 必须保持硬件实时输出 |
| PMOD/按钮/拨码管脚 | XDC + 顶层硬件 | 是 | 改管脚约束必须重新实现 |
| AXI 外设增删、地址映射 | Vivado Block Design | 是 | 硬件平台变化，需要新 bitstream 和 BSP |

## 避免反复生成 bitstream 的工作流

推荐把工程分成“固定硬件平台”和“可频繁替换的软件/资源”两层：

```text
固定硬件 bitstream:
  MicroBlaze + AXI GPIO + AXI SPI + AXI Timer + Interrupt Controller
  VGA 扫描/绘图外设
  VS1003B 接口引脚

可频繁替换的软件/资源:
  main.c / vs1003.c / chart.c / song_data.c
  谱面文本转换出的 C 数组
  SD/Flash/串口下载的 MIDI 或 MP3 数据
```

日常修改建议流程：

1. 只改歌曲数据、谱面、音量、BPM、判定窗口、菜单逻辑时，只编译 SDK C 程序并下载 ELF。
2. 若歌曲较短，可以先作为 `const uint8_t song[]` 放进 MicroBlaze 程序，验证最快。
3. 若歌曲超过 BRAM/程序空间承受范围，改为 SD 卡、Flash 或串口加载，硬件 bitstream 仍保持不变。
4. 只有新增外设、改 AXI 地址、改 PMOD 管脚、改 VGA 像素级绘图硬件时，才重新跑 Vivado 生成 bitstream。

### SDK/ELF 优先修改项

以下内容后续不建议再写进 `rhythm_video_audio.v` 的巨大状态机：

```text
song_id
song_length
song_bpm
volume_level
chart_note_table
good_window_ms
bad_window_ms
score
combo
pause_flag
finish_flag
last_judge
```

这些变量由 MicroBlaze 维护，再通过 AXI GPIO 或自定义 AXI-Lite 寄存器同步给 VGA/LED/数码管外设。这样课堂调试时可以快速改 C 程序，而不是每次等待综合、布局布线和 bitstream。

## 风险与注意事项

- VGA 像素时序不能完全依赖 C 软件循环，应保留硬件扫描。
- VS1003B 的 `DREQ` 必须严格作为流控信号，不能无脑连续发送。
- 按键中断要做去抖或边沿过滤，避免一次按下触发多次。
- 若 MP3 数据放入 BRAM，容量有限；完整音乐更适合 SD 卡或外部 Flash。
- 若只把 MicroBlaze 挂在工程里但不参与控制，答辩时 SoC 说服力不足。
