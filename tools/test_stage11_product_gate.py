#!/usr/bin/env python3
"""Self-check pending, GO, NO-GO, and anti-fabrication gate behavior."""

from __future__ import annotations

import copy

from evaluate_stage11_product_gate import evaluate, load_results, DEFAULT_INPUT, ROUTES


def completed_fixture() -> dict:
    data = load_results(DEFAULT_INPUT)
    for item in data["participants"]:
        item.update(
            {
                "status": "completed",
                "human_observer": "observer",
                "started_at": "2026-07-30T10:00:00+08:00",
                "completed_at": "2026-07-30T11:00:00+08:00",
                "first_menu_edit_reason": "route adaptation",
                "route_menu_change_counts": {"standard_short_chain": 1},
                "failure_attribution_correct": 1,
                "failure_attribution_total": 1,
                "failure_adjustment_success": True,
                "rearranges_after_upgrade": 1,
                "research_nodes_purchased": 2,
                "research_nodes_used_within_three_runs": 2,
                "research_planning_observed": True,
                "research_wait_too_long": False,
                "universal_menu_dominance_observed": False,
                "sorting_only_by_satisfaction_observed": False,
                "research_tree_collection_only_observed": False,
                "unlocked_recipe_long_term_unused_observed": False,
                "menu_edit_repetitive_labor_observed": False,
            }
        )
        item["route_builds"] = {
            route: [f"{route}-build-a", f"{route}-build-b"] for route in ROUTES
        }
        if item["cohort"] == "new":
            item.update(
                {
                    "two_directions_seconds": 90,
                    "three_directions_seconds": 150,
                    "identified_direction_count": 2,
                    "independent_research_and_menu": True,
                }
            )
        else:
            item["mid_late_non_numeric_progression"] = True
        if item["cohort"] == "late":
            item["endless_highest_floor"] = 12
            item["endless_active_build_changes"] = 2
            item["endless_restart_willingness"] = True
            item["late_recipe_full_replacement_observed"] = False
            item["endless_numeric_only_observed"] = False
    return data


def main() -> int:
    pending = load_results(DEFAULT_INPUT)
    assert evaluate(pending)["status"] == "PENDING"
    passing = completed_fixture()
    assert evaluate(passing)["status"] == "GO"
    failing = copy.deepcopy(passing)
    failing["participants"][0]["universal_menu_dominance_observed"] = True
    assert evaluate(failing)["status"] == "NO_GO"
    fabricated = copy.deepcopy(passing)
    fabricated["participants"][0]["human_observer"] = ""
    try:
        evaluate(fabricated)
    except ValueError:
        pass
    else:
        raise AssertionError("completed records without a human observer must be rejected")
    print("STAGE11_PRODUCT_GATE_SELF_CHECK_PASS states=PENDING,GO,NO_GO")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
