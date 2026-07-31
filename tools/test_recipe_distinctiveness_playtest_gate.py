#!/usr/bin/env python3
"""Self-check PENDING, GO, NO-GO, and anti-fabrication behavior."""

from __future__ import annotations

import copy

from evaluate_recipe_distinctiveness_playtest import (
    DEFAULT_INPUT,
    DEFAULT_PILOT,
    evaluate,
    load_json,
)


def completed_fixture() -> tuple[dict, dict]:
    data = load_json(DEFAULT_INPUT)
    pilot = load_json(DEFAULT_PILOT)
    for session in data["sessions"]:
        session.update(
            {
                "status": "completed",
                "participant_id": f"player-{session['id']}",
                "human_observer": "observer",
                "started_at": "2026-07-31T10:00:00+08:00",
                "completed_at": "2026-07-31T10:20:00+08:00",
                "win": True,
                "failure_reason": "",
                "player_can_explain_group_differences": True,
                "group_spatial_tradeoff_observed": True,
                "dominant_choice_observed": False,
                "dominant_recipe_id": "",
                "unexpected_interaction_observed": False,
                "observer_notes": "controlled fixture",
            }
        )
        context = session["controlled_context"]
        context.update(
            {
                "route_id": f"route-{session['group_id']}",
                "encounter_id": f"boss-{session['group_id']}",
                "supply_budget": 16,
                "upgrade_ids": ["always_fresh"],
                "menu_recipe_ids": sorted(
                    session["recipe_observations"].keys()
                ),
            }
        )
        for observation in session["recipe_observations"].values():
            observation.update(
                {
                    "available_to_select": True,
                    "selected": True,
                    "copies_placed": 1,
                    "first_sale_ms": 3000,
                    "total_sales": 2,
                    "total_satisfaction": 20,
                    "remaining_stock": 1,
                    "role_understood": True,
                    "role_description": "distinct role",
                    "spatial_tradeoff_observed": True,
                    "selection_or_rejection_reason": "tested this role",
                }
            )
    return data, pilot


def main() -> int:
    pending = load_json(DEFAULT_INPUT)
    pilot = load_json(DEFAULT_PILOT)
    assert evaluate(pending, pilot)["status"] == "PENDING"

    passing, pilot = completed_fixture()
    assert evaluate(passing, pilot)["status"] == "GO"

    dominant = copy.deepcopy(passing)
    dominant["sessions"][0]["dominant_choice_observed"] = True
    dominant["sessions"][0]["dominant_recipe_id"] = next(
        iter(dominant["sessions"][0]["recipe_observations"])
    )
    assert evaluate(dominant, pilot)["status"] == "NO_GO"

    context_drift = copy.deepcopy(passing)
    context_drift["sessions"][1]["controlled_context"]["supply_budget"] = 18
    assert evaluate(context_drift, pilot)["status"] == "NO_GO"

    fabricated = copy.deepcopy(passing)
    fabricated["sessions"][0]["human_observer"] = ""
    try:
        evaluate(fabricated, pilot)
    except ValueError:
        pass
    else:
        raise AssertionError(
            "completed records without a human observer must be rejected"
        )
    print(
        "RECIPE_DISTINCTIVENESS_PLAYTEST_SELF_CHECK_PASS "
        "states=PENDING,GO,NO_GO"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
