extends SceneTree

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const GAME_STATE := preload("res://scripts/game_state.gd")

var _failures: Array[String] = []
var _save_path := OS.get_temp_dir().path_join("showcase_sold_out_drag_path_self_check.json")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var view = MAIN_SCENE.instantiate()
	view.set("save_path", _save_path)
	view.set("broken_save_path", _save_path + ".broken")
	root.add_child(view)
	await process_frame
	await process_frame

	var state = GAME_STATE.new_game()
	state.level = 2
	state.shop_level = 2
	state.add_recipe("butter_cookie")
	state.add_recipe("rice_milk_drink")
	state.add_product("rice_milk_drink", 1)
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
	_expect_equal("round starts", bool(view.call("_start_showcase_business_round")), true)
	var item_states: Dictionary = state.active_business_round.get("item_states", {})
	var butter_state: Dictionary = item_states.get("butter_cookie", {}).duplicate(true)
	butter_state["duration_ms"] = 1000
	butter_state["cycle_elapsed_ms"] = 0
	item_states["butter_cookie"] = butter_state
	state.active_business_round["item_states"] = item_states

	view.call("_advance_showcase_business_round", 1000)
	await process_frame
	var sold_out_state: Dictionary = (state.active_business_round.get("item_states", {}) as Dictionary).get("butter_cookie", {})
	_expect_equal("natural sale consumes the last unit", int(sold_out_state.get("fresh_stock", -1)), 0)
	_expect_equal("natural sale enters waiting state", bool(sold_out_state.get("waiting_for_refill", false)), true)

	var grid := view.get_node("Root/Body/MainArea/StorefrontPanel/ShowcasePanel/ShowcaseGrid") as GridContainer
	var butter_anchor := int(view.call("_display_anchor_slot_index_for_recipe", "butter_cookie"))
	var sold_out_button := grid.get_child(butter_anchor) as Button
	var sold_out_drag_data: Dictionary = sold_out_button.get("drag_data")
	_expect(not sold_out_drag_data.is_empty(), "naturally sold-out cell should immediately become a drag source")
	_expect((sold_out_button.get("drag_end_callable") as Callable).is_valid(), "naturally sold-out cell should wire drag-out completion")

	var inventory_drag := {
		"kind": "inventory_product",
		"recipe_id": "rice_milk_drink",
		"variant_id": "standard"
	}
	_expect_equal(
		"real showcase control accepts inventory drag over sold-out cell",
		bool(sold_out_button.call("_can_drop_data", Vector2.ZERO, inventory_drag)),
		true
	)
	sold_out_button.call("_drop_data", Vector2.ZERO, inventory_drag)
	await process_frame
	_expect_equal("real control drop removes sold-out product", state.display_items.has("butter_cookie"), false)
	_expect_equal("real control drop lists replacement product", state.display_items.has("rice_milk_drink"), true)
	_expect_equal(
		"replacement auto-anchors upward from a bottom-edge sold-out cell",
		state.get_display_item_cells("rice_milk_drink"),
		[Vector2i(8, 10), Vector2i(9, 10)]
	)

	_finish(view)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _expect_equal(message: String, actual: Variant, expected: Variant) -> void:
	if actual != expected:
		_fail("%s expected %s, got %s" % [message, str(expected), str(actual)])


func _fail(message: String) -> void:
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
		print("SHOWCASE_SOLD_OUT_DRAG_PATH_SELF_CHECK_PASS")
		quit(0)
	else:
		for failure in _failures:
			print("SHOWCASE_SOLD_OUT_DRAG_PATH_SELF_CHECK_FAIL: %s" % failure)
		quit(1)
