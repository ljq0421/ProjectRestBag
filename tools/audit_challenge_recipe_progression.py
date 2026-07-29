#!/usr/bin/env python3
"""Audit ProjectRest Two challenge recipe progression coverage."""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any

from audit_recipe_data import load_catalog, load_display_config


ROOT = Path(__file__).resolve().parents[1]
CATALOG_PATH = ROOT / "scripts/catalog.gd"
DISPLAY_PATH = ROOT / "doc/recipe_display_config.json"
RUNTIME_PATH = ROOT / "doc/challenge/challenge_recipes.json"
MANIFEST_PATH = ROOT / "doc/challenge/recipe_progression_manifest.json"
TAXONOMY_PATH = ROOT / "doc/challenge/challenge_tag_taxonomy.json"
TREE_PATH = ROOT / "doc/challenge/research_tree.json"
OUTPUT_PATH = ROOT / "doc/challenge/recipe_migration_audit.md"

RUNTIME_FIELDS = {
    "shape_cells",
    "supply_cost",
    "copy_limit",
    "virtual_stock",
    "cycle_ms",
    "satisfaction",
    "tags",
    "rotatable",
    "build_roles",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    return parser.parse_args()


def read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8-sig"))


def main() -> None:
    args = parse_args()
    catalog = load_catalog(CATALOG_PATH)
    _, display = load_display_config(DISPLAY_PATH)
    runtime = read_json(RUNTIME_PATH)
    manifest = read_json(MANIFEST_PATH)
    taxonomy = read_json(TAXONOMY_PATH)
    tree = read_json(TREE_PATH)

    manifest_recipes = manifest.get("recipes", {})
    runtime_recipes = runtime.get("recipes", {})
    known_tags = set(taxonomy.get("tags", {}).keys())
    known_roles = set(taxonomy.get("build_roles", {}).keys())
    known_branches = set(manifest.get("branches", []))
    blockers: list[str] = []
    warnings: list[str] = []

    expected_ids = set(catalog)
    for label, ids in (
        ("display", set(display)),
        ("manifest", set(manifest_recipes)),
    ):
        missing = sorted(expected_ids - ids)
        extra = sorted(ids - expected_ids)
        if missing:
            blockers.append(f"{label} missing recipe IDs: {', '.join(missing)}")
        if extra:
            blockers.append(f"{label} has unknown recipe IDs: {', '.join(extra)}")

    starter_ids = list(runtime.get("starter_recipe_ids", []))
    research_ids = list(runtime.get("research_recipe_ids", []))
    if len(starter_ids) != 6:
        blockers.append(f"runtime starter count must be 6, found {len(starter_ids)}")
    if set(starter_ids) & set(research_ids):
        blockers.append("starter and research runtime pools overlap")
    if set(runtime_recipes) != set(starter_ids) | set(research_ids):
        blockers.append("runtime recipe IDs do not equal starter + research pools")

    batch_counts: Counter[str] = Counter()
    branch_counts: Counter[str] = Counter()
    status_counts: Counter[str] = Counter()
    for recipe_id, entry in manifest_recipes.items():
        batch_counts[str(entry.get("migration_batch", ""))] += 1
        branch_id = str(entry.get("research_branch_id", ""))
        branch_counts[branch_id] += 1
        status = str(entry.get("content_status", ""))
        status_counts[status] += 1
        if branch_id not in known_branches:
            blockers.append(f"{recipe_id}: unknown research branch {branch_id}")
        unknown_tags = sorted(set(entry.get("combat_tags", [])) - known_tags)
        if unknown_tags:
            blockers.append(f"{recipe_id}: unknown challenge tags {unknown_tags}")
        unknown_roles = sorted(set(entry.get("build_roles", [])) - known_roles)
        if unknown_roles:
            blockers.append(f"{recipe_id}: unknown build roles {unknown_roles}")
        if status == "released":
            if recipe_id not in runtime_recipes:
                blockers.append(f"{recipe_id}: released in manifest but absent from runtime")
            runtime_fields = entry.get("runtime", {})
            missing_fields = sorted(RUNTIME_FIELDS - set(runtime_fields) - {"build_roles"})
            if missing_fields:
                blockers.append(f"{recipe_id}: released runtime fields missing {missing_fields}")
        elif recipe_id in runtime_recipes:
            blockers.append(f"{recipe_id}: runtime recipe is not released in manifest")

    tree_owned: set[str] = set()
    for node_id, node in tree.get("nodes", {}).items():
        for unlock in node.get("unlocks", []):
            if unlock.get("type") != "recipe":
                continue
            recipe_id = str(unlock.get("id", ""))
            if recipe_id in tree_owned:
                blockers.append(f"research recipe has multiple node owners: {recipe_id}")
            tree_owned.add(recipe_id)
            if recipe_id not in runtime_recipes:
                blockers.append(f"research node {node_id} unlocks non-runtime recipe {recipe_id}")
    if tree_owned != set(research_ids):
        blockers.append("research tree recipe rewards do not match runtime research pool")

    proposed = sum(
        count for batch, count in batch_counts.items() if batch in {"A", "B", "C", "D"}
    )
    if proposed != 154:
        blockers.append(f"migration batches must cover 154 draft recipes, found {proposed}")
    if status_counts.get("released", 0) != len(runtime_recipes):
        blockers.append("released manifest count does not match runtime count")
    if status_counts.get("draft", 0) > 0:
        warnings.append(
            f"{status_counts['draft']} recipes remain draft and are intentionally excluded from runtime"
        )

    lines = [
        "# Challenge Recipe Migration Audit",
        "",
        "Generated by `tools/audit_challenge_recipe_progression.py`.",
        "",
        "## Summary",
        "",
        f"- Catalog recipes: {len(catalog)}",
        f"- Display recipes: {len(display)}",
        f"- Manifest recipes: {len(manifest_recipes)}",
        f"- Runtime challenge recipes: {len(runtime_recipes)}",
        f"- Starter recipes: {len(starter_ids)}",
        f"- Research recipes: {len(research_ids)}",
        "",
        "## Migration Batches",
        "",
    ]
    for batch_id in ("baseline", "A", "B", "C", "D"):
        lines.append(f"- `{batch_id}`: {batch_counts.get(batch_id, 0)} recipes")
    lines.extend(["", "## Proposed Research Branch Coverage", ""])
    for branch_id in manifest.get("branches", []):
        lines.append(f"- `{branch_id}`: {branch_counts.get(branch_id, 0)} recipes")
    lines.extend(["", "## Blocking Mismatches", ""])
    lines.extend(f"- {message}" for message in blockers)
    if not blockers:
        lines.append("- None")
    lines.extend(["", "## Expected Draft Warnings", ""])
    lines.extend(f"- {message}" for message in warnings)
    if not warnings:
        lines.append("- None")
    lines.extend(["", "## Result", ""])
    lines.append("- PASS" if not blockers else "- FAIL")
    text = "\n".join(lines) + "\n"

    if args.check:
        current = OUTPUT_PATH.read_text(encoding="utf-8-sig") if OUTPUT_PATH.exists() else ""
        if blockers:
            raise SystemExit("\n".join(blockers))
        if current != text:
            raise SystemExit("Generated audit is stale: doc/challenge/recipe_migration_audit.md")
    else:
        OUTPUT_PATH.write_text(text, encoding="utf-8")
        if blockers:
            raise SystemExit("\n".join(blockers))
    print(
        "CHALLENGE_RECIPE_AUDIT_PASS "
        f"catalog={len(catalog)} runtime={len(runtime_recipes)} draft={status_counts.get('draft', 0)}"
    )


if __name__ == "__main__":
    main()
