from __future__ import annotations

import argparse
import re
import shutil
import sys
import uuid
from pathlib import Path

from PIL import Image


INVENTORY_ICON_SIZE = (80, 80)
SOURCE_ICON_SIZE = (512, 512)
SOURCE_ALIASES = {
    "baked_rice_cake": "baked_rice_cake_icon_512_alpha_2x1.png",
    "egg_milk_custard": "egg_milk_custard_icon_512_alpha_2x2.png",
    "milk_rice_dew": "milk_rice_dew_icon_512_alpha_1x2.png",
    "rice_milk_drink": "rice_milk_drink_icon_512_alpha_1x2.png",
    "rich_rice_drink": "rich_rice_drink_icon_512_alpha_1x2.png",
}


def _catalog_recipe_ids(catalog_path: Path) -> list[str]:
    text = catalog_path.read_text(encoding="utf-8")
    match = re.search(
        r"const RECIPES := \{(?P<body>.*?)\n\}\s*\n\s*const PROCESSING_RECIPES",
        text,
        flags=re.DOTALL,
    )
    if match is None:
        raise ValueError(f"could not locate RECIPES block in {catalog_path}")
    recipe_ids = re.findall(
        r'^\s*"([^"]+)"\s*:',
        match.group("body"),
        flags=re.MULTILINE,
    )
    if not recipe_ids:
        raise ValueError(f"no recipe ids found in {catalog_path}")
    return recipe_ids


def _resolve_source_icon(source_dir: Path, recipe_id: str) -> Path | None:
    exact_path = source_dir / f"{recipe_id}.png"
    if exact_path.is_file():
        return exact_path
    alias_name = SOURCE_ALIASES.get(recipe_id)
    if alias_name is None:
        return None
    alias_path = source_dir / alias_name
    return alias_path if alias_path.is_file() else None


def _validated_sources(
    source_dir: Path,
    catalog_path: Path,
) -> tuple[list[str], dict[str, Path]]:
    recipe_ids = _catalog_recipe_ids(catalog_path)
    sources: dict[str, Path] = {}
    missing: list[str] = []
    for recipe_id in recipe_ids:
        source_path = _resolve_source_icon(source_dir, recipe_id)
        if source_path is None:
            missing.append(recipe_id)
            continue
        with Image.open(source_path) as image:
            if image.size != SOURCE_ICON_SIZE:
                raise ValueError(
                    f"source icon {source_path} must be 512x512, got "
                    f"{image.width}x{image.height}"
                )
        sources[recipe_id] = source_path
    if missing:
        raise FileNotFoundError("missing source icons: %s" % ", ".join(missing))
    return recipe_ids, sources


def _publish_staging_directory(staging_dir: Path, output_dir: Path) -> None:
    backup_dir = output_dir.with_name(f".{output_dir.name}-backup-{uuid.uuid4().hex}")
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


def _copy_import_sidecars(output_dir: Path, staging_dir: Path) -> None:
    if not output_dir.is_dir():
        return
    for sidecar in output_dir.glob("*.png.import"):
        shutil.copy2(sidecar, staging_dir / sidecar.name)


def generate_inventory_icons(
    source_dir: Path,
    output_dir: Path,
    catalog_path: Path,
) -> list[Path]:
    recipe_ids, sources = _validated_sources(source_dir, catalog_path)
    output_dir.parent.mkdir(parents=True, exist_ok=True)
    staging_dir = output_dir.with_name(
        f".{output_dir.name}-staging-{uuid.uuid4().hex}"
    )
    staging_dir.mkdir()
    try:
        _copy_import_sidecars(output_dir, staging_dir)
        for recipe_id in recipe_ids:
            with Image.open(sources[recipe_id]) as image:
                rgba = image.convert("RGBA")
                resized = rgba.resize(INVENTORY_ICON_SIZE, Image.Resampling.LANCZOS)
                resized.save(
                    staging_dir / f"{recipe_id}.png",
                    format="PNG",
                    optimize=True,
                )
        _publish_staging_directory(staging_dir, output_dir)
    finally:
        if staging_dir.exists():
            shutil.rmtree(staging_dir)
    return [output_dir / f"{recipe_id}.png" for recipe_id in recipe_ids]


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate 80x80 inventory recipe icons from full 512x512 canvases."
    )
    parser.add_argument("--source-dir", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--catalog-path", type=Path, required=True)
    return parser.parse_args()


def main() -> int:
    args = _parse_args()
    try:
        generated = generate_inventory_icons(
            args.source_dir.resolve(),
            args.output_dir.resolve(),
            args.catalog_path.resolve(),
        )
    except (FileNotFoundError, ValueError) as error:
        print(error, file=sys.stderr)
        return 1
    print(f"generated {len(generated)} inventory icons")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
