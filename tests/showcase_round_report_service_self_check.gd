extends SceneTree

var _failures: Array[String] = []


func _init() -> void:
	var path := "res://scripts/showcase_round_report_service.gd"
	if not ResourceLoader.exists(path):
		_fail("ShowcaseRoundReportService should exist")
		_finish()
		return
	var service = load(path)
	_expect_event_income_breakdown(service)
	var round_state := {
		"round_id": 9,
		"kind": "standard",
		"duration_ms": 30000,
		"sale_events": [
			{"recipe_id": "a", "quantity": 1, "batch": "fresh", "earned_coins": 120, "base_price": 100, "environment_price_pct": 10.0, "anchor_slot": 5, "reasons": ["黄金区"]},
			{"recipe_id": "a", "quantity": 1, "batch": "carried", "earned_coins": 96, "base_price": 100, "environment_price_pct": 10.0, "anchor_slot": 5, "reasons": ["黄金区", "街区小集"]},
			{"recipe_id": "b", "quantity": 1, "batch": "fresh", "earned_coins": 45, "base_price": 50, "environment_price_pct": -10.0, "anchor_slot": 8, "reasons": []}
		],
		"refill_events": [
			{"recipe_id": "a", "amount": 2, "elapsed_ms": 12000}
		]
	}
	var report: Dictionary = service.build_report(round_state, {
		"forced_clearance_coins": 3,
		"direct_clearance_coins": 20
	})
	_expect_equal("report round id", int(report.get("round_id", 0)), 9)
	_expect_equal("normal sale income", int(report.get("normal_income", 0)), 261)
	_expect_equal("base income replay", int(report.get("base_income", 0)), 230)
	_expect_equal("market impact", int(report.get("market_income", 0)), 13)
	_expect_equal("layout and chain extra", int(report.get("layout_extra_income", 0)), 18)
	_expect_equal("clearance stays separate", int(report.get("clearance_income", 0)), 23)
	_expect_equal("all parts reconcile to total", int(report.get("total_coins", 0)), 284)
	_expect_equal("top contributor is stable", String(report.get("top_recipe_id", "")), "a")
	var product_a: Dictionary = (report.get("products", {}) as Dictionary).get("a", {})
	_expect_equal("product sale count", int(product_a.get("sold_count", 0)), 2)
	_expect_equal("product full-price count", int(product_a.get("fresh_sale_count", 0)), 1)
	_expect_equal("product carried count", int(product_a.get("carried_sale_count", 0)), 1)
	_expect_equal("product refill count", int(product_a.get("refill_count", 0)), 2)
	_expect_equal("product unique rule reasons", (product_a.get("triggered_rules", []) as Array).size(), 2)
	_expect_equal("report never invents shortage loss", report.has("shortage_loss"), false)
	var dynamic_report: Dictionary = service.build_report({
		"round_id": 10,
		"kind": "standard",
		"duration_ms": 30000,
		"live_layout_changed": true,
		"initial_item_states": {
			"a": {"recipe_id": "a", "duration_ms": 30000, "cycle_elapsed_ms": 0, "fresh_stock": 1, "carried_stock": 0, "unit_price": 1}
		},
		"sale_events": [
			{"recipe_id": "new_item", "quantity": 1, "batch": "fresh", "earned_coins": 75, "base_price": 50, "environment_price_pct": 10.0, "anchor_slot": 20}
		],
		"role_snapshot": {"new_item": {"role": "harvest", "role_reason": "营业中上新后形成收获位"}},
		"item_states": {"new_item": {"fresh_stock": 1, "carried_stock": 0, "duration_ms": 5000, "cycle_elapsed_ms": 2000, "anchor_cell": Vector2i(5, 7)}},
		"refill_events": []
	})
	_expect_equal("dynamic-layout report uses actually credited events", int(dynamic_report.get("normal_income", 0)), 75)
	_expect_equal("dynamic-layout report does not claim fixed-layout replay", bool(dynamic_report.get("replay_verified", false)), false)
	var dynamic_product: Dictionary = (dynamic_report.get("products", {}) as Dictionary).get("new_item", {})
	_expect_equal("dynamic-layout report keeps the final live role", String(dynamic_product.get("role", "")), "harvest")
	_expect_equal("dynamic-layout report keeps the final threshold gap", int(dynamic_product.get("next_sale_gap_ms", -1)), 3000)
	_finish()


func _expect_event_income_breakdown(service: Script) -> void:
	if not _script_declares_method(service, "event_income_breakdown"):
		_fail("round report service should expose one shared event income breakdown")
		return
	var fresh: Dictionary = service.call("event_income_breakdown", {
		"earned_coins": 86,
		"quantity": 1,
		"batch": "fresh",
		"base_price": 50,
		"environment_price_pct": 16.0
	})
	_expect_equal("fresh event base income", int(fresh.get("base_income", -1)), 50)
	_expect_equal("fresh event market income", int(fresh.get("market_income", -1)), 8)
	_expect_equal("fresh event layout income", int(fresh.get("layout_extra_income", -1)), 28)
	_expect_equal("fresh event parts reconcile", int(fresh.get("total_coins", -1)), 86)
	var carried: Dictionary = service.call("event_income_breakdown", {
		"earned_coins": 86,
		"quantity": 1,
		"batch": "carried",
		"base_price": 50,
		"environment_price_pct": 16.0
	})
	_expect_equal("carried event discounts base income", int(carried.get("base_income", -1)), 40)
	_expect_equal("carried event discounts market income", int(carried.get("market_income", -1)), 6)
	_expect_equal("carried event keeps credited layout remainder", int(carried.get("layout_extra_income", -1)), 40)
	var bonus_only: Dictionary = service.call("event_income_breakdown", {
		"earned_coins": 12,
		"quantity": 0,
		"bonus_only": true,
		"base_price": 50,
		"environment_price_pct": 16.0
	})
	_expect_equal("bonus-only event has no base income", int(bonus_only.get("base_income", -1)), 0)
	_expect_equal("bonus-only event has no market income", int(bonus_only.get("market_income", -1)), 0)
	_expect_equal("bonus-only event is layout-chain income", int(bonus_only.get("layout_extra_income", -1)), 12)


func _script_declares_method(script: Script, method_name: String) -> bool:
	for method_value in script.get_script_method_list():
		if method_value is Dictionary and String((method_value as Dictionary).get("name", "")) == method_name:
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
		print("SHOWCASE_ROUND_REPORT_SERVICE_SELF_CHECK_PASS")
		quit(0)
	else:
		for failure in _failures:
			printerr("SHOWCASE_ROUND_REPORT_SERVICE_SELF_CHECK_FAIL: %s" % failure)
		quit(1)
