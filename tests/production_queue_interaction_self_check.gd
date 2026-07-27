extends SceneTree

const GameState := preload("res://scripts/game_state.gd")
const MainScene := preload("res://scenes/Main.tscn")

var failures: Array[String] = []
var save_path := OS.get_temp_dir().path_join("production_queue_interaction_self_check.json")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var view = MainScene.instantiate()
	view.set("save_path", save_path)
	view.set("broken_save_path", save_path + ".broken")
	root.add_child(view)
	await process_frame
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
	state.unlock_ingredient_process("rice_flour")
	state.ingredient_inventory = {"rice": 5, "spring_water": 5}
	view.set("state", state)
	view.call("_refresh_current_page")
	await process_frame
	await process_frame

	var make_target := view.call("_tutorial_recipe_action_target", "make") as Control
	_expect(make_target != null and make_target is Button, "craft tutorial should target the real queue-row action")
	if make_target != null:
		await _click(make_target.get_global_rect().get_center())
	_expect_equal("real make click queues one batch", state.recipe_production_queue.size(), 1)
	_expect(String(view.get("global_popup_mode")).is_empty(), "queue-row make should not open the removed picker")
	await process_frame
	var active_row := _queue_row_for_recipe(view, "rice_milk_drink")
	_expect(active_row != null, "active recipe row should remain visible")
	if active_row != null:
		_expect((active_row.get_node("Content/ActionButton") as Button).disabled, "active recipe action should be disabled")

	var process_row := _queue_row_for_recipe(view, "rice_flour_process")
	_expect(process_row != null, "processed ingredient should share the same queue")
	if process_row != null:
		await _click((process_row.get_node("Content/ActionButton") as Button).get_global_rect().get_center())
	_expect_equal("real process click creates timed task", state.ingredient_processing_queue.size(), 1)
	_expect_equal("processed output waits for completion", state.get_ingredient_count("rice_flour"), 0)

	state.recipe_production_queue.clear()
	state.ingredient_processing_queue.clear()
	state.ingredient_inventory = {"rice": 2, "spring_water": 2}
	_expect(state.queue_recipe_production("rice_milk_drink", 1, 100, "manual"), "fixture should start a completed-stock batch")
	_expect(state.complete_recipe_production(0, 2147483647), "fixture should complete the batch")
	view.call("_refresh_production_workbench")
	await process_frame
	await process_frame

	var completed_cell := _completed_cell_for_recipe(view, "rice_milk_drink")
	_expect(completed_cell != null, "completed recipe stock should move to the left rail")
	if completed_cell == null:
		view.queue_free()
		await process_frame
		_cleanup()
		_finish()
		return
	var completed_drag := completed_cell.get_node("DragButton") as Button
	var stock_before: int = state.get_product_count("rice_milk_drink")
	var target := _first_valid_showcase_target(view, completed_drag.get("drag_data"))
	_expect(target != null, "fixture should find an unlocked showcase drop target")
	if target != null:
		await _drag_mouse(completed_drag.get_global_rect().get_center(), target.get_global_rect().get_center())
	_expect_equal("real queue drag lists one product", state.get_product_count("rice_milk_drink"), stock_before - 1)
	var refreshed_cell := _completed_cell_for_recipe(view, "rice_milk_drink")
	_expect(refreshed_cell != null, "left cell should remain while completed stock is still positive")
	if refreshed_cell != null:
		var refreshed_badge := refreshed_cell.get_node("DragButton/StockBadge") as Label
		_expect_equal("successful drag refreshes visible stock", refreshed_badge.text, str(stock_before - 1))

	state.product_inventory["rice_milk_drink"] = 1
	state.mark_recipe_production_ready("rice_milk_drink", 99, 100)
	view.call("_refresh_production_workbench")
	await process_frame
	await process_frame
	var one_item_cell := _completed_cell_for_recipe(view, "rice_milk_drink")
	_expect(one_item_cell != null, "one-item fixture should expose the completed left cell")
	if one_item_cell == null:
		view.queue_free()
		await process_frame
		_cleanup()
		_finish()
		return
	var one_item_drag := one_item_cell.get_node("DragButton") as Button
	view.call("_on_production_queue_search_changed", "清爽")
	await process_frame
	_expect(_completed_cell_for_recipe(view, "rice_milk_drink") != null, "tag search should retain matching completed stock")
	view.call("_on_production_queue_search_changed", "不存在的标签")
	await process_frame
	_expect(_completed_cell_for_recipe(view, "rice_milk_drink") == null, "search should hide nonmatching completed stock")
	view.call("_on_production_queue_search_changed", "")
	await process_frame
	one_item_cell = _completed_cell_for_recipe(view, "rice_milk_drink")
	_expect(one_item_cell != null, "clearing search should restore completed stock")
	if one_item_cell == null:
		view.queue_free()
		await process_frame
		_cleanup()
		_finish()
		return
	one_item_drag = one_item_cell.get_node("DragButton") as Button

	state.ingredient_process_unlocks.clear()
	state.ingredient_inventory = {"rice": 10, "spring_water": 10}
	state.unlock_feature("research_make_all")
	view.call("_make_all_available_products")
	_expect_equal(
		"make all excludes recipes with completed stock",
		state.active_recipe_production_batch_count("rice_milk_drink"),
		0
	)
	var invalid_data: Dictionary = (one_item_drag.get("drag_data") as Dictionary).duplicate(true)
	invalid_data["target_slot_index"] = -1
	_expect(not bool(view.call("_drop_showcase_data", "showcase", invalid_data)), "invalid target should reject completed stock")
	_expect_equal("failed drop preserves completed stock", state.get_product_count("rice_milk_drink"), 1)
	_expect(not state.production_ready_recipe_record("rice_milk_drink").is_empty(), "failed drop should preserve the row record")

	var final_target := _first_valid_showcase_target(view, one_item_drag.get("drag_data"))
	_expect(final_target != null, "fixture should find a target for the final completed item")
	if final_target != null:
		var final_data: Dictionary = (one_item_drag.get("drag_data") as Dictionary).duplicate(true)
		final_data["target_slot_index"] = int(final_target.get_meta("slot_index", -1))
		_expect(bool(view.call("_drop_showcase_data", "showcase", final_data)), "final completed item should use the shared showcase drop path")
		await process_frame
		await process_frame
	_expect_equal("final drag consumes last completed item", state.get_product_count("rice_milk_drink"), 0)
	_expect(state.production_ready_recipe_record("rice_milk_drink").is_empty(), "final drag should prune the completed-row record")
	_expect(_completed_cell_for_recipe(view, "rice_milk_drink") == null, "final listing removes the completed left cell")
	var final_row := _queue_row_for_recipe(view, "rice_milk_drink")
	_expect(final_row != null, "cleared recipe should return to the right queue")

	view.queue_free()
	await process_frame
	_cleanup()
	_finish()


