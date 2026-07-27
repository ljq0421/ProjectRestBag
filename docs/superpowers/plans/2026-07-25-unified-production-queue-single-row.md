# Unified Single-Row Production Queue Implementation Plan

> **For agentic workers:** Implement this plan task by task. Keep each task independently testable and commit only the files listed for that task.

**Goal:** Replace the production picker and three-slot recipe rows with one searchable, continuously sorted production queue whose 68px rows show recipe, named material costs, duration, price, action, and whole-row progress.

**Architecture:** Keep stable layout and row structure in `.tscn` files. Add a durable timed queue for processed ingredients beside the existing finished-recipe queue, expose both through one normalized row snapshot in `main_view.gd`, and let row scripts bind data and refresh countdown/progress without rebuilding the list every second. New starts are limited to one active batch per recipe while different recipes remain concurrent.

**Tech Stack:** Godot 4.6.1, GDScript, scene-first UI, repository-local headless self-checks.

## Global Constraints

- Target checkout: `D:\Project\ProjectRest\project-rest-new`.
- Treat `docs/superpowers/specs/2026-07-25-unified-production-queue-single-row-design.zh.md` as the approved source of truth.
- One active batch is allowed per recipe ID. Finished recipes and processed-ingredient recipes use the same rule, but different recipe IDs may run concurrently.
- Existing saves containing legacy multi-batch finished-recipe work must continue settling. Do not start new work for that recipe until all of its legacy batches have completed.
- Processed ingredients stay in the unified list and become timed work:
  - rice flour: 2 seconds
  - wheat flour: 2 seconds
  - glutinous rice flour: 4 seconds
  - cocoa: 4 seconds
  - matcha: 4 seconds
  - yogurt: 8 seconds
- Preserve `production_ready_recipe_records`, `display_sequence`, completed-stock badges, and the existing `inventory_product` drag protocol.
- Preserve the one-second performance contract: a tick updates only runtime values; structural snapshot/list rebuilds happen only after state-changing events.
- Keep the workbench at 820px wide and 858px high. Keep the header at 54px, remove the 76px footer, and provide a 794px scroll viewport.
- Each recipe row is exactly 68px high with 6px inter-row spacing. The 68×68 product icon is the completed-stock drag hot area.
- The list fully displays 10 rows and clips the 11th. Do not add a second toolbar row or section headings.
- Do not display the labels “可制作”, “缺材料”, “成品”, “中间食材”, “耗时”, or “售价”.
- Materials must show icon, name, and quantity. Missing quantities use current/required presentation.
- Use `res://resources/ui/icons/storefront/countdown_alarm.svg` before time and `res://resources/ui/icons/purchase/coin.svg` before price. Processed ingredients display `0` after the coin icon.
- Whole-row progress fills left to right behind all row content from product icon through action button. Do not add a `ProgressBar` node and do not display a percentage.
- Search and unlocked bulk actions live in the workbench header. The single bulk menu contains “制作全部”, “一键补货”, and “上架全部”.
- Automation starts one batch only. Remove the “每轮 3 批” option and do not create a pending three-batch sequence.
- Preserve all unrelated untracked files under `resources/ui/icons_v1`.
- Every Godot headless command must include `--log-file` pointing to a writable temp path; never use `NUL`.

---

## File Map

- `scripts/catalog.gd`
  - Adds the approved duration to each processed-ingredient recipe.
- `scripts/game_state.gd`
  - Enforces one new batch per recipe, stores and settles timed processed-ingredient work, and preserves legacy multi-batch settlement.
- `scripts/automation_service.gd`
  - Normalizes every production rule to one batch.
- `scripts/ui/pages/kitchen_automation_panel.gd`
  - Removes the three-batch choice from automation editing.
- `scenes/Main.tscn`
  - Sets the production workbench shell width to 820px.
- `scenes/ui/pages/production_workbench.tscn`
  - Defines the 54px header, search, bulk menu, automation action, 794px list viewport, and no footer.
- `scripts/ui/pages/production_workbench.gd`
  - Emits header actions and performs structural versus runtime row refreshes.
- `scenes/ui/pages/production_queue_recipe_row.tscn`
  - Defines the stable 68px single-row structure and full-row fill layer.
