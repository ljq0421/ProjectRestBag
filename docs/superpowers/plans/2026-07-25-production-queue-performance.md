# Production Queue Performance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the 0.7–0.9 second periodic and post-click stalls from the production queue while preserving queue, picker, completion-stock, drag, and save behavior.

**Architecture:** Split the one-second queue tick from event-level production UI refreshes. Build one reusable picker snapshot per state event, partition craftable and missing entries in a single scan, and update existing queue rows incrementally during countdown ticks.

**Tech Stack:** Godot 4.6.1, GDScript, scene-first UI, repository-local headless self-checks.

## Global Constraints

- Target checkout: `D:\Project\ProjectRest\project-rest-new`.
- Do not change `Catalog.get_*()` public copy semantics.
- Do not change save shape, production timing, three-batch capacity, completion settlement, picker layout, search behavior, or sorting behavior.
- Preserve `production_ready_recipe_records`, `display_sequence`, and the existing `inventory_product` drag protocol.
- Preserve all unrelated untracked files under `resources/ui/icons_v1`.
- Every Godot headless command must include `--log-file` pointing to a writable temp path; never use `NUL`.
- Performance thresholds are measured on the current development machine and are not deterministic unit-test assertions.

---

## File Map

- `scripts/main_view.gd`
  - Owns queue tick routing, picker snapshot construction, snapshot reuse, and event-level refresh.
- `scripts/game_state.gd`
  - Provides a cheap mastery-level read that does not deep-copy the entire recipe catalog.
- `scripts/ui/pages/production_workbench.gd`
  - Separates structural queue refresh from runtime countdown refresh.
- `scripts/ui/pages/production_queue_recipe_row.gd`
  - Updates runtime slot values and avoids recreating unchanged style resources.
- `tests/production_queue_performance_self_check.gd`
  - Guards the high-frequency call graph and snapshot reuse contract.
- `tests/recipe_production_ui_self_check.gd`
  - Verifies one-pass snapshot partitioning with real `GameState`.
- `tests/production_queue_scene_self_check.gd`
  - Verifies incremental row updates and style reuse.

---

### Task 1: Add Failing Performance-Contract Tests

**Files:**
- Create: `tests/production_queue_performance_self_check.gd`
- Modify: `tests/recipe_production_ui_self_check.gd:42-54`
- Modify: `tests/production_queue_scene_self_check.gd:36-68`

**Interfaces:**
- Consumes: current `Main.tscn`, `ProductionWorkbench`, and `ProductionQueueRecipeRow`.
- Produces: required contracts for `_refresh_production_queue_tick(now_unix)`, `_build_production_picker_snapshot()`, cached `production_picker_snapshot`, `refresh_queue_runtime()`, and `refresh_runtime()`.

- [ ] **Step 1: Create the source-level high-frequency regression check**

Create `tests/production_queue_performance_self_check.gd` with these assertions:

```gdscript
extends SceneTree

const MAIN_VIEW_PATH := "res://scripts/main_view.gd"

var failures: Array[String] = []


func _init() -> void:
	var source := FileAccess.get_file_as_string(MAIN_VIEW_PATH)
	var process_block := _function_block(source, "_process")
	var workbench_block := _function_block(source, "_refresh_production_workbench")
	var filter_block := _function_block(source, "_on_production_picker_filter_changed")

	_expect(
		process_block.find("_refresh_production_queue_tick(") >= 0,
		"one-second process must use the lightweight queue tick"
	)
	_expect(
		process_block.find("_refresh_production_workbench(") < 0,
		"one-second process must not rebuild production picker data"
	)
	_expect_equal(
		"event refresh builds one picker snapshot",
		workbench_block.count("_build_production_picker_snapshot("),
		1
	)
	_expect(
		filter_block.find("_build_production_picker_snapshot(") < 0,
		"tab switching must reuse the current picker snapshot"
	)
	_finish()


func _function_block(source: String, function_name: String) -> String:
	var start := source.find("func %s(" % function_name)
	if start < 0:
		return ""
	var next_function := source.find("\nfunc ", start + 1)
	return source.substr(start) if next_function < 0 else source.substr(start, next_function - start)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _expect_equal(label: String, actual: Variant, expected: Variant) -> void:
	if actual != expected:
		failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])


func _finish() -> void:
	if failures.is_empty():
		print("PRODUCTION_QUEUE_PERFORMANCE_SELF_CHECK_PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
```

