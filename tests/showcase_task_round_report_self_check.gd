extends SceneTree

const REPORT_SERVICE_PATH := "res://scripts/showcase_round_report_service.gd"

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var service = load(REPORT_SERVICE_PATH)
	if service == null:
		_fail("ShowcaseRoundReportService should load")
		_finish()
		return

	var round_state := {
		"round_id": 21,
		"kind": "challenge",
		"phase": "settlement",
		"duration_ms": 30000,
		"elapsed_ms": 30000,
		"live_layout_changed": true,
		"challenge": {"id": "contract_chain", "version": 3},
		"environment": {"id": "steady_demand", "label": "平稳需求"},
		"layout_snapshot": {
			"a": {"cells": [Vector2i(1, 1), Vector2i(1, 2)]},
			"b": {"cells": [Vector2i(2, 1)]}
		},
		"role_snapshot": {
			"a": {"role": "lure"},
			"b": {"role": "harvest"}
		},
		"tag_snapshot": {
			"a": ["清爽"],
			"b": ["清爽", "果香"]
		},
		"sale_events": [
			{"recipe_id": "a", "quantity": 1, "batch": "fresh", "earned_coins": 20, "base_price": 15, "anchor_slot": 1},
			{"recipe_id": "b", "quantity": 1, "batch": "fresh", "earned_coins": 35, "base_price": 25, "anchor_slot": 2, "chain_source": "a"}
		],
		"refill_events": [
			{"recipe_id": "a", "amount": 2, "elapsed_ms": 12000}
		],
		"item_states": {
			"a": {"fresh_stock": 1, "carried_stock": 0, "waiting_for_refill": false},
			"b": {"fresh_stock": 0, "carried_stock": 0, "waiting_for_refill": true}
		}
	}
	var report: Dictionary = service.build_report(round_state, {
		"settlement_id": "round:21:settlement",
		"forced_clearance_coins": 2,
		"direct_clearance_coins": 10,
		"forced_clearance_count": 1,
		"direct_clearance_count": 2,
		"carried_leftover_count": 3
	})

	_expect_equal("stable report id", String(report.get("report_id", "")), "round:21:settlement")
	_expect_equal("challenge id", String(report.get("challenge_id", "")), "contract_chain")
	_expect_equal("challenge version", int(report.get("challenge_version", 0)), 3)
	_expect_equal("report completeness", bool(report.get("is_complete", false)), true)
	_expect_equal("missing field list", (report.get("missing_fields", []) as Array).size(), 0)
	_expect_equal("environment snapshot", String((report.get("environment", {}) as Dictionary).get("id", "")), "steady_demand")
	_expect_equal("layout snapshot recipe count", (report.get("layout_snapshot", {}) as Dictionary).size(), 2)
	_expect_equal("report uses only save-safe values", _contains_vector_value(report), false)
	_expect_equal("highest per-product sale count", int(report.get("max_product_sold", 0)), 1)
	_expect_equal("sold distinct recipe count", int(report.get("sold_distinct_recipes", 0)), 2)

	var layout: Dictionary = report.get("layout", {})
	_expect_equal("occupied cell count", int(layout.get("occupied_cells", 0)), 3)
	_expect_equal("distinct recipe count", int(layout.get("distinct_recipes", 0)), 2)
	_expect_equal("distinct role count", int(layout.get("distinct_roles", 0)), 2)
	_expect_equal("largest shared tag group", int(layout.get("max_shared_tag", 0)), 2)
	_expect_equal("lure role count", int((layout.get("role_counts", {}) as Dictionary).get("lure", 0)), 1)
	_expect_equal("refreshing tag count", int((layout.get("tag_counts", {}) as Dictionary).get("清爽", 0)), 2)

	var counts: Dictionary = report.get("counts", {})
	_expect_equal("sold count", int(counts.get("sold", 0)), 2)
	_expect_equal("chain trigger count", int(counts.get("chain_triggers", 0)), 1)
	_expect_equal("refill action count", int(counts.get("refill_actions", 0)), 1)
	_expect_equal("refilled item count", int(counts.get("refilled_items", 0)), 2)
	_expect_equal("waiting item count", int(counts.get("waiting_for_refill", 0)), 1)
	_expect_equal("forced clearance count", int(counts.get("forced_clearance", 0)), 1)
	_expect_equal("direct clearance count", int(counts.get("direct_clearance", 0)), 2)
	_expect_equal("carried leftover count", int(counts.get("carried_leftovers", 0)), 3)

	var incomplete: Dictionary = service.build_report({
		"round_id": 22,
		"kind": "standard",
		"duration_ms": 30000,
		"sale_events": [],
		"refill_events": [],
		"item_states": {}
	})
	_expect_equal("report without settlement id is incomplete", bool(incomplete.get("is_complete", true)), false)
	_expect((incomplete.get("missing_fields", []) as Array).has("report_id"), "Incomplete report should name report_id")

	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _expect_equal(label: String, actual: Variant, expected: Variant) -> void:
	if actual != expected:
		_fail("%s expected %s, got %s" % [label, expected, actual])


func _contains_vector_value(value: Variant) -> bool:
	if value is Vector2 or value is Vector2i:
		return true
	if value is Dictionary:
		for child in (value as Dictionary).values():
			if _contains_vector_value(child):
				return true
	if value is Array:
		for child in value as Array:
			if _contains_vector_value(child):
				return true
	return false


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("SHOWCASE_TASK_ROUND_REPORT_SELF_CHECK_PASS")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)