- `scripts/ui/pages/production_queue_recipe_row.gd`
  - Binds recipe/material/action data, updates whole-row fill and countdown, and preserves drag behavior.
- `scripts/main_view.gd`
  - Builds, filters, sorts, and dispatches one unified production snapshot; migrates popup actions to the header.
- `scenes/ui/overlays/production_recipe_picker_overlay.tscn`
- `scenes/ui/overlays/production_recipe_card.tscn`
- `scripts/ui/overlays/production_recipe_picker_overlay.gd`
- `scripts/ui/overlays/production_recipe_card.gd`
  - Removed after all live references have been migrated.
- `tests/ingredient_processing_timing_self_check.gd`
  - Covers timed processed-ingredient work, persistence, and offline settlement.
- Existing production, automation, tutorial, drag, performance, and MVP self-checks
  - Updated to guard the new contract.

---

### Task 1: Lock the New Domain Contract with Failing Tests

**Files:**
- Create: `tests/ingredient_processing_timing_self_check.gd`
- Modify: `tests/recipe_production_timing_self_check.gd`
- Modify: `tests/automation_settlement_self_check.gd`
- Modify: `tests/production_queue_interaction_self_check.gd`

**Required contracts:**
- New finished-recipe starts always create one batch.
- A second start for the same recipe is rejected while that recipe is active.
- Different recipe IDs may be active at the same time.
- Processed ingredients use the approved durations, consume inputs at start, and award outputs only after completion.
- Different processed-ingredient recipe IDs may run concurrently.
- A processed-ingredient recipe cannot be started twice concurrently.
- Both queues survive save/load and settle elapsed work after offline time.
- Legacy finished-recipe records with more than one batch still settle, but block new work for that recipe until empty.
- Automation rules and starts normalize to one batch.

- [ ] **Step 1: Add the processed-ingredient timing self-check**

Build a focused `SceneTree` test using real `Catalog`, `RecipeBook`, and `GameState` data. Assert:

```gdscript
_expect_equal("rice flour duration", Catalog.processing_recipe_duration("rice_flour_process"), 2)
_expect_equal("wheat flour duration", Catalog.processing_recipe_duration("wheat_flour_process"), 2)
_expect_equal("glutinous rice flour duration", Catalog.processing_recipe_duration("glutinous_rice_flour_process"), 4)
_expect_equal("cocoa duration", Catalog.processing_recipe_duration("cocoa_process"), 4)
_expect_equal("matcha duration", Catalog.processing_recipe_duration("matcha_process"), 4)
_expect_equal("yogurt duration", Catalog.processing_recipe_duration("yogurt_process"), 8)
```

Queue one processed ingredient at a fixed timestamp, then assert input deduction, no immediate output, active summary values, second-start rejection, concurrent start of a different processed ingredient, completion settlement, save/load restoration, and offline settlement.

- [ ] **Step 2: Change finished-recipe timing tests to one-batch semantics**

Replace new three-batch expectations with:

```gdscript
_expect_equal("new queue batch count", int(entry.get("batches", 0)), 1)
_expect(not state.queue_recipe_production(recipe_id, 1, now_unix), "same recipe must not start twice")
_expect(state.queue_recipe_production(other_recipe_id, 1, now_unix), "different recipes may run concurrently")
```

Add a manually constructed legacy save entry with `batches = 3`; assert it loads, settles all three outputs at its recorded ready time, and rejects a new start for that recipe while present.

- [ ] **Step 3: Change automation tests**

Load or create a rule containing `batches = 3`. Assert the sanitized rule contains `batches = 1`, the first eligible cycle starts one batch, and the following cycle cannot start the same recipe while it is active.

- [ ] **Step 4: Add interaction-level expectations**

In `production_queue_interaction_self_check.gd`, require processed-ingredient actions to create timed queue state instead of changing inventory immediately.