- [ ] **Step 2: Change the production UI test to require a single snapshot**

Replace the paired `_production_picker_entries()` calls in
`tests/recipe_production_ui_self_check.gd` with:

```gdscript
var picker_snapshot: Dictionary = view.call("_build_production_picker_snapshot")
var craftable_entries: Array = picker_snapshot.get("craftable", [])
var missing_entries: Array = picker_snapshot.get("missing", [])
_expect_equal(
	"snapshot craftable count",
	int(picker_snapshot.get("craftable_count", -1)),
	craftable_entries.size()
)
_expect_equal(
	"snapshot missing count",
	int(picker_snapshot.get("missing_count", -1)),
	missing_entries.size()
)
```

After filling the third active slot, rebuild one snapshot and assert the
recipe is absent from both arrays. After setting rice inventory to zero,
rebuild one snapshot and assert `rice_milk_drink` appears only in `missing`.

- [ ] **Step 3: Require incremental queue-row behavior**

After the initial `row.configure(...)` call in
`tests/production_queue_scene_self_check.gd`, capture the active slot style:

```gdscript
var first_slot := slots.get_node("BatchSlot1") as PanelContainer
var active_style_before := first_slot.get_theme_stylebox("panel")
row.call("refresh_runtime", {
	"batch_progress": [{
		"queue_sequence": 1,
		"batch_index": 0,
		"source": "manual",
		"progress": 0.75,
		"remaining_seconds": 0
	}],
	"completion_feedback": []
})
var active_style_after := first_slot.get_theme_stylebox("panel")
_expect(active_style_before == active_style_after, "unchanged active state should reuse its style")
_expect(is_equal_approx(
	(first_slot.get_node("SlotContent/SlotProgress") as ProgressBar).value,
	0.75
), "runtime refresh should update progress")
```

- [ ] **Step 4: Run the new tests and verify failure**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-new-production-perf.log" -s res://tests/production_queue_performance_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-new-production-ui.log" -s res://tests/recipe_production_ui_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-new-production-scene.log" -s res://tests/production_queue_scene_self_check.gd
```

Expected:

- performance check fails because `_process()` still calls `_refresh_production_workbench()`;
- production UI check fails because `_build_production_picker_snapshot()` does not exist;
- scene check fails because `refresh_runtime()` does not exist.

- [ ] **Step 5: Commit the failing tests**

```powershell
git add -- tests/production_queue_performance_self_check.gd tests/recipe_production_ui_self_check.gd tests/production_queue_scene_self_check.gd
git commit -m "test: guard production queue refresh performance"
```

---

### Task 2: Build and Reuse One Picker Snapshot

**Files:**
- Modify: `scripts/main_view.gd:2794-2807`
- Modify: `scripts/main_view.gd:4628-4712`
- Modify: `scripts/main_view.gd:4784-4825`
- Modify: `scripts/main_view.gd:4870-4943`
- Modify: `scripts/main_view.gd:4973-5010`
- Modify: `scripts/main_view.gd:9030-9060`
- Modify: `scripts/game_state.gd:1468-1472`
- Test: `tests/recipe_production_ui_self_check.gd`
- Test: `tests/production_queue_performance_self_check.gd`

**Interfaces:**
- Produces: `_build_production_picker_snapshot() -> Dictionary`.
- Produces: `_refresh_production_picker(snapshot_value: Dictionary = {}) -> void`.
- Produces: `GameState.recipe_mastery_level(recipe_id: String) -> int`.
- Preserves: `_production_picker_entries(filter_id: String) -> Array` as a compatibility wrapper for focused tests and existing callers.

- [ ] **Step 1: Add a cheap mastery-level accessor**

Add to `scripts/game_state.gd` beside `get_recipe_growth()`:

```gdscript
func recipe_mastery_level(recipe_id: String) -> int:
	if recipe_id.is_empty():
		return 0
	var stored_value: Variant = recipe_growth.get(recipe_id, {})
	if not stored_value is Dictionary:
		return 0
	return clampi(
		int((stored_value as Dictionary).get("mastery_level", 0)),
		RecipeGrowthService.MASTERY_TRIAL,
		RecipeGrowthService.MASTERY_SIGNATURE
	)
