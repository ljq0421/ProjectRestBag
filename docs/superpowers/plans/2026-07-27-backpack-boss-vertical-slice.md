# Backpack Boss Vertical Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build one complete, deterministic 30-second Boss encounter in `project-rest-two`, covering challenge supply, spatial loadout, automatic battle, double pressure bars, explainable settlement, and same-encounter retry without touching long-term inventory.

**Architecture:** Add an isolated `challenge` namespace and a new scene-first challenge root. Pure services own configuration, loadout validation, deterministic battle, reports, run state, and save writes; UI scenes only send intent and render service output. The legacy `Main.tscn`, `main_view.gd`, production flow, inventory, and research runtime remain untouched during this slice.

**Tech Stack:** Godot 4.6.1, GDScript, JSON configuration, `.tscn` scenes, existing `RecipeIconService` / `ShowcaseIconService`, headless `SceneTree` self-checks.

## Global Constraints

- Work only in `D:\Project\ProjectRest\project-rest-two`; `project-rest-new` remains read-only.
- Stage 1 contains one Boss encounter, 6 recipes, three demand windows at 8/16/24 seconds, and final resolution at 30 seconds.
- Battle is fully automatic after start; placement, rotation, supply changes, refill, and skills remain locked.
- Challenge supply is virtual and must neither read nor write long-term product inventory.
- Use integer milliseconds and stable event ordering; identical snapshot, encounter, and seed must produce identical events and result.
- A sale due exactly at 8/16/24/30 seconds resolves before the demand check at that timestamp.
- Stage 1 does not implement the five-encounter chain, post-win upgrades, research tree, endless mode, or migration of all 166 recipes.
- New saves use `user://project_rest_two_save_v1.json`; never scan or import `project_rest_new` saves.
- Stable layout belongs in `.tscn`; scripts bind state, emit intent, and refresh presentation.
- Do not add Boss logic to `scripts/main_view.gd` or new challenge nodes to `scenes/Main.tscn`.
- Every Godot headless command includes `--log-file` pointing to `$env:TEMP`.

---

## Planned File Map

### Configuration

- `doc/challenge/challenge_recipes.json`: six battle recipe definitions and 6×8 board rules.
- `doc/challenge/boss_encounters.json`: first Boss, three demand windows, pressure values, and relation rule.
- `scripts/challenge/challenge_config_validator.gd`: parse-independent schema and reachability validation.

### Domain Services

- `scripts/challenge/challenge_save_service.gd`: independent atomic save/load and broken-save recovery.
- `scripts/challenge/challenge_loadout_service.gd`: supply budget, copy limits, rotation, occupancy, relations, and immutable snapshot.
- `scripts/challenge/boss_battle_service.gd`: deterministic sale clock, satisfaction, demand windows, pressure bars, and outcome.
- `scripts/challenge/boss_battle_report_service.gd`: player-facing contribution and failure explanation derived from battle events.
- `scripts/challenge/challenge_run_service.gd`: two-confidence single-encounter state, idempotent settlement, and retry identity.

### UI

- `scenes/challenge/challenge_supply_card.tscn` and `scripts/challenge/ui/challenge_supply_card.gd`: recipe drag source.
- `scenes/challenge/challenge_board.tscn` and `scripts/challenge/ui/challenge_board.gd`: 6×8 spatial board.
- `scenes/challenge/challenge_battle_view.tscn` and `scripts/challenge/ui/challenge_battle_view.gd`: timeline, double bars, and automatic battle presentation.
- `scenes/challenge/challenge_settlement_dialog.tscn` and `scripts/challenge/ui/challenge_settlement_dialog.gd`: result, contribution, exact gap, and retry action.
- `scenes/challenge/challenge_main.tscn` and `scripts/challenge/challenge_main_view.gd`: stage-one orchestration only.

### Tests

- `tests/challenge/challenge_save_service_self_check.gd`
- `tests/challenge/challenge_config_validator_self_check.gd`
- `tests/challenge/challenge_loadout_service_self_check.gd`
- `tests/challenge/boss_battle_service_self_check.gd`
- `tests/challenge/boss_battle_report_self_check.gd`
- `tests/challenge/challenge_run_service_self_check.gd`
- `tests/challenge/challenge_board_scene_self_check.gd`
- `tests/challenge/challenge_battle_view_self_check.gd`
- `tests/challenge/challenge_main_scene_self_check.gd`
- `tests/challenge/challenge_vertical_slice_self_check.gd`

---

### Task 1: Independent Challenge Save Namespace

**Files:**
- Create: `scripts/challenge/challenge_save_service.gd`
- Create: `tests/challenge/challenge_save_service_self_check.gd`

**Interfaces:**
- Consumes: plain JSON-safe `Dictionary`.
- Produces:
  - `ChallengeSaveService.empty_save() -> Dictionary`
  - `ChallengeSaveService.save_to_path(path: String, data: Dictionary) -> Dictionary`
  - `ChallengeSaveService.load_from_path(path: String) -> Dictionary`
  - constants `SAVE_PATH` and `BROKEN_SAVE_PATH`.

- [ ] **Step 1: Write the failing save namespace self-check**

Create a `SceneTree` self-check that asserts the constants and round-trips an isolated temporary file:

```gdscript
extends SceneTree

const SERVICE_PATH := "res://scripts/challenge/challenge_save_service.gd"

var failures: Array[String] = []
var save_path := OS.get_temp_dir().path_join("project_rest_two_challenge_save_test.json")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var service = load(SERVICE_PATH)
	_expect(service != null, "challenge save service should load")
	_expect(service.SAVE_PATH == "user://project_rest_two_save_v1.json", "save path should use project-rest-two namespace")
	_expect(service.SAVE_PATH.find("project_rest_new") == -1, "save path must not mention project-rest-new")
	var source := service.empty_save()
	source["meta"]["unlocked_recipe_ids"] = ["butter_cookie"]
	var saved: Dictionary = service.save_to_path(save_path, source)
	_expect(bool(saved.get("ok", false)), "save should succeed")
	var loaded: Dictionary = service.load_from_path(save_path)
	_expect(bool(loaded.get("ok", false)), "load should succeed")
	_expect(loaded.get("data", {}) == source, "loaded data should match saved data")
	_cleanup()
	_finish()
```