- [ ] **Step 5: Run the focused tests and verify failure**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\prn-unified-domain-recipe.log" -s res://tests/recipe_production_timing_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\prn-unified-domain-process.log" -s res://tests/ingredient_processing_timing_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\prn-unified-domain-automation.log" -s res://tests/automation_settlement_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\prn-unified-domain-interaction.log" -s res://tests/production_queue_interaction_self_check.gd
```

Expected: failures identify the current three-batch allowance, instant processing, missing processing queue, and three-batch automation rule.

- [ ] **Step 6: Commit the failing contract tests**

```powershell
git add -- tests/ingredient_processing_timing_self_check.gd tests/recipe_production_timing_self_check.gd tests/automation_settlement_self_check.gd tests/production_queue_interaction_self_check.gd
git commit -m "test: define unified production timing contract"
```

---

### Task 2: Implement One-Batch Recipe Work and Timed Ingredient Processing

**Files:**
- Modify: `scripts/catalog.gd`
- Modify: `scripts/game_state.gd`
- Modify: `scripts/recipe_book.gd`
- Modify: `scripts/main_view.gd`
- Test: `tests/ingredient_processing_timing_self_check.gd`
- Test: `tests/recipe_production_timing_self_check.gd`
- Test: `tests/production_queue_interaction_self_check.gd`

**Interfaces:**
- `Catalog.processing_recipe_duration(recipe_id: String) -> int`
- `GameState.queue_ingredient_processing(recipe_id: String, now_unix: int) -> Dictionary`
- `GameState.complete_ingredient_processing(now_unix: int) -> Array[Dictionary]`
- `GameState.ingredient_processing_queue_summary(now_unix: int) -> Array[Dictionary]`
- Durable `ingredient_processing_queue: Array[Dictionary]`

- [ ] **Step 1: Put duration data on processed-ingredient recipes**

Add a `duration_seconds` field to each `PROCESSING_RECIPES` entry using the six approved values. Add one catalog accessor that returns a positive integer and does not mutate catalog data.

- [ ] **Step 2: Add durable processed-ingredient queue state**

Add `ingredient_processing_queue` to the `GameState` constructor/defaults, `from_dict()`, `to_dict()`, and sanitizer path. Store only canonical runtime fields needed for deterministic settlement:

```gdscript
{
	"recipe_id": String,
	"queued_at_unix": int,
	"ready_at_unix": int,
	"duration_seconds": int,
	"source": String,
	"display_sequence": int
}
```

Reject malformed or unknown recipe IDs during sanitization. Preserve valid elapsed entries so the normal completion pass can settle them.

- [ ] **Step 3: Enforce one active entry per recipe**

Change `MAX_CONCURRENT_RECIPE_BATCHES` to one for new work. Keep the legacy `batches` field readable and settle it as stored; do not truncate loaded legacy entries. A recipe is unavailable for a new start whenever any queue entry with that recipe ID remains.

Apply the same active-recipe check to `ingredient_processing_queue`.

- [ ] **Step 4: Start and settle processed-ingredient work**

Refactor the existing instant-processing path so input validation and consumption remain in the recipe/domain layer, but output is deferred until `complete_ingredient_processing()`. Return structured success/failure data so UI notifications can explain missing materials or already-active work.

Use one transaction boundary:

1. validate recipe and active state;
2. validate every input;
3. consume all inputs;
4. append the timed queue entry;
5. emit/save one state change.

On completion, award the configured output exactly once and remove the queue entry.

- [ ] **Step 5: Include processed work in the shared completion tick**

Update the production tick in `main_view.gd` so finished recipes and processed ingredients settle from the same timestamp. A completion event triggers one structural workbench refresh; a non-completing second triggers runtime-only row refresh.

- [ ] **Step 6: Run focused domain tests**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\prn-unified-domain-recipe-pass.log" -s res://tests/recipe_production_timing_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\prn-unified-domain-process-pass.log" -s res://tests/ingredient_processing_timing_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\prn-unified-domain-interaction-pass.log" -s res://tests/production_queue_interaction_self_check.gd
```

Expected pass markers:

- `RECIPE_PRODUCTION_TIMING_SELF_CHECK_PASS`
- `INGREDIENT_PROCESSING_TIMING_SELF_CHECK_PASS`
- `PRODUCTION_QUEUE_INTERACTION_SELF_CHECK_PASS`

- [ ] **Step 7: Commit domain behavior**