```

Update `_recipe_icon_texture()` in `main_view.gd` to call
`state.recipe_mastery_level(recipe_id)` instead of `state.get_recipe_growth()`.

- [ ] **Step 2: Add cached snapshot state**

Add beside the existing picker state fields in `main_view.gd`:

```gdscript
var production_picker_snapshot: Dictionary = {}
```

- [ ] **Step 3: Replace the two-pass builder with a one-pass snapshot**

Implement:

```gdscript
func _build_production_picker_snapshot() -> Dictionary:
	var craftable: Array = []
	var missing: Array = []
	var recipes: Dictionary = catalog.get_recipes()
	var ingredients: Dictionary = catalog.get_ingredients()
	var devices: Dictionary = catalog.get_devices()
	var processes: Dictionary = catalog.get_processing_recipes()
	var stable_order := 0

	for recipe_id in _sorted_keys(recipes):
		if not state.is_recipe_unlocked(recipe_id):
			continue
		var recipe: Dictionary = recipes.get(recipe_id, {})
		var device_id := String(recipe.get("device", ""))
		if recipe.is_empty() or devices.get(device_id, {}).is_empty() or not state.is_device_unlocked(device_id):
			stable_order += 1
			continue
		var active_count := state.active_recipe_production_batch_count(recipe_id)
		if active_count >= GameState.MAX_CONCURRENT_RECIPE_BATCHES:
			stable_order += 1
			continue
		var entry := _production_picker_recipe_entry(
			recipe_id,
			recipe,
			recipes,
			ingredients,
			active_count,
			stable_order
		)
		(craftable if String(entry.get("filter", "")) == PICKER_FILTER_CRAFTABLE else missing).append(entry)
		stable_order += 1

	for process_id in _sorted_keys(processes):
		var process_entry := _production_picker_process_entry(
			process_id,
			processes.get(process_id, {}),
			recipes,
			ingredients,
			devices,
			stable_order
		)
		if not process_entry.is_empty():
			(craftable if String(process_entry.get("filter", "")) == PICKER_FILTER_CRAFTABLE else missing).append(process_entry)
		stable_order += 1

	_sort_production_picker_entries(craftable, missing)
	return {
		"craftable": craftable,
		"missing": missing,
		"craftable_count": craftable.size(),
		"missing_count": missing.size()
	}
```

Implement `_production_picker_recipe_entry`,
`_production_picker_process_entry`,
`_missing_recipe_material_ids_from_catalog`,
`_material_name_from_catalog`, and
`_material_stock_requirements_from_catalog` so they use the dictionaries
passed above and do not call `catalog.get_recipes()`,
`catalog.get_ingredients()`, or `catalog.get_devices()`.

Use these helper bodies:

```gdscript
func _missing_recipe_material_ids_from_catalog(
	recipe: Dictionary,
	ingredients: Dictionary,
	recipes: Dictionary
) -> Array[String]:
	var missing: Array[String] = []
	for material_value: Variant in recipe.get("materials", []):
		var material_id := String(material_value)
		if ingredients.has(material_id):
			if not state.has_ingredient(material_id):
				missing.append(material_id)
		elif recipes.has(material_id):
			if not state.has_product(material_id):
				missing.append(material_id)
		else:
			missing.append(material_id)
	return missing


func _material_name_from_catalog(
	material_id: String,
	ingredients: Dictionary,
	recipes: Dictionary
) -> String:
	if ingredients.has(material_id):
		return String((ingredients.get(material_id, {}) as Dictionary).get("name", material_id))
	return String((recipes.get(material_id, {}) as Dictionary).get("name", material_id))


