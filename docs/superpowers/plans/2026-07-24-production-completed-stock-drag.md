# Persistent Completed Production Rows Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep a completed recipe visible in the production queue while finished stock remains, and let the player drag one finished product directly from that row to the showcase.

**Architecture:** Keep `recipe_production_queue` limited to active work and add a persisted, recipe-keyed `production_ready_recipe_records` ledger for row identity and stable ordering. `main_view.gd` merges active queue summaries with that ledger, while `ProductionQueueRecipeRow` exposes a stable drag source that emits the existing `inventory_product` payload, so all placement, variant, phase, and inventory rules remain owned by the current showcase path.

**Tech Stack:** Godot 4.6.1, GDScript, `.tscn` scene-first UI, existing `output_cell.gd` drag protocol, headless SceneTree self-checks.

## Global Constraints

- One recipe may still have at most three active batches; completed stock never consumes a batch slot.
- Production completion still grants inventory, growth, and task progress exactly once and removes the active task.
- Each successful queue-row drag lists exactly one product through the existing showcase flow.
- A row disappears only when finished inventory is zero and active batch count is zero.
- Manual and automation completion use the same ledger registration path.
- Stable UI nodes stay in `.tscn`; scripts bind state, drag payloads, and signals.
- Do not modify recipe assets, `scripts/catalog.gd`, or unrelated dirty documentation.
- Run every Godot headless command with a writable `--log-file`.

---

### Task 1: Persist Completed Recipe Row Identity in GameState

**Files:**
- Modify: `scripts/game_state.gd:105`
- Modify: `scripts/game_state.gd:194`
- Modify: `scripts/game_state.gd:239-330`
- Modify: `scripts/game_state.gd:384-389`
- Modify: `scripts/game_state.gd:1650-1676`
- Modify: `scripts/game_state.gd:2031-2088`
- Modify: `scripts/game_state.gd` beside the existing production queue sanitizers
- Test: `tests/recipe_production_timing_self_check.gd`
- Test: `tests/automation_settlement_self_check.gd`

**Interfaces:**
- Produces: `production_ready_recipe_records: Dictionary`
- Produces: `mark_recipe_production_ready(recipe_id: String, display_sequence: int, completed_at_unix: int) -> void`
- Produces: `prune_recipe_production_ready_record(recipe_id: String) -> void`
- Produces: `production_ready_recipe_record(recipe_id: String) -> Dictionary`
- Consumes: existing `active_recipe_production_batch_count(recipe_id: String) -> int`
- Consumes: existing `complete_recipe_production(index: int, now_unix: int = -1) -> bool`

- [ ] **Step 1: Add failing manual-completion, cleanup, and roundtrip assertions**

Append focused assertions to the manual production cases in `tests/recipe_production_timing_self_check.gd`:

```gdscript
var completed_sequence := int(state.recipe_production_queue[0].get("queue_sequence", 0))
_expect(state.complete_recipe_production(0, ready_at), "ready manual production should complete")
_expect(state.recipe_production_queue.is_empty(), "completed work should leave the active queue")
var ready_record: Dictionary = state.production_ready_recipe_record("rice_milk_drink")
_expect(not ready_record.is_empty(), "completed recipe should create a persistent row record")
_expect(int(ready_record.get("display_sequence", 0)) == completed_sequence, "row record should preserve queue ordering")
_expect(state.get_product_count("rice_milk_drink") == 3, "completion should still grant its output exactly once")

var restored = GameState.from_dict(state.to_dict())
_expect(not restored.production_ready_recipe_record("rice_milk_drink").is_empty(), "completed row record should survive save roundtrip")

restored.remove_product("rice_milk_drink", restored.get_product_count("rice_milk_drink"))
_expect(restored.production_ready_recipe_record("rice_milk_drink").is_empty(), "zero stock without active work should prune the row record")
```

Add the active-batch protection case:

