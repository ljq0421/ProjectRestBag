extends SceneTree

const GameState := preload("res://scripts/game_state.gd")
const MainScene := preload("res://scenes/Main.tscn")
const TEST_SAVE_PATH := "res://tests/recipe_production_ui_self_check.save.json"

var failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var view = MainScene.instantiate()
	view.set("save_path", TEST_SAVE_PATH)
	root.add_child(view)
	await process_frame
	view.set_process(false)

	var state = GameState.new_game()
	state.level = 5
	state.tutorial_guide_finished = true
	for feature_id in ["purchase", "output", "inventory", "research", "craft", "catalog", "list"]:
		state.unlock_core_feature(feature_id)
	state.unlock_device("round_pot")
	state.unlock_device("grinder")
	state.add_recipe("rice_milk_drink")
	state.add_recipe("rich_rice_drink")
	state.unlock_ingredient_process("rice_flour")
	state.ingredient_inventory = {"rice": 20, "spring_water": 20, "milk": 20, "sugar": 20}
	_expect(state.queue_recipe_production("rice_milk_drink", 1, 1000), "first manual queue should start")
	_expect(not state.queue_recipe_production("rice_milk_drink", 1, 1000), "same recipe second batch should be rejected")
	_expect(state.queue_recipe_production("rich_rice_drink", 1, 1000), "different recipe should run in parallel")
	_expect(state.queue_ingredient_processing("rice_flour_process", 1000), "processed ingredient should run beside finished recipes")
	view.set("state", state)

	var snapshot: Dictionary = view.call("_build_unified_production_queue_snapshot", 1000)
	var completed_entries: Array = snapshot.get("completed_entries", [])
	var queue_entries: Array = snapshot.get("queue_entries", [])
	var entries: Array = queue_entries
	_expect_equal("active snapshot starts without completed stock", completed_entries.size(), 0)
	_expect_equal("right queue owns every active entry", queue_entries.size(), entries.size())
	var rice_process := _entry_for_id(entries, "rice_flour_process")
	var rice_recipe := _entry_for_id(entries, "rice_milk_drink")
	var rich_recipe := _entry_for_id(entries, "rich_rice_drink")
	_expect(not rice_process.is_empty(), "active processed ingredient should be in unified queue")
	_expect(not rice_recipe.is_empty(), "active finished recipe should be in unified queue")
	_expect(not rich_recipe.is_empty(), "different active finished recipe should be in unified queue")
	if not rice_process.is_empty():
		_expect_equal("processing band comes first", int(rice_process.get("sort_band", -1)), 0)
		_expect_equal("processing price is zero", int(rice_process.get("price", -1)), 0)
		_expect_equal("processing duration is explicit", int(rice_process.get("duration_seconds", 0)), 2)
	if not rice_recipe.is_empty():
		_expect_equal("active finished recipe stays in upper band", int(rice_recipe.get("sort_band", -1)), 1)
		_expect_equal("active finished action", String(rice_recipe.get("action_kind", "")), "active")
		_expect_equal("active finished progress starts at zero", float(rice_recipe.get("progress", -1.0)), 0.0)
	_assert_finished_price_descending(entries)

	view.call("_refresh_production_workbench")
	await process_frame
	var workbench = view.get("production_workbench")
	var rows := workbench.get_node(
		"ProductionColumns/QueueColumn/QueueScroll/QueueRows"
	) as VBoxContainer
	var queue_row := _queue_row_for_recipe(rows, "rice_milk_drink")
	_expect(queue_row != null, "finished recipe should render one persistent row")
	if queue_row != null:
		_expect_equal("row height is 68", int(queue_row.custom_minimum_size.y), 68)
		_expect(queue_row.get_node_or_null("Content/BatchSlots") == null, "row should not have per-batch slots")
		_expect_equal("active row action disabled", (queue_row.get_node("Content/ActionButton") as Button).disabled, true)

	var completion: Dictionary = view.call("_process_online_recipe_production", 1002)
	_expect_equal("online tick completes one finished batch", int(completion.get("completed_batches", 0)), 1)
	_expect_equal("online tick completes one processed ingredient", int(completion.get("completed_processes", 0)), 1)
	_expect_equal("finished output enters stock", state.get_product_count("rice_milk_drink"), 3)
	_expect_equal("processed output enters stock", state.get_ingredient_count("rice_flour"), 2)
	_expect_equal("longer finished recipe remains active", state.recipe_production_queue.size(), 1)
	var status_bar := view.get_node("Root/StatusBar/StatusLabel") as Label
	_expect(status_bar.text.find("制作完成") >= 0, "combined completion should provide visible feedback")
	state.ingredient_inventory["rice"] = 0
	snapshot = view.call("_build_unified_production_queue_snapshot", 1002)
	completed_entries = snapshot.get("completed_entries", [])
	queue_entries = snapshot.get("queue_entries", [])
	rich_recipe = _entry_for_id(queue_entries, "rich_rice_drink")
	_expect_equal("active recipe stays in upper band after inputs were consumed", int(rich_recipe.get("sort_band", -1)), 1)
	_expect(not _entry_for_id(completed_entries, "rice_milk_drink").is_empty(), "finished stock moves to completed ownership")
	_expect(_entry_for_id(queue_entries, "rice_milk_drink").is_empty(), "finished stock is not duplicated in right queue")

	state.unlock_device("oven")
	state.add_recipe("sponge_cake")
	_expect(state.add_product("sponge_cake", 1), "second completed fixture enters product stock")
	state.mark_recipe_production_ready("sponge_cake", 99, 1002)
	snapshot = view.call("_build_unified_production_queue_snapshot", 1002)
	completed_entries = snapshot.get("completed_entries", [])
	queue_entries = snapshot.get("queue_entries", [])
	_expect_equal("two recipes have completed ownership", completed_entries.size(), 2)
	if completed_entries.size() >= 2:
		_expect_equal("completed stock sorts higher price first", String((completed_entries[0] as Dictionary).get("recipe_id", "")), "sponge_cake")
		_expect_equal("completed stock sorts lower price second", String((completed_entries[1] as Dictionary).get("recipe_id", "")), "rice_milk_drink")
	var completed_rice := _entry_for_id(completed_entries, "rice_milk_drink")
	if not completed_rice.is_empty():
		var completed_icon: Texture2D = completed_rice.get("icon") as Texture2D
		_expect(completed_icon != null, "completed stock uses a product texture")
		if completed_icon != null:
			_expect(completed_icon.resource_path.find("resources/recipe_icons/") >= 0, "completed stock uses the 128 base icon")
			_expect(completed_icon.resource_path.find("recipe_icons_action") < 0, "completed stock must not upscale a 32 action icon")

	_expect(state.remove_product("rice_milk_drink", 3), "clearing completed stock succeeds")
	snapshot = view.call("_build_unified_production_queue_snapshot", 1002)
	completed_entries = snapshot.get("completed_entries", [])
	queue_entries = snapshot.get("queue_entries", [])
	_expect(_entry_for_id(completed_entries, "rice_milk_drink").is_empty(), "zero stock removes completed ownership")
	_expect(not _entry_for_id(queue_entries, "rice_milk_drink").is_empty(), "zero stock returns recipe to right queue")
	_expect(state.production_ready_recipe_record("rice_milk_drink").is_empty(), "zero stock clears completed-ready record")

	state.recipe_production_queue.clear()
	for process_id_value: Variant in view.get("catalog").get_processing_recipes().keys():
		var process: Dictionary = view.get("catalog").get_processing_recipes().get(process_id_value, {})
		state.unlock_ingredient_process(String(process.get("output_item_id", "")))
	state.ingredient_inventory.clear()
	snapshot = view.call("_build_unified_production_queue_snapshot", 1003)
	entries = snapshot.get("queue_entries", [])
	_assert_processing_duration_order(entries)
	_assert_missing_finished_price_order(entries)
	rice_recipe = _entry_for_id(entries, "rice_milk_drink")
	_expect_equal("missing finished recipe moves to final band", int(rice_recipe.get("sort_band", -1)), 3)
	_expect(String(rice_recipe.get("disabled_reason", "")).find("不足") >= 0, "missing recipe explains material shortage")
	var rice_material := _material_for_id(rice_recipe.get("materials", []), "rice")
	_expect(not rice_material.is_empty(), "row data should include named rice material")
	if not rice_material.is_empty():
		_expect_equal("missing material owned count", int(rice_material.get("owned_count", -1)), 0)
		_expect_equal("missing material required count", int(rice_material.get("required_count", -1)), 1)
		_expect(String(rice_material.get("display_text", "")).find("0/1") >= 0, "missing material uses current/required display")

	view.call("_refresh_production_workbench")
	await process_frame
	view.call("_on_production_queue_search_changed", "米浆饮")
	await process_frame
	_expect_equal("search keeps one matching row", _visible_recipe_row_count(rows), 1)
	view.call("_on_production_queue_search_changed", "")

	view.queue_free()
	await process_frame
	_cleanup_test_save()
	_finish()