func _material_stock_requirements_from_catalog(
	materials_value: Variant,
	ingredients: Dictionary,
	recipes: Dictionary
) -> String:
	if not materials_value is Array:
		return ""
	var required_by_id: Dictionary = {}
	var ordered_ids: Array[String] = []
	for material_value: Variant in materials_value:
		var material_id := String(material_value)
		if material_id.is_empty():
			continue
		if not required_by_id.has(material_id):
			required_by_id[material_id] = 0
			ordered_ids.append(material_id)
		required_by_id[material_id] = int(required_by_id[material_id]) + 1
	var parts: Array[String] = []
	for material_id in ordered_ids:
		var stock := (
			state.get_ingredient_count(material_id)
			if ingredients.has(material_id)
			else state.get_product_count(material_id)
		)
		parts.append("%s %d/%d" % [
			_material_name_from_catalog(material_id, ingredients, recipes),
			stock,
			int(required_by_id[material_id])
		])
	return ", ".join(parts)
```

Build recipe entries with:

```gdscript
func _production_picker_recipe_entry(
	recipe_id: String,
	recipe: Dictionary,
	recipes: Dictionary,
	ingredients: Dictionary,
	active_count: int,
	stable_order: int
) -> Dictionary:
	var missing_ids := _missing_recipe_material_ids_from_catalog(recipe, ingredients, recipes)
	var entry_filter := PICKER_FILTER_CRAFTABLE if missing_ids.is_empty() else PICKER_FILTER_MISSING
	var missing_names: Array[String] = []
	for material_id in missing_ids:
		missing_names.append(_material_name_from_catalog(material_id, ingredients, recipes))
	var restockable := false
	for material_id in missing_ids:
		var ingredient: Dictionary = ingredients.get(material_id, {})
		if not ingredient.is_empty() and _is_ingredient_available_for_purchase(material_id, ingredient):
			restockable = true
			break
	var search_parts: Array[String] = [recipe_id, String(recipe.get("name", recipe_id))]
	for material_value: Variant in recipe.get("materials", []):
		search_parts.append(_material_name_from_catalog(String(material_value), ingredients, recipes))
	for tag_value: Variant in recipe.get("tags", []):
		search_parts.append(String(tag_value))
	return {
		"id": recipe_id,
		"kind": "recipe",
		"filter": entry_filter,
		"name": String(recipe.get("name", recipe_id)),
		"icon": _material_icon_texture(recipe_id),
		"stock_count": state.get_product_count(recipe_id),
		"active_count": active_count,
		"remaining_capacity": GameState.MAX_CONCURRENT_RECIPE_BATCHES - active_count,
		"materials_text": "材料：%s" % _material_stock_requirements_from_catalog(
			recipe.get("materials", []),
			ingredients,
			recipes
		),
		"reason": "" if missing_names.is_empty() else "原料%s不足" % "、".join(missing_names),
		"missing_count": missing_ids.size(),
		"restockable": restockable,
		"action_enabled": true if entry_filter == PICKER_FILTER_CRAFTABLE else restockable,
		"can_list": state.has_product(recipe_id) and state.is_core_feature_unlocked(CoreFeatureUnlockService.LIST),
		"stable_order": stable_order,
		"search_haystack": " ".join(search_parts)
	}
