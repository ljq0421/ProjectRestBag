extends SceneTree

const GAME_STATE := preload("res://scripts/game_state.gd")
const TUTORIAL_PROGRESS := preload("res://scripts/tutorial_progress.gd")
const CORE_FEATURE_UNLOCK_SERVICE := preload("res://scripts/core_feature_unlock_service.gd")

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var partial_data: Dictionary = GAME_STATE.new_game().to_dict()
	partial_data.erase("core_feature_unlocks")
	partial_data.erase("core_unlock_progress")
	partial_data["tutorial_guide_content_version"] = GAME_STATE.TUTORIAL_GUIDE_CONTENT_VERSION
	partial_data["tutorial_guide_step"] = TUTORIAL_PROGRESS.STEP_CRAFT
	partial_data["tutorial_guide_finished"] = false
	partial_data["tutorial_guide_skipped"] = false
	partial_data["unlocked_recipes"] = ["rice_milk_drink"]
	var partial = GAME_STATE.from_dict(partial_data)
	for feature_id in [
		CORE_FEATURE_UNLOCK_SERVICE.PURCHASE,
		CORE_FEATURE_UNLOCK_SERVICE.OUTPUT,
		CORE_FEATURE_UNLOCK_SERVICE.INVENTORY,
		CORE_FEATURE_UNLOCK_SERVICE.RESEARCH,
		CORE_FEATURE_UNLOCK_SERVICE.CRAFT,
		CORE_FEATURE_UNLOCK_SERVICE.CATALOG,
	]:
		_expect(partial.is_core_feature_unlocked(feature_id), "partial legacy save should restore %s" % feature_id)
	_expect(not partial.is_core_feature_unlocked(CORE_FEATURE_UNLOCK_SERVICE.LIST), "partial reconstruction should not unlock descendants")
	_expect(partial.is_device_unlocked("round_pot"), "research reconstruction should repair round pot")

	var completed_data: Dictionary = GAME_STATE.new_game().to_dict()
	completed_data.erase("core_feature_unlocks")
	completed_data.erase("core_unlock_progress")
	completed_data["tutorial_guide_content_version"] = GAME_STATE.TUTORIAL_GUIDE_CONTENT_VERSION
	completed_data["tutorial_guide_step"] = TUTORIAL_PROGRESS.STEP_COMPLETE
	completed_data["tutorial_guide_finished"] = true
	completed_data["tutorial_guide_skipped"] = false
	completed_data["shop_level"] = 1
	completed_data["level"] = 1
	completed_data["recipe_starlight_total"] = 3
	completed_data["recipe_starlight_available"] = 2
	completed_data["claimed_starlight_rewards"] = ["legacy:reward"]
	completed_data["completed_tasks"] = ["tutorial_l0_first_product", "tutorial_l0_open_shop", "tutorial_l0_first_business"]
	completed_data["claimed_tasks"] = ["tutorial_l0_first_product"]
	completed_data["task_progress"] = {"tutorial_l0_first_business": {"count": 1}}
	completed_data["pending_notifications"] = [{
		"title": "完整营业教学完成",
		"body": "旧教学奖励待领取",
		"metadata": {"task_id": "tutorial_l0_first_business"},
	}]
	var completed = GAME_STATE.from_dict(completed_data)
	for feature_id in CORE_FEATURE_UNLOCK_SERVICE.ORDER:
		_expect(completed.is_core_feature_unlocked(feature_id), "completed legacy save should preserve %s" % feature_id)
	for removed_id in ["tutorial_l0_first_product", "tutorial_l0_open_shop", "tutorial_l0_first_business"]:
		_expect(not completed.completed_tasks.has(removed_id), "removed completed task should be purged")
		_expect(not completed.claimed_tasks.has(removed_id), "removed claimed task should be purged")
		_expect(not completed.task_progress.has(removed_id), "removed task progress should be purged")
	_expect(completed.pending_notifications.is_empty(), "stale tutorial notifications should be purged")

	var current_starlight_data: Dictionary = GAME_STATE.new_game().to_dict()
	current_starlight_data["recipe_starlight_total"] = 1
	current_starlight_data["recipe_starlight_available"] = 1
	current_starlight_data["claimed_starlight_rewards"] = ["recipe_unlock:rice_milk_drink"]
	var current_core_unlocks: Dictionary = (current_starlight_data.get("core_feature_unlocks", {}) as Dictionary).duplicate(true)
	current_core_unlocks.erase(CORE_FEATURE_UNLOCK_SERVICE.STARLIGHT)
	current_starlight_data["core_feature_unlocks"] = current_core_unlocks
	var repaired_current = GAME_STATE.from_dict(current_starlight_data)
	_expect(repaired_current.is_core_feature_unlocked(CORE_FEATURE_UNLOCK_SERVICE.STARLIGHT), "current save with claimed starlight should restore starlight access")
	_expect(repaired_current.recipe_starlight_total == 1, "starlight repair should preserve total balance")
	_expect(repaired_current.recipe_starlight_available == 1, "starlight repair should preserve available balance")
	_expect(repaired_current.claimed_starlight_rewards == ["recipe_unlock:rice_milk_drink"], "starlight repair should preserve reward records")
	_expect(not repaired_current.is_automation_unlocked("output"), "starlight repair should not unlock output automation")
	_expect(not repaired_current.is_automation_unlocked("kitchen"), "starlight repair should not unlock kitchen automation")

	var current_without_starlight = GAME_STATE.from_dict(GAME_STATE.new_game().to_dict())
	_expect(not current_without_starlight.is_core_feature_unlocked(CORE_FEATURE_UNLOCK_SERVICE.STARLIGHT), "current save without starlight evidence should remain locked")

	var no_guide_data: Dictionary = GAME_STATE.new_game().to_dict()
	no_guide_data.erase("core_feature_unlocks")
	no_guide_data.erase("core_unlock_progress")
	for key in [
		"tutorial_guide_step",
		"tutorial_guide_finished",
		"tutorial_guide_skipped",
		"tutorial_guide_dialogue_acknowledged_step",
		"tutorial_guide_dismissed_step",
		"tutorial_guide_content_version",
	]:
		no_guide_data.erase(key)
	var unrestricted_legacy = GAME_STATE.from_dict(no_guide_data)
	_expect(unrestricted_legacy.is_core_feature_unlocked(CORE_FEATURE_UNLOCK_SERVICE.TASK), "pre-guide save should not be relocked")
	_expect(not unrestricted_legacy.is_core_feature_unlocked(CORE_FEATURE_UNLOCK_SERVICE.STARLIGHT), "pre-guide save without stars should not fabricate starlight access")

	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("LEGACY_CORE_UNLOCK_RECONSTRUCTION_SELF_CHECK_PASS")
		quit(0)
		return
	for failure in _failures:
		printerr("LEGACY_CORE_UNLOCK_RECONSTRUCTION_SELF_CHECK_FAIL: %s" % failure)
	quit(1)
