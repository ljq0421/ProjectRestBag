extends SceneTree

const GAME_STATE := preload("res://scripts/game_state.gd")
const TUTORIAL_PROGRESS := preload("res://scripts/tutorial_progress.gd")
const CORE_FEATURE_UNLOCK_SERVICE := preload("res://scripts/core_feature_unlock_service.gd")

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var state = GAME_STATE.new_game()
	_expect_equal("new guide step", state.tutorial_guide_step, TUTORIAL_PROGRESS.STEP_PURCHASE)
	_expect_equal("new game starter removed", state.get_ingredient_count("spring_water_starter"), 0)
	_expect_equal("new game water retained", state.get_ingredient_count("spring_water"), 10)
	_expect_equal("guide now has settlement stage", TUTORIAL_PROGRESS.STEPS.size(), 11)

	_expect(TUTORIAL_PROGRESS.skip_current_step(state), "I will do it myself should dismiss guidance")
	_expect_equal("dismiss does not advance", state.tutorial_guide_step, TUTORIAL_PROGRESS.STEP_PURCHASE)
	_expect(TUTORIAL_PROGRESS.is_current_guidance_dismissed(state), "dismissal should be observable")
	var dismissed_roundtrip = GAME_STATE.from_dict(state.to_dict())
	_expect(TUTORIAL_PROGRESS.is_current_guidance_dismissed(dismissed_roundtrip), "dismissal should survive save")

	TUTORIAL_PROGRESS.on_purchase_completed(state, {"rice_seed": 1})
	_expect_equal("purchase advances", state.tutorial_guide_step, TUTORIAL_PROGRESS.STEP_OUTPUT)
	_expect(not TUTORIAL_PROGRESS.is_current_guidance_dismissed(state), "real completion should clear old dismissal")
	TUTORIAL_PROGRESS.on_ingredient_harvested(state, "rice", 3, "farm", "guide-rice", true)
	_expect_equal("manual rice harvest advances", state.tutorial_guide_step, TUTORIAL_PROGRESS.STEP_RESEARCH)
	_expect(state.is_device_unlocked("round_pot"), "manual rice harvest unlocks round pot")
	TUTORIAL_PROGRESS.on_recipe_unlocked(state, "rice_milk_drink")
	TUTORIAL_PROGRESS.on_product_made(state, "rice_milk_drink", 1)
	TUTORIAL_PROGRESS.on_product_displayed(state, "rice_milk_drink", 1)
	TUTORIAL_PROGRESS.on_showcase_rulebook_opened(state)
	TUTORIAL_PROGRESS.on_showcase_product_moved(state, "rice_milk_drink")
	TUTORIAL_PROGRESS.on_showcase_product_rotated(state, "rice_milk_drink")
	TUTORIAL_PROGRESS.on_business_round_started(state)
	TUTORIAL_PROGRESS.on_storefront_viewed(state)
	_expect_equal("storefront waits for settlement", state.tutorial_guide_step, TUTORIAL_PROGRESS.STEP_SETTLEMENT)
	_expect(not TUTORIAL_PROGRESS.on_business_round_settled(state, {"counts": {"sold": 0}}), "zero sale does not finish")
	_expect(TUTORIAL_PROGRESS.on_business_round_settled(state, {"counts": {"sold": 1}}), "real sale settlement reaches final dialogue")
	var coins_before := int(state.coins)
	_expect(TUTORIAL_PROGRESS.close_guide(state), "final confirmation finishes guide")
	_expect_equal("guide completion raises Lv1", state.level, 1)
	_expect_equal("guide completion has no coin reward", state.coins, coins_before)
	_expect(state.is_core_feature_unlocked(CORE_FEATURE_UNLOCK_SERVICE.TASK), "guide completion unlocks task")
	_expect(not state.is_core_feature_unlocked(CORE_FEATURE_UNLOCK_SERVICE.STARLIGHT), "guide completion keeps starlight locked")

	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error(message)


func _expect_equal(label: String, actual: Variant, expected: Variant) -> void:
	_expect(actual == expected, "%s expected %s, got %s" % [label, expected, actual])


func _finish() -> void:
	if _failures.is_empty():
		print("TUTORIAL_GUIDE_STATE_SELF_CHECK_PASS")
		quit(0)
		return
	for failure in _failures:
		printerr("TUTORIAL_GUIDE_STATE_SELF_CHECK_FAIL: %s" % failure)
	quit(1)
