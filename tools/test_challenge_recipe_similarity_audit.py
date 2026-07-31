#!/usr/bin/env python3
"""Self-check the challenge recipe similarity audit rules."""

from __future__ import annotations

from audit_challenge_recipe_similarity import (
    RecipeRecord,
    dominance_advantages,
    exact_duplicate_clusters,
    normalized_shape,
    select_pilot_clusters,
    similarity_score,
)


def record(
    recipe_id: str,
    *,
    shape: tuple[tuple[int, int], ...] = ((0, 0), (0, 1)),
    roles: tuple[str, ...] = ("tempo",),
    tags: tuple[str, ...] = ("fast",),
    rotatable: bool = True,
    cost: int = 3,
    copies: int = 2,
    stock: int = 4,
    cycle: int = 2000,
    satisfaction: int = 8,
) -> RecipeRecord:
    return RecipeRecord(
        recipe_id=recipe_id,
        display_name=recipe_id,
        branch_id="test",
        tier=1,
        batch="test",
        roles=roles,
        tags=tags,
        shape=normalized_shape(shape, rotatable),
        rotatable=rotatable,
        supply_cost=cost,
        copy_limit=copies,
        virtual_stock=stock,
        cycle_ms=cycle,
        satisfaction=satisfaction,
    )


def main() -> None:
    vertical = normalized_shape(((0, 0), (0, 1)), True)
    horizontal = normalized_shape(((0, 0), (1, 0)), True)
    assert vertical == horizontal
    assert normalized_shape(((0, 0), (0, 1)), False) != normalized_shape(
        ((0, 0), (1, 0)),
        False,
    )

    first = record("first")
    rotated_duplicate = record(
        "rotated_duplicate",
        shape=((0, 0), (1, 0)),
    )
    clusters = exact_duplicate_clusters(
        {
            first.recipe_id: first,
            rotated_duplicate.recipe_id: rotated_duplicate,
        }
    )
    assert len(clusters) == 1
    assert [value.recipe_id for value in clusters[0]] == [
        "first",
        "rotated_duplicate",
    ]
    assert similarity_score(first, rotated_duplicate) == 100.0

    dominant = record(
        "dominant",
        tags=("fast", "refreshing"),
        cost=2,
        copies=3,
        stock=5,
        cycle=1500,
        satisfaction=9,
    )
    dominated = record("dominated")
    assert dominance_advantages(dominant, dominated) == [
        "lower_cost",
        "higher_copy_limit",
        "higher_stock",
        "faster_cycle",
        "higher_satisfaction",
        "tag_superset",
    ]
    assert dominance_advantages(dominated, dominant) == []

    different_shape = record(
        "different_shape",
        shape=((0, 0), (1, 0), (1, 1)),
        cost=1,
        copies=4,
        stock=6,
        cycle=1000,
        satisfaction=12,
    )
    assert dominance_advantages(different_shape, dominated) == []

    pilot_clusters = [
        [record(f"large_{index}") for index in range(4)],
        [record(f"medium_a_{index}") for index in range(3)],
        [record(f"medium_b_{index}") for index in range(3)],
        [record(f"small_{index}") for index in range(2)],
    ]
    selected_indexes, selected_ids = select_pilot_clusters(pilot_clusters)
    assert selected_indexes == [0, 1, 2, 3]
    assert len(selected_ids) == 12
    print("CHALLENGE_RECIPE_SIMILARITY_AUDIT_SELF_CHECK_PASS")


if __name__ == "__main__":
    main()
