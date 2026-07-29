#!/usr/bin/env python3
"""Build the challenge recipe manifest and generated runtime catalog.

The old shop catalog and showcase display file are source evidence only.  This
tool never derives final battle numbers from price or production duration.
Unmigrated recipes remain explicit draft rows until a designer fills and
reviews their challenge fields.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

from audit_recipe_data import load_catalog, load_display_config


ROOT = Path(__file__).resolve().parents[1]
CATALOG_PATH = ROOT / "scripts/catalog.gd"
DISPLAY_PATH = ROOT / "doc/recipe_display_config.json"
RUNTIME_PATH = ROOT / "doc/challenge/challenge_recipes.json"
MANIFEST_PATH = ROOT / "doc/challenge/recipe_progression_manifest.json"

BRANCHES = (
    "tempo_display",
    "fruit_set",
    "signature_display",
    "milk_soft",
    "tea_bittersweet",
    "crisp_bake",
    "savory_hearty",
    "spatial_combo",
)
RUNTIME_FIELDS = (
    "shape_cells",
    "supply_cost",
    "copy_limit",
    "virtual_stock",
    "cycle_ms",
    "satisfaction",
    "tags",
    "rotatable",
)
CURRENT_BRANCHES = {
    "butter_cookie": "tempo_display",
    "strawberry_jelly": "fruit_set",
    "milk_pudding": "milk_soft",
    "blueberry_muffin": "crisp_bake",
    "sponge_cake": "signature_display",
    "chocolate_lava_cake": "signature_display",
    "vanilla_scone": "tempo_display",
    "chocolate_cookie": "tempo_display",
    "blueberry_mousse": "fruit_set",
    "strawberry_mousse": "fruit_set",
    "cream_shortcake": "signature_display",
    "caramel_mousse": "signature_display",
}
CURRENT_BUILD_ROLES = {
    "butter_cookie": ["tempo"],
    "strawberry_jelly": ["tempo"],
    "milk_pudding": ["pairing"],
    "blueberry_muffin": ["pairing"],
    "sponge_cake": ["signature"],
    "chocolate_lava_cake": ["signature"],
    "vanilla_scone": ["tempo"],
    "chocolate_cookie": ["tempo"],
    "blueberry_mousse": ["pairing"],
    "strawberry_mousse": ["pairing"],
    "cream_shortcake": ["signature"],
    "caramel_mousse": ["signature"],
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--sync-manifest",
        action="store_true",
        help="create or refresh source evidence while preserving authored challenge fields",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="fail if generated files differ instead of writing them",
    )
    return parser.parse_args()


def read_json(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {}
    return json.loads(path.read_text(encoding="utf-8-sig"))


def write_or_check(path: Path, payload: dict[str, Any], check: bool) -> None:
    text = json.dumps(payload, ensure_ascii=False, indent=2) + "\n"
    if check:
        current = path.read_text(encoding="utf-8-sig") if path.exists() else ""
        if current != text:
            raise SystemExit(f"Generated file is stale: {path.relative_to(ROOT)}")
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def proposed_branch(recipe: dict[str, Any]) -> str:
    tags = set(str(value) for value in recipe.get("tags", []))
    if tags & {"咸香", "饱腹"}:
        return "savory_hearty"
    if "茶香" in tags:
        return "tea_bittersweet"
    if "香脆" in tags:
        return "crisp_bake"
    if tags & {"软糯", "奶香"}:
        return "milk_soft"
    if tags & {"果香", "清凉", "清爽"}:
        return "fruit_set"
    if tags & {"招牌", "浓郁", "苦甜"}:
        return "signature_display"
    if "低负担" in tags:
        return "tempo_display"
    return "spatial_combo"


def proposed_tier(recipe: dict[str, Any]) -> int:
    level = int(recipe.get("unlock_level") or 0)
    if level <= 1:
        return 1
    if level <= 3:
        return 2
    if level <= 5:
        return 3
    return 4


def proposed_tags(recipe: dict[str, Any], branch_id: str) -> list[str]:
    source = set(str(value) for value in recipe.get("tags", []))
    result: list[str] = []
    mapping = (
        ("fast", {"低负担"}),
        ("fruit", {"果香"}),
        ("drink", {"清爽", "清凉"}),
        ("soft", {"软糯", "奶香"}),
        ("tea", {"茶香"}),
        ("crisp", {"香脆"}),
        ("savory", {"咸香"}),
        ("hearty", {"饱腹"}),
        ("rich", {"浓郁", "苦甜"}),
        ("signature", {"招牌"}),
    )
    for challenge_tag, source_tags in mapping:
        if source & source_tags:
            result.append(challenge_tag)
    if branch_id == "spatial_combo":
        result.append("spatial")
    if not result:
        result.append("aromatic")
    return result


def build_roles(branch_id: str) -> list[str]:
    return {
        "tempo_display": ["tempo"],
        "fruit_set": ["pairing"],
        "signature_display": ["signature"],
        "milk_soft": ["softness"],
        "tea_bittersweet": ["flavor"],
        "crisp_bake": ["tempo", "shape"],
        "savory_hearty": ["sustain"],
        "spatial_combo": ["space"],
    }[branch_id]


def assign_batches(
    catalog: dict[str, dict[str, Any]],
    released_ids: set[str],
) -> dict[str, str]:
    candidates = sorted(
        (recipe for recipe_id, recipe in catalog.items() if recipe_id not in released_ids),
        key=lambda recipe: (int(recipe.get("unlock_level") or 0), str(recipe["id"])),
    )
    sizes = (("A", 18), ("B", 34), ("C", 48), ("D", 54))
    assignments: dict[str, str] = {}
    cursor = 0
    for batch_id, size in sizes:
        for recipe in candidates[cursor : cursor + size]:
            assignments[str(recipe["id"])] = batch_id
        cursor += size
    if cursor != len(candidates):
        raise SystemExit(
            f"Batch contract covers {cursor} recipes but {len(candidates)} need migration"
        )
    return assignments


def sync_manifest() -> dict[str, Any]:
    catalog = load_catalog(CATALOG_PATH)
    _, display = load_display_config(DISPLAY_PATH)
    runtime = read_json(RUNTIME_PATH)
    existing = read_json(MANIFEST_PATH)
    existing_recipes = existing.get("recipes", {})
    runtime_recipes = runtime.get("recipes", {})
    released_ids = set(str(recipe_id) for recipe_id in runtime_recipes)
    batches = assign_batches(catalog, released_ids)

    recipes: dict[str, Any] = {}
    for recipe_id, source in catalog.items():
        display_entry = display.get(recipe_id, {})
        previous = existing_recipes.get(recipe_id, {})
        is_released = recipe_id in released_ids
        branch_id = str(
            previous.get(
                "research_branch_id",
                CURRENT_BRANCHES.get(recipe_id, proposed_branch(source)),
            )
        )
        if branch_id not in BRANCHES:
            branch_id = proposed_branch(source)
        unlock_kind = "draft"
        if recipe_id in runtime.get("starter_recipe_ids", []):
            unlock_kind = "starter"
        elif recipe_id in runtime.get("research_recipe_ids", []):
            unlock_kind = "research"
        runtime_fields: dict[str, Any] = {}
        if is_released:
            definition = runtime_recipes[recipe_id]
            runtime_fields = {
                field: definition[field]
                for field in RUNTIME_FIELDS
                if field in definition
            }
        elif isinstance(previous.get("runtime"), dict):
            runtime_fields = previous["runtime"]

        recipes[recipe_id] = {
            "recipe_id": recipe_id,
            "display_name": source.get("name", recipe_id),
            "source": {
                "device": source.get("device", ""),
                "materials": source.get("materials", []),
                "tags": source.get("tags", []),
                "unlock_level": int(source.get("unlock_level") or 0),
                "production_duration_seconds": int(
                    source.get("production_duration_seconds") or 0
                ),
                "display_shape": display_entry.get("default_shape", ""),
                "cell_count": int(display_entry.get("cell_count", 0)),
                "rotatable": bool(display_entry.get("rotatable", False)),
            },
            "migration_batch": "baseline" if is_released else batches[recipe_id],
            "content_status": "released" if is_released else str(
                previous.get("content_status", "draft")
            ),
            "unlock_kind": unlock_kind if is_released else str(
                previous.get("unlock_kind", "draft")
            ),
            "research_branch_id": branch_id,
            "research_tier": int(
                previous.get("research_tier", proposed_tier(source))
            ),
            "research_node_id": str(
                previous.get(
                    "research_node_id",
                    recipe_id if unlock_kind == "research" else "",
                )
            ),
            "combat_tags": list(
                previous.get(
                    "combat_tags",
                    runtime_recipes.get(recipe_id, {}).get(
                        "tags",
                        proposed_tags(source, branch_id),
                    ),
                )
            ),
            "build_roles": list(
                CURRENT_BUILD_ROLES.get(
                    recipe_id,
                    previous.get("build_roles", build_roles(branch_id)),
                )
            ),
            "runtime": runtime_fields,
            "review_notes": str(previous.get("review_notes", "")),
        }

    return {
        "meta": {
            "total_recipes": len(recipes),
            "released_recipes": len(released_ids),
            "starter_recipes": len(runtime.get("starter_recipe_ids", [])),
            "research_recipes": len(runtime.get("research_recipe_ids", [])),
            "migration_batches": {"A": 18, "B": 34, "C": 48, "D": 54},
            "content_status_order": [
                "draft",
                "data_validated",
                "simulation_validated",
                "mouse_validated",
                "released",
            ],
        },
        "branches": list(BRANCHES),
        "recipes": recipes,
    }


def generated_runtime(
    current_runtime: dict[str, Any],
    manifest: dict[str, Any],
) -> dict[str, Any]:
    released = {
        recipe_id: entry
        for recipe_id, entry in manifest.get("recipes", {}).items()
        if entry.get("content_status") == "released"
    }
    current_order = list(current_runtime.get("recipes", {}).keys())
    remaining = sorted(recipe_id for recipe_id in released if recipe_id not in current_order)
    ordered_ids = [recipe_id for recipe_id in current_order if recipe_id in released] + remaining
    starter_ids = [
        recipe_id
        for recipe_id in ordered_ids
        if released[recipe_id].get("unlock_kind") == "starter"
    ]
    research_ids = [
        recipe_id
        for recipe_id in ordered_ids
        if released[recipe_id].get("unlock_kind") == "research"
    ]
    recipes: dict[str, Any] = {}
    for recipe_id in ordered_ids:
        entry = released[recipe_id]
        definition = dict(entry.get("runtime", {}))
        missing = [field for field in RUNTIME_FIELDS if field not in definition]
        if missing:
            raise SystemExit(f"Released recipe {recipe_id} is missing runtime fields: {missing}")
        definition["build_roles"] = list(entry.get("build_roles", []))
        recipes[recipe_id] = definition
    return {
        "grid_rows": int(current_runtime.get("grid_rows", 6)),
        "grid_columns": int(current_runtime.get("grid_columns", 8)),
        "supply_budget": int(current_runtime.get("supply_budget", 16)),
        "starter_recipe_ids": starter_ids,
        "research_recipe_ids": research_ids,
        "recipes": recipes,
    }


def main() -> None:
    args = parse_args()
    current_runtime = read_json(RUNTIME_PATH)
    manifest = sync_manifest() if args.sync_manifest or not MANIFEST_PATH.exists() else read_json(MANIFEST_PATH)
    if args.sync_manifest or not MANIFEST_PATH.exists():
        write_or_check(MANIFEST_PATH, manifest, args.check)
    generated = generated_runtime(current_runtime, manifest)
    write_or_check(RUNTIME_PATH, generated, args.check)
    print(
        "CHALLENGE_RECIPE_GENERATION_OK "
        f"manifest={len(manifest.get('recipes', {}))} "
        f"runtime={len(generated.get('recipes', {}))} "
        f"starters={len(generated.get('starter_recipe_ids', []))}"
    )


if __name__ == "__main__":
    main()
