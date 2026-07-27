import unittest
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = ROOT / "resources" / "ui" / "icons_v1"
RECIPE_IDS = sorted(
    {
        path.stem.rsplit("_", 1)[0]
        for stage_number in (1, 2, 3)
        for path in SOURCE_DIR.glob(f"*_{stage_number}.png")
    }
)
EXPECTED_RECIPE_COUNT = 166
STAGES = {
    1: "",
    2: "_popular",
    3: "_signature",
}
SURFACES = {
    "recipe_icons": (128, 128),
    "recipe_icons_catalog": (112, 112),
    "recipe_icons_inventory": (80, 80),
    "recipe_icons_action": (32, 32),
}


class StagedRecipeIconAssetsTest(unittest.TestCase):
    def test_source_batch_is_complete_rgba_and_transparent(self):
        self.assertEqual(len(RECIPE_IDS), EXPECTED_RECIPE_COUNT)
        for recipe_id in RECIPE_IDS:
            for stage_number in STAGES:
                path = SOURCE_DIR / f"{recipe_id}_{stage_number}.png"
                self.assertTrue(path.is_file(), f"missing source icon: {path}")
                with Image.open(path) as image:
                    self.assertEqual(image.size, (1024, 1024), str(path))
                    self.assertEqual(image.mode, "RGBA", str(path))
                    alpha_min, alpha_max = image.getchannel("A").getextrema()
                    self.assertEqual(alpha_min, 0, str(path))
                    self.assertGreaterEqual(alpha_max, 254, str(path))

    def test_all_runtime_surfaces_have_three_imported_stages(self):
        for directory_name, expected_size in SURFACES.items():
            directory = ROOT / "resources" / directory_name
            for recipe_id in RECIPE_IDS:
                for suffix in STAGES.values():
                    path = directory / f"{recipe_id}{suffix}.png"
                    self.assertTrue(path.is_file(), f"missing runtime icon: {path}")
                    self.assertTrue(
                        path.with_suffix(".png.import").is_file(),
                        f"missing Godot import metadata: {path}.import",
                    )
                    with Image.open(path) as image:
                        self.assertEqual(image.size, expected_size, str(path))
                        self.assertEqual(image.mode, "RGBA", str(path))
                        alpha_min, alpha_max = image.getchannel("A").getextrema()
                        self.assertEqual(alpha_min, 0, str(path))
                        self.assertGreaterEqual(alpha_max, 254, str(path))


if __name__ == "__main__":
    unittest.main()
