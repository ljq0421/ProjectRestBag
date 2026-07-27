extends SceneTree

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const GAME_STATE := preload("res://scripts/game_state.gd")

var _failures: Array[String] = []
var _save_path := OS.get_temp_dir().path_join("showcase_drag_preview_main_path_self_check.json")


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
	state.set_showcase_unlocked_bounds({"min_row": 4, "max_row": 9, "min_column": 5, "max_column": 10})
	state.display_items = {
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
	var anchor := int(view.call("_display_anchor_slot_index_for_recipe", "butter_cookie"))
	var slot := grid.get_child(anchor) as Button
	var unlist_label := view.get_node_or_null("ShowcaseUnlistDragLabel") as Label
	var outside_position := Vector2(1850, 1000)
	var inventory_before := int(state.get_product_count("butter_cookie"))
	_expect(view.call("_can_unlist_showcase_item", "butter_cookie") == true, "stocked adjusting-phase item should allow drag-out unlisting")

	var drag_started := await _start_mouse_drag(slot)
	var preview := root.find_child("ShowcaseProductDragPreview", true, false) as Control
	_expect(drag_started, "real mouse input should start a drag from the stocked showcase slot")
	_expect(preview != null, "the inherited drag entry point should attach the specialized showcase preview")
	_expect(unlist_label != null, "main scene should provide a top-level unlist drag label")
	_expect(root.gui_is_dragging(), "real showcase slot should start an engine drag")
	_expect(unlist_label != null and not unlist_label.visible, "real main-view drag inside showcase should stay transparent")
	var locked_slot := grid.get_child(0) as Control
	var locked_position := locked_slot.get_global_rect().get_center()
	await _move_drag(locked_position)
	var invalid_drag_data: Dictionary = (slot.get("drag_data") as Dictionary).duplicate(true)
	invalid_drag_data["target_slot_index"] = 0
	_expect(
		view.call("_can_drop_showcase_data", "showcase", invalid_drag_data) == false,
		"locked showcase cell should reject the dragged product"
	)
	_expect(
		String(view.get("showcase_unlist_drag_recipe_id")) == "butter_cookie",
		"crossing an invalid showcase cell should not end unlist-status tracking"
	)
	_expect(grid.get_global_rect().has_point(root.get_mouse_position()), "locked test cell should still be inside the full showcase grid")
	_expect(unlist_label != null and unlist_label.visible, "leaving the unlocked showcase cells should show 下架 even inside the full grid")

	await _move_drag(outside_position)
	_expect(not grid.get_global_rect().has_point(root.get_mouse_position()), "test pointer should be outside the real showcase grid")
	_expect(unlist_label != null and unlist_label.visible, "real main-view drag outside showcase should show 下架")
	if unlist_label != null:
		_expect(unlist_label.size == Vector2(112, 56), "下架 label should retain its intended 112x56 size when repositioned")
		_expect(
			root.get_visible_rect().encloses(unlist_label.get_global_rect()),
			"下架 label should remain fully inside the viewport near a window edge"
		)
		_expect(
			not unlist_label.get_global_rect().has_point(root.get_mouse_position()),
			"下架 label should not sit underneath the forbidden drag cursor"
		)

	await _move_drag(locked_position)
	_expect(unlist_label != null and unlist_label.visible, "下架 should remain visible over a locked cell before release")
	await _release_drag(locked_position)
	_expect(not state.display_items.has("butter_cookie"), "real mouse drag outside unlocked cells should unlist the stocked product")
	_expect(int(state.get_product_count("butter_cookie")) == inventory_before + 1, "unlisting should return remaining stock to product inventory")
	_finish(view)


func _move_drag(to: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	motion.position = to
	motion.global_position = to
	motion.relative = Vector2(400, 300)
	Input.parse_input_event(motion)
	await process_frame
	await process_frame


func _start_mouse_drag(source: Control) -> bool:
	var from := source.get_global_rect().get_center()
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

	var motion := InputEventMouseMotion.new()
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	motion.position = from + Vector2(24, 0)
	motion.global_position = motion.position
	motion.relative = Vector2(24, 0)
	Input.parse_input_event(motion)
	await process_frame
	await process_frame
	return root.gui_is_dragging()


func _release_drag(at: Vector2) -> void:
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = at
	release.global_position = at
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
		print("SHOWCASE_DRAG_PREVIEW_MAIN_PATH_SELF_CHECK_PASS")
		quit(0)
	else:
		for failure in _failures:
			printerr("SHOWCASE_DRAG_PREVIEW_MAIN_PATH_SELF_CHECK_FAIL: %s" % failure)
		quit(1)
