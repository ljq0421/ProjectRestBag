extends SceneTree

const SERVICE_PATH := "res://scripts/task_condition_service.gd"

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var service = load(SERVICE_PATH)
	if service == null:
		_fail("TaskConditionService should load")
		_finish()
		return

	var report := {
		"is_complete": true,
		"layout": {
			"occupied_cells": 4,
			"distinct_recipes": 2,
			"role_counts": {"lure": 1, "harvest": 1},
			"tag_counts": {"清爽": 2, "果香": 1}
		},
		"counts": {
			"sold": 6,
			"forced_clearance": 0,
			"refill_actions": 1
		},
		"products": {
			"tea": {"sold_count": 4, "triggered_rules": ["黄金区", "热度连锁"]}
		}
	}

	var gte: Dictionary = service.evaluate_condition(report, {
		"field": "layout.occupied_cells", "operator": "gte", "value": 5
	})
	_expect_equal("gte is valid", bool(gte.get("valid", false)), true)
	_expect_equal("gte fails below target", bool(gte.get("passed", true)), false)
	_expect_equal("gte numeric gap", int(gte.get("gap", 0)), 1)
	_expect(String(gte.get("reason", "")).contains("还差 1"), "gte reason should expose an actionable gap")

	var lte: Dictionary = service.evaluate_condition(report, {
		"field": "counts.forced_clearance", "operator": "lte", "value": 0
	})
	_expect_equal("lte passes at target", bool(lte.get("passed", false)), true)
	var nested_product: Dictionary = service.evaluate_condition(report, {
		"field": "products.tea.sold_count", "operator": "eq", "value": 4
	})
	_expect_equal("product point path resolves", bool(nested_product.get("passed", false)), true)
	var contains: Dictionary = service.evaluate_condition(report, {
		"field": "products.tea.triggered_rules", "operator": "contains", "value": "热度连锁"
	})
	_expect_equal("contains supports arrays", bool(contains.get("passed", false)), true)
	var not_contains: Dictionary = service.evaluate_condition(report, {
		"field": "products.tea.triggered_rules", "operator": "not_contains", "value": "强制清仓"
	})
	_expect_equal("not_contains supports arrays", bool(not_contains.get("passed", false)), true)

	var all_result: Dictionary = service.evaluate_condition_group(report, {
		"operator": "all",
		"conditions": [
			{"field": "layout.role_counts.lure", "operator": "gte", "value": 1},
			{"operator": "any", "conditions": [
				{"field": "layout.tag_counts.清爽", "operator": "gte", "value": 2},
				{"field": "layout.tag_counts.果香", "operator": "gte", "value": 3}
			]}
		]
	})
	_expect_equal("nested all and any pass", bool(all_result.get("passed", false)), true)
	_expect_equal("compound result exposes children", (all_result.get("children", []) as Array).size(), 2)

	var unknown: Dictionary = service.evaluate_condition(report, {
		"field": "counts.sold", "operator": "approximately", "value": 6
	})
	_expect_equal("unknown operator is invalid", bool(unknown.get("valid", true)), false)

	var consecutive: Dictionary = service.evaluate_condition(report, {
		"field": "counts.sold", "operator": "gte", "value": 5, "consecutive_runs": 3
	}, [
		{"is_complete": true, "counts": {"sold": 7}},
		{"is_complete": true, "counts": {"sold": 5}}
	])
	_expect_equal("consecutive reports pass deterministically", bool(consecutive.get("passed", false)), true)
	_expect_equal("consecutive count is exposed", int(consecutive.get("current", 0)), 3)

	var tiers: Dictionary = service.evaluate_tiers(report, [
		{"id": "bronze", "condition": {"field": "counts.sold", "operator": "gte", "value": 3}},
		{"id": "silver", "condition": {"field": "counts.sold", "operator": "gte", "value": 6}},
		{"id": "gold", "condition": {"operator": "all", "conditions": [
			{"field": "counts.sold", "operator": "gte", "value": 8},
			{"field": "layout.occupied_cells", "operator": "lte", "value": 4}
		]}}
	])
	_expect_equal("highest reached tier", String(tiers.get("highest_tier", "")), "silver")
	_expect_equal("next tier", String(tiers.get("next_tier", "")), "gold")
	_expect_equal("next tier exposes failed checks", (tiers.get("next_failures", []) as Array).size(), 1)
	_expect_equal("next tier gap", int(((tiers.get("next_failures", []) as Array)[0] as Dictionary).get("gap", 0)), 2)

	var incomplete := report.duplicate(true)
	incomplete["is_complete"] = false
	incomplete["missing_fields"] = ["report_id"]
	var invalid_report: Dictionary = service.evaluate_tiers(incomplete, [
		{"id": "bronze", "condition": {"field": "counts.sold", "operator": "gte", "value": 0}}
	])
	_expect_equal("incomplete report is invalid", bool(invalid_report.get("valid", true)), false)
	_expect_equal("incomplete report never earns bronze", String(invalid_report.get("highest_tier", "x")), "")

	var task_service = load("res://scripts/task_service.gd")
	var delegated: Dictionary = task_service.evaluate_business_task({
		"condition": {"kind": "round_report", "field": "counts.sold", "operator": "gte", "value": 6}
	}, report)
	_expect_equal("TaskService delegates report conditions", bool(delegated.get("passed", false)), true)

	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _expect_equal(label: String, actual: Variant, expected: Variant) -> void:
	if actual != expected:
		_fail("%s expected %s, got %s" % [label, expected, actual])


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("TASK_CONDITION_SERVICE_SELF_CHECK_PASS")
		quit(0)
	else:
		for failure in _failures:
			printerr("TASK_CONDITION_SERVICE_SELF_CHECK_FAIL: %s" % failure)
		quit(1)
