#!/usr/bin/env python3
"""Freeze immutable fields for the recipes that predate progression v2.

This utility intentionally understands only the compact, one-recipe-per-line
literal format used by ``scripts/catalog.gd``.  It refuses to overwrite an
existing fixture so the baseline cannot silently move with production data.
"""

from __future__ import annotations

import argparse
import ast
import json
import re
from pathlib import Path


EXPECTED_RECIPE_COUNT = 149
IMMUTABLE_FIELDS = ("id", "name", "device", "materials", "price", "output_count", "tags")
RECIPE_LINE = re.compile(r'^\s*"([^"]+)"\s*:\s*(\{.*\})\s*,?\s*$')


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--catalog", type=Path, default=Path("scripts/catalog.gd"))
    parser.add_argument(
        "--out",
        type=Path,
        default=Path("tests/fixtures/existing_recipe_contract_v1.json"),
    )
    return parser.parse_args()


def extract_recipe_contract(catalog_path: Path) -> dict[str, dict[str, object]]:
    text = catalog_path.read_text(encoding="utf-8")
    try:
        recipe_block = text.split("const RECIPES := {", 1)[1].split(
            "const PROCESSING_RECIPES := {", 1
        )[0]
    except IndexError as exc:
        raise SystemExit(f"Could not locate RECIPES block in {catalog_path}") from exc

    recipes: dict[str, dict[str, object]] = {}
    for line_number, line in enumerate(recipe_block.splitlines(), start=1):
        match = RECIPE_LINE.match(line)
        if not match:
            continue
        recipe_id, literal = match.groups()
        try:
            recipe = ast.literal_eval(literal)
        except (SyntaxError, ValueError) as exc:
            raise SystemExit(
                f"Could not parse recipe {recipe_id!r} near RECIPES line {line_number}: {exc}"
            ) from exc
        missing_fields = [field for field in IMMUTABLE_FIELDS if field not in recipe]
        if missing_fields:
            raise SystemExit(f"Recipe {recipe_id!r} is missing immutable fields: {missing_fields}")
        if recipe_id in recipes:
            raise SystemExit(f"Duplicate recipe id: {recipe_id}")
        if recipe.get("id") != recipe_id:
            raise SystemExit(f"Recipe key/id mismatch: {recipe_id!r} != {recipe.get('id')!r}")
        recipes[recipe_id] = {field: recipe[field] for field in IMMUTABLE_FIELDS}

    if len(recipes) != EXPECTED_RECIPE_COUNT:
        raise SystemExit(
            f"Expected exactly {EXPECTED_RECIPE_COUNT} recipes before progression v2, "
            f"found {len(recipes)}"
        )
    return dict(sorted(recipes.items()))


def main() -> None:
    args = parse_args()
    if args.out.exists():
        raise SystemExit(f"Refusing to overwrite frozen fixture: {args.out}")

    recipes = extract_recipe_contract(args.catalog)
    payload = {
        "meta": {
            "recipe_count": EXPECTED_RECIPE_COUNT,
            "immutable_fields": list(IMMUTABLE_FIELDS),
        },
        "recipes": recipes,
    }
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"Wrote {len(recipes)} frozen recipe contracts to {args.out}")


if __name__ == "__main__":
    main()
