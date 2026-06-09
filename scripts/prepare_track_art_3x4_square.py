#!/usr/bin/env python3
"""Prepare track artwork by stretching to 3:4, then center-cropping to 1:1."""

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
PICTURES = ROOT / "scripts" / "pictures"
OUTPUT = ROOT / "generated" / "album_art"
STRETCHED_SIZE = (300, 400)
SQUARE_SIZE = 300


def prepare(song: str) -> None:
    source_path = PICTURES / f"{song}_raw_black.png"
    stretched_path = OUTPUT / f"{song}_3x4_stretched.png"
    square_path = OUTPUT / f"{song}_3x4_square.png"

    with Image.open(source_path) as source:
        stretched = source.convert("RGB").resize(
            STRETCHED_SIZE, Image.Resampling.LANCZOS
        )
    top = (STRETCHED_SIZE[1] - SQUARE_SIZE) // 2
    square = stretched.crop((0, top, SQUARE_SIZE, top + SQUARE_SIZE))
    stretched.save(stretched_path)
    square.save(square_path)
    print(f"{song}: {source_path.name} -> 300x400 -> 300x300")


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for song in ("canon", "fade", "aphasia"):
        prepare(song)


if __name__ == "__main__":
    main()
