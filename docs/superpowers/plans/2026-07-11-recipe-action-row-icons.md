# Recipe Action Row Icons Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make recipe action-row icons 32x32 and load dedicated, high-quality resized assets from `res://resources/recipe_icons_action/`.

**Architecture:** Keep the original 512x512 files in `resources/recipe_icons` unchanged. A deterministic Pillow/LANCZOS generator creates action-row assets in the new directory, while the row scene owns display geometry and its script owns the dedicated resource path.

**Tech Stack:** Godot 4.6.1, GDScript, Python 3, Pillow.

## Global Constraints

- Work directly on `main`.
- Do not modify files in `res://resources/recipe_icons/`.
- Action-row icons and textures must both be exactly 32x32.

---

### Task 1: Generate and use dedicated action-row icons

**Files:**
- Create: `tools/generate_action_recipe_icons.py`
- Create: `tests/test_generate_action_recipe_icons.py`
- Create: `tests/recipe_action_icon_layout_self_check.gd`
- Create: `resources/recipe_icons_action/*.png`
- Modify: `scenes/ui/pages/recipe_action_row.tscn`
- Modify: `scripts/ui/pages/recipe_action_row.gd`

**Interfaces:**
- Consumes: PNG files from `resources/recipe_icons`.
- Produces: `generate_action_icons(source_dir: Path, output_dir: Path) -> list[Path]` and 32x32 runtime textures under `resources/recipe_icons_action`.

- [x] Write failing Python and Godot checks for LANCZOS output, source preservation, row geometry, and runtime resource path.
- [x] Run both checks and confirm they fail because the generator and 32x32 layout do not exist yet.
- [x] Add the minimal generator, set `RecipeIcon` to 32x32, and load `recipe_icons_action`.
- [x] Generate all action icons without modifying source files.
- [x] Run focused checks and Godot project parse verification.
