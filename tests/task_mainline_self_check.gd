extends SceneTree

const GAME_STATE := preload("res://scripts/game_state.gd")
const TASK_SERVICE := preload("res://scripts/task_service.gd")
const TASK_CATALOG := preload("res://scripts/task_catalog_service.gd")
const TASK_OVERLAY_SCENE := preload("res://scenes/ui/overlays/task_overlay.tscn")
const TUTORIAL_PROGRESS := preload("res://scripts/tutorial_progress.gd")

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var catalog := TASK_CATALOG.load_catalog()
	var definitions := TASK_SERVICE.get_task_definitions()
	_expect_equal("NPC tutorial creates no task cards", (catalog.get("tutorial_tasks", []) as Array).size(), 0)
	_expect_equal("Lv.1-Lv.5 has seven growth tasks", (catalog.get("growth_tasks", []) as Array).size(), 7)
	_expect((catalog.get("round_contracts", []) as Array).size() >= 3, "Lv.6+ should expose at least three contracts")

	for task_value in definitions.values():
		if not task_value is Dictionary:
			continue
		var task: Dictionary = task_value
		var task_type := String(task.get("type", ""))
		var reward: Dictionary = task.get("reward", {})
		if int(task.get("level", 0)) >= 1:
			_expect(not reward.has("set_level"), "%s must not upgrade the shop directly" % String(task.get("id", "")))
		if int(task.get("level", 0)) >= 3 and ["growth", "contract"].has(task_type):
			_expect_equal("Lv.3+ build event", String(task.get("event", "")), "business_round_completed")
		for reward_key in reward.keys():
			_expect(["coins", "reputation", "ingredients", "tools", "unlock_tools", "unlock_devices", "unlock_automation", "unlock_features", "set_level", "starlight", "rating_points"].has(String(reward_key)), "%s has unknown reward key %s" % [String(task.get("id", "")), reward_key])

	var state = GAME_STATE.new_game()
	var first_active := _active_ids(TASK_SERVICE.get_visible_tasks(state))
	_expect(first_active.is_empty(), "Task list must stay hidden during the NPC tutorial")
	state.record_task_event("harvest", {"item_id": "rice"})
	_expect(state.task_progress.is_empty(), "Task progress must not be recorded before task unlock")
	_open_task_system(state)
	var post_tutorial_ids := _active_ids(TASK_SERVICE.get_visible_tasks(state))
	_expect(post_tutorial_ids.has("growth_l1_sales_rhythm"), "The first post-tutorial growth task should be visible")
	for removed_id in ["tutorial_l0_first_product", "tutorial_l0_open_shop", "tutorial_l0_first_business"]:
		_expect(not post_tutorial_ids.has(removed_id), "Removed tutorial card must stay absent: %s" % removed_id)
	var coins_before := int(state.coins)
	state.record_task_event("business_round_completed", _report({"sold": 2, "refill_actions": 1}, 40, 0, 2, 1, 1))
	_expect(state.is_task_completed("growth_l1_sales_rhythm"), "The first real growth task should complete from one qualifying round")
	_expect(state.claim_task_reward("growth_l1_sales_rhythm"), "Growth reward should be claimable")
	_expect_equal("growth reward coins", int(state.coins), coins_before + 135)

	var build_state = GAME_STATE.new_game()
	_open_task_system(build_state)
	build_state.level = 3
	for prerequisite in ["growth_l1_sales_rhythm", "growth_l1_leftover_decision", "growth_l2_basic_combo", "growth_l2_compact_build"]:
		build_state.completed_tasks.append(prerequisite)
	var completed: Array = build_state.record_task_event("business_round_completed", _report({
		"sold": 7,
		"refill_actions": 2,
		"forced_clearance": 0,
		"direct_clearance": 1,
		"carried_leftovers": 1,
		"chain_triggers": 1
	}, 240, 40, 8, 3, 3))
	_expect(completed.has("growth_l3_inventory_pressure"), "Unified report should complete the current inventory challenge")
	_expect_equal("Build course does not change level", int(build_state.level), 3)
	build_state.level = 4

	var overlay = TASK_OVERLAY_SCENE.instantiate()
	var snapshot: Dictionary = TASK_SERVICE.build_task_snapshot(build_state)
	_expect(not overlay.call("_task_entries", snapshot, "current").is_empty(), "Current filter should contain the next growth task")
	_expect(not overlay.call("_task_entries", snapshot, "side").is_empty(), "Side filter should contain selected support tasks")
	overlay.free()

	_finish()


func _open_task_system(state) -> void:
	for feature_id in ["output", "inventory", "research", "craft", "catalog", "list", "rulebook", "arrange", "business", "storefront_manage"]:
		state.unlock_core_feature(feature_id)
	state.tutorial_guide_step = TUTORIAL_PROGRESS.STEP_COMPLETE
	_expect(TUTORIAL_PROGRESS.close_guide(state), "Final grandma confirmation should open tasks")


func _report(counts: Dictionary, total_coins: int, layout_extra: int, occupied: int, distinct_recipes: int, distinct_roles: int) -> Dictionary:
	return {
		"is_complete": true,
		"report_id": "test:round",
		"round_id": 1,
		"duration_ms": 30000,
		"challenge_id": "",
		"counts": counts,
		"total_coins": total_coins,
		"layout_extra_income": layout_extra,
		"max_product_sold": 3,
		"sold_distinct_recipes": distinct_recipes,
		"layout": {"occupied_cells": occupied, "distinct_recipes": distinct_recipes, "distinct_roles": distinct_roles, "max_shared_tag": 2}
	}


func _active_ids(tasks: Array) -> Array[String]:
	var result: Array[String] = []
	for task_value in tasks:
		if task_value is Dictionary:
			result.append(String((task_value as Dictionary).get("id", "")))
	return result


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
		print("TASK_MAINLINE_SELF_CHECK_PASS")
		quit(0)
	else:
		for failure in _failures:
			printerr("TASK_MAINLINE_SELF_CHECK_FAIL: %s" % failure)
		quit(1)
