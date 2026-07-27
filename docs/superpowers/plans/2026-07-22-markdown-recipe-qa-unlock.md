# Markdown Recipe QA Unlock Implementation Plan

> **Scope:** `D:\Project\ProjectRest\project-rest-new` only.

**Goal:** Pressing `Ctrl + Alt + U` in a debug build reads a fixed Markdown manifest, unlocks the listed recipes plus only the prerequisites needed to use the normal catalog, crafting, inventory, drag, and listing flow, persists the changes to the current save, and reports missing runtime icon assets.

**Architecture:** Add a focused `DevRecipeUnlockImporter` service for parsing, dependency planning, state snapshots, plan application, rollback, and asset auditing. Keep `main_view.gd` responsible only for the debug key binding, save orchestration, UI refresh, and visible summary. Reuse existing `GameState`, `CoreFeatureUnlockService`, `RecipeBook`, inventory drag, and showcase placement paths instead of adding QA-only gameplay paths.

**Verification:** Add parser/planner unit-style headless coverage and a scene-level end-to-end self-check, then run focused catalog, production, inventory, showcase, and core-feature regressions with an explicit writable Godot log path.

---

## Task 1: Add the fixed manifest contract and Markdown parser

**Files:**

- Add: `doc/recipe_icon_preview_manifest.md`
- Add: `scripts/dev_recipe_unlock_importer.gd`
- Add: `tests/markdown_recipe_unlock_importer_self_check.gd`

**Steps:**

1. Create a focused self-check that calls a parser with in-memory Markdown containing:
   - a whole-line bare recipe ID with surrounding whitespace;
   - a base icon path;
   - `_popular` and `_signature` icon paths;
   - a heading ending in a recipe ID;
   - repeated recipe IDs;
   - material and device IDs inside prose or code blocks;
   - an unknown snake-case ID.
2. Assert that the parser returns only Catalog recipe IDs, strips supported growth suffixes, preserves first-seen order, deduplicates results, and reports explicit invalid candidates separately.
3. Run the self-check and confirm it fails because the importer does not exist yet.
4. Implement `DevRecipeUnlockImporter` as a `RefCounted` service with a narrow public API:
   - `parse_markdown_text(text, recipes)`;
   - `parse_manifest(path, recipes)`.
5. Match only whole-line bare recipe IDs, canonical `resources/recipe_icons/<name>.png` paths, and heading-terminal parenthesized IDs. Bare IDs may have surrounding whitespace but must occupy the entire line; do not accept list markers or scan arbitrary snake-case tokens from prompt bodies.
6. Validate every normalized candidate against the supplied recipe dictionary before adding it to `recipe_ids`.
7. Return a structured result containing at least `ok`, `recipe_ids`, `ignored_ids`, and `errors`.
8. Add `doc/recipe_icon_preview_manifest.md` with concise usage instructions and no default recipe IDs, so a fresh checkout does not unlock anything until the user supplies a list.
9. Run the parser self-check and require `MARKDOWN_RECIPE_UNLOCK_IMPORTER_SELF_CHECK_PASS`.

**Commit boundary:** parser, manifest contract, and parser tests.

## Task 2: Build the recursive prerequisite and icon-audit plan

**Files:**

- Modify: `scripts/dev_recipe_unlock_importer.gd`
- Modify: `tests/markdown_recipe_unlock_importer_self_check.gd`

**Steps:**

1. Add failing assertions for a high-level recipe with a processed ingredient, using `matcha_pudding` as the primary fixture.
2. Build a reverse lookup from `Catalog.get_processing_recipes()` keyed by `output_item_id`.
3. Recursively collect, in deterministic order:
   - target recipes;
   - recipe-valued material dependencies, if the current catalog introduces any;
   - each recipe's production device;
   - processing recipes required by ingredient outputs;
   - processing devices and processing inputs;
   - process unlock output IDs;
   - purchase unlock output IDs only when the ingredient explicitly declares a non-empty `purchase_unlock_condition`;
   - the maximum `unlock_level` across target recipes, recipe dependencies, ingredients, and processing recipes.