```powershell
git add -- scripts/catalog.gd scripts/game_state.gd scripts/recipe_book.gd scripts/main_view.gd tests/ingredient_processing_timing_self_check.gd tests/recipe_production_timing_self_check.gd tests/production_queue_interaction_self_check.gd
git commit -m "feat: add single-batch timed production"
```

---

### Task 3: Normalize Automation to One Batch

**Files:**
- Modify: `scripts/automation_service.gd`
- Modify: `scripts/ui/pages/kitchen_automation_panel.gd`
- Modify: `scenes/ui/pages/kitchen_automation_panel.tscn` only if the batch selector is scene-defined
- Test: `tests/automation_settlement_self_check.gd`
- Test: any existing automation panel scene self-check

**Interfaces:**
- Existing stored rules containing `batches = 3` are normalized to `1` when read.
- New or edited rules always persist `batches = 1`.

- [ ] **Step 1: Remove the three-batch UI option**

Delete the loop that adds `[1, 3]` choices. If the selector no longer conveys useful information, remove the label and selector nodes from the scene and hard-code one in the edited rule. If removing them would disturb an unrelated panel layout, retain a read-only “1批” value; do not expose a choice.

- [ ] **Step 2: Normalize service input**

In `_sanitize_rule()`, always output `batches = 1` regardless of a legacy stored value. In scheduling and capacity checks, use one batch instead of trusting caller-supplied batch counts.

- [ ] **Step 3: Verify automation behavior**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\prn-unified-automation.log" -s res://tests/automation_settlement_self_check.gd
```

Expected: `AUTOMATION_SETTLEMENT_SELF_CHECK_PASS`.

- [ ] **Step 4: Commit automation changes**

```powershell
git add -- scripts/automation_service.gd scripts/ui/pages/kitchen_automation_panel.gd scenes/ui/pages/kitchen_automation_panel.tscn tests/automation_settlement_self_check.gd
git diff --cached --name-only
git commit -m "refactor: limit production automation to one batch"
```

If the scene was not changed, omit its path. The staged list must contain only the automation files above.

---

### Task 4: Lock and Build the 820px Workbench and 68px Row Scenes

**Files:**
- Modify: `tests/production_queue_scene_self_check.gd`
- Modify: `tests/recipe_production_ui_self_check.gd`
- Modify: `scenes/Main.tscn`
- Modify: `scenes/ui/pages/production_workbench.tscn`
- Modify: `scripts/ui/pages/production_workbench.gd`
- Modify: `scenes/ui/pages/production_queue_recipe_row.tscn`
- Modify: `scripts/ui/pages/production_queue_recipe_row.gd`

**Scene contract:**
- `WorkbenchPanel` width: 820px.
- `ProductionWorkbench` height: 858px.
- Header: 54px.
- Queue viewport: 794px after removing the 76px footer.
- Row: 68px high; 6px list separation.
- Product icon: 68×68px.
- Stable material-chip container exists in the scene.
- Clock and coin textures are explicit scene resources.
- A background fill node covers the entire row and clips to progress.
- No per-batch slot nodes, no `ProgressBar`, and no percentage label.

- [ ] **Step 1: Rewrite scene assertions first**

Change `production_queue_scene_self_check.gd` to instantiate the real scenes and assert exact dimensions and required node roles. Assert forbidden nodes/types are absent. Configure representative rows for:

- craftable finished recipe;
- missing-material finished recipe;
- active processed ingredient with price `0`;
- completed stock with badge and drag payload.

Verify a material chip shows icon, name, and quantity text; a missing chip shows current/required text. Verify clock/coin icons are visible and no “耗时” or “售价” text exists.

- [ ] **Step 2: Run the scene test and verify failure**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\prn-unified-scene-red.log" -s res://tests/production_queue_scene_self_check.gd
```

Expected: failures report the current 760px shell, 190px multi-slot row, footer, progress bars, and missing header controls.

- [ ] **Step 3: Rebuild the workbench scene**

Define the complete layout in `production_workbench.tscn`:

```text
ProductionWorkbench (820×858)
├── Header (54)
│   ├── SearchField
│   ├── BulkActionButton/Menu
│   └── AutomationButton
└── QueueScroll (794)
    └── QueueList (separation 6)
```

