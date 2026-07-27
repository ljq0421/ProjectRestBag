import subprocess
import sys
import unittest
from pathlib import Path


class GenerateRecipeIconPromptsTest(unittest.TestCase):
    def test_generates_markdown_from_prompt_config_and_project_sources(self):
        root = Path(__file__).resolve().parents[1]
        script = root / 'tools' / 'generate_recipe_icon_prompts.py'
        tmp_root = root / 'tmp'
        tmp_root.mkdir(exist_ok=True)

        output_path = tmp_root / 'test_generated_recipe_icon_prompts.md'
        result = subprocess.run(
            [
                sys.executable,
                str(script),
                '--limit',
                '3',
                '--out',
                str(output_path),
            ],
            cwd=root,
            text=True,
            capture_output=True,
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        text = output_path.read_text(encoding='utf-8')

        self.assertIn('# Recipe Icon Prompts', text)
        self.assertIn('## rice_milk_drink - ', text)
        self.assertIn('shape:', text)
        self.assertIn('vertical 2-cell footprint inside a 4x4 grid', text)
        self.assertIn('materials: rice, spring_water, sugar', text)
        self.assertIn('Create a 512x512 game recipe icon', text)
        self.assertIn('Do not draw the grid', text)
        self.assertIn('transparent background preferred', text)
        self.assertIn('not a realistic food photo', text)
        self.assertIn('fully transparent', text)
        self.assertIn('ingredients only as palette, texture, and flavor inspiration', text)
        self.assertIn('Do not draw raw ingredients', text)
        self.assertNotIn('optional subtle ingredient hints', text)
        self.assertNotIn('#ff00ff', text)
        self.assertNotIn('chroma key', text.lower())
        self.assertNotIn('chroma-key', text.lower())
        self.assertNotIn('photorealistic', text.split('## rice_milk_drink - ', 1)[0])

    def test_generates_specific_occupied_cells_for_l_shaped_recipes(self):
        root = Path(__file__).resolve().parents[1]
        script = root / 'tools' / 'generate_recipe_icon_prompts.py'
        tmp_root = root / 'tmp'
        tmp_root.mkdir(exist_ok=True)

        output_path = tmp_root / 'test_generated_l_shape_prompt.md'
        result = subprocess.run(
            [
                sys.executable,
                str(script),
                '--only',
                'beef_baked_pie',
                '--out',
                str(output_path),
            ],
            cwd=root,
            text=True,
            capture_output=True,
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        text = output_path.read_text(encoding='utf-8')

        self.assertIn('## beef_baked_pie - ', text)
        self.assertIn('L-shaped 3-cell footprint', text)
        self.assertIn('occupied grid cells: (1,1), (2,1), (2,2)', text)
        self.assertIn('missing bottom-left cell', text)
        self.assertIn('Do not fill the missing cell', text)


if __name__ == '__main__':
    unittest.main()