```

Build process entries with the same cached dictionaries and the current
availability rules:

```gdscript
func _production_picker_process_entry(
	process_id: String,
	process: Dictionary,
	recipes: Dictionary,
	ingredients: Dictionary,
	devices: Dictionary,
	stable_order: int
) -> Dictionary:
	if process.is_empty() or int(process.get("unlock_level", 1)) > state.level:
		return {}
	var output_item_id := String(process.get("output_item_id", ""))
	if not state.has_method("is_ingredient_process_unlocked") or not state.is_ingredient_process_unlocked(output_item_id):
		return {}
	var missing_ids: Array[String] = []
	for material_value: Variant in process.get("materials", []):
		var material_id := String(material_value)
		if not ingredients.has(material_id) or not state.has_ingredient(material_id):
			missing_ids.append(material_id)
	var entry_filter := PICKER_FILTER_CRAFTABLE if missing_ids.is_empty() else PICKER_FILTER_MISSING
	var missing_names: Array[String] = []
	for material_id in missing_ids:
		missing_names.append(_material_name_from_catalog(material_id, ingredients, recipes))
	var device_id := String(process.get("device", ""))
	var reason := "" if missing_names.is_empty() else "原料%s不足" % "、".join(missing_names)
	if reason.is_empty() and (devices.get(device_id, {}).is_empty() or not state.is_device_unlocked(device_id)):
		var device: Dictionary = devices.get(device_id, {})
		reason = "工具%s未解锁" % String(device.get("name", device_id))
	var search_parts: Array[String] = [process_id, _material_name_from_catalog(output_item_id, ingredients, recipes)]
	for material_value: Variant in process.get("materials", []):
		search_parts.append(_material_name_from_catalog(String(material_value), ingredients, recipes))
	return {
		"id": process_id,
		"kind": "processing",
		"filter": entry_filter,
		"name": _material_name_from_catalog(output_item_id, ingredients, recipes),
		"icon": _material_icon_texture(output_item_id),
		"stock_count": state.get_ingredient_count(output_item_id),
		"materials_text": "材料：%s" % _material_stock_requirements_from_catalog(
			process.get("materials", []),
			ingredients,
			recipes
		),
		"reason": reason,
		"missing_count": missing_ids.size(),
		"restockable": false,
		"action_enabled": entry_filter == PICKER_FILTER_CRAFTABLE,
		"can_list": false,
		"stable_order": stable_order,
		"search_haystack": " ".join(search_parts)
	}
```

For the card's `restockable` flag, inspect the already-computed missing IDs:

```gdscript
var restockable := false
for material_id in missing_ids:
	var ingredient: Dictionary = ingredients.get(material_id, {})
	if not ingredient.is_empty() and _is_ingredient_available_for_purchase(material_id, ingredient):
		restockable = true
		break
```

The actual restock button handler must continue calling
`_recipe_restock_quote(recipe_id)` for authoritative pricing and validation.

Sort both arrays once:

```gdscript
func _sort_production_picker_entries(craftable: Array, missing: Array) -> void:
	craftable.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var capacity_a := int(a.get("remaining_capacity", 4 if String(a.get("kind", "")) == "processing" else 0))
		var capacity_b := int(b.get("remaining_capacity", 4 if String(b.get("kind", "")) == "processing" else 0))
		if capacity_a != capacity_b:
			return capacity_a > capacity_b
		return int(a.get("stable_order", 0)) < int(b.get("stable_order", 0))
	)
	missing.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if bool(a.get("restockable", false)) != bool(b.get("restockable", false)):
			return bool(a.get("restockable", false))
		if int(a.get("missing_count", 0)) != int(b.get("missing_count", 0)):
			return int(a.get("missing_count", 0)) < int(b.get("missing_count", 0))
		return int(a.get("stable_order", 0)) < int(b.get("stable_order", 0))
	)
```

- [ ] **Step 4: Preserve the old filtered entry API**

Replace `_production_picker_entries()` with:

```gdscript
func _production_picker_entries(filter_id: String) -> Array:
	var snapshot := _build_production_picker_snapshot()
	return (
		snapshot.get("missing", [])
		if filter_id == PICKER_FILTER_MISSING
		else snapshot.get("craftable", [])
	)
```

- [ ] **Step 5: Make event refresh build exactly one snapshot**

Change `_refresh_production_workbench()` to:

```gdscript
func _refresh_production_workbench() -> void:
	if state == null:
		return
	var queue_entries := _production_queue_entries(int(Time.get_unix_time_from_system()))
	var active_batches := _production_active_batch_count(queue_entries)
	production_picker_snapshot = _build_production_picker_snapshot()
	production_workbench.refresh_queue(
		queue_entries,
		active_batches,
		bool(state.automation_paused)
	)
	production_workbench.refresh_entry_counts(
		int(production_picker_snapshot.get("craftable_count", 0)),
		int(production_picker_snapshot.get("missing_count", 0))
	)
	if global_popup_mode == MODE_PRODUCTION_PICKER:
		_refresh_production_picker(production_picker_snapshot)
