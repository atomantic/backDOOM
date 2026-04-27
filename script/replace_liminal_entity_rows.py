#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


ENTITY_COLUMNS = 6
ENTITY_CELL_SIZE = 256
ENTITY_BASELINE_Y = 244
ENTITY_TARGET_MAX_WIDTH = 220
ENTITY_TARGET_MAX_HEIGHT = 230

SPRITE_COLUMNS = 4
SPRITE_ROWS = 3
SPRITE_TARGET_MAX_WIDTH = 300
SPRITE_TARGET_MAX_HEIGHT = 322
SPRITE_BASELINE_OFFSET = 18


def key_to_alpha(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    width, height = rgba.size

    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            green_delta = g - max(r, b)
            is_key = g > 150 and green_delta > 50
            is_soft_edge = g > 112 and green_delta > 22

            if is_key:
                pixels[x, y] = (r, g, b, 0)
            elif is_soft_edge:
                alpha = max(0, min(255, int((50 - green_delta) / 28 * 255)))
                pixels[x, y] = (r, min(g, max(r, b) + 10), b, min(a, alpha))

    return rgba


def alpha_bbox(image: Image.Image) -> tuple[int, int, int, int] | None:
    return image.getchannel("A").point(lambda value: 255 if value > 12 else 0).getbbox()


def split_row(source: Image.Image) -> list[Image.Image]:
    source = key_to_alpha(source)
    cell_width = source.width // ENTITY_COLUMNS
    return [
        source.crop((column * cell_width, 0, (column + 1) * cell_width, source.height))
        for column in range(ENTITY_COLUMNS)
    ]


def normalized_entity_frames(source: Image.Image) -> list[Image.Image]:
    frames = split_row(source)
    bounds = [alpha_bbox(frame) for frame in frames]
    non_empty_bounds = [bbox for bbox in bounds if bbox is not None]
    if not non_empty_bounds:
        return [Image.new("RGBA", (ENTITY_CELL_SIZE, ENTITY_CELL_SIZE), (0, 0, 0, 0)) for _ in frames]

    max_width = max(bbox[2] - bbox[0] for bbox in non_empty_bounds)
    max_height = max(bbox[3] - bbox[1] for bbox in non_empty_bounds)
    scale = min(ENTITY_TARGET_MAX_WIDTH / max_width, ENTITY_TARGET_MAX_HEIGHT / max_height, 1.0)
    normalized: list[Image.Image] = []

    for frame, bbox in zip(frames, bounds):
        output = Image.new("RGBA", (ENTITY_CELL_SIZE, ENTITY_CELL_SIZE), (0, 0, 0, 0))
        if bbox is None:
            normalized.append(output)
            continue

        trimmed = frame.crop(bbox)
        scaled_size = (
            max(1, int(round(trimmed.width * scale))),
            max(1, int(round(trimmed.height * scale))),
        )
        scaled = trimmed.resize(scaled_size, Image.Resampling.LANCZOS)
        output.alpha_composite(
            scaled,
            (
                (ENTITY_CELL_SIZE - scaled.width) // 2,
                ENTITY_BASELINE_Y - scaled.height,
            ),
        )
        normalized.append(output)

    return normalized


def replace_entity_row(sheet: Image.Image, row: int, frames: list[Image.Image]) -> None:
    for column, frame in enumerate(frames):
        x = column * ENTITY_CELL_SIZE
        y = row * ENTITY_CELL_SIZE
        sheet.paste((0, 0, 0, 0), (x, y, x + ENTITY_CELL_SIZE, y + ENTITY_CELL_SIZE))
        sheet.alpha_composite(frame, (x, y))


def still_from_frame(frame: Image.Image, target_size: tuple[int, int]) -> Image.Image:
    bbox = alpha_bbox(frame)
    output = Image.new("RGBA", target_size, (0, 0, 0, 0))
    if bbox is None:
        return output

    trimmed = frame.crop(bbox)
    scale = min(
        SPRITE_TARGET_MAX_WIDTH / trimmed.width,
        SPRITE_TARGET_MAX_HEIGHT / trimmed.height,
        1.0,
    )
    scaled_size = (
        max(1, int(round(trimmed.width * scale))),
        max(1, int(round(trimmed.height * scale))),
    )
    scaled = trimmed.resize(scaled_size, Image.Resampling.LANCZOS)
    output.alpha_composite(
        scaled,
        (
            (target_size[0] - scaled.width) // 2,
            target_size[1] - scaled.height - SPRITE_BASELINE_OFFSET,
        ),
    )
    return output


def replace_sprite_cell(atlas: Image.Image, column: int, row: int, still: Image.Image) -> None:
    cell_width = atlas.width // SPRITE_COLUMNS
    cell_height = atlas.height // SPRITE_ROWS
    x = column * cell_width
    y = row * cell_height
    cell = still_from_frame(still, (cell_width, cell_height))
    transparent = Image.new("RGBA", (cell_width, cell_height), (0, 0, 0, 0))
    transparent.alpha_composite(cell)
    atlas.paste(transparent, (x, y))


def main() -> None:
    parser = argparse.ArgumentParser(description="Replace Hellspawn/Hellbound rows with liminal Backrooms entities.")
    parser.add_argument("--entity-sheet", required=True, type=Path)
    parser.add_argument("--sprite-atlas", required=True, type=Path)
    parser.add_argument("--hellspawn-row", required=True, type=Path)
    parser.add_argument("--hellbound-row", required=True, type=Path)
    args = parser.parse_args()

    entity_sheet = Image.open(args.entity_sheet).convert("RGBA")
    sprite_atlas = Image.open(args.sprite_atlas).convert("RGBA")
    hellspawn_frames = normalized_entity_frames(Image.open(args.hellspawn_row))
    hellbound_frames = normalized_entity_frames(Image.open(args.hellbound_row))

    replace_entity_row(entity_sheet, row=2, frames=hellspawn_frames)
    replace_entity_row(entity_sheet, row=3, frames=hellbound_frames)
    replace_sprite_cell(sprite_atlas, column=3, row=0, still=hellspawn_frames[2])
    replace_sprite_cell(sprite_atlas, column=0, row=1, still=hellbound_frames[2])

    entity_sheet.save(args.entity_sheet)
    sprite_atlas.save(args.sprite_atlas)
    print(f"Updated {args.entity_sheet}")
    print(f"Updated {args.sprite_atlas}")


if __name__ == "__main__":
    main()
