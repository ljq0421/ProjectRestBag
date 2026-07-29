#!/usr/bin/env python3
"""Generate the three five-encounter challenge routes and mastery blueprints."""

from __future__ import annotations

import argparse
import copy
import json
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
ROUTE_PATH = ROOT / "doc/challenge/standard_run.json"
ENCOUNTER_PATH = ROOT / "doc/challenge/boss_encounters.json"
MASTERY_PATH = ROOT / "doc/challenge/challenge_masteries.json"
TREE_PATH = ROOT / "doc/challenge/research_tree.json"
UPGRADE_PATH = ROOT / "doc/challenge/run_upgrades.json"

ROUTE_IDS = ("standard_short_chain", "flavor_texture_route", "grand_composition_route")
ROUTE_ENCOUNTERS = {
    "flavor_texture_route": (
        ("route_b_soft_opening", "柔软晨间席", ["soft", "drink"]),
        ("route_b_tea_salon", "茶香品鉴厅", ["tea", "rich"]),
        ("route_b_crisp_festival", "香脆烘焙节", ["crisp", "bake"]),
        ("route_b_texture_master", "质地校准师", ["soft", "crisp"]),
        ("route_b_patisserie_exam", "风味甜点考核", ["tea", "rich", "soft"]),
    ),
    "grand_composition_route": (
        ("route_c_hearty_market", "饱腹市集", ["savory", "hearty"]),
        ("route_c_space_architect", "橱窗建筑师", ["spatial"]),
        ("route_c_savory_banquet", "咸甜宴会", ["savory", "signature"]),
        ("route_c_combo_director", "复合构筑总监", ["spatial", "hearty"]),
        ("route_c_grand_critic", "终局陈列评论家", ["signature", "spatial", "rich"]),
    ),
}
STARTERS = [
    "butter_cookie",
    "strawberry_jelly",
    "milk_pudding",
    "blueberry_muffin",
    "sponge_cake",
    "chocolate_lava_cake",
]
ADVANCED_MENUS = {
    "flavor_texture_route": [
        ["egg_milk_custard", "caramel_pudding_steamed", "rich_rice_drink", "milk_pudding"],
        ["black_tea_latte", "lemon_honey_black_tea", "black_tea_panna", "butter_cookie", "sponge_cake", "strawberry_jelly"],
        ["oats_cookie", "almond_chocolate_tart", "blueberry_muffin", "butter_cookie", "cream_shortcake", "milk_pudding"],
    ],
    "grand_composition_route": [
        ["beef_baked_pie", "chicken_steamed_dumpling", "sponge_cake", "milk_pudding"],
        ["banana_pound_cake", "blueberry_cream_tart", "cream_shortcake", "caramel_mousse"],
        ["chocolate_lava_cake", "sponge_cake", "butter_cookie", "strawberry_jelly", "milk_pudding", "blueberry_muffin"],
    ],
}
STARTER_FALLBACK_TAGS = {
    "route_b_soft_opening": ["drink"],
    "route_b_tea_salon": ["signature"],
    "route_b_crisp_festival": ["bake"],
    "route_b_texture_master": ["drink", "bake"],
    "route_b_patisserie_exam": ["signature", "drink"],
    "route_c_hearty_market": ["fast", "signature"],
    "route_c_space_architect": ["set"],
    "route_c_savory_banquet": ["signature"],
    "route_c_combo_director": ["set", "signature"],
    "route_c_grand_critic": ["signature", "set", "chocolate"],
}