```gdscript
var retained = GameState.from_dict(state.to_dict())
retained.add_ingredient("rice", 1)
retained.add_ingredient("spring_water", 1)
_expect(retained.queue_recipe_production("rice_milk_drink", 1, ready_at + 1, "manual"), "fixture should start a later active batch")
retained.remove_product("rice_milk_drink", retained.get_product_count("rice_milk_drink"))
_expect(not retained.production_ready_recipe_record("rice_milk_drink").is_empty(), "active work should keep the row after finished stock reaches zero")
```

In `tests/automation_settlement_self_check.gd`, after the existing automated kitchen completion assertion, add:

```gdscript
var automated_ready_record: Dictionary = state.production_ready_recipe_record(recipe_id)
_expect(not automated_ready_record.is_empty(), "automated completion should register the same persistent row identity")
```

- [ ] **Step 2: Run the focused tests and verify the new API is missing**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\recipe-ready-ledger-red.log" -s res://tests/recipe_production_timing_self_check.gd
```

Expected: FAIL because `production_ready_recipe_record` and `production_ready_recipe_records` do not exist.

- [ ] **Step 3: Add the ledger, completion registration, persistence, and cleanup**

Add the state field beside `recipe_production_queue`:

```gdscript
var recipe_production_queue: Array = []
var production_ready_recipe_records: Dictionary = {}
```

Initialize it in `new_game()`:

```gdscript
state.recipe_production_queue = []
state.production_ready_recipe_records = {}
```

Add these public methods beside the recipe production methods:

```gdscript
func mark_recipe_production_ready(recipe_id: String, display_sequence: int, completed_at_unix: int) -> void:
	if recipe_id.is_empty() or not _recipes().has(recipe_id):
		return
	var record: Dictionary = production_ready_recipe_records.get(recipe_id, {})
	if record.is_empty():
		record["display_sequence"] = maxi(1, display_sequence)
	record["last_completed_at_unix"] = maxi(0, completed_at_unix)
	production_ready_recipe_records[recipe_id] = record


func prune_recipe_production_ready_record(recipe_id: String) -> void:
	if recipe_id.is_empty() or not production_ready_recipe_records.has(recipe_id):
		return
	if get_product_count(recipe_id) > 0 or active_recipe_production_batch_count(recipe_id) > 0:
		return
	production_ready_recipe_records.erase(recipe_id)


func production_ready_recipe_record(recipe_id: String) -> Dictionary:
	var record: Variant = production_ready_recipe_records.get(recipe_id, {})
	return (record as Dictionary).duplicate(true) if record is Dictionary else {}
```

Change `remove_product` so every inventory-consumption path shares cleanup:

```gdscript
func remove_product(recipe_id: String, amount: int) -> bool:
	if not _remove_inventory(product_inventory, recipe_id, amount):
		return false
	prune_recipe_production_ready_record(recipe_id)
	return true
```

In `complete_recipe_production`, capture sequence and register only after inventory is granted:

```gdscript
var completed_sequence := maxi(1, int(slot.get("queue_sequence", index + 1)))
if not add_product(recipe_id, output_count):
	return false
mark_recipe_production_ready(recipe_id, completed_sequence, current_time)
```

Add the sanitizer beside `_sanitize_recipe_production_queue`:

```gdscript
func _sanitize_production_ready_recipe_records(raw_value: Variant) -> Dictionary:
	var sanitized: Dictionary = {}
	if not raw_value is Dictionary:
		return sanitized
	for recipe_id_value: Variant in (raw_value as Dictionary).keys():
		var recipe_id := String(recipe_id_value)
		var record_value: Variant = (raw_value as Dictionary).get(recipe_id_value, {})
		if recipe_id.is_empty() or not _recipes().has(recipe_id) or not record_value is Dictionary:
			continue
		var record: Dictionary = record_value
		var display_sequence := int(record.get("display_sequence", 0))
		if display_sequence <= 0:
			continue
		sanitized[recipe_id] = {
			"display_sequence": display_sequence,
			"last_completed_at_unix": maxi(0, int(record.get("last_completed_at_unix", 0)))
		}
	return sanitized
