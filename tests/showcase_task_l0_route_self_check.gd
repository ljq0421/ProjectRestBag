extends SceneTree

const GAME_STATE := preload("res://scripts/game_state.gd")
const TASK_SERVICE := preload("res://scripts/task_service.gd")
const TUTORIAL_PROGRESS := preload("res://scripts/tutorial_progress.gd")

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var definitions := TASK_SERVICE.get_task_definitions()
	for removed_id in ["tutorial_l0_first_product", "tutorial_l0_open_shop", "tutorial_l0_first_business", "tutorial_l0_inspect_terms"]:
		_expect(not definitions.has(removed_id), "Removed tutorial task must stay absent: %s" % removed_id)
	for task_value in definitions.values():
		if task_value is Dictionary:
			_expect(String((task_value as Dictionary).get("event", "")) != "showcase_terms_viewed", "Task catalog should not consume sales-term hover events")

	var state = GAME_STATE.new_game()
	state.tutorial_guide_step = TUTORIAL_PROGRESS.STEP_SETTLEMENT
	_expect(not TUTORIAL_PROGRESS.on_business_round_settled(state, _settlement_report(0)), "Zero-sale settlement cannot finish onboarding")
	_expect_equal("Zero-sale settlement stays Lv.0", int(state.level), 0)
	_expect(TUTORIAL_PROGRESS.on_business_round_settled(state, _settlement_report(1)), "A real sale settlement should reach grandma's final dialogue")
	_expect_equal("Settlement still waits for grandma", int(state.level), 0)
	_expect(not state.is_core_feature_unlocked("task"), "Tasks remain locked before grandma confirmation")
	for feature_id in ["output", "inventory", "research", "craft", "catalog", "list", "rulebook", "arrange", "business", "storefront_manage"]:
		state.unlock_core_feature(feature_id)
	_expect(TUTORIAL_PROGRESS.close_guide(state), "Grandma confirmation should finish onboarding")
	_expect_equal("Grandma confirmation enters Lv.1", int(state.level), 1)
	_expect(state.is_core_feature_unlocked("task"), "Grandma confirmation should open tasks")
	_expect(state.completed_tasks.is_empty(), "Onboarding should not fabricate completed task cards")
	_finish()


func _settlement_report(sold: int) -> Dictionary:
	return {"is_complete": true, "report_id": "l0:%d" % sold, "round_id": 1, "duration_ms": 30000, "counts": {"sold": sold}}


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
		print("SHOWCASE_TASK_L0_ROUTE_SELF_CHECK_PASS")
		quit(0)
	else:
		for failure in _failures:
			printerr("SHOWCASE_TASK_L0_ROUTE_SELF_CHECK_FAIL: %s" % failure)
		quit(1)