func _click(position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	Input.parse_input_event(motion)
	await process_frame
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = position
	press.global_position = position
	Input.parse_input_event(press)
	await process_frame
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = position
	release.global_position = position
	Input.parse_input_event(release)
	await process_frame
	await process_frame


func _queue_row_for_recipe(view: Control, recipe_id: String) -> Control:
	var rows := view.get_node(
		"Root/Body/MainArea/WorkbenchPanel/ProductionWorkbench/"
		+ "ProductionColumns/QueueColumn/QueueScroll/QueueRows"
	)
	for child_value: Variant in rows.get_children():
		if child_value is Control and String((child_value as Control).get_meta("recipe_id", "")) == recipe_id:
			return child_value as Control
	return null


func _completed_cell_for_recipe(view: Control, recipe_id: String) -> Control:
	var cells := view.get_node(
		"Root/Body/MainArea/WorkbenchPanel/ProductionWorkbench/"
		+ "ProductionColumns/CompletedColumn/CompletedScroll/CompletedCenter/CompletedCells"
	)
	for child_value: Variant in cells.get_children():
		if child_value is Control \
				and String((child_value as Control).get_meta("recipe_id", "")) == recipe_id:
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
	var hover := InputEventMouseMotion.new()
	hover.position = from
	hover.global_position = from
	Input.parse_input_event(hover)
	await process_frame

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


func _cleanup() -> void:
	for path in [save_path, save_path + ".broken"]:
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
		print("PRODUCTION_QUEUE_INTERACTION_SELF_CHECK_PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
