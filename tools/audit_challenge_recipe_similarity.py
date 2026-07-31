#!/usr/bin/env python3
"""Audit challenge recipes for duplicate identity and conservative dominance."""

from __future__ import annotations

import argparse
import json
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable


ROOT = Path(__file__).resolve().parents[1]
RUNTIME_PATH = ROOT / "doc/challenge/challenge_recipes.json"
MANIFEST_PATH = ROOT / "doc/challenge/recipe_progression_manifest.json"
JSON_OUTPUT_PATH = ROOT / "doc/challenge/recipe_similarity_audit.json"
MARKDOWN_OUTPUT_PATH = ROOT / "doc/challenge/recipe_similarity_audit.md"
PILOT_PATH = ROOT / "doc/challenge/recipe_distinctiveness_pilot.json"

SCHEMA_VERSION = 2
NEAR_DUPLICATE_THRESHOLD = 85.0
MARKDOWN_PAIR_LIMIT = 40
PILOT_MIN = 10
PILOT_MAX = 12


@dataclass(frozen=True)
class RecipeRecord:
    recipe_id: str
    display_name: str
    branch_id: str
    tier: int
    batch: str
    roles: tuple[str, ...]
    tags: tuple[str, ...]
    shape: tuple[tuple[int, int], ...]
    rotatable: bool
    supply_cost: int
    copy_limit: int
    virtual_stock: int
    cycle_ms: int
    satisfaction: int

    @property
    def cell_count(self) -> int:
        return len(self.shape)

    @property
    def exact_signature(self) -> tuple[Any, ...]:
        return (
            self.roles,
            self.tags,
            self.shape,
            self.rotatable,
            self.supply_cost,
            self.copy_limit,
            self.virtual_stock,
            self.cycle_ms,
            self.satisfaction,
        )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--runtime", type=Path, default=RUNTIME_PATH)
    parser.add_argument("--manifest", type=Path, default=MANIFEST_PATH)
    parser.add_argument("--pilot", type=Path, default=PILOT_PATH)
    parser.add_argument("--json-output", type=Path, default=JSON_OUTPUT_PATH)
    parser.add_argument("--markdown-output", type=Path, default=MARKDOWN_OUTPUT_PATH)
    return parser.parse_args()


def read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8-sig"))


def normalized_shape(
    cells: Iterable[Iterable[int]],
    rotatable: bool,
) -> tuple[tuple[int, int], ...]:
    points = tuple((int(cell[0]), int(cell[1])) for cell in cells)
    if not points:
        return ()

    def normalize(
        values: Iterable[tuple[int, int]],
    ) -> tuple[tuple[int, int], ...]:
        copied = tuple(values)
        min_x = min(point[0] for point in copied)
        min_y = min(point[1] for point in copied)
        return tuple(
            sorted((point[0] - min_x, point[1] - min_y) for point in copied)
        )

    candidates = [normalize(points)]
    if rotatable:
        rotated = points
        for _ in range(3):
            rotated = tuple((-point[1], point[0]) for point in rotated)
            candidates.append(normalize(rotated))
    return min(candidates)


def build_records(
    runtime: dict[str, Any],
    manifest: dict[str, Any],
) -> dict[str, RecipeRecord]:
    runtime_recipes = runtime.get("recipes", {})
    manifest_recipes = manifest.get("recipes", {})
    records: dict[str, RecipeRecord] = {}
    for recipe_id in sorted(runtime_recipes):
        recipe = runtime_recipes[recipe_id]
        entry = manifest_recipes.get(recipe_id, {})
        rotatable = bool(recipe.get("rotatable", False))
        records[recipe_id] = RecipeRecord(
            recipe_id=recipe_id,
            display_name=str(entry.get("display_name", recipe_id)),
            branch_id=str(entry.get("research_branch_id", "")),
            tier=int(entry.get("research_tier", 0)),
            batch=str(entry.get("migration_batch", "")),
            roles=tuple(sorted(str(value) for value in recipe.get("build_roles", []))),
            tags=tuple(sorted(str(value) for value in recipe.get("tags", []))),
            shape=normalized_shape(recipe.get("shape_cells", []), rotatable),
            rotatable=rotatable,
            supply_cost=int(recipe.get("supply_cost", 0)),
            copy_limit=int(recipe.get("copy_limit", 0)),
            virtual_stock=int(recipe.get("virtual_stock", 0)),
            cycle_ms=int(recipe.get("cycle_ms", 0)),
            satisfaction=int(recipe.get("satisfaction", 0)),
        )
    return records


