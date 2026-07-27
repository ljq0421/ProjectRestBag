#!/usr/bin/env python3
"""Generate sparse recipe-growth footprint overrides.

The top-level recipe geometry remains the trial-stage source of truth. Popular
inherits it unchanged; signature stores only fields that differ.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_CONFIG_PATH = ROOT / "doc" / "recipe_display_config.json"


MINI_SHAREABLES = {
    "white_sugar_rice_ball",
    "butter_cookie",
    "chocolate_cookie",
    "matcha_mochi",
    "matcha_cookie",
    "mango_glutinous_rice_cake",
    "black_sesame_crisp_cake",
    "sea_salt_chocolate_cookie",
    "red_bean_glutinous_rice_ball",
    "sugar_roasted_chestnut",
    "chestnut_glutinous_rice_cake",
    "oats_cookie",
    "sea_salt_nuts_cookie",
    "cocoa_glutinous_rice_cake",
    "black_tea_butter_cookie",
    "green_tea_redbean_mochi",
    "black_tea_cocoa_cookie",
}


THREE_BY_THREE_CAKES = {
    "cream_shortcake",
    "cheesecake",
    "orange_chiffon_cake",
    "honey_sponge_cake",
    "yogurt_cheesecake",
    "black_tea_chiffon_cake",
    "black_tea_light_cheesecake",
}


FIXED_MEDIUM_SIGNATURES = {
    "egg_milk_custard",
    # Its remark says the whole cake is already the default signature form.
    "strawberry_cream_cake",
}


GEOMETRY_KEYS = (
    "cell_count",
    "shape_category",
    "default_shape",
    "rotatable",
    "shape_cells",
)


def full_rectangle_target(recipe: dict, rows: int, cols: int, category: str, rotatable: bool) -> dict:
    target = {key: recipe[key] for key in GEOMETRY_KEYS if key in recipe}
    target.update(
        {
            "cell_count": rows * cols,
            "shape_category": category,
            "default_shape": f"{rows}x{cols}",
            "rotatable": rotatable,
        }
    )
    target.pop("shape_cells", None)
    return target


def sparse_override(recipe: dict, target: dict) -> dict:
    override = {}
    for key in GEOMETRY_KEYS:
        if key == "shape_cells":
            if key in recipe and key not in target:
                override[key] = []
            elif key in target and target[key] != recipe.get(key):
                override[key] = target[key]
        elif key in target and target[key] != recipe.get(key):
            override[key] = target[key]
    return override


def signature_override(recipe_id: str, recipe: dict) -> dict:
    remark = str(recipe.get("remark", ""))
    category = str(recipe["shape_category"])
    cell_count = int(recipe["cell_count"])

    if "2x3大份招牌款" in remark:
        target = full_rectangle_target(recipe, 2, 3, "大块款", True)
    elif recipe_id in THREE_BY_THREE_CAKES:
        target = full_rectangle_target(recipe, 3, 3, "大块款", False)
    elif recipe_id in FIXED_MEDIUM_SIGNATURES:
        target = {key: recipe[key] for key in GEOMETRY_KEYS if key in recipe}
    elif recipe_id in MINI_SHAREABLES:
        target = full_rectangle_target(recipe, 1, 2, "横盘款", True)
    elif category == "横盘款":
        target = full_rectangle_target(recipe, 2, 2, "中块款", True)
    elif category == "中块款" and cell_count in {3, 4}:
        target = full_rectangle_target(recipe, 2, 3, "大块款", True)
    else:
        target = {key: recipe[key] for key in GEOMETRY_KEYS if key in recipe}

    return sparse_override(recipe, target)


def generate(config: dict) -> dict:
    shape_types = list(config["meta"]["shape_types"])
    config["meta"]["shape_types"] = ["大块款" if value == "招牌款" else value for value in shape_types]

    for recipe_id, recipe in config["recipes"].items():
        recipe["growth_variants"] = {
            "popular": {},
            "signature": signature_override(recipe_id, recipe),
        }
    return config


def rendered_config(path: Path) -> str:
    config = json.loads(path.read_text(encoding="utf-8"))
    generate(config)
    return json.dumps(config, ensure_ascii=False, indent=2) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, default=DEFAULT_CONFIG_PATH)
    parser.add_argument("--check", action="store_true", help="Fail if the config is not generated exactly.")
    args = parser.parse_args()

    path = args.config.resolve()
    current = path.read_text(encoding="utf-8")
    expected = rendered_config(path)
    if args.check:
        if current != expected:
            print(f"STALE: {path}")
            return 1
        print(f"OK: {path}")
        return 0

    path.write_text(expected, encoding="utf-8", newline="\n")
    recipes = json.loads(expected)["recipes"]
    changed = sum(bool(recipe["growth_variants"]["signature"]) for recipe in recipes.values())
    print(f"UPDATED: {path}")
    print(f"RECIPES: {len(recipes)}")
    print(f"SIGNATURE_OVERRIDES: {changed}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
