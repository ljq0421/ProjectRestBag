extends SceneTree

const GAME_STATE := preload("res://scripts/game_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	var state = GAME_STATE.new_game()
	for property_name in ["contract_best_tiers", "store_rating_points", "applied_contract_report_ids"]:
		_expect(_has_property(state, property_name), "GameState should expose %s" % property_name)
	if not _failures.is_empty():
		_finish()
		return
	state.level = 6
	state.coins = 100
	var snapshot := {
		"id": "contract_fast_turnover",
		"task_id": "contract_fast_turnover",
		"version": 1,
		"instance_id": "contract_fast_turnover:v1:r8",
		"round_id": 8,
		"risk": "normal",
		"deposit": 0
	}
	_expect_equal("contract can be selected", bool(state.accept_showcase_challenge(snapshot)), true)
	var result := {
		"valid": true,
		"success": true,
		"status": "success",
		"instance_id": "contract_fast_turnover:v1:r8",
		"task_id": "contract_fast_turnover",
		"challenge_id": "contract_fast_turnover",
		"report_id": "round:8",
		"highest_tier": "silver",
		"deposit_returned": 0,
		"reward_coins": 0
	}
	_expect_equal("first contract result applies", bool(state.apply_showcase_challenge_result(result)), true)
	_expect_equal("silver best tier saved", String(state.contract_best_tiers.get("contract_fast_turnover", "")), "silver")
	_expect_equal("silver adds two rating points", int(state.store_rating_points), 2)
	_expect_equal("report id is recorded", state.applied_contract_report_ids.has("round:8"), true)
	_expect_equal("duplicate report cannot apply", bool(state.apply_showcase_challenge_result(result)), false)
	_expect_equal("duplicate report does not add rating", int(state.store_rating_points), 2)

	state.pending_showcase_challenge = snapshot.duplicate(true)
	state.pending_showcase_challenge["instance_id"] = "contract_fast_turnover:v1:r9"
	var weaker := result.duplicate(true)
	weaker["instance_id"] = "contract_fast_turnover:v1:r9"
	weaker["report_id"] = "round:9"
	weaker["highest_tier"] = "bronze"
	_expect_equal("repeat contract with new report applies", bool(state.apply_showcase_challenge_result(weaker)), true)
	_expect_equal("weaker repeat does not lower best tier", String(state.contract_best_tiers.get("contract_fast_turnover", "")), "silver")
	_expect_equal("bronze repeat still adds one rating point", int(state.store_rating_points), 3)

	var restored = GAME_STATE.from_dict(state.to_dict())
	_expect_equal("rating points persist", int(restored.store_rating_points), 3)
	_expect_equal("best tier persists", String(restored.contract_best_tiers.get("contract_fast_turnover", "")), "silver")
	_expect_equal("applied report ids persist", restored.applied_contract_report_ids.has("round:9"), true)

	_finish()


func _has_property(value: Object, property_name: String) -> bool:
	for property: Dictionary in value.get_property_list():
		if String(property.get("name", "")) == property_name:
			return true
	return false


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
		print("SHOWCASE_ROUND_CONTRACT_SELF_CHECK_PASS")
		quit(0)
	else:
		for failure in _failures:
			printerr("SHOWCASE_ROUND_CONTRACT_SELF_CHECK_FAIL: %s" % failure)
		quit(1)
