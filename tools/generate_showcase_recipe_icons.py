from __future__ import annotations

import argparse
import json
import shutil
import sys
from pathlib import Path

from PIL import Image


CELL_SIZE = 80
CELL_GAP = 0
VARIANT_IDS = ("standard", "small", "gift_box", "large", "sample")


def normalize_cells(cells: list[tuple[int, int]]) -> list[tuple[int, int]]:
    if not cells:
        return []
    min_row = min(row for row, _ in cells)
    min_col = min(col for _, col in cells)
    return sorted((row - min_row + 1, col - min_col + 1) for row, col in cells)


def rotate_clockwise(cells: list[tuple[int, int]]) -> list[tuple[int, int]]:
    rows = max(row for row, _ in cells)
    return normalize_cells([(col, rows - row + 1) for row, col in cells])


def canvas_extent(cells: list[tuple[int, int]]) -> tuple[int, int]:
    rows = max(row for row, _ in cells)
    cols = max(col for _, col in cells)
    return (
        cols * CELL_SIZE + (cols - 1) * CELL_GAP,
        rows * CELL_SIZE + (rows - 1) * CELL_GAP,
    )


def _default_cells(recipe: dict) -> list[tuple[int, int]]:
    raw_cells = recipe.get("shape_cells", [])
    if isinstance(raw_cells, list) and raw_cells:
        cells = []
        for value in raw_cells:
            if not isinstance(value, list) or len(value) != 2:
                raise ValueError("shape_cells entries must be [row, col]")
            cells.append((int(value[0]), int(value[1])))
        normalized = normalize_cells(cells)
        if len(set(normalized)) != len(normalized):
            raise ValueError("shape_cells contains duplicates")
        return normalized

    shape = str(recipe.get("default_shape", "1x1")).lower().split("x")
    if len(shape) != 2:
        raise ValueError("default_shape must use rowsxcols")
    rows, cols = int(shape[0]), int(shape[1])
    if rows <= 0 or cols <= 0:
        raise ValueError("default_shape dimensions must be positive")
    return [(row, col) for row in range(1, rows + 1) for col in range(1, cols + 1)]


def _base_count(recipe: dict, configured_cells: list[tuple[int, int]]) -> int:
    raw_cells = recipe.get("shape_cells", [])
    if isinstance(raw_cells, list) and raw_cells:
        return len(configured_cells)
    return max(1, int(recipe.get("cell_count", 1)))


def _expanded_cells(cells: list[tuple[int, int]], target_count: int) -> list[tuple[int, int]]:
    result = list(cells)
    used = set(result)
    max_rows = max(row for row, _ in result)
    max_cols = max(col for _, col in result)
    while len(result) < target_count:
        added = False
        for row in range(1, max_rows + 1):
            for col in range(1, max_cols + 2):
                cell = (row, col)
                if cell in used:
                    continue
                result.append(cell)
                used.add(cell)
                added = True
                break
            if added:
                break
        if not added:
            max_rows += 1
            result.append((max_rows, 1))
            used.add((max_rows, 1))
        max_rows = max(max_rows, max(row for row, _ in result))
        max_cols = max(max_cols, max(col for _, col in result))
    return normalize_cells(result)


def _variant_cells(recipe: dict, variant_id: str) -> list[tuple[int, int]]:
    configured_cells = _default_cells(recipe)
    base_count = _base_count(recipe, configured_cells)
    if variant_id in ("small", "sample"):
        target_count = 1
    elif variant_id in ("gift_box", "large"):
        target_count = base_count + 1
    else:
        target_count = base_count
    if target_count <= len(configured_cells):
        return normalize_cells(configured_cells[:target_count])
    return _expanded_cells(configured_cells, target_count)


def _unique_orientations(
    cells: list[tuple[int, int]], rotatable: bool
) -> list[tuple[int, list[tuple[int, int]]]]:
    orientations = []
    seen = set()
    current = normalize_cells(cells)
    turns = 4 if rotatable else 1
    for turn in range(turns):
        key = tuple(current)
        if key not in seen:
            seen.add(key)
            orientations.append((turn * 90, current))
        current = rotate_clockwise(current)
    return orientations


