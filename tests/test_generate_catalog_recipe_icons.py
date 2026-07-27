import importlib.util
import shutil
import unittest
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SCRIPT_PATH = ROOT / "tools" / "generate_catalog_recipe_icons.py"


def _load_generator_module():
    if not SCRIPT_PATH.exists():
        return None
    spec = importlib.util.spec_from_file_location("generate_catalog_recipe_icons", SCRIPT_PATH)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


class GenerateCatalogRecipeIconsTest(unittest.TestCase):
    def setUp(self):
        sandbox_tmp = ROOT / "tmp" / "catalog_icon_tests"
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
            f'\t"{recipe_id}": {{"id": "{recipe_id}"}},' for recipe_id in recipe_ids
        )
        self.catalog_path.write_text(
            "const RECIPES := {\n"
            f"{recipe_lines}\n"
            "}\n\n"
            "const PROCESSING_RECIPES := {\n}\n",
            encoding="utf-8",
        )

    def test_generates_132_square_rgba_icon_without_touching_source(self):
        module = _load_generator_module()
        self.assertIsNotNone(module, "generator script should exist")
        self._write_catalog(["sample_recipe"])
        source = self.source_dir / "sample_recipe.png"
        Image.new("RGBA", (512, 512), (20, 40, 60, 128)).save(source)
        original = source.read_bytes()

        generated = module.generate_catalog_icons(
            self.source_dir,
            self.output_dir,
            self.catalog_path,
        )

        self.assertEqual(generated, [self.output_dir / "sample_recipe.png"])
        with Image.open(generated[0]) as result:
            self.assertEqual(result.size, (132, 132))
            self.assertEqual(result.mode, "RGBA")
            pixel = result.getpixel((66, 66))
            self.assertLessEqual(abs(pixel[0] - 20), 1)
            self.assertLessEqual(abs(pixel[1] - 40), 1)
            self.assertLessEqual(abs(pixel[2] - 60), 1)
            self.assertEqual(pixel[3], 128)
        self.assertEqual(source.read_bytes(), original)

    def test_uses_explicit_alias_for_legacy_recipe_icon_name(self):
        module = _load_generator_module()
        self.assertIsNotNone(module, "generator script should exist")
        self._write_catalog(["baked_rice_cake"])
        aliased_source = self.source_dir / "baked_rice_cake_icon_512_alpha_2x1.png"
        Image.new("RGBA", (512, 512), (80, 100, 120, 255)).save(aliased_source)

        generated = module.generate_catalog_icons(
            self.source_dir,
            self.output_dir,
            self.catalog_path,
        )

        self.assertEqual(generated, [self.output_dir / "baked_rice_cake.png"])
        with Image.open(generated[0]) as result:
            self.assertEqual(result.size, (132, 132))
            self.assertEqual(result.getpixel((66, 66)), (80, 100, 120, 255))


if __name__ == "__main__":
    unittest.main()
