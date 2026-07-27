from __future__ import annotations

import argparse
import os
import re
import shutil
import sys
import uuid
from pathlib import Path

from PIL import Image, ImageFilter


SOURCE_ICON_SIZE = (1024, 1024)
STAGE_SUFFIXES = {
    1: "",
    2: "_popular",
    3: "_signature",
}
OUTPUT_SIZES = {
    "base": (128, 128),
    "catalog": (112, 112),
    "inventory": (80, 80),
    "action": (32, 32),
}
SHARPEN_SETTINGS = {
    "base": (0.60, 90, 2),
    "catalog": (0.55, 100, 2),
    "inventory": (0.50, 110, 1),
    "action": (0.40, 130, 1),
}
RECIPE_ID_PATTERN = re.compile(r"^[a-z0-9_]+$")


def _unique_recipe_ids(recipe_ids: list[str]) -> list[str]:
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


def _validated_sources(
    source_dir: Path,
    recipe_ids: list[str],
) -> dict[tuple[str, int], Path]:
    sources: dict[tuple[str, int], Path] = {}
    missing: list[Path] = []
    for recipe_id in recipe_ids:
        for stage_number in STAGE_SUFFIXES:
            source_path = source_dir / f"{recipe_id}_{stage_number}.png"
            if not source_path.is_file():
                missing.append(source_path)
                continue
            with Image.open(source_path) as image:
                if image.size != SOURCE_ICON_SIZE:
                    raise ValueError(
                        f"source icon {source_path} must be "
                        f"{SOURCE_ICON_SIZE[0]}x{SOURCE_ICON_SIZE[1]}, got "
                        f"{image.width}x{image.height}"
                    )
                image.convert("RGBA").getbbox()
            sources[(recipe_id, stage_number)] = source_path
    if missing:
        raise FileNotFoundError(
            "missing staged source icons: %s" % ", ".join(str(path) for path in missing)
        )
    return sources


def _validated_output_dirs(output_dirs: dict[str, Path]) -> dict[str, Path]:
    missing_surfaces = [surface for surface in OUTPUT_SIZES if surface not in output_dirs]
    if missing_surfaces:
        raise ValueError("missing output directories: %s" % ", ".join(missing_surfaces))
    return {surface: Path(output_dirs[surface]) for surface in OUTPUT_SIZES}


def _resize_and_sharpen(rgba: Image.Image, surface: str) -> Image.Image:
    output_size = OUTPUT_SIZES[surface]
    resized = rgba.resize(output_size, Image.Resampling.LANCZOS)
    alpha = resized.getchannel("A")
    radius, percent, threshold = SHARPEN_SETTINGS[surface]
    sharpened_rgb = resized.convert("RGB").filter(
        ImageFilter.UnsharpMask(
            radius=radius,
            percent=percent,
            threshold=threshold,
        )
    )
    sharpened_rgb.putalpha(alpha)
    return sharpened_rgb


def install_staged_icons(
    source_dir: Path,
    output_dirs: dict[str, Path],
    recipe_ids: list[str],
) -> list[Path]:
    clean_recipe_ids = _unique_recipe_ids(recipe_ids)
    clean_output_dirs = _validated_output_dirs(output_dirs)
    sources = _validated_sources(source_dir, clean_recipe_ids)

    common_parent = Path(
        os.path.commonpath([str(path.resolve().parent) for path in clean_output_dirs.values()])
    )
    common_parent.mkdir(parents=True, exist_ok=True)
    generated: list[tuple[Path, Path]] = []
    staging_root = common_parent / f"staged_recipe_icons_{uuid.uuid4().hex}"
    staging_root.mkdir()
    try:
        for recipe_id in clean_recipe_ids:
            for stage_number, stage_suffix in STAGE_SUFFIXES.items():
                source_path = sources[(recipe_id, stage_number)]
                with Image.open(source_path) as image:
                    rgba = image.convert("RGBA")
                    for surface in OUTPUT_SIZES:
                        staged_path = staging_root / surface / f"{recipe_id}{stage_suffix}.png"
                        staged_path.parent.mkdir(parents=True, exist_ok=True)
                        output = _resize_and_sharpen(rgba, surface)
                        output.save(staged_path, format="PNG", optimize=True)
                        target_path = clean_output_dirs[surface] / staged_path.name
                        generated.append((staged_path, target_path))

        for output_dir in clean_output_dirs.values():
            output_dir.mkdir(parents=True, exist_ok=True)
        for staged_path, target_path in generated:
            os.replace(staged_path, target_path)
    finally:
        if staging_root.exists():
            shutil.rmtree(staging_root)

    return [target_path for _, target_path in generated]


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Install _1/_2/_3 recipe art as stage-aware runtime icons."
    )
    parser.add_argument(
        "--source-dir",
        type=Path,
        default=Path("resources/ui/icons_v1"),
    )
    parser.add_argument("--recipe-id", action="append", required=True)
    parser.add_argument(
        "--base-output-dir",
        type=Path,
        default=Path("resources/recipe_icons"),
    )
    parser.add_argument(
        "--catalog-output-dir",
        type=Path,
        default=Path("resources/recipe_icons_catalog"),
    )
    parser.add_argument(
        "--inventory-output-dir",
        type=Path,
        default=Path("resources/recipe_icons_inventory"),
    )
    parser.add_argument(
        "--action-output-dir",
        type=Path,
        default=Path("resources/recipe_icons_action"),
    )
    return parser.parse_args()


def main() -> int:
    args = _parse_args()
    try:
        generated = install_staged_icons(
            args.source_dir.resolve(),
            {
                "base": args.base_output_dir.resolve(),
                "catalog": args.catalog_output_dir.resolve(),
                "inventory": args.inventory_output_dir.resolve(),
                "action": args.action_output_dir.resolve(),
            },
            args.recipe_id,
        )
    except (FileNotFoundError, OSError, ValueError) as error:
        print(error, file=sys.stderr)
        return 1
    print(
        "installed %d staged icons for %d recipes"
        % (len(generated), len(_unique_recipe_ids(args.recipe_id)))
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
