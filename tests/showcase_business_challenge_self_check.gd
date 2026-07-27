extends SceneTree

const GAME_STATE := preload("res://scripts/game_state.gd")
const TASK_CATALOG := preload("res://scripts/task_catalog_service.gd")
const CATALOG := preload("res://scripts/catalog.gd")
const SERVICE := preload("res://scripts/showcase_challenge_service.gd")

var _failures: Array[String] = []


func _init() -> void:
	var contracts: Array = TASK_CATALOG.load_catalog().get("round_contracts", [])
	var choices := SERVICE.generate_contract_choices(6, 12, contracts, CATALOG.new().get_showcase_round_rules(), {
		"unlocked_recipe_ids": ["sponge_cake"], "unlocked_tags": ["甜"]
	})
	_expect_equal("contract selection count", choices.size(), 3)
	var first: Dictionary = choices[0] if not choices.is_empty() else {}
	for field in ["task_id", "version", "title", "description", "tiers", "environment", "duration_seconds", "instance_id"]:
		_expect(first.has(field), "Contract snapshot should contain %s" % field)
	_expect_equal("normal contract has no deposit", int(first.get("deposit", -1)), 0)

	var state = GAME_STATE.new_game()
	state.level = 6
	state.coins = 100
	_expect_equal("contract acceptance succeeds", bool(state.accept_showcase_challenge(first)), true)
	_expect_equal("normal contract does not deduct coins", int(state.coins), 100)
	_expect_equal("accepted snapshot is stored", String(state.pending_showcase_challenge.get("task_id", "")), String(first.get("task_id", "")))

	var failed_report := {"is_complete": true, "report_id": "round:12", "counts": {"sold": 0, "chain_triggers": 0, "forced_clearance": 9}, "layout": {"occupied_cells": 99}, "total_coins": 0}
	var failed := SERVICE.evaluate_business_challenge(first, failed_report)
	_expect_equal("failed contract is explicit", String(failed.get("status", "")), "failed")
	_expect_equal("contract result never issues task coins", int(failed.get("reward_coins", -1)), 0)
	var success_report := {"is_complete": true, "report_id": "round:12", "counts": {"sold": 999, "chain_triggers": 999, "forced_clearance": 0}, "layout": {"occupied_cells": 1}, "total_coins": 9999}
	var success := SERVICE.evaluate_business_challenge(first, success_report)
	_expect_equal("meeting gold targets succeeds", String(success.get("status", "")), "success")
	_expect_equal("highest tier is gold", String(success.get("highest_tier", "")), "gold")

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
		print("SHOWCASE_BUSINESS_CHALLENGE_SELF_CHECK_PASS")
		quit(0)
	else:
		for failure in _failures:
			printerr("SHOWCASE_BUSINESS_CHALLENGE_SELF_CHECK_FAIL: %s" % failure)
		quit(1)