def read(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8-sig"))


def write_or_check(path: Path, value: dict[str, Any], check: bool) -> None:
    text = json.dumps(value, ensure_ascii=False, indent=2) + "\n"
    if check:
        if not path.exists() or path.read_text(encoding="utf-8-sig") != text:
            raise SystemExit(f"Generated file is stale: {path.relative_to(ROOT)}")
    else:
        path.write_text(text, encoding="utf-8")


def route_definition(
    route_id: str,
    display_name: str,
    description: str,
    prerequisite: str,
    roles: list[str],
    encounter_rows: tuple[tuple[str, str, list[str]], ...],
) -> dict[str, Any]:
    return {
        "id": route_id,
        "display_name": display_name,
        "description": description,
        "unlock_requirement_route_id": prerequisite,
        "grid_rows": 6,
        "grid_columns": 8,
        "supply_budget": 16,
        "required_unlock_node_ids": [],
        "guaranteed_recipe_pool": STARTERS,
        "revealed_branch_ids": [],
        "recommended_build_roles": roles,
        "validation_menus": [STARTERS[:4], STARTERS] + ADVANCED_MENUS[route_id],
        "stages": [
            {
                "stage_index": index,
                "encounter_id": row[0],
                "encounter_type": "final_boss" if index == 4 else "elite" if index == 3 else "normal",
            }
            for index, row in enumerate(encounter_rows)
        ],
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    current_routes = read(ROUTE_PATH)
    current_encounters = read(ENCOUNTER_PATH)
    routes = current_routes["routes"]
    route_a = routes["standard_short_chain"]
    route_a.update(
        {
            "description": "节奏、搭配和招牌的基础五场短链。",
            "unlock_requirement_route_id": "",
            "required_unlock_node_ids": [],
            "guaranteed_recipe_pool": STARTERS,
            "revealed_branch_ids": ["tempo_display", "fruit_set", "signature_display"],
            "recommended_build_roles": ["tempo", "pairing", "signature"],
            "validation_menus": [STARTERS[:4], STARTERS],
        }
    )
    routes["flavor_texture_route"] = route_definition(
        "flavor_texture_route",
        "风味与质地路线",
        "以奶香软糯、茶香苦甜和香脆烘焙重组菜单。",
        "standard_short_chain",
        ["softness", "flavor", "shape"],
        ROUTE_ENCOUNTERS["flavor_texture_route"],
    )
    routes["flavor_texture_route"]["revealed_branch_ids"] = [
        "milk_soft",
        "tea_bittersweet",
        "crisp_bake",
    ]
    routes["grand_composition_route"] = route_definition(
        "grand_composition_route",
        "复合经营路线",
        "以咸香饱腹、空间联动和晚期招牌完成终局构筑。",
        "flavor_texture_route",
        ["sustain", "space", "signature"],
        ROUTE_ENCOUNTERS["grand_composition_route"],
    )
    routes["grand_composition_route"]["revealed_branch_ids"] = [
        "savory_hearty",
        "spatial_combo",
        "signature_display",
    ]

    encounter_defs = current_encounters["encounters"]
    templates = [
        encounter_defs[row["encounter_id"]]
        for row in route_a["stages"]
    ]
    for route_id, rows in ROUTE_ENCOUNTERS.items():
        for index, (encounter_id, display_name, theme_tags) in enumerate(rows):
            definition = copy.deepcopy(templates[index])
            definition["id"] = encounter_id
            definition["display_name"] = display_name
            definition["route_theme_tags"] = theme_tags
            definition["theme_explanation"] = (
                f"本场优先检验 {'、'.join(theme_tags)} 标签；"
                "开局配方保留一组可达替代标签，高级菜单可用主题配方重构。"
            )
            definition["blueprint_hint_id"] = f"blueprint_{encounter_id}"
            definition["relation_bonus_pct"] = 20 + index * 3
            windows = definition.get("windows", [])
            if windows:
                theme_window = windows[0]
                theme_window["metric"] = "tag_sales_count"
                theme_window["target_tags"] = (
                    list(theme_tags) + STARTER_FALLBACK_TAGS[encounter_id]
                )
                theme_window["tag"] = STARTER_FALLBACK_TAGS[encounter_id][0]
                theme_window["target"] = 1
            encounter_defs[encounter_id] = definition

    masteries = {
        "masteries": {
            "route_a_first_clear": {
                "id": "route_a_first_clear",
                "display_name": "基础构筑毕业",
                "description": "首次完成五场标准短链。",
                "condition": {"type": "route_first_clear", "route_id": "standard_short_chain"},
                "reveal_node_ids": [],
            },
            "route_b_first_clear": {
                "id": "route_b_first_clear",
                "display_name": "风味与质地毕业",
                "description": "首次完成风味与质地路线。",
                "condition": {"type": "route_first_clear", "route_id": "flavor_texture_route"},
                "reveal_node_ids": [],
            },
            "route_triad": {
                "id": "route_triad",
                "display_name": "三路线陈列大师",
                "description": "三条标准路线各完成至少一次。",
                "condition": {"type": "all_route_first_clears", "route_ids": list(ROUTE_IDS)},
                "reveal_node_ids": [],
            },
            "endless_20": {
                "id": "endless_20",
                "display_name": "无尽二十层",
                "description": "无尽最高纪录达到 20 层。",
                "condition": {"type": "endless_best_floor", "floor": 20},
                "reveal_node_ids": [],
            },
        }
    }
    tree = read(TREE_PATH)
    branch_nodes = {
        branch["id"]: list(branch.get("node_ids", []))
        for branch in tree.get("branches", [])
    }
    masteries["masteries"]["route_triad"]["reveal_node_ids"] = [
        branch_nodes["signature_display"][-1],
        branch_nodes["spatial_combo"][-1],
    ]
    masteries["masteries"]["endless_20"]["reveal_node_ids"] = [
        branch_nodes["savory_hearty"][-1]
    ]
    write_or_check(ROUTE_PATH, current_routes, args.check)
    write_or_check(ENCOUNTER_PATH, current_encounters, args.check)
    write_or_check(MASTERY_PATH, masteries, args.check)
    upgrades = read(UPGRADE_PATH)
    upgrade_defs = upgrades["upgrades"]
    for upgrade_id, display_name, tag in (
        ("soft_texture_boost", "柔软质地加成", "soft"),
        ("tea_aroma_boost", "茶香余韵", "tea"),
        ("crisp_counter", "香脆专柜", "crisp"),
        ("savory_service", "咸香服务台", "savory"),
        ("hearty_reserve", "饱腹备货", "hearty"),
        ("spatial_planning", "空间规划", "spatial"),
        ("rich_finish", "浓郁收尾", "rich"),
    ):
        upgrade_defs[upgrade_id] = {
            "id": upgrade_id,
            "display_name": display_name,
            "description": f"带有 {tag} 标签的菜单配方满足力 +2。",
            "category": "compatible",
            "max_stacks": 2,
            "mutual_exclusion_group": "",
            "effect": {
                "type": "satisfaction_add",
                "target_tags": [tag],
                "value": 2,
            },
        }
    write_or_check(UPGRADE_PATH, upgrades, args.check)
    print("CHALLENGE_ROUTE_GENERATION_OK routes=3 encounters=15 masteries=4 upgrades=7")


if __name__ == "__main__":
    main()
