extends SceneTree

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const GAME_STATE := preload("res://scripts/game_state.gd")

var _failures: Array[String] = []
var _save_path := OS.get_temp_dir().path_join("showcase_sold_out_engine_drag_self_check.json")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var view = MAIN_SCENE.instantiate()
	view.set("save_path", _save_path)
	view.set("broken_save_path", _save_path + ".broken")
	root.add_child(view)
	await process_frame
	await process_frame

	var state = GAME_STATE.new_game()
	state.level = 2
	state.shop_level = 2
	state.tutorial_guide_skipped = true
	state.add_recipe("butter_cookie")
	state.add_recipe("rice_milk_drink")
	state.add_recipe("white_sugar_rice_ball")
	state.add_product("rice_milk_drink", 1)
	state.add_product("white_sugar_rice_ball", 1)
	state.set_showcase_unlocked_bounds({"min_row": 4, "max_row": 9, "min_column": 5, "max_column": 10})
	state.display_items = {
		"white_sugar_rice_ball": {
			"cells": [Vector2i(8, 10)],
			"fresh_stock": 0,
			"carried_stock": 0,
			"stock": 0,
			"base_sale_seconds": 13,
			"variant_id": "standard"
		},
		"butter_cookie": {
			"cells": [Vector2i(9, 10)],
			"fresh_stock": 1,
			"carried_stock": 0,
			"stock": 1,
			"base_sale_seconds": 1,
			"variant_id": "standard"
		}
	}
	view.set("state", state)
	view.call("_refresh_showcase_layout_projection")
	view.call("_refresh_storefront_showcase")
	view.call("_refresh_showcase_round_controls")
	view.call("_close_global_popup")
	view.call("_refresh_tutorial_guide")
	await process_frame
	var grid := view.get_node("Root/Body/MainArea/StorefrontPanel/ShowcasePanel/ShowcaseGrid") as GridContainer
	var outside_position := Vector2(1850, 1000)
	var waiting_anchor := int(view.call("_display_anchor_slot_index_for_recipe", "white_sugar_rice_ball"))
	var waiting_button := grid.get_child(waiting_anchor) as Button
	_expect((waiting_button.get("drag_end_callable") as Callable).get_method() == "_on_showcase_product_drag_ended", "adjusting-phase waiting white sugar rice ball should wire drag-end unlisting")
	await _drag_mouse(waiting_button.get_global_rect().get_center(), outside_position)
	_expect(not state.display_items.has("white_sugar_rice_ball"), "adjusting-phase waiting white sugar rice ball should unlist when dragged outside")

	_expect(bool(view.call("_start_showcase_business_round")), "round should start")
	_force_natural_sold_out(view, state, "butter_cookie")
	await process_frame

	var butter_anchor := int(view.call("_display_anchor_slot_index_for_recipe", "butter_cookie"))
	var sold_out_button := grid.get_child(butter_anchor) as Button
	var source_position := sold_out_button.get_global_rect().get_center()
	await _drag_mouse(source_position, outside_position)
	_expect(not state.display_items.has("butter_cookie"), "engine drag from sold-out slot to outside should unlist it")

	_restore_sold_out_item(view, state, "butter_cookie", [Vector2i(9, 10)])
	view.call("_show_inventory_global_popup")
	await process_frame
	await process_frame
	butter_anchor = int(view.call("_display_anchor_slot_index_for_recipe", "butter_cookie"))
	sold_out_button = grid.get_child(butter_anchor) as Button
	var inventory_source := _inventory_drag_source(view, "rice_milk_drink")
	_expect(inventory_source != null, "inventory should expose rice milk drink as an engine drag source")
	if inventory_source != null:
		_expect(bool(sold_out_button.call("_can_drop_data", Vector2.ZERO, inventory_source.get("drag_data"))), "covered sold-out target should be a legal replacement before engine routing")
		await _drag_mouse(inventory_source.get_global_rect().get_center(), sold_out_button.get_global_rect().get_center())
		_expect(not state.display_items.has("butter_cookie"), "engine inventory drop should remove the sold-out item")
		_expect(state.display_items.has("rice_milk_drink"), "engine inventory drop should list the replacement item")
		_expect((view.get_node("GlobalOverlayLayer") as Control).visible, "inventory overlay should return after the product drag ends")

	_finish(view)


func _force_natural_sold_out(view: Node, state, recipe_id: String) -> void:
	var item_states: Dictionary = state.active_business_round.get("item_states", {})
	var item: Dictionary = item_states.get(recipe_id, {}).duplicate(true)
	item["duration_ms"] = 1000
	item["cycle_elapsed_ms"] = 0
	item_states[recipe_id] = item
	state.active_business_round["item_states"] = item_states
	view.call("_advance_showcase_business_round", 1000)


func _restore_sold_out_item(view: Node, state, recipe_id: String, cells: Array[Vector2i]) -> void:
	state.display_items[recipe_id] = {
		"cells": cells.duplicate(),
		"fresh_stock": 0,
		"carried_stock": 0,
		"stock": 0,
		"base_sale_seconds": 1,
		"variant_id": "standard"
	}
	var item_states: Dictionary = state.active_business_round.get("item_states", {})
	item_states[recipe_id] = {
		"recipe_id": recipe_id,
		"fresh_stock": 0,
		"carried_stock": 0,
		"waiting_for_refill": true,
		"duration_ms": 1000,
		"cycle_elapsed_ms": 0
	}
	state.active_business_round["item_states"] = item_states
	view.call("_refresh_showcase_layout_projection")
	view.call("_refresh_storefront_showcase")


func _inventory_drag_source(view: Node, recipe_id: String) -> Control:
	var inventory_grid := view.get_node("GlobalOverlayLayer/OverlayFrame/OverlayModeStack/InventoryOverlay/InventoryBody/InventoryMainPanel/InventoryGrid")
	for child in inventory_grid.get_children():
		var drag_data: Variant = child.get("drag_data")
		if drag_data is Dictionary and String((drag_data as Dictionary).get("recipe_id", "")) == recipe_id:
			return child as Control
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


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error(message)


func _finish(view: Node) -> void:
	if is_instance_valid(view):
		view.queue_free()
	if FileAccess.file_exists(_save_path):
		DirAccess.remove_absolute(_save_path)
	if FileAccess.file_exists(_save_path + ".broken"):
		DirAccess.remove_absolute(_save_path + ".broken")
	if _failures.is_empty():
		print("SHOWCASE_SOLD_OUT_ENGINE_DRAG_SELF_CHECK_PASS")
		quit(0)
	else:
		for failure in _failures:
			printerr("SHOWCASE_SOLD_OUT_ENGINE_DRAG_SELF_CHECK_FAIL: %s" % failure)
		quit(1)