Include `_expect`, `_cleanup`, and `_finish` helpers that print `CHALLENGE_SAVE_SERVICE_SELF_CHECK_PASS` and return exit code 0 only when `failures` is empty.

- [ ] **Step 2: Run the save self-check and verify it fails**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-two-save-test.log" -s res://tests/challenge/challenge_save_service_self_check.gd
```

Expected: non-zero exit because `challenge_save_service.gd` does not exist.

- [ ] **Step 3: Implement the minimal atomic save service**

Use this exact save shape:

```gdscript
class_name ChallengeSaveService
extends RefCounted

const SAVE_PATH := "user://project_rest_two_save_v1.json"
const BROKEN_SAVE_PATH := "user://project_rest_two_save_v1.broken.json"


static func empty_save() -> Dictionary:
	return {
		"schema_version": 1,
		"meta": {
			"research_points": 0,
			"unlocked_recipe_ids": [],
			"revealed_research_node_ids": [],
			"boss_first_clear_ids": [],
			"endless_records": {}
		},
		"active_run": null,
		"active_battle": null
	}
```

`save_to_path` must write JSON to `path + ".tmp"` and close the file. If `path + ".previous"` exists, remove that previous backup; if the target exists, rename it to `path + ".previous"`; finally rename the temp file to the target. Return `{"ok": true}` or `{"ok": false, "error": "..."}` without throwing.

`load_from_path` must:

1. return `{"ok": true, "data": empty_save(), "source": "new"}` when no file exists;
2. parse the target and require a Dictionary;
3. when the target is malformed, rename it to `path + ".broken"` without overwriting an existing broken copy;
4. try `path + ".previous"` and restore it to the target when valid;
5. return a structured error when neither file is valid.

- [ ] **Step 4: Run the save self-check**

Run the command from Step 2.

Expected: `CHALLENGE_SAVE_SERVICE_SELF_CHECK_PASS`.

- [ ] **Step 5: Commit**

```powershell
git add scripts/challenge/challenge_save_service.gd tests/challenge/challenge_save_service_self_check.gd
git commit -m "feat: add isolated challenge save service"
```

---

### Task 2: Six-Recipe and Boss Configuration Contract

**Files:**
- Create: `doc/challenge/challenge_recipes.json`
- Create: `doc/challenge/boss_encounters.json`
- Create: `scripts/challenge/challenge_config_validator.gd`
- Create: `tests/challenge/challenge_config_validator_self_check.gd`

**Interfaces:**
- Consumes: parsed recipe, encounter, and existing catalog dictionaries.
- Produces:
  - `ChallengeConfigValidator.validate(recipe_config, encounter_config, catalog_recipes) -> Dictionary`
  - result fields `valid: bool`, `errors: Array[String]`, `recipe_defs: Dictionary`, `encounters: Dictionary`.

- [ ] **Step 1: Add a failing validator self-check**

Test these exact failures:

```gdscript
var missing_recipe := validator.validate(
	{"grid_rows": 6, "grid_columns": 8, "supply_budget": 16, "recipes": {"not_in_catalog": _valid_recipe()}},
	{"encounters": {"critic": _valid_encounter()}},
	{}
)
_expect(not missing_recipe.valid, "unknown catalog recipe should be invalid")

var bad_window := _valid_encounter()
bad_window["windows"][1]["at_ms"] = 8000
var bad_order := validator.validate(
	_valid_recipe_config(),
	{"encounters": {"critic": bad_window}},
	{"butter_cookie": {}}
)
_expect(not bad_order.valid, "demand windows should be strictly ordered")
```

Also assert that the committed JSON:

- contains exactly 6 recipes;
- uses a 6×8 grid and supply budget 16;
- has windows exactly at `[8000, 16000, 24000]`;
- has final time `30000`;
- references only recipe IDs found in `Catalog.new().get_recipes()`.

- [ ] **Step 2: Run the validator self-check and verify it fails**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-two-config-test.log" -s res://tests/challenge/challenge_config_validator_self_check.gd
```

Expected: non-zero exit because the files do not exist.

- [ ] **Step 3: Add the six-recipe configuration**

Use these definitions:

| Recipe | Shape cells | Cost | Copy limit | Virtual stock | Cycle | Satisfaction | Tags |
|---|---|---:|---:|---:|---:|---:|---|
| `butter_cookie` | `[[0,0]]` | 2 | 3 | 6 | 4000 ms | 4 | `fast,bake` |
| `strawberry_jelly` | `[[0,0]]` | 2 | 3 | 5 | 5000 ms | 5 | `fast,fruit` |
| `milk_pudding` | `[[0,0],[0,1]]` | 3 | 2 | 4 | 5000 ms | 7 | `drink,set` |
| `blueberry_muffin` | `[[0,0],[1,0]]` | 3 | 2 | 5 | 6000 ms | 8 | `bake,set` |
| `sponge_cake` | `[[0,0],[0,1],[1,0],[1,1]]` | 5 | 1 | 3 | 8000 ms | 22 | `signature,bake` |
| `chocolate_lava_cake` | `[[0,0],[0,1],[1,0],[1,1]]` | 5 | 1 | 3 | 10000 ms | 29 | `signature,chocolate` |

Coordinates are `[row, column]`. Rotation is allowed for the two-cell recipes and disabled for square recipes.

- [ ] **Step 4: Add the first Boss configuration**

Create encounter `picky_food_critic`:

