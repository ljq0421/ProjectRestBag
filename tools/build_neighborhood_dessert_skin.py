#!/usr/bin/env python3
"""Build aligned runtime textures for the neighborhood dessert Godot theme."""

from __future__ import annotations

import argparse
from dataclasses import dataclass
from pathlib import Path
import sys

from PIL import Image


REPO_ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = REPO_ROOT / "resources" / "ui" / "skin" / "neighborhood_dessert"
OUTPUT_DIR = SOURCE_DIR / "runtime"
SOURCE_PADDING = 4
SOURCE_OVERRIDES = {
    "panel_v1": REPO_ROOT / "resources" / "ui" / "skin_v1" / "panel_v1.png",
}
STATE_SOURCE_OVERRIDES = {
    "button_red": {
        state: REPO_ROOT
        / "resources"
        / "ui"
        / "skin_v1"
        / f"button_red_{state}_v1.png"
        for state in ("normal", "hover", "pressed", "selected", "disabled")
    },
}


@dataclass(frozen=True)
class Family:
    states: tuple[str, ...]
    output_size: tuple[int, int]
    rotate_clockwise: bool = False
    normalize_alpha_bounds: bool = False


FAMILIES: dict[str, Family] = {
    "button_primary": Family(("normal", "hover", "pressed", "disabled"), (144, 40)),
    "button_secondary": Family(("normal", "hover", "pressed", "disabled"), (144, 40)),
    "button_flat": Family(("normal", "hover", "pressed", "disabled"), (144, 36)),
    "button_icon": Family(("normal", "hover", "pressed", "disabled"), (40, 40)),
    "button_danger": Family(("normal", "hover", "pressed", "disabled"), (144, 40)),
    "button_red": Family(
        ("normal", "hover", "pressed", "selected", "disabled"),
        (154, 40),
        normalize_alpha_bounds=True,
    ),
    "tab_top": Family(("normal", "hover", "selected", "disabled"), (144, 40)),
    "panel_main": Family(("normal",), (320, 200)),
    "panel_section": Family(("normal",), (280, 160)),
    "panel_inset": Family(("normal",), (280, 160)),
    "panel_modal": Family(("normal",), (320, 200)),
    "panel_v1": Family(("",), (320, 181)),
    "slot_item": Family(
        ("normal", "hover", "selected", "locked", "disabled", "reward"),
        (80, 80),
    ),
    "status_tag": Family(("normal", "positive"), (64, 20)),
    "input_text": Family(("normal", "focus", "error", "disabled"), (180, 40)),
    "input_dropdown": Family(("normal", "focus", "error", "disabled"), (180, 40)),
    "input_number": Family(("normal", "focus", "error", "disabled"), (144, 40)),
    "toggle": Family(("off", "on", "hover", "disabled"), (72, 36)),
    "progress_track": Family(("",), (144, 16)),
    "progress_fill_green": Family(("",), (144, 16)),
    "panel_popup": Family(("normal",), (220, 180)),
    "tooltip_bubble": Family(("normal",), (180, 72)),
    "status_tag_extended": Family(("normal", "positive", "warning", "negative"), (96, 28)),
    "scrollbar_track": Family(("",), (8, 120)),
    "scrollbar_thumb": Family(("normal", "hover", "pressed", "disabled"), (8, 48)),
    "scrollbar_track_horizontal": Family(("",), (120, 18), rotate_clockwise=True),
    "scrollbar_thumb_horizontal": Family(
        ("normal", "hover", "pressed", "disabled"),
        (48, 18),
        rotate_clockwise=True,
    ),
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--check",
        action="store_true",
        help="Validate existing runtime outputs without rewriting them.",
    )
    return parser.parse_args()


def source_path(family_name: str, state: str) -> Path:
    if family_name in STATE_SOURCE_OVERRIDES:
        state_overrides = STATE_SOURCE_OVERRIDES[family_name]
        if state not in state_overrides:
            raise ValueError(f"missing source override state: {family_name}/{state}")
        return state_overrides[state]
    if family_name in SOURCE_OVERRIDES:
        if state:
            raise ValueError(f"source override does not support states: {family_name}/{state}")
        return SOURCE_OVERRIDES[family_name]
    source_family_name = family_name.removesuffix("_horizontal").removesuffix("_extended")
    filename = source_family_name if not state else f"{source_family_name}_{state}"
    return SOURCE_DIR / f"{filename}.png"


def output_path(family_name: str, state: str) -> Path:
    filename = family_name if not state else f"{family_name}_{state}"
    return OUTPUT_DIR / f"{filename}.png"


def load_family_sources(family_name: str, family: Family) -> dict[str, Image.Image]:
    images: dict[str, Image.Image] = {}
    canvas_size: tuple[int, int] | None = None
    for state in family.states:
        path = source_path(family_name, state)
        if not path.is_file():
            raise ValueError(f"missing source: {path}")
        with Image.open(path) as source:
            if "A" not in source.getbands():
                raise ValueError(f"source lacks alpha: {path}")
            image = source.convert("RGBA")
        if canvas_size is None:
            canvas_size = image.size
        elif image.size != canvas_size:
            raise ValueError(
                f"source canvas mismatch in {family_name}: {image.size} != {canvas_size}"
            )
        if image.getchannel("A").getbbox() is None:
            raise ValueError(f"source is fully transparent: {path}")
        images[state] = image
    return images