def _jaccard(left: tuple[str, ...], right: tuple[str, ...]) -> float:
    left_set = set(left)
    right_set = set(right)
    union = left_set | right_set
    if not union:
        return 1.0
    return len(left_set & right_set) / len(union)


def _numeric_similarity(left: int, right: int) -> float:
    return 1.0 - abs(left - right) / max(1, abs(left), abs(right))


def similarity_score(left: RecipeRecord, right: RecipeRecord) -> float:
    shape_similarity = 1.0 if left.shape == right.shape else 0.0
    if shape_similarity == 0.0 and left.cell_count == right.cell_count:
        shape_similarity = 0.5
    score = (
        20.0 * _jaccard(left.roles, right.roles)
        + 20.0 * _jaccard(left.tags, right.tags)
        + 15.0 * shape_similarity
        + 10.0 * _numeric_similarity(left.supply_cost, right.supply_cost)
        + 5.0 * _numeric_similarity(left.copy_limit, right.copy_limit)
        + 5.0 * _numeric_similarity(left.virtual_stock, right.virtual_stock)
        + 10.0 * _numeric_similarity(left.cycle_ms, right.cycle_ms)
        + 10.0 * _numeric_similarity(left.satisfaction, right.satisfaction)
        + 5.0 * float(left.rotatable == right.rotatable)
    )
    return round(score, 2)


def exact_duplicate_clusters(
    records: dict[str, RecipeRecord],
) -> list[list[RecipeRecord]]:
    grouped: dict[tuple[Any, ...], list[RecipeRecord]] = defaultdict(list)
    for record in records.values():
        grouped[record.exact_signature].append(record)
    clusters = [
        sorted(group, key=lambda record: record.recipe_id)
        for group in grouped.values()
        if len(group) > 1
    ]
    return sorted(
        clusters,
        key=lambda group: (-len(group), tuple(record.recipe_id for record in group)),
    )


def near_duplicate_pairs(
    records: dict[str, RecipeRecord],
) -> list[dict[str, Any]]:
    ordered = [records[recipe_id] for recipe_id in sorted(records)]
    pairs: list[dict[str, Any]] = []
    for index, left in enumerate(ordered):
        for right in ordered[index + 1 :]:
            if left.exact_signature == right.exact_signature:
                continue
            score = similarity_score(left, right)
            if score < NEAR_DUPLICATE_THRESHOLD:
                continue
            pairs.append(
                {
                    "left_id": left.recipe_id,
                    "right_id": right.recipe_id,
                    "score": score,
                    "same_shape": left.shape == right.shape,
                    "same_roles": left.roles == right.roles,
                    "same_tags": left.tags == right.tags,
                }
            )
    return sorted(
        pairs,
        key=lambda pair: (
            -float(pair["score"]),
            str(pair["left_id"]),
            str(pair["right_id"]),
        ),
    )


def dominance_advantages(
    dominant: RecipeRecord,
    dominated: RecipeRecord,
) -> list[str]:
    if dominant.shape != dominated.shape:
        return []
    if dominant.rotatable != dominated.rotatable:
        return []
    if not set(dominant.roles).issuperset(dominated.roles):
        return []
    if not set(dominant.tags).issuperset(dominated.tags):
        return []
    no_worse = (
        dominant.supply_cost <= dominated.supply_cost
        and dominant.copy_limit >= dominated.copy_limit
        and dominant.virtual_stock >= dominated.virtual_stock
        and dominant.cycle_ms <= dominated.cycle_ms
        and dominant.satisfaction >= dominated.satisfaction
    )
    if not no_worse:
        return []

    advantages: list[str] = []
    if dominant.supply_cost < dominated.supply_cost:
        advantages.append("lower_cost")
    if dominant.copy_limit > dominated.copy_limit:
        advantages.append("higher_copy_limit")
    if dominant.virtual_stock > dominated.virtual_stock:
        advantages.append("higher_stock")
    if dominant.cycle_ms < dominated.cycle_ms:
        advantages.append("faster_cycle")
    if dominant.satisfaction > dominated.satisfaction:
        advantages.append("higher_satisfaction")
    if set(dominant.roles) > set(dominated.roles):
        advantages.append("role_superset")
    if set(dominant.tags) > set(dominated.tags):
        advantages.append("tag_superset")
    return advantages