```json
{
  "duration_ms": 30000,
  "initial_pickiness": 197,
  "initial_reputation": 100,
  "relation_bonus_pct": 25,
  "relation": {
    "id": "drink_bake_pair",
    "left_tag": "drink",
    "right_tag": "bake"
  },
  "windows": [
    {"id": "early_tempo", "at_ms": 8000, "metric": "sales_count", "target": 3, "reputation_damage": 25},
    {"id": "linked_display", "at_ms": 16000, "metric": "active_relation_count", "target": 1, "reputation_damage": 30},
    {"id": "sustained_service", "at_ms": 24000, "from_ms": 16000, "metric": "window_satisfaction", "target": 30, "reputation_damage": 45}
  ]
}
```

The final 30-second check wins only when pickiness is zero; otherwise it loses by timeout.

- [ ] **Step 5: Implement config validation**

Validate required keys, positive numeric values, shape uniqueness, recipe catalog presence, copy limits, known metrics, strictly increasing windows, and the last window occurring before duration.

For theoretical availability, enumerate the six recipe copy-count vectors from zero through each `copy_limit` (at most 576 combinations). Reject combinations over budget or 48 occupied cells. At least one remaining combination must:

- produce 3 or more sales by 8000 ms;
- include both a `drink` and a `bake` instance;
- produce 30 or more satisfaction during `(16000, 24000]`;
- produce at least 197 total satisfaction by 30000 ms after one non-stacking 25% relation bonus per participating instance.

The validator does not solve exact placement; the loadout tests prove that a drink/bake relation fits the board.

Return all errors in one pass, prefixed with the failing ID:

```gdscript
return {
	"valid": errors.is_empty(),
	"errors": errors,
	"recipe_defs": recipe_config.get("recipes", {}),
	"encounters": encounter_config.get("encounters", {})
}
```

- [ ] **Step 6: Run the validator self-check**

Run the command from Step 2.

Expected: `CHALLENGE_CONFIG_VALIDATOR_SELF_CHECK_PASS`.

- [ ] **Step 7: Commit**

```powershell
git add doc/challenge scripts/challenge/challenge_config_validator.gd tests/challenge/challenge_config_validator_self_check.gd
git commit -m "feat: define vertical slice challenge data"
```

---

### Task 3: Challenge Supply and Spatial Loadout

**Files:**
- Create: `scripts/challenge/challenge_loadout_service.gd`
- Create: `tests/challenge/challenge_loadout_service_self_check.gd`

**Interfaces:**
- Consumes:
  - draft `{"placements": Array[Dictionary]}`
  - recipe definitions from Task 2
  - board rows, columns, budget, and encounter relation rule.
- Produces:
  - `analyze(draft, recipe_defs, rows, columns, budget, encounter) -> Dictionary`
  - `build_snapshot(draft, recipe_defs, encounter, rows, columns, budget) -> Dictionary`
  - analysis fields `valid`, `errors`, `spent_budget`, `occupied_cells`, `relations`, `instances`.

- [ ] **Step 1: Write failing loadout cases**

Use instance-based placements so duplicate recipes are unambiguous:

```gdscript
var valid_draft := {"placements": [
	{"instance_id": "pudding_1", "recipe_id": "milk_pudding", "origin": [2, 2], "rotation": 0},
	{"instance_id": "muffin_1", "recipe_id": "blueberry_muffin", "origin": [2, 4], "rotation": 0}
]}
var valid := service.analyze(valid_draft, defs, 6, 8, 16, encounter)
_expect(valid.valid, "adjacent set pair should be valid")
_expect(valid.relations.size() == 1, "drink and bake pair should form one relation")
var built := service.build_snapshot(valid_draft, defs, encounter, 6, 8, 16)
_expect(bool(built.get("ok", false)), "valid draft should build a battle snapshot")
var snapshot_text := JSON.stringify(built.get("snapshot", {}))
_expect(snapshot_text.find("inventory") == -1, "snapshot must not contain inventory state")
valid_draft["placements"].clear()
_expect((built.get("snapshot", {}).get("instances", []) as Array).size() == 2, "snapshot should be isolated from later draft mutation")

var overlap := {"placements": [
	{"instance_id": "a", "recipe_id": "sponge_cake", "origin": [0, 0], "rotation": 0},
	{"instance_id": "b", "recipe_id": "butter_cookie", "origin": [1, 1], "rotation": 0}
]}
_expect(not service.analyze(overlap, defs, 6, 8, 16, encounter).valid, "overlap should be invalid")
```

Add explicit cases for out-of-bounds, unknown recipe, duplicate instance ID, copy-limit overflow, budget overflow, and 90-degree rotation of `milk_pudding`.

- [ ] **Step 2: Run and verify failure**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-two-loadout-test.log" -s res://tests/challenge/challenge_loadout_service_self_check.gd
```

Expected: non-zero exit because the service is missing.

- [ ] **Step 3: Implement normalized shape rotation**

Implement:

```gdscript
static func rotated_cells(shape_cells: Array, rotation: int) -> Array[Vector2i]:
	var turns := int(posmod(rotation, 360) / 90)
	var cells: Array[Vector2i] = []
	for value in shape_cells:
		var cell := Vector2i(int(value[0]), int(value[1]))
		for _turn in range(turns):
			cell = Vector2i(cell.y, -cell.x)
		cells.append(cell)
	var min_row := cells.map(func(cell): return cell.x).min()
	var min_column := cells.map(func(cell): return cell.y).min()
	for index in range(cells.size()):
		cells[index] -= Vector2i(min_row, min_column)
	cells.sort_custom(func(left, right): return left.x < right.x or (left.x == right.x and left.y < right.y))
	return cells
