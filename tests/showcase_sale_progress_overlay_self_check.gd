extends SceneTree

const SLOT_SCENE_PATH := "res://scenes/ui/storefront/showcase_slot.tscn"
const GROUP_SCENE_PATH := "res://scenes/ui/storefront/showcase_sale_progress_group.tscn"
const MAIN := preload("res://scenes/Main.tscn")
const GAME_STATE := preload("res://scripts/game_state.gd")

var _failures: Array[String] = []
var _save_path := OS.get_temp_dir().path_join("showcase_sale_progress_overlay_self_check.json")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var group_packed := load(GROUP_SCENE_PATH) as PackedScene
	if group_packed == null:
		_fail("showcase sale progress group scene should load")
		_finish()
		return
	var group := group_packed.instantiate() as Control
	root.add_child(group)
	await process_frame
	_expect(group.has_method("configure"), "group overlay should expose geometry configuration")
	if not group.has_method("configure"):
		group.queue_free()
		_finish()
		return
	_expect(group.mouse_filter == Control.MOUSE_FILTER_IGNORE, "group overlay should ignore mouse input")
	_expect((group.get("fill_color") as Color).is_equal_approx(Color(0.941176, 0.392157, 0.0, 0.45)), "group overlay should own the approved fill color")
	_expect((group.get("edge_color") as Color).is_equal_approx(Color(1.0, 0.878431, 0.541176, 1.0)), "group overlay should own the approved edge color")

	group.call("configure", "horizontal", [Rect2(10, 20, 40, 40), Rect2(50, 20, 40, 40)], 0.5, true)
	var horizontal_fills: Array = group.get("fill_rects")
	var horizontal_edges: Array = group.get("edge_segments")
	_expect(group.visible and group.size.is_equal_approx(Vector2(80, 40)), "horizontal product should use one overlay spanning both cells")
	_expect(horizontal_fills.size() == 2, "horizontal product should fill both occupied cell intersections")
	_expect(_has_rect(horizontal_fills, Rect2(0, 20, 40, 20)) and _has_rect(horizontal_fills, Rect2(40, 20, 40, 20)), "horizontal product should share one bottom-up liquid level")
	_expect(horizontal_edges.size() == 1 and (horizontal_edges[0] as Vector2).is_equal_approx(Vector2(0, 80)), "horizontal adjacent cells should merge into one continuous edge")

	group.call("configure", "vertical", [Rect2(0, 0, 40, 40), Rect2(0, 40, 40, 40)], 0.5, true)
	var vertical_fills: Array = group.get("fill_rects")
	_expect(vertical_fills.size() == 1 and _has_rect(vertical_fills, Rect2(0, 40, 40, 40)), "vertical fifty-percent progress should fill only the lower cell")

	group.call("configure", "l_shape", [Rect2(0, 0, 40, 40), Rect2(0, 40, 40, 40), Rect2(40, 40, 40, 40)], 0.5, true)
	var l_shape_fills: Array = group.get("fill_rects")
	_expect(l_shape_fills.size() == 2, "L-shaped product should fill only its two occupied lower cells")
	_expect(_has_rect(l_shape_fills, Rect2(0, 40, 40, 40)) and _has_rect(l_shape_fills, Rect2(40, 40, 40, 40)), "L-shaped fill should not paint its empty upper-right corner")

	group.call("configure", "completion", [Rect2(0, 0, 40, 40), Rect2(40, 0, 40, 40)], 0.9, true)
	group.call("play_sale_complete_feedback")
	group.call("configure", "completion", [Rect2(0, 0, 40, 40), Rect2(40, 0, 40, 40)], 0.0, false)
	var completion_edges_value: Variant = group.get("completion_edge_segments")
	_expect(completion_edges_value is Array and (completion_edges_value as Array).size() == 1, "sold-out refresh should preserve the product-level completion edge")
	_expect(group.visible, "sold-out refresh should keep completion feedback visible")
	await create_timer(0.25).timeout
	_expect(not group.visible, "sold-out product group should hide after its completion pulse")
	group.queue_free()
	await process_frame
	var packed := load(SLOT_SCENE_PATH) as PackedScene
	if packed == null:
		_fail("showcase slot scene should load")
		_finish()
		return
	var slot := packed.instantiate() as Button
	root.add_child(slot)
	await process_frame

	var flash := slot.get_node_or_null("SaleCompleteFlash") as ColorRect
	_expect(slot.get_node_or_null("SaleProgressClip") == null, "slot should no longer own per-cell sale progress clipping")
	_expect(not slot.has_method("set_sale_progress"), "slot should no longer expose per-cell sale progress refresh")
	_expect(not slot.has_method("clear_sale_progress"), "slot should no longer own sale progress clearing")
	_expect(slot.has_method("play_sale_complete_feedback"), "slot should expose confirmed-sale feedback")
	if flash == null or not slot.has_method("play_sale_complete_feedback"):
		slot.queue_free()
		_finish()
		return

	_expect(flash.mouse_filter == Control.MOUSE_FILTER_IGNORE, "sale flash should ignore mouse input")

	var child_count_before_feedback := slot.get_child_count()
	slot.call("play_sale_complete_feedback")
	slot.call("play_sale_complete_feedback")
	_expect(flash.visible, "confirmed sale feedback should show the slot flash immediately")
	_expect(slot.get_child_count() == child_count_before_feedback, "restarting sale feedback should not create duplicate nodes")
	await create_timer(0.25).timeout
	_expect(not flash.visible, "confirmed sale feedback should finish within 0.25 seconds")

	slot.call("clear_product_visual")
	_expect(not flash.visible, "clearing product visuals should hide sale completion flash")
	slot.queue_free()
	await process_frame
	await _test_main_integration()
	_finish()


