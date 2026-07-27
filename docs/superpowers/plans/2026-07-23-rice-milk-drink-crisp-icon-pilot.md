# Rice Milk Drink Crisp Icon Pilot Implementation Plan

## Goal

Generate a visually sharper `rice_milk_drink` three-stage pilot at each UI surface's logical pixel size while leaving the 1024 source art and every other recipe unchanged.

## Task 1: Make ordinary runtime icon output match UI sizes

Update `tools/install_staged_recipe_icons.py` so base, catalog, inventory, and action outputs are 128, 112, 80, and 32 pixels. Add one RGB-only post-resize sharpening helper with per-surface strength and preserve the resized alpha channel exactly.

Update `tests/test_install_staged_recipe_icons.py` to verify the new dimensions, source hashes, alpha preservation across sharpening, and atomic failure behavior.

## Task 2: Support incremental mixed-size showcase output

Update `tools/generate_staged_showcase_recipe_icons.py` to accept a selected cell size and a preserve-existing mode. Record `cell_size` per manifest entry, calculate canvas extents and regions from that value, and preserve every non-selected recipe byte-for-byte. Keep matching Godot import sidecars and remove obsolete selected-recipe sidecars.

Render the selected subject into the largest occupied rectangle, retain a proportional transparent inset, and sharpen RGB after downsampling without modifying alpha.

Update `tests/test_generate_staged_showcase_recipe_icons.py` for 72-pixel regions, incremental manifest merging, non-selected file preservation, rotation, irregular footprints, and source immutability.

## Task 3: Update asset audits for per-entry cell size

Update `tests/test_staged_recipe_icon_assets.py` for the new ordinary target sizes. Update `tests/test_staged_showcase_icon_assets.py` to use each entry's `cell_size`, defaulting to the manifest-level value for legacy entries.

## Task 4: Generate only the pilot assets

Run the ordinary installer with only `--recipe-id rice_milk_drink`.

Run the showcase generator with only `--recipe-id rice_milk_drink`, `--cell-size 72`, and preserve-existing mode. Confirm the other nine recipe file hashes and manifest entries are unchanged.

Run Godot import with a writable `--log-file`.

## Task 5: Verify runtime and visual quality

Run Python generator and asset tests. Run recipe icon service, catalog, inventory, showcase icon service, stage-aware main-path, drag-preview, showcase distribution, and MVP Godot checks.

Inspect all three ordinary stages and representative 0°/90° showcase outputs. Produce a concise old/new comparison for user review, including exact canvas and alpha-bounds measurements. Run `git diff --check` and confirm no non-pilot recipe binary changed.
