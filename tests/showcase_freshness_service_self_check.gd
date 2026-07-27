extends SceneTree

const SERVICE_PATH := "res://scripts/showcase_freshness_service.gd"

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	if not ResourceLoader.exists(SERVICE_PATH):
		_fail("ShowcaseFreshnessService should exist")
		_finish()
		return
	var service := load(SERVICE_PATH)
	if service == null or not service.has_method("prepare_settlement"):
		_fail("ShowcaseFreshnessService should expose prepare_settlement")
		_finish()
		return

	var item_states := {
		"mixed_item": {
			"recipe_id": "mixed_item",
			"fresh_stock": 3,
			"carried_stock": 2,
			"waiting_for_refill": false
		},
		"fresh_only": {
			"recipe_id": "fresh_only",
			"fresh_stock": 1,
			"carried_stock": 0,
			"waiting_for_refill": false
		}
	}
	var quote: Dictionary = service.prepare_settlement(item_states, {
		"mixed_item": 45,
		"fresh_only": 11
	}, "round:7")
	_expect_equal("settlement id", String(quote.get("settlement_id", "")), "round:7")
	_expect_equal("forced clearance coins", int(quote.get("forced_clearance_coins", 0)), 8)
	_expect_equal("forced clearance item count", int(quote.get("forced_clearance_count", 0)), 2)
	var forced_entries: Array = quote.get("forced_entries", [])
	_expect_equal("forced entry count", forced_entries.size(), 1)
	if forced_entries.size() == 1:
		_expect_equal("forced quantity", int((forced_entries[0] as Dictionary).get("quantity", 0)), 2)
		_expect_equal("forced unit price", int((forced_entries[0] as Dictionary).get("unit_price", 0)), 4)
	var fresh_options: Array = quote.get("fresh_options", [])
	_expect_equal("fresh option count", fresh_options.size(), 2)

	if not service.has_method("apply_decisions"):
		_fail("ShowcaseFreshnessService should expose apply_decisions")
	else:
		var missing_decision: Dictionary = service.apply_decisions(item_states, quote, {
			"mixed_item": "clear_50"
		}, [])
		_expect_equal("all fresh decisions are required", bool(missing_decision.get("ok", true)), false)
		_expect_equal("invalid decision pays nothing", int(missing_decision.get("earned_coins", -1)), 0)

		var applied: Dictionary = service.apply_decisions(item_states, quote, {
			"mixed_item": "clear_50",
			"fresh_only": "carry_80"
		}, [])
		_expect_equal("valid decisions apply", bool(applied.get("ok", false)), true)
		_expect_equal("forced plus direct clearance coins", int(applied.get("earned_coins", 0)), 74)
		_expect_equal("forced clearance subtotal", int(applied.get("forced_clearance_coins", 0)), 8)
		_expect_equal("direct clearance subtotal", int(applied.get("direct_clearance_coins", 0)), 66)
		_expect_equal("forced clearance count is preserved", int(applied.get("forced_clearance_count", 0)), 2)
		_expect_equal("direct clearance count", int(applied.get("direct_clearance_count", 0)), 3)
		_expect_equal("carried leftover count", int(applied.get("carried_leftover_count", 0)), 1)
		var applied_states: Dictionary = applied.get("item_states", {})
		var cleared: Dictionary = applied_states.get("mixed_item", {})
		_expect_equal("cleared fresh stock removed", int(cleared.get("fresh_stock", -1)), 0)
		_expect_equal("forced carried stock removed", int(cleared.get("carried_stock", -1)), 0)
		_expect_equal("cleared layout waits for refill", bool(cleared.get("waiting_for_refill", false)), true)
		var carried: Dictionary = applied_states.get("fresh_only", {})
		_expect_equal("kept fresh becomes carried", int(carried.get("carried_stock", 0)), 1)
		_expect_equal("kept fresh batch clears", int(carried.get("fresh_stock", -1)), 0)
		_expect_equal("kept layout still has stock", bool(carried.get("waiting_for_refill", true)), false)

		var duplicate: Dictionary = service.apply_decisions(item_states, quote, {
			"mixed_item": "clear_50",
			"fresh_only": "carry_80"
		}, ["round:7"])
		_expect_equal("duplicate settlement rejected", bool(duplicate.get("ok", true)), false)
		_expect_equal("duplicate settlement pays nothing", int(duplicate.get("earned_coins", -1)), 0)
		_expect_equal("duplicate settlement has no clearance count", int(duplicate.get("direct_clearance_count", -1)), 0)
	_finish()


func _expect_equal(label: String, actual: Variant, expected: Variant) -> void:
	if actual != expected:
		_fail("%s expected %s, got %s" % [label, expected, actual])


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("SHOWCASE_FRESHNESS_SERVICE_SELF_CHECK_PASS")
		quit(0)
	else:
		for failure in _failures:
			printerr("SHOWCASE_FRESHNESS_SERVICE_SELF_CHECK_FAIL: %s" % failure)
		quit(1)