func _test_main_integration() -> void:
	DirAccess.remove_absolute(_save_path)
	DirAccess.remove_absolute(_save_path + ".broken")
	var view = MAIN.instantiate()
	view.set("save_path", _save_path)
	view.set("broken_save_path", _save_path + ".broken")
	root.add_child(view)
	await process_frame
	if not view.has_method("_refresh_storefront_showcase"):
		_fail("main view script should parse and expose showcase refresh methods")
		view.queue_free()
		await process_frame
		DirAccess.remove_absolute(_save_path)
		DirAccess.remove_absolute(_save_path + ".broken")
		return

	var state = GAME_STATE.new_game()
	state.level = 6
	state.shop_level = 6
	state.coins = 100000
	state.add_recipe("sponge_cake")
	state.add_product("sponge_cake", 3)
	var occupied_cells := [Vector2i(5, 6), Vector2i(5, 7), Vector2i(6, 6), Vector2i(6, 7)]
	_expect(state.list_display_item("sponge_cake", occupied_cells, 2), "fixture should list a four-cell showcase product")
	state.active_business_round = {
		"round_id": state.business_round_id,
		"phase": "running",
		"paused": true,
		"duration_ms": 30000,
		"remaining_ms": 25000,
		"item_states": {
			"sponge_cake": {
				"fresh_stock": 2,
				"carried_stock": 0,
				"duration_ms": 10000,
				"cycle_elapsed_ms": 5000,
				"waiting_for_refill": false,
			}
		}
	}
	view.set("state", state)
	view.call("_refresh_storefront_showcase")
	await process_frame
	await process_frame

	var grid := view.get_node("Root/Body/MainArea/StorefrontPanel/ShowcasePanel/ShowcaseGrid") as GridContainer
	var feedback_layer := view.get_node("ShowcaseFeedbackLayer") as Control
	var progress_groups_value: Variant = view.get("showcase_sale_progress_groups")
	var product_group: Control = null
	_expect(progress_groups_value is Dictionary, "main view should own product-level sale progress groups")
	if progress_groups_value is Dictionary:
		var progress_groups := progress_groups_value as Dictionary
		_expect(progress_groups.size() == 1 and progress_groups.has("sponge_cake"), "one displayed recipe should create exactly one progress group")
		product_group = progress_groups.get("sponge_cake") as Control
		if product_group != null:
			var group_cells: Array = product_group.get("cell_rects")
			var group_fills: Array = product_group.get("fill_rects")
			var group_edges: Array = product_group.get("edge_segments")
			_expect(product_group.get_parent() == feedback_layer, "product progress group should live in the shared feedback layer")
			_expect(group_cells.size() == occupied_cells.size(), "product progress group should use every real occupied cell")
			_expect(group_fills.size() == 2, "two-row product at fifty percent should fill only its lower row")
			_expect(group_edges.size() == 1, "two-column lower row should share one continuous liquid edge")
	for cell in occupied_cells:
		var slot_index := int(view.call("_showcase_slot_index_for_cell", cell))
		var button := grid.get_child(slot_index) as Button
		_expect(button.get_node_or_null("SaleProgressClip") == null, "occupied slots should not retain per-cell progress layers")

	view.call("_show_page", "storefront_manage")
	state.active_business_round["paused"] = false
	view.set("showcase_round_delta_carry_ms", 0.0)
	var before_item: Dictionary = state.active_business_round.get("item_states", {}).get("sponge_cake", {})
	var before_elapsed_ms := int(before_item.get("cycle_elapsed_ms", 0))
	view.call("_process_showcase_business_round_delta", 0.25)
	var progressed_item: Dictionary = state.active_business_round.get("item_states", {}).get("sponge_cake", {})
	var progressed_elapsed_ms := int(progressed_item.get("cycle_elapsed_ms", 0))
	_expect(progressed_elapsed_ms == before_elapsed_ms + 250, "business round fixture should advance by 250ms (%d -> %d)" % [before_elapsed_ms, progressed_elapsed_ms])
	var expected_liquid_y := product_group.size.y * (1.0 - float(progressed_elapsed_ms) / float(int(progressed_item.get("duration_ms", 1)))) if product_group != null else -1.0
	_expect(product_group != null and is_equal_approx(float(product_group.get("liquid_y")), expected_liquid_y), "product-level liquid should follow the business round every frame")

	var empty_index := int(view.call("_showcase_slot_index_for_cell", Vector2i(5, 8)))
	_expect((grid.get_child(empty_index) as Button).get_node_or_null("SaleProgressClip") == null, "neighboring empty slot should not own a progress layer")

	var old_progress_bar_count := 0
	for child in feedback_layer.get_children():
		if String(child.name).begins_with("ShowcaseSaleProgress_"):
			old_progress_bar_count += 1
	_expect(old_progress_bar_count == 0, "legacy showcase sale progress bars should no longer be created")
	_expect(not view.has_method("_refresh_showcase_group_progress_bars"), "legacy group progress refresh should be removed")

	state.active_business_round["phase"] = "adjusting"
	view.call("_refresh_storefront_showcase")
	await process_frame
	_expect(product_group != null and not product_group.visible, "adjusting phase should hide the whole product progress group")

	state.active_business_round = {
		"round_id": state.business_round_id,
		"phase": "running",
		"paused": true,
		"duration_ms": 30000,
		"elapsed_ms": 250,
		"remaining_ms": 29750,
		"sale_terms": {},
		"role_snapshot": {},
		"sale_events": [],
		"applied_sale_event_ids": [],
		"item_states": {
			"sponge_cake": {
				"fresh_stock": 1,
				"carried_stock": 0,
				"duration_ms": 10000,
				"cycle_elapsed_ms": 9999,
				"waiting_for_refill": false,
				"unit_price": 10,
				"anchor_cell": occupied_cells[0],
			}
		}
	}
	view.call("_refresh_storefront_showcase")
	await process_frame
	var sale_events_before := (state.active_business_round.get("sale_events", []) as Array).size()
	state.active_business_round["paused"] = false
	view.call("_advance_showcase_business_round", 1)
	var sale_events_after := (state.active_business_round.get("sale_events", []) as Array).size()
	_expect(sale_events_after == sale_events_before + 1, "one-stock fixture should confirm a sale through the real round path (%d -> %d)" % [sale_events_before, sale_events_after])
	for cell in occupied_cells:
		var button := grid.get_child(int(view.call("_showcase_slot_index_for_cell", cell))) as Button
		_expect((button.get_node("SaleCompleteFlash") as ColorRect).visible, "final-stock sale should flash every occupied cell after sold-out refresh")
	_expect(product_group != null and product_group.visible, "final-stock sale should let the product-level completion pulse finish")
	await create_timer(0.25).timeout
	for cell in occupied_cells:
		var button := grid.get_child(int(view.call("_showcase_slot_index_for_cell", cell))) as Button
		_expect(not (button.get_node("SaleCompleteFlash") as ColorRect).visible, "final-stock sale flash should finish within 0.25 seconds")
	_expect(product_group != null and not product_group.visible, "sold-out product group should hide after completion feedback")

	_expect(view.has_method("_play_showcase_sale_progress_completion"), "main view should expose confirmed-sale cell feedback")
	if view.has_method("_play_showcase_sale_progress_completion"):
		var occupied_indices: Array[int] = []
		for cell in occupied_cells:
			occupied_indices.append(int(view.call("_showcase_slot_index_for_cell", cell)))
		var child_counts := {}
		for slot_index in occupied_indices:
			child_counts[slot_index] = (grid.get_child(slot_index) as Button).get_child_count()
		var event := {"recipe_id": "sponge_cake", "cell_indices": occupied_indices}
		view.call("_play_showcase_sale_progress_completion", event)
		view.call("_play_showcase_sale_progress_completion", event)
		for slot_index in occupied_indices:
			var button := grid.get_child(slot_index) as Button
			_expect((button.get_node("SaleCompleteFlash") as ColorRect).visible, "confirmed sale should flash every occupied cell")
			_expect(button.get_child_count() == int(child_counts.get(slot_index, -1)), "repeated confirmed sale should not create duplicate cell nodes")
		var empty_flash := grid.get_child(empty_index).get_node("SaleCompleteFlash") as ColorRect
		_expect(not empty_flash.visible, "confirmed sale should not flash an unoccupied neighboring cell")
		await create_timer(0.25).timeout
		for slot_index in occupied_indices:
			var button := grid.get_child(slot_index) as Button
			_expect(not (button.get_node("SaleCompleteFlash") as ColorRect).visible, "confirmed sale cell flash should finish within 0.25 seconds")
		view.call("_play_showcase_sale_progress_completion", {"bonus_only": true, "cell_indices": occupied_indices})
		view.call("_play_showcase_sale_progress_completion", {"recipe_id": "sponge_cake", "cell_indices": [-1, grid.get_child_count()]})
		for slot_index in occupied_indices:
			var button := grid.get_child(slot_index) as Button
			_expect(not (button.get_node("SaleCompleteFlash") as ColorRect).visible, "bonus-only and invalid events should not flash product cells")

		var preview_button := grid.get_child(occupied_indices[0]) as Button
		preview_button.set_meta("showcase_preview", true)
		view.call("_play_showcase_sale_progress_completion", {"recipe_id": "sponge_cake", "cell_indices": [occupied_indices[0]]})
		_expect((preview_button.get_node("SaleCompleteFlash") as ColorRect).visible, "same-product stack preview should still show a real confirmed sale")
		preview_button.set_meta("showcase_preview", false)
		await create_timer(0.25).timeout

		var non_product_button := grid.get_child(empty_index) as Button
		non_product_button.set_meta("showcase_preview", true)
		non_product_button.set_meta("recipe_id", "rice_milk_drink")
		view.call("_play_showcase_sale_progress_completion", {"recipe_id": "sponge_cake", "cell_indices": [empty_index]})
		_expect(not (non_product_button.get_node("SaleCompleteFlash") as ColorRect).visible, "unrelated preview cells should ignore product sale feedback")
		non_product_button.set_meta("showcase_preview", false)
		non_product_button.remove_meta("recipe_id")
		non_product_button.set_meta("showcase_prop_id", "fixture_prop")
		view.call("_play_showcase_sale_progress_completion", {"recipe_id": "sponge_cake", "cell_indices": [empty_index]})
		_expect(not (non_product_button.get_node("SaleCompleteFlash") as ColorRect).visible, "prop and empty cells should ignore product sale feedback")
		non_product_button.remove_meta("showcase_prop_id")

		var locked_index := -1
		for slot_index in range(grid.get_child_count()):
			if not bool(view.call("_is_showcase_slot_unlocked", slot_index)):
				locked_index = slot_index
				break
		if locked_index >= 0:
			var locked_button := grid.get_child(locked_index) as Button
			view.call("_play_showcase_sale_progress_completion", {"recipe_id": "sponge_cake", "cell_indices": [locked_index]})
			_expect(not (locked_button.get_node("SaleCompleteFlash") as ColorRect).visible, "locked cells should ignore product sale feedback")

		view.call("_play_showcase_sale_progress_completion", {"recipe_id": "sponge_cake"})
		_expect(not (preview_button.get_node("SaleCompleteFlash") as ColorRect).visible, "events without cell indices should be ignored")
		non_product_button.queue_free()
		view.call("_play_showcase_sale_progress_completion", {"recipe_id": "sponge_cake", "cell_indices": [empty_index]})
		_expect(not (non_product_button.get_node("SaleCompleteFlash") as ColorRect).visible, "queued-for-deletion cells should ignore product sale feedback")

	view.queue_free()
	await process_frame
	DirAccess.remove_absolute(_save_path)
	DirAccess.remove_absolute(_save_path + ".broken")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _has_rect(rects: Array, expected: Rect2) -> bool:
	for rect_value in rects:
		if rect_value is Rect2 and (rect_value as Rect2).is_equal_approx(expected):
			return true
	return false


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("SHOWCASE_SALE_PROGRESS_OVERLAY_SELF_CHECK_PASS")
		quit(0)
		return
	for failure in _failures:
		printerr("SHOWCASE_SALE_PROGRESS_OVERLAY_SELF_CHECK_FAIL: %s" % failure)
	quit(1)
