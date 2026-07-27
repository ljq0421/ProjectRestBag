extends SceneTree

const GAME_STATE := preload("res://scripts/game_state.gd")
const TUTORIAL_PROGRESS := preload("res://scripts/tutorial_progress.gd")
const CORE_FEATURE_UNLOCK_SERVICE := preload("res://scripts/core_feature_unlock_service.gd")

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var state = GAME_STATE.new_game()
	var initial_coins: int = state.coins
	var initial_starlight: int = state.recipe_starlight_total
	_expect(TUTORIAL_PROGRESS.skip_current_step(state), "I will do it myself should hide current guidance")
	_expect_equal("skip keeps purchase step", state.tutorial_guide_step, TUTORIAL_PROGRESS.STEP_PURCHASE)
	_expect_equal("skip records dismissed step", state.tutorial_guide_dismissed_step, TUTORIAL_PROGRESS.STEP_PURCHASE)

	_expect(TUTORIAL_PROGRESS.on_purchase_completed(state, {"rice_seed": 1}), "rice seed purchase should advance")
	_expect(state.is_core_feature_unlocked(CORE_FEATURE_UNLOCK_SERVICE.OUTPUT), "purchase should unlock output")
	_expect(state.is_core_feature_unlocked(CORE_FEATURE_UNLOCK_SERVICE.INVENTORY), "purchase should unlock inventory")
	_expect_equal("new step clears dismissal", state.tutorial_guide_dismissed_step, "")

	TUTORIAL_PROGRESS.on_ingredient_harvested(state, "rice", 3, "farm", "guide-rice", true)
	_expect(state.is_core_feature_unlocked(CORE_FEATURE_UNLOCK_SERVICE.RESEARCH), "manual rice harvest should unlock research")
	_expect(state.is_device_unlocked("round_pot"), "manual rice harvest should unlock round pot")

	TUTORIAL_PROGRESS.on_recipe_unlocked(state, "rice_milk_drink")
	_expect(state.is_core_feature_unlocked(CORE_FEATURE_UNLOCK_SERVICE.CRAFT), "rice milk research should unlock craft")
	_expect(state.is_core_feature_unlocked(CORE_FEATURE_UNLOCK_SERVICE.CATALOG), "rice milk research should unlock catalog")

	TUTORIAL_PROGRESS.on_product_made(state, "rice_milk_drink", 1)
	_expect(state.is_core_feature_unlocked(CORE_FEATURE_UNLOCK_SERVICE.LIST), "completed product should unlock listing")
	TUTORIAL_PROGRESS.on_product_displayed(state, "rice_milk_drink", 1)
	_expect(state.is_core_feature_unlocked(CORE_FEATURE_UNLOCK_SERVICE.RULEBOOK), "successful listing should unlock rulebook")
	TUTORIAL_PROGRESS.on_showcase_rulebook_opened(state)
	_expect(state.is_core_feature_unlocked(CORE_FEATURE_UNLOCK_SERVICE.ARRANGE), "guided rulebook should unlock arrangement")
	TUTORIAL_PROGRESS.on_showcase_product_moved(state, "rice_milk_drink")
	TUTORIAL_PROGRESS.on_showcase_product_rotated(state, "rice_milk_drink")
	_expect(state.is_core_feature_unlocked(CORE_FEATURE_UNLOCK_SERVICE.BUSINESS), "move and rotate should unlock business")
	TUTORIAL_PROGRESS.on_business_round_started(state)
	_expect(state.is_core_feature_unlocked(CORE_FEATURE_UNLOCK_SERVICE.STOREFRONT_MANAGE), "real business start should unlock storefront management")
	TUTORIAL_PROGRESS.on_storefront_viewed(state)
	_expect_equal("view storefront waits for settlement", state.tutorial_guide_step, TUTORIAL_PROGRESS.STEP_SETTLEMENT)
	_expect(not TUTORIAL_PROGRESS.on_business_round_settled(state, {"counts": {"sold": 0}}), "zero-sale settlement should not complete tutorial")
	_expect_equal("zero sale remains at settlement", state.tutorial_guide_step, TUTORIAL_PROGRESS.STEP_SETTLEMENT)
	_expect(TUTORIAL_PROGRESS.on_business_round_settled(state, {"counts": {"sold": 1}}), "real sale settlement should show final dialogue")
	_expect_equal("sold settlement reaches final dialogue", state.tutorial_guide_step, TUTORIAL_PROGRESS.STEP_COMPLETE)
	_expect(TUTORIAL_PROGRESS.close_guide(state), "confirming final dialogue should finish tutorial")
	_expect(state.is_core_feature_unlocked(CORE_FEATURE_UNLOCK_SERVICE.TASK), "final confirmation should unlock task")
	_expect(not state.is_core_feature_unlocked(CORE_FEATURE_UNLOCK_SERVICE.STARLIGHT), "final confirmation should keep starlight locked")
	_expect_equal("tutorial finishes at Lv1", state.level, 1)
	_expect_equal("tutorial grants no coins", state.coins, initial_coins)
	_expect_equal("tutorial grants no starlight", state.recipe_starlight_total, initial_starlight)

	var settle_first = GAME_STATE.new_game()
	settle_first.tutorial_guide_step = TUTORIAL_PROGRESS.STEP_STOREFRONT
	_expect(not TUTORIAL_PROGRESS.on_business_round_settled(settle_first, {"counts": {"sold": 1}}), "settlement first should wait for storefront view")
	_expect_equal("settlement first keeps storefront step", settle_first.tutorial_guide_step, TUTORIAL_PROGRESS.STEP_STOREFRONT)
	_expect(bool(settle_first.get_core_unlock_progress("first_sale_settlement_completed", false)), "settlement evidence should persist before storefront view")
	var settle_first_restored = GAME_STATE.from_dict(settle_first.to_dict())
	_expect(TUTORIAL_PROGRESS.on_storefront_viewed(settle_first_restored), "later storefront view should converge completed evidence")
	_expect_equal("settlement then storefront reaches final dialogue", settle_first_restored.tutorial_guide_step, TUTORIAL_PROGRESS.STEP_COMPLETE)

	var zero_sale_first = GAME_STATE.new_game()
	zero_sale_first.tutorial_guide_step = TUTORIAL_PROGRESS.STEP_STOREFRONT
	_expect(not TUTORIAL_PROGRESS.on_business_round_settled(zero_sale_first, {"counts": {"sold": 0}}), "zero-sale settlement first should not complete")
	_expect(not bool(zero_sale_first.get_core_unlock_progress("first_sale_settlement_completed", false)), "zero-sale settlement should not persist valid evidence")
	_expect(TUTORIAL_PROGRESS.on_storefront_viewed(zero_sale_first), "storefront view should still advance to settlement wait")
	_expect_equal("zero sale then storefront waits for settlement", zero_sale_first.tutorial_guide_step, TUTORIAL_PROGRESS.STEP_SETTLEMENT)

	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error(message)


func _expect_equal(label: String, actual: Variant, expected: Variant) -> void:
	_expect(actual == expected, "%s expected %s, got %s" % [label, expected, actual])


func _finish() -> void:
	if _failures.is_empty():
		print("CORE_UNLOCK_EVENT_CHAIN_SELF_CHECK_PASS")
		quit(0)
		return
	for failure in _failures:
		printerr("CORE_UNLOCK_EVENT_CHAIN_SELF_CHECK_FAIL: %s" % failure)
	quit(1)
