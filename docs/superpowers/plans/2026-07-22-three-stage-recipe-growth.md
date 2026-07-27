# Three-Stage Recipe Growth Implementation Plan

> **Scope:** `D:\Project\ProjectRest\project-rest-new` only.

**Goal:** Remove the stable recipe stage and leave one continuous three-stage contract: trial, popular, signature.

**Architecture:** Keep `RecipeGrowthService` as the single source of truth for stage IDs, names, requirements, traits, and masterwork activation. Keep `DeviceGrowthService` as the device-to-recipe ceiling source. Update consumers to read the new continuous IDs `0..2`; do not add save migration or compatibility branches.

**Verification:** Run focused Godot self-check scripts with an explicit writable `--log-file`, run the Python display-config tests and generator check, then perform project parse and diff hygiene checks.

---

## Task 1: Convert the runtime stage model to three continuous IDs

**Files:**

- Modify: `scripts/recipe_growth_service.gd`
- Modify: `scripts/device_growth_service.gd`
- Modify: `game_data.json`

**Steps:**

1. Replace the four mastery constants with `TRIAL=0`, `POPULAR=1`, `SIGNATURE=2` and delete `MASTERY_STABLE`.
2. Define trial-to-popular as `30 batches / 10 effective rounds / 3 synergy rounds / device L3`.
3. Keep popular-to-signature at `40 / 14 / 8 / L5`.
4. Update all clamps, stage names, advancement limits, trait thresholds, bonuses, and masterwork activation to the new IDs.
5. Change device caps from `[1,1,2,2,3]` to `[0,0,1,1,2]` and rewrite player-facing device effects.
6. Change recipe mastery starlight rewards from `1/2/3` to `3/3` at new levels `1/2`, preserving cumulative rewards at popular and signature.

## Task 2: Update runtime consumers and player-facing UI

**Files:**

- Modify: `scripts/main_view.gd`
- Modify: `scripts/ui/overlays/recipe_growth_detail_panel.gd`
- Modify: `scripts/ui/overlays/device_growth_drawer.gd`
- Modify: `scripts/ui/pages/recipe_action_row.gd`
- Modify: `scripts/ui/overlays/showcase_rulebook_dialog.gd`
- Modify: `scenes/ui/overlays/recipe_growth_detail_panel.tscn`
- Modify: `scenes/ui/overlays/device_growth_drawer.tscn`
- Modify: `scenes/ui/pages/recipe_action_row.tscn`

**Steps:**

1. Replace the catalog badge array with `试作/人气/招牌` and clamp to `0..2`.
2. Render exactly three stages in the growth detail track and change completion copy to “三阶段成长已完成”.
3. Count and display only trial, popular, and signature recipes in the device drawer.
4. Rewrite default scene text and rulebook text so no active UI mentions stable or four stages.
5. Preserve the existing uncommitted `DessertRedActionButton` change in `recipe_growth_detail_panel.tscn`.
6. Keep the current immediate recipe promotion check during device upgrade; do not introduce a next-production delay.

## Task 3: Remove stable display configuration and deprecate stable prompt output

**Files:**

- Modify: `tools/generate_recipe_growth_display_config.py`
- Modify: `doc/recipe_display_config.json`
- Modify: `tests/test_recipe_growth_display_config.py`
- Modify: `doc/recipe_growth_icon_prompts_batch_01.md`
- Modify: `doc/recipe_growth_icon_prompts_batch_02.md`
- Modify: `doc/recipe_growth_icon_prompts_batch_04.md`
- Modify: `doc/recipe_growth_icon_prompts_batch_05.md`
- Modify: `doc/recipe_growth_icon_prompts_batch_06.md`
- Modify: `doc/recipe_growth_icon_prompts_batch_07.md`
- Modify: `doc/recipe_growth_icon_prompts_batch_08.md`
- Modify: `doc/recipe_growth_icon_prompts_batch_09.md`
- Modify: `doc/recipe_growth_icon_prompts_batch_10.md`

**Steps:**

1. Generate only `popular` and `signature` sparse variants.
2. Remove every `growth_variants.stable` key from the generated JSON.
3. Change the Python test stage contract and valid growth-stage names to three stages.
4. Add a prominent current-status note to each still-usable prompt batch: stable output is retired and must not be generated; only popular and signature remain active.
5. Leave historical design specifications unchanged.

## Task 4: Delete stable-stage icon assets

**Files:**

- Delete: `resources/recipe_icons/*_stable.png`
- Delete: `resources/recipe_icons/*_stable.png.import`

**Steps:**

1. Resolve the exact Git-tracked file list and verify every target is directly under `resources/recipe_icons` with the `_stable.png` suffix.
2. Delete the 132 PNGs and 132 matching import files with `apply_patch`.
3. Verify `git ls-files` contains no remaining stable-stage icon targets.
4. Do not delete unrelated files that use “stable” as an ordinary English word.

## Task 5: Rewrite focused growth fixtures and regression checks

**Files:**

- Modify: `tests/recipe_growth_stage_progress_self_check.gd`
- Modify: `tests/recipe_growth_round_progress_self_check.gd`
- Modify: `tests/recipe_growth_summary_ui_self_check.gd`
- Modify: `tests/recipe_masterwork_growth_self_check.gd`
- Modify: `tests/device_growth_self_check.gd`
- Modify: `tests/device_recipe_growth_ui_self_check.gd`
- Modify: `tests/recipe_growth_choice_scene_self_check.gd`
- Modify: `tests/automation_settlement_self_check.gd`
- Modify: `tests/component_contract_self_check.gd`
- Modify other tests only when a failing assertion directly encodes the removed stable stage.

**Steps:**

1. Make the stage-progress test assert the two new requirement dictionaries and empty signature requirement.
2. Update fixtures so trial promotion occurs only at `30/10/3/L3` and produces popular level `1`.
3. Update popular-to-signature fixtures to start at level `1` and reach level `2`.
4. Update masterwork fixtures to use `MASTERY_SIGNATURE` instead of raw legacy values.
5. Update device-cap, device-wait, automation-report, summary-copy, component-contract, and trait-choice assertions.
6. Add explicit absence checks for `MASTERY_STABLE`, “稳定款”, “四阶段”, and `growth_variants.stable` in active runtime/config surfaces.

## Task 6: Run verification and inspect the final diff

**Commands:**

1. Run `python -m unittest tests.test_recipe_growth_display_config`.
2. Run `python tools/generate_recipe_growth_display_config.py --check`.
3. Run focused Godot scripts serially with `D:\Godot\Godot_v4.6.1-stable_win64_console.exe --headless --path . --log-file <writable-temp-log> -s res://tests/<test>.gd`.
4. Run the project parse/quit check with an explicit writable log file.
5. Run `rg` absence checks, `git diff --check`, and targeted `git diff` review.
6. Confirm the pre-existing red-button scene change and all unrelated dirty-worktree files remain intact.
