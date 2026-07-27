extends SceneTree

const GAME_STATE := preload("res://scripts/game_state.gd")
const CORE_FEATURE_UNLOCK_SERVICE := preload("res://scripts/core_feature_unlock_service.gd")

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var state = GAME_STATE.new_game()
	_expect(state.is_core_feature_unlocked(CORE_FEATURE_UNLOCK_SERVICE.PURCHASE), "new game should open purchase")
	for feature_id in CORE_FEATURE_UNLOCK_SERVICE.ORDER:
		if feature_id == CORE_FEATURE_UNLOCK_SERVICE.PURCHASE:
			continue
		_expect(not state.is_core_feature_unlocked(feature_id), "new game should lock %s" % feature_id)
	_expect_equal("new game keeps ten spring water", state.get_ingredient_count("spring_water"), 10)
	_expect_equal("new game removes starter ingredient", state.get_ingredient_count("spring_water_starter"), 0)

	_expect(not state.unlock_core_feature(CORE_FEATURE_UNLOCK_SERVICE.RESEARCH), "cannot skip prerequisites")
	_expect(state.unlock_core_feature(CORE_FEATURE_UNLOCK_SERVICE.OUTPUT), "output unlocks after purchase")
	_expect(state.unlock_core_feature(CORE_FEATURE_UNLOCK_SERVICE.INVENTORY), "inventory unlocks after purchase")
	state.record_core_unlock_progress("purchased_rice_seed", true)

	var restored = GAME_STATE.from_dict(state.to_dict())
	_expect(restored.is_core_feature_unlocked(CORE_FEATURE_UNLOCK_SERVICE.PURCHASE), "purchase survives save")
	_expect(restored.is_core_feature_unlocked(CORE_FEATURE_UNLOCK_SERVICE.OUTPUT), "output survives save")
	_expect(restored.is_core_feature_unlocked(CORE_FEATURE_UNLOCK_SERVICE.INVENTORY), "inventory survives save")
	_expect(not restored.is_core_feature_unlocked(CORE_FEATURE_UNLOCK_SERVICE.RESEARCH), "locked feature survives save")
	_expect(bool(restored.get_core_unlock_progress("purchased_rice_seed", false)), "unlock evidence survives save")

	var damaged_data: Dictionary = state.to_dict()
	damaged_data["core_feature_unlocks"] = {CORE_FEATURE_UNLOCK_SERVICE.BUSINESS: true}
	var repaired = GAME_STATE.from_dict(damaged_data)
	_expect(repaired.is_core_feature_unlocked(CORE_FEATURE_UNLOCK_SERVICE.BUSINESS), "repair never relocks saved feature")
	for prerequisite_id in CORE_FEATURE_UNLOCK_SERVICE.prerequisite_closure(CORE_FEATURE_UNLOCK_SERVICE.BUSINESS):
		_expect(repaired.is_core_feature_unlocked(prerequisite_id), "repair restores prerequisite %s" % prerequisite_id)
	_expect(not repaired.is_core_feature_unlocked(CORE_FEATURE_UNLOCK_SERVICE.STOREFRONT_MANAGE), "repair does not unlock descendants")

	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error(message)


func _expect_equal(label: String, actual: Variant, expected: Variant) -> void:
	_expect(actual == expected, "%s expected %s, got %s" % [label, expected, actual])


func _finish() -> void:
	if _failures.is_empty():
		print("CORE_FEATURE_UNLOCK_STATE_SELF_CHECK_PASS")
		quit(0)
		return
	for failure in _failures:
		printerr("CORE_FEATURE_UNLOCK_STATE_SELF_CHECK_FAIL: %s" % failure)
	quit(1)
