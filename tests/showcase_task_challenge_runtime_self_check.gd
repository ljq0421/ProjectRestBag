extends SceneTree

const TASK_CATALOG := preload("res://scripts/task_catalog_service.gd")
const CATALOG := preload("res://scripts/catalog.gd")
const CHALLENGE_SERVICE_PATH := "res://scripts/showcase_challenge_service.gd"

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var service = load(CHALLENGE_SERVICE_PATH)
	var catalog := TASK_CATALOG.load_catalog()
	var contracts: Array = catalog.get("round_contracts", [])
	var rules := CATALOG.new().get_showcase_round_rules()
	var choices: Array = service.generate_contract_choices(6, 42, contracts, rules, {
		"unlocked_recipe_ids": ["a", "b"],
		"unlocked_tags": ["清爽", "果香"]
	})
	_expect_equal("three contract choices", choices.size(), 3)
	var choice_ids := {}
	var dimensions := {}
	for choice_value in choices:
		if not choice_value is Dictionary:
			continue
		var choice: Dictionary = choice_value
		choice_ids[String(choice.get("task_id", ""))] = true
		for dimension in choice.get("dimensions", []):
			dimensions[String(dimension)] = true
	_expect_equal("contract choices are unique", choice_ids.size(), 3)
	_expect(dimensions.size() >= 2, "Contract choices should cover at least two build dimensions")
	_expect_equal("same round generates stable choices", choices, service.generate_contract_choices(6, 42, contracts, rules, {"unlocked_recipe_ids": ["a", "b"], "unlocked_tags": ["清爽", "果香"]}))

	var snapshot: Dictionary = choices[0] if not choices.is_empty() else {}
	for field in ["task_id", "version", "instance_id", "tiers", "environment", "resolved_recipe_ids", "duration_seconds"]:
		_expect(snapshot.has(field), "Challenge snapshot should preserve %s" % field)
	var original_target := _first_target(snapshot)
	if not contracts.is_empty():
		((contracts[0] as Dictionary).get("tiers", [])[0] as Dictionary)["condition"] = {"field": "counts.sold", "operator": "gte", "value": 999}
	_expect_equal("accepted snapshot is isolated from config changes", _first_target(snapshot), original_target)

	var report := {
		"is_complete": true,
		"report_id": "round:42",
		"round_id": 42,
		"counts": {"sold": 999, "chain_triggers": 999, "forced_clearance": 0},
		"layout": {"occupied_cells": 1},
		"total_coins": 9999
	}
	var result: Dictionary = service.evaluate_business_challenge(snapshot, report)
	_expect_equal("complete report evaluates", String(result.get("status", "")), "success")
	_expect(not String(result.get("highest_tier", "")).is_empty(), "Successful contract should expose its highest tier")
	_expect_equal("challenge service does not issue task coins", int(result.get("reward_coins", -1)), 0)

	var invalid_report := report.duplicate(true)
	invalid_report["is_complete"] = false
	invalid_report["missing_fields"] = ["environment"]
	var invalid: Dictionary = service.evaluate_business_challenge(snapshot, invalid_report)
	_expect_equal("incomplete report is invalid, not failed", String(invalid.get("status", "")), "invalid")

	_finish()


func _first_target(snapshot: Dictionary) -> int:
	var tiers: Array = snapshot.get("tiers", [])
	if tiers.is_empty():
		return -1
	return int(((tiers[0] as Dictionary).get("condition", {}) as Dictionary).get("value", -1))


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
		print("SHOWCASE_TASK_CHALLENGE_RUNTIME_SELF_CHECK_PASS")
		quit(0)
	else:
		for failure in _failures:
			printerr("SHOWCASE_TASK_CHALLENGE_RUNTIME_SELF_CHECK_FAIL: %s" % failure)
		quit(1)