def dominance_relations(
    records: dict[str, RecipeRecord],
) -> list[dict[str, Any]]:
    relations: list[dict[str, Any]] = []
    ordered = [records[recipe_id] for recipe_id in sorted(records)]
    for dominant in ordered:
        for dominated in ordered:
            if dominant.recipe_id == dominated.recipe_id:
                continue
            advantages = dominance_advantages(dominant, dominated)
            if not advantages:
                continue
            relations.append(
                {
                    "dominant_id": dominant.recipe_id,
                    "dominated_id": dominated.recipe_id,
                    "advantages": advantages,
                }
            )
    return sorted(
        relations,
        key=lambda relation: (
            str(relation["dominated_id"]),
            str(relation["dominant_id"]),
        ),
    )


def record_payload(record: RecipeRecord) -> dict[str, Any]:
    return {
        "recipe_id": record.recipe_id,
        "display_name": record.display_name,
        "branch_id": record.branch_id,
        "tier": record.tier,
        "batch": record.batch,
    }


def signature_payload(record: RecipeRecord) -> dict[str, Any]:
    return {
        "roles": list(record.roles),
        "tags": list(record.tags),
        "shape": [list(point) for point in record.shape],
        "rotatable": record.rotatable,
        "supply_cost": record.supply_cost,
        "copy_limit": record.copy_limit,
        "virtual_stock": record.virtual_stock,
        "cycle_ms": record.cycle_ms,
        "satisfaction": record.satisfaction,
    }


def select_pilot_clusters(
    clusters: list[list[RecipeRecord]],
) -> tuple[list[int], list[str]]:
    selected_cluster_indexes: list[int] = []
    selected_ids: list[str] = []
    for index, cluster in enumerate(clusters):
        cluster_ids = [record.recipe_id for record in cluster]
        if len(selected_ids) + len(cluster_ids) > PILOT_MAX:
            continue
        selected_cluster_indexes.append(index)
        selected_ids.extend(cluster_ids)
        if len(selected_ids) == PILOT_MAX:
            break
    return selected_cluster_indexes, selected_ids