Remove the old recipe-entry footer. Emit dedicated signals for search changes, bulk action selection, and automation open.

- [ ] **Step 4: Rebuild the row scene**

Define a single horizontal row:

```text
ProductionQueueRecipeRow (height 68, clip contents)
├── Background
├── ProgressFill (full rect; width controlled by progress)
└── Content
    ├── ProductIconButton (68×68)
    │   └── StockBadge
    ├── RecipeName
    ├── MaterialStrip
    ├── TimeGroup
    │   ├── ClockIcon
    │   └── TimeValue
    ├── PriceGroup
    │   ├── CoinIcon
    │   └── PriceValue
    └── ActionButton
```

Use theme/style resources already present in the project. Keep text ellipsis and minimum sizes explicit so one long recipe name or material does not expand the row.

- [ ] **Step 5: Bind structure without dynamic layout construction**

Let `production_queue_recipe_row.gd`:

- bind normalized row data;
- create only the variable count of material chips inside the scene-defined strip;
- cache styles/textures instead of recreating them each tick;
- set progress by changing `ProgressFill.size.x` or its right anchor from normalized progress;
- show total seconds when idle and remaining whole seconds when active;
- emit make/restock/drag actions;
- keep the product icon as the completed-stock drag origin.

- [ ] **Step 6: Verify the scene contract**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\prn-unified-scene-pass.log" -s res://tests/production_queue_scene_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\prn-unified-ui-partial.log" -s res://tests/recipe_production_ui_self_check.gd
```

The scene test must pass. The UI test may still fail only on unified snapshot or old popup behavior scheduled for Task 5.

- [ ] **Step 7: Commit scene-first layout**

```powershell
git add -- scenes/Main.tscn scenes/ui/pages/production_workbench.tscn scenes/ui/pages/production_queue_recipe_row.tscn scripts/ui/pages/production_workbench.gd scripts/ui/pages/production_queue_recipe_row.gd tests/production_queue_scene_self_check.gd tests/recipe_production_ui_self_check.gd
git commit -m "feat: build compact production queue workbench"
```

---

### Task 5: Build the Unified Snapshot, Sorting, Search, and Row Actions

**Files:**
- Modify: `scripts/main_view.gd`
- Modify: `scripts/ui/pages/production_workbench.gd`
- Modify: `scripts/ui/pages/production_queue_recipe_row.gd`
- Modify: `tests/recipe_production_ui_self_check.gd`
- Modify: `tests/production_queue_performance_self_check.gd`
- Modify: `tests/production_queue_interaction_self_check.gd`

**Normalized row data:**

```gdscript
{
	"entry_kind": "processing" | "finished",
	"recipe_id": String,
	"name": String,
	"icon": Texture2D,
	"materials": Array[Dictionary],
	"duration_seconds": int,
	"remaining_seconds": int,
	"price": int,
	"is_active": bool,
	"is_craftable": bool,
	"progress": float,
	"action_kind": "make" | "restock" | "active",
	"disabled_reason": String,
	"inventory_count": int,
	"unlock_sequence": int,
	"display_sequence": int
}
```

Each material dictionary contains ID, display name, icon, required count, owned count, and missing state.

**Ordering key:**

1. craftable or active processed ingredients;
2. craftable or active finished recipes;
3. missing-material processed ingredients;
4. missing-material finished recipes.

Within processed-ingredient bands: duration ascending, then unlock/config sequence.
Within finished-recipe bands: price descending, then unlock/config sequence.

- [ ] **Step 1: Rewrite unified-list tests first**

Create fixtures spanning all four logical bands, equal duration, equal price, active rows, completed stock, and search matches. Assert one flat array in the exact order without section labels.

Assert an active row stays in its corresponding upper band even though starting work consumed its materials. After completion and the next structural refresh, allow it to be classified from its current inventory/material state.

- [ ] **Step 2: Build one event-level snapshot**

Replace separate picker and queue entry builders with one `_build_production_queue_snapshot(now_unix)` pass. Precompute:

- finished-recipe active lookup;
- processed-ingredient active lookup;
- completed-stock count lookup;
- owned-material counts;
- unlock/config sequence lookup.

Do not repeatedly deep-copy catalogs inside the per-row loop.

- [ ] **Step 3: Apply stable classification and sorting**

Assign a numeric band and type-specific secondary key to each row. Use unlock/config sequence as the deterministic final key. Do not alphabetically reorder ties.

Search filters the already-built snapshot by recipe name and material name. Search changes rebuild/filter rows from cached structural data; they do not query or mutate game state.

- [ ] **Step 4: Wire row actions**

- “制作” starts exactly one timed entry.
- Missing-material action opens or executes the existing restock path, preserving explanation and return behavior.
- Active action is disabled and displays remaining time.
- Completed-stock icon drag produces the existing `inventory_product` payload.
- A failed drop preserves stock; a successful showcase drop refreshes the queue badge/count.

After a successful make/restock/bulk/drag state change, rebuild one structural snapshot. Do not rebuild from hover, motion, or the one-second tick.

- [ ] **Step 5: Separate structural and runtime refresh**

Keep:

```gdscript
func _refresh_production_workbench() -> void:
	var snapshot := _build_production_queue_snapshot(Time.get_unix_time_from_system())
	production_workbench.refresh_queue(snapshot)