def _trim_alpha(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    bounds = rgba.getchannel("A").getbbox()
    if bounds is None:
        raise ValueError("source icon is fully transparent")
    return rgba.crop(bounds)


def _rotated_art(image: Image.Image, rotation: int) -> Image.Image:
    if rotation == 90:
        return image.transpose(Image.Transpose.ROTATE_270)
    if rotation == 180:
        return image.transpose(Image.Transpose.ROTATE_180)
    if rotation == 270:
        return image.transpose(Image.Transpose.ROTATE_90)
    return image.copy()


def _render_canvas(
    source: Image.Image,
    cells: list[tuple[int, int]],
    rotation: int,
) -> Image.Image:
    width, height = canvas_extent(cells)
    art = _rotated_art(_trim_alpha(source), rotation)
    art.thumbnail((width, height), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    canvas.alpha_composite(art, ((width - art.width) // 2, (height - art.height) // 2))

    occupied = set(cells)
    rows = max(row for row, _ in cells)
    cols = max(col for _, col in cells)
    transparent = Image.new("RGBA", (CELL_SIZE, CELL_SIZE), (0, 0, 0, 0))
    for row in range(1, rows + 1):
        for col in range(1, cols + 1):
            if (row, col) in occupied:
                continue
            x = (col - 1) * (CELL_SIZE + CELL_GAP)
            y = (row - 1) * (CELL_SIZE + CELL_GAP)
            canvas.paste(transparent, (x, y))
    return canvas


def _regions(cells: list[tuple[int, int]]) -> dict[str, list[int]]:
    return {
        f"{row}:{col}": [
            (col - 1) * (CELL_SIZE + CELL_GAP),
            (row - 1) * (CELL_SIZE + CELL_GAP),
            CELL_SIZE,
            CELL_SIZE,
        ]
        for row, col in cells
    }


def _validate_sources(source_dir: Path, recipes: dict) -> dict[str, Path]:
    sources = {}
    missing = []
    for recipe_id in sorted(recipes):
        path = source_dir / f"{recipe_id}.png"
        if path.is_file():
            sources[recipe_id] = path
        else:
            missing.append(recipe_id)
    if missing:
        raise FileNotFoundError("missing source icons: %s" % ", ".join(missing))
    return sources


def _publish(staging_dir: Path, output_dir: Path) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    for path in output_dir.glob("*.png"):
        path.unlink()
    manifest_path = output_dir / "showcase_icon_manifest.json"
    if manifest_path.exists():
        manifest_path.unlink()
    for path in staging_dir.iterdir():
        path.replace(output_dir / path.name)
    staging_dir.rmdir()


def generate_showcase_icons(
    source_dir: Path,
    output_dir: Path,
    config_path: Path,
) -> dict:
    source_dir = source_dir.resolve()
    output_dir = output_dir.resolve()
    config_path = config_path.resolve()
    config = json.loads(config_path.read_text(encoding="utf-8-sig"))
    recipes = config.get("recipes", {})
    if not isinstance(recipes, dict) or not recipes:
        raise ValueError("config must contain recipes")
    sources = _validate_sources(source_dir, recipes)

    staging_dir = output_dir.parent / f".{output_dir.name}.staging"
    if staging_dir.exists():
        shutil.rmtree(staging_dir)
    staging_dir.mkdir(parents=True)
    manifest = {
        "version": 1,
        "cell_size": CELL_SIZE,
        "cell_gap": CELL_GAP,
        "recipe_count": len(recipes),
        "entries": {},
    }
    try:
        for recipe_id in sorted(recipes):
            recipe = recipes[recipe_id]
            if not isinstance(recipe, dict):
                raise ValueError(f"recipe display entry must be an object: {recipe_id}")
            with Image.open(sources[recipe_id]) as source:
                for variant_id in VARIANT_IDS:
                    variant_cells = _variant_cells(recipe, variant_id)
                    for rotation, cells in _unique_orientations(
                        variant_cells, len(variant_cells) > 1
                    ):
                        filename = f"{recipe_id}__{variant_id}__r{rotation}.png"
                        canvas = _render_canvas(source, cells, rotation)
                        canvas.save(staging_dir / filename, format="PNG", optimize=True)
                        rows = max(row for row, _ in cells)
                        cols = max(col for _, col in cells)
                        key = f"{recipe_id}|{variant_id}|r{rotation}"
                        manifest["entries"][key] = {
                            "texture_path": f"res://resources/recipe_icons_showcase/{filename}",
                            "recipe_id": recipe_id,
                            "variant_id": variant_id,
                            "rotation": rotation,
                            "rows": rows,
                            "cols": cols,
                            "cells": [[row, col] for row, col in cells],
                            "regions": _regions(cells),
                        }
        (staging_dir / "showcase_icon_manifest.json").write_text(
            json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
        _publish(staging_dir, output_dir)
    except Exception:
        shutil.rmtree(staging_dir, ignore_errors=True)
        raise
    return manifest


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate showcase recipe icon canvases.")
    parser.add_argument("--source-dir", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--config-path", type=Path, required=True)
    return parser.parse_args()


def main() -> int:
    args = _parse_args()
    try:
        manifest = generate_showcase_icons(
            args.source_dir,
            args.output_dir,
            args.config_path,
        )
    except (FileNotFoundError, ValueError, OSError, json.JSONDecodeError) as error:
        print(error, file=sys.stderr)
        return 1
    print(
        "generated %d showcase canvases for %d recipes"
        % (len(manifest["entries"]), manifest["recipe_count"])
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
