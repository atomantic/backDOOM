#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


ROWS = 4
COLUMNS = 6
CELL_SIZE = 256
TARGET_MAX_WIDTH = 218
TARGET_MAX_HEIGHT = 226
BASELINE_Y = 244


def key_to_alpha(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    width, height = rgba.size

    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            green_delta = g - max(r, b)
            is_key = g > 150 and green_delta > 52
            is_soft_edge = g > 115 and green_delta > 24

            if is_key:
                pixels[x, y] = (r, g, b, 0)
            elif is_soft_edge:
                alpha = max(0, min(255, int((52 - green_delta) / 28 * 255)))
                # Despill the keyed edge so tiny matte leftovers read as shadow, not green.
                pixels[x, y] = (r, min(g, max(r, b) + 10), b, min(a, alpha))

    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            if a == 0:
                continue

            edge_pixel = a < 245
            if not edge_pixel:
                for ny in range(max(0, y - 1), min(height, y + 2)):
                    for nx in range(max(0, x - 1), min(width, x + 2)):
                        if pixels[nx, ny][3] == 0:
                            edge_pixel = True
                            break
                    if edge_pixel:
                        break

            if edge_pixel and g > max(r, b) + 12:
                pixels[x, y] = (r, max(r, b) + 8, b, a)

    return rgba


def alpha_bbox(image: Image.Image) -> tuple[int, int, int, int] | None:
    alpha = image.getchannel("A")
    return alpha.point(lambda value: 255 if value > 12 else 0).getbbox()


def is_foreground(pixel: tuple[int, int, int, int]) -> bool:
    r, g, b, _ = pixel
    return not (g > 150 and g - max(r, b) > 52)


def bands_from_projection(values: list[int], minimum: int, gap_bridge: int = 8) -> list[tuple[int, int]]:
    raw: list[tuple[int, int]] = []
    start: int | None = None

    for index, value in enumerate(values):
        if value >= minimum and start is None:
            start = index
        elif value < minimum and start is not None:
            raw.append((start, index))
            start = None

    if start is not None:
        raw.append((start, len(values)))

    if not raw:
        return []

    merged = [raw[0]]
    for start, end in raw[1:]:
        previous_start, previous_end = merged[-1]
        if start - previous_end <= gap_bridge:
            merged[-1] = (previous_start, end)
        else:
            merged.append((start, end))

    return merged


def split_band_evenly(start: int, end: int, count: int) -> list[tuple[int, int]]:
    span = end - start
    return [
        (
            start + round(span * index / count),
            start + round(span * (index + 1) / count),
        )
        for index in range(count)
    ]


def detected_cells(source: Image.Image) -> list[list[Image.Image]]:
    source = source.resize((CELL_SIZE * COLUMNS, CELL_SIZE * ROWS), Image.Resampling.LANCZOS).convert("RGBA")
    pixels = source.load()
    width, height = source.size
    y_projection = [
        sum(1 for x in range(width) if is_foreground(pixels[x, y]))
        for y in range(height)
    ]
    row_bands = bands_from_projection(y_projection, minimum=20, gap_bridge=4)
    row_bands = [(start, end) for start, end in row_bands if end - start > 48]

    if len(row_bands) != ROWS:
        row_bands = split_band_evenly(0, height, ROWS)

    cells: list[list[Image.Image]] = []
    for row_start, row_end in row_bands[:ROWS]:
        row_crop = source.crop((0, max(0, row_start - 4), width, min(height, row_end + 4)))
        row_pixels = row_crop.load()
        row_height = row_crop.height
        x_projection = [
            sum(1 for y in range(row_height) if is_foreground(row_pixels[x, y]))
            for x in range(width)
        ]
        column_bands = bands_from_projection(x_projection, minimum=8, gap_bridge=22)

        if len(column_bands) != COLUMNS:
            column_bands = split_band_evenly(0, width, COLUMNS)

        row_cells: list[Image.Image] = []
        for column_start, column_end in column_bands[:COLUMNS]:
            crop = row_crop.crop(
                (
                    max(0, column_start - 4),
                    0,
                    min(width, column_end + 4),
                    row_height,
                )
            )
            row_cells.append(key_to_alpha(crop))

        cells.append(row_cells)

    return cells


def repack(cells: list[list[Image.Image]]) -> Image.Image:
    output = Image.new("RGBA", (CELL_SIZE * COLUMNS, CELL_SIZE * ROWS), (0, 0, 0, 0))

    for row, row_cells in enumerate(cells):
        bounds = [alpha_bbox(cell) for cell in row_cells]
        non_empty_bounds = [bbox for bbox in bounds if bbox is not None]
        if not non_empty_bounds:
            continue

        max_width = max(bbox[2] - bbox[0] for bbox in non_empty_bounds)
        max_height = max(bbox[3] - bbox[1] for bbox in non_empty_bounds)
        scale = min(TARGET_MAX_WIDTH / max_width, TARGET_MAX_HEIGHT / max_height, 1.0)

        for column, cell in enumerate(row_cells):
            bbox = bounds[column]
            if bbox is None:
                continue

            trimmed = cell.crop(bbox)
            scaled_size = (
                max(1, int(round(trimmed.width * scale))),
                max(1, int(round(trimmed.height * scale))),
            )
            scaled = trimmed.resize(scaled_size, Image.Resampling.LANCZOS)
            x = column * CELL_SIZE + (CELL_SIZE - scaled.width) // 2
            y = row * CELL_SIZE + BASELINE_Y - scaled.height
            output.alpha_composite(scaled, (x, y))

    return output


def main() -> None:
    parser = argparse.ArgumentParser(description="Prepare a clean transparent entity idle spritesheet.")
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()

    source = Image.open(args.input)
    output = repack(detected_cells(source))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    output.save(args.output)
    print(f"Wrote {args.output}")


if __name__ == "__main__":
    main()
