from __future__ import annotations

import argparse
import importlib.util
import json
import re
import shutil
import sys
import uuid
from pathlib import Path

from PIL import Image, ImageFilter


BASE_GENERATOR_PATH = Path(__file__).with_name("generate_showcase_recipe_icons.py")
BASE_SPEC = importlib.util.spec_from_file_location(
    "project_rest_generate_showcase_recipe_icons",
    BASE_GENERATOR_PATH,
)
if BASE_SPEC is None or BASE_SPEC.loader is None:
    raise ImportError(f"could not load showcase generator: {BASE_GENERATOR_PATH}")
BASE_GENERATOR = importlib.util.module_from_spec(BASE_SPEC)
BASE_SPEC.loader.exec_module(BASE_GENERATOR)

STAGES = {
    0: ("trial", ""),
    1: ("popular", "_popular"),
    2: ("signature", "_signature"),
}
RECIPE_ID_PATTERN = re.compile(r"^[a-z0-9_]+$")
MANIFEST_FILENAME = "staged_showcase_icon_manifest.json"
SAFE_MARGIN_PX = 4
SAFE_MARGIN_RATIO = 0.05
SHOWCASE_SHARPEN = (0.50, 110, 1)


def _clean_recipe_ids(recipe_ids: list[str]) -> list[str]:
    result: list[str] = []
    for raw_recipe_id in recipe_ids:
        recipe_id = raw_recipe_id.strip()
        if not RECIPE_ID_PATTERN.fullmatch(recipe_id):
            raise ValueError(f"invalid recipe id: {raw_recipe_id!r}")
        if recipe_id not in result:
            result.append(recipe_id)
    if not result:
        raise ValueError("at least one --recipe-id is required")
    return result


def _load_recipes(config_path: Path, recipe_ids: list[str]) -> dict[str, dict]:
    config = json.loads(config_path.read_text(encoding="utf-8-sig"))
    all_recipes = config.get("recipes", {})
    if not isinstance(all_recipes, dict) or not all_recipes:
        raise ValueError("config must contain recipes")
    missing = [recipe_id for recipe_id in recipe_ids if recipe_id not in all_recipes]
    if missing:
        raise ValueError("missing recipe display config: %s" % ", ".join(missing))
    result: dict[str, dict] = {}
    for recipe_id in recipe_ids:
        recipe = all_recipes[recipe_id]
        if not isinstance(recipe, dict):
            raise ValueError(f"recipe display entry must be an object: {recipe_id}")
        result[recipe_id] = recipe
    return result


def _validated_sources(
    source_dir: Path,
    recipe_ids: list[str],
    source_naming: str,
) -> dict[tuple[str, int], Path]:
    if source_naming not in {"runtime", "icons-v1"}:
        raise ValueError(f"unsupported source naming: {source_naming}")
    sources: dict[tuple[str, int], Path] = {}
    missing: list[Path] = []
    for recipe_id in recipe_ids:
        expected_size = None
        for mastery_level, (_, suffix) in STAGES.items():
            filename = (
                f"{recipe_id}_{mastery_level + 1}.png"
                if source_naming == "icons-v1"
                else f"{recipe_id}{suffix}.png"
            )
            source_path = source_dir / filename
            if not source_path.is_file():
                missing.append(source_path)
                continue
            with Image.open(source_path) as image:
                if source_naming == "icons-v1" and image.size != (1024, 1024):
                    raise ValueError(
                        f"icons-v1 source {source_path} must be 1024x1024, got "
                        f"{image.width}x{image.height}"
                    )
                rgba = image.convert("RGBA")
                if rgba.getchannel("A").getbbox() is None:
                    raise ValueError(f"source icon is fully transparent: {source_path}")
                if expected_size is None:
                    expected_size = image.size
                elif image.size != expected_size:
                    raise ValueError(
                        f"stage source sizes must match for {recipe_id}: "
                        f"expected {expected_size[0]}x{expected_size[1]}, got "
                        f"{image.width}x{image.height}"
                    )
            sources[(recipe_id, mastery_level)] = source_path
    if missing:
        raise FileNotFoundError(
            "missing staged showcase sources: %s"
            % ", ".join(str(path) for path in missing)
        )
    return sources


