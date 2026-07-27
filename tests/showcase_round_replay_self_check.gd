extends SceneTree

var _failures: Array[String] = []


func _init() -> void:
	var sale_service = load("res://scripts/showcase_round_sale_service.gd")
	var report_service = load("res://scripts/showcase_round_report_service.gd")
	var initial_states := {
		"tea": {
			"recipe_id": "tea", "anchor_cell": Vector2i(0, 0),
			"fresh_stock": 2, "carried_stock": 1, "cycle_elapsed_ms": 0,
			"unit_price": 120, "duration_ms": 5000,
			"base_unit_price": 80, "base_duration_ms": 10000,
			"market_unit_price": 100, "market_duration_ms": 7500,
			"waiting_for_refill": false
		}
	}
	var refills := [{"recipe_id": "tea", "amount": 3, "elapsed_ms": 10000}]
	_expect_equal("sale service exposes deterministic replay", sale_service.has_method("replay_round"), true)
	if sale_service.has_method("replay_round"):
		var base: Dictionary = sale_service.call("replay_round", initial_states, 30000, refills, "base")
		var market: Dictionary = sale_service.call("replay_round", initial_states, 30000, refills, "market")
		var full: Dictionary = sale_service.call("replay_round", initial_states, 30000, refills, "full")
		_expect_equal("base replay respects carried-first and refill time", int(base.get("income", 0)), 224)
		_expect_equal("market replay crosses one additional cycle", int(market.get("income", 0)), 380)
		_expect_equal("full replay crosses two additional cycles", int(full.get("income", 0)), 696)
		_expect_equal("full replay sale count", int(full.get("sold_count", 0)), 6)

	var report: Dictionary = report_service.call("build_report", {
		"round_id": 8, "kind": "standard", "duration_ms": 30000,
		"initial_item_states": initial_states,
		"refill_events": refills,
		"role_snapshot": {"tea": {"role": "lure", "role_reason": "测试引流角色"}},
		"sale_events": [{"recipe_id": "bogus", "earned_coins": 99999}]
	}, {"direct_clearance_coins": 10, "forced_clearance_coins": 2})
	_expect_equal("report marks replay attribution", bool(report.get("replay_verified", false)), true)
	_expect_equal("report base income comes from replay", int(report.get("base_income", 0)), 224)
	_expect_equal("report market income is replay delta", int(report.get("market_income", 0)), 156)
	_expect_equal("report layout income is replay delta", int(report.get("layout_extra_income", 0)), 316)
	_expect_equal("report clearance remains separate", int(report.get("clearance_income", 0)), 12)
	_expect_equal("report total reconciles", int(report.get("total_coins", 0)), 708)
	var tea_product: Dictionary = (report.get("products", {}) as Dictionary).get("tea", {})
	_expect_equal("report separates fresh sales", int(tea_product.get("fresh_sale_count", 0)), 5)
	_expect_equal("report separates carried sales", int(tea_product.get("carried_sale_count", 0)), 1)
	_expect_equal("report keeps refill quantity", int(tea_product.get("refill_count", 0)), 3)
	_expect_equal("report keeps configured product role", String(tea_product.get("role", "")), "lure")
	_expect_equal("report marks exhausted product without next-tier gap", int(tea_product.get("next_sale_gap_ms", 0)), -1)
	var tie_states := {
		"z_early": {
			"recipe_id": "z_early", "anchor_cell": Vector2i(0, 0), "fresh_stock": 1, "carried_stock": 0,
			"cycle_elapsed_ms": 0, "unit_price": 10, "duration_ms": 1000,
			"base_unit_price": 10, "base_duration_ms": 1000, "market_unit_price": 10, "market_duration_ms": 1000
		},
		"a_late": {
			"recipe_id": "a_late", "anchor_cell": Vector2i(0, 1), "fresh_stock": 1, "carried_stock": 0,
			"cycle_elapsed_ms": 0, "unit_price": 10, "duration_ms": 1000,
			"base_unit_price": 10, "base_duration_ms": 1000, "market_unit_price": 10, "market_duration_ms": 1000
		}
	}
	var tie_report: Dictionary = report_service.call("build_report", {
		"round_id": 9, "kind": "standard", "duration_ms": 1000,
		"initial_item_states": tie_states, "refill_events": []
	})
	_expect_equal("replayed top product uses anchor before recipe id", String(tie_report.get("top_recipe_id", "")), "z_early")
	_finish()


func _expect_equal(label: String, actual: Variant, expected: Variant) -> void:
	if actual != expected:
		_fail("%s expected %s, got %s" % [label, expected, actual])


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("SHOWCASE_ROUND_REPLAY_SELF_CHECK_PASS")
		quit(0)
	else:
		for failure in _failures:
			printerr("SHOWCASE_ROUND_REPLAY_SELF_CHECK_FAIL: %s" % failure)
		quit(1)