```

Add:

```gdscript
func _production_active_batch_count(entries: Array) -> int:
	var count := 0
	for entry_value: Variant in entries:
		if entry_value is Dictionary:
			count += ((entry_value as Dictionary).get("batch_progress", []) as Array).size()
	return count
```

- [ ] **Step 6: Reuse the snapshot when opening and switching tabs**

Change `_show_production_picker()` to build once and pass the snapshot:

```gdscript
func _show_production_picker(filter: int) -> void:
	_open_global_popup_mode(MODE_PRODUCTION_PICKER)
	production_recipe_picker_overlay.open_with_filter(filter)
	production_picker_snapshot = _build_production_picker_snapshot()
	production_workbench.refresh_entry_counts(
		int(production_picker_snapshot.get("craftable_count", 0)),
		int(production_picker_snapshot.get("missing_count", 0))
	)
	_refresh_production_picker(production_picker_snapshot)
```

Change filter handling and picker refresh to:

```gdscript
func _on_production_picker_filter_changed(_filter: int) -> void:
	if global_popup_mode == MODE_PRODUCTION_PICKER:
		_refresh_production_picker(production_picker_snapshot)


func _refresh_production_picker(snapshot_value: Dictionary = {}) -> void:
	if state == null:
		return
	var snapshot := snapshot_value
	if snapshot.is_empty():
		snapshot = _build_production_picker_snapshot()
		production_picker_snapshot = snapshot
	var filter_id := (
		PICKER_FILTER_MISSING
		if production_recipe_picker_overlay.current_filter() == ProductionRecipePickerOverlayComponent.Filter.MISSING
		else PICKER_FILTER_CRAFTABLE
	)
	production_recipe_picker_overlay.refresh(snapshot.get(filter_id, []), {
		"make_all": state.is_feature_unlocked(RESEARCH_MAKE_ALL_FEATURE_ID),
		"bulk_restock": state.is_feature_unlocked(RESEARCH_BULK_RESTOCK_FEATURE_ID),
		"list_all": state.is_feature_unlocked(RESEARCH_LIST_ALL_FEATURE_ID)
	}, {
		"craftable": int(snapshot.get("craftable_count", 0)),
		"missing": int(snapshot.get("missing_count", 0))
	})
```

- [ ] **Step 7: Run snapshot tests**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-new-production-ui.log" -s res://tests/recipe_production_ui_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-new-picker.log" -s res://tests/production_recipe_picker_self_check.gd
```

Expected markers:

- `RECIPE_PRODUCTION_UI_SELF_CHECK_PASS`
- `PRODUCTION_RECIPE_PICKER_SELF_CHECK_PASS`

- [ ] **Step 8: Commit the snapshot implementation**

```powershell
git add -- scripts/main_view.gd scripts/game_state.gd tests/recipe_production_ui_self_check.gd
git commit -m "perf: build production picker data once"
```

---

### Task 3: Add the Lightweight Queue Tick and Reuse Row Styles

**Files:**
- Modify: `scripts/main_view.gd:552-578`
- Modify: `scripts/main_view.gd:2794-2807`
- Modify: `scripts/ui/pages/production_workbench.gd:27-65`
- Modify: `scripts/ui/pages/production_queue_recipe_row.gd:14-125`
- Test: `tests/production_queue_performance_self_check.gd`
- Test: `tests/production_queue_scene_self_check.gd`

**Interfaces:**
- Consumes: `_production_queue_entries(now_unix)` and `_production_active_batch_count(entries)`.
- Produces: `_refresh_production_queue_tick(now_unix: int) -> void`.
- Produces: `ProductionWorkbench.refresh_queue_runtime(entries, active_batch_count, automation_paused) -> void`.
- Produces: `ProductionQueueRecipeRow.refresh_runtime(entry: Dictionary) -> void`.