func _assert_finished_price_descending(entries: Array) -> void:
	var last_price := 2147483647
	for entry_value: Variant in entries:
		if not entry_value is Dictionary:
			continue
		var entry: Dictionary = entry_value
		if String(entry.get("entry_kind", "")) != "finished" or int(entry.get("sort_band", -1)) != 1:
			continue
		var price := int(entry.get("price", 0))
		_expect(price <= last_price, "finished recipes in the same band must sort price high to low")
		last_price = price


func _assert_processing_duration_order(entries: Array) -> void:
	var last_duration := -1
	var last_stable_order := -1
	for entry_value: Variant in entries:
		if not entry_value is Dictionary:
			continue
		var entry: Dictionary = entry_value
		if String(entry.get("entry_kind", "")) != "processing" or int(entry.get("sort_band", -1)) != 2:
			continue
		var duration := int(entry.get("duration_seconds", 0))
		var stable_order := int(entry.get("stable_order", -1))
		_expect(duration >= last_duration, "missing processed ingredients must sort by duration ascending")
		if duration == last_duration:
			_expect(stable_order > last_stable_order, "equal processing durations must keep config unlock order")
		last_duration = duration
		last_stable_order = stable_order


func _assert_missing_finished_price_order(entries: Array) -> void:
	var last_price := 2147483647
	for entry_value: Variant in entries:
		if not entry_value is Dictionary:
			continue
		var entry: Dictionary = entry_value
		if String(entry.get("entry_kind", "")) != "finished" or int(entry.get("sort_band", -1)) != 3:
			continue
		var price := int(entry.get("price", 0))
		_expect(price <= last_price, "missing finished recipes must sort price high to low")
		last_price = price