```

Reject rotations not divisible by 90 and non-zero rotations for recipes with `rotatable: false`.

- [ ] **Step 4: Implement occupancy, budget, copies, and relation analysis**

Touching means Manhattan-adjacent cells, not diagonal cells. One drink/bake instance pair produces one `drink_bake_pair` relation regardless of how many borders touch.

Store occupied cells as `"row:column"` keys and relation entries as:

```gdscript
{
	"relation_id": "drink_bake_pair",
	"left_instance_id": "pudding_1",
	"right_instance_id": "muffin_1",
	"bonus_pct": 25
}
```

- [ ] **Step 5: Build an immutable battle snapshot**

`build_snapshot` first calls `analyze`. On failure return `{"ok": false, "errors": errors}`. On success return a deep-duplicated snapshot:

```gdscript
{
	"ok": true,
	"snapshot": {
		"grid_rows": 6,
		"grid_columns": 8,
		"spent_budget": 6,
		"instances": analyzed_instances,
		"relations": relations,
		"encounter_id": "picky_food_critic"
	}
}
```

Each instance contains its own `virtual_stock`, `cycle_ms`, `base_satisfaction`, `tags`, and resolved absolute cells. It contains no warehouse or inventory key.

- [ ] **Step 6: Run the loadout self-check**

Expected: `CHALLENGE_LOADOUT_SERVICE_SELF_CHECK_PASS`.

- [ ] **Step 7: Commit**

```powershell
git add scripts/challenge/challenge_loadout_service.gd tests/challenge/challenge_loadout_service_self_check.gd
git commit -m "feat: add challenge loadout validation"
```

---

### Task 4: Deterministic Automatic Boss Battle

**Files:**
- Create: `scripts/challenge/boss_battle_service.gd`
- Create: `tests/challenge/boss_battle_service_self_check.gd`

**Interfaces:**
- Consumes: immutable snapshot from Task 3 and encounter definition from Task 2.
- Produces:
  - `create_state(snapshot, encounter, seed) -> Dictionary`
  - `advance(state, target_elapsed_ms) -> Dictionary`
  - `simulate(snapshot, encounter, seed) -> Dictionary`
  - state fields `phase`, `elapsed_ms`, `pickiness`, `reputation`, `item_states`, `resolved_windows`, `events`, `outcome`.

- [ ] **Step 1: Write failing deterministic event tests**

Build a snapshot with one 2500 ms cookie and assert:

```gdscript
var first := service.simulate(snapshot, encounter, 42)
var second := service.simulate(snapshot, encounter, 42)
_expect(first.events == second.events, "same snapshot and seed should replay identically")
_expect(first.outcome == second.outcome, "same snapshot and seed should keep outcome")

var boundary := service.advance(service.create_state(snapshot_with_4000_ms_cookie, encounter, 42), 8000)
var sale_index := _event_index(boundary.events, "sale", 8000)
var window_index := _event_index(boundary.events, "demand_window", 8000)
_expect(sale_index >= 0 and sale_index < window_index, "sale due exactly at the window should resolve first")
```

Add tests for:

- simultaneous sales sorted by `instance_id`;
- virtual stock stopping further sales;
- 25% relation bonus using integer calculation `floor(base * 125 / 100)`;
- window damage only once;
- immediate victory when pickiness reaches zero;
- timeout loss at 30000 ms;
- `advance` refusing to move backward.

- [ ] **Step 2: Run and verify failure**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-two-battle-test.log" -s res://tests/challenge/boss_battle_service_self_check.gd
```

Expected: non-zero exit because the service is missing.

- [ ] **Step 3: Implement battle state creation**

Initialize each item:

```gdscript
item_states[instance_id] = {
	"instance_id": instance_id,
	"recipe_id": instance.recipe_id,
	"next_sale_ms": int(instance.cycle_ms),
	"remaining_stock": int(instance.virtual_stock),
	"sales_count": 0,
	"satisfaction": 0
}
```

Initial battle phase is `running`; pickiness and reputation come only from the encounter.

- [ ] **Step 4: Implement stable sale scheduling**

Deep-duplicate the input state before advancing so callers cannot mutate a saved checkpoint accidentally. For every next timestamp up to `target_elapsed_ms`:

1. collect due instances;
2. sort by `instance_id`;
3. emit sale events and reduce stock;
4. emit relation events;
5. subtract satisfaction from pickiness;
6. check immediate victory;
7. resolve any demand window at that timestamp;
8. check reputation loss.

An instance participating in one or more valid relations receives the 25% bonus once per sale; multiple touching partners do not stack the bonus in Stage 1.

Every event contains:

```gdscript
{
	"seq": next_event_seq,
	"at_ms": event_time,
	"type": "sale",
	"source_id": instance_id,
	"recipe_id": recipe_id,
	"base_satisfaction": base_value,
	"relation_bonus": bonus_value,
	"final_satisfaction": final_value
}
```

- [ ] **Step 5: Implement the three metrics and final deadline**

- `sales_count`: cumulative sale count at the window.
- `active_relation_count`: snapshot relation count.
- `window_satisfaction`: satisfaction from events where `from_ms < at_ms <= window.at_ms`.

Demand event fields include `actual`, `target`, `passed`, `reputation_damage`, and `reputation_after`.

At 30000 ms, emit `battle_end` with `outcome: "victory"` only if pickiness is zero; otherwise `outcome: "loss_timeout"`.

- [ ] **Step 6: Run the battle self-check**

Expected: `BOSS_BATTLE_SERVICE_SELF_CHECK_PASS`.

- [ ] **Step 7: Commit**

```powershell
git add scripts/challenge/boss_battle_service.gd tests/challenge/boss_battle_service_self_check.gd
git commit -m "feat: add deterministic boss battle engine"
```

---

### Task 5: Explainable Report and Idempotent Retry State

**Files:**
- Create: `scripts/challenge/boss_battle_report_service.gd`
- Create: `scripts/challenge/challenge_run_service.gd`
- Create: `tests/challenge/boss_battle_report_self_check.gd`
- Create: `tests/challenge/challenge_run_service_self_check.gd`

**Interfaces:**
- Consumes: final battle state and encounter.
- Produces:
  - `BossBattleReportService.build(battle_state, encounter) -> Dictionary`
  - `ChallengeRunService.create_single_encounter(run_id, seed, encounter_id) -> Dictionary`
  - `ChallengeRunService.register_result(run_state, settlement) -> Dictionary`.

