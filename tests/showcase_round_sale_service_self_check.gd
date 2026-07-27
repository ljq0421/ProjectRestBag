extends SceneTree

const SERVICE_PATH := "res://scripts/showcase_round_sale_service.gd"

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	if not ResourceLoader.exists(SERVICE_PATH):
		_fail("ShowcaseRoundSaleService should exist")
		_finish()
		return
	var service := load(SERVICE_PATH)
	if service == null or not service.has_method("advance"):
		_fail("ShowcaseRoundSaleService should expose advance")
		_finish()
		return

	var item_states := {
		"slow_item": {
			"recipe_id": "slow_item",
			"anchor_cell": Vector2i(5, 5),
			"duration_ms": 15000,
			"cycle_elapsed_ms": 0,
			"fresh_stock": 3,
			"carried_stock": 0,
			"unit_price": 100,
			"waiting_for_refill": false
		}
	}
	var result: Dictionary = service.advance(item_states, 0, 30000)
	var events: Array = result.get("events", [])
	_expect_equal("fifteen second event count", events.size(), 2)
	if events.size() == 2:
		_expect_equal("first completion", int((events[0] as Dictionary).get("completed_at_ms", 0)), 15000)
		_expect_equal("second completion", int((events[1] as Dictionary).get("completed_at_ms", 0)), 30000)
		_expect_equal("first event price", int((events[0] as Dictionary).get("earned_coins", 0)), 100)
	var next_states: Dictionary = result.get("item_states", {})
	var slow_state: Dictionary = next_states.get("slow_item", {})
	_expect_equal("remaining fresh stock", int(slow_state.get("fresh_stock", 0)), 1)
	_expect_equal("cycle restarts at exact boundary", int(slow_state.get("cycle_elapsed_ms", -1)), 0)

	var mixed_result: Dictionary = service.advance({
		"mixed_item": {
			"recipe_id": "mixed_item",
			"anchor_cell": Vector2i(5, 6),
			"duration_ms": 10000,
			"cycle_elapsed_ms": 0,
			"fresh_stock": 2,
			"carried_stock": 1,
			"unit_price": 101,
			"waiting_for_refill": false
		}
	}, 0, 20000)
	var mixed_events: Array = mixed_result.get("events", [])
	_expect_equal("mixed batch event count", mixed_events.size(), 2)
	if mixed_events.size() == 2:
		_expect_equal("carried batch sells first", String((mixed_events[0] as Dictionary).get("batch", "")), "carried")
		_expect_equal("carried batch uses eighty percent", int((mixed_events[0] as Dictionary).get("earned_coins", 0)), 80)
		_expect_equal("fresh batch sells second", String((mixed_events[1] as Dictionary).get("batch", "")), "fresh")
		_expect_equal("fresh batch keeps full price", int((mixed_events[1] as Dictionary).get("earned_coins", 0)), 101)
	var mixed_state: Dictionary = (mixed_result.get("item_states", {}) as Dictionary).get("mixed_item", {})
	_expect_equal("carried stock consumed", int(mixed_state.get("carried_stock", -1)), 0)
	_expect_equal("fresh stock remaining after mixed sales", int(mixed_state.get("fresh_stock", -1)), 1)

	if not service.has_method("refill_item"):
		_fail("ShowcaseRoundSaleService should expose refill_item")
	else:
		_expect_equal("display capacity helper is removed", service.has_method("display_capacity"), false)
		var sold_out_result: Dictionary = service.advance({
			"fast_item": {
				"recipe_id": "fast_item",
				"anchor_cell": Vector2i(5, 7),
				"duration_ms": 5000,
				"cycle_elapsed_ms": 0,
				"fresh_stock": 1,
				"carried_stock": 0,
				"unit_price": 20,
				"waiting_for_refill": false
			}
		}, 0, 10000)
		_expect_equal("sold out only completes real stock", (sold_out_result.get("events", []) as Array).size(), 1)
		var sold_out_states: Dictionary = sold_out_result.get("item_states", {})
		var sold_out_state: Dictionary = sold_out_states.get("fast_item", {})
		_expect_equal("sold out waits for refill", bool(sold_out_state.get("waiting_for_refill", false)), true)
		_expect_equal("sold out cycle resets", int(sold_out_state.get("cycle_elapsed_ms", -1)), 0)

		var refill_result: Dictionary = service.refill_item(sold_out_states, "fast_item", 2, 10000)
		var refilled_states: Dictionary = refill_result.get("item_states", {})
		var refilled_state: Dictionary = refilled_states.get("fast_item", {})
		_expect_equal("refill adds fresh stock", int(refilled_state.get("fresh_stock", 0)), 2)
		_expect_equal("refill resumes waiting item", bool(refilled_state.get("waiting_for_refill", true)), false)
		_expect_equal("waiting refill starts full cycle", int(refilled_state.get("cycle_elapsed_ms", -1)), 0)
		_expect_equal("refill event timestamp", int((refill_result.get("refill_event", {}) as Dictionary).get("elapsed_ms", -1)), 10000)
		_expect_equal("refilled item completes after full cycle", (service.advance(refilled_states, 10000, 15000).get("events", []) as Array).size(), 1)

		var active_refill: Dictionary = service.refill_item({
			"active_item": {
				"recipe_id": "active_item",
				"duration_ms": 5000,
				"cycle_elapsed_ms": 3000,
				"fresh_stock": 1,
				"carried_stock": 0,
				"waiting_for_refill": false
			}
		}, "active_item", 2, 12000)
		var active_state: Dictionary = (active_refill.get("item_states", {}) as Dictionary).get("active_item", {})
		_expect_equal("active refill preserves progress", int(active_state.get("cycle_elapsed_ms", 0)), 3000)
		_expect_equal("active refill adds stock", int(active_state.get("fresh_stock", 0)), 3)
		var legacy_capacity_refill: Dictionary = service.refill_item({
			"active_item": {
				"fresh_stock": 2,
				"carried_stock": 0,
				"display_capacity": 3,
				"waiting_for_refill": false
			}
		}, "active_item", 4, 13000)
		var legacy_capacity_state: Dictionary = (legacy_capacity_refill.get("item_states", {}) as Dictionary).get("active_item", {})
		_expect_equal("legacy capacity does not cap refill", int(legacy_capacity_refill.get("accepted_amount", -1)), 4)
		_expect_equal("unlimited refill rejects nothing", int(legacy_capacity_refill.get("rejected_amount", -1)), 0)
		_expect_equal("unlimited refill adds the full amount", int(legacy_capacity_state.get("fresh_stock", -1)), 6)
		_expect_equal("unlimited refill records the full amount", int((legacy_capacity_refill.get("refill_event", {}) as Dictionary).get("amount", -1)), 4)

	var simultaneous: Dictionary = service.advance({
		"z_later_anchor": _sale_item("z_later_anchor", Vector2i(6, 5)),
		"z_same_anchor": _sale_item("z_same_anchor", Vector2i(5, 8)),
		"a_same_anchor": _sale_item("a_same_anchor", Vector2i(5, 8)),
		"m_earlier_anchor": _sale_item("m_earlier_anchor", Vector2i(5, 7))
	}, 0, 5000)
	var simultaneous_events: Array = simultaneous.get("events", [])
	_expect_equal("simultaneous event count", simultaneous_events.size(), 4)
	if simultaneous_events.size() == 4:
		_expect_equal("earlier anchor resolves first", String((simultaneous_events[0] as Dictionary).get("recipe_id", "")), "m_earlier_anchor")
		_expect_equal("same anchor uses recipe id tie break", String((simultaneous_events[1] as Dictionary).get("recipe_id", "")), "a_same_anchor")
		_expect_equal("same anchor later id follows", String((simultaneous_events[2] as Dictionary).get("recipe_id", "")), "z_same_anchor")
		_expect_equal("later row resolves last", String((simultaneous_events[3] as Dictionary).get("recipe_id", "")), "z_later_anchor")

	if not service.has_method("build_item_states"):
		_fail("ShowcaseRoundSaleService should expose build_item_states")
	else:
		var built: Dictionary = service.build_item_states({
			"configured_item": {
				"cells": [Vector2i(6, 6), Vector2i(5, 6)],
				"fresh_stock": 2,
				"carried_stock": 1
			},
			"waiting_item": {
				"cells": [Vector2i(7, 7)],
				"fresh_stock": 0,
				"carried_stock": 0
			}
		}, {
			"configured_item": {"duration_seconds": 10, "unit_price": 33},
			"waiting_item": {"duration_seconds": 5, "unit_price": 12}
		})
		var configured: Dictionary = built.get("configured_item", {})
		_expect_equal("built duration uses milliseconds", int(configured.get("duration_ms", 0)), 10000)
		_expect_equal("built anchor uses lowest cell", configured.get("anchor_cell", Vector2i.ZERO), Vector2i(5, 6))
		_expect_equal("built fresh stock", int(configured.get("fresh_stock", 0)), 2)
		_expect_equal("built carried stock", int(configured.get("carried_stock", 0)), 1)
		_expect_equal("built state omits display capacity", configured.has("display_capacity"), false)
		var waiting: Dictionary = built.get("waiting_item", {})
		_expect_equal("zero stock builds waiting state", bool(waiting.get("waiting_for_refill", false)), true)
	_expect_live_layout_merge(service)
	_finish()


