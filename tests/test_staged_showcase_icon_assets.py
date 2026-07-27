import json
import unittest
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
OUTPUT_DIR = ROOT / "resources" / "recipe_icons_showcase_staged"
MANIFEST_PATH = OUTPUT_DIR / "staged_showcase_icon_manifest.json"
SOURCE_DIR = ROOT / "resources" / "ui" / "icons_v1"
RECIPE_IDS = {
    path.stem.rsplit("_", 1)[0]
    for stage_number in (1, 2, 3)
    for path in SOURCE_DIR.glob(f"*_{stage_number}.png")
}
EXPECTED_RECIPE_COUNT = 166
EXPECTED_ENTRY_COUNT = 5160
STAGE_IDS = {0: "trial", 1: "popular", 2: "signature"}
SAFE_MARGIN_RATIO = 0.05


class StagedShowcaseIconAssetsTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
        cls.entries = cls.manifest["entries"]

    def test_manifest_has_the_complete_current_pack(self):
        self.assertEqual(self.manifest["cell_size"], 72)
        self.assertEqual(len(RECIPE_IDS), EXPECTED_RECIPE_COUNT)
        self.assertEqual(self.manifest["recipe_count"], len(RECIPE_IDS))
        self.assertEqual(self.manifest["stage_count"], len(STAGE_IDS))
        self.assertEqual(len(self.entries), EXPECTED_ENTRY_COUNT)

        covered = {
            (entry["recipe_id"], entry["mastery_level"], entry["stage_id"])
            for entry in self.entries.values()
        }
        self.assertEqual(
            covered,
            {
                (recipe_id, mastery_level, stage_id)
                for recipe_id in RECIPE_IDS
                for mastery_level, stage_id in STAGE_IDS.items()
            },
        )

    def test_every_entry_has_an_imported_transparent_canvas(self):
        for entry_key, entry in self.entries.items():
            self.assertEqual(entry.get("cell_size"), 72, entry_key)
            texture_path = entry["texture_path"]
            self.assertTrue(texture_path.startswith("res://"), entry_key)
            image_path = ROOT / texture_path.removeprefix("res://")
            self.assertTrue(image_path.is_file(), f"missing canvas: {image_path}")
            self.assertTrue(
                image_path.with_suffix(".png.import").is_file(),
                f"missing Godot import metadata: {image_path}.import",
            )
            with Image.open(image_path) as image:
                cell_size = int(entry.get("cell_size", self.manifest["cell_size"]))
                safe_margin = max(1, round(cell_size * SAFE_MARGIN_RATIO))
                self.assertEqual(
                    image.size,
                    (
                        int(entry["cols"]) * cell_size,
                        int(entry["rows"]) * cell_size,
                    ),
                    entry_key,
                )
                self.assertEqual(image.mode, "RGBA", entry_key)
                alpha_min, alpha_max = image.getchannel("A").getextrema()
                self.assertEqual(alpha_min, 0, entry_key)
                self.assertGreaterEqual(alpha_max, 254, entry_key)
                bounds = image.getchannel("A").getbbox()
                self.assertIsNotNone(bounds, entry_key)
                left, top, right, bottom = bounds
                self.assertGreaterEqual(left, safe_margin, entry_key)
                self.assertGreaterEqual(top, safe_margin, entry_key)
                self.assertGreaterEqual(image.width - right, safe_margin, entry_key)
                self.assertGreaterEqual(image.height - bottom, safe_margin, entry_key)
                occupied = {tuple(cell) for cell in entry["cells"]}
                first_row = top // cell_size + 1
                last_row = (bottom - 1) // cell_size + 1
                first_col = left // cell_size + 1
                last_col = (right - 1) // cell_size + 1
                covered_cells = {
                    (row, col)
                    for row in range(first_row, last_row + 1)
                    for col in range(first_col, last_col + 1)
                }
                self.assertTrue(
                    covered_cells <= occupied,
                    f"subject bounding box crosses an empty cell: {entry_key}",
                )


if __name__ == "__main__":
    unittest.main()