- [ ] **Step 1: Route the one-second process to a lightweight function**

In `_process()`, replace `_refresh_production_workbench()` with:

```gdscript
_refresh_production_queue_tick(now_unix)
```

Add beside `_refresh_production_workbench()`:

```gdscript
func _refresh_production_queue_tick(now_unix: int) -> void:
	if state == null:
		return
	var queue_entries := _production_queue_entries(now_unix)
	production_workbench.refresh_queue_runtime(
		queue_entries,
		_production_active_batch_count(queue_entries),
		bool(state.automation_paused)
	)
```

- [ ] **Step 2: Add runtime-only workbench refresh**

In `production_workbench.gd`, add:

```gdscript
func refresh_queue_runtime(entries: Array, active_batch_count: int, automation_paused: bool) -> void:
	var rows_by_recipe := _queue_rows_by_recipe()
	var entry_ids: Dictionary = {}
	for entry_value: Variant in entries:
		if not entry_value is Dictionary:
			continue
		var entry: Dictionary = entry_value
		var recipe_id := String(entry.get("recipe_id", ""))
		if recipe_id.is_empty():
			continue
		entry_ids[recipe_id] = true
		var row := rows_by_recipe.get(recipe_id) as Control
		if row == null:
			refresh_queue(entries, active_batch_count, automation_paused)
			return
		row.call("refresh_runtime", entry)
	for recipe_id_value: Variant in rows_by_recipe.keys():
		if not entry_ids.has(String(recipe_id_value)):
			refresh_queue(entries, active_batch_count, automation_paused)
			return
	_apply_queue_summary(entries.size(), active_batch_count, automation_paused)
```

Extract the repeated child scan and summary update:

```gdscript
func _queue_rows_by_recipe() -> Dictionary:
	var result: Dictionary = {}
	for child_value: Variant in active_queue_rows.get_children():
		if child_value is Control:
			var child := child_value as Control
			var recipe_id := String(child.get_meta("recipe_id", ""))
			if not recipe_id.is_empty():
				result[recipe_id] = child
	return result


func _apply_queue_summary(entry_count: int, active_batch_count: int, automation_paused: bool) -> void:
	empty_queue_panel.visible = entry_count == 0
	queue_summary_label.text = "进行中 %d 种 · %d 批" % [entry_count, active_batch_count]
	automation_paused_label.visible = automation_paused
```

Use these helpers from the existing full `refresh_queue()` as well.

- [ ] **Step 3: Add runtime-only row refresh**

In `production_queue_recipe_row.gd`, add:

```gdscript
func refresh_runtime(entry: Dictionary) -> void:
	refresh_batches(
		entry.get("batch_progress", []),
		entry.get("completion_feedback", [])
	)
```

Do not update icon, name, device, completed-stock drag dictionaries, or drag
preview data from this method.

- [ ] **Step 4: Reuse unchanged slot styles**

Change `_apply_slot_style()` to:

```gdscript
func _apply_slot_style(slot: PanelContainer, completed: bool, empty: bool = false) -> void:
	var visual_state := "completed" if completed else ("empty" if empty else "active")
	if String(slot.get_meta("visual_state", "")) == visual_state:
		return
	slot.set_meta("visual_state", visual_state)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.82, 0.93, 0.84, 0.96) if completed else (Color(0.94, 0.91, 0.86, 0.7) if empty else Color(1.0, 0.97, 0.91, 0.98))
	style.border_color = Color(0.32, 0.68, 0.42, 1.0) if completed else (Color(0.62, 0.55, 0.49, 0.65) if empty else Color(0.78, 0.57, 0.42, 0.9))
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	slot.add_theme_stylebox_override("panel", style)
```