4. Explicitly unlock devices through the device ledger. Do not include device `unlock_level=999` sentinel values in the required shop-level calculation.
5. If a target has a missing recipe, ingredient, processing, or device dependency, mark that target as invalid and exclude its incomplete dependency branch without discarding other valid targets.
6. Produce a plan dictionary containing at least:
   - `target_recipe_ids`;
   - `recipe_ids`;
   - `device_ids`;
   - `process_unlock_ids`;
   - `purchase_unlock_ids`;
   - `required_level`;
   - `invalid_targets`;
   - `missing_assets`.
7. Audit the real runtime icon surfaces for every valid target:
   - `resources/recipe_icons/<id>.png`;
   - `resources/recipe_icons_catalog/<id>.png`;
   - `resources/recipe_icons_action/<id>.png`;
   - `resources/recipe_icons_inventory/<id>.png`;
   - standard-layout entries and referenced textures in `resources/recipe_icons_showcase/showcase_icon_manifest.json`.
8. Treat asset failures as report entries, not plan failures.
9. Extend the self-check to assert that `matcha_pudding` requires shop level 5, `chiller`, `grinder`, and the `matcha` process permission, while it does not fabricate a purchase permission absent from Catalog.

**Commit boundary:** dependency planner, asset audit, and planner tests.

## Task 3: Apply plans atomically to the real GameState

**Files:**

- Modify: `scripts/dev_recipe_unlock_importer.gd`
- Modify: `tests/markdown_recipe_unlock_importer_self_check.gd`

**Steps:**

1. Add failing assertions for plan application against `GameState.new_game()`.
2. Implement snapshot helpers covering:
   - `level`;
   - `core_feature_unlocks`;
   - `unlocked_devices`;
   - `device_growth`;
   - `ingredient_purchase_unlocks`;
   - `ingredient_process_unlocks`;
   - `unlocked_recipes`;
   - `feedback_log`.
3. Implement `apply_plan(state, plan)` in this order:
   - raise `state.level` to `required_level`, never lower it;
   - iterate `CoreFeatureUnlockService.ORDER` and call `state.unlock_core_feature()` through `CoreFeatureUnlockService.LIST` only;
   - call `state.unlock_device()` for required devices;
   - call `state.unlock_ingredient_process()` for required processed outputs;
   - call `state.unlock_ingredient_purchase()` only for planner-approved purchase outputs;
   - call `state.add_recipe(recipe_id, false)` for dependency and target recipes.
4. Return counts for added, already-present, rejected, and automatically added prerequisites. Do not call research, tutorial, task-event, reward, inventory-grant, or growth APIs.
5. Implement `restore_snapshot(state, snapshot)` for save-failure rollback.
6. Assert that plan application:
   - unlocks core features through `LIST` and no further;
   - leaves tutorial, tasks, pending notifications, inventory, coins, recipe growth, and running production/business data unchanged;
   - is idempotent on a second application;
   - appends no duplicate unlock logs on the second application.
7. Save the mutated fixture through `SaveSystem`, reload it, and assert the level, core permissions, devices, ingredient process permissions, and recipes persist.

**Commit boundary:** atomic state application, rollback helpers, and persistence tests.

## Task 4: Wire the debug-only Ctrl+Alt+U import into the main scene

**Files:**

- Modify: `scripts/main_view.gd`
- Add: `tests/markdown_recipe_unlock_scene_self_check.gd`

**Steps:**

1. Add a preload for `DevRecipeUnlockImporter` and a configurable `recipe_qa_manifest_path` defaulting to `res://doc/recipe_icon_preview_manifest.md`. The configurable property exists only so tests can point to an isolated temporary manifest.
2. Handle a pressed, non-echo `Ctrl + Alt + KEY_U` event before the existing mouse-only branches in `_input()`. Do not capture `F8`, because the Godot editor reserves it for stopping the running project.
3. Guard the shortcut with `OS.is_debug_build()` and consume the event only when the importer actually handles it.
4. Put the orchestration in a directly testable method such as `_run_recipe_qa_unlock_import(path)`:
   - parse the manifest;
   - build the plan;
   - stop before mutation when no legal targets exist;
   - snapshot state;
   - apply the plan;
   - save once through `_save_game()`;
   - restore the snapshot if save fails;
   - refresh the UI;
   - return the structured result.