func _expect_live_layout_merge(service: Script) -> void:
	if not service.has_method("merge_live_layout_states"):
		_fail("ShowcaseRoundSaleService should expose merge_live_layout_states")
		return
	var merged: Dictionary = service.call("merge_live_layout_states", {
		"existing": {
			"recipe_id": "existing",
			"duration_ms": 10000,
			"cycle_elapsed_ms": 5000,
			"fresh_stock": 2,
			"carried_stock": 1,
			"waiting_for_refill": false
		},
		"waiting": {
			"recipe_id": "waiting",
			"duration_ms": 8000,
			"cycle_elapsed_ms": 0,
			"fresh_stock": 0,
			"carried_stock": 0,
			"waiting_for_refill": true
		}
	}, {
		"existing": {"recipe_id": "existing", "duration_ms": 6000, "cycle_elapsed_ms": 0, "fresh_stock": 99, "carried_stock": 0, "unit_price": 40},
		"waiting": {"recipe_id": "waiting", "duration_ms": 4000, "cycle_elapsed_ms": 0, "fresh_stock": 99, "carried_stock": 0, "unit_price": 20},
		"new_item": {"recipe_id": "new_item", "duration_ms": 7000, "cycle_elapsed_ms": 0, "fresh_stock": 1, "carried_stock": 0, "unit_price": 30}
	})
	var existing: Dictionary = merged.get("existing", {})
	_expect_equal("live retime preserves existing fresh stock", int(existing.get("fresh_stock", 0)), 2)
	_expect_equal("live retime preserves existing carried stock", int(existing.get("carried_stock", 0)), 1)
	_expect_equal("live retime preserves fifty-percent progress", int(existing.get("cycle_elapsed_ms", 0)), 3000)
	_expect_equal("live retime applies new duration", int(existing.get("duration_ms", 0)), 6000)
	_expect_equal("live retime applies new price", int(existing.get("unit_price", 0)), 40)
	var waiting: Dictionary = merged.get("waiting", {})
	_expect_equal("sold-out item stays empty after live retime", int(waiting.get("fresh_stock", -1)), 0)
	_expect_equal("sold-out item keeps waiting after live retime", bool(waiting.get("waiting_for_refill", false)), true)
	var new_item: Dictionary = merged.get("new_item", {})
	_expect_equal("new live item starts with one fresh stock", int(new_item.get("fresh_stock", 0)), 1)
	_expect_equal("new live item starts at zero progress", int(new_item.get("cycle_elapsed_ms", -1)), 0)


func _sale_item(recipe_id: String, anchor_cell: Vector2i) -> Dictionary:
	return {
		"recipe_id": recipe_id,
		"anchor_cell": anchor_cell,
		"duration_ms": 5000,
		"cycle_elapsed_ms": 0,
		"fresh_stock": 1,
		"carried_stock": 0,
		"unit_price": 10,
		"waiting_for_refill": false
	}


func _expect_equal(label: String, actual: Variant, expected: Variant) -> void:
	if actual != expected:
		_fail("%s expected %s, got %s" % [label, expected, actual])


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("SHOWCASE_ROUND_SALE_SERVICE_SELF_CHECK_PASS")
		quit(0)
	else:
		for failure in _failures:
			printerr("SHOWCASE_ROUND_SALE_SERVICE_SELF_CHECK_FAIL: %s" % failure)
		quit(1)
