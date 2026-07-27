import importlib.util
import shutil
import unittest
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SCRIPT_PATH = ROOT / "tools" / "generate_action_recipe_icons.py"


def _load_generator_module():
	if not SCRIPT_PATH.exists():
		return None
	spec = importlib.util.spec_from_file_location("generate_action_recipe_icons", SCRIPT_PATH)
	module = importlib.util.module_from_spec(spec)
	assert spec.loader is not None
	spec.loader.exec_module(module)
	return module


class GenerateActionRecipeIconsTest(unittest.TestCase):
	def setUp(self):
		sandbox_tmp = ROOT / "tmp" / "action_icon_tests"
		sandbox_tmp.mkdir(parents=True, exist_ok=True)
		self.temp_root = sandbox_tmp / self._testMethodName
		shutil.rmtree(self.temp_root, ignore_errors=True)
		self.temp_root.mkdir()
		self.source_dir = self.temp_root / "source"
		self.output_dir = self.temp_root / "output"
		self.source_dir.mkdir()

	def tearDown(self):
		shutil.rmtree(self.temp_root, ignore_errors=True)

	def test_generates_32_square_rgba_icons_without_touching_sources(self):
		module = _load_generator_module()
		self.assertIsNotNone(module, "action icon generator script should exist")
		sources = []
		for name, color in (("first.png", (20, 40, 60, 128)), ("second.png", (80, 100, 120, 255))):
			path = self.source_dir / name
			Image.new("RGBA", (512, 512), color).save(path)
			sources.append(path)
		originals = {path: path.read_bytes() for path in sources}

		generated = module.generate_action_icons(self.source_dir, self.output_dir)

		self.assertEqual(generated, [self.output_dir / "first.png", self.output_dir / "second.png"])
		for output_path in generated:
			with Image.open(output_path) as result:
				self.assertEqual(result.size, (32, 32))
				self.assertEqual(result.mode, "RGBA")
		for source_path, original in originals.items():
			self.assertEqual(source_path.read_bytes(), original)


if __name__ == "__main__":
	unittest.main()