def _copy_import_sidecars(output_dir: Path, staging_dir: Path) -> None:
    if not output_dir.is_dir():
        return
    for sidecar in output_dir.glob("*.png.import"):
        target_png = staging_dir / sidecar.name.removesuffix(".import")
        if target_png.is_file():
            shutil.copy2(sidecar, staging_dir / sidecar.name)


def _canvas_extent(
    cells: list[tuple[int, int]],
    cell_size: int,
) -> tuple[int, int]:
    rows = max(row for row, _ in cells)
    cols = max(col for _, col in cells)
    return (
        cols * cell_size + (cols - 1) * BASE_GENERATOR.CELL_GAP,
        rows * cell_size + (rows - 1) * BASE_GENERATOR.CELL_GAP,
    )


def _regions(
    cells: list[tuple[int, int]],
    cell_size: int,
) -> dict[str, list[int]]:
    return {
        f"{row}:{col}": [
            (col - 1) * (cell_size + BASE_GENERATOR.CELL_GAP),
            (row - 1) * (cell_size + BASE_GENERATOR.CELL_GAP),
            cell_size,
            cell_size,
        ]
        for row, col in cells
    }


def _safe_margin(cell_size: int) -> int:
    return max(1, round(cell_size * SAFE_MARGIN_RATIO))


def _sharpen_rgb_preserve_alpha(image: Image.Image) -> Image.Image:
    alpha = image.getchannel("A")
    radius, percent, threshold = SHOWCASE_SHARPEN
    sharpened_rgb = image.convert("RGB").filter(
        ImageFilter.UnsharpMask(
            radius=radius,
            percent=percent,
            threshold=threshold,
        )
    )
    sharpened_rgb.putalpha(alpha)
    return sharpened_rgb


def _render_contained_canvas(
    source: Image.Image,
    cells: list[tuple[int, int]],
    rotation: int,
    cell_size: int = BASE_GENERATOR.CELL_SIZE,
) -> Image.Image:
    """Render art inside one occupied rectangle so shape holes cannot crop it."""
    width, height = _canvas_extent(cells, cell_size)
    art = BASE_GENERATOR._rotated_art(BASE_GENERATOR._trim_alpha(source), rotation)
    safe_margin_px = _safe_margin(cell_size)
    rect_x, rect_y, rect_width, rect_height = _best_occupied_rect(
        cells,
        art.width,
        art.height,
        cell_size,
        safe_margin_px,
    )
    available_width = max(1, rect_width - safe_margin_px * 2)
    available_height = max(1, rect_height - safe_margin_px * 2)
    art.thumbnail((available_width, available_height), Image.Resampling.LANCZOS)
    art = _sharpen_rgb_preserve_alpha(art)
    canvas = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    canvas.alpha_composite(
        art,
        (
            rect_x + (rect_width - art.width) // 2,
            rect_y + (rect_height - art.height) // 2,
        ),
    )
    return canvas


def _best_occupied_rect(
    cells: list[tuple[int, int]],
    art_width: int,
    art_height: int,
    cell_size: int,
    safe_margin_px: int,
) -> tuple[int, int, int, int]:
    occupied = set(cells)
    rows = max(row for row, _ in cells)
    cols = max(col for _, col in cells)
    best_score: tuple[float, int] | None = None
    best_rect: tuple[int, int, int, int] | None = None
    for top in range(1, rows + 1):
        for bottom in range(top, rows + 1):
            for left in range(1, cols + 1):
                for right in range(left, cols + 1):
                    if any(
                        (row, col) not in occupied
                        for row in range(top, bottom + 1)
                        for col in range(left, right + 1)
                    ):
                        continue
                    rect_width = (
                        (right - left + 1) * cell_size
                        + (right - left) * BASE_GENERATOR.CELL_GAP
                    )
                    rect_height = (
                        (bottom - top + 1) * cell_size
                        + (bottom - top) * BASE_GENERATOR.CELL_GAP
                    )
                    available_width = max(1, rect_width - safe_margin_px * 2)
                    available_height = max(1, rect_height - safe_margin_px * 2)
                    scale = min(
                        available_width / max(1, art_width),
                        available_height / max(1, art_height),
                    )
                    score = (scale, rect_width * rect_height)
                    if best_score is None or score > best_score:
                        best_score = score
                        best_rect = (
                            (left - 1) * (cell_size + BASE_GENERATOR.CELL_GAP),
                            (top - 1) * (cell_size + BASE_GENERATOR.CELL_GAP),
                            rect_width,
                            rect_height,
                        )
    if best_rect is None:
        raise ValueError("showcase shape has no occupied cells")
    return best_rect