- [ ] **Step 1: Write failing report assertions**

The report test must assert exact fields:

```gdscript
var report := service.build(failed_battle, encounter)
_expect(report.outcome == "loss_timeout", "report should preserve outcome")
_expect(report.windows.size() == 3, "report should include all demand windows")
_expect(report.primary_failure.window_id == "sustained_service", "report should identify the final failed window")
_expect(report.primary_failure.actual == 22, "report should expose actual value")
_expect(report.primary_failure.target == 30, "report should expose target value")
_expect(report.suggestions[0].code == "increase_window_satisfaction", "suggestion should come from a fixed rule")
```

Recipe contribution rows contain `recipe_id`, `sales_count`, `base_satisfaction`, `relation_bonus`, and `total_satisfaction`, sorted by total descending then recipe ID.

- [ ] **Step 2: Write failing run-state assertions**

```gdscript
var run := service.create_single_encounter("run-1", 42, "picky_food_critic")
_expect(run.confidence == 2, "run should start with two confidence")
var first_loss := service.register_result(run, {
	"settlement_id": "settlement-1",
	"outcome": "loss_timeout",
	"encounter_id": "picky_food_critic"
})
_expect(first_loss.run.confidence == 1, "first loss should consume one confidence")
_expect(first_loss.run.phase == "preparation", "first loss should return to preparation")
var duplicate := service.register_result(first_loss.run, {
	"settlement_id": "settlement-1",
	"outcome": "loss_timeout",
	"encounter_id": "picky_food_critic"
})
_expect(duplicate.run.confidence == 1, "duplicate settlement must not consume confidence")
```

Also assert that the second unique loss ends the run and that encounter ID and reward seed do not change after the first loss.

- [ ] **Step 3: Run both tests and verify failure**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-two-report-test.log" -s res://tests/challenge/boss_battle_report_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-two-run-test.log" -s res://tests/challenge/challenge_run_service_self_check.gd
```

Expected: both fail because the services are missing.

- [ ] **Step 4: Implement fixed-rule report generation**

Map metrics to suggestion codes:

```gdscript
const SUGGESTION_BY_METRIC := {
	"sales_count": {"code": "increase_early_sales", "text": "增加短周期配方或提高前段挑战备货。"},
	"active_relation_count": {"code": "build_drink_bake_relation", "text": "让饮品与烘焙配方正交相邻，激活组合关系。"},
	"window_satisfaction": {"code": "increase_window_satisfaction", "text": "提高中后段满足力，或避免关键配方过早耗尽。"}
}
```

Do not generate prose from randomness or an online service.

- [ ] **Step 5: Implement single-encounter run state**

Run state includes:

```gdscript
{
	"run_id": run_id,
	"mode": "vertical_slice",
	"seed": seed,
	"phase": "preparation",
	"confidence": 2,
	"encounter_id": encounter_id,
	"encounter_seed": seed,
	"reward_seed": seed + 1000,
	"settled_ids": []
}
```

`register_result` deep-duplicates input, checks `settled_ids`, and returns `{"applied": false, "run": unchanged}` for duplicates.

- [ ] **Step 6: Run both self-checks**

Expected pass tokens:

- `BOSS_BATTLE_REPORT_SELF_CHECK_PASS`
- `CHALLENGE_RUN_SERVICE_SELF_CHECK_PASS`

- [ ] **Step 7: Commit**

```powershell
git add scripts/challenge/boss_battle_report_service.gd scripts/challenge/challenge_run_service.gd tests/challenge/boss_battle_report_self_check.gd tests/challenge/challenge_run_service_self_check.gd
git commit -m "feat: add battle report and retry state"
```

---

### Task 6: Scene-First Challenge Supply and Board

**Files:**
- Create: `scenes/challenge/challenge_supply_card.tscn`
- Create: `scenes/challenge/challenge_board.tscn`
- Create: `scripts/challenge/ui/challenge_supply_card.gd`
- Create: `scripts/challenge/ui/challenge_board.gd`
- Create: `tests/challenge/challenge_board_scene_self_check.gd`

**Interfaces:**
- Consumes: recipe definitions and a loadout draft.
- Produces:
  - supply signal `recipe_drag_started(recipe_id: String)`
  - board signals `draft_changed(draft: Dictionary)` and `placement_rejected(reasons: Array[String])`
  - `bind(recipe_defs, loadout_service, encounter, budget) -> void`
  - `set_draft(draft)`, `get_draft()`, `place_recipe(...)`, `rotate_instance(...)`, `remove_instance(...)`, `set_locked(bool)`.

- [ ] **Step 1: Write the failing scene contract**

Instantiate `challenge_board.tscn` at 1920×1080 and assert:

```gdscript
var board := BOARD_SCENE.instantiate()
root.add_child(board)
await process_frame
_expect(board.get_node("BoardGrid").columns == 8, "board should use eight columns")
_expect(board.get_node("BoardGrid").get_child_count() == 48, "board should expose 6x8 cells")
_expect(board.has_method("place_recipe"), "board should expose placement intent")
_expect(board.has_method("set_locked"), "board should expose battle lock")
```

Bind the six recipe definitions, place and rotate `milk_pudding`, then verify two occupied cells. Lock the board and verify placement, rotation, and removal return false without mutating the draft.

- [ ] **Step 2: Run and verify failure**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-two-board-test.log" -s res://tests/challenge/challenge_board_scene_self_check.gd
```

- [ ] **Step 3: Build stable `.tscn` structure**

`challenge_board.tscn`:

```text
ChallengeBoard (VBoxContainer)
  Header (HBoxContainer)
    BudgetLabel
    CoverageLabel
    RiskLabel
  BoardFrame (PanelContainer)
    BoardGrid (GridContainer, columns=8)
  RelationSummary (RichTextLabel)
```

