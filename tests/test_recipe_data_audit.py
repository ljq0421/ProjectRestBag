import json
import subprocess
import sys
import unittest
from pathlib import Path


CANONICAL_TAGS = {
    "甜",
    "苦甜",
    "咸香",
    "果香",
    "茶香",
    "奶香",
    "香脆",
    "软糯",
    "清爽",
    "浓郁",
    "清凉",
    "低负担",
    "饱腹",
    "经典",
    "招牌",
}


class RecipeDataAuditTest(unittest.TestCase):
    def test_catalog_loader_exposes_recipe_production_duration(self):
        root = Path(__file__).resolve().parents[1]
        tools_path = str(root / "tools")
        sys.path.insert(0, tools_path)
        try:
            import audit_recipe_data as audit

            recipes = audit.load_catalog(root / "scripts" / "catalog.gd")
        finally:
            sys.path.remove(tools_path)

        self.assertIn("production_duration_seconds", recipes["rice_milk_drink"])
        self.assertEqual(recipes["rice_milk_drink"]["production_duration_seconds"], 2)
        self.assertEqual(recipes["cream_shortcake"]["production_duration_seconds"], 8)

    def test_rule_match_matrix_selects_one_rule_per_pair(self):
        root = Path(__file__).resolve().parents[1]
        tools_path = str(root / "tools")
        sys.path.insert(0, tools_path)
        try:
            import audit_recipe_data as audit

            recipes = audit.load_catalog(root / "scripts" / "catalog.gd")
            rules = audit.load_display_rules(
                root / "doc" / "display_rules_full.json"
            )["base_tag_bonuses"]
            matrix = audit.build_rule_match_matrix(recipes, rules)
        finally:
            sys.path.remove(tools_path)

        self.assertEqual(
            matrix["selected_pair_count"],
            sum(matrix["coverage_by_rule"].values()),
        )
        self.assertEqual(set(matrix["coverage_by_rule"]), set(rules))

    def test_taxonomy_contains_exact_canonical_vocabulary(self):
        root = Path(__file__).resolve().parents[1]
        taxonomy_path = root / "doc" / "recipe_tag_taxonomy.json"

        data = json.loads(taxonomy_path.read_text(encoding="utf-8"))

        self.assertEqual(set(data["tags"]), CANONICAL_TAGS)
        self.assertEqual(data["meta"]["total_tags"], 15)

    def test_strict_audit_rejects_unknown_recipe_tag(self):
        root = Path(__file__).resolve().parents[1]
        script = root / "tools" / "audit_recipe_data.py"
        catalog_text = (root / "scripts" / "catalog.gd").read_text(encoding="utf-8-sig")
        catalog_text = catalog_text.replace(
            '"tags": ["经典", "清爽"]',
            '"tags": ["不存在"]',
            1,
        )

        tmp = root / "tmp"
        tmp.mkdir(exist_ok=True)
        catalog_path = tmp / "test_recipe_data_audit_catalog.gd"
        output_path = tmp / "test_recipe_data_audit_strict.md"
        try:
            catalog_path.write_text(catalog_text, encoding="utf-8")

            result = subprocess.run(
                [
                    sys.executable,
                    str(script),
                    "--catalog",
                    str(catalog_path),
                    "--taxonomy",
                    str(root / "doc" / "recipe_tag_taxonomy.json"),
                    "--out",
                    str(output_path),
                    "--strict",
                ],
                cwd=root,
                text=True,
                capture_output=True,
            )

            self.assertEqual(result.returncode, 1, result.stderr)
            self.assertTrue(output_path.exists(), result.stderr)
            self.assertIn("不存在", output_path.read_text(encoding="utf-8"))
        finally:
            catalog_path.unlink(missing_ok=True)
            output_path.unlink(missing_ok=True)

    def test_strict_audit_rejects_invalid_production_duration(self):
        root = Path(__file__).resolve().parents[1]
        script = root / "tools" / "audit_recipe_data.py"
        catalog_text = (root / "scripts" / "catalog.gd").read_text(
            encoding="utf-8-sig"
        )
        catalog_prefix, recipe_catalog_text = catalog_text.split(
            "const RECIPES := {", 1
        )
        recipe_catalog_text = recipe_catalog_text.replace(
            '"production_duration_seconds": 2',
            '"production_duration_seconds": 3',
            1,
        )
        catalog_text = catalog_prefix + "const RECIPES := {" + recipe_catalog_text

        tmp = root / "tmp"
        tmp.mkdir(exist_ok=True)
        catalog_path = tmp / "test_invalid_recipe_duration_catalog.gd"
        output_path = tmp / "test_invalid_recipe_duration_audit.md"
        try:
            catalog_path.write_text(catalog_text, encoding="utf-8")
            result = subprocess.run(
                [
                    sys.executable,
                    str(script),
                    "--catalog",
                    str(catalog_path),
                    "--out",
                    str(output_path),
                    "--strict",
                ],
                cwd=root,
                text=True,
                capture_output=True,
            )

            self.assertEqual(result.returncode, 1, result.stderr)
            self.assertIn(
                "Invalid recipe production durations",
                output_path.read_text(encoding="utf-8"),
            )
        finally:
            catalog_path.unlink(missing_ok=True)
            output_path.unlink(missing_ok=True)

    def test_generates_recipe_data_audit_from_project_sources(self):
        root = Path(__file__).resolve().parents[1]
        script = root / "tools" / "audit_recipe_data.py"
        tmp_root = root / "tmp"
        tmp_root.mkdir(exist_ok=True)

        output_path = tmp_root / "test_recipe_data_audit.md"
        result = subprocess.run(
            [
                sys.executable,
                str(script),
                "--out",
                str(output_path),
            ],
            cwd=root,
            text=True,
            capture_output=True,
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        text = output_path.read_text(encoding="utf-8")

        self.assertIn("# Recipe Data Audit", text)
        self.assertIn("Catalog recipes: 166", text)
        self.assertIn("Display recipes: 166", text)
        self.assertIn("Display meta total_recipes: 166", text)
        self.assertIn("## Blocking Mismatches", text)
        self.assertIn("Display-only recipes missing runtime catalog entries", text)
        display_only_section = text.split(
            "### Display-only recipes missing runtime catalog entries", 1
        )[1].split("### Catalog recipes with missing required fields", 1)[0]
        self.assertIn("- None", display_only_section)
        self.assertNotIn("`rich_rice_drink`", display_only_section)
        self.assertNotIn("`white_sugar_rice_porridge`", display_only_section)
        self.assertIn("## Recipe Groups", text)
        self.assertIn("### Volume sellers", text)
        self.assertIn("### Profit picks", text)


if __name__ == "__main__":
    unittest.main()