def _publish(staging_dir: Path, output_dir: Path) -> None:
    backup_dir = output_dir.with_name(f"staged_showcase_backup_{uuid.uuid4().hex}")
    had_existing_output = output_dir.exists()
    try:
        if had_existing_output:
            output_dir.replace(backup_dir)
        staging_dir.replace(output_dir)
    except Exception:
        if not output_dir.exists() and backup_dir.exists():
            backup_dir.replace(output_dir)
        raise
    finally:
        if backup_dir.exists():
            shutil.rmtree(backup_dir)


def _load_existing_manifest(output_dir: Path) -> dict:
    manifest_path = output_dir / MANIFEST_FILENAME
    if not manifest_path.is_file():
        raise FileNotFoundError(
            f"preserve-existing requires an existing manifest: {manifest_path}"
        )
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    if not isinstance(manifest, dict) or not isinstance(manifest.get("entries"), dict):
        raise ValueError(f"invalid existing staged showcase manifest: {manifest_path}")
    return manifest


def _copy_existing_for_incremental_update(
    output_dir: Path,
    staging_dir: Path,
    recipe_ids: list[str],
) -> None:
    if not output_dir.is_dir():
        raise FileNotFoundError(
            f"preserve-existing requires an existing output directory: {output_dir}"
        )
    shutil.copytree(output_dir, staging_dir, dirs_exist_ok=True)
    for recipe_id in recipe_ids:
        for png in staging_dir.glob(f"{recipe_id}__*.png"):
            png.unlink()


def _remove_orphan_selected_sidecars(
    staging_dir: Path,
    recipe_ids: list[str],
) -> None:
    for recipe_id in recipe_ids:
        for sidecar in staging_dir.glob(f"{recipe_id}__*.png.import"):
            png = staging_dir / sidecar.name.removesuffix(".import")
            if not png.is_file():
                sidecar.unlink()


