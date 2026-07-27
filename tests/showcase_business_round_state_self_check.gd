extends SceneTree

const GAME_STATE := preload("res://scripts/game_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	var state = GAME_STATE.new_game()
	for property_name in [
		"showcase_seed",
		"business_round_id",
		"active_business_round",
		"pending_showcase_settlement",
		"recent_showcase_round_reports",
		"applied_showcase_settlement_ids"
	]:
		if not _has_property(state, property_name):
			_fail("GameState should expose %s" % property_name)
	if not _failures.is_empty():
		_finish()
		return
	_expect_equal("new round id", int(state.business_round_id), 1)
	_expect_equal("new game has persistent showcase seed", int(state.showcase_seed) > 0, true)
	_expect_equal("new active round", state.get("active_business_round"), {})
	_expect_equal("new pending settlement", state.get("pending_showcase_settlement"), {})
	_expect_equal("new round reports", state.get("recent_showcase_round_reports"), [])
	_expect_equal("new applied settlement ids", state.get("applied_showcase_settlement_ids"), [])

	state.business_round_id = 4
	state.showcase_seed = 987654
	state.active_business_round = {
		"round_id": 4,
		"phase": "running",
		"duration_ms": 30000,
		"elapsed_ms": 12500,
		"remaining_ms": 17500,
		"heat": 12,
		"item_states": {
			"tea": {
				"fresh_stock": 2,
				"carried_stock": 1,
				"cycle_elapsed_ms": 2500
			}
		}
	}
	state.pending_showcase_settlement = {"settlement_id": "round:3"}
	state.recent_showcase_round_reports = [{"round_id": 2, "total_coins": 80}]
	state.applied_showcase_settlement_ids.clear()
	state.applied_showcase_settlement_ids.append("round:1")
	state.applied_showcase_settlement_ids.append("round:2")
	var restored = GAME_STATE.from_dict(state.to_dict())
	_expect_equal("restored round id", int(restored.business_round_id), 4)
	_expect_equal("restored showcase seed", int(restored.showcase_seed), 987654)
	_expect_equal("restored active phase", String(restored.active_business_round.get("phase", "")), "running")
	_expect_equal("restored elapsed", int(restored.active_business_round.get("elapsed_ms", 0)), 12500)
	_expect_equal("restored item fresh stock", int((restored.active_business_round.get("item_states", {}).get("tea", {}) as Dictionary).get("fresh_stock", 0)), 2)
	_expect_equal("restored pending settlement", String(restored.pending_showcase_settlement.get("settlement_id", "")), "round:3")
	_expect_equal("restored round report", int((restored.recent_showcase_round_reports[0] as Dictionary).get("round_id", 0)), 2)
	_expect_equal("restored applied ids", restored.applied_showcase_settlement_ids, ["round:1", "round:2"])

	var migrated = GAME_STATE.from_dict({
		"display_items": {
			"sponge_cake": {
				"cells": [[5, 5], [5, 6], [6, 5], [6, 6]],
				"stock": 3
			}
		}
	})
	var migrated_item: Dictionary = migrated.display_items.get("sponge_cake", {})
	_expect_equal("legacy stock becomes fresh batch", int(migrated_item.get("fresh_stock", 0)), 3)
	_expect_equal("legacy stock has no carried batch", int(migrated_item.get("carried_stock", -1)), 0)

	var batch_loaded = GAME_STATE.from_dict({
		"display_items": {
			"sponge_cake": {
				"cells": [[5, 5], [5, 6], [6, 5], [6, 6]],
				"fresh_stock": 2,
				"carried_stock": 1
			}
		}
	})
	var batch_round_trip = GAME_STATE.from_dict(batch_loaded.to_dict())
	var batch_item: Dictionary = batch_round_trip.display_items.get("sponge_cake", {})
	_expect_equal("fresh batch round trips", int(batch_item.get("fresh_stock", 0)), 2)
	_expect_equal("carried batch round trips", int(batch_item.get("carried_stock", 0)), 1)

	if not state.has_method("apply_showcase_round_sale") or not state.has_method("apply_showcase_round_settlement"):
		_fail("GameState should expose atomic showcase round application methods")
	else:
		state.level = 2
		state.shop_level = 2
		state.add_recipe("sponge_cake")
		state.display_items = {
			"sponge_cake": {
				"cells": [Vector2i(5, 5), Vector2i(5, 6), Vector2i(6, 5), Vector2i(6, 6)],
				"fresh_stock": 1,
				"carried_stock": 0,
				"stock": 1,
				"variant_id": "standard"
			}
		}
		state.active_business_round = {
			"round_id": 4,
			"phase": "running",
			"applied_sale_event_ids": []
		}
		_expect_equal("GameState rejects layout moves during business", bool(state.place_display_item("sponge_cake", [Vector2i(6, 6)])), false)
		_expect_equal("GameState rejects layout removal during business", bool(state.remove_display_item("sponge_cake")), false)
		var coins_before_sale := int(state.coins)
		var sale_event := {
			"event_id": "4:sponge_cake:1",
			"recipe_id": "sponge_cake",
			"quantity": 1,
			"earned_coins": 20,
			"earned_reputation": 1,
			"unit_price": 20,
			"batch": "fresh",
			"reasons": []
		}
		_expect_equal("first sale applies", bool(state.apply_showcase_round_sale(sale_event)), true)
		_expect_equal("sale credits coins", int(state.coins), coins_before_sale + 20)
		_expect_equal("sale does not count as business day", int(state.business_runs), 0)
		_expect_equal("duplicate sale rejected", bool(state.apply_showcase_round_sale(sale_event)), false)
		_expect_equal("duplicate sale does not credit coins", int(state.coins), coins_before_sale + 20)

		state.pending_showcase_settlement = {"settlement_id": "round:4"}
		var settlement_result := {
			"ok": true,
			"settlement_id": "round:4",
			"earned_coins": 74,
			"round_report": {"round_id": 4, "total_coins": 94, "is_complete": true, "missing_fields": []},
			"item_states": {
				"sponge_cake": {
					"fresh_stock": 0,
					"carried_stock": 2,
					"waiting_for_refill": false
				}
			}
		}
		_expect_equal("first settlement applies", bool(state.apply_showcase_round_settlement(settlement_result)), true)
		_expect_equal("settlement credits coins", int(state.coins), coins_before_sale + 94)
		_expect_equal("settlement counts one business day", int(state.business_runs), 1)
		_expect_equal("settlement stores the completed round report", int((state.recent_showcase_round_reports.back() as Dictionary).get("round_id", 0)), 4)
		_expect_equal("settlement updates carried batch", int((state.display_items.get("sponge_cake", {}) as Dictionary).get("carried_stock", 0)), 2)
		_expect_equal("settlement preserves layout cells", (state.display_items.get("sponge_cake", {}) as Dictionary).get("cells", []), [Vector2i(5, 5), Vector2i(5, 6), Vector2i(6, 5), Vector2i(6, 6)])
		_expect_equal("duplicate settlement rejected", bool(state.apply_showcase_round_settlement(settlement_result)), false)
		_expect_equal("duplicate settlement does not credit coins", int(state.coins), coins_before_sale + 94)
		_expect_equal("duplicate settlement does not count day", int(state.business_runs), 1)

		var incomplete_state = GAME_STATE.new_game()
		incomplete_state.pending_showcase_settlement = {"settlement_id": "round:1"}
		var incomplete_applied: bool = incomplete_state.apply_showcase_round_settlement({
			"ok": true,
			"settlement_id": "round:1",
			"earned_coins": 0,
			"round_report": {"round_id": 1, "is_complete": false, "missing_fields": ["environment"]},
			"item_states": {}
		})
		_expect_equal("incomplete settlement still closes the business round", bool(incomplete_applied), true)
		_expect_equal("incomplete report does not enter report history", incomplete_state.recent_showcase_round_reports.size(), 0)

		state.display_items["sponge_cake"] = {
			"cells": [Vector2i(5, 6)],
			"fresh_stock": 1,
			"carried_stock": 2,
			"stock": 3
		}
		state.product_inventory["sponge_cake"] = 5
		_expect_equal("adjustment refill accepts stock beyond the old capacity", bool(state.add_display_item_stock("sponge_cake", 5)), true)
		var refilled_item: Dictionary = state.display_items.get("sponge_cake", {})
		_expect_equal("adjustment refill consumes the full requested inventory", int(state.get_product_count("sponge_cake")), 0)
		_expect_equal("fresh batch receives the full refill", int(refilled_item.get("fresh_stock", 0)), 6)
		_expect_equal("carried batch is unchanged by refill", int(refilled_item.get("carried_stock", 0)), 2)
		_expect_equal("combined stock stays synchronized", int(refilled_item.get("stock", 0)), 8)
		_expect_equal("sales remove carried batch first", bool(state.remove_display_item_stock("sponge_cake", 7)), true)
		var sold_item: Dictionary = state.display_items.get("sponge_cake", {})
		_expect_equal("carried batch is exhausted first", int(sold_item.get("carried_stock", -1)), 0)
		_expect_equal("fresh batch supplies the remainder", int(sold_item.get("fresh_stock", -1)), 1)
		_expect_equal("combined stock remains synchronized after sale", int(sold_item.get("stock", 0)), 1)

	_finish()


func _has_property(value: Object, property_name: String) -> bool:
	for property: Dictionary in value.get_property_list():
		if String(property.get("name", "")) == property_name:
			return true
	return false


func _expect_equal(label: String, actual: Variant, expected: Variant) -> void:
	if actual != expected:
		_fail("%s expected %s, got %s" % [label, expected, actual])


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("SHOWCASE_BUSINESS_ROUND_STATE_SELF_CHECK_PASS")
		quit(0)
	else:
		for failure in _failures:
			printerr("SHOWCASE_BUSINESS_ROUND_STATE_SELF_CHECK_FAIL: %s" % failure)
		quit(1)
