#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


SOURCE_GRID = 5
OUTPUT_COLUMNS = 6
OUTPUT_ROWS = 4
OUTPUT_CELL_SIZE = 256


def repack(source: Image.Image) -> Image.Image:
    source = source.convert("RGBA")
    source_cell_width = source.width // SOURCE_GRID
    source_cell_height = source.height // SOURCE_GRID
    output = Image.new(
        "RGBA",
        (OUTPUT_COLUMNS * OUTPUT_CELL_SIZE, OUTPUT_ROWS * OUTPUT_CELL_SIZE),
        (0, 0, 0, 255),
    )

    for index in range(OUTPUT_COLUMNS * OUTPUT_ROWS):
        source_column = index % SOURCE_GRID
        source_row = index // SOURCE_GRID
        if source_row >= SOURCE_GRID:
            break

        crop = source.crop(
            (
                source_column * source_cell_width,
                source_row * source_cell_height,
                (source_column + 1) * source_cell_width,
                (source_row + 1) * source_cell_height,
            )
        )
        tile = crop.resize((OUTPUT_CELL_SIZE, OUTPUT_CELL_SIZE), Image.Resampling.LANCZOS)
        output.alpha_composite(
            tile,
            (
                (index % OUTPUT_COLUMNS) * OUTPUT_CELL_SIZE,
                (index // OUTPUT_COLUMNS) * OUTPUT_CELL_SIZE,
            ),
        )

    return output.convert("RGB")


def main() -> None:
    parser = argparse.ArgumentParser(description="Repack a 5x5 texture atlas as a 6x4 reference tileset.")
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()

    source = Image.open(args.input)
    output = repack(source)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    output.save(args.output)
    print(f"Wrote {args.output}")


if __name__ == "__main__":
    main()
