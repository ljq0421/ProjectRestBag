from __future__ import annotations

import argparse
import sys
from pathlib import Path

from PIL import Image


ACTION_ICON_SIZE = (32, 32)


def generate_action_icons(source_dir: Path, output_dir: Path) -> list[Path]:
	source_paths = sorted(source_dir.glob("*.png"))
	if not source_paths:
		raise FileNotFoundError(f"no source icons found in {source_dir}")

	output_dir.mkdir(parents=True, exist_ok=True)
	generated: list[Path] = []
	for source_path in source_paths:
		output_path = output_dir / source_path.name
		with Image.open(source_path) as image:
			rgba = image.convert("RGBA")
			resized = rgba.resize(ACTION_ICON_SIZE, Image.Resampling.LANCZOS)
			resized.save(output_path, format="PNG", optimize=True)
		generated.append(output_path)
	return generated


def _parse_args() -> argparse.Namespace:
	parser = argparse.ArgumentParser(description="Generate 32x32 recipe action-row icons.")
	parser.add_argument("--source-dir", type=Path, required=True)
	parser.add_argument("--output-dir", type=Path, required=True)
	return parser.parse_args()


def main() -> int:
	args = _parse_args()
	try:
		generated = generate_action_icons(
			args.source_dir.resolve(),
			args.output_dir.resolve(),
		)
	except FileNotFoundError as error:
		print(error, file=sys.stderr)
		return 1
	print(f"generated {len(generated)} action-row icons")
	return 0


if __name__ == "__main__":
	raise SystemExit(main())