```

Load the field after `recipe_production_queue`, then prune stale records after both inventory and queue are available:

```gdscript
state.production_ready_recipe_records = state._sanitize_production_ready_recipe_records(
	data.get("production_ready_recipe_records", {})
)
for recipe_id_value: Variant in state.production_ready_recipe_records.keys():
	state.prune_recipe_production_ready_record(String(recipe_id_value))
```

Persist it in `to_dict()`:

```gdscript
"recipe_production_queue": recipe_production_queue.duplicate(true),
"production_ready_recipe_records": production_ready_recipe_records.duplicate(true),
```

- [ ] **Step 4: Run domain and automation tests**

Run:

```powershell
$tests = @('recipe_production_timing_self_check.gd','automation_settlement_self_check.gd')
foreach ($test in $tests) {
  & "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\$test.log" -s "res://tests/$test"
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
```

Expected: both exit `0`; timing prints `RECIPE_PRODUCTION_TIMING_SELF_CHECK_PASS`, automation prints its existing pass marker.

- [ ] **Step 5: Commit the domain contract**

```powershell
git add scripts/game_state.gd tests/recipe_production_timing_self_check.gd tests/automation_settlement_self_check.gd
git commit -m "feat: persist completed production row identity"
```

---

### Task 2: Merge Completed Stock into the Queue and Add the Drag Surface

**Files:**
- Modify: `scenes/ui/pages/production_queue_recipe_row.tscn`
- Modify: `scripts/ui/pages/production_queue_recipe_row.gd`
- Modify: `scripts/main_view.gd:4533-4567`
- Test: `tests/production_queue_scene_self_check.gd`
- Test: `tests/recipe_production_ui_self_check.gd`

**Interfaces:**
- Consumes: `GameState.production_ready_recipe_records`
- Consumes: `GameState.production_ready_recipe_record(recipe_id: String) -> Dictionary`
- Produces queue entry fields: `completed_stock_count`, `completed_stock_drag_enabled`, `completed_stock_tooltip`, `drag_data`, `drag_preview_text`, `drag_preview_data`, `drag_end_callable`
- Produces stable scene node: `Content/RecipeSummary/CompletedStockDragArea`
- Reuses: `scripts/output_cell.gd.configure_drag(data, preview_text, preview_data, end_callable, start_callable)`

- [ ] **Step 1: Add failing scene and merged-row tests**

In `tests/production_queue_scene_self_check.gd`, require the stable drag source:

```gdscript
var completed_drag := row.get_node_or_null("Content/RecipeSummary/CompletedStockDragArea") as Button
_expect(completed_drag != null, "queue row should declare a stable completed-stock drag area")
_expect(completed_drag != null and completed_drag.has_method("configure_drag"), "completed-stock area should reuse the shared drag protocol")
```

In `tests/recipe_production_ui_self_check.gd`, complete a batch, refresh entries, and assert the row persists:

```gdscript
var completed_sequence := int(state.recipe_production_queue[0].get("queue_sequence", 0))
_expect(state.complete_recipe_production(0, ready_at), "fixture production should complete")
var completed_entries: Array = view.call("_production_queue_entries", ready_at)
var completed_entry := _entry_for_recipe(completed_entries, "rice_milk_drink")
_expect(not completed_entry.is_empty(), "stock-only completed recipe should remain in the production queue")
_expect(int(completed_entry.get("completed_stock_count", 0)) == state.get_product_count("rice_milk_drink"), "queue entry should use finished inventory as its stock source")
_expect((completed_entry.get("batch_progress", []) as Array).is_empty(), "completed stock should not count as an active batch")
_expect(int(completed_entry.get("first_queue_sequence", 0)) == completed_sequence, "completed row should preserve stable production ordering")
```

Add coexistence and capacity assertions:

```gdscript
state.add_ingredient("rice", 3)
state.add_ingredient("spring_water", 3)
for batch_index in range(3):
	_expect(state.queue_recipe_production("rice_milk_drink", 1, ready_at + batch_index + 1, "manual"), "fixture should fill active slot %d" % (batch_index + 1))
var mixed_entry := _entry_for_recipe(view.call("_production_queue_entries", ready_at + 1), "rice_milk_drink")
_expect((mixed_entry.get("batch_progress", []) as Array).size() == 3, "completed inventory should coexist with three active slots")
_expect(int(mixed_entry.get("completed_stock_count", 0)) > 0, "mixed row should retain its draggable completed stock")
```

- [ ] **Step 2: Run the scene test and verify the drag node is missing**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\production-completed-row-red.log" -s res://tests/production_queue_scene_self_check.gd
```

Expected: FAIL with `queue row should declare a stable completed-stock drag area`.

- [ ] **Step 3: Declare and bind `CompletedStockDragArea`**

Increase the scene load steps and add the shared drag script:

```ini
[ext_resource type="Script" path="res://scripts/output_cell.gd" id="2_drag"]
```

Under `Content/RecipeSummary`, after `BatchCountLabel`, declare:

```ini
[node name="CompletedStockDragArea" type="Button" parent="Content/RecipeSummary"]
visible = false
custom_minimum_size = Vector2(150, 52)
layout_mode = 2
mouse_default_cursor_shape = 6
theme_type_variation = &"DessertContentButton"
text = "制作完成 · 库存 ×0\n拖拽上架"
script = ExtResource("2_drag")
```

Bind and configure it in `production_queue_recipe_row.gd`:

```gdscript
@onready var completed_stock_drag_area: Button = $Content/RecipeSummary/CompletedStockDragArea
```

Extend `configure(entry)`:

```gdscript
var completed_stock_count := maxi(0, int(entry.get("completed_stock_count", 0)))
completed_stock_drag_area.visible = completed_stock_count > 0
completed_stock_drag_area.set_meta("completed_stock_count", completed_stock_count)
if completed_stock_count > 0:
	completed_stock_drag_area.text = "制作完成 · 库存 ×%d\n拖拽上架" % completed_stock_count
	var drag_enabled := bool(entry.get("completed_stock_drag_enabled", false))
	completed_stock_drag_area.disabled = not drag_enabled
	completed_stock_drag_area.tooltip_text = String(entry.get("completed_stock_tooltip", ""))
	completed_stock_drag_area.modulate = Color(0.82, 1.0, 0.84, 1.0)
	if drag_enabled:
		completed_stock_drag_area.call(
			"configure_drag",
			entry.get("drag_data", {}),
			String(entry.get("drag_preview_text", "")),
			entry.get("drag_preview_data", {}),
			entry.get("drag_end_callable", Callable()),
			Callable()
		)
	else:
		completed_stock_drag_area.call("clear_drag")
else:
	completed_stock_drag_area.call("clear_drag")
```

Also bind the node in `_bind_nodes()` so tests can configure rows before `_ready`:

```gdscript
completed_stock_drag_area = get_node("Content/RecipeSummary/CompletedStockDragArea") as Button
```

- [ ] **Step 4: Merge ready records and construct the existing inventory drag payload**

In `_production_queue_entries`, add ready-record recipe IDs:

```gdscript
for recipe_id_value: Variant in state.production_ready_recipe_records.keys():
	var ready_recipe_id := String(recipe_id_value)
	if state.get_product_count(ready_recipe_id) > 0:
		recipe_ids[ready_recipe_id] = true
```

For each row, read the ledger and build drag details:

```gdscript
var ready_record: Dictionary = state.production_ready_recipe_record(recipe_id)
var completed_stock_count := state.get_product_count(recipe_id) if not ready_record.is_empty() else 0
var drag_details := _production_queue_completed_stock_drag_details(recipe_id) if completed_stock_count > 0 else {}
var active_sequence := int((batch_progress[0] as Dictionary).get("queue_sequence", 0)) if not batch_progress.is_empty() else 0
var ready_sequence := int(ready_record.get("display_sequence", 0))
var first_sequence := active_sequence if ready_sequence <= 0 else (ready_sequence if active_sequence <= 0 else mini(active_sequence, ready_sequence))
```

Add these fields to the queue entry:

```gdscript
"completed_stock_count": completed_stock_count,
"completed_stock_drag_enabled": bool(drag_details.get("enabled", false)),
"completed_stock_tooltip": String(drag_details.get("tooltip", "")),
"drag_data": drag_details.get("drag_data", {}),
"drag_preview_text": String(drag_details.get("preview_text", "")),
"drag_preview_data": drag_details.get("preview_data", {}),
"drag_end_callable": drag_details.get("end_callable", Callable())
```

Add the helper beside `_production_queue_entries`:

```gdscript
func _production_queue_completed_stock_drag_details(recipe_id: String) -> Dictionary:
	var variant_id := _selected_showcase_variant(recipe_id)
	var shape_info := _showcase_drag_shape_info(recipe_id, variant_id)
	var can_drag := state.is_core_feature_unlocked(CoreFeatureUnlockService.LIST) and state.has_product(recipe_id)
	var tooltip := "拖到橱窗上架；每次上架 1 件。"
	if not can_drag:
		tooltip = state.core_feature_locked_reason(CoreFeatureUnlockService.LIST)
	return {
		"enabled": can_drag,
		"tooltip": tooltip,
		"drag_data": {
			"kind": "inventory_product",
			"recipe_id": recipe_id,
			"variant_id": variant_id,
			"manual_list_source": "drag",
			"default_shape": String(shape_info.get("default_shape", "1x1")),
			"shape_rows": int(shape_info.get("shape_rows", 1)),
			"shape_cols": int(shape_info.get("shape_cols", 1)),
			"cell_count": int(shape_info.get("cell_count", 1)),
			"shape_cells": shape_info.get("shape_cells", [])
		},
		"preview_text": "%s\n%s\n%s / %d格" % [
			_recipe_name(recipe_id),
			_showcase_variant_label(variant_id),
			String(shape_info.get("default_shape", "1x1")),
			int(shape_info.get("cell_count", 1))
		],
		"preview_data": shape_info,
		"end_callable": Callable(self, "_on_production_queue_completed_stock_drag_ended")
	}


func _on_production_queue_completed_stock_drag_ended() -> void:
	_clear_showcase_drag_preview()
```

- [ ] **Step 5: Run queue scene and UI tests**

Run:

```powershell
$tests = @('production_queue_scene_self_check.gd','recipe_production_ui_self_check.gd')
foreach ($test in $tests) {
  & "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\$test.log" -s "res://tests/$test"
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
```

Expected: both exit `0` and print their existing pass markers.

- [ ] **Step 6: Commit the merged row and drag surface**

```powershell
git add scenes/ui/pages/production_queue_recipe_row.tscn scripts/ui/pages/production_queue_recipe_row.gd scripts/main_view.gd tests/production_queue_scene_self_check.gd tests/recipe_production_ui_self_check.gd
git commit -m "feat: keep completed stock in production rows"
```

---

### Task 3: Refresh Queue State after Real Showcase Drag-and-Drop

**Files:**
- Modify: `scripts/main_view.gd:7612-7710`
- Modify: `scripts/main_view.gd` at `_record_manual_list_success`
- Modify: `tests/production_queue_interaction_self_check.gd`
- Test: `tests/showcase_initial_multicell_interaction_self_check.gd`

**Interfaces:**
- Consumes: existing `inventory_product` drop protocol
- Consumes: `GameState.remove_product`, which prunes the ready record after the final item
- Produces: immediate/deferred production workbench refresh after every successful manual listing
- Preserves: failed drops do not mutate inventory or ready records

- [ ] **Step 1: Add a real mouse drag case to the production interaction test**

After the existing picker interaction in `tests/production_queue_interaction_self_check.gd`, create a completed row:

```gdscript
view.call("_close_global_popup")
state.recipe_production_queue.clear()
state.ingredient_inventory = {"rice": 2, "spring_water": 2}
_expect(state.queue_recipe_production("rice_milk_drink", 1, 100, "manual"), "fixture should start a completed-stock batch")
_expect(state.complete_recipe_production(0, 2147483647), "fixture should complete the batch")
view.call("_refresh_production_workbench")
await process_frame
await process_frame

var completed_row := _queue_row_for_recipe(view, "rice_milk_drink")
_expect(completed_row != null, "completed recipe row should remain visible")
var completed_drag := completed_row.get_node("Content/RecipeSummary/CompletedStockDragArea") as Button
var stock_before := state.get_product_count("rice_milk_drink")
var target := _first_valid_showcase_target(view, completed_drag.get("drag_data"))
_expect(target != null, "fixture should find an unlocked showcase drop target")
if target != null:
	await _drag_mouse(completed_drag.get_global_rect().get_center(), target.get_global_rect().get_center())
_expect(state.get_product_count("rice_milk_drink") == stock_before - 1, "real queue drag should list exactly one product")
var refreshed_row := _queue_row_for_recipe(view, "rice_milk_drink")
_expect(refreshed_row != null, "row should remain while completed stock is still positive")
if refreshed_row != null:
	var refreshed_drag := refreshed_row.get_node("Content/RecipeSummary/CompletedStockDragArea") as Button
	_expect(int(refreshed_drag.get_meta("completed_stock_count", -1)) == stock_before - 1, "successful drag should refresh the visible completed-stock count")
```

Add helpers:

```gdscript
func _queue_row_for_recipe(view: Control, recipe_id: String) -> Control:
	var rows := view.get_node("Root/Body/MainArea/WorkbenchPanel/ProductionWorkbench/ActiveQueueScroll/ActiveQueueRows")
	for child_value: Variant in rows.get_children():
		if child_value is Control and String((child_value as Control).get_meta("recipe_id", "")) == recipe_id:
			return child_value as Control
	return null


func _first_valid_showcase_target(view: Control, drag_data_value: Variant) -> Button:
	if not drag_data_value is Dictionary:
		return null
	var grid := view.get_node("Root/Body/MainArea/StorefrontPanel/ShowcasePanel/ShowcaseGrid") as GridContainer
	for slot_index in range(grid.get_child_count()):
		var candidate_data: Dictionary = (drag_data_value as Dictionary).duplicate(true)
		candidate_data["target_slot_index"] = slot_index
		if bool(view.call("_can_drop_showcase_data", "showcase", candidate_data)):
			return grid.get_child(slot_index) as Button
	return null


func _drag_mouse(from: Vector2, to: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = from
	press.global_position = from
	Input.parse_input_event(press)
	await process_frame

	var start_motion := InputEventMouseMotion.new()
	start_motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	start_motion.position = from + Vector2(24, 0)
	start_motion.global_position = start_motion.position
	start_motion.relative = Vector2(24, 0)
	Input.parse_input_event(start_motion)
	await process_frame

	var drag_motion := InputEventMouseMotion.new()
	drag_motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	drag_motion.position = to
	drag_motion.global_position = to
	drag_motion.relative = to - start_motion.position
	Input.parse_input_event(drag_motion)
	await process_frame

	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = to
	release.global_position = to
	Input.parse_input_event(release)
	await process_frame
	await process_frame
```

Add failed-drop and final-stock assertions using a fresh one-item row. Re-fetch the row after every refresh so the test never holds a stale scene reference:

```gdscript
state.product_inventory["rice_milk_drink"] = 1
state.mark_recipe_production_ready("rice_milk_drink", 99, 100)
view.call("_refresh_production_workbench")
await process_frame
await process_frame
var one_item_row := _queue_row_for_recipe(view, "rice_milk_drink")
_expect(one_item_row != null, "one-item fixture should expose the completed row")
var one_item_drag := one_item_row.get_node("Content/RecipeSummary/CompletedStockDragArea") as Button
var invalid_data: Dictionary = (one_item_drag.get("drag_data") as Dictionary).duplicate(true)
invalid_data["target_slot_index"] = -1
_expect(not bool(view.call("_drop_showcase_data", "showcase", invalid_data)), "invalid target should reject completed stock")
_expect(state.get_product_count("rice_milk_drink") == 1, "failed drop should preserve completed stock")
_expect(not state.production_ready_recipe_record("rice_milk_drink").is_empty(), "failed drop should preserve the row record")

var final_target := _first_valid_showcase_target(view, one_item_drag.get("drag_data"))
_expect(final_target != null, "fixture should find a target for the final completed item")
if final_target != null:
	await _drag_mouse(one_item_drag.get_global_rect().get_center(), final_target.get_global_rect().get_center())
_expect(state.get_product_count("rice_milk_drink") == 0, "final successful drag should consume the last completed item")
_expect(state.production_ready_recipe_record("rice_milk_drink").is_empty(), "final successful drag should prune the completed-row record")
_expect(_queue_row_for_recipe(view, "rice_milk_drink") == null, "row should disappear when completed stock is zero and no active batch remains")
```

- [ ] **Step 2: Run the interaction test and verify the row does not refresh after listing**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\production-completed-drag-red.log" -s res://tests/production_queue_interaction_self_check.gd
```

Expected: FAIL on the final-row visibility assertion because successful listing does not currently refresh the production workbench.

- [ ] **Step 3: Refresh the workbench from the shared successful-list hook**

Extend `_record_manual_list_success`:

```gdscript
func _record_manual_list_success(recipe_id: String, drag_data: Dictionary) -> void:
	state.record_task_event("manual_list_success", {
		"action_kind": String(drag_data.get("manual_list_source", "drag")),
		"recipe_id": recipe_id
	})
	call_deferred("_refresh_production_workbench")
```

Do not add refresh calls to failure branches. `GameState.remove_product` already prunes the ledger before the existing `_save_game()` calls, so the saved state and deferred UI refresh see the same lifecycle.

- [ ] **Step 4: Run real interaction and showcase regression tests**

Run:

```powershell
$tests = @(
  'production_queue_interaction_self_check.gd',
  'showcase_initial_multicell_interaction_self_check.gd',
  'showcase_live_listing_self_check.gd',
  'research_batch_unlock_self_check.gd'
)
foreach ($test in $tests) {
  & "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\$test.log" -s "res://tests/$test"
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
```

Expected: all four exit `0` and print their existing pass markers.

- [ ] **Step 5: Run final production and MVP verification**

Run:

```powershell
$tests = @(
  'recipe_production_timing_self_check.gd',
  'recipe_production_ui_self_check.gd',
  'automation_settlement_self_check.gd',
  'production_queue_scene_self_check.gd',
  'production_recipe_picker_self_check.gd',
  'production_queue_interaction_self_check.gd',
  'research_overlay_production_workbench_self_check.gd',
  'tutorial_guide_dynamic_target_self_check.gd',
  'component_contract_self_check.gd',
  'mvp_self_check.gd'
)
foreach ($test in $tests) {
  & "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\final-$test.log" -s "res://tests/$test"
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
```

Run the import smoke check:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-new-import.log" --quit
```

Expected: every command exits `0`. Windows root-certificate messages and the existing sandbox temp-save warning are non-fatal only when the pass marker and exit code are present.

- [ ] **Step 6: Audit scope and commit**

Run:

```powershell
git diff --check
git status --short
git diff -- scripts/game_state.gd scripts/main_view.gd scripts/ui/pages/production_queue_recipe_row.gd scenes/ui/pages/production_queue_recipe_row.tscn tests/recipe_production_timing_self_check.gd tests/automation_settlement_self_check.gd tests/production_queue_scene_self_check.gd tests/recipe_production_ui_self_check.gd tests/production_queue_interaction_self_check.gd
```

Confirm that existing recipe assets, `scripts/catalog.gd`, unrelated documentation, and fixture edits remain unstaged.

Commit:

```powershell
git add scripts/main_view.gd tests/production_queue_interaction_self_check.gd
git commit -m "feat: drag completed production stock to showcase"
```
