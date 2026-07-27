"""Audit recipe catalog, showcase display config, and gameplay tag integrity."""

from __future__ import annotations

import argparse
import json
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any


DEFAULT_CATALOG_PATH = Path("scripts/catalog.gd")
DEFAULT_DISPLAY_CONFIG_PATH = Path("doc/recipe_display_config.json")
DEFAULT_DISPLAY_RULES_PATH = Path("doc/display_rules_full.json")
DEFAULT_TAXONOMY_PATH = Path("doc/recipe_tag_taxonomy.json")
DEFAULT_OUTPUT_PATH = Path("doc/recipe_data_audit.md")
DEFAULT_STRUCTURED_CONSUMER_PATHS = (
    Path("scripts/recipe_growth_service.gd"),
    Path("scripts/task_service.gd"),
    Path("scripts/showcase_rule_service.gd"),
)
DEFAULT_RUNTIME_TAG_PATHS = (
    Path("scripts/shop_simulation.gd"),
    Path("scripts/main_view.gd"),
    *DEFAULT_STRUCTURED_CONSUMER_PATHS,
)

CATALOG_REQUIRED_FIELDS = (
    "name",
    "device",
    "materials",
    "tags",
    "price",
    "output_count",
    "unlock_level",
    "production_duration_seconds",
)
DISPLAY_REQUIRED_FIELDS = (
    "recipe_name",
    "cell_count",
    "shape_category",
    "default_shape",
    "rotatable",
)
LEGACY_TAGS = {
    "Q弹",
    "丝滑",
    "养生",
    "咸甜",
    "咸鲜",
    "回甘",
    "复合香",
    "嫩滑",
    "微苦",
    "扎实",
    "拉丝",
    "暖胃",
    "松软",
    "栗香",
    "流心",
    "浓醇",
    "润喉",
    "清冽",
    "清新",
    "清润",
    "清淡",
    "清甘",
    "清甜",
    "温润",
    "湿润",
    "滋润",
    "焦脆",
    "焦香",
    "管饱",
    "米香",
    "粉糯",
    "粗粮",
    "绵密",
    "解腻",
    "软嫩",
    "酥脆",
    "酸甜",
    "醇厚",
    "醇香",
    "顺滑",
    "香气",
    "香甜",
    "鲜软",
    "香浓",
}


def _extract_const_block(text: str, const_name: str) -> str:
    marker = f"const {const_name} := {{"
    marker_start = text.find(marker)
    if marker_start < 0:
        raise ValueError(f"const block not found: {const_name}")
    start = marker_start + len(marker)
    depth = 1
    in_string = False
    escaped = False
    for index in range(start, len(text)):
        char = text[index]
        if in_string:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                in_string = False
            continue
        if char == '"':
            in_string = True
        elif char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return text[start:index]
    raise ValueError(f"unterminated const block: {const_name}")


def _string_field(body: str, key: str) -> str | None:
    match = re.search(rf'"{re.escape(key)}"\s*:\s*"([^"]*)"', body)
    return match.group(1) if match else None


def _array_field(body: str, key: str) -> list[str]:
    match = re.search(rf'"{re.escape(key)}"\s*:\s*\[([^]]*)\]', body)
    return re.findall(r'"([^"]+)"', match.group(1)) if match else []


def _number_field(body: str, key: str) -> int | None:
    match = re.search(rf'"{re.escape(key)}"\s*:\s*(-?\d+)', body)
    return int(match.group(1)) if match else None


def _dictionary_ids(text: str, const_name: str) -> set[str]:
    block = _extract_const_block(text, const_name)
    return set(re.findall(r'^\s*"([^"]+)"\s*:\s*\{', block, flags=re.MULTILINE))


def _dictionary_records(path: Path, const_name: str) -> dict[str, str]:
    text = path.read_text(encoding="utf-8-sig")
    block = _extract_const_block(text, const_name)
    records: dict[str, str] = {}
    for line in block.splitlines():
        match = re.match(r'\s*"([^"]+)"\s*:\s*\{(.+?)\},?\s*(?:#.*)?$', line)
        if match:
            records[match.group(1)] = match.group(2)
    return records


def load_catalog(path: Path) -> dict[str, dict[str, Any]]:
    recipes: dict[str, dict[str, Any]] = {}
    for recipe_id, body in _dictionary_records(path, "RECIPES").items():
        recipes[recipe_id] = {
            "id": _string_field(body, "id") or recipe_id,
            "name": _string_field(body, "name"),
            "device": _string_field(body, "device"),
            "materials": _array_field(body, "materials"),
            "price": _number_field(body, "price"),
            "output_count": _number_field(body, "output_count"),
            "unlock_level": _number_field(body, "unlock_level"),
            "production_duration_seconds": _number_field(
                body, "production_duration_seconds"
            ),
            "tags": _array_field(body, "tags"),
        }
    return recipes


