"""Generate explicit 2/4/8 second production durations for Catalog.RECIPES."""

from __future__ import annotations

import argparse
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_CATALOG_PATH = ROOT / "scripts" / "catalog.gd"
RECIPES_MARKER = "const RECIPES := {"
NEXT_MARKER = "const PROCESSING_RECIPES := {"


def _recipe_lines(block: str) -> dict[str, tuple[str, list[str]]]:
    records: dict[str, tuple[str, list[str]]] = {}
    for line in block.splitlines():
        match = re.match(r'\s*"([^"]+)"\s*:\s*\{(.+?)\},?\s*$', line)
        if not match:
            continue
        materials_match = re.search(
            r'"materials"\s*:\s*\[([^]]*)\]', match.group(2)
        )
        materials = (
            re.findall(r'"([^"]+)"', materials_match.group(1))
            if materials_match
            else []
        )
        records[match.group(1)] = (line, materials)
    return records


def _duration(materials: list[str], recipe_ids: set[str]) -> int:
    if any(material_id in recipe_ids for material_id in materials):
        return 8
    if len(materials) <= 3:
        return 2
    if len(materials) == 4:
        return 4
    return 8


def generated_catalog(text: str) -> tuple[str, dict[int, int]]:
    if RECIPES_MARKER not in text or NEXT_MARKER not in text:
        raise ValueError("Catalog RECIPES block markers are missing")
    prefix, remainder = text.split(RECIPES_MARKER, 1)
    block, suffix = remainder.split(NEXT_MARKER, 1)
    records = _recipe_lines(block)
    if len(records) != 166:
        raise ValueError(f"Expected 166 recipes, found {len(records)}")

    recipe_ids = set(records)
    counts = {2: 0, 4: 0, 8: 0}
    updated_lines: list[str] = []
    for line in block.splitlines(keepends=True):
        line_body = line.rstrip("\r\n")
        ending = line[len(line_body) :]
        match = re.match(r'\s*"([^"]+)"\s*:\s*\{', line_body)
        if not match or match.group(1) not in records:
            updated_lines.append(line)
            continue
        recipe_id = match.group(1)
        duration = _duration(records[recipe_id][1], recipe_ids)
        counts[duration] += 1
        if re.search(r'"production_duration_seconds"\s*:\s*\d+', line_body):
            line_body = re.sub(
                r'"production_duration_seconds"\s*:\s*\d+',
                f'"production_duration_seconds": {duration}',
                line_body,
                count=1,
            )
        else:
            line_body = line_body.replace(
                ', "price":',
                f', "production_duration_seconds": {duration}, "price":',
                1,
            )
        updated_lines.append(line_body + ending)

    if counts != {2: 69, 4: 49, 8: 48}:
        raise ValueError(f"Unexpected duration distribution: {counts}")
    return prefix + RECIPES_MARKER + "".join(updated_lines) + NEXT_MARKER + suffix, counts


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--catalog", type=Path, default=DEFAULT_CATALOG_PATH)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--check", action="store_true")
    mode.add_argument("--write", action="store_true")
    args = parser.parse_args()

    catalog_path = args.catalog.resolve()
    original = catalog_path.read_text(encoding="utf-8-sig")
    updated, counts = generated_catalog(original)
    if args.check:
        if updated != original:
            print(f"Recipe production duration config is stale: {catalog_path}")
            return 1
        print(f"Recipe production duration config is clean: {counts}")
        return 0

    if updated != original:
        catalog_path.write_text(updated, encoding="utf-8")
    print(f"Wrote recipe production duration config: {counts}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
