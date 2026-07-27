import re
import subprocess
import sys
import unittest
from collections import Counter
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CATALOG_PATH = ROOT / "scripts" / "catalog.gd"
GENERATOR_PATH = ROOT / "tools" / "generate_recipe_production_durations.py"


def _recipe_records():
    text = CATALOG_PATH.read_text(encoding="utf-8-sig")
    block = text.split("const RECIPES := {", 1)[1].split(
        "const PROCESSING_RECIPES := {", 1
    )[0]
    records = {}
    for line in block.splitlines():
        match = re.match(r'\s*"([^"]+)"\s*:\s*\{(.+?)\},?\s*$', line)
        if not match:
            continue
        body = match.group(2)
        materials_match = re.search(r'"materials"\s*:\s*\[([^]]*)\]', body)
        duration_match = re.search(
            r'"production_duration_seconds"\s*:\s*(\d+)', body
        )
        records[match.group(1)] = {
            "materials": re.findall(r'"([^"]+)"', materials_match.group(1))
            if materials_match
            else [],
            "duration": int(duration_match.group(1)) if duration_match else None,
        }
    return records


class RecipeProductionDurationConfigTest(unittest.TestCase):
    def test_all_recipes_have_explicit_allowed_duration(self):
        recipes = _recipe_records()

        self.assertEqual(len(recipes), 166)
        missing = [
            recipe_id
            for recipe_id, recipe in recipes.items()
            if recipe["duration"] is None
        ]
        self.assertEqual(missing, [])
        self.assertEqual(Counter(recipe["duration"] for recipe in recipes.values()), {
            2: 69,
            4: 49,
            8: 48,
        })

    def test_config_matches_complexity_defaults(self):
        recipes = _recipe_records()
        recipe_ids = set(recipes)

        for recipe_id, recipe in recipes.items():
            materials = recipe["materials"]
            if any(material_id in recipe_ids for material_id in materials):
                expected = 8
            elif len(materials) <= 3:
                expected = 2
            elif len(materials) == 4:
                expected = 4
            else:
                expected = 8
            self.assertEqual(recipe["duration"], expected, recipe_id)

    def test_generator_check_is_clean(self):
        self.assertTrue(GENERATOR_PATH.exists())
        result = subprocess.run(
            [sys.executable, str(GENERATOR_PATH), "--check"],
            cwd=ROOT,
            text=True,
            capture_output=True,
        )

        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_generator_write_is_idempotent(self):
        source = CATALOG_PATH.read_text(encoding="utf-8-sig")
        prefix, recipes_and_suffix = source.split("const RECIPES := {", 1)
        stale = prefix + "const RECIPES := {" + re.sub(
            r', "production_duration_seconds": \d+', "", recipes_and_suffix, count=1
        )
        catalog_path = ROOT / "tmp" / "test_recipe_production_duration_catalog.gd"
        try:
            catalog_path.write_text(stale, encoding="utf-8")
            command = [
                sys.executable,
                str(GENERATOR_PATH),
                "--catalog",
                str(catalog_path),
                "--write",
            ]
            first = subprocess.run(command, cwd=ROOT, text=True, capture_output=True)
            first_text = catalog_path.read_text(encoding="utf-8")
            second = subprocess.run(command, cwd=ROOT, text=True, capture_output=True)
            second_text = catalog_path.read_text(encoding="utf-8")
        finally:
            catalog_path.unlink(missing_ok=True)

        self.assertEqual(first.returncode, 0, first.stdout + first.stderr)
        self.assertEqual(second.returncode, 0, second.stdout + second.stderr)
        self.assertEqual(first_text, second_text)

    def test_generator_check_rejects_stale_or_illegal_config(self):
        source = CATALOG_PATH.read_text(encoding="utf-8-sig")
        prefix, recipes_and_suffix = source.split("const RECIPES := {", 1)
        variants = [
            prefix + "const RECIPES := {" + re.sub(
                r', "production_duration_seconds": \d+', "", recipes_and_suffix, count=1
            ),
            prefix + "const RECIPES := {" + re.sub(
                r'"production_duration_seconds": \d+',
                '"production_duration_seconds": 3',
                recipes_and_suffix,
                count=1,
            ),
        ]
        catalog_path = ROOT / "tmp" / "test_recipe_production_duration_catalog.gd"
        try:
            for index, variant in enumerate(variants):
                catalog_path.write_text(variant, encoding="utf-8")
                result = subprocess.run(
                    [
                        sys.executable,
                        str(GENERATOR_PATH),
                        "--catalog",
                        str(catalog_path),
                        "--check",
                    ],
                    cwd=ROOT,
                    text=True,
                    capture_output=True,
                )
                self.assertNotEqual(result.returncode, 0, result.stdout)
        finally:
            catalog_path.unlink(missing_ok=True)


if __name__ == "__main__":
    unittest.main()