func _refresh_production_queue_tick(now_unix: int) -> void:
	production_workbench.refresh_queue_runtime(
		game_state.recipe_production_queue_summary(now_unix),
		game_state.ingredient_processing_queue_summary(now_unix)
	)
```

The exact names may follow current project conventions, but the call graph must preserve this boundary.

- [ ] **Step 6: Run unified-list, interaction, and performance tests**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\prn-unified-list.log" -s res://tests/recipe_production_ui_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\prn-unified-actions.log" -s res://tests/production_queue_interaction_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\prn-unified-performance.log" -s res://tests/production_queue_performance_self_check.gd
```

Expected pass markers:

- `RECIPE_PRODUCTION_UI_SELF_CHECK_PASS`
- `PRODUCTION_QUEUE_INTERACTION_SELF_CHECK_PASS`
- `PRODUCTION_QUEUE_PERFORMANCE_SELF_CHECK_PASS`

- [ ] **Step 7: Commit unified snapshot behavior**

```powershell
git add -- scripts/main_view.gd scripts/ui/pages/production_workbench.gd scripts/ui/pages/production_queue_recipe_row.gd tests/recipe_production_ui_self_check.gd tests/production_queue_performance_self_check.gd tests/production_queue_interaction_self_check.gd
git commit -m "feat: unify production queue entries"
```

---

### Task 6: Move Bulk Operations to the Header and Remove the Old Popup

**Files:**
- Modify: `scripts/main_view.gd`
- Modify: `scenes/Main.tscn`
- Modify: `scenes/ui/pages/production_workbench.tscn`
- Modify: `scripts/ui/pages/production_workbench.gd`
- Delete: `scenes/ui/overlays/production_recipe_picker_overlay.tscn`
- Delete: `scenes/ui/overlays/production_recipe_card.tscn`
- Delete: `scripts/ui/overlays/production_recipe_picker_overlay.gd`
- Delete: `scripts/ui/overlays/production_recipe_card.gd`
- Delete: `scripts/ui/overlays/production_recipe_picker_overlay.gd.uid`
- Delete: `scripts/ui/overlays/production_recipe_card.gd.uid`
- Rename: `tests/production_recipe_picker_self_check.gd` to `tests/production_queue_header_self_check.gd`
- Rename its `.uid` sidecar only if the repository's existing rename workflow requires a stable UID
- Modify: `tests/component_contract_self_check.gd`
- Modify: `tests/recipe_action_icon_layout_self_check.gd`
- Modify: `tests/recipe_growth_summary_ui_self_check.gd`
- Modify: `tests/recipe_production_ui_self_check.gd`
- Modify: `tests/red_operation_button_skin_self_check.gd`
- Modify: `tests/research_batch_unlock_self_check.gd`
- Modify: `tests/research_overlay_production_workbench_self_check.gd`
- Modify: `tests/research_recipe_restock_self_check.gd`
- Modify: `tests/tutorial_guide_dynamic_target_self_check.gd`