`challenge_supply_card.tscn`:

```text
ChallengeSupplyCard (Button)
  Icon (TextureRect)
  NameLabel (Label)
  CostBadge (Label)
  CountBadge (Label)
```

Use 80×80 board cells. Recipe visuals use `ShowcaseIconService.fragment(...)` when a staged fragment exists and `RecipeIconService.texture(...)` as fallback.

- [ ] **Step 4: Implement drag, placement, rotation, and removal as intent**

Drag payload:

```gdscript
{
	"kind": "challenge_recipe",
	"recipe_id": recipe_id
}
```

The board delegates every mutation to `ChallengeLoadoutService.analyze`. Rejected drafts emit exact service errors and preserve the previous draft.

Right-click rotates the instance under the pointer by 90 degrees. Dragging an existing instance outside the board removes it only while unlocked.

- [ ] **Step 5: Bind visible coverage and reasons**

Display:

- `挑战备货 6 / 16`
- active relation names;
- first validation error;
- `稳定覆盖／边缘／缺口` values supplied by the parent controller.

Supply cards show selected count and copy limit; they never read warehouse stock.

- [ ] **Step 6: Run the board scene self-check**

Expected: `CHALLENGE_BOARD_SCENE_SELF_CHECK_PASS`.

- [ ] **Step 7: Commit**

```powershell
git add scenes/challenge/challenge_supply_card.tscn scenes/challenge/challenge_board.tscn scripts/challenge/ui/challenge_supply_card.gd scripts/challenge/ui/challenge_board.gd tests/challenge/challenge_board_scene_self_check.gd
git commit -m "feat: add challenge supply board"
```

---

### Task 7: Double-Pressure Battle Presentation

**Files:**
- Create: `scenes/challenge/challenge_battle_view.tscn`
- Create: `scripts/challenge/ui/challenge_battle_view.gd`
- Create: `tests/challenge/challenge_battle_view_self_check.gd`

**Interfaces:**
- Consumes: battle snapshot, encounter, and `BossBattleService`.
- Produces:
  - signal `battle_finished(final_state: Dictionary)`
  - read-only presentation flags `battle_locked: bool` and `battle_paused: bool`
  - `bind_encounter(encounter) -> void`
  - `start_battle(snapshot, seed) -> void`
  - `restore_battle(saved_state, encounter) -> void`
  - `advance_for_test(target_elapsed_ms) -> void`
  - `set_paused(paused: bool) -> void`.

- [ ] **Step 1: Write the failing battle view contract**

Assert node paths and state behavior:

```gdscript
_expect(view.get_node("TopStatus/ReputationBar") is ProgressBar, "reputation bar should exist")
_expect(view.get_node("TopStatus/PickinessBar") is ProgressBar, "pickiness bar should exist")
_expect(view.get_node("BossPanel/DemandTimeline").get_child_count() == 4, "timeline should show 8/16/24/30")
view.start_battle(snapshot, 42)
_expect(view.get("battle_locked"), "battle should lock immediately")
view.advance_for_test(16000)
_expect(view.get_node("BossPanel/DemandTimeline/Window16").has_theme_color_override("font_color"), "current window should be visually resolved")
var saved_state: Dictionary = view.get("battle_state").duplicate(true)
view.restore_battle(saved_state, encounter)
_expect(bool(view.get("battle_paused")), "restored battle should start paused")
view.advance_for_test(24000)
_expect(int((view.get("battle_state") as Dictionary).get("elapsed_ms", 0)) == 16000, "paused restored battle should not advance")
view.set_paused(false)
view.advance_for_test(24000)
_expect(int((view.get("battle_state") as Dictionary).get("elapsed_ms", 0)) == 24000, "continued battle should resume from saved time")
```

Advance to completion and assert `battle_finished` fires once.

- [ ] **Step 2: Run and verify failure**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-two-battle-view-test.log" -s res://tests/challenge/challenge_battle_view_self_check.gd
```

- [ ] **Step 3: Build the battle scene**

```text
ChallengeBattleView (Control)
  TopStatus (HBoxContainer)
    ConfidenceLabel
    ReputationLabel
    ReputationBar
    PickinessLabel
    PickinessBar
  BattleBody (HBoxContainer)
    BoardPresentation (Control)
    BossPanel (VBoxContainer)
      BossPortrait
      BossName
      BossRule
      DemandTimeline (VBoxContainer)
        Window08
        Window16
        Window24
        Window30
  BattleFooter (HBoxContainer)
    CurrentDemandLabel
    NextDemandLabel
    PauseButton
