import importlib.util
import json
import shutil
import unittest
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SCRIPT_PATH = ROOT / "tools" / "generate_showcase_recipe_icons.py"


def _load_generator_module():
    if not SCRIPT_PATH.exists():
        return None
    spec = importlib.util.spec_from_file_location("generate_showcase_recipe_icons", SCRIPT_PATH)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


class GenerateShowcaseRecipeIconsTest(unittest.TestCase):
    def setUp(self):
        sandbox_tmp = ROOT / "tmp" / "showcase_icon_tests"
        sandbox_tmp.mkdir(parents=True, exist_ok=True)
        self.temp_root = sandbox_tmp / self._testMethodName
        shutil.rmtree(self.temp_root, ignore_errors=True)
        self.temp_root.mkdir()
        self.source_dir = self.temp_root / "source"
        self.output_dir = self.temp_root / "output"
        self.source_dir.mkdir()
        self.module = _load_generator_module()

    def tearDown(self):
        shutil.rmtree(self.temp_root, ignore_errors=True)

    def write_source(self, recipe_id, size=(512, 512), color=(220, 80, 40, 255)):
        path = self.source_dir / f"{recipe_id}.png"
        Image.new("RGBA", size, color).save(path)
        return path

    def write_config(self, config):
        path = self.temp_root / "recipe_display_config.json"
        path.write_text(json.dumps(config, ensure_ascii=False), encoding="utf-8")
        return path

    def generate(self, config, recipe_id):
        self.assertIsNotNone(self.module, "showcase icon generator script should exist")
        self.write_source(recipe_id)
        return self.module.generate_showcase_icons(
            self.source_dir,
            self.output_dir,
            self.write_config(config),
        )

    def test_generates_horizontal_canvas_manifest_and_preserves_source(self):
        self.assertIsNotNone(self.module, "showcase icon generator script should exist")
        config = {
            "recipes": {
                "horizontal": {
                    "cell_count": 2,
                    "default_shape": "1x2",
                    "rotatable": True,
                }
            }
        }
        source = self.write_source("horizontal")
        original = source.read_bytes()

        manifest = self.module.generate_showcase_icons(
            self.source_dir,
            self.output_dir,
            self.write_config(config),
        )

        r0 = manifest["entries"]["horizontal|standard|r0"]
        r90 = manifest["entries"]["horizontal|standard|r90"]
        self.assertEqual((r0["cols"], r0["rows"]), (2, 1))
        self.assertEqual((r90["cols"], r90["rows"]), (1, 2))
        self.assertEqual(r0["regions"]["1:1"], [0, 0, 80, 80])
        self.assertEqual(r0["regions"]["1:2"], [80, 0, 80, 80])
        with Image.open(self.output_dir / Path(r0["texture_path"]).name) as image:
            self.assertEqual(image.size, (160, 80))
            self.assertEqual(image.mode, "RGBA")
        self.assertEqual(source.read_bytes(), original)

    def test_masks_missing_l_shape_cell(self):
        config = {
            "recipes": {
                "corner": {
                    "cell_count": 3,
                    "default_shape": "2x2",
                    "shape_cells": [[1, 1], [1, 2], [2, 1]],
                    "rotatable": True,
                }
            }
        }

        manifest = self.generate(config, "corner")

        entry = manifest["entries"]["corner|standard|r0"]
        self.assertNotIn("2:2", entry["regions"])
        with Image.open(self.output_dir / Path(entry["texture_path"]).name) as image:
            self.assertEqual(image.size, (160, 160))
            self.assertEqual(image.getpixel((120, 120))[3], 0)

    def test_generates_variant_cell_counts_matching_runtime_rules(self):
        config = {
            "recipes": {
                "variant_recipe": {
                    "cell_count": 3,
                    "default_shape": "2x2",
                    "shape_cells": [[1, 1], [1, 2], [2, 1]],
                    "rotatable": False,
                }
            }
        }

        manifest = self.generate(config, "variant_recipe")

        expected_counts = {
            "standard": 3,
            "small": 1,
            "sample": 1,
            "gift_box": 4,
            "large": 4,
        }
        for variant_id, expected_count in expected_counts.items():
            entry = manifest["entries"][f"variant_recipe|{variant_id}|r0"]
            self.assertEqual(len(entry["cells"]), expected_count, variant_id)

    def test_multicell_shapes_cover_runtime_rotation_even_when_config_marks_nonrotatable(self):
        config = {
            "recipes": {
                "runtime_rotated_corner": {
                    "cell_count": 3,
                    "default_shape": "2x2",
                    "shape_cells": [[1, 1], [1, 2], [2, 1]],
                    "rotatable": False,
                }
            }
        }

        manifest = self.generate(config, "runtime_rotated_corner")

        standard_keys = {
            key for key in manifest["entries"]
            if key.startswith("runtime_rotated_corner|standard|")
        }
        self.assertEqual(
            standard_keys,
            {
                "runtime_rotated_corner|standard|r0",
                "runtime_rotated_corner|standard|r90",
                "runtime_rotated_corner|standard|r180",
                "runtime_rotated_corner|standard|r270",
            },
        )

    def test_failure_keeps_existing_output_unchanged(self):
        self.assertIsNotNone(self.module, "showcase icon generator script should exist")
        self.output_dir.mkdir()
        sentinel = self.output_dir / "sentinel.png"
        sentinel.write_bytes(b"existing")

        with self.assertRaises(FileNotFoundError):
            self.module.generate_showcase_icons(
                self.source_dir,
                self.output_dir,
                self.write_config({"recipes": {"missing": {"default_shape": "1x1"}}}),
            )

        self.assertEqual(sentinel.read_bytes(), b"existing")

    def test_repository_sources_cover_every_configured_recipe(self):
        config_path = ROOT / "doc" / "recipe_display_config.json"
        source_dir = ROOT / "resources" / "recipe_icons"
        config = json.loads(config_path.read_text(encoding="utf-8-sig"))
        recipe_ids = sorted(config["recipes"])
        source_ids = sorted(path.stem for path in source_dir.glob("*.png"))

        self.assertEqual(len(recipe_ids), 166)
        self.assertEqual(source_ids, recipe_ids)

    def test_checked_in_manifest_matches_every_generated_canvas(self):
        output_dir = ROOT / "resources" / "recipe_icons_showcase"
        manifest_path = output_dir / "showcase_icon_manifest.json"
        self.assertTrue(manifest_path.is_file(), "showcase manifest should exist")
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        entries = manifest["entries"]

        self.assertEqual(manifest["recipe_count"], 166)
        self.assertEqual(manifest["cell_size"], 80)
        self.assertEqual(len(list(output_dir.glob("*.png"))), len(entries))
        for entry_key, entry in entries.items():
            texture_path = entry["texture_path"]
            self.assertTrue(texture_path.startswith("res://resources/recipe_icons_showcase/"), entry_key)
            image_path = output_dir / Path(texture_path).name
            self.assertTrue(image_path.is_file(), entry_key)
            expected_size = (entry["cols"] * 80, entry["rows"] * 80)
            with Image.open(image_path) as image:
                self.assertEqual(image.size, expected_size, entry_key)
                self.assertEqual(image.mode, "RGBA", entry_key)
                occupied = {tuple(cell) for cell in entry["cells"]}
                self.assertEqual(
                    set(entry["regions"]),
                    {f"{row}:{col}" for row, col in occupied},
                    entry_key,
                )
                for row in range(1, entry["rows"] + 1):
                    for col in range(1, entry["cols"] + 1):
                        if (row, col) in occupied:
                            region = entry["regions"][f"{row}:{col}"]
                            self.assertEqual(region[2:], [80, 80], entry_key)
                            continue
                        x = (col - 1) * 80 + 40
                        y = (row - 1) * 80 + 40
                        self.assertEqual(image.getpixel((x, y))[3], 0, entry_key)

    def test_neighbor_regions_share_the_same_pixel_boundary_without_a_gap(self):
        config = {
            "recipes": {
                "vertical": {
                    "cell_count": 2,
                    "default_shape": "2x1",
                    "shape_cells": [[1, 1], [2, 1]],
                }
            }
        }
        manifest = self.generate(config, "vertical")
        entry = manifest["entries"]["vertical|standard|r0"]

        top = entry["regions"]["1:1"]
        bottom = entry["regions"]["2:1"]
        self.assertEqual(top[1] + top[3], bottom[1])
        self.assertEqual(manifest["cell_size"], 80)
        self.assertEqual(manifest["cell_gap"], 0)


if __name__ == "__main__":
    unittest.main()
