extends SceneTree

const MAIN := preload("res://scenes/Main.tscn")
const GAME_STATE := preload("res://scripts/game_state.gd")
const CATALOG := preload("res://scripts/catalog.gd")
const TASK_SERVICE := preload("res://scripts/task_service.gd")
const TASK_CATALOG := preload("res://scripts/task_catalog_service.gd")
const CONDITION_SERVICE := preload("res://scripts/task_condition_service.gd")
const CHALLENGE_SERVICE := preload("res://scripts/showcase_challenge_service.gd")
const TUTORIAL_PROGRESS := preload("res://scripts/tutorial_progress.gd")

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var task_catalog := TASK_CATALOG.load_catalog()
	_expect_equal("task catalog validation", TASK_CATALOG.validate_catalog(task_catalog, TASK_CATALOG.load_game_data()), [])
	_expect_equal("NPC tutorial task cards", (task_catalog.get("tutorial_tasks", []) as Array).size(), 0)
	_expect_equal("Lv.1-Lv.5 growth tasks", (task_catalog.get("growth_tasks", []) as Array).size(), 7)
	_expect((task_catalog.get("round_contracts", []) as Array).size() >= 3, "Lv.6+ contract pool should be populated")

	var state = GAME_STATE.new_game()
	state.record_task_event("harvest", {"item_id": "rice"})
	_expect(state.task_progress.is_empty(), "Task progress stays empty during NPC tutorial")
	state.tutorial_guide_step = TUTORIAL_PROGRESS.STEP_SETTLEMENT
	TUTORIAL_PROGRESS.on_business_round_settled(state, {
		"is_complete": true, "report_id": "round:1", "round_id": 1, "duration_ms": 30000,
		"counts": {"sold": 1}
	})
	_expect_equal("settlement remains Lv.0 before grandma confirmation", int(state.level), 0)
	for feature_id in ["output", "inventory", "research", "craft", "catalog", "list", "rulebook", "arrange", "business", "storefront_manage"]:
		state.unlock_core_feature(feature_id)
	TUTORIAL_PROGRESS.close_guide(state)
	_expect_equal("grandma confirmation enters Lv.1", int(state.level), 1)
	_expect(state.is_core_feature_unlocked("task"), "grandma confirmation opens tasks")

	var evaluation := CONDITION_SERVICE.evaluate_tiers({
		"is_complete": true, "counts": {"sold": 6}, "layout": {"occupied_cells": 4}
	}, [
		{"id": "bronze", "condition": {"field": "counts.sold", "operator": "gte", "value": 3}},
		{"id": "silver", "condition": {"field": "counts.sold", "operator": "gte", "value": 6}},
		{"id": "gold", "condition": {"field": "counts.sold", "operator": "gte", "value": 9}}
	])
	_expect_equal("shared evaluator reaches silver", String(evaluation.get("highest_tier", "")), "silver")

	var choices := CHALLENGE_SERVICE.generate_contract_choices(6, 9, task_catalog.get("round_contracts", []), CATALOG.new().get_showcase_round_rules(), {
		"unlocked_recipe_ids": ["rice_milk_drink"], "unlocked_tags": ["清爽"]
	})
	_expect_equal("Lv.6 generates three choices", choices.size(), 3)
	_expect_equal("contract choice is deterministic", choices, CHALLENGE_SERVICE.generate_contract_choices(6, 9, task_catalog.get("round_contracts", []), CATALOG.new().get_showcase_round_rules(), {"unlocked_recipe_ids": ["rice_milk_drink"], "unlocked_tags": ["清爽"]}))

	for level in range(2, 7):
		var requirement := CATALOG.new().get_upgrade_definition(level)
		_expect(int(requirement.get("cost", 0)) >= 0, "Upgrade %d should still use catalog economy requirements" % level)

	var view = MAIN.instantiate()
	root.add_child(view)
	await process_frame
	_expect(view.get_node_or_null("Root/Body/MainArea/StorefrontPanel/ShowcasePanel/TaskProgressPanel") != null, "Showcase should declare a stable task progress panel")
	_expect(view.get_node_or_null("StorefrontChallengeDialog") != null, "Storefront should keep contract selection behind the challenge entry")
	view.queue_free()

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
		print("MVP_SELF_CHECK_PASS")
		quit(0)
	else:
		for failure in _failures:
			printerr("MVP_SELF_CHECK_FAIL: %s" % failure)
		quit(1)
