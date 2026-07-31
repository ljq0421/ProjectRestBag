#!/usr/bin/env python3
"""Generate the complete 166-recipe challenge catalog and research tree."""

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
TREE_PATH = ROOT / "doc/challenge/research_tree.json"
DISTINCTIVENESS_PILOT_PATH = (
    ROOT / "doc/challenge/recipe_distinctiveness_pilot.json"
)

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
ROLE_NAMES = {
    "tempo": "快速周转",
    "pairing": "搭配联动",
    "signature": "招牌输出",
    "softness": "柔软续航",
    "flavor": "风味覆盖",
    "shape": "形状构筑",
    "sustain": "持续经营",
    "space": "空间联动",
}
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
BASELINE_IDS = tuple(CURRENT_BRANCHES)
STARTER_IDS = (
    "butter_cookie",
    "strawberry_jelly",
    "milk_pudding",
    "blueberry_muffin",
    "sponge_cake",
    "chocolate_lava_cake",
)
BRANCH_COPY = {
    "tempo_display": ("节奏陈列", "快速周转、小件复制与早期窗口。"),
    "fruit_set": ("水果套装", "水果、饮品与套装标签的复合覆盖。"),
    "signature_display": ("招牌展示", "高满足力、大件与晚期招牌取舍。"),
    "milk_soft": ("奶香软糯", "柔软质地、奶香与持续供给。"),
    "tea_bittersweet": ("茶香苦甜", "茶香、苦甜与浓郁风味覆盖。"),
    "crisp_bake": ("香脆烘焙", "小件香脆、烘焙与形状效率。"),
    "savory_hearty": ("咸香饱腹", "咸香、饱腹与低频高覆盖。"),
    "spatial_combo": ("空间联动", "旋转、异形和相邻空间组合。"),
}
BRANCH_REVEAL_ENCOUNTERS = {
    "milk_soft": "route_b_soft_opening",
    "tea_bittersweet": "route_b_tea_salon",
    "crisp_bake": "route_b_crisp_festival",
    "savory_hearty": "route_c_hearty_market",
    "spatial_combo": "route_c_space_architect",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sync-manifest", action="store_true")
    parser.add_argument("--check", action="store_true")
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
    return 1 if level <= 1 else 2 if level <= 3 else 3 if level <= 5 else 4


def proposed_tags(recipe: dict[str, Any], branch_id: str) -> list[str]:
    source = set(str(value) for value in recipe.get("tags", []))
    result: list[str] = []
    mapping = (
        ("fast", {"低负担"}),
        ("fruit", {"果香"}),
        ("drink", {"清爽", "清凉"}),
        ("refreshing", {"清爽", "清凉"}),
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


def assign_batches(catalog: dict[str, dict[str, Any]]) -> dict[str, str]:
    candidates = sorted(
        (recipe for recipe_id, recipe in catalog.items() if recipe_id not in BASELINE_IDS),
        key=lambda recipe: (int(recipe.get("unlock_level") or 0), str(recipe["id"])),
    )
    assignments: dict[str, str] = {}
    cursor = 0
    for batch_id, size in (("A", 18), ("B", 34), ("C", 48), ("D", 54)):
        for recipe in candidates[cursor : cursor + size]:
            assignments[str(recipe["id"])] = batch_id
        cursor += size
    if cursor != len(candidates):
        raise SystemExit(f"Batch contract covers {cursor}, expected {len(candidates)}")
    return assignments


def normalized_shape(display_entry: dict[str, Any]) -> list[list[int]]:
    explicit = display_entry.get("shape_cells", [])
    if explicit:
        xs = [int(cell[0]) for cell in explicit]
        ys = [int(cell[1]) for cell in explicit]
        min_x, min_y = min(xs), min(ys)
        return [[int(cell[1]) - min_y, int(cell[0]) - min_x] for cell in explicit]
    shape = str(display_entry.get("default_shape", "1x1"))
    count = max(1, int(display_entry.get("cell_count", 1)))
    width, height = 1, 1
    if "x" in shape:
        left, right = shape.split("x", 1)
        width, height = max(1, int(left)), max(1, int(right))
    cells: list[list[int]] = []
    for row in range(height):
        for column in range(width):
            cells.append([row, column])
            if len(cells) == count:
                return cells
    return cells or [[0, 0]]


def proposed_runtime(
    source: dict[str, Any],
    display_entry: dict[str, Any],
    combat_tags: list[str],
) -> dict[str, Any]:
    cells = normalized_shape(display_entry)
    count = len(cells)
    tier = proposed_tier(source)
    seconds = int(source.get("production_duration_seconds") or 5)
    cycle_ms = max(2000, min(12000, seconds * 1000))
    copy_limit = 3 if count == 1 else 2 if count == 2 else 1
    return {
        "shape_cells": cells,
        "supply_cost": max(2, min(6, count + 1 + (1 if tier >= 3 else 0))),
        "copy_limit": copy_limit,
        "virtual_stock": max(2, copy_limit * 2),
        "cycle_ms": cycle_ms,
        "satisfaction": max(4, min(18, 2 + count * 2 + tier + cycle_ms // 4000)),
        "tags": combat_tags,
        "rotatable": bool(display_entry.get("rotatable", False)),
    }


def challenge_role_summary(
    roles: list[str],
    combat_tags: list[str],
    runtime_fields: dict[str, Any],
) -> str:
    role_text = "、".join(ROLE_NAMES.get(role, role) for role in roles)
    tag_text = "、".join(combat_tags)
    shape_count = len(runtime_fields.get("shape_cells", []))
    rotation = "可旋转" if runtime_fields.get("rotatable", False) else "固定朝向"
    return (
        f"{role_text}；以{tag_text}覆盖需求，"
        f"{shape_count} 格{rotation}，"
        f"{int(runtime_fields.get('cycle_ms', 0)) // 1000} 秒周期，"
        f"成本 {int(runtime_fields.get('supply_cost', 0))}，"
        f"最多复制 {int(runtime_fields.get('copy_limit', 0))} 份。"
    )


def apply_distinctiveness_pilot(manifest: dict[str, Any]) -> dict[str, Any]:
    if not DISTINCTIVENESS_PILOT_PATH.exists():
        return manifest
    pilot = read_json(DISTINCTIVENESS_PILOT_PATH)
    entries = manifest.get("recipes", {})
    for recipe_id, pilot_entry in pilot.get("recipes", {}).items():
        if recipe_id not in entries:
            raise SystemExit(
                f"Distinctiveness pilot references unknown recipe: {recipe_id}"
            )
        entry = entries[recipe_id]
        expected_branch = str(pilot_entry.get("expected_branch_id", ""))
        expected_tier = int(pilot_entry.get("expected_tier", 0))
        if str(entry.get("research_branch_id", "")) != expected_branch:
            raise SystemExit(
                f"{recipe_id} pilot branch drift: "
                f"{entry.get('research_branch_id')} != {expected_branch}"
            )
        if int(entry.get("research_tier", 0)) != expected_tier:
            raise SystemExit(
                f"{recipe_id} pilot tier drift: "
                f"{entry.get('research_tier')} != {expected_tier}"
            )
        runtime_target = dict(pilot_entry.get("runtime", {}))
        missing = [
            field for field in RUNTIME_FIELDS if field not in runtime_target
        ]
        if missing:
            raise SystemExit(
                f"{recipe_id} pilot runtime fields missing: {missing}"
            )
        runtime_fields = {
            field: runtime_target[field] for field in RUNTIME_FIELDS
        }
        combat_tags = list(runtime_fields["tags"])
        entry["combat_tags"] = combat_tags
        entry["runtime"] = runtime_fields
        entry["challenge_role_summary"] = challenge_role_summary(
            list(entry.get("build_roles", [])),
            combat_tags,
            runtime_fields,
        )
        entry["review_notes"] = (
            "第一批同质配方人工重做（2026-07-31）："
            f"{pilot_entry.get('design_role', '')}；"
            f"{pilot_entry.get('tradeoff', '')}"
        )
    return manifest


def sync_manifest() -> dict[str, Any]:
    catalog = load_catalog(CATALOG_PATH)
    _, display = load_display_config(DISPLAY_PATH)
    runtime = read_json(RUNTIME_PATH)
    existing = read_json(MANIFEST_PATH)
    previous_entries = existing.get("recipes", {})
    runtime_recipes = runtime.get("recipes", {})
    batches = assign_batches(catalog)
    recipes: dict[str, Any] = {}
    for recipe_id, source in catalog.items():
        display_entry = display.get(recipe_id, {})
        previous = previous_entries.get(recipe_id, {})
        baseline = recipe_id in BASELINE_IDS
        branch_id = str(
            previous.get(
                "research_branch_id",
                CURRENT_BRANCHES.get(recipe_id, proposed_branch(source)),
            )
        )
        if branch_id not in BRANCHES:
            branch_id = proposed_branch(source)
        combat_tags = list(
            previous.get(
                "combat_tags",
                runtime_recipes.get(recipe_id, {}).get(
                    "tags", proposed_tags(source, branch_id)
                ),
            )
        )
        if set(source.get("tags", [])) & {"清爽", "清凉"}:
            for tag_id in ("drink", "refreshing"):
                if tag_id not in combat_tags:
                    combat_tags.append(tag_id)
        if baseline:
            definition = runtime_recipes[recipe_id]
            runtime_fields = {
                field: definition[field] for field in RUNTIME_FIELDS if field in definition
            }
        elif isinstance(previous.get("runtime"), dict) and previous["runtime"]:
            runtime_fields = previous["runtime"]
        else:
            runtime_fields = proposed_runtime(source, display_entry, combat_tags)
        if not baseline:
            runtime_fields["tags"] = combat_tags
        batch = "baseline" if baseline else batches[recipe_id]
        roles = list(
            CURRENT_BUILD_ROLES.get(
                recipe_id, previous.get("build_roles", build_roles(branch_id))
            )
        )
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
                "shape_cells": normalized_shape(display_entry),
            },
            "migration_batch": batch,
            "content_status": "released",
            "unlock_kind": "starter" if recipe_id in STARTER_IDS else "research",
            "research_branch_id": branch_id,
            "research_tier": int(previous.get("research_tier", proposed_tier(source))),
            "research_node_id": str(
                previous.get(
                    "research_node_id",
                    recipe_id if baseline and recipe_id not in STARTER_IDS else "",
                )
            ),
            "combat_tags": combat_tags,
            "build_roles": roles,
            "challenge_role_summary": challenge_role_summary(
                roles, combat_tags, runtime_fields
            ),
            "runtime": runtime_fields,
            "review_notes": str(
                previous.get("review_notes")
                or f"阶段 {6 if baseline else {'A': 7, 'B': 8, 'C': 9, 'D': 10}[batch]} "
                "归一化迁移；继续以真人构筑数据复核。"
            ),
        }
    return {
        "meta": {
            "total_recipes": len(recipes),
            "released_recipes": len(recipes),
            "starter_recipes": len(STARTER_IDS),
            "research_recipes": len(recipes) - len(STARTER_IDS),
            "target_batch": "D",
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


def generated_research_tree(
    current_tree: dict[str, Any], manifest: dict[str, Any]
) -> dict[str, Any]:
    entries: dict[str, dict[str, Any]] = manifest["recipes"]
    baseline_research = set(BASELINE_IDS) - set(STARTER_IDS)
    nodes = {
        node_id: node
        for node_id, node in current_tree.get("nodes", {}).items()
        if any(
            unlock.get("type") == "recipe" and unlock.get("id") in baseline_research
            for unlock in node.get("unlocks", [])
        )
    }
    boss_reveals = {
        encounter_id: list(node_ids)
        for encounter_id, node_ids in current_tree.get("boss_reveals", {}).items()
        if all(node_id in nodes for node_id in node_ids)
    }
    branches: list[dict[str, Any]] = []
    for branch_id in BRANCHES:
        name, description = BRANCH_COPY[branch_id]
        node_ids = [
            node_id
            for node_id, node in nodes.items()
            if node.get("branch_id") == branch_id
        ]
        previous_node_id = node_ids[-1] if node_ids else ""
        candidates = [
            recipe_id
            for recipe_id, entry in entries.items()
            if entry["unlock_kind"] == "research"
            and entry["research_branch_id"] == branch_id
            and recipe_id not in baseline_research
        ]
        candidates.sort(
            key=lambda recipe_id: (
                entries[recipe_id]["research_tier"],
                entries[recipe_id]["migration_batch"],
                recipe_id,
            )
        )
        cursor = 0
        sequence = 1
        while cursor < len(candidates):
            tier = int(entries[candidates[cursor]]["research_tier"])
            family: list[str] = []
            while (
                cursor < len(candidates)
                and int(entries[candidates[cursor]]["research_tier"]) == tier
                and len(family) < 3
            ):
                family.append(candidates[cursor])
                cursor += 1
            node_id = f"family_{branch_id}_t{tier}_{sequence:02d}"
            tags = sorted(
                {tag for recipe_id in family for tag in entries[recipe_id]["combat_tags"]}
            )
            nodes[node_id] = {
                "id": node_id,
                "display_name": f"{name} · T{tier}-{sequence}",
                "branch_id": branch_id,
                "tier": tier,
                "cost": 3 + (tier - 1) * 2,
                "prerequisite_ids": [previous_node_id] if previous_node_id else [],
                "tags": tags,
                "build_purpose": (
                    f"解锁 {len(family)} 个{name}家族配方，"
                    "在同主题下提供不同形状、周期和复制策略。"
                ),
                "unlocks": [
                    {"type": "recipe", "id": recipe_id} for recipe_id in family
                ],
            }
            for recipe_id in family:
                entries[recipe_id]["research_node_id"] = node_id
            node_ids.append(node_id)
            previous_node_id = node_id
            sequence += 1
        for node_id in node_ids:
            for unlock in nodes[node_id].get("unlocks", []):
                if unlock.get("type") == "recipe":
                    entries[str(unlock["id"])]["research_node_id"] = node_id
        branches.append(
            {
                "id": branch_id,
                "display_name": name,
                "description": description,
                "node_ids": node_ids,
            }
        )
        if branch_id in BRANCH_REVEAL_ENCOUNTERS and node_ids:
            boss_reveals[BRANCH_REVEAL_ENCOUNTERS[branch_id]] = [node_ids[0]]
    return {
        "id": "complete_recipe_research",
        "display_name": "甜点陈列研究",
        "completion_reward_points": 3,
        "starter_recipe_ids": list(STARTER_IDS),
        "branches": branches,
        "boss_reveals": boss_reveals,
        "nodes": nodes,
    }


def generated_runtime(current: dict[str, Any], manifest: dict[str, Any]) -> dict[str, Any]:
    entries = manifest["recipes"]
    current_order = list(current.get("recipes", {}))
    ordered_ids = current_order + sorted(set(entries) - set(current_order))
    recipes: dict[str, Any] = {}
    for recipe_id in ordered_ids:
        entry = entries[recipe_id]
        definition = dict(entry["runtime"])
        missing = [field for field in RUNTIME_FIELDS if field not in definition]
        if missing:
            raise SystemExit(f"{recipe_id} missing runtime fields: {missing}")
        definition["build_roles"] = list(entry["build_roles"])
        recipes[recipe_id] = definition
    research_ids = [
        recipe_id for recipe_id in ordered_ids if recipe_id not in STARTER_IDS
    ]
    return {
        "grid_rows": int(current.get("grid_rows", 6)),
        "grid_columns": int(current.get("grid_columns", 8)),
        "supply_budget": int(current.get("supply_budget", 16)),
        "starter_recipe_ids": list(STARTER_IDS),
        "research_recipe_ids": research_ids,
        "recipes": recipes,
    }


def main() -> None:
    args = parse_args()
    current = read_json(RUNTIME_PATH)
    manifest = (
        sync_manifest()
        if args.sync_manifest or not MANIFEST_PATH.exists()
        else read_json(MANIFEST_PATH)
    )
    manifest = apply_distinctiveness_pilot(manifest)
    tree = generated_research_tree(read_json(TREE_PATH), manifest)
    runtime = generated_runtime(current, manifest)
    write_or_check(MANIFEST_PATH, manifest, args.check)
    write_or_check(TREE_PATH, tree, args.check)
    write_or_check(RUNTIME_PATH, runtime, args.check)
    print(
        "CHALLENGE_RECIPE_GENERATION_OK "
        f"manifest={len(manifest['recipes'])} runtime={len(runtime['recipes'])} "
        f"starters={len(runtime['starter_recipe_ids'])} "
        f"research={len(runtime['research_recipe_ids'])}"
    )


if __name__ == "__main__":
    main()