def load_customers(path: Path) -> dict[str, dict[str, Any]]:
    customers: dict[str, dict[str, Any]] = {}
    for customer_id, body in _dictionary_records(path, "CUSTOMERS").items():
        customers[customer_id] = {
            "preference_tags": _array_field(body, "preference_tags"),
        }
    return customers


def load_catalog_ids(path: Path) -> tuple[set[str], set[str]]:
    text = path.read_text(encoding="utf-8-sig")
    return _dictionary_ids(text, "INGREDIENTS"), _dictionary_ids(text, "DEVICES")


def load_display_config(path: Path) -> tuple[dict[str, Any], dict[str, dict[str, Any]]]:
    data = json.loads(path.read_text(encoding="utf-8-sig"))
    recipes = data.get("recipes", {})
    return data.get("meta", {}), {
        str(recipe_id): recipe for recipe_id, recipe in recipes.items()
    }


def load_display_rules(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8-sig"))


def load_taxonomy(path: Path) -> dict[str, dict[str, Any]]:
    data = json.loads(path.read_text(encoding="utf-8-sig"))
    tags = data.get("tags", {})
    if int(data.get("meta", {}).get("total_tags", -1)) != len(tags):
        raise ValueError("taxonomy meta.total_tags does not match tags")
    return {str(tag): definition for tag, definition in tags.items()}


def rule_tags(display_rules: dict[str, Any]) -> set[str]:
    tags: set[str] = set()
    for rule in display_rules.get("base_tag_bonuses", {}).values():
        tags.update(
            str(rule[key])
            for key in ("trigger_tag_a", "trigger_tag_b")
            if rule.get(key)
        )
    for rule in display_rules.get("set_bonuses", {}).values():
        tags.update(str(tag) for tag in rule.get("required_tags", []))
    for rule in display_rules.get("conflict_penalties", {}).values():
        tags.update(
            str(tag)
            for tag in rule.get("conflict_tags", [])
            if "任意" not in str(tag)
        )
    return tags


def build_rule_match_matrix(
    recipes: dict[str, dict[str, Any]],
    rules: dict[str, Any],
) -> dict[str, Any]:
    ordered_rule_ids = sorted(
        rules,
        key=lambda rule_id: (
            -int(rules[rule_id].get("priority", 0)),
            str(rule_id),
        ),
    )
    coverage_by_rule = {str(rule_id): 0 for rule_id in rules}
    selected_pairs: list[dict[str, str]] = []
    multi_match_pairs: list[dict[str, Any]] = []
    recipe_ids = sorted(recipes)
    for index, left_id in enumerate(recipe_ids):
        left_tags = set(recipes[left_id].get("tags", []))
        for right_id in recipe_ids[index + 1 :]:
            right_tags = set(recipes[right_id].get("tags", []))
            matches: list[str] = []
            for rule_id in ordered_rule_ids:
                rule = rules[rule_id]
                tag_a = str(rule.get("trigger_tag_a", ""))
                tag_b = str(rule.get("trigger_tag_b", ""))
                if (
                    tag_a in left_tags
                    and tag_b in right_tags
                ) or (
                    tag_b in left_tags
                    and tag_a in right_tags
                ):
                    matches.append(str(rule_id))
            if matches:
                selected_rule = matches[0]
                coverage_by_rule[selected_rule] += 1
                selected_pairs.append(
                    {
                        "left": left_id,
                        "right": right_id,
                        "rule": selected_rule,
                    }
                )
            if len(matches) > 1:
                multi_match_pairs.append(
                    {
                        "left": left_id,
                        "right": right_id,
                        "matches": matches,
                    }
                )
    return {
        "selected_pair_count": len(selected_pairs),
        "coverage_by_rule": coverage_by_rule,
        "multi_match_pairs": multi_match_pairs,
    }


def load_structured_tag_references(paths: tuple[Path, ...]) -> dict[str, set[str]]:
    references: dict[str, set[str]] = {}
    for path in paths:
        if not path.exists():
            continue
        text = path.read_text(encoding="utf-8-sig")
        tags: set[str] = set()
        for match in re.finditer(
            r'"(?:tags|preference_tags)"\s*:\s*\[([^]]*)\]',
            text,
        ):
            tags.update(re.findall(r'"([^"]+)"', match.group(1)))
        tags.update(re.findall(r'"tag"\s*:\s*"([^"]+)"', text))
        references[path.as_posix()] = tags
    return references


def find_legacy_runtime_references(paths: tuple[Path, ...]) -> dict[str, list[str]]:
    references: dict[str, list[str]] = {}
    for path in paths:
        if not path.exists():
            continue
        text = path.read_text(encoding="utf-8-sig")
        found = sorted(
            tag
            for tag in LEGACY_TAGS
            if re.search(rf'\.has\(\s*"{re.escape(tag)}"\s*\)', text)
            or re.search(
                rf'"(?:tags|preference_tags|tag)"\s*:\s*(?:\[[^]]*"{re.escape(tag)}"|"{re.escape(tag)}")',
                text,
            )
        )
        if found:
            references[path.as_posix()] = found
    return references


def build_audit(
    catalog_path: Path,
    display_config_path: Path,
    display_rules_path: Path,
    taxonomy_path: Path = DEFAULT_TAXONOMY_PATH,
) -> dict[str, Any]:
    catalog_recipes = load_catalog(catalog_path)
    customers = load_customers(catalog_path)
    ingredient_ids, device_ids = load_catalog_ids(catalog_path)
    display_meta, display_recipes = load_display_config(display_config_path)
    display_rules = load_display_rules(display_rules_path)
    taxonomy = load_taxonomy(taxonomy_path)
    canonical_tags = set(taxonomy)
    known_material_ids = ingredient_ids | set(catalog_recipes)
    known_rule_tags = rule_tags(display_rules)
    consumer_references = load_structured_tag_references(
        DEFAULT_STRUCTURED_CONSUMER_PATHS
    )
    customer_tags = {
        str(tag)
        for customer in customers.values()
        for tag in customer.get("preference_tags", [])
    }
    structured_consumer_tags = set().union(
        *(consumer_references.values() or [set()])
    )
    all_consumer_tags = known_rule_tags | customer_tags | structured_consumer_tags

    missing_display_ids = sorted(set(catalog_recipes) - set(display_recipes))
    display_only_ids = sorted(set(display_recipes) - set(catalog_recipes))
    missing_catalog_fields: dict[str, list[str]] = {}
    invalid_recipe_production_durations: dict[str, int] = {}
    unknown_materials: dict[str, list[str]] = {}
    unknown_devices: dict[str, str] = {}
    illegal_recipe_tags: dict[str, list[str]] = {}
    invalid_recipe_tag_counts: dict[str, list[str]] = {}
    catalog_tags: set[str] = set()
    tag_usage: Counter[str] = Counter()

    for recipe_id, recipe in catalog_recipes.items():
        missing = [
            field
            for field in CATALOG_REQUIRED_FIELDS
            if recipe.get(field) in (None, "", [])
        ]
        if missing:
            missing_catalog_fields[recipe_id] = missing
        production_duration = recipe.get("production_duration_seconds")
        if production_duration is not None and int(production_duration) not in {2, 4, 8}:
            invalid_recipe_production_durations[recipe_id] = int(production_duration)
        bad_materials = [
            item
            for item in recipe.get("materials", [])
            if item not in known_material_ids
        ]
        if bad_materials:
            unknown_materials[recipe_id] = bad_materials
        if recipe.get("device") not in device_ids:
            unknown_devices[recipe_id] = str(recipe.get("device"))
        tags = [str(tag) for tag in recipe.get("tags", [])]
        catalog_tags.update(tags)
        tag_usage.update(tags)
        illegal = sorted(set(tags) - canonical_tags)
        if illegal:
            illegal_recipe_tags[recipe_id] = illegal
        max_count = 3 if "招牌" in tags else 2
        if len(tags) < 1 or len(tags) > max_count:
            invalid_recipe_tag_counts[recipe_id] = tags

    missing_display_fields: dict[str, list[str]] = {}
    duplicate_display_tags: dict[str, list[str]] = {}
    shape_groups: defaultdict[str, list[str]] = defaultdict(list)
    for recipe_id, recipe in display_recipes.items():
        missing = [
            field
            for field in DISPLAY_REQUIRED_FIELDS
            if recipe.get(field) in (None, "", [])
        ]
        if missing:
            missing_display_fields[recipe_id] = missing
        if "tags" in recipe:
            duplicate_display_tags[recipe_id] = [
                str(tag) for tag in recipe.get("tags", [])
            ]
        shape_groups[str(recipe.get("default_shape", "missing"))].append(recipe_id)

    illegal_consumer_tags = sorted(all_consumer_tags - canonical_tags)
    orphan_tags = sorted(canonical_tags - all_consumer_tags)
    legacy_tag_references = find_legacy_runtime_references(
        DEFAULT_RUNTIME_TAG_PATHS
    )
    rule_match_matrix = build_rule_match_matrix(
        catalog_recipes,
        display_rules.get("base_tag_bonuses", {}),
    )

    set_core_tags = {
        str(tag)
        for rule in display_rules.get("set_bonuses", {}).values()
        for tag in rule.get("required_tags", [])
    }
    conflict_tags = {
        str(tag)
        for rule in display_rules.get("conflict_penalties", {}).values()
        for tag in rule.get("conflict_tags", [])
        if "任意" not in str(tag)
    }
    recipe_groups: dict[str, list[str]] = {
        "volume": [],
        "profit": [],
        "set_core": [],
        "adjacency_helper": [],
        "conflict_risk": [],
        "variant_candidate": [],
    }
    for recipe_id, recipe in catalog_recipes.items():
        display_recipe = display_recipes.get(recipe_id, {})
        tags = set(str(tag) for tag in recipe.get("tags", []))
        if int(recipe.get("output_count") or 0) >= 4 or int(
            display_recipe.get("cell_count", 0) or 0
        ) <= 1:
            recipe_groups["volume"].append(recipe_id)
        if int(recipe.get("price") or 0) >= 38:
            recipe_groups["profit"].append(recipe_id)
        if tags & set_core_tags:
            recipe_groups["set_core"].append(recipe_id)
        if tags & known_rule_tags:
            recipe_groups["adjacency_helper"].append(recipe_id)
        if tags & conflict_tags:
            recipe_groups["conflict_risk"].append(recipe_id)
        if int(display_recipe.get("cell_count", 0) or 0) in {1, 2, 3, 4}:
            recipe_groups["variant_candidate"].append(recipe_id)

    return {
        "catalog_count": len(catalog_recipes),
        "display_count": len(display_recipes),
        "display_meta_total": display_meta.get("total_recipes"),
        "rule_count": display_rules.get("meta", {}).get("total_rules"),
        "taxonomy_count": len(taxonomy),
        "missing_display_ids": missing_display_ids,
        "display_only_ids": display_only_ids,
        "missing_catalog_fields": missing_catalog_fields,
        "invalid_recipe_production_durations": invalid_recipe_production_durations,
        "missing_display_fields": missing_display_fields,
        "unknown_materials": unknown_materials,
        "unknown_devices": unknown_devices,
        "illegal_recipe_tags": illegal_recipe_tags,
        "invalid_recipe_tag_counts": invalid_recipe_tag_counts,
        "duplicate_display_tags": duplicate_display_tags,
        "illegal_consumer_tags": illegal_consumer_tags,
        "orphan_tags": orphan_tags,
        "legacy_tag_references": legacy_tag_references,
        "rule_match_matrix": rule_match_matrix,
        "rule_tags": sorted(known_rule_tags),
        "tag_usage": tag_usage,
        "shape_groups": {
            key: sorted(value) for key, value in sorted(shape_groups.items())
        },
        "recipe_groups": {
            key: sorted(value) for key, value in recipe_groups.items()
        },
    }


def _code(value: str) -> str:
    return "`" + value.replace("`", "\\`") + "`"


def _format_id_list(items: list[str], limit: int = 30) -> list[str]:
    if not items:
        return ["- None"]
    lines = [f"- {_code(item)}" for item in items[:limit]]
    if len(items) > limit:
        lines.append(f"- ... {len(items) - limit} more")
    return lines


def _format_map(mapping: dict[str, Any], limit: int = 30) -> list[str]:
    if not mapping:
        return ["- None"]
    lines: list[str] = []
    for index, key in enumerate(sorted(mapping)):
        if index >= limit:
            lines.append(f"- ... {len(mapping) - limit} more")
            break
        value = mapping[key]
        rendered = ", ".join(str(item) for item in value) if isinstance(
            value, list
        ) else str(value)
        lines.append(f"- {_code(key)}: {rendered}")
    return lines


def render_markdown(audit: dict[str, Any]) -> str:
    lines = [
        "# Recipe Data Audit",
        "",
        "Generated by `tools/audit_recipe_data.py`.",
        "",
        "## Summary",
        "",
        f"- Catalog recipes: {audit['catalog_count']}",
        f"- Display recipes: {audit['display_count']}",
        f"- Display meta total_recipes: {audit['display_meta_total']}",
        f"- Display rule meta total_rules: {audit['rule_count']}",
        f"- Canonical recipe tags: {audit['taxonomy_count']}",
        "",
        "## Blocking Mismatches",
        "",
    ]
    blocking_sections = (
        ("Catalog recipes missing display config", "missing_display_ids", False),
        ("Display-only recipes missing runtime catalog entries", "display_only_ids", False),
        ("Catalog recipes with missing required fields", "missing_catalog_fields", True),
        ("Invalid recipe production durations", "invalid_recipe_production_durations", True),
        ("Display recipes with missing required fields", "missing_display_fields", True),
        ("Recipes with unknown materials", "unknown_materials", True),
        ("Recipes with unknown devices", "unknown_devices", True),
    )
    for title, key, is_map in blocking_sections:
        lines.extend([f"### {title}", ""])
        lines.extend(
            _format_map(audit[key]) if is_map else _format_id_list(audit[key])
        )
        lines.append("")

    lines.extend(["## Tag Integrity", ""])
    tag_sections = (
        ("Illegal recipe tags", "illegal_recipe_tags", True),
        ("Invalid recipe tag counts", "invalid_recipe_tag_counts", True),
        ("Duplicate display tags", "duplicate_display_tags", True),
        ("Illegal consumer tags", "illegal_consumer_tags", False),
        ("Legacy structured tag references", "legacy_tag_references", True),
        ("Tag islands", "orphan_tags", False),
    )
    for title, key, is_map in tag_sections:
        lines.extend([f"### {title}", ""])
        lines.extend(
            _format_map(audit[key]) if is_map else _format_id_list(audit[key])
        )
        lines.append("")

    lines.extend(["## Canonical Tag Usage", ""])
    for tag, count in sorted(audit["tag_usage"].items()):
        lines.append(f"- {_code(tag)}: {count} recipes")
    matrix = audit["rule_match_matrix"]
    lines.extend(
        [
            "",
            "## Base Rule Match Matrix",
            "",
            f"- Selected recipe pairs: {matrix['selected_pair_count']}",
            f"- Raw multi-match candidates: {len(matrix['multi_match_pairs'])}",
            "",
            "### Coverage by rule",
            "",
        ]
    )
    for rule_id, count in sorted(matrix["coverage_by_rule"].items()):
        lines.append(f"- {_code(rule_id)}: {count} selected pairs")
    lines.extend(["", "## Shape Groups", ""])
    for shape, ids in audit["shape_groups"].items():
        lines.append(f"- {_code(shape)}: {len(ids)} recipes")
    lines.extend(["", "## Recipe Groups", ""])
    group_names = {
        "volume": "Volume sellers",
        "profit": "Profit picks",
        "set_core": "Set cores",
        "adjacency_helper": "Adjacency helpers",
        "conflict_risk": "Conflict risks",
        "variant_candidate": "Variant candidates",
    }
    for group_id, label in group_names.items():
        lines.extend([f"### {label}", ""])
        lines.extend(_format_id_list(audit["recipe_groups"][group_id], limit=40))
        lines.append("")
    return "\n".join(lines).rstrip() + "\n"


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--catalog", type=Path, default=DEFAULT_CATALOG_PATH)
    parser.add_argument(
        "--display-config", type=Path, default=DEFAULT_DISPLAY_CONFIG_PATH
    )
    parser.add_argument(
        "--display-rules", type=Path, default=DEFAULT_DISPLAY_RULES_PATH
    )
    parser.add_argument("--taxonomy", type=Path, default=DEFAULT_TAXONOMY_PATH)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUTPUT_PATH)
    parser.add_argument(
        "--strict",
        action="store_true",
        help="Return non-zero when blocking or tag-integrity mismatches exist.",
    )
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    audit = build_audit(
        args.catalog,
        args.display_config,
        args.display_rules,
        args.taxonomy,
    )
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(
        render_markdown(audit),
        encoding="utf-8",
        newline="\n",
    )
    print(f"Wrote recipe data audit to {args.out}")
    blocker_keys = (
        "missing_display_ids",
        "display_only_ids",
        "missing_catalog_fields",
        "invalid_recipe_production_durations",
        "missing_display_fields",
        "unknown_materials",
        "unknown_devices",
        "illegal_recipe_tags",
        "invalid_recipe_tag_counts",
        "duplicate_display_tags",
        "illegal_consumer_tags",
        "orphan_tags",
        "legacy_tag_references",
    )
    if args.strict and any(audit[key] for key in blocker_keys):
        print("Recipe data audit found blocking mismatches.", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