def union_alpha_bbox(images: dict[str, Image.Image]) -> tuple[int, int, int, int]:
    boxes = [image.getchannel("A").getbbox() for image in images.values()]
    valid_boxes = [box for box in boxes if box is not None]
    left = min(box[0] for box in valid_boxes)
    top = min(box[1] for box in valid_boxes)
    right = max(box[2] for box in valid_boxes)
    bottom = max(box[3] for box in valid_boxes)
    width, height = next(iter(images.values())).size
    return (
        max(0, left - SOURCE_PADDING),
        max(0, top - SOURCE_PADDING),
        min(width, right + SOURCE_PADDING),
        min(height, bottom + SOURCE_PADDING),
    )


def clear_fully_transparent_rgb(image: Image.Image) -> Image.Image:
    red, green, blue, alpha = image.convert("RGBA").split()
    visible_mask = alpha.point(lambda value: 255 if value > 0 else 0)
    empty_channel = Image.new("L", image.size, 0)
    return Image.merge(
        "RGBA",
        (
            Image.composite(red, empty_channel, visible_mask),
            Image.composite(green, empty_channel, visible_mask),
            Image.composite(blue, empty_channel, visible_mask),
            alpha,
        ),
    )


def resize_flat_center(image: Image.Image, target_size: tuple[int, int]) -> Image.Image:
    alpha_bbox = image.getchannel("A").getbbox()
    if alpha_bbox is None:
        raise ValueError("cannot normalize a fully transparent image")

    cropped = image.crop(alpha_bbox)
    target_width, target_height = target_size
    scaled_width = max(1, round(cropped.width * target_height / cropped.height))
    scaled = cropped.resize((scaled_width, target_height), Image.Resampling.LANCZOS)
    if scaled_width == target_width:
        return clear_fully_transparent_rgb(scaled)

    center_x = scaled_width // 2
    center_half_width = min(8, max(1, scaled_width // 8))
    center_left = center_x - center_half_width
    center_right = center_x + center_half_width
    left = scaled.crop((0, 0, center_left, target_height))
    center = scaled.crop((center_left, 0, center_right, target_height))
    right = scaled.crop((center_right, 0, scaled_width, target_height))
    target_center_width = target_width - left.width - right.width
    if target_center_width <= 0:
        raise ValueError(
            f"target width {target_width} is too small for preserved button caps"
        )

    normalized = Image.new("RGBA", target_size, (0, 0, 0, 0))
    normalized.paste(left, (0, 0))
    normalized.paste(
        center.resize((target_center_width, target_height), Image.Resampling.LANCZOS),
        (left.width, 0),
    )
    normalized.paste(right, (left.width + target_center_width, 0))
    return clear_fully_transparent_rgb(normalized)


def build_family(family_name: str, family: Family) -> dict[str, Image.Image]:
    sources = load_family_sources(family_name, family)
    if family.normalize_alpha_bounds:
        return {
            state: resize_flat_center(image, family.output_size)
            for state, image in sources.items()
        }
    crop_box = union_alpha_bbox(sources)
    return {
        state: (
            image.crop(crop_box)
            .transpose(Image.Transpose.ROTATE_270)
            .resize(family.output_size, Image.Resampling.LANCZOS)
            if family.rotate_clockwise
            else image.crop(crop_box).resize(family.output_size, Image.Resampling.LANCZOS)
        )
        for state, image in sources.items()
    }


def validate_outputs(family_name: str, family: Family) -> None:
    sizes: set[tuple[int, int]] = set()
    alpha_boxes: set[tuple[int, int, int, int] | None] = set()
    for state in family.states:
        path = output_path(family_name, state)
        if not path.is_file():
            raise ValueError(f"missing runtime output: {path}")
        with Image.open(path) as source:
            if source.mode != "RGBA":
                raise ValueError(f"runtime output must be RGBA: {path}")
            sizes.add(source.size)
            alpha_boxes.add(source.getchannel("A").getbbox())
    if sizes != {family.output_size}:
        raise ValueError(f"runtime size mismatch in {family_name}: {sorted(sizes)}")
    if len(alpha_boxes) != 1:
        raise ValueError(
            f"runtime alpha alignment mismatch in {family_name}: {sorted(alpha_boxes)}"
        )


def build_all() -> None:
    built: dict[str, dict[str, Image.Image]] = {}
    for family_name, family in FAMILIES.items():
        built[family_name] = build_family(family_name, family)

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    for family_name, states in built.items():
        for state, image in states.items():
            image.save(output_path(family_name, state), format="PNG", optimize=True)
        print(f"built {family_name}: {len(states)} state(s)")


def check_all() -> None:
    for family_name, family in FAMILIES.items():
        validate_outputs(family_name, family)
    print("NEIGHBORHOOD_DESSERT_RUNTIME_SKIN_CHECK_PASS")


def main() -> int:
    args = parse_args()
    try:
        if not args.check:
            build_all()
        check_all()
    except (OSError, ValueError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