```

The board remains visually present but does not expose mutation controls.

- [ ] **Step 4: Implement event-driven refresh**

`_process` may call `advance`, but it must not calculate satisfaction. For each new event:

- sale: pulse the source item and show satisfaction toward `PickinessBar`;
- relation: highlight both related instances;
- demand window: mark pass/fail and animate reputation loss;
- battle end: stop processing and emit `battle_finished` once.

`advance_for_test` uses the same refresh path without waiting for real time and refuses to advance while `battle_paused` is true.

`restore_battle` deep-duplicates the saved battle state, renders all already resolved windows, sets the view to paused, and waits for `set_paused(false)` before `_process` advances time.

- [ ] **Step 5: Run the battle view self-check**

Expected: `CHALLENGE_BATTLE_VIEW_SELF_CHECK_PASS`.

- [ ] **Step 6: Commit**

```powershell
git add scenes/challenge/challenge_battle_view.tscn scripts/challenge/ui/challenge_battle_view.gd tests/challenge/challenge_battle_view_self_check.gd
git commit -m "feat: add double-pressure battle view"
```

---

### Task 8: Settlement, Same-Encounter Retry, and Challenge Root

**Files:**
- Create: `scenes/challenge/challenge_settlement_dialog.tscn`
- Create: `scripts/challenge/ui/challenge_settlement_dialog.gd`
- Create: `scenes/challenge/challenge_main.tscn`
- Create: `scripts/challenge/challenge_main_view.gd`
- Create: `tests/challenge/challenge_main_scene_self_check.gd`

**Interfaces:**
- Consumes: services from Tasks 1–7.
- Produces:
  - a complete preparation → battle → result → retry loop;
  - settlement signal `retry_requested`;
  - root methods `start_vertical_slice()`, `start_battle()`, `retry_same_encounter()`.

- [ ] **Step 1: Write the failing root-scene flow**

The test uses these two drafts:

```gdscript
var failing_draft := {"placements": [
	{"instance_id": "cookie_only", "recipe_id": "butter_cookie", "origin": [0, 0], "rotation": 0}
]}
var passing_draft := {"placements": [
	{"instance_id": "pudding_1", "recipe_id": "milk_pudding", "origin": [0, 0], "rotation": 0},
	{"instance_id": "muffin_1", "recipe_id": "blueberry_muffin", "origin": [1, 0], "rotation": 0},
	{"instance_id": "pudding_2", "recipe_id": "milk_pudding", "origin": [0, 3], "rotation": 0},
	{"instance_id": "muffin_2", "recipe_id": "blueberry_muffin", "origin": [1, 3], "rotation": 0},
	{"instance_id": "cookie_1", "recipe_id": "butter_cookie", "origin": [4, 0], "rotation": 0},
	{"instance_id": "cookie_2", "recipe_id": "butter_cookie", "origin": [4, 1], "rotation": 0}
]}
```

The passing draft costs exactly 16, forms two drink/bake relations, survives all windows, produces 212 total satisfaction, and reduces 197 pickiness to zero at 30 seconds.

Instantiate the new root and assert:

```gdscript
_expect(view.get_node("Root/TopBar/ConfidenceLabel").text.find("2") >= 0, "run should start with two confidence")
_expect(view.get_node("Root/Body/PreparationPanel").visible, "preparation should be visible first")
_expect(not view.get_node("Root/Body/BattlePanel").visible, "battle should be hidden before start")
view.call("set_draft_for_test", failing_draft)
view.call("start_battle")
_expect(view.get_node("Root/Body/BattlePanel").visible, "battle should become visible")
view.call("advance_battle_for_test", 30000)
_expect(view.get_node("SettlementDialog").visible, "settlement should open")
var run_before_retry: Dictionary = view.get("run_state")
var encounter_before: String = String(run_before_retry.get("encounter_id", ""))
view.get_node("SettlementDialog/Margin/Content/ActionRow/RetryButton").emit_signal("pressed")
await process_frame
var run_after_retry: Dictionary = view.get("run_state")
_expect(int(run_after_retry.get("confidence", 0)) == 1, "retry should retain one confidence")
_expect(String(run_after_retry.get("encounter_id", "")) == encounter_before, "retry should preserve encounter")
view.call("set_draft_for_test", passing_draft)
view.call("start_battle")
view.call("advance_battle_for_test", 30000)
var final_battle: Dictionary = view.get("battle_state")
_expect(String(final_battle.get("outcome", "")) == "victory", "reworked draft should win")
```

Use a deliberately failing draft for the retry assertion and a passing draft for the final victory assertion.

- [ ] **Step 2: Run and verify failure**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-two-main-scene-test.log" -s res://tests/challenge/challenge_main_scene_self_check.gd
```

- [ ] **Step 3: Build settlement content in `.tscn`**

```text
ChallengeSettlementDialog (PopupPanel)
  Margin (MarginContainer)
    Content (VBoxContainer)
      ResultTitle
      PressureSummary
      WindowRows
      ContributionRows
      PrimaryFailure
      SuggestionList
      ActionRow
        RetryButton
        BackButton
```

`bind_report(report)` fills existing nodes; it does not create the stable shell in code.

- [ ] **Step 4: Build the challenge root scene**

```text
ChallengeMain (Control)
  Root (VBoxContainer)
    TopBar (HBoxContainer)
      StageLabel
      ConfidenceLabel
      SaveStatusLabel
    Body (Stacked panels)
      PreparationPanel
        MainColumns
          ChallengeBoard
          BossPreview
        SupplyStrip
        StartButton
      BattlePanel
        ChallengeBattleView
  SettlementDialog
```

The preparation panel follows the approved “橱窗战场优先” layout: large board left, Boss and full timeline right, supply and start action at the bottom.

- [ ] **Step 5: Implement orchestration without domain calculations**

`challenge_main_view.gd` may:

- load and validate JSON;
- create a single-encounter run;
- bind scenes;
- request snapshot creation;
- simulate a valid draft to classify each window as `稳定覆盖／边缘／缺口`;
- pass snapshot to battle view;
- build and show report;
- register settlement;
- save after run creation, battle start, result, and retry.

When configuration validation fails, keep `StartButton` disabled and show `挑战配置无效：<first error>`. When a loadout is invalid, put the first validation error in the button tooltip. A theoretically weak but legal loadout remains startable and shows a risk warning instead.

It must not:

- calculate occupancy, satisfaction, window pass/fail, confidence, or report text;
- access `GameState.inventory`, `display_items`, production, or old research;
- call any old refill method.

- [ ] **Step 6: Restore an interrupted battle paused**

When save data contains `active_battle`, instantiate the battle view from the saved state and show a `继续挑战` button. Do not advance elapsed time until the player presses it.

If active battle parsing fails but run state is valid, return to preparation with the same encounter and show `战斗进度损坏，已回到本场战前准备。`.

- [ ] **Step 7: Run the root scene self-check**

Expected: `CHALLENGE_MAIN_SCENE_SELF_CHECK_PASS`.

- [ ] **Step 8: Commit**

```powershell
git add scenes/challenge/challenge_settlement_dialog.tscn scenes/challenge/challenge_main.tscn scripts/challenge/ui/challenge_settlement_dialog.gd scripts/challenge/challenge_main_view.gd tests/challenge/challenge_main_scene_self_check.gd
git commit -m "feat: complete single boss retry loop"
```

