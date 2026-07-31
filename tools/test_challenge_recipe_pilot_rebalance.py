#!/usr/bin/env python3
"""Verify the confirmed distinctiveness pilot against generated recipe data."""

from __future__ import annotations

import json
from pathlib import Path

from audit_challenge_recipe_similarity import (
    build_records,
    dominance_relations,
    exact_duplicate_clusters,
    near_duplicate_pairs,
)


ROOT = Path(__file__).resolve().parents[1]
PILOT_PATH = ROOT / "doc/challenge/recipe_distinctiveness_pilot.json"
MANIFEST_PATH = ROOT / "doc/challenge/recipe_progression_manifest.json"
RUNTIME_PATH = ROOT / "doc/challenge/challenge_recipes.json"


def read_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8-sig"))


def main() -> None:
    pilot = read_json(PILOT_PATH)
    manifest = read_json(MANIFEST_PATH)
    runtime = read_json(RUNTIME_PATH)
    pilot_recipes = pilot["recipes"]
    pilot_ids = set(pilot_recipes)
    acceptance = pilot["acceptance"]

    assert len(pilot_ids) == int(acceptance["recipe_count"]) == 12
    for recipe_id, pilot_entry in pilot_recipes.items():
        manifest_entry = manifest["recipes"][recipe_id]
        assert (
            manifest_entry["research_branch_id"]
            == pilot_entry["expected_branch_id"]
        )
        assert int(manifest_entry["research_tier"]) == int(
            pilot_entry["expected_tier"]
        )
        assert manifest_entry["combat_tags"] == pilot_entry["runtime"]["tags"]
        assert manifest_entry["runtime"] == pilot_entry["runtime"]
        assert runtime["recipes"][recipe_id]["build_roles"] == manifest_entry[
            "build_roles"
        ]
        for field, expected in pilot_entry["runtime"].items():
            assert runtime["recipes"][recipe_id][field] == expected

    records = build_records(runtime, manifest)
    exact_collisions = [
        sorted(record.recipe_id for record in cluster)
        for cluster in exact_duplicate_clusters(records)
        if any(record.recipe_id in pilot_ids for record in cluster)
    ]
    internal_near_pairs = [
        pair
        for pair in near_duplicate_pairs(records)
        if pair["left_id"] in pilot_ids and pair["right_id"] in pilot_ids
    ]
    involved_dominance = [
        relation
        for relation in dominance_relations(records)
        if relation["dominant_id"] in pilot_ids
        or relation["dominated_id"] in pilot_ids
    ]

    if acceptance["require_global_exact_signature_uniqueness"]:
        assert exact_collisions == []
    assert len(internal_near_pairs) <= int(
        acceptance["max_internal_near_duplicate_pairs"]
    )
    assert len(involved_dominance) <= int(
        acceptance["max_involved_dominance_relations"]
    )
    print(
        "CHALLENGE_RECIPE_PILOT_REBALANCE_SELF_CHECK_PASS "
        f"recipes={len(pilot_ids)} exact_collisions={len(exact_collisions)} "
        f"internal_near_pairs={len(internal_near_pairs)} "
        f"dominance={len(involved_dominance)}"
    )


if __name__ == "__main__":
    main()
