import importlib.util
import shutil
import unittest
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SCRIPT_PATH = ROOT / "tools" / "install_staged_recipe_icons.py"


def _load_installer_module():
    spec = importlib.util.spec_from_file_location("install_staged_recipe_icons", SCRIPT_PATH)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


class InstallStagedRecipeIconsTest(unittest.TestCase):
    def setUp(self):
        sandbox_tmp = ROOT / "tmp" / "staged_recipe_icon_tests"
        sandbox_tmp.mkdir(parents=True, exist_ok=True)
        self.temp_root = sandbox_tmp / self._testMethodName
        shutil.rmtree(self.temp_root, ignore_errors=True)
        self.temp_root.mkdir()
        self.source_dir = self.temp_root / "source"
        self.source_dir.mkdir()
        self.output_dirs = {
            surface: self.temp_root / "outputs" / surface
            for surface in ["base", "catalog", "inventory", "action"]
        }

    def tearDown(self):
        shutil.rmtree(self.temp_root, ignore_errors=True)

    def _write_stage_sources(self, recipe_id="sample_recipe"):
        colors = {
            1: (220, 40, 60, 255),
            2: (40, 180, 90, 192),
            3: (50, 100, 220, 128),
        }
        for stage_number, color in colors.items():
            image = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
            image.paste(color, (256, 256, 768, 768))
            image.save(self.source_dir / f"{recipe_id}_{stage_number}.png")
        return colors

    def test_installs_all_stage_names_and_surface_sizes(self):
        module = _load_installer_module()
        colors = self._write_stage_sources()
        source_bytes = {
            path.name: path.read_bytes()
            for path in self.source_dir.glob("*.png")
        }

        generated = module.install_staged_icons(
            self.source_dir,
            self.output_dirs,
            ["sample_recipe"],
        )

        self.assertEqual(len(generated), 12)
        suffixes = {1: "", 2: "_popular", 3: "_signature"}
        for surface, expected_size in module.OUTPUT_SIZES.items():
            for stage_number, suffix in suffixes.items():
                output_path = self.output_dirs[surface] / f"sample_recipe{suffix}.png"
                self.assertTrue(output_path.is_file())
                with Image.open(output_path) as result:
                    self.assertEqual(result.size, expected_size)
                    self.assertEqual(result.mode, "RGBA")
                    center = result.getpixel((expected_size[0] // 2, expected_size[1] // 2))
                    self.assertTrue(
                        all(
                            abs(actual - expected) <= 1
                            for actual, expected in zip(center, colors[stage_number])
                        ),
                        f"center color {center} should preserve {colors[stage_number]}",
                    )
                    self.assertEqual(result.getpixel((0, 0))[3], 0)
        self.assertEqual(
            source_bytes,
            {path.name: path.read_bytes() for path in self.source_dir.glob("*.png")},
        )

    def test_sharpening_preserves_resized_alpha_channel(self):
        module = _load_installer_module()
        source = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
        source.paste((230, 130, 60, 255), (240, 120, 800, 920))

        for surface, expected_size in module.OUTPUT_SIZES.items():
            resized = source.resize(expected_size, Image.Resampling.LANCZOS)
            sharpened = module._resize_and_sharpen(source, surface)
            self.assertEqual(
                sharpened.getchannel("A").tobytes(),
                resized.getchannel("A").tobytes(),
                surface,
            )

    def test_missing_stage_rejects_batch_before_touching_outputs(self):
        module = _load_installer_module()
        self._write_stage_sources()
        (self.source_dir / "sample_recipe_3.png").unlink()
        existing_dir = self.output_dirs["base"]
        existing_dir.mkdir(parents=True)
        existing = existing_dir / "sample_recipe.png"
        existing.write_bytes(b"existing")

        with self.assertRaisesRegex(FileNotFoundError, "sample_recipe_3.png"):
            module.install_staged_icons(
                self.source_dir,
                self.output_dirs,
                ["sample_recipe"],
            )

        self.assertEqual(existing.read_bytes(), b"existing")
        self.assertFalse(self.output_dirs["catalog"].exists())

    def test_invalid_source_size_rejects_batch(self):
        module = _load_installer_module()
        self._write_stage_sources()
        Image.new("RGBA", (512, 1024), (1, 2, 3, 4)).save(
            self.source_dir / "sample_recipe_2.png"
        )

        with self.assertRaisesRegex(ValueError, "must be 1024x1024"):
            module.install_staged_icons(
                self.source_dir,
                self.output_dirs,
                ["sample_recipe"],
            )

        self.assertFalse((self.temp_root / "outputs").exists())

    def test_selected_recipe_does_not_touch_other_outputs(self):
        module = _load_installer_module()
        self._write_stage_sources("selected_recipe")
        self._write_stage_sources("other_recipe")
        for output_dir in self.output_dirs.values():
            output_dir.mkdir(parents=True)
            (output_dir / "other_recipe.png").write_bytes(b"keep")

        module.install_staged_icons(
            self.source_dir,
            self.output_dirs,
            ["selected_recipe", "selected_recipe"],
        )

        for output_dir in self.output_dirs.values():
            self.assertEqual((output_dir / "other_recipe.png").read_bytes(), b"keep")
            self.assertTrue((output_dir / "selected_recipe_signature.png").is_file())


if __name__ == "__main__":
    unittest.main()
