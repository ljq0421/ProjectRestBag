#!/usr/bin/env python3
"""Render objective Stage 11 telemetry without inferring human intent."""

from __future__ import annotations

import argparse
import json
import sys
from collections import Counter
from pathlib import Path
from typing import Any


def load_state(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        save = json.load(handle)
    state = save.get("meta", {}).get("stage11_playtest")
    if not isinstance(state, dict):
        raise ValueError(f"{path} has no stage11_playtest state")
    if not state.get("participant_id") or not isinstance(state.get("events"), list):
        raise ValueError(f"{path} contains invalid stage11_playtest state")
    return state


def summarize(state: dict[str, Any]) -> dict[str, Any]:
    events = state["events"]
    counts = Counter(str(event.get("type", "")) for event in events)
    routes = Counter()
    outcomes = Counter()
    failed_windows = Counter()
    for event in events:
        payload = event.get("payload", {})
        if not isinstance(payload, dict):
            continue
        if event.get("type") == "run_started":
            routes[str(payload.get("route_id", "unknown"))] += 1
        if event.get("type") == "battle_settled":
            outcomes[str(payload.get("outcome", "unknown"))] += 1
            for window_id in payload.get("failed_window_ids", []):
                failed_windows[str(window_id)] += 1
    research_purchased = 0
    research_used = 0
    for index, event in enumerate(events):
        if event.get("type") != "research_unlocked":
            continue
        payload = event.get("payload", {})
        unlocks = payload.get("granted_unlocks", []) if isinstance(payload, dict) else []
        recipe_ids = {
            str(unlock.get("id", ""))
            for unlock in unlocks
            if isinstance(unlock, dict) and unlock.get("type") == "recipe"
        }
        research_purchased += 1
        future_runs = [
            future
            for future in events[index + 1 :]
            if future.get("type") == "run_started"
        ][:3]
        if any(
            recipe_ids.intersection(
                str(recipe_id)
                for recipe_id in future.get("payload", {}).get("recipe_ids", [])
            )
            for future in future_runs
        ):
            research_used += 1
    started = int(state.get("started_unix_ms", 0))
    completed = int(state.get("completed_unix_ms", 0))
    duration_minutes = (
        max(0.0, (completed - started) / 60000.0) if started and completed else None
    )
    return {
        "participant_id": state["participant_id"],
        "cohort": state.get("cohort", ""),
        "status": state.get("status", ""),
        "duration_minutes": duration_minutes,
        "event_count": len(events),
        "event_counts": counts,
        "routes": routes,
        "outcomes": outcomes,
        "failed_windows": failed_windows,
        "research_purchased": research_purchased,
        "research_used": research_used,
    }


def _counter_text(counter: Counter[str]) -> str:
    return ", ".join(f"{key}={value}" for key, value in sorted(counter.items())) or "-"


def render(summaries: list[dict[str, Any]]) -> str:
    lines = [
        "# 阶段 11 客观遥测摘要",
        "",
        (
            "本文件只汇总游戏实际发生的事件，不推断玩家的理解、动机、失败归因或"
            "继续游玩的意愿；这些内容必须由观察员记录。"
        ),
        "",
        (
            "| 玩家 | 分组 | 遥测状态 | 时长(分钟) | 事件数 |"
            " 研究节点三局内使用 | 路线开局 | 战斗结果 |"
        ),
        "|---|---|---|---:|---:|---:|---|---|",
    ]
    for item in summaries:
        duration = (
            f"{item['duration_minutes']:.1f}"
            if item["duration_minutes"] is not None
            else "-"
        )
        lines.append(
            f"| {item['participant_id']} | {item['cohort']} | {item['status']} | "
            f"{duration} | {item['event_count']} | "
            f"{item['research_used']}/{item['research_purchased']} | "
            f"{_counter_text(item['routes'])} | {_counter_text(item['outcomes'])} |"
        )
    lines.extend(["", "## 每名玩家事件", ""])
    for item in summaries:
        lines.extend(
            [
                f"### {item['participant_id']}",
                "",
                f"- 事件：{_counter_text(item['event_counts'])}",
                f"- 失败窗口：{_counter_text(item['failed_windows'])}",
                "",
            ]
        )
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--save", action="append", type=Path, required=True)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    try:
        summaries = [summarize(load_state(path)) for path in args.save]
    except (OSError, json.JSONDecodeError, ValueError) as error:
        print(f"STAGE11_TELEMETRY_INVALID: {error}", file=sys.stderr)
        return 2
    participant_ids = [item["participant_id"] for item in summaries]
    if len(participant_ids) != len(set(participant_ids)):
        print("STAGE11_TELEMETRY_INVALID: duplicate participant_id", file=sys.stderr)
        return 2
    report = render(sorted(summaries, key=lambda item: item["participant_id"]))
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(report, encoding="utf-8")
    else:
        print(report)
    print(
        "STAGE11_TELEMETRY_SUMMARY_PASS participants=%d" % len(summaries),
        file=sys.stderr if not args.output else sys.stdout,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