**Required behavior:**
- Search is always available in the production header.
- One “批量操作” menu exposes unlocked “制作全部”, “一键补货”, and “上架全部”.
- Locked operations are omitted or disabled using the existing unlock source of truth.
- “自动排程” remains a separate header action.
- No runtime code instantiates or opens the old production picker.

- [ ] **Step 1: Convert the old picker test before deleting code**

Turn `production_recipe_picker_self_check.gd` into a unified-header/bulk-action self-check, preferably renamed to `production_queue_header_self_check.gd`. Assert:

- search signal and filtering;
- one bulk menu;
- exact menu items and unlock behavior;
- batch actions route to existing bulk implementations;
- old popup scene paths and `_show_production_picker()` are absent from live source.

- [ ] **Step 2: Migrate bulk action routing**

Connect the workbench header menu to the existing domain actions:

- “制作全部” → existing make-all path, changed to one active entry per recipe;
- “一键补货” → existing unlocked bulk restock quote/purchase path;
- “上架全部” → existing available-product listing path.

Preserve existing confirmation, price quote, insufficient-currency feedback, atomic purchase, and successful-action refresh behavior. Do not duplicate these rules in the workbench script.

- [ ] **Step 3: Migrate tutorial targets**

Replace old popup/card node paths with stable queue-row or header targets. Preserve the exact real event that advances each tutorial/task; do not satisfy tests by manually emitting signals.

- [ ] **Step 4: Remove popup state and files**

Remove popup-specific constants, cached snapshot fields, open/close/filter handlers, signal connections, and `Main.tscn` instances. Search before deletion:

```powershell
rg -n "production_recipe_picker|ProductionRecipePicker|ProductionRecipeCard|_show_production_picker|_refresh_production_picker" .
```

Delete the popup/card scenes, scripts, and their tracked script UID sidecars only after every live reference is migrated. Keep documentation history unchanged.

- [ ] **Step 5: Run header, tutorial, workbench, and drag checks**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\prn-unified-header.log" -s res://tests/production_queue_header_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\prn-unified-research.log" -s res://tests/research_overlay_production_workbench_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\prn-unified-drag.log" -s res://tests/production_queue_interaction_self_check.gd
```

Also run every test returned by:

```powershell
rg -l "production_recipe_picker|RecipeEntryBar|ProductionQueueRecipeRow|production workbench" tests
```

- [ ] **Step 6: Prove active old references are zero**

```powershell
rg -n "res://scenes/ui/overlays/production_recipe_picker_overlay.tscn|res://scenes/ui/overlays/production_recipe_card.tscn|res://scripts/ui/overlays/production_recipe_picker_overlay.gd|res://scripts/ui/overlays/production_recipe_card.gd" scenes scripts tests project.godot
```

Expected: no matches.

- [ ] **Step 7: Commit header migration and popup removal**

```powershell
git add -- scripts/main_view.gd scenes/Main.tscn scenes/ui/pages/production_workbench.tscn scripts/ui/pages/production_workbench.gd
git add -u -- scenes/ui/overlays/production_recipe_picker_overlay.tscn scenes/ui/overlays/production_recipe_card.tscn scripts/ui/overlays/production_recipe_picker_overlay.gd scripts/ui/overlays/production_recipe_picker_overlay.gd.uid scripts/ui/overlays/production_recipe_card.gd scripts/ui/overlays/production_recipe_card.gd.uid
git add -- tests/production_queue_header_self_check.gd tests/component_contract_self_check.gd tests/recipe_action_icon_layout_self_check.gd tests/recipe_growth_summary_ui_self_check.gd tests/recipe_production_ui_self_check.gd tests/red_operation_button_skin_self_check.gd tests/research_batch_unlock_self_check.gd tests/research_overlay_production_workbench_self_check.gd tests/research_recipe_restock_self_check.gd tests/tutorial_guide_dynamic_target_self_check.gd
git add -u -- tests/production_recipe_picker_self_check.gd
git diff --cached --name-only
git commit -m "refactor: move production actions into queue header"
```

If the test UID sidecar is renamed, add both the old and new explicit UID paths. The staged list must contain only the files named in this task.

---

### Task 7: Runtime Layout, Regression, and Scope Verification

**Files:**
- Modify only files required by failures discovered in this task.

- [ ] **Step 1: Import the project headlessly**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --editor --path . --log-file "$env:TEMP\prn-unified-import.log" --quit
```

