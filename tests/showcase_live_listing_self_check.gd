extends SceneTree

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const GAME_STATE := preload("res://scripts/game_state.gd")

var _failures: Array[String] = []
var _save_path := OS.get_temp_dir().path_join("showcase_live_listing_self_check.json")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_check_replacement_shape_boundaries()
	var view = MAIN_SCENE.instantiate()
	view.set("save_path", _save_path)
	view.set("broken_save_path", _save_path + ".broken")
	root.add_child(view)
	await process_frame
	await process_frame

	var state = GAME_STATE.new_game()
	state.level = 2
	state.shop_level = 2
	state.add_recipe("sponge_cake")
	state.add_recipe("butter_cookie")
	state.add_recipe("chocolate_cookie")
	state.add_product("butter_cookie", 2)
	state.add_product("chocolate_cookie", 1)
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
	view.call("_refresh_storefront_showcase")
	view.call("_refresh_showcase_round_controls")
	state.active_business_round["live_layout_changed"] = true
	state.active_business_round["live_listing_events"] = [{"recipe_id": "stale_previous_round"}]
	_expect_equal("round starts before live listing", bool(view.call("_start_showcase_business_round")), true)
	_expect_equal("new round clears prior live-layout marker", bool(state.active_business_round.get("live_layout_changed", true)), false)
	_expect_equal("new round clears prior live-listing events", (state.active_business_round.get("live_listing_events", []) as Array).size(), 0)
	state.active_business_round["paused"] = true
	var before_states: Dictionary = state.active_business_round.get("item_states", {})
	var sponge_before: Dictionary = before_states.get("sponge_cake", {}).duplicate(true)
	sponge_before["duration_ms"] = 10000
	sponge_before["cycle_elapsed_ms"] = 5000
	before_states["sponge_cake"] = sponge_before
	state.active_business_round["item_states"] = before_states
	_expect_equal(
		"state mutation rejects a locked live-listing cell",
		state.can_list_display_item_during_round("butter_cookie", [Vector2i(1, 1)], 1, "standard"),
		false
	)

	var listed := bool(view.call("_drop_showcase_data", "showcase", {
		"kind": "inventory_product",
		"recipe_id": "butter_cookie",
		"variant_id": "standard",
		"target_slot_index": 62
	}))
	await process_frame
	_expect_equal("new product can enter an empty showcase cell during business", listed, true)
	if listed:
		_expect_equal("live listing consumes one inventory product", int(state.get_product_count("butter_cookie")), 1)
		_expect_equal("live listing persists the new display item", state.display_items.has("butter_cookie"), true)
		var live_states: Dictionary = state.active_business_round.get("item_states", {})
		var butter_live: Dictionary = live_states.get("butter_cookie", {})
		_expect_equal("new live item joins current round", butter_live.is_empty(), false)
		_expect_equal("new live item starts with one fresh stock", int(butter_live.get("fresh_stock", 0)), 1)
		_expect_equal("new live item starts a full cycle", int(butter_live.get("cycle_elapsed_ms", -1)), 0)
		var sponge_live: Dictionary = live_states.get("sponge_cake", {})
		_expect(int(sponge_live.get("duration_ms", 0)) != 10000, "new adjacent classic product should immediately change the existing sale speed")
		var expected_elapsed := int(round(0.5 * float(int(sponge_live.get("duration_ms", 0)))))
		_expect_equal("existing item preserves its progress ratio after live layout change", int(sponge_live.get("cycle_elapsed_ms", -1)), expected_elapsed)
		_expect_equal("round records a live layout change", bool(state.active_business_round.get("live_layout_changed", false)), true)
		var listing_events: Array = state.active_business_round.get("live_listing_events", [])
		_expect_equal("round records one live listing event", listing_events.size(), 1)
		if not listing_events.is_empty():
			var event_cells: Array = (listing_events[0] as Dictionary).get("cells", [])
			_expect(
				not event_cells.is_empty() and event_cells[0] is Array,
				"live-listing event cells should use save-safe [row, col] arrays"
			)
		_expect_equal("current sale terms include the new product", (state.active_business_round.get("sale_terms", {}) as Dictionary).has("butter_cookie"), true)
		_expect_equal("current role snapshot includes the new product", (state.active_business_round.get("role_snapshot", {}) as Dictionary).has("butter_cookie"), true)
		_expect_equal("live listing creates a visible green product pulse", _has_feedback_role(view.get_node("ShowcaseFeedbackLayer"), "restock"), true)
		_expect_equal("live listing badge confirms success", _anchor_badge_text(view, "butter_cookie"), "上新成功")
		var summary := view.get_node("Root/Body/MainArea/StorefrontPanel/ShowcasePanel/ShowcasePulseSummary") as Label
		_expect(summary.text.find("可售库存 2") >= 0, "live summary should use current-round stock after listing")

		butter_live["cycle_elapsed_ms"] = mini(1000, maxi(0, int(butter_live.get("duration_ms", 1)) - 1))
		live_states["butter_cookie"] = butter_live
		state.active_business_round["item_states"] = live_states
		var progress_before_refill := int(butter_live.get("cycle_elapsed_ms", 0))
		var refilled := bool(view.call("_drop_showcase_data", "showcase", {
			"kind": "inventory_product",
			"recipe_id": "butter_cookie",
			"variant_id": "standard",
			"target_slot_index": 62
		}))
		await process_frame
		_expect_equal("existing same product can be refilled during business", refilled, true)
		if refilled:
			var refilled_butter: Dictionary = (state.active_business_round.get("item_states", {}) as Dictionary).get("butter_cookie", {})
			_expect_equal("same-product refill consumes remaining inventory", int(state.get_product_count("butter_cookie")), 0)
			_expect_equal("same-product refill increases current fresh stock", int(refilled_butter.get("fresh_stock", 0)), 2)
			_expect_equal("active same-product refill preserves sale progress", int(refilled_butter.get("cycle_elapsed_ms", -1)), progress_before_refill)
			_expect_equal("refill badge confirms the amount", _anchor_badge_text(view, "butter_cookie"), "补货 +1")
			_expect(summary.text.find("可售库存 3") >= 0, "live summary should update after same-product refill")
			await create_timer(0.55).timeout
			state.add_product("butter_cookie", 1)
			var refilled_again := bool(view.call("_drop_showcase_data", "showcase", {
				"kind": "inventory_product",
				"recipe_id": "butter_cookie",
				"variant_id": "standard",
				"target_slot_index": 62
			}))
			await process_frame
			_expect_equal("a second same-product refill succeeds", refilled_again, true)
			_expect_equal("second refill restarts the visible badge", _anchor_badge_text(view, "butter_cookie"), "补货 +1")
			await create_timer(0.70).timeout
			_expect_equal("the first timer cannot clear the newer refill badge", _anchor_badge_text(view, "butter_cookie"), "补货 +1")
			await create_timer(0.60).timeout
			_expect(_anchor_badge_text(view, "butter_cookie") != "补货 +1", "the newest refill badge should restore after its own timer")

		var status_label := view.get_node("Root/StatusBar/StatusLabel") as Label
		var moved_existing := bool(view.call("_drop_showcase_data", "showcase", {
			"kind": "showcase_product",
			"recipe_id": "butter_cookie",
			"variant_id": "standard",
			"target_slot_index": 63
		}))
		_expect_equal("existing product cannot move during business", moved_existing, false)
		_expect(status_label.text.find("不能移动已有商品") >= 0, "blocked live move should explain the exact reason")
		var locked_listing := bool(view.call("_drop_showcase_data", "showcase", {
			"kind": "inventory_product",
			"recipe_id": "butter_cookie",
			"variant_id": "standard",
			"target_slot_index": 0
		}))
		_expect_equal("same product still routes to refill instead of locked new placement", locked_listing, false)
		_expect(status_label.text.find("库存不足") >= 0, "failed refill should expose inventory shortage")
		await create_timer(0.60).timeout
		_expect_equal("restock pulse releases after visible feedback", _has_feedback_role(view.get_node("ShowcaseFeedbackLayer"), "restock"), false)

		_expect(state.has_method("is_display_item_sold_out_during_round"), "GameState should expose the live sold-out predicate")
		_expect(state.has_method("replace_sold_out_display_item_during_round"), "GameState should expose atomic live replacement")
		_expect(state.has_method("unlist_sold_out_display_item_during_round"), "GameState should expose live sold-out removal")
		_expect(view.has_method("_finish_showcase_product_drag"), "Main should resolve sold-out drag completion")
		if state.has_method("is_display_item_sold_out_during_round") \
				and state.has_method("replace_sold_out_display_item_during_round") \
				and state.has_method("unlist_sold_out_display_item_during_round") \
				and view.has_method("_finish_showcase_product_drag"):
			var sold_out_states: Dictionary = state.active_business_round.get("item_states", {})
			var sold_out_butter: Dictionary = sold_out_states.get("butter_cookie", {}).duplicate(true)
			sold_out_butter["fresh_stock"] = 0
			sold_out_butter["carried_stock"] = 0
			sold_out_butter["waiting_for_refill"] = true
			sold_out_states["butter_cookie"] = sold_out_butter
			state.active_business_round["item_states"] = sold_out_states
			var butter_display: Dictionary = state.display_items.get("butter_cookie", {}).duplicate(true)
			butter_display["fresh_stock"] = 0
			butter_display["carried_stock"] = 0
			butter_display["stock"] = 0
			state.display_items["butter_cookie"] = butter_display
			state.active_business_round["sale_events"] = [{"event_id": "prior-butter-sale", "recipe_id": "butter_cookie", "quantity": 1}]
			view.call("_refresh_storefront_showcase")
			await process_frame

			_expect_equal("butter is sold out in the active round", bool(state.call("is_display_item_sold_out_during_round", "butter_cookie")), true)
			_expect_equal("sponge remains active in the active round", bool(state.call("is_display_item_sold_out_during_round", "sponge_cake")), false)
			var grid := view.get_node("Root/Body/MainArea/StorefrontPanel/ShowcasePanel/ShowcaseGrid") as GridContainer
			var butter_anchor := int(view.call("_display_anchor_slot_index_for_recipe", "butter_cookie"))
			var sponge_anchor := int(view.call("_display_anchor_slot_index_for_recipe", "sponge_cake"))
			_expect(not (grid.get_child(butter_anchor).get("drag_data") as Dictionary).is_empty(), "sold-out live product should remain draggable")
			_expect((grid.get_child(sponge_anchor).get("drag_data") as Dictionary).is_empty(), "in-stock live product should not be draggable")

			var display_before_failed_replace: Dictionary = state.display_items.duplicate(true)
			var inventory_before_failed_replace: Dictionary = state.product_inventory.duplicate(true)
			var failed_replace := bool(state.call(
				"replace_sold_out_display_item_during_round",
				"butter_cookie",
				"chocolate_cookie",
				[Vector2i(5, 5)],
				1,
				"standard",
				12
			))
			_expect_equal("replacement cannot cover an in-stock product", failed_replace, false)
			_expect_equal("failed replacement preserves display layout", state.display_items, display_before_failed_replace)
			_expect_equal("failed replacement preserves inventory", state.product_inventory, inventory_before_failed_replace)

			var replace_drag := {
				"kind": "inventory_product",
				"recipe_id": "chocolate_cookie",
				"variant_id": "standard",
				"target_slot_index": butter_anchor
			}
			_expect_equal("inventory product can target one sold-out occupied cell", bool(view.call("_can_drop_showcase_data", "showcase", replace_drag)), true)
			_expect_equal("sold-out occupied target uses replacement preview", String(view.get("showcase_drag_preview_mode")), "replace")
			var sponge_state_before_replace: Dictionary = (state.active_business_round.get("item_states", {}) as Dictionary).get("sponge_cake", {}).duplicate(true)
			var replaced := bool(view.call("_drop_showcase_data", "showcase", replace_drag))
			await process_frame
			_expect_equal("sold-out occupied cell accepts atomic replacement", replaced, true)
			_expect_equal("replacement removes the sold-out display item", state.display_items.has("butter_cookie"), false)
			_expect_equal("replacement places the new display item", state.display_items.has("chocolate_cookie"), true)
			_expect_equal("replacement consumes one new product", int(state.get_product_count("chocolate_cookie")), 0)
			_expect_equal("replacement clears the drag preview", String(view.get("showcase_drag_preview_mode")), "")
			var states_after_replace: Dictionary = state.active_business_round.get("item_states", {})
			_expect_equal("replacement removes old round state", states_after_replace.has("butter_cookie"), false)
			_expect_equal("replacement adds new round state", states_after_replace.has("chocolate_cookie"), true)
			var sponge_after_replace: Dictionary = states_after_replace.get("sponge_cake", {})
			var old_duration := maxi(1, int(sponge_state_before_replace.get("duration_ms", 1)))
			var new_duration := maxi(1, int(sponge_after_replace.get("duration_ms", 1)))
			var expected_progress := float(int(sponge_state_before_replace.get("cycle_elapsed_ms", 0))) / float(old_duration)
			var actual_progress := float(int(sponge_after_replace.get("cycle_elapsed_ms", 0))) / float(new_duration)
			_expect(absf(actual_progress - expected_progress) <= 0.02, "replacement should preserve unaffected sale progress ratio")
			_expect_equal("replacement preserves prior sale events", (state.active_business_round.get("sale_events", []) as Array).size(), 1)
			var layout_events: Array = state.active_business_round.get("live_listing_events", [])
			var replace_event: Dictionary = layout_events.back() if not layout_events.is_empty() else {}
			_expect_equal("replacement records its layout event kind", String(replace_event.get("kind", "")), "replace")
			_expect_equal("replacement event records removed product", String(replace_event.get("replaced_recipe_id", "")), "butter_cookie")
			_expect_equal("replacement badge confirms the action", _anchor_badge_text(view, "chocolate_cookie"), "替换上架")
			_expect(status_label.text.find("营业中替换") >= 0, "replacement should show explicit status feedback")

			var chocolate_states: Dictionary = state.active_business_round.get("item_states", {})
			var sold_out_chocolate: Dictionary = chocolate_states.get("chocolate_cookie", {}).duplicate(true)
			sold_out_chocolate["fresh_stock"] = 0
			sold_out_chocolate["carried_stock"] = 0
			sold_out_chocolate["waiting_for_refill"] = true
			chocolate_states["chocolate_cookie"] = sold_out_chocolate
			state.active_business_round["item_states"] = chocolate_states
			var chocolate_display: Dictionary = state.display_items.get("chocolate_cookie", {}).duplicate(true)
			chocolate_display["fresh_stock"] = 0
			chocolate_display["carried_stock"] = 0
			chocolate_display["stock"] = 0
			state.display_items["chocolate_cookie"] = chocolate_display
			view.call("_refresh_storefront_showcase")
			await process_frame
			var grid_center := grid.get_global_rect().get_center()
			_expect_equal("successful drag does not unlist sold-out product", bool(view.call("_finish_showcase_product_drag", "chocolate_cookie", true, Vector2(-100, -100))), false)
			_expect_equal("invalid drop inside showcase does not unlist sold-out product", bool(view.call("_finish_showcase_product_drag", "chocolate_cookie", false, grid_center)), false)
			_expect_equal("inside invalid drop preserves sold-out product", state.display_items.has("chocolate_cookie"), true)
			_expect_equal("failed drag outside showcase unlists sold-out product", bool(view.call("_finish_showcase_product_drag", "chocolate_cookie", false, Vector2(-100, -100))), true)
			_expect_equal("drag-out removal frees display item", state.display_items.has("chocolate_cookie"), false)
			_expect_equal("drag-out removal clears round item state", (state.active_business_round.get("item_states", {}) as Dictionary).has("chocolate_cookie"), false)
			_expect_equal("drag-out removal preserves prior sale events", (state.active_business_round.get("sale_events", []) as Array).size(), 1)
			layout_events = state.active_business_round.get("live_listing_events", [])
			var unlist_event: Dictionary = layout_events.back() if not layout_events.is_empty() else {}
			_expect_equal("drag-out removal records its layout event kind", String(unlist_event.get("kind", "")), "unlist")
			_expect_equal("drag-out removal records removed product", String(unlist_event.get("recipe_id", "")), "chocolate_cookie")
			_expect(status_label.text.find("营业中下架") >= 0, "drag-out removal should show explicit status feedback")

	_finish(view)