def evaluate_confirmed_pilot(
    records: dict[str, RecipeRecord],
    clusters: list[list[RecipeRecord]],
    near_pairs: list[dict[str, Any]],
    relations: list[dict[str, Any]],
    pilot: dict[str, Any],
) -> dict[str, Any]:
    configured_recipes = pilot.get("recipes", {})
    pilot_ids = set(str(recipe_id) for recipe_id in configured_recipes)
    unknown_ids = sorted(pilot_ids - set(records))
    exact_collisions = [
        sorted(record.recipe_id for record in cluster)
        for cluster in clusters
        if any(record.recipe_id in pilot_ids for record in cluster)
    ]
    internal_near_pairs = [
        pair
        for pair in near_pairs
        if pair["left_id"] in pilot_ids and pair["right_id"] in pilot_ids
    ]
    external_near_pairs = [
        pair
        for pair in near_pairs
        if (pair["left_id"] in pilot_ids) != (pair["right_id"] in pilot_ids)
    ]
    involved_relations = [
        relation
        for relation in relations
        if relation["dominant_id"] in pilot_ids
        or relation["dominated_id"] in pilot_ids
    ]
    acceptance = pilot.get("acceptance", {})
    required_count = int(acceptance.get("recipe_count", 0))
    require_unique = bool(
        acceptance.get("require_global_exact_signature_uniqueness", False)
    )
    max_internal_near = int(
        acceptance.get("max_internal_near_duplicate_pairs", 0)
    )
    max_dominance = int(
        acceptance.get("max_involved_dominance_relations", 0)
    )
    passed = (
        not unknown_ids
        and len(pilot_ids) == required_count
        and (not require_unique or not exact_collisions)
        and len(internal_near_pairs) <= max_internal_near
        and len(involved_relations) <= max_dominance
    )
    recipe_payloads = []
    for recipe_id in configured_recipes:
        pilot_entry = configured_recipes[recipe_id]
        record = records.get(recipe_id)
        if record is None:
            continue
        recipe_payloads.append(
            {
                **record_payload(record),
                "baseline_cluster_id": str(
                    pilot_entry.get("baseline_cluster_id", "")
                ),
                "design_role": str(pilot_entry.get("design_role", "")),
                "tradeoff": str(pilot_entry.get("tradeoff", "")),
                "current_signature": signature_payload(record),
            }
        )
    return {
        "status": "pass" if passed else "fail",
        "configured_status": str(pilot.get("status", "")),
        "baseline_summary": dict(pilot.get("baseline_summary", {})),
        "recipe_count": len(pilot_ids),
        "unknown_recipe_ids": unknown_ids,
        "global_exact_collision_count": len(exact_collisions),
        "global_exact_collisions": exact_collisions,
        "internal_near_duplicate_pair_count": len(internal_near_pairs),
        "internal_near_duplicate_pairs": internal_near_pairs,
        "external_near_duplicate_pair_count": len(external_near_pairs),
        "external_near_duplicate_pairs": external_near_pairs,
        "involved_dominance_relation_count": len(involved_relations),
        "involved_dominance_relations": involved_relations,
        "acceptance": acceptance,
        "recipes": recipe_payloads,
    }


def build_audit(
    runtime: dict[str, Any],
    manifest: dict[str, Any],
    confirmed_pilot: dict[str, Any] | None = None,
) -> dict[str, Any]:
    records = build_records(runtime, manifest)
    clusters = exact_duplicate_clusters(records)
    near_pairs = near_duplicate_pairs(records)
    relations = dominance_relations(records)

    recipes_in_clusters = sum(len(cluster) for cluster in clusters)
    redundant_slots = sum(len(cluster) - 1 for cluster in clusters)
    dominated_ids = sorted(
        {str(relation["dominated_id"]) for relation in relations}
    )
    selected_cluster_indexes, pilot_ids = select_pilot_clusters(clusters)

    branch_counts: dict[str, int] = defaultdict(int)
    for record in records.values():
        branch_counts[record.branch_id] += 1

    cluster_payloads: list[dict[str, Any]] = []
    for index, cluster in enumerate(clusters):
        cluster_payloads.append(
            {
                "cluster_id": f"exact-{index + 1:03d}",
                "signature": signature_payload(cluster[0]),
                "recipes": [record_payload(record) for record in cluster],
            }
        )

    selected_cluster_ids = [
        cluster_payloads[index]["cluster_id"]
        for index in selected_cluster_indexes
    ]
    audit = {
        "schema_version": SCHEMA_VERSION,
        "source": {
            "runtime": "doc/challenge/challenge_recipes.json",
            "manifest": "doc/challenge/recipe_progression_manifest.json",
            "confirmed_pilot": (
                "doc/challenge/recipe_distinctiveness_pilot.json"
                if confirmed_pilot
                else ""
            ),
        },
        "rules": {
            "near_duplicate_threshold": NEAR_DUPLICATE_THRESHOLD,
            "shape_rotation_is_canonicalized": True,
            "dominance_requires_same_shape_and_rotation_semantics": True,
            "dominance_requires_role_and_tag_supersets": True,
        },
        "summary": {
            "recipe_count": len(records),
            "exact_signature_count": len(records) - redundant_slots,
            "exact_duplicate_cluster_count": len(clusters),
            "recipes_in_exact_duplicate_clusters": recipes_in_clusters,
            "redundant_recipe_slots": redundant_slots,
            "near_duplicate_pair_count": len(near_pairs),
            "full_dominance_relation_count": len(relations),
            "dominated_recipe_count": len(dominated_ids),
        },
        "branch_recipe_counts": dict(sorted(branch_counts.items())),
        "exact_duplicate_clusters": cluster_payloads,
        "near_duplicate_pairs": near_pairs,
        "dominance_relations": relations,
        "pilot_proposal": {
            "status": "proposal_only_no_balance_changes",
            "strategy": (
                "Take complete largest exact-duplicate clusters, without "
                "splitting a cluster, and fill toward the 12-recipe upper bound."
            ),
            "target_range": [PILOT_MIN, PILOT_MAX],
            "selected_cluster_ids": selected_cluster_ids,
            "recipe_ids": pilot_ids,
        },
        "limitations": [
            (
                "Similarity is a deterministic triage score, not a claim that "
                "two recipes feel identical to players."
            ),
            (
                "Dominance is intentionally conservative and ignores pairs "
                "with different canonical shapes or rotation semantics."
            ),
            (
                "Research timing, boss demand, upgrade availability, and human "
                "preference still require route simulation and playtests."
            ),
        ],
    }
    if confirmed_pilot:
        audit["confirmed_pilot_evaluation"] = evaluate_confirmed_pilot(
            records,
            clusters,
            near_pairs,
            relations,
            confirmed_pilot,
        )
    return audit