Expected: clean scene/script parse and resource import. Check the log for parse errors, missing external resources, invalid node paths, and orphaned popup references.

- [ ] **Step 2: Run the focused production suite**

```powershell
$tests = @(
  'ingredient_processing_timing_self_check.gd',
  'recipe_production_timing_self_check.gd',
  'production_queue_scene_self_check.gd',
  'production_queue_interaction_self_check.gd',
  'production_queue_performance_self_check.gd',
  'recipe_production_ui_self_check.gd',
  'production_queue_header_self_check.gd',
  'automation_settlement_self_check.gd',
  'research_overlay_production_workbench_self_check.gd'
)
foreach ($test in $tests) {
  & "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\prn-unified-$($test.Replace('.gd', '')).log" -s "res://tests/$test"
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
```

Expected: every test prints its pass marker and exits zero.

- [ ] **Step 3: Run broad regressions**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\prn-unified-mvp.log" -s res://tests/mvp_self_check.gd
```

Run any additional tests discovered by `rg -l` in Task 6, especially tutorial dynamic targets and showcase drag/drop coverage.

- [ ] **Step 4: Verify the live interaction path**

Run the project and check:

1. workbench is 820×858 and the list shows 10 complete 68px rows;
2. no category headings appear;
3. processed ingredients occupy the upper bands and use duration/config ordering;
4. finished recipes use descending price ordering;
5. missing entries follow their craftable counterpart bands;
6. each material chip shows icon, name, and quantity;
7. processed ingredients show coin icon plus `0`;
8. starting one row fills the entire row left-to-right without percentage text;
9. the same recipe cannot start again, while a different recipe can;
10. completed finished stock remains draggable from the 68×68 icon;
11. search and each unlocked bulk operation work from the header;
12. no old production popup opens from any button or tutorial path.

- [ ] **Step 5: Recheck high-frequency behavior**

Use the Godot monitor or existing measurement harness while several recipe types are active. Confirm the one-second tick does not rebuild row nodes or recipe/material snapshots. State-changing actions may rebuild once.

- [ ] **Step 6: Check diff and repository scope**

```powershell
git diff --check
git status --short
git diff --stat
git diff --name-only
```

Confirm:

- no files under `resources/ui/icons_v1` are staged;
- no save migration scaffolding was added beyond sanitizing the new queue and preserving legacy finished work;
- no unrelated UI was changed;
- deleted popup resources have zero active references.

- [ ] **Step 7: Commit only verification-driven fixes**

If verification required fixes:

```powershell
git add -- <explicit-files-only>
git diff --cached --name-only
git commit -m "fix: complete unified production queue verification"
```

If no fixes were required, do not create an empty commit.

---

## Completion Checklist

- [ ] Every recipe ID has at most one newly started active batch.
- [ ] Different recipe IDs run concurrently.
- [ ] All six processed ingredients use the approved durations and timed settlement.
- [ ] Legacy multi-batch finished work settles without enabling new multi-batch starts.
- [ ] Automation exposes and schedules one batch only.
- [ ] One flat list follows the four-band ordering and deterministic tie breakers.
- [ ] The 820×858 workbench contains a 54px header and 794px list viewport.
- [ ] Ten 68px rows fit fully with 6px separation.
- [ ] Rows show product icon, name, named material chips, clock/time, coin/price, and action on one line.
- [ ] Whole-row fill conveys progress; no progress bar or percentage exists.
- [ ] Processed-ingredient price is `0`.
- [ ] Search, bulk actions, and automation entry are in the header.
- [ ] The old production picker and card have no active runtime references.
- [ ] Completed-stock badge and `inventory_product` drag behavior remain intact.
- [ ] One-second ticks are runtime-only refreshes.
- [ ] Focused production tests, MVP check, import, live interaction, and diff checks pass.
