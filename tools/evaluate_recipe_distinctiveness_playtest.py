#!/usr/bin/env python3
"""Evaluate the confirmed 12-recipe human playtest without inventing evidence."""

from __future__ import annotations

import argparse
import json
import sys
from collections import defaultdict
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_INPUT = (
    ROOT / "doc/challenge/recipe_distinctiveness_playtest_results.json"
)
DEFAULT_PILOT = ROOT / "doc/challenge/recipe_distinctiveness_pilot.json"
DEFAULT_OUTPUT = (
    ROOT / "doc/challenge/recipe_distinctiveness_playtest_gate.md"
)
SESSION_GROUPS = {
    "S01": "exact-001",
    "S02": "exact-001",
    "S03": "exact-002",
    "S04": "exact-002",
    "S05": "exact-003",
    "S06": "exact-003",
    "S07": "exact-005",
    "S08": "exact-005",
}


def load_json(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        value = json.load(handle)
    if not isinstance(value, dict):
        raise ValueError(f"{path.name} root must be an object")
    return value


def pilot_groups(pilot: dict[str, Any]) -> dict[str, list[str]]:
    groups: dict[str, list[str]] = defaultdict(list)
    recipes = pilot.get("recipes", {})
    if not isinstance(recipes, dict):
        raise ValueError("pilot recipes must be an object")
    for recipe_id, entry in recipes.items():
        if not isinstance(entry, dict):
            raise ValueError(f"pilot recipe {recipe_id} must be an object")
        cluster_id = str(entry.get("baseline_cluster_id", ""))
        groups[cluster_id].append(str(recipe_id))
    return {
        cluster_id: sorted(recipe_ids)
        for cluster_id, recipe_ids in groups.items()
    }


def _is_non_negative_number(value: object) -> bool:
    return (
        isinstance(value, (int, float))
        and not isinstance(value, bool)
        and value >= 0
    )


def validate_results(
    data: dict[str, Any],
    pilot: dict[str, Any],
) -> list[str]:
    errors: list[str] = []
    if data.get("schema_version") != 1:
        errors.append("schema_version must equal 1")
    groups = pilot_groups(pilot)
    if set(groups) != set(SESSION_GROUPS.values()):
        errors.append(
            "pilot baseline clusters must be exact-001, exact-002, "
            "exact-003, and exact-005"
        )
    sessions = data.get("sessions")
    if not isinstance(sessions, list):
        return errors + ["sessions must be an array"]
    session_ids = [
        str(item.get("id", ""))
        for item in sessions
        if isinstance(item, dict)
    ]
    if sorted(session_ids) != sorted(SESSION_GROUPS):
        errors.append("sessions must contain S01 through S08 exactly once")

    for item in sessions:
        if not isinstance(item, dict):
            errors.append("each session must be an object")
            continue
        session_id = str(item.get("id", "?"))
        expected_group = SESSION_GROUPS.get(session_id)
        expected_recipe_ids = set(groups.get(expected_group or "", []))
        if str(item.get("group_id", "")) != expected_group:
            errors.append(
                f"{session_id}.group_id must equal {expected_group}"
            )
        status = item.get("status")
        if status not in {"pending", "completed"}:
            errors.append(
                f"{session_id}.status must be pending or completed"
            )
        if status != "completed":
            continue

        for field in (
            "participant_id",
            "human_observer",
            "started_at",
            "completed_at",
        ):
            if not str(item.get(field, "")).strip():
                errors.append(
                    f"{session_id}.{field} is required when completed"
                )

        context = item.get("controlled_context")
        if not isinstance(context, dict):
            errors.append(
                f"{session_id}.controlled_context must be an object"
            )
        else:
            for field in ("route_id", "encounter_id"):
                if not str(context.get(field, "")).strip():
                    errors.append(
                        f"{session_id}.controlled_context.{field} is required"
                    )
            if not _is_non_negative_number(context.get("supply_budget")):
                errors.append(
                    f"{session_id}.controlled_context.supply_budget "
                    "must be non-negative"
                )
            for field in ("upgrade_ids", "menu_recipe_ids"):
                if not isinstance(context.get(field), list):
                    errors.append(
                        f"{session_id}.controlled_context.{field} "
                        "must be an array"
                    )
            menu_ids = {
                str(value) for value in context.get("menu_recipe_ids", [])
            }
            if not expected_recipe_ids.issubset(menu_ids):
                errors.append(
                    f"{session_id}.controlled_context.menu_recipe_ids must "
                    "include every recipe in the tested group"
                )

        observations = item.get("recipe_observations")
        if not isinstance(observations, dict):
            errors.append(
                f"{session_id}.recipe_observations must be an object"
            )
        elif set(observations) != expected_recipe_ids:
            errors.append(
                f"{session_id}.recipe_observations must contain exactly "
                f"{sorted(expected_recipe_ids)}"
            )
        else:
            for recipe_id, observation in observations.items():
                prefix = f"{session_id}.{recipe_id}"
                if not isinstance(observation, dict):
                    errors.append(f"{prefix} observation must be an object")
                    continue
                for field in (
                    "available_to_select",
                    "selected",
                    "role_understood",
                    "spatial_tradeoff_observed",
                ):
                    if not isinstance(observation.get(field), bool):
                        errors.append(
                            f"{prefix}.{field} must be boolean when completed"
                        )
                if not str(
                    observation.get("selection_or_rejection_reason", "")
                ).strip():
                    errors.append(
                        f"{prefix}.selection_or_rejection_reason is required"
                    )
                if observation.get("role_understood") and not str(
                    observation.get("role_description", "")
                ).strip():
                    errors.append(
                        f"{prefix}.role_description is required when "
                        "role_understood is true"
                    )
                if observation.get("selected"):
                    if observation.get("available_to_select") is not True:
                        errors.append(
                            f"{prefix} cannot be selected when unavailable"
                        )
                    copies = observation.get("copies_placed")
                    if (
                        not isinstance(copies, int)
                        or isinstance(copies, bool)
                        or copies <= 0
                    ):
                        errors.append(
                            f"{prefix}.copies_placed must be positive "
                            "when selected"
                        )
                    for field in (
                        "first_sale_ms",
                        "total_sales",
                        "total_satisfaction",
                        "remaining_stock",
                    ):
                        if not _is_non_negative_number(
                            observation.get(field)
                        ):
                            errors.append(
                                f"{prefix}.{field} must be non-negative "
                                "when selected"
                            )

        for field in (
            "win",
            "player_can_explain_group_differences",
            "group_spatial_tradeoff_observed",
            "dominant_choice_observed",
            "unexpected_interaction_observed",
        ):
            if not isinstance(item.get(field), bool):
                errors.append(
                    f"{session_id}.{field} must be boolean when completed"
                )
        dominant_id = str(item.get("dominant_recipe_id", ""))
        if item.get("dominant_choice_observed"):
            if dominant_id not in expected_recipe_ids:
                errors.append(
                    f"{session_id}.dominant_recipe_id must identify a "
                    "recipe in the tested group"
                )
        elif dominant_id:
            errors.append(
                f"{session_id}.dominant_recipe_id must be empty when no "
                "dominant choice was observed"
            )
        if not item.get("win") and not str(
            item.get("failure_reason", "")
        ).strip():
            errors.append(
                f"{session_id}.failure_reason is required after a loss"
            )
    return errors


def _criterion(name: str, ready: bool, passed: bool, detail: str) -> dict[str, str]:
    return {
        "name": name,
        "state": "PENDING" if not ready else "PASS" if passed else "FAIL",
        "detail": detail,
    }


def _context_signature(session: dict[str, Any]) -> tuple[Any, ...]:
    context = session["controlled_context"]
    return (
        str(context["route_id"]),
        str(context["encounter_id"]),
        int(context["supply_budget"]),
        tuple(sorted(str(value) for value in context["upgrade_ids"])),
        tuple(sorted(str(value) for value in context["menu_recipe_ids"])),
    )


def evaluate(
    data: dict[str, Any],
    pilot: dict[str, Any],
) -> dict[str, Any]:
    errors = validate_results(data, pilot)
    if errors:
        raise ValueError("\n".join(errors))
    groups = pilot_groups(pilot)
    sessions: list[dict[str, Any]] = data["sessions"]
    completed = [item for item in sessions if item["status"] == "completed"]
    all_complete = len(completed) == len(SESSION_GROUPS)
    completed_by_group: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for item in completed:
        completed_by_group[str(item["group_id"])].append(item)

    controlled_ready = all_complete
    controlled_passed = controlled_ready and all(
        len(group_sessions) == 2
        and len({_context_signature(item) for item in group_sessions}) == 1
        for group_sessions in completed_by_group.values()
    )

    availability: dict[str, int] = defaultdict(int)
    selections: dict[str, int] = defaultdict(int)
    understood: dict[str, int] = defaultdict(int)
    for item in completed:
        for recipe_id, observation in item["recipe_observations"].items():
            availability[recipe_id] += int(
                observation["available_to_select"]
            )
            selections[recipe_id] += int(observation["selected"])
            understood[recipe_id] += int(observation["role_understood"])

    pilot_ids = sorted(
        recipe_id for recipe_ids in groups.values() for recipe_id in recipe_ids
    )
    available_passed = all_complete and all(
        availability[recipe_id] == 2 for recipe_id in pilot_ids
    )
    selection_passed = all_complete and all(
        selections[recipe_id] >= 1 for recipe_id in pilot_ids
    )
    role_passed = all_complete and all(
        understood[recipe_id] >= 1 for recipe_id in pilot_ids
    ) and all(
        item["player_can_explain_group_differences"] for item in completed
    )
    spatial_passed = all_complete and all(
        any(item["group_spatial_tradeoff_observed"] for item in group_sessions)
        for group_sessions in completed_by_group.values()
    )
    dominance_passed = all_complete and not any(
        item["dominant_choice_observed"] for item in completed
    )
    interaction_passed = all_complete and not any(
        item["unexpected_interaction_observed"] for item in completed
    )

    criteria = [
        _criterion(
            "每组两局使用相同对照条件",
            controlled_ready,
            controlled_passed,
            f"已完成 {len(completed)}/8 局",
        ),
        _criterion(
            "12 个试点在两局中均可被选择",
            all_complete,
            available_passed,
            (
                f"两次可选覆盖 "
                f"{sum(count == 2 for count in availability.values())}/12"
            ),
        ),
        _criterion(
            "12 个试点均至少真实上阵一次",
            all_complete,
            selection_passed,
            f"已上阵覆盖 {sum(count >= 1 for count in selections.values())}/12",
        ),
        _criterion(
            "玩家能解释同组配方的不同定位",
            all_complete,
            role_passed,
            f"定位理解覆盖 {sum(count >= 1 for count in understood.values())}/12",
        ),
        _criterion(
            "四组都观察到真实空间取舍",
            all_complete,
            spatial_passed,
            (
                "已观察 "
                f"{sum(any(item['group_spatial_tradeoff_observed'] for item in values) for values in completed_by_group.values())}/4 组"
            ),
        ),
        _criterion(
            "没有明显统治同组选择",
            all_complete,
            dominance_passed,
            (
                f"统治选择记录 "
                f"{sum(item['dominant_choice_observed'] for item in completed)}"
            ),
        ),
        _criterion(
            "没有异常标签或升级组合",
            all_complete,
            interaction_passed,
            (
                f"异常交互记录 "
                f"{sum(item['unexpected_interaction_observed'] for item in completed)}"
            ),
        ),
    ]
    if not all_complete:
        status = "PENDING"
    elif all(item["state"] == "PASS" for item in criteria):
        status = "GO"
    else:
        status = "NO_GO"
    return {
        "status": status,
        "completed_count": len(completed),
        "pending_ids": [
            item["id"] for item in sessions if item["status"] != "completed"
        ],
        "criteria": criteria,
        "recipe_metrics": {
            recipe_id: {
                "available_sessions": availability[recipe_id],
                "selected_sessions": selections[recipe_id],
                "role_understood_sessions": understood[recipe_id],
            }
            for recipe_id in pilot_ids
        },
    }


def render_report(
    data: dict[str, Any],
    pilot: dict[str, Any],
    evaluation: dict[str, Any],
) -> str:
    groups = pilot_groups(pilot)
    lines = [
        "# 首批配方差异化真人试玩验收门",
        "",
        f"结论：**{evaluation['status']}**",
        "",
        (
            "本报告只接受真实玩家与观察员填写的八局对照记录。"
            "自动化审计、平衡模拟和 Godot 自检不能替代产品 GO。"
        ),
        "",
        f"- 已完成：{evaluation['completed_count']}/8",
        f"- 待完成：{', '.join(evaluation['pending_ids']) or '无'}",
        "",
        "## 验收项",
        "",
        "| 状态 | 验收项 | 证据摘要 |",
        "| --- | --- | --- |",
    ]
    for item in evaluation["criteria"]:
        lines.append(
            f"| {item['state']} | {item['name']} | {item['detail']} |"
        )

    lines.extend(
        [
            "",
            "## 配方覆盖",
            "",
            "| 原重复簇 | 配方 | 可选局数 | 上阵局数 | 理解局数 |",
            "| --- | --- | ---: | ---: | ---: |",
        ]
    )
    metrics = evaluation["recipe_metrics"]
    for group_id, recipe_ids in groups.items():
        for recipe_id in recipe_ids:
            recipe_name = pilot["recipes"][recipe_id].get(
                "design_role", recipe_id
            )
            values = metrics[recipe_id]
            lines.append(
                f"| `{group_id}` | `{recipe_id}` · {recipe_name} | "
                f"{values['available_sessions']} | "
                f"{values['selected_sessions']} | "
                f"{values['role_understood_sessions']} |"
            )

    lines.extend(
        [
            "",
            "## 对照局状态",
            "",
            "| 记录 | 原重复簇 | 状态 | 玩家 | 观察员 |",
            "| --- | --- | --- | --- | --- |",
        ]
    )
    for item in data["sessions"]:
        lines.append(
            f"| {item['id']} | `{item['group_id']}` | {item['status']} | "
            f"{item.get('participant_id') or '-'} | "
            f"{item.get('human_observer') or '-'} |"
        )
    lines.extend(
        [
            "",
            "## 判定规则",
            "",
            "- `PENDING`：八局记录尚未完成，不能确认本批配方。",
            "- `NO_GO`：记录完整但至少一项失败；只调整有证据的问题后复测。",
            "- `GO`：八局记录完整且七项验收全部通过。",
            "",
        ]
    )
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, default=DEFAULT_INPUT)
    parser.add_argument("--pilot", type=Path, default=DEFAULT_PILOT)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--require-product-go", action="store_true")
    args = parser.parse_args()
    try:
        data = load_json(args.input)
        pilot = load_json(args.pilot)
        evaluation = evaluate(data, pilot)
        report = render_report(data, pilot, evaluation)
    except (OSError, json.JSONDecodeError, ValueError) as error:
        print(
            f"RECIPE_DISTINCTIVENESS_PLAYTEST_INVALID: {error}",
            file=sys.stderr,
        )
        return 2
    if args.check:
        current = (
            args.output.read_text(encoding="utf-8")
            if args.output.exists()
            else ""
        )
        if current != report:
            print(
                "RECIPE_DISTINCTIVENESS_PLAYTEST_STALE: regenerate report",
                file=sys.stderr,
            )
            return 1
    else:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(report, encoding="utf-8")
    print(
        "RECIPE_DISTINCTIVENESS_PLAYTEST_%s completed=%d/8"
        % (evaluation["status"], evaluation["completed_count"])
    )
    if args.require_product_go and evaluation["status"] != "GO":
        return 3
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