def _format_shape(shape: list[list[int]]) -> str:
    return " ".join(f"({point[0]},{point[1]})" for point in shape)


def render_markdown(audit: dict[str, Any]) -> str:
    summary = audit["summary"]
    lines = [
        "# 挑战配方相似度与全面支配审计",
        "",
        "由 `tools/audit_challenge_recipe_similarity.py` 生成。",
        "",
        "本报告用于持续分诊和验证人工重做结果；算法结果不能替代路线模拟与真人试玩。",
        "",
        "## 摘要",
        "",
        f"- 运行时配方：{summary['recipe_count']}",
        f"- 唯一精确战斗签名：{summary['exact_signature_count']}",
        (
            "- 完全重复簇："
            f"{summary['exact_duplicate_cluster_count']}"
        ),
        (
            "- 完全重复簇涉及配方："
            f"{summary['recipes_in_exact_duplicate_clusters']}"
        ),
        f"- 重复配方槽位：{summary['redundant_recipe_slots']}",
        (
            f"- 近似重复配对（分数 >= "
            f"{audit['rules']['near_duplicate_threshold']:.0f}): "
            f"{summary['near_duplicate_pair_count']}"
        ),
        (
            "- 保守全面支配关系："
            f"{summary['full_dominance_relation_count']}"
        ),
        f"- 被支配配方：{summary['dominated_recipe_count']}",
        "",
        "## 审计规则",
        "",
        "- 精确签名包含构筑角色、标签、标准形状、旋转语义、成本、复制上限、库存、周期和满足力。",
        "- 可旋转形状会在 0/90/180/270 度之间归一化，避免横竖方向制造虚假差异。",
        "- 近似重复分数只用于安排人工复核优先级，不直接证明玩家体感相同。",
        "- 全面支配要求形状和旋转语义相同，角色与标签为超集，全部战斗数值不差，且至少一项严格更优。",
        "",
        "## 研究分支覆盖",
        "",
        "| 分支 | 配方数 |",
        "| --- | ---: |",
    ]
    for branch_id, count in audit["branch_recipe_counts"].items():
        lines.append(f"| `{branch_id or 'unassigned'}` | {count} |")

    lines.extend(["", "## 完全重复簇", ""])
    for cluster in audit["exact_duplicate_clusters"]:
        signature = cluster["signature"]
        lines.extend(
            [
                f"### {cluster['cluster_id']} · {len(cluster['recipes'])} 个配方",
                "",
                (
                    f"- 角色：`{', '.join(signature['roles'])}`；"
                    f"标签：`{', '.join(signature['tags'])}`"
                ),
                (
                    f"- 形状：`{_format_shape(signature['shape'])}`；"
                    f"可旋转：`{str(signature['rotatable']).lower()}`"
                ),
                (
                    f"- 成本 {signature['supply_cost']}；复制上限 "
                    f"{signature['copy_limit']}；库存 "
                    f"{signature['virtual_stock']}；周期 "
                    f"{signature['cycle_ms']} ms；满足力 "
                    f"{signature['satisfaction']}"
                ),
                "",
                "| 配方 | 分支 | 层级 | 批次 |",
                "| --- | --- | ---: | --- |",
            ]
        )
        for recipe in cluster["recipes"]:
            lines.append(
                f"| `{recipe['recipe_id']}` · {recipe['display_name']} | "
                f"`{recipe['branch_id']}` | {recipe['tier']} | "
                f"`{recipe['batch']}` |"
            )
        lines.append("")

    lines.extend(
        [
            "## 高优先级近似重复配对",
            "",
            (
                f"展示 {len(audit['near_duplicate_pairs'])} 个命中项中的前 "
                f"{min(MARKDOWN_PAIR_LIMIT, len(audit['near_duplicate_pairs']))} 个。"
            ),
            "",
            "| 分数 | 左侧 | 右侧 | 同形状 | 同角色 | 同标签 |",
            "| ---: | --- | --- | :---: | :---: | :---: |",
        ]
    )
    for pair in audit["near_duplicate_pairs"][:MARKDOWN_PAIR_LIMIT]:
        lines.append(
            f"| {pair['score']:.2f} | `{pair['left_id']}` | "
            f"`{pair['right_id']}` | "
            f"{'是' if pair['same_shape'] else '否'} | "
            f"{'是' if pair['same_roles'] else '否'} | "
            f"{'是' if pair['same_tags'] else '否'} |"
        )

    lines.extend(
        [
            "",
            "## 保守全面支配关系",
            "",
        ]
    )
    if audit["dominance_relations"]:
        lines.extend(
            [
                "| 支配方 | 被支配方 | 严格优势 |",
                "| --- | --- | --- |",
            ]
        )
        for relation in audit["dominance_relations"]:
            lines.append(
                f"| `{relation['dominant_id']}` | "
                f"`{relation['dominated_id']}` | "
                f"`{', '.join(relation['advantages'])}` |"
            )
    else:
        lines.append("- 在保守同形状规则下未发现。")

    confirmed = audit.get("confirmed_pilot_evaluation", {})
    if confirmed:
        baseline = confirmed.get("baseline_summary", {})
        lines.extend(
            [
                "",
                "## 已确认试点验收",
                "",
                f"- 验收状态：`{confirmed['status']}`",
                f"- 试点配方：{confirmed['recipe_count']}",
                (
                    "- 全局完全重复碰撞："
                    f"{confirmed['global_exact_collision_count']}"
                ),
                (
                    "- 试点内部近似重复配对："
                    f"{confirmed['internal_near_duplicate_pair_count']}"
                ),
                (
                    "- 涉及试点的全面支配关系："
                    f"{confirmed['involved_dominance_relation_count']}"
                ),
                (
                    "- 与非试点配方的近似配对："
                    f"{confirmed['external_near_duplicate_pair_count']}"
                    "（保留为后续人工复核线索）"
                ),
                "",
                "### 相较审计基线",
                "",
                "| 指标 | 调整前 | 调整后 | 变化 |",
                "| --- | ---: | ---: | ---: |",
                (
                    "| 完全重复簇 | "
                    f"{baseline.get('exact_duplicate_cluster_count', 0)} | "
                    f"{summary['exact_duplicate_cluster_count']} | "
                    f"{summary['exact_duplicate_cluster_count'] - int(baseline.get('exact_duplicate_cluster_count', 0)):+d} |"
                ),
                (
                    "| 重复簇涉及配方 | "
                    f"{baseline.get('recipes_in_exact_duplicate_clusters', 0)} | "
                    f"{summary['recipes_in_exact_duplicate_clusters']} | "
                    f"{summary['recipes_in_exact_duplicate_clusters'] - int(baseline.get('recipes_in_exact_duplicate_clusters', 0)):+d} |"
                ),
                (
                    "| 近似重复配对 | "
                    f"{baseline.get('near_duplicate_pair_count', 0)} | "
                    f"{summary['near_duplicate_pair_count']} | "
                    f"{summary['near_duplicate_pair_count'] - int(baseline.get('near_duplicate_pair_count', 0)):+d} |"
                ),
                (
                    "| 全面支配关系 | "
                    f"{baseline.get('full_dominance_relation_count', 0)} | "
                    f"{summary['full_dominance_relation_count']} | "
                    f"{summary['full_dominance_relation_count'] - int(baseline.get('full_dominance_relation_count', 0)):+d} |"
                ),
                "",
                "| 配方 | 差异化定位 | 核心取舍 |",
                "| --- | --- | --- |",
            ]
        )
        for recipe in confirmed["recipes"]:
            lines.append(
                f"| `{recipe['recipe_id']}` · {recipe['display_name']} | "
                f"{recipe['design_role']} | {recipe['tradeoff']} |"
            )

    pilot = audit["pilot_proposal"]
    lines.extend(
        [
            "",
            "## 下一批试点提案",
            "",
            f"- 状态：`{pilot['status']}`",
            "- 选择规则：保持完全重复簇完整，不拆开配方簇，并尽量填满 12 个试点上限。",
            f"- 选中簇：{', '.join(pilot['selected_cluster_ids'])}",
            f"- 候选配方：{len(pilot['recipe_ids'])}",
            "",
            "| # | 配方 | 名称 | 分支 | 层级 | 完全重复簇 |",
            "| ---: | --- | --- | --- | ---: | --- |",
        ]
    )
    records_by_id = {
        recipe["recipe_id"]: (cluster["cluster_id"], recipe)
        for cluster in audit["exact_duplicate_clusters"]
        for recipe in cluster["recipes"]
    }
    for index, recipe_id in enumerate(pilot["recipe_ids"], start=1):
        cluster_id, recipe = records_by_id[recipe_id]
        lines.append(
            f"| {index} | `{recipe_id}` | {recipe['display_name']} | "
            f"`{recipe['branch_id']}` | {recipe['tier']} | "
            f"`{cluster_id}` |"
        )

    lines.extend(
        [
            "",
            "## 证据边界",
            "",
            "- 相似度是确定性的分诊分数，不能据此断言两个配方的真人体感完全相同。",
            "- 全面支配规则刻意保守，不比较标准形状或旋转语义不同的配方。",
            "- 研究时机、Boss 需求、强化可用性和玩家偏好仍需路线模拟与真人试玩验证。",
        ]
    )
    return "\n".join(lines) + "\n"


