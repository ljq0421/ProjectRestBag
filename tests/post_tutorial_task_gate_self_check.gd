extends SceneTree

const GAME_STATE := preload("res://scripts/game_state.gd")
const TASK_SERVICE := preload("res://scripts/task_service.gd")
const TUTORIAL_PROGRESS := preload("res://scripts/tutorial_progress.gd")
const CORE_FEATURE_UNLOCK_SERVICE := preload("res://scripts/core_feature_unlock_service.gd")

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var during_tutorial = GAME_STATE.new_game()
	_expect(not during_tutorial.is_core_feature_unlocked(CORE_FEATURE_UNLOCK_SERVICE.TASK), "task should stay locked during grandma tutorial")
	_expect(not during_tutorial.is_core_feature_unlocked(CORE_FEATURE_UNLOCK_SERVICE.STARLIGHT), "new game should start with starlight locked")
	_expect(during_tutorial.claim_starlight_reward("self_check:tutorial_first", 1), "first tutorial-time starlight claim should succeed")
	_expect(during_tutorial.is_core_feature_unlocked(CORE_FEATURE_UNLOCK_SERVICE.STARLIGHT), "first tutorial-time claim should open starlight immediately")
	_expect(not during_tutorial.is_core_feature_unlocked(CORE_FEATURE_UNLOCK_SERVICE.TASK), "opening starlight should not open tasks")
	_expect_equal("tutorial-time total starlight", during_tutorial.recipe_starlight_total, 1)
	_expect_equal("tutorial-time available starlight", during_tutorial.recipe_starlight_available, 1)
	_expect(not during_tutorial.claim_starlight_reward("self_check:tutorial_first", 1), "duplicate tutorial-time claim should fail")
	_expect_equal("duplicate claim keeps total starlight", during_tutorial.recipe_starlight_total, 1)
	_expect(not during_tutorial.is_automation_unlocked("output"), "opening starlight should not unlock output automation")
	_expect(not during_tutorial.is_automation_unlocked("kitchen"), "opening starlight should not unlock kitchen automation")

	var definitions := TASK_SERVICE.get_task_definitions()
	for removed_id in ["tutorial_l0_first_product", "tutorial_l0_open_shop", "tutorial_l0_first_business"]:
		_expect(not definitions.has(removed_id), "%s should be deleted" % removed_id)
	var first_growth: Dictionary = definitions.get("growth_l1_sales_rhythm", {})
	_expect((first_growth.get("prerequisites", []) as Array).is_empty(), "first Lv1 growth task should have no deleted prerequisite")

	var state = GAME_STATE.new_game()
	state.level = 1
	var report := {
		"is_complete": true,
		"kind": "standard",
		"duration_ms": 30000,
		"max_product_sold": 2,
		"counts": {"sold": 2, "refill_actions": 1},
	}
	_expect(state.get_active_tasks().is_empty(), "task list should stay empty during grandma tutorial")
	_expect(state.record_task_event("business_round_completed", report).is_empty(), "tutorial events should not update backend tasks")
	_expect(state.task_progress.is_empty(), "tutorial should leave task progress clean")

	for feature_id in CORE_FEATURE_UNLOCK_SERVICE.ORDER:
		if feature_id in [CORE_FEATURE_UNLOCK_SERVICE.TASK, CORE_FEATURE_UNLOCK_SERVICE.STARLIGHT]:
			continue
		if not state.is_core_feature_unlocked(feature_id):
			state.unlock_core_feature(feature_id)
	state.tutorial_guide_step = TUTORIAL_PROGRESS.STEP_COMPLETE
	_expect(TUTORIAL_PROGRESS.close_guide(state), "final grandma confirmation should open tasks")
	var active: Array = state.get_active_tasks()
	_expect(not active.is_empty(), "task list should populate after tutorial")
	if not active.is_empty():
		_expect_equal("first post tutorial task", String((active[0] as Dictionary).get("id", "")), "growth_l1_sales_rhythm")
	state.record_task_event("business_round_completed", report)
	_expect(state.task_progress.has("growth_l1_sales_rhythm"), "post tutorial events should update growth task")
	_expect(not state.is_core_feature_unlocked(CORE_FEATURE_UNLOCK_SERVICE.STARLIGHT), "starlight should still be locked before first claim")
	_expect(state.claim_starlight_reward("self_check:first", 1), "first real starlight claim should succeed")
	_expect(state.is_core_feature_unlocked(CORE_FEATURE_UNLOCK_SERVICE.STARLIGHT), "first real starlight claim should open starlight")

	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error(message)


func _expect_equal(label: String, actual: Variant, expected: Variant) -> void:
	_expect(actual == expected, "%s expected %s, got %s" % [label, expected, actual])


func _finish() -> void:
	if _failures.is_empty():
		print("POST_TUTORIAL_TASK_GATE_SELF_CHECK_PASS")
		quit(0)
		return
	for failure in _failures:
		printerr("POST_TUTORIAL_TASK_GATE_SELF_CHECK_FAIL: %s" % failure)
	quit(1)
