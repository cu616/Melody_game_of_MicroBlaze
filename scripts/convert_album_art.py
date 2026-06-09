#!/usr/bin/env python3
"""
Convert an album-art image into FPGA-friendly memory files.

Default output format is palette indexed:
  - album_art_index.mem: one 8-bit palette index per pixel, row-major
  - album_art_palette.mem: one RGB444 palette color per line
  - album_art_preview.png: quantized preview
  - album_art_meta.json: dimensions and Verilog parameters

Example:
  python scripts/convert_album_art.py cover.png --width 96 --height 96 --colors 64 --out-dir generated/album_art
"""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
from typing import Iterable, Tuple

try:
    from PIL import Image
except ImportError as exc:  # pragma: no cover - user-facing dependency check
    raise SystemExit(
        "Pillow is required. Install it with `python -m pip install Pillow`, "
        "or run this script with a Python environment that already has Pillow."
    ) from exc


RGB = Tuple[int, int, int]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Convert album art to .mem files for VGA/FPGA ROM use."
    )
    parser.add_argument("image", type=Path, help="Input image path.")
    parser.add_argument(
        "--width",
        type=int,
        default=96,
        help="Output width in pixels. Default: 96.",
    )
    parser.add_argument(
        "--height",
        type=int,
        default=96,
        help="Output height in pixels. Default: 96.",
    )
    parser.add_argument(
        "--colors",
        type=int,
        default=64,
        help="Palette color count for indexed mode. Default: 64.",
    )
    parser.add_argument(
        "--mode",
        choices=("indexed", "rgb444"),
        default="indexed",
        help="Output mode. indexed saves indices plus palette; rgb444 saves direct RGB444 pixels.",
    )
    parser.add_argument(
        "--fit",
        choices=("cover", "contain", "stretch"),
        default="cover",
        help="Resize behavior. cover center-crops; contain letterboxes; stretch distorts.",
    )
    parser.add_argument(
        "--background",
        default="000000",
        help="RGB hex background for contain mode. Default: 000000.",
    )
    parser.add_argument(
        "--out-dir",
        type=Path,
        default=Path("generated") / "album_art",
        help="Output directory. Default: generated/album_art.",
    )
    parser.add_argument(
        "--prefix",
        default="album_art",
        help="Output filename prefix. Default: album_art.",
    )
    return parser.parse_args()


def require_range(name: str, value: int, lo: int, hi: int) -> None:
    if value < lo or value > hi:
        raise SystemExit(f"{name} must be between {lo} and {hi}; got {value}.")


def parse_rgb_hex(value: str) -> RGB:
    text = value.strip().lstrip("#")
    if len(text) != 6:
        raise SystemExit("--background must be 6 hex digits, for example 101010.")
    try:
        return tuple(int(text[i : i + 2], 16) for i in (0, 2, 4))  # type: ignore[return-value]
    except ValueError as exc:
        raise SystemExit("--background must contain only hex digits.") from exc


