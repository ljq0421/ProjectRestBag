import importlib.util
import json
import shutil
import unittest
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SCRIPT_PATH = ROOT / "tools" / "generate_staged_showcase_recipe_icons.py"


def _load_generator_module():
    spec = importlib.util.spec_from_file_location(
        "generate_staged_showcase_recipe_icons",
        SCRIPT_PATH,
    )
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


class GenerateStagedShowcaseRecipeIconsTest(unittest.TestCase):
    def setUp(self):
        sandbox_tmp = ROOT / "tmp" / "staged_showcase_icon_tests"
        sandbox_tmp.mkdir(parents=True, exist_ok=True)
        self.temp_root = sandbox_tmp / self._testMethodName
        shutil.rmtree(self.temp_root, ignore_errors=True)
        self.temp_root.mkdir()
        self.source_dir = self.temp_root / "source"
        self.output_dir = self.temp_root / "output"
        self.config_path = self.temp_root / "recipe_display_config.json"
        self.source_dir.mkdir()
        self.config_path.write_text(
            json.dumps(
                {
                    "recipes": {
                        "sample_recipe": {
                            "default_shape": "1x2",
                            "cell_count": 2,
                            "stages": {"popular": {}, "signature": {}},
                        },
                        "other_recipe": {
                            "default_shape": "1x1",
                            "cell_count": 1,
                            "stages": {"popular": {}, "signature": {}},
                        },
                    }
                }
            ),
            encoding="utf-8",
        )

    def tearDown(self):
        shutil.rmtree(self.temp_root, ignore_errors=True)

    def _write_sources(self, recipe_id="sample_recipe"):
        colors = {
            "": (220, 40, 60, 255),
            "_popular": (40, 180, 90, 255),
            "_signature": (50, 100, 220, 255),
        }
        for suffix, color in colors.items():
            image = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
            image.paste(color, (96, 128, 416, 384))
            image.save(self.source_dir / f"{recipe_id}{suffix}.png")

    def _write_icons_v1_sources(self, recipe_id="sample_recipe"):
        for stage_number, color in {
            1: (220, 40, 60, 255),
            2: (40, 180, 90, 255),
            3: (50, 100, 220, 255),
        }.items():
            image = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
            image.paste(color, (192, 128, 832, 896))
            image.save(self.source_dir / f"{recipe_id}_{stage_number}.png")

    def test_generates_three_stage_manifest_with_rotated_regions(self):
        module = _load_generator_module()
        self._write_sources()

        manifest = module.generate_staged_showcase_icons(
            self.source_dir,
            self.output_dir,
            self.config_path,
            ["sample_recipe"],
        )

        self.assertEqual(manifest["recipe_count"], 1)
        self.assertEqual(manifest["stage_count"], 3)
        self.assertEqual(manifest["version"], 2)
        for mastery_level, stage_id in [(0, "trial"), (1, "popular"), (2, "signature")]:
            horizontal_key = f"sample_recipe|m{mastery_level}|standard|r0"
            vertical_key = f"sample_recipe|m{mastery_level}|standard|r90"
            self.assertIn(horizontal_key, manifest["entries"])
            self.assertIn(vertical_key, manifest["entries"])
            horizontal = manifest["entries"][horizontal_key]
            vertical = manifest["entries"][vertical_key]
            self.assertEqual(horizontal["stage_id"], stage_id)
            self.assertEqual(horizontal["cell_size"], 80)
            self.assertEqual(horizontal["regions"]["1:2"], [80, 0, 80, 80])
            self.assertEqual(vertical["regions"]["2:1"], [0, 80, 80, 80])
            horizontal_path = self.output_dir / Path(horizontal["texture_path"]).name
            vertical_path = self.output_dir / Path(vertical["texture_path"]).name
            with Image.open(horizontal_path) as image:
                self.assertEqual(image.size, (160, 80))
                self._assert_safe_alpha_inset(image, module.SAFE_MARGIN_PX)
            with Image.open(vertical_path) as image:
                self.assertEqual(image.size, (80, 160))
                self._assert_safe_alpha_inset(image, module.SAFE_MARGIN_PX)

        saved_manifest = json.loads(
            (self.output_dir / module.MANIFEST_FILENAME).read_text(encoding="utf-8")
        )
        self.assertEqual(saved_manifest, manifest)
        self.assertFalse(any(path.name.startswith("other_recipe") for path in self.output_dir.iterdir()))

    def test_missing_stage_leaves_existing_output_untouched(self):
        module = _load_generator_module()
        self._write_sources()
        (self.source_dir / "sample_recipe_signature.png").unlink()
        self.output_dir.mkdir()
        marker = self.output_dir / "keep.txt"
        marker.write_text("existing", encoding="utf-8")

        with self.assertRaisesRegex(FileNotFoundError, "sample_recipe_signature.png"):
            module.generate_staged_showcase_icons(
                self.source_dir,
                self.output_dir,
                self.config_path,
                ["sample_recipe"],
            )

        self.assertEqual(marker.read_text(encoding="utf-8"), "existing")
        self.assertEqual(list(self.output_dir.iterdir()), [marker])

    def test_regeneration_preserves_matching_import_sidecars(self):
        module = _load_generator_module()
        self._write_sources()
        module.generate_staged_showcase_icons(
            self.source_dir,
            self.output_dir,
            self.config_path,
            ["sample_recipe"],
        )
        png = next(self.output_dir.glob("*.png"))
        sidecar = png.with_suffix(".png.import")
        sidecar.write_text("godot-import-metadata", encoding="utf-8")

        module.generate_staged_showcase_icons(
            self.source_dir,
            self.output_dir,
            self.config_path,
            ["sample_recipe"],
        )

        self.assertEqual(sidecar.read_text(encoding="utf-8"), "godot-import-metadata")

    def test_irregular_rotated_subject_is_not_cut_by_an_empty_cell(self):
        module = _load_generator_module()
        source = Image.new("RGBA", (80, 160), (0, 0, 0, 0))
        source.paste((240, 120, 40, 255), (20, 8, 60, 152))
        cells = [(1, 1), (1, 2), (2, 2)]

        canvas = module._render_contained_canvas(source, cells, 90)

        self.assertEqual(canvas.size, (160, 160))
        bounds = canvas.getchannel("A").getbbox()
        self.assertIsNotNone(bounds)
        left, top, right, bottom = bounds
        self.assertGreaterEqual(left, module.SAFE_MARGIN_PX)
        self.assertGreaterEqual(top, module.SAFE_MARGIN_PX)
        self.assertLessEqual(right, 160 - module.SAFE_MARGIN_PX)
        self.assertLessEqual(bottom, 80 - module.SAFE_MARGIN_PX)

    def test_incremental_update_preserves_other_recipe_and_uses_72px_regions(self):
        module = _load_generator_module()
        self._write_sources("other_recipe")
        module.generate_staged_showcase_icons(
            self.source_dir,
            self.output_dir,
            self.config_path,
            ["other_recipe"],
        )
        other_png = self.output_dir / "other_recipe__trial__standard__r0.png"
        other_sidecar = other_png.with_suffix(".png.import")
        other_sidecar.write_text("other-import", encoding="utf-8")
        other_png_bytes = other_png.read_bytes()
        before_manifest = json.loads(
            (self.output_dir / module.MANIFEST_FILENAME).read_text(encoding="utf-8")
        )
        other_entry = before_manifest["entries"]["other_recipe|m0|standard|r0"]

        self._write_sources("sample_recipe")
        source_bytes = {
            path.name: path.read_bytes()
            for path in self.source_dir.glob("sample_recipe*.png")
        }
        manifest = module.generate_staged_showcase_icons(
            self.source_dir,
            self.output_dir,
            self.config_path,
            ["sample_recipe"],
            cell_size=72,
            preserve_existing=True,
        )

        self.assertEqual(manifest["recipe_count"], 2)
        self.assertEqual(manifest["cell_size"], 80)
        self.assertEqual(
            manifest["entries"]["other_recipe|m0|standard|r0"],
            other_entry,
        )
        self.assertEqual(other_png.read_bytes(), other_png_bytes)
        self.assertEqual(other_sidecar.read_text(encoding="utf-8"), "other-import")
        pilot_entry = manifest["entries"]["sample_recipe|m0|standard|r0"]
        self.assertEqual(pilot_entry["cell_size"], 72)
        self.assertEqual(pilot_entry["regions"]["1:2"], [72, 0, 72, 72])
        pilot_png = self.output_dir / Path(pilot_entry["texture_path"]).name
        with Image.open(pilot_png) as image:
            self.assertEqual(image.size, (144, 72))
        self.assertEqual(
            source_bytes,
            {
                path.name: path.read_bytes()
                for path in self.source_dir.glob("sample_recipe*.png")
            },
        )

    def test_showcase_sharpening_preserves_alpha(self):
        module = _load_generator_module()
        image = Image.new("RGBA", (72, 72), (0, 0, 0, 0))
        image.paste((230, 120, 40, 192), (8, 5, 64, 67))

        sharpened = module._sharpen_rgb_preserve_alpha(image)

        self.assertEqual(
            sharpened.getchannel("A").tobytes(),
            image.getchannel("A").tobytes(),
        )

    def test_icons_v1_naming_reads_1024_stage_sources_directly(self):
        module = _load_generator_module()
        self._write_icons_v1_sources()
        source_bytes = {
            path.name: path.read_bytes()
            for path in self.source_dir.glob("sample_recipe_*.png")
        }

        manifest = module.generate_staged_showcase_icons(
            self.source_dir,
            self.output_dir,
            self.config_path,
            ["sample_recipe"],
            cell_size=72,
            source_naming="icons-v1",
        )

        self.assertEqual(
            manifest["entries"]["sample_recipe|m2|standard|r0"]["cell_size"],
            72,
        )
        self.assertEqual(
            source_bytes,
            {
                path.name: path.read_bytes()
                for path in self.source_dir.glob("sample_recipe_*.png")
            },
        )

    def test_icons_v1_naming_rejects_a_downsampled_source(self):
        module = _load_generator_module()
        self._write_icons_v1_sources()
        Image.new("RGBA", (128, 128), (10, 20, 30, 255)).save(
            self.source_dir / "sample_recipe_2.png"
        )

        with self.assertRaisesRegex(ValueError, "must be 1024x1024"):
            module.generate_staged_showcase_icons(
                self.source_dir,
                self.output_dir,
                self.config_path,
                ["sample_recipe"],
                cell_size=72,
                source_naming="icons-v1",
            )

        self.assertFalse(self.output_dir.exists())

    def _assert_safe_alpha_inset(self, image, safe_margin):
        bounds = image.convert("RGBA").getchannel("A").getbbox()
        self.assertIsNotNone(bounds)
        left, top, right, bottom = bounds
        self.assertGreaterEqual(left, safe_margin)
        self.assertGreaterEqual(top, safe_margin)
        self.assertGreaterEqual(image.width - right, safe_margin)
        self.assertGreaterEqual(image.height - bottom, safe_margin)


if __name__ == "__main__":
    unittest.main()
