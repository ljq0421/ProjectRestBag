# Stage-Aware Showcase Icon Pack Implementation Plan

**Goal:** Make the ten staged recipe icon sets appear after listing while preserving showcase shapes, variants, rotations, drag preview, and fallback to existing showcase art.

**Scope guard:** Add a separate staged showcase directory and manifest. Do not rewrite or delete `resources/recipe_icons_showcase` or its manifest.

## Task 1: Add the staged showcase generator

**Files:**

- Create `tools/generate_staged_showcase_recipe_icons.py`
- Create `tests/test_generate_staged_showcase_recipe_icons.py`

Reuse the existing showcase generator's cell, variant, rotation, and region helpers. Render each rotated subject with a 4 px transparent safe inset inside the final canvas so no outer edge can crop the artwork. Accept explicit recipe IDs, validate all three source stages before publishing, and generate an isolated manifest.

## Task 2: Extend the showcase icon service

**Files:**

- Modify `scripts/ui/storefront/showcase_icon_service.gd`
- Modify `tests/showcase_icon_service_self_check.gd`

Load the existing manifest plus an optional staged manifest. Add `mastery_level` to layout and fragment lookup. Resolve exact staged level, then staged trial, then existing art. Include the selected entry key in the fragment cache key.

## Task 3: Pass growth stage through the live listing path

**Files:**

- Modify `scripts/main_view.gd`
- Modify the focused showcase runtime self-check

Read current recipe growth for both placed items and drag preview, and pass the level through layout and fragment calls. Assert the atlas resource path changes for stages 0, 1, and 2 without changing occupied cells.

## Task 4: Generate and import the ten-recipe pack

Generate 306 PNG canvases under `resources/recipe_icons_showcase_staged`, write the staged manifest, and run Godot `--import` with a writable log path to produce import sidecars. The current display config produces 102 combinations per stage; this supersedes the stale 95-combination count in the old showcase manifest.

## Task 5: Verify

Run generator tests, staged asset audit, service test, listing/drag tests, existing showcase distribution and interaction tests, and MVP. Visually inspect a 1×1, rotated 1×2, and L-shaped recipe across all three stages. Confirm the old showcase directory has no changes.