func _check_replacement_shape_boundaries() -> void:
	var replacement_state = GAME_STATE.new_game()
	replacement_state.level = 2
	replacement_state.shop_level = 2
	replacement_state.add_recipe("rice_milk_drink")
	replacement_state.add_recipe("butter_cookie")
	replacement_state.add_recipe("chocolate_cookie")
	replacement_state.add_product("rice_milk_drink", 1)
	replacement_state.display_items = {
		"butter_cookie": {
			"cells": [Vector2i(5, 7)],
			"fresh_stock": 0,
			"carried_stock": 0,
			"stock": 0,
			"variant_id": "standard"
		},
		"chocolate_cookie": {
			"cells": [Vector2i(6, 7)],
			"fresh_stock": 0,
			"carried_stock": 0,
			"stock": 0,
			"variant_id": "standard"
		}
	}
	replacement_state.active_business_round = {
		"phase": "running",
		"item_states": {
			"butter_cookie": {"fresh_stock": 0, "carried_stock": 0, "waiting_for_refill": true},
			"chocolate_cookie": {"fresh_stock": 0, "carried_stock": 0, "waiting_for_refill": true}
		}
	}
	var inconsistent_states: Dictionary = replacement_state.active_business_round.get("item_states", {})
	var inconsistent_butter: Dictionary = inconsistent_states.get("butter_cookie", {}).duplicate(true)
	inconsistent_butter["waiting_for_refill"] = false
	inconsistent_states["butter_cookie"] = inconsistent_butter
	replacement_state.active_business_round["item_states"] = inconsistent_states
	_expect_equal(
		"zero stock without waiting state is not eligible for live removal",
		bool(replacement_state.call("is_display_item_sold_out_during_round", "butter_cookie")),
		false
	)
	inconsistent_butter["waiting_for_refill"] = true
	inconsistent_states["butter_cookie"] = inconsistent_butter
	replacement_state.active_business_round["item_states"] = inconsistent_states
	var replacement_cells := [Vector2i(5, 7), Vector2i(6, 7)]
	_expect_equal(
		"one replacement cannot cover two sold-out products",
		bool(replacement_state.call("can_replace_display_item_during_round", "butter_cookie", "rice_milk_drink", replacement_cells, 1, "standard")),
		false
	)
	replacement_state.display_items.erase("chocolate_cookie")
	var item_states: Dictionary = replacement_state.active_business_round.get("item_states", {})
	item_states.erase("chocolate_cookie")
	replacement_state.active_business_round["item_states"] = item_states
	replacement_state.display_props = {
		"cake_stand": {"prop_id": "cake_stand", "cells": [Vector2i(6, 7)]}
	}
	_expect_equal(
		"replacement cannot extend into a display prop",
		bool(replacement_state.call("can_replace_display_item_during_round", "butter_cookie", "rice_milk_drink", replacement_cells, 1, "standard")),
		false
	)
	replacement_state.display_props = {}
	var butter_display: Dictionary = replacement_state.display_items.get("butter_cookie", {}).duplicate(true)
	butter_display["cells"] = [Vector2i(1, 1)]
	replacement_state.display_items["butter_cookie"] = butter_display
	_expect_equal(
		"replacement cannot use locked showcase cells",
		bool(replacement_state.call("can_replace_display_item_during_round", "butter_cookie", "rice_milk_drink", [Vector2i(1, 1), Vector2i(2, 1)], 1, "standard")),
		false
	)
	butter_display["cells"] = [Vector2i(5, 7)]
	replacement_state.display_items["butter_cookie"] = butter_display
	_expect_equal(
		"replacement shape may extend from sold-out cells into adjacent empty cells",
		bool(replacement_state.call("can_replace_display_item_during_round", "butter_cookie", "rice_milk_drink", replacement_cells, 1, "standard")),
		true
	)


