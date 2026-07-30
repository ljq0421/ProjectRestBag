#!/usr/bin/env python3
"""Evaluate Stage 11 human playtest results without inventing observations."""

from __future__ import annotations

import argparse
import json
import sys
from collections import Counter
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_INPUT = ROOT / "doc/challenge/stage11_playtest_results.json"
DEFAULT_OUTPUT = ROOT / "doc/challenge/stage11_product_gate.md"
EXPECTED_IDS = [f"P{index:02d}" for index in range(1, 7)]
EXPECTED_COHORTS = {"new": 2, "mid": 2, "late": 2}
ROUTES = [
    "standard_short_chain",
    "flavor_texture_route",
    "grand_composition_route",
]


def load_results(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        value = json.load(handle)
    if not isinstance(value, dict):
        raise ValueError("results root must be an object")
    return value


def validate_results(data: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    if data.get("schema_version") != 1:
        errors.append("schema_version must equal 1")
    participants = data.get("participants")
    if not isinstance(participants, list):
        return errors + ["participants must be an array"]
    ids = [str(item.get("id", "")) for item in participants if isinstance(item, dict)]
    if sorted(ids) != EXPECTED_IDS:
        errors.append("participants must contain P01 through P06 exactly once")
    cohorts = Counter(
        item.get("cohort") for item in participants if isinstance(item, dict)
    )
    if cohorts != Counter(EXPECTED_COHORTS):
        errors.append("participants must contain two new, two mid, and two late players")
    for item in participants:
        if not isinstance(item, dict):
            errors.append("each participant must be an object")
            continue
        participant_id = str(item.get("id", "?"))
        if item.get("status") not in {"pending", "completed"}:
            errors.append(f"{participant_id}.status must be pending or completed")
        if item.get("status") == "completed":
            for field in ("human_observer", "started_at", "completed_at"):
                if not str(item.get(field, "")).strip():
                    errors.append(f"{participant_id}.{field} is required when completed")
            for field in (
                "failure_adjustment_success",
                "universal_menu_dominance_observed",
                "sorting_only_by_satisfaction_observed",
                "research_tree_collection_only_observed",
                "unlocked_recipe_long_term_unused_observed",
                "menu_edit_repetitive_labor_observed",
            ):
                if not isinstance(item.get(field), bool):
                    errors.append(f"{participant_id}.{field} must be boolean when completed")
            if not str(item.get("first_menu_edit_reason", "")).strip():
                errors.append(
                    f"{participant_id}.first_menu_edit_reason is required when completed"
                )
            if not isinstance(item.get("route_menu_change_counts"), dict):
                errors.append(
                    f"{participant_id}.route_menu_change_counts must be an object"
                )
            for field in (
                "failure_attribution_correct",
                "failure_attribution_total",
                "rearranges_after_upgrade",
                "research_nodes_purchased",
                "research_nodes_used_within_three_runs",
            ):
                value = item.get(field)
                if not isinstance(value, int) or isinstance(value, bool) or value < 0:
                    errors.append(
                        f"{participant_id}.{field} must be a non-negative integer"
                    )
            correct = item.get("failure_attribution_correct")
            total = item.get("failure_attribution_total")
            if (
                isinstance(correct, int)
                and not isinstance(correct, bool)
                and isinstance(total, int)
                and not isinstance(total, bool)
                and correct > total
            ):
                errors.append(
                    f"{participant_id}.failure_attribution_correct exceeds total"
                )
            used = item.get("research_nodes_used_within_three_runs")
            purchased = item.get("research_nodes_purchased")
            if (
                isinstance(used, int)
                and not isinstance(used, bool)
                and isinstance(purchased, int)
                and not isinstance(purchased, bool)
                and used > purchased
            ):
                errors.append(
                    f"{participant_id}.research usage exceeds purchased nodes"
                )
            for field in ("research_planning_observed", "research_wait_too_long"):
                if not isinstance(item.get(field), bool):
                    errors.append(f"{participant_id}.{field} must be boolean when completed")
            if not isinstance(item.get("useless_recipe_feedback"), list):
                errors.append(f"{participant_id}.useless_recipe_feedback must be an array")
            if item.get("cohort") == "new":
                for field in (
                    "two_directions_seconds",
                    "three_directions_seconds",
                    "identified_direction_count",
                ):
                    value = item.get(field)
                    if (
                        not isinstance(value, (int, float))
                        or isinstance(value, bool)
                        or value < 0
                    ):
                        errors.append(
                            f"{participant_id}.{field} must be a non-negative number"
                        )
                if not isinstance(item.get("independent_research_and_menu"), bool):
                    errors.append(
                        f"{participant_id}.independent_research_and_menu must be boolean"
                    )
            if item.get("cohort") in {"mid", "late"} and not isinstance(
                item.get("mid_late_non_numeric_progression"), bool
            ):
                errors.append(
                    f"{participant_id}.mid_late_non_numeric_progression must be boolean"
                )
            if item.get("cohort") == "late":
                for field in (
                    "late_recipe_full_replacement_observed",
                    "endless_numeric_only_observed",
                ):
                    if not isinstance(item.get(field), bool):
                        errors.append(
                            f"{participant_id}.{field} must be boolean when completed"
                        )
                if (
                    not isinstance(item.get("endless_highest_floor"), int)
                    or isinstance(item.get("endless_highest_floor"), bool)
                    or int(item.get("endless_highest_floor", -1)) < 0
                ):
                    errors.append(
                        f"{participant_id}.endless_highest_floor must be non-negative"
                    )
                if (
                    not isinstance(item.get("endless_active_build_changes"), int)
                    or isinstance(item.get("endless_active_build_changes"), bool)
                    or int(item.get("endless_active_build_changes", -1)) < 0
                ):
                    errors.append(
                        f"{participant_id}.endless_active_build_changes must be non-negative"
                    )
                if not isinstance(item.get("endless_restart_willingness"), bool):
                    errors.append(
                        f"{participant_id}.endless_restart_willingness must be boolean"
                    )
        route_builds = item.get("route_builds")
        if not isinstance(route_builds, dict):
            errors.append(f"{participant_id}.route_builds must be an object")
        elif any(not isinstance(route_builds.get(route), list) for route in ROUTES):
            errors.append(f"{participant_id}.route_builds must list all three routes")
    return errors


def _criterion(name: str, state: str, detail: str) -> dict[str, str]:
    return {"name": name, "state": state, "detail": detail}


def _state(ready: bool, passed: bool) -> str:
    if not ready:
        return "PENDING"
    return "PASS" if passed else "FAIL"


def evaluate(data: dict[str, Any]) -> dict[str, Any]:
    errors = validate_results(data)
    if errors:
        raise ValueError("\n".join(errors))
    criteria_config = data.get("criteria", {})
    participants: list[dict[str, Any]] = data["participants"]
    completed = [item for item in participants if item["status"] == "completed"]
    new_players = [item for item in completed if item["cohort"] == "new"]
    mid_late = [item for item in completed if item["cohort"] in {"mid", "late"}]
    late_players = [item for item in completed if item["cohort"] == "late"]

    max_seconds = int(criteria_config.get("new_player_direction_seconds_max", 120))
    min_directions = int(criteria_config.get("new_player_direction_count_min", 2))
    new_direction_ready = len(new_players) == EXPECTED_COHORTS["new"] and all(
        item.get("two_directions_seconds") is not None
        and item.get("identified_direction_count") is not None
        for item in new_players
    )
    new_direction_passed = new_direction_ready and all(
        float(item["two_directions_seconds"]) <= max_seconds
        and int(item["identified_direction_count"]) >= min_directions
        for item in new_players
    )

    independent_ready = len(new_players) == EXPECTED_COHORTS["new"] and all(
        isinstance(item.get("independent_research_and_menu"), bool)
        for item in new_players
    )
    independent_passed = independent_ready and all(
        item["independent_research_and_menu"] for item in new_players
    )

    research_purchased = sum(
        int(item.get("research_nodes_purchased", 0)) for item in completed
    )
    research_used = sum(
        int(item.get("research_nodes_used_within_three_runs", 0))
        for item in completed
    )
    research_rate = research_used / research_purchased if research_purchased else 0.0
    research_ready = len(completed) == 6 and research_purchased > 0
    research_passed = (
        research_ready
        and research_rate >= float(criteria_config.get("research_usage_rate_min", 0.7))
    )

    builds_by_route: dict[str, set[str]] = {route: set() for route in ROUTES}
    for item in completed:
        for route in ROUTES:
            builds_by_route[route].update(
                str(build).strip()
                for build in item["route_builds"][route]
                if str(build).strip()
            )
    min_builds = int(criteria_config.get("distinct_builds_per_route_min", 2))
    builds_ready = len(completed) == 6
    builds_passed = builds_ready and all(
        len(builds_by_route[route]) >= min_builds for route in ROUTES
    )

    learning_ready = len(completed) == 6 and all(
        isinstance(item.get("failure_adjustment_success"), bool)
        for item in completed
    )
    learning_passed = learning_ready and all(
        item["failure_adjustment_success"] for item in completed
    )

    progression_ready = len(mid_late) == 4 and all(
        isinstance(item.get("mid_late_non_numeric_progression"), bool)
        for item in mid_late
    )
    progression_passed = progression_ready and all(
        item["mid_late_non_numeric_progression"] for item in mid_late
    )

    min_changes = int(criteria_config.get("endless_active_build_changes_min", 1))
    endless_ready = len(late_players) == 2 and all(
        item.get("endless_active_build_changes") is not None for item in late_players
    )
    endless_passed = endless_ready and all(
        int(item["endless_active_build_changes"]) >= min_changes
        for item in late_players
    )

    dominance_ready = len(completed) == 6 and all(
        isinstance(item.get("universal_menu_dominance_observed"), bool)
        for item in completed
    )
    dominance_passed = dominance_ready and not any(
        item["universal_menu_dominance_observed"] for item in completed
    )
    general_no_go_fields = (
        "sorting_only_by_satisfaction_observed",
        "research_tree_collection_only_observed",
        "unlocked_recipe_long_term_unused_observed",
        "menu_edit_repetitive_labor_observed",
    )
    no_go_ready = len(completed) == 6 and all(
        isinstance(item.get(field), bool)
        for item in completed
        for field in general_no_go_fields
    ) and all(
        isinstance(item.get(field), bool)
        for item in late_players
        for field in (
            "late_recipe_full_replacement_observed",
            "endless_numeric_only_observed",
        )
    )
    no_go_observed = any(
        item[field] for item in completed for field in general_no_go_fields
    ) or any(
        item[field]
        for item in late_players
        for field in (
            "late_recipe_full_replacement_observed",
            "endless_numeric_only_observed",
        )
    )

    criteria = [
        _criterion(
            "新玩家两分钟内识别至少两条构筑方向",
            _state(new_direction_ready, new_direction_passed),
            f"阈值 <= {max_seconds}s 且方向数 >= {min_directions}",
        ),
        _criterion(
            "首次标准流程后可独立研究并调整菜单",
            _state(independent_ready, independent_passed),
            f"已完成新玩家记录 {len(new_players)}/2",
        ),
        _criterion(
            "研究节点在三局内使用率至少 70%",
            _state(research_ready, research_passed),
            f"{research_used}/{research_purchased} = {research_rate:.1%}"
            if research_purchased
            else "尚无已完成的研究节点使用记录",
        ),
        _criterion(
            "每条路线至少出现两套可识别构筑",
            _state(builds_ready, builds_passed),
            ", ".join(f"{route}={len(builds_by_route[route])}" for route in ROUTES),
        ),
        _criterion(
            "玩家能解释失败并作出针对性调整",
            _state(learning_ready, learning_passed),
            f"已完成记录 {len(completed)}/6",
        ),
        _criterion(
            "中后期进展不只是数值上涨",
            _state(progression_ready, progression_passed),
            f"已完成中后期记录 {len(mid_late)}/4",
        ),
        _criterion(
            "无尽模式迫使后期玩家主动改变构筑",
            _state(endless_ready, endless_passed),
            f"阈值为每名后期玩家至少 {min_changes} 次主动调整",
        ),
        _criterion(
            "不存在全路线通用的统治菜单",
            _state(dominance_ready, dominance_passed),
            f"已完成记录 {len(completed)}/6",
        ),
        _criterion(
            "未触发路线图明确列出的产品 NO-GO 现象",
            _state(no_go_ready, no_go_ready and not no_go_observed),
            "检查满足力单排序、收藏清单化、长期闲置、重复劳动、全面替代和纯数值无尽",
        ),
    ]
    all_complete = len(completed) == 6
    if not all_complete:
        gate_status = "PENDING"
    elif all(item["state"] == "PASS" for item in criteria):
        gate_status = "GO"
    else:
        gate_status = "NO_GO"
    return {
        "status": gate_status,
        "completed_count": len(completed),
        "pending_ids": [item["id"] for item in participants if item["status"] != "completed"],
        "criteria": criteria,
    }


def render_report(data: dict[str, Any], evaluation: dict[str, Any]) -> str:
    lines = [
        "# 阶段 11 产品验收门",
        "",
        f"结论：**{evaluation['status']}**",
        "",
        (
            "本报告只接受六名真实玩家的观察记录。自动化 PASS、测试档启动成功或"
            "工程回归通过，都不能替代产品 GO。"
        ),
        "",
        f"- 已完成：{evaluation['completed_count']}/6",
        f"- 待完成：{', '.join(evaluation['pending_ids']) or '无'}",
        "",
        "## 验收项",
        "",
        "| 状态 | 验收项 | 证据摘要 |",
        "|---|---|---|",
    ]
    for item in evaluation["criteria"]:
        lines.append(f"| {item['state']} | {item['name']} | {item['detail']} |")
    lines.extend(
        [
            "",
            "## 玩家记录状态",
            "",
            "| 玩家 | 分组 | 状态 | 观察员 |",
            "|---|---|---|---|",
        ]
    )
    for item in data["participants"]:
        lines.append(
            f"| {item['id']} | {item['cohort']} | {item['status']} | "
            f"{item.get('human_observer') or '-'} |"
        )
    lines.extend(
        [
            "",
            "## 发布规则",
            "",
            "- `PENDING`：六人记录尚未完成，禁止宣称产品验收通过。",
            "- `NO_GO`：六人记录完成，但至少一项验收失败；先修正再复测。",
            "- `GO`：六人记录完成且所有验收项通过。",
            "",
        ]
    )
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, default=DEFAULT_INPUT)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--require-product-go", action="store_true")
    args = parser.parse_args()
    try:
        data = load_results(args.input)
        evaluation = evaluate(data)
        report = render_report(data, evaluation)
    except (OSError, json.JSONDecodeError, ValueError) as error:
        print(f"STAGE11_PRODUCT_GATE_INVALID: {error}", file=sys.stderr)
        return 2
    if args.check:
        current = args.output.read_text(encoding="utf-8") if args.output.exists() else ""
        if current != report:
            print("STAGE11_PRODUCT_GATE_STALE: regenerate the report", file=sys.stderr)
            return 1
    else:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(report, encoding="utf-8")
    print(
        "STAGE11_PRODUCT_GATE_%s completed=%d/6"
        % (evaluation["status"], evaluation["completed_count"])
    )
    if args.require_product_go and evaluation["status"] != "GO":
        return 3
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
