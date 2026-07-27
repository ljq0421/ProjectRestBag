import json
import unittest
from collections import deque
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CONFIG_PATH = ROOT / "doc" / "recipe_display_config.json"
ICON_ROOT = ROOT / "resources" / "recipe_icons"
STAGES = ("popular", "signature")
GROWTH_STAGE_NAMES = {"试作品", "人气款", "招牌款"}


def load_config():
    return json.loads(CONFIG_PATH.read_text(encoding="utf-8"))


def resolve_variant(trial, override):
    resolved = {
        key: value
        for key, value in trial.items()
        if key not in {"recipe_name", "remark", "growth_variants"}
    }
    for key, value in override.items():
        if key == "shape_cells" and value == []:
            resolved.pop("shape_cells", None)
        else:
            resolved[key] = value
    return resolved


def shape_dimensions(value):
    rows_text, cols_text = value.lower().split("x", 1)
    return int(rows_text), int(cols_text)


def assert_shape_valid(test_case, recipe_id, stage, resolved):
    rows, cols = shape_dimensions(str(resolved["default_shape"]))
    test_case.assertGreater(rows, 0, f"{recipe_id}:{stage} rows")
    test_case.assertGreater(cols, 0, f"{recipe_id}:{stage} cols")
    test_case.assertLessEqual(rows, 3, f"{recipe_id}:{stage} rows")
    test_case.assertLessEqual(cols, 3, f"{recipe_id}:{stage} cols")

    raw_cells = resolved.get("shape_cells")
    if raw_cells:
        cells = [tuple(cell) for cell in raw_cells]
        test_case.assertEqual(len(cells), len(set(cells)), f"{recipe_id}:{stage} duplicate cells")
        for row, col in cells:
            test_case.assertTrue(1 <= row <= rows, f"{recipe_id}:{stage} row boundary")
            test_case.assertTrue(1 <= col <= cols, f"{recipe_id}:{stage} col boundary")
        visited = {cells[0]}
        queue = deque([cells[0]])
        while queue:
            row, col = queue.popleft()
            for neighbor in ((row - 1, col), (row + 1, col), (row, col - 1), (row, col + 1)):
                if neighbor in cells and neighbor not in visited:
                    visited.add(neighbor)
                    queue.append(neighbor)
        test_case.assertEqual(set(cells), visited, f"{recipe_id}:{stage} disconnected cells")
        occupied = len(cells)
    else:
        occupied = rows * cols

    test_case.assertEqual(int(resolved["cell_count"]), occupied, f"{recipe_id}:{stage} cell_count")
    test_case.assertLessEqual(occupied, 9, f"{recipe_id}:{stage} occupied cells")


class RecipeGrowthDisplayConfigTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.config = load_config()
        cls.recipes = cls.config["recipes"]

    def test_all_recipes_define_sparse_growth_variants(self):
        self.assertEqual(self.config["meta"]["total_recipes"], 166)
        self.assertEqual(len(self.recipes), 166)
        for recipe_id, trial in self.recipes.items():
            variants = trial.get("growth_variants")
            self.assertIsInstance(variants, dict, f"{recipe_id} growth_variants")
            self.assertEqual(set(variants), set(STAGES), f"{recipe_id} stages")
            self.assertEqual(variants["popular"], {}, f"{recipe_id} popular must inherit trial")

    def test_variant_overrides_are_minimal_and_resolve_to_valid_shapes(self):
        allowed_categories = set(self.config["meta"]["shape_types"])
        self.assertNotIn("招牌款", allowed_categories)
        self.assertIn("大块款", allowed_categories)

        for recipe_id, trial in self.recipes.items():
            for stage in STAGES:
                override = trial["growth_variants"][stage]
                for key, value in override.items():
                    if key == "shape_cells" and value == []:
                        self.assertIn("shape_cells", trial, f"{recipe_id}:{stage} unnecessary clear")
                    else:
                        self.assertNotEqual(value, trial.get(key), f"{recipe_id}:{stage} redundant {key}")
                resolved = resolve_variant(trial, override)
                self.assertIn(resolved["shape_category"], allowed_categories, f"{recipe_id}:{stage} category")
                self.assertNotIn(resolved["shape_category"], GROWTH_STAGE_NAMES, f"{recipe_id}:{stage} growth category")
                assert_shape_valid(self, recipe_id, stage, resolved)

    def test_representative_signature_shapes_follow_recipe_identity(self):
        expected = {
            "rice_milk_drink": (2, "竖杯款", "2x1", True, True),
            "butter_cookie": (2, "横盘款", "1x2", True, True),
            "rice_flour_steamed_cake": (4, "中块款", "2x2", True, True),
            "apple_pie": (6, "大块款", "2x3", True, True),
            "orange_chiffon_cake": (9, "大块款", "3x3", False, True),
            "strawberry_cream_cake": (4, "中块款", "2x2", True, True),
            "community_parfait": (6, "大块款", "2x3", True, True),
        }
        for recipe_id, signature in expected.items():
            trial = self.recipes[recipe_id]
            variants = trial.get("growth_variants")
            self.assertIsInstance(variants, dict, f"{recipe_id} growth_variants")
            resolved = resolve_variant(trial, variants["signature"])
            actual = (
                resolved["cell_count"],
                resolved["shape_category"],
                resolved["default_shape"],
                resolved["rotatable"],
                "shape_cells" not in resolved,
            )
            self.assertEqual(actual, signature, recipe_id)

    def test_stable_stage_assets_are_removed(self):
        self.assertEqual(list(ICON_ROOT.glob("*_stable.png")), [])
        self.assertEqual(list(ICON_ROOT.glob("*_stable.png.import")), [])


if __name__ == "__main__":
    unittest.main()
