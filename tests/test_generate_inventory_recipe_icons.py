import importlib.util
import shutil
import unittest
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SCRIPT_PATH = ROOT / "tools" / "generate_inventory_recipe_icons.py"


def _load_generator_module():
    if not SCRIPT_PATH.exists():
        return None
    spec = importlib.util.spec_from_file_location(
        "generate_inventory_recipe_icons",
        SCRIPT_PATH,
    )
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


class GenerateInventoryRecipeIconsTest(unittest.TestCase):
    def setUp(self):
        sandbox_tmp = ROOT / "tmp" / "inventory_icon_tests"
        sandbox_tmp.mkdir(parents=True, exist_ok=True)
        self.temp_root = sandbox_tmp / self._testMethodName
        shutil.rmtree(self.temp_root, ignore_errors=True)
        self.temp_root.mkdir()
        self.source_dir = self.temp_root / "source"
        self.output_dir = self.temp_root / "output"
        self.catalog_path = self.temp_root / "catalog.gd"
        self.source_dir.mkdir()

    def tearDown(self):
        shutil.rmtree(self.temp_root, ignore_errors=True)

    def _write_catalog(self, recipe_ids):
        recipe_lines = "\n".join(
            f'\t"{recipe_id}": {{"id": "{recipe_id}"}},'
            for recipe_id in recipe_ids
        )
        self.catalog_path.write_text(
            "const RECIPES := {\n"
            f"{recipe_lines}\n"
            "}\n\n"
            "const PROCESSING_RECIPES := {\n}\n",
            encoding="utf-8",
        )

    def test_scales_full_512_canvas_to_80_without_touching_source(self):
        module = _load_generator_module()
        self.assertIsNotNone(module, "inventory icon generator script should exist")
        self._write_catalog(["sample_recipe"])
        source = self.source_dir / "sample_recipe.png"
        image = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
        image.paste((220, 40, 60, 255), (128, 128, 384, 384))
        image.save(source)
        original = source.read_bytes()

        generated = module.generate_inventory_icons(
            self.source_dir,
            self.output_dir,
            self.catalog_path,
        )

        self.assertEqual(generated, [self.output_dir / "sample_recipe.png"])
        with Image.open(generated[0]) as result:
            self.assertEqual(result.size, (80, 80))
            self.assertEqual(result.mode, "RGBA")
            self.assertEqual(result.getpixel((40, 40)), (220, 40, 60, 255))
            self.assertEqual(result.getpixel((5, 5)), (0, 0, 0, 0))
            self.assertGreater(result.getpixel((20, 40))[3], 0)
            self.assertEqual(result.getpixel((10, 40))[3], 0)
        self.assertEqual(source.read_bytes(), original)

    def test_rejects_non_512_source_without_replacing_existing_output(self):
        module = _load_generator_module()
        self.assertIsNotNone(module, "inventory icon generator script should exist")
        self._write_catalog(["sample_recipe"])
        Image.new("RGBA", (256, 512), (20, 40, 60, 255)).save(
            self.source_dir / "sample_recipe.png"
        )
        self.output_dir.mkdir()
        existing = self.output_dir / "keep.png"
        existing.write_bytes(b"existing-output")

        with self.assertRaisesRegex(ValueError, "must be 512x512"):
            module.generate_inventory_icons(
                self.source_dir,
                self.output_dir,
                self.catalog_path,
            )

        self.assertEqual(existing.read_bytes(), b"existing-output")
        self.assertEqual(list(self.output_dir.iterdir()), [existing])

    def test_uses_explicit_alias_for_legacy_recipe_icon_name(self):
        module = _load_generator_module()
        self.assertIsNotNone(module, "inventory icon generator script should exist")
        self._write_catalog(["rice_milk_drink"])
        alias = self.source_dir / "rice_milk_drink_icon_512_alpha_1x2.png"
        Image.new("RGBA", (512, 512), (80, 100, 120, 255)).save(alias)

        generated = module.generate_inventory_icons(
            self.source_dir,
            self.output_dir,
            self.catalog_path,
        )

        self.assertEqual(generated, [self.output_dir / "rice_milk_drink.png"])
        with Image.open(generated[0]) as result:
            self.assertEqual(result.size, (80, 80))
            self.assertEqual(result.getpixel((40, 40)), (80, 100, 120, 255))

    def test_successful_regeneration_preserves_godot_import_sidecars(self):
        module = _load_generator_module()
        self.assertIsNotNone(module, "inventory icon generator script should exist")
        self._write_catalog(["sample_recipe"])
        Image.new("RGBA", (512, 512), (20, 40, 60, 255)).save(
            self.source_dir / "sample_recipe.png"
        )
        self.output_dir.mkdir()
        sidecar = self.output_dir / "sample_recipe.png.import"
        sidecar.write_text("godot-import-metadata", encoding="utf-8")

        module.generate_inventory_icons(
            self.source_dir,
            self.output_dir,
            self.catalog_path,
        )

        self.assertEqual(sidecar.read_text(encoding="utf-8"), "godot-import-metadata")


if __name__ == "__main__":
    unittest.main()
