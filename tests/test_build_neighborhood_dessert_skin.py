from __future__ import annotations

import importlib.util
from pathlib import Path
import sys
import unittest


REPO_ROOT = Path(__file__).resolve().parents[1]
BUILDER_PATH = REPO_ROOT / "tools" / "build_neighborhood_dessert_skin.py"


def load_builder():
    spec = importlib.util.spec_from_file_location("build_neighborhood_dessert_skin", BUILDER_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Unable to load {BUILDER_PATH}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


class RedButtonSkinBuilderTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.builder = load_builder()

    def test_red_button_source_mapping_uses_skin_v1_assets(self) -> None:
        for state in ("normal", "hover", "pressed", "selected", "disabled"):
            expected = REPO_ROOT / "resources" / "ui" / "skin_v1" / f"button_red_{state}_v1.png"
            self.assertEqual(self.builder.source_path("button_red", state), expected)

    def test_red_button_states_share_normalized_geometry(self) -> None:
        family = self.builder.FAMILIES["button_red"]
        built = self.builder.build_family("button_red", family)

        self.assertEqual(set(built), set(family.states))
        self.assertEqual({image.size for image in built.values()}, {family.output_size})
        self.assertEqual(
            {image.getchannel("A").getbbox() for image in built.values()},
            {(0, 0, family.output_size[0], family.output_size[1])},
        )

    def test_red_button_outputs_clear_hidden_rgb(self) -> None:
        family = self.builder.FAMILIES["button_red"]
        built = self.builder.build_family("button_red", family)

        for state, image in built.items():
            for red, green, blue, alpha in image.get_flattened_data():
                if alpha == 0:
                    self.assertEqual(
                        (red, green, blue),
                        (0, 0, 0),
                        f"{state} contains hidden RGB below fully transparent pixels",
                    )


if __name__ == "__main__":
    unittest.main()