func _anchor_badge_text(view: Node, recipe_id: String) -> String:
	var anchor_slot := int(view.call("_display_anchor_slot_index_for_recipe", recipe_id))
	var grid := view.get_node("Root/Body/MainArea/StorefrontPanel/ShowcasePanel/ShowcaseGrid") as GridContainer
	if anchor_slot < 0 or anchor_slot >= grid.get_child_count():
		return ""
	var badge := grid.get_child(anchor_slot).get_node_or_null("StatusBadge") as Label
	return badge.text if badge != null and badge.visible else ""


func _find_descendant_with_meta(node: Node, key: String, expected: Variant) -> Node:
	if node == null:
		return null
	if node.has_meta(key) and node.get_meta(key) == expected:
		return node
	for child in node.get_children():
		var found := _find_descendant_with_meta(child, key, expected)
		if found != null:
			return found
	return null


func _has_feedback_role(node: Node, role: String) -> bool:
	return _find_descendant_with_meta(node, "showcase_feedback_role", role) != null


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
		print("SHOWCASE_LIVE_LISTING_SELF_CHECK_PASS")
		quit(0)
	else:
		for failure in _failures:
			printerr("SHOWCASE_LIVE_LISTING_SELF_CHECK_FAIL: %s" % failure)
		quit(1)