def generate_staged_showcase_icons(
    source_dir: Path,
    output_dir: Path,
    config_path: Path,
    recipe_ids: list[str],
    cell_size: int = BASE_GENERATOR.CELL_SIZE,
    preserve_existing: bool = False,
    source_naming: str = "runtime",
) -> dict:
    if cell_size <= 0:
        raise ValueError("cell size must be positive")
    clean_recipe_ids = _clean_recipe_ids(recipe_ids)
    recipes = _load_recipes(config_path, clean_recipe_ids)
    sources = _validated_sources(source_dir, clean_recipe_ids, source_naming)
    existing_manifest = _load_existing_manifest(output_dir) if preserve_existing else None
    output_dir.parent.mkdir(parents=True, exist_ok=True)
    staging_dir = output_dir.with_name(f"staged_showcase_icons_{uuid.uuid4().hex}")
    staging_dir.mkdir()
    if existing_manifest is not None:
        manifest = json.loads(json.dumps(existing_manifest))
        selected = set(clean_recipe_ids)
        manifest["entries"] = {
            key: entry
            for key, entry in manifest["entries"].items()
            if str(entry.get("recipe_id", "")) not in selected
        }
        manifest["version"] = max(2, int(manifest.get("version", 1)))
        try:
            _copy_existing_for_incremental_update(
                output_dir,
                staging_dir,
                clean_recipe_ids,
            )
        except Exception:
            shutil.rmtree(staging_dir, ignore_errors=True)
            raise
    else:
        manifest = {
            "version": 2,
            "cell_size": cell_size,
            "cell_gap": BASE_GENERATOR.CELL_GAP,
            "recipe_count": len(clean_recipe_ids),
            "stage_count": len(STAGES),
            "entries": {},
        }
    try:
        for recipe_id in sorted(clean_recipe_ids):
            recipe = recipes[recipe_id]
            for mastery_level, (stage_id, _) in STAGES.items():
                with Image.open(sources[(recipe_id, mastery_level)]) as source:
                    for variant_id in BASE_GENERATOR.VARIANT_IDS:
                        variant_cells = BASE_GENERATOR._variant_cells(recipe, variant_id)
                        orientations = BASE_GENERATOR._unique_orientations(
                            variant_cells,
                            len(variant_cells) > 1,
                        )
                        for rotation, cells in orientations:
                            filename = (
                                f"{recipe_id}__{stage_id}__{variant_id}__r{rotation}.png"
                            )
                            canvas = _render_contained_canvas(
                                source,
                                cells,
                                rotation,
                                cell_size,
                            )
                            canvas.save(staging_dir / filename, format="PNG", optimize=True)
                            key = f"{recipe_id}|m{mastery_level}|{variant_id}|r{rotation}"
                            manifest["entries"][key] = {
                                "texture_path": (
                                    "res://resources/recipe_icons_showcase_staged/"
                                    f"{filename}"
                                ),
                                "recipe_id": recipe_id,
                                "mastery_level": mastery_level,
                                "stage_id": stage_id,
                                "variant_id": variant_id,
                                "rotation": rotation,
                                "cell_size": cell_size,
                                "rows": max(row for row, _ in cells),
                                "cols": max(col for _, col in cells),
                                "cells": [[row, col] for row, col in cells],
                                "regions": _regions(cells, cell_size),
                            }
        manifest["recipe_count"] = len(
            {
                str(entry.get("recipe_id", ""))
                for entry in manifest["entries"].values()
                if str(entry.get("recipe_id", ""))
            }
        )
        manifest["stage_count"] = len(STAGES)
        (staging_dir / MANIFEST_FILENAME).write_text(
            json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
        if preserve_existing:
            _remove_orphan_selected_sidecars(staging_dir, clean_recipe_ids)
        else:
            _copy_import_sidecars(output_dir, staging_dir)
        _publish(staging_dir, output_dir)
    except Exception:
        shutil.rmtree(staging_dir, ignore_errors=True)
        raise
    return manifest


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate stage-aware showcase canvases for selected recipes."
    )
    parser.add_argument(
        "--source-dir",
        type=Path,
        default=Path("resources/recipe_icons"),
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path("resources/recipe_icons_showcase_staged"),
    )
    parser.add_argument(
        "--config-path",
        type=Path,
        default=Path("doc/recipe_display_config.json"),
    )
    parser.add_argument("--recipe-id", action="append", required=True)
    parser.add_argument(
        "--cell-size",
        type=int,
        default=BASE_GENERATOR.CELL_SIZE,
    )
    parser.add_argument(
        "--preserve-existing",
        action="store_true",
        help="Replace only selected recipes in an existing staged output pack.",
    )
    parser.add_argument(
        "--source-naming",
        choices=["runtime", "icons-v1"],
        default="runtime",
        help="Select recipe.png stage suffixes or icons_v1 recipe_1/_2/_3 names.",
    )
    return parser.parse_args()


def main() -> int:
    args = _parse_args()
    try:
        manifest = generate_staged_showcase_icons(
            args.source_dir.resolve(),
            args.output_dir.resolve(),
            args.config_path.resolve(),
            args.recipe_id,
            args.cell_size,
            args.preserve_existing,
            args.source_naming,
        )
    except (FileNotFoundError, OSError, ValueError, json.JSONDecodeError) as error:
        print(error, file=sys.stderr)
        return 1
    print(
        "generated %d staged showcase canvases for %d recipes"
        % (len(manifest["entries"]), manifest["recipe_count"])
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
