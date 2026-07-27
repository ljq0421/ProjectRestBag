# Three-Stage Recipe Icon Runtime Replacement Plan

**Goal:** Install the ten `resources/ui/icons_v1` recipe batches as stage-aware runtime assets and make catalog, inventory, action-row, and research-result UI resolve the current growth stage with safe fallback.

**Scope guard:** Do not change `resources/recipe_icons_showcase`, its manifest, recipe growth rules, or unrelated dirty UI work. Patch `scripts/main_view.gd` only at icon-loading call sites.

## Task 1: Add the batch converter

**Files:**

- Create `tools/install_staged_recipe_icons.py`
- Create `tests/test_install_staged_recipe_icons.py`

Implement explicit `_1/_2/_3` to base/`_popular`/`_signature` mapping, validate all selected inputs before publishing, resize to 512/132/80/32, preserve RGBA, and touch only selected recipe IDs.

Verify with:

```powershell
& $workspacePython -m unittest tests.test_install_staged_recipe_icons
```

## Task 2: Add the runtime resolver

**Files:**

- Create `scripts/recipe_icon_service.gd`
- Create `tests/recipe_icon_service_self_check.gd`

Provide stage suffix and surface directory mapping. Resolve current-stage surface image, surface trial fallback, current-stage base image, then base trial image. Test all stages, all surfaces, fallback ordering, and missing resources.

## Task 3: Pilot `rice_milk_drink` in the catalog

**Files:**

- Modify `scripts/main_view.gd`
- Modify `tests/catalog_icon_layout_self_check.gd`

Generate the pilot assets, route catalog cards through the resolver, set the recipe state to stages 0/1/2, and verify the loaded resource path changes without altering locked-card behavior.

## Task 4: Extend the resolver to remaining UI surfaces

**Files:**

- Modify `scripts/main_view.gd`
- Modify `tests/inventory_recipe_icon_layout_self_check.gd`
- Modify `tests/research_wait_dialog_self_check.gd`
- Add a focused runtime check for action/material icon resolution if existing coverage is insufficient

Replace inventory, action/material, and research-result direct paths with the shared resolver. Keep ingredient icon routing unchanged.

## Task 5: Install all ten recipes

Run the converter for:

```text
baked_rice_cake
caramel_pudding_steamed
chicken_steamed_dumpling
egg_milk_custard
milk_crisp_cake
milk_rice_dew
rice_milk_drink
rich_rice_drink
soft_steamed_egg_cake
white_sugar_rice_ball
```

Add a durable asset audit test for the expected paths, sizes, RGBA mode, and transparent alpha range. Run Godot once to import new dynamic-load PNGs and retain generated `.import` sidecars.

## Task 6: Verify

Run Python tests, the new icon service check, the focused catalog/inventory/action/research checks, and a project parse/import pass. Every Godot headless command must use a writable `--log-file` path.

Inspect `git diff --check`, the owned-file diff, asset counts, and representative rendered icons at 132/80/32 pixels. Confirm no showcase files changed and unrelated dirty files remain untouched.