def serialized_json(audit: dict[str, Any]) -> str:
    return json.dumps(audit, ensure_ascii=False, indent=2) + "\n"


def main() -> None:
    args = parse_args()
    confirmed_pilot = read_json(args.pilot) if args.pilot.exists() else None
    audit = build_audit(
        read_json(args.runtime),
        read_json(args.manifest),
        confirmed_pilot,
    )
    json_text = serialized_json(audit)
    markdown_text = render_markdown(audit)
    if args.check:
        current_json = (
            args.json_output.read_text(encoding="utf-8-sig")
            if args.json_output.exists()
            else ""
        )
        current_markdown = (
            args.markdown_output.read_text(encoding="utf-8-sig")
            if args.markdown_output.exists()
            else ""
        )
        stale: list[str] = []
        if current_json != json_text:
            stale.append(str(args.json_output.relative_to(ROOT)))
        if current_markdown != markdown_text:
            stale.append(str(args.markdown_output.relative_to(ROOT)))
        if stale:
            raise SystemExit(
                "Generated similarity audit is stale: " + ", ".join(stale)
            )
    else:
        args.json_output.write_text(json_text, encoding="utf-8")
        args.markdown_output.write_text(markdown_text, encoding="utf-8")

    summary = audit["summary"]
    print(
        "CHALLENGE_RECIPE_SIMILARITY_AUDIT_PASS "
        f"recipes={summary['recipe_count']} "
        f"exact_clusters={summary['exact_duplicate_cluster_count']} "
        f"clustered_recipes={summary['recipes_in_exact_duplicate_clusters']} "
        f"near_pairs={summary['near_duplicate_pair_count']} "
        f"dominance={summary['full_dominance_relation_count']} "
        f"pilot={len(audit['pilot_proposal']['recipe_ids'])}"
    )


if __name__ == "__main__":
    main()