- [ ] **Step 5: Run queue-focused tests**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-new-production-perf.log" -s res://tests/production_queue_performance_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-new-production-scene.log" -s res://tests/production_queue_scene_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-new-production-interaction.log" -s res://tests/production_queue_interaction_self_check.gd
```

Expected markers:

- `PRODUCTION_QUEUE_PERFORMANCE_SELF_CHECK_PASS`
- `PRODUCTION_QUEUE_SCENE_SELF_CHECK_PASS`
- `PRODUCTION_QUEUE_INTERACTION_SELF_CHECK_PASS`

- [ ] **Step 6: Commit the lightweight queue tick**

```powershell
git add -- scripts/main_view.gd scripts/ui/pages/production_workbench.gd scripts/ui/pages/production_queue_recipe_row.gd tests/production_queue_performance_self_check.gd tests/production_queue_scene_self_check.gd
git commit -m "perf: keep production countdown refresh lightweight"
```

---

### Task 4: Run Regression and Runtime Performance Acceptance

**Files:**
- Modify only if a regression test exposes a production-queue defect in files already listed above.
- Do not modify unrelated storefront fixtures or untracked icon resources.

**Interfaces:**
- Consumes: completed snapshot and lightweight tick implementations.
- Produces: verified focused suite and before/after runtime measurements.

- [ ] **Step 1: Run the focused regression suite**

Run each command from `D:\Project\ProjectRest\project-rest-new`:

```powershell
$tests = @(
	'production_queue_performance_self_check.gd',
	'production_queue_scene_self_check.gd',
	'production_recipe_picker_self_check.gd',
	'production_queue_interaction_self_check.gd',
	'recipe_production_ui_self_check.gd',
	'recipe_production_timing_self_check.gd',
	'automation_settlement_self_check.gd',
	'mvp_self_check.gd'
)
foreach ($test in $tests) {
	& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
		--headless `
		--path . `
		--log-file "$env:TEMP\project-rest-new-$test.log" `
		-s "res://tests/$test"
	if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
```

Expected: every script exits `0` and prints its corresponding `*_PASS` marker.

- [ ] **Step 2: Run a headless import/parse check**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-new-import.log" --quit
```

Expected: exit code `0`, with no new GDScript parse error.

- [ ] **Step 3: Measure the same runtime paths used during diagnosis**

Start the game through the connected Godot editor and evaluate:

```gdscript
var main = get_tree().current_scene
var result = {}
var t0 = Time.get_ticks_usec()
for i in range(20):
	main._refresh_production_queue_tick(int(Time.get_unix_time_from_system()))
var t1 = Time.get_ticks_usec()
for i in range(10):
	var ignored_snapshot = main._build_production_picker_snapshot()
var t2 = Time.get_ticks_usec()
var previous_mode = main.global_popup_mode
main.global_popup_mode = main.MODE_PRODUCTION_PICKER
var t3 = Time.get_ticks_usec()
main._refresh_current_page()
var t4 = Time.get_ticks_usec()
main.global_popup_mode = previous_mode
result["queue_tick_avg_usec"] = float(t1 - t0) / 20.0
result["snapshot_avg_usec"] = float(t2 - t1) / 10.0
result["picker_open_full_refresh_usec"] = t4 - t3
return result
```

Acceptance on the current development machine:

- `queue_tick_avg_usec < 5000`;
- `snapshot_avg_usec < 100000`;
- `picker_open_full_refresh_usec < 200000`;
- `_process()` does not rebuild the picker snapshot each second.

- [ ] **Step 4: Inspect the final diff and working tree**

Run:

```powershell
git diff --check
git status --short
git diff --stat 21731888..HEAD
```

Confirm:

- only planned code, tests, spec, and plan files are part of the fix;
- all `resources/ui/icons_v1` untracked files remain unmodified and uncommitted;
- no save files or temp logs are tracked.

- [ ] **Step 5: Commit any regression-only correction**

Only if Step 1 or Step 2 required a correction:

```powershell
git add -- scripts/main_view.gd scripts/game_state.gd scripts/ui/pages/production_workbench.gd scripts/ui/pages/production_queue_recipe_row.gd tests/production_queue_performance_self_check.gd tests/recipe_production_ui_self_check.gd tests/production_queue_scene_self_check.gd
git commit -m "fix: preserve production queue behavior after optimization"
```

If no correction was needed, do not create an empty commit.