func _entry_for_id(entries: Array, item_id: String) -> Dictionary:
	for entry_value: Variant in entries:
		if entry_value is Dictionary and String((entry_value as Dictionary).get("recipe_id", "")) == item_id:
			return entry_value as Dictionary
	return {}


func _material_for_id(materials_value: Variant, material_id: String) -> Dictionary:
	if not materials_value is Array:
		return {}
	for material_value: Variant in materials_value:
		if material_value is Dictionary and String((material_value as Dictionary).get("id", "")) == material_id:
			return material_value as Dictionary
	return {}


func _queue_row_for_recipe(rows: VBoxContainer, recipe_id: String) -> Control:
	for child_value: Variant in rows.get_children():
		if child_value is Control and String((child_value as Control).get_meta("recipe_id", "")) == recipe_id:
			return child_value as Control
	return null


func _visible_recipe_row_count(rows: VBoxContainer) -> int:
	var count := 0
	for child_value: Variant in rows.get_children():
		if child_value is Control and not String((child_value as Control).get_meta("entry_key", "")).is_empty():
			count += 1
	return count


func _cleanup_test_save() -> void:
	var path := ProjectSettings.globalize_path(TEST_SAVE_PATH)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _expect_equal(label: String, actual: Variant, expected: Variant) -> void:
	if actual != expected:
		failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])


func _finish() -> void:
	if failures.is_empty():
		print("RECIPE_PRODUCTION_UI_SELF_CHECK_PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