def resize_image(image: Image.Image, width: int, height: int, fit: str, background: RGB) -> Image.Image:
    src = image.convert("RGB")
    if fit == "stretch":
        return src.resize((width, height), Image.Resampling.LANCZOS)

    src_w, src_h = src.size
    if fit == "cover":
        scale = max(width / src_w, height / src_h)
        resized = src.resize((math.ceil(src_w * scale), math.ceil(src_h * scale)), Image.Resampling.LANCZOS)
        left = (resized.width - width) // 2
        top = (resized.height - height) // 2
        return resized.crop((left, top, left + width, top + height))

    scale = min(width / src_w, height / src_h)
    resized = src.resize((max(1, round(src_w * scale)), max(1, round(src_h * scale))), Image.Resampling.LANCZOS)
    canvas = Image.new("RGB", (width, height), background)
    canvas.paste(resized, ((width - resized.width) // 2, (height - resized.height) // 2))
    return canvas


def rgb888_to_rgb444(rgb: RGB) -> int:
    r, g, b = rgb
    return ((r >> 4) << 8) | ((g >> 4) << 4) | (b >> 4)


def write_lines(path: Path, lines: Iterable[str]) -> None:
    path.write_text("".join(f"{line}\n" for line in lines), encoding="ascii")


def quantize_indexed(image: Image.Image, colors: int) -> tuple[Image.Image, list[RGB], list[int]]:
    quantized = image.quantize(colors=colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.FLOYDSTEINBERG)
    palette_raw = quantized.getpalette() or []
    palette: list[RGB] = []
    for idx in range(colors):
        base = idx * 3
        if base + 2 < len(palette_raw):
            palette.append((palette_raw[base], palette_raw[base + 1], palette_raw[base + 2]))
        else:
            palette.append((0, 0, 0))
    indices = list(quantized.getdata())
    return quantized.convert("RGB"), palette, indices


def write_indexed_outputs(args: argparse.Namespace, image: Image.Image) -> dict:
    require_range("--colors", args.colors, 2, 256)
    preview, palette, indices = quantize_indexed(image, args.colors)

    index_bits = max(1, math.ceil(math.log2(args.colors)))
    index_hex_digits = max(2, math.ceil(index_bits / 4))

    index_path = args.out_dir / f"{args.prefix}_index.mem"
    palette_path = args.out_dir / f"{args.prefix}_palette.mem"
    preview_path = args.out_dir / f"{args.prefix}_preview.png"

    write_lines(index_path, (f"{value:0{index_hex_digits}X}" for value in indices))
    write_lines(palette_path, (f"{rgb888_to_rgb444(rgb):03X}" for rgb in palette))
    preview.save(preview_path)

    return {
        "mode": "indexed",
        "index_mem": str(index_path),
        "palette_mem": str(palette_path),
        "preview": str(preview_path),
        "colors": args.colors,
        "index_bits": index_bits,
        "index_hex_digits": index_hex_digits,
        "verilog": {
            "ART_WIDTH": args.width,
            "ART_HEIGHT": args.height,
            "ART_PIXELS": args.width * args.height,
            "ART_COLORS": args.colors,
            "ART_INDEX_BITS": index_bits,
        },
    }


def write_rgb444_outputs(args: argparse.Namespace, image: Image.Image) -> dict:
    pixels = [rgb888_to_rgb444(pixel) for pixel in image.getdata()]
    mem_path = args.out_dir / f"{args.prefix}_rgb444.mem"
    preview_path = args.out_dir / f"{args.prefix}_preview.png"

    write_lines(mem_path, (f"{value:03X}" for value in pixels))
    image.save(preview_path)

    return {
        "mode": "rgb444",
        "rgb444_mem": str(mem_path),
        "preview": str(preview_path),
        "verilog": {
            "ART_WIDTH": args.width,
            "ART_HEIGHT": args.height,
            "ART_PIXELS": args.width * args.height,
            "ART_RGB_BITS": 12,
        },
    }


def main() -> None:
    args = parse_args()
    require_range("--width", args.width, 1, 640)
    require_range("--height", args.height, 1, 480)

    if not args.image.is_file():
        raise SystemExit(f"Input image not found: {args.image}")

    args.out_dir.mkdir(parents=True, exist_ok=True)

    background = parse_rgb_hex(args.background)
    source = Image.open(args.image)
    converted = resize_image(source, args.width, args.height, args.fit, background)

    if args.mode == "indexed":
        meta = write_indexed_outputs(args, converted)
    else:
        meta = write_rgb444_outputs(args, converted)

    meta.update(
        {
            "source": str(args.image),
            "width": args.width,
            "height": args.height,
            "pixels": args.width * args.height,
            "fit": args.fit,
        }
    )

    meta_path = args.out_dir / f"{args.prefix}_meta.json"
    meta_path.write_text(json.dumps(meta, indent=2), encoding="ascii")

    print(f"Converted {args.image} -> {args.out_dir}")
    print(f"Mode: {meta['mode']}, size: {args.width}x{args.height}, pixels: {args.width * args.height}")
    if args.mode == "indexed":
        print(f"Index MEM: {meta['index_mem']}")
        print(f"Palette MEM: {meta['palette_mem']}")
    else:
        print(f"RGB444 MEM: {meta['rgb444_mem']}")
    print(f"Preview: {meta['preview']}")
    print(f"Meta: {meta_path}")


if __name__ == "__main__":
    main()
