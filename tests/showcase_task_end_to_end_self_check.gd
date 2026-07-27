extends SceneTree

const GAME_STATE := preload("res://scripts/game_state.gd")
const TASK_CATALOG := preload("res://scripts/task_catalog_service.gd")
const CATALOG := preload("res://scripts/catalog.gd")
const CHALLENGE_SERVICE := preload("res://scripts/showcase_challenge_service.gd")

var _failures: Array[String] = []


func _init() -> void:
	var state = GAME_STATE.new_game()
	state.level = 6
	state.coins = 500
	var contracts: Array = TASK_CATALOG.load_catalog().get("round_contracts", [])
	var choices := CHALLENGE_SERVICE.generate_contract_choices(6, 20, contracts, CATALOG.new().get_showcase_round_rules(), {
		"unlocked_recipe_ids": ["a", "b", "c"], "unlocked_tags": ["清爽", "果香"]
	})
	var snapshot: Dictionary = choices[0]
	_expect(state.accept_showcase_challenge(snapshot), "Contract selection should lock a snapshot")
	var report := {
		"is_complete": true,
		"report_id": "round:20",
		"round_id": 20,
		"duration_ms": 30000,
		"challenge_id": String(snapshot.get("task_id", "")),
		"counts": {"sold": 999, "chain_triggers": 999, "forced_clearance": 0},
		"layout": {"occupied_cells": 1, "distinct_roles": 4, "max_shared_tag": 3},
		"total_coins": 9999,
		"layout_extra_income": 9999,
		"sold_distinct_recipes": 3
	}
	var result := CHALLENGE_SERVICE.evaluate_business_challenge(snapshot, report)
	_expect_equal("contract reaches gold", String(result.get("highest_tier", "")), "gold")
	var completed: Array = state.record_task_event("business_round_completed", report)
	var task_id := String(snapshot.get("task_id", ""))
	_expect(completed.has(task_id), "Selected contract should create one claimable task result")
	_expect_equal("challenge result applies once", bool(state.apply_showcase_challenge_result(result)), true)
	_expect_equal("gold adds three rating points", int(state.store_rating_points), 3)
	_expect_equal("duplicate result is rejected", bool(state.apply_showcase_challenge_result(result)), false)
	_expect_equal("duplicate does not add rating", int(state.store_rating_points), 3)
	var contract_definition: Dictionary = {}
	for contract_value: Variant in contracts:
		if contract_value is Dictionary and String((contract_value as Dictionary).get("id", "")) == task_id:
			contract_definition = contract_value
			break
	var repeated_snapshot := CHALLENGE_SERVICE.create_task_challenge(
		contract_definition,
		21,
		CATALOG.new().get_showcase_round_rules(),
		{"level": 6, "unlocked_recipe_ids": ["a", "b", "c"], "unlocked_tags": ["清爽", "果香"]}
	)
	_expect(not state.accept_showcase_challenge(repeated_snapshot), "A repeated contract should not overwrite an unclaimed result")
	var reward_before := int(state.coins)
	_expect(state.claim_task_reward(task_id), "Contract task reward should be claimable")
	_expect(int(state.coins) > reward_before, "Contract claim should grant configured coins")
	_expect_equal("contract reward cannot be claimed twice", bool(state.claim_task_reward(task_id)), false)

	_expect(state.accept_showcase_challenge(repeated_snapshot), "The same contract should be selectable again in a later round")
	_expect(not state.is_task_completed(task_id), "Selecting a repeatable contract should open a fresh task result")
	var repeated_report := report.duplicate(true)
	repeated_report["report_id"] = "round:21"
	repeated_report["round_id"] = 21
	var repeated_completed: Array = state.record_task_event("business_round_completed", repeated_report)
	_expect(repeated_completed.has(task_id), "A repeated contract should create a new claimable task result")
	var repeated_reward_before := int(state.coins)
	_expect(state.claim_task_reward(task_id), "A repeated contract reward should be claimable for the new instance")
	_expect(int(state.coins) > repeated_reward_before, "A repeated contract claim should grant the configured reward again")

	var invalid_report := report.duplicate(true)
	invalid_report["is_complete"] = false
	invalid_report["report_id"] = "round:21"
	invalid_report["missing_fields"] = ["environment"]
	var invalid := CHALLENGE_SERVICE.evaluate_business_challenge(snapshot, invalid_report)
	_expect_equal("incomplete report remains invalid", String(invalid.get("status", "")), "invalid")

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
		print("SHOWCASE_TASK_END_TO_END_SELF_CHECK_PASS")
		quit(0)
	else:
		for failure in _failures:
			printerr("SHOWCASE_TASK_END_TO_END_SELF_CHECK_FAIL: %s" % failure)
		quit(1)