5. After success or rollback, refresh:
   - `_refresh_core_feature_access()`;
   - `_refresh_current_page()`;
   - the catalog overlay when open;
   - the inventory overlay when open;
   - storefront visuals and current popup content through their existing refresh methods.
6. Show one compact status summary containing target, added, existing, prerequisite, level, ignored-ID, missing-asset, and save counts. Do not queue one notification per recipe or open research-result dialogs.
7. In the scene self-check, instantiate `Main.tscn` with temporary save and manifest paths, invoke the orchestration method, and assert:
   - the normal catalog renders a target recipe as unlocked;
   - the normal production list includes the target recipe;
   - the workbench permissions expose inventory and catalog while post-`LIST` features remain locked;
   - the status label contains a successful import summary.
8. Point the same fixture at a save path inside a nonexistent directory, assert save failure, and verify every snapshotted state field is restored.

**Commit boundary:** Ctrl+Alt+U integration, UI refresh, visible feedback, and scene-level rollback coverage.

## Task 5: Prove the normal craft-to-inventory-to-showcase path

**Files:**

- Modify: `tests/markdown_recipe_unlock_scene_self_check.gd`
- Modify an existing test only if a newly exposed regression requires it; prefer reusing helpers from current production, inventory, and showcase self-checks without changing their contracts.

**Steps:**

1. Use the imported fixture state rather than directly calling `add_recipe()` for the target under test.
2. Add exactly the real materials required by the target recipe to the test inventory.
3. Start production through `RecipeBook.make_product()` or the existing main-view button handler, not by directly adding a product.
4. Advance the existing manual production queue to completion and assert the output enters `product_inventory`.
5. Build the inventory cell through `_make_inventory_cell()` and assert its drag data uses `kind=inventory_product`, the correct `recipe_id`, and the real configured shape.
6. Use the existing showcase placement validation with the imported `LIST` permission, real product stock, configured shape cells, and an unlocked showcase region.
7. Apply the existing listing path and assert product stock decreases while the corresponding display item appears in the showcase state.
8. Re-run the import and confirm the ongoing product inventory and display item remain unchanged.

**Commit boundary:** end-to-end normal gameplay proof.

## Task 6: Run focused verification and inspect the diff

**Files:**

- No planned production-file changes beyond the files above.

**Commands:**

Run each Godot test from `D:\Project\ProjectRest\project-rest-new` with an explicit writable log path:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\markdown-recipe-unlock-importer.log" -s res://tests/markdown_recipe_unlock_importer_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\markdown-recipe-unlock-scene.log" -s res://tests/markdown_recipe_unlock_scene_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\recipe-production-ui.log" -s res://tests/recipe_production_ui_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\inventory-recipe-icon-layout.log" -s res://tests/inventory_recipe_icon_layout_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\catalog-icon-layout.log" -s res://tests/catalog_icon_layout_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\showcase-initial-multicell.log" -s res://tests/showcase_initial_multicell_interaction_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\core-feature-lock-ui.log" -s res://tests/core_feature_lock_ui_self_check.gd
```

Then run the project parse and diff checks:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\markdown-recipe-unlock-project.log" --quit
git diff --check
git status --short
```

**Final inspection:**

1. Confirm the shortcut is debug-only and no release-visible button or menu was added.
2. Confirm normal recipe research, tutorial, task, reward, crafting, inventory, and showcase code paths were not replaced.
3. Confirm the fixed manifest is the only user-edited input surface.
4. Confirm unrelated dirty-worktree changes in scenes, UI assets, showcase behavior, and tests remain untouched.
5. Confirm the final diff contains only the approved importer, manifest, main-view hook, tests, and documentation.
