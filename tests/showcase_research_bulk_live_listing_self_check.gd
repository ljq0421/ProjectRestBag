extends SceneTree

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const GAME_STATE := preload("res://scripts/game_state.gd")

var _failures: Array[String] = []
var _save_path := OS.get_temp_dir().path_join("showcase_research_bulk_live_listing_self_check.json")


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
	state.unlock_feature("research_list_all")
	state.add_recipe("sponge_cake")
	state.add_recipe("butter_cookie")
	state.display_items = {
		"sponge_cake": {
			"cells": [Vector2i(5, 5), Vector2i(5, 6), Vector2i(6, 5), Vector2i(6, 6)],
			"fresh_stock": 1,
			"carried_stock": 0,
			"stock": 1,
			"variant_id": "standard"
		}
	}
	view.set("state", state)
	view.call("_refresh_showcase_layout_projection")
	view.call("_refresh_storefront_showcase")
	view.call("_refresh_showcase_round_controls")
	_expect_equal("round starts", bool(view.call("_start_showcase_business_round")), true)
	state.active_business_round["paused"] = true

	var item_states: Dictionary = state.active_business_round.get("item_states", {})
	var sold_out: Dictionary = item_states.get("sponge_cake", {})
	sold_out["fresh_stock"] = 0
	sold_out["carried_stock"] = 0
	sold_out["cycle_elapsed_ms"] = 0
	sold_out["waiting_for_refill"] = true
	item_states["sponge_cake"] = sold_out
	state.active_business_round["item_states"] = item_states
	state.add_product("sponge_cake", 6)
	state.add_product("butter_cookie", 5)
	_expect_equal("new product is unlocked for the batch action", state.is_recipe_unlocked("butter_cookie"), true)
	_expect_equal(
		"new product has an available unlocked placement",
		(view.call("_first_available_showcase_placement", "butter_cookie", "standard") as Dictionary).is_empty(),
		false
	)
	view.call("_refresh_storefront_showcase")
	_expect_equal("sold-out recipe begins gray", _anchor_button(view, "sponge_cake").modulate, Color(0.48, 0.48, 0.48, 0.82))

	view.call("_on_tertiary_action")
	await process_frame

	var refilled: Dictionary = (state.active_business_round.get("item_states", {}) as Dictionary).get("sponge_cake", {})
	_expect_equal("research list-all consumes inventory", int(state.get_product_count("sponge_cake")), 0)
	_expect_equal("research list-all consumes new-product inventory", int(state.get_product_count("butter_cookie")), 0)
	_expect_equal("research list-all adds all stock beyond the old capacity", int(refilled.get("fresh_stock", 0)), 6)
	_expect_equal("research list-all releases waiting state", bool(refilled.get("waiting_for_refill", true)), false)
	_expect_equal("running showcase view reads the new stock", int((view.call("_showcase_round_item_view", "sponge_cake") as Dictionary).get("quantity", 0)), 6)
	_expect_equal("research list-all restores the product icon color", _anchor_button(view, "sponge_cake").modulate, Color.WHITE)
	_expect_equal("research list-all shows batch refill feedback", _anchor_badge_text(view, "sponge_cake"), "补货 +6")
	var butter_state: Dictionary = (state.active_business_round.get("item_states", {}) as Dictionary).get("butter_cookie", {})
	_expect_equal("research list-all immediately adds all new-product inventory", int(butter_state.get("fresh_stock", 0)), 5)
	_expect_equal("new batch-listed product is rendered on the showcase", String(_anchor_button(view, "butter_cookie").get_meta("recipe_id", "")), "butter_cookie")
	_expect_equal("new batch-listed product is not gray", _anchor_button(view, "butter_cookie").modulate, Color.WHITE)
	var listing_events: Array = state.active_business_round.get("live_listing_events", [])
	_expect_equal("batch live listing records one layout event", listing_events.size(), 1)
	if not listing_events.is_empty():
		_expect_equal("batch live listing records its full amount", int((listing_events[0] as Dictionary).get("amount", 0)), 5)
	var status_label := view.get_node("Root/StatusBar/StatusLabel") as Label
	_expect(status_label.text.find("已上架 11 份成品") >= 0, "research list-all should retain its full batch success summary")
	_expect(status_label.text.find("容量") == -1, "research list-all feedback should not mention display capacity")

	_finish(view)


func _anchor_button(view: Node, recipe_id: String) -> Button:
	var anchor_slot := int(view.call("_display_anchor_slot_index_for_recipe", recipe_id))
	var grid := view.get_node("Root/Body/MainArea/StorefrontPanel/ShowcasePanel/ShowcaseGrid") as GridContainer
	return grid.get_child(anchor_slot) as Button


func _anchor_badge_text(view: Node, recipe_id: String) -> String:
	var badge := _anchor_button(view, recipe_id).get_node_or_null("StatusBadge") as Label
	return badge.text if badge != null and badge.visible else ""


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _expect_equal(label: String, actual: Variant, expected: Variant) -> void:
	if actual != expected:
		_fail("%s expected %s, got %s" % [label, expected, actual])


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish(view: Node) -> void:
	if is_instance_valid(view):
		view.queue_free()
	if FileAccess.file_exists(_save_path):
		DirAccess.remove_absolute(_save_path)
	if FileAccess.file_exists(_save_path + ".tmp"):
		DirAccess.remove_absolute(_save_path + ".tmp")
	if _failures.is_empty():
		print("SHOWCASE_RESEARCH_BULK_LIVE_LISTING_SELF_CHECK_PASS")
		quit(0)
	else:
		for failure in _failures:
			printerr("SHOWCASE_RESEARCH_BULK_LIVE_LISTING_SELF_CHECK_FAIL: %s" % failure)
		quit(1)