---

### Task 9: Default Entry, Aggregate Verification, and Isolation Proof

**Files:**
- Modify: `project.godot`
- Create: `tests/challenge/challenge_vertical_slice_self_check.gd`
- Create: `docs/superpowers/verification/2026-07-27-backpack-boss-vertical-slice-playtest.md`

**Interfaces:**
- Consumes: all Stage 1 services and scenes.
- Produces: `res://scenes/challenge/challenge_main.tscn` as the default project entry and one aggregate release gate.

- [ ] **Step 1: Add the failing aggregate self-check**

The aggregate self-check must load every Stage 1 file, instantiate the root at 1920×1080, and run:

1. valid loadout snapshot;
2. deterministic simulation twice;
3. one deliberate loss;
4. same encounter retry with confidence 1;
5. one victory;
6. save/load round trip;
7. forbidden dependency scan.

Forbidden source tokens under `res://scripts/challenge/`:

```gdscript
const FORBIDDEN_TOKENS := [
	"project_rest_new_save",
	"state.inventory",
	"display_items",
	"refill_item(",
	"production_queue",
	"RecipeBook.research"
]
```

The test prints `CHALLENGE_VERTICAL_SLICE_SELF_CHECK_PASS` only after all checks pass.

- [ ] **Step 2: Run the aggregate test before switching the main scene**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-two-vertical-slice.log" -s res://tests/challenge/challenge_vertical_slice_self_check.gd
```

Expected: fail until all integration gaps are fixed.

- [ ] **Step 3: Fix only integration gaps exposed by the aggregate test**

Allowed fixes are limited to Stage 1 files listed in this plan. Do not repair failures by editing `main_view.gd`, old inventory, production, research, task, tutorial, or `.gitignore`.

Re-run the aggregate test after each fix until it prints the pass token.

- [ ] **Step 4: Switch the default scene**

Change exactly:

```ini
run/main_scene="res://scenes/challenge/challenge_main.tscn"
```

Keep viewport width 1920, viewport height 1080, and stretch mode `canvas_items`.

- [ ] **Step 5: Run all Stage 1 self-checks**

```powershell
$tests = @(
  'challenge_save_service_self_check.gd',
  'challenge_config_validator_self_check.gd',
  'challenge_loadout_service_self_check.gd',
  'boss_battle_service_self_check.gd',
  'boss_battle_report_self_check.gd',
  'challenge_run_service_self_check.gd',
  'challenge_board_scene_self_check.gd',
  'challenge_battle_view_self_check.gd',
  'challenge_main_scene_self_check.gd',
  'challenge_vertical_slice_self_check.gd'
)
foreach ($test in $tests) {
  & "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-two-$test.log" -s "res://tests/challenge/$test"
  if ($LASTEXITCODE -ne 0) { throw "$test failed" }
}
```

Expected: all ten tests exit 0.

- [ ] **Step 6: Verify the real player path**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64.exe" --path .
```

Using only the mouse:

1. read all four Boss timeline points;
2. drag six-recipe supply cards onto the board;
3. rotate `milk_pudding`;
4. see the drink/bake relation activate;
5. see budget and risk update;
6. start battle;
7. confirm all build controls are locked;
8. watch current and next demand indicators;
9. lose and read the exact failed metric;
10. retry the same Boss with confidence 1;
11. change the layout and win;
12. close and reopen during battle, then confirm it resumes paused.

- [ ] **Step 7: Record product playtest evidence**

Record at least three human-observed runs in `docs/superpowers/verification/2026-07-27-backpack-boss-vertical-slice-playtest.md`:

```markdown
# Backpack Boss Vertical Slice Playtest

| Run | Player familiarity | Build direction | Understood loop within 2 min | Identified exact loss cause | Chose to rearrange | Result |
|---|---|---|---|---|---|---|

## Go/No-Go

- Continue only if the unfamiliar player identifies the failed window without developer explanation.
- Continue only if all three build directions produce a distinct placement decision.
- Stop and revise feedback if a player describes the result only as “数值不够”.
```

Add one observed row for an unfamiliar fast-build player, one for a familiar set-build player, and one for a familiar signature-build player. If no unfamiliar player is available, Stage 1 remains technically complete but does not pass the product exit gate.

- [ ] **Step 8: Prove source-project isolation**

```powershell
git -C D:\Project\ProjectRest\project-rest-new status --short
git -C D:\Project\ProjectRest\project-rest-new rev-parse HEAD
```

Expected:

- no status output;
- HEAD remains `147ce4b1e3c25e5608dd844fa4c00fd2c3e52323`.

- [ ] **Step 9: Commit**

```powershell
git add project.godot doc/challenge scripts/challenge scenes/challenge tests/challenge docs/superpowers/verification/2026-07-27-backpack-boss-vertical-slice-playtest.md
git diff --cached --name-only
git commit -m "feat: make boss challenge the default vertical slice"
```

Before committing, confirm the staged list contains only `project.godot`, paths under the four challenge directories above, and the playtest report.

- [ ] **Step 10: Final repository check**

```powershell
git status --short --branch
git log --oneline -10
```

Expected: clean `main`; nine focused Stage 1 commits after the plan commit.

---

## Stage 1 Exit Gate

Do not start the five-encounter chain until all statements are true:

- The new challenge root is the default scene.
- One Boss can be lost, explained, retried with the same encounter, and won.
- Six recipes support visibly different fast, set, and signature approaches.
- Battle events are deterministic across replay and save restoration.
- No challenge service touches long-term inventory or production.
- Double pressure bars and 8/16/24/30 demand states are readable at 1920×1080.
- `project-rest-new` remains clean at the recorded base commit.
- The ten Stage 1 self-checks and the real mouse path pass.
- The playtest report contains observed evidence and passes its Go/No-Go rules.
