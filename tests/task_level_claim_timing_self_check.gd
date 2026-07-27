extends SceneTree

const GAME_STATE := preload("res://scripts/game_state.gd")
const TUTORIAL_PROGRESS := preload("res://scripts/tutorial_progress.gd")

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var state = GAME_STATE.new_game()
	var coins_before := int(state.coins)
	var starlight_before := int(state.recipe_starlight_total)
	state.tutorial_guide_step = TUTORIAL_PROGRESS.STEP_SETTLEMENT

	_expect(TUTORIAL_PROGRESS.on_business_round_settled(state, _sold_round_report()), "A real sale settlement should reach final grandma dialogue")
	_expect_equal("Settlement preserves Lv.0 until grandma confirmation", int(state.level), 0)
	_expect(not state.is_core_feature_unlocked("task"), "Task stays locked before grandma confirmation")
	for feature_id in ["output", "inventory", "research", "craft", "catalog", "list", "rulebook", "arrange", "business", "storefront_manage"]:
		state.unlock_core_feature(feature_id)
	_expect(TUTORIAL_PROGRESS.close_guide(state), "Grandma confirmation should finish onboarding")
	_expect_equal("Grandma confirmation enters Lv.1", int(state.level), 1)
	_expect(state.is_core_feature_unlocked("task"), "Grandma confirmation should unlock tasks")
	_expect_equal("Onboarding grants no one-time coins", int(state.coins), coins_before)
	_expect_equal("Onboarding grants no one-time starlight", int(state.recipe_starlight_total), starlight_before)
	_expect(not TUTORIAL_PROGRESS.close_guide(state), "Final confirmation must be idempotent")
	_finish()


func _sold_round_report() -> Dictionary:
	return {
		"is_complete": true,
		"report_id": "test:level_claim_timing",
		"round_id": 1,
		"duration_ms": 30000,
		"challenge_id": "",
		"counts": {"sold": 1},
		"total_coins": 20,
		"layout_extra_income": 0,
		"max_product_sold": 1,
		"sold_distinct_recipes": 1,
		"layout": {"occupied_cells": 1, "distinct_recipes": 1, "distinct_roles": 1, "max_shared_tag": 1}
	}


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
		print("TASK_LEVEL_CLAIM_TIMING_SELF_CHECK_PASS")
		quit(0)
	else:
		for failure in _failures:
			printerr("TASK_LEVEL_CLAIM_TIMING_SELF_CHECK_FAIL: %s" % failure)
		quit(1)
