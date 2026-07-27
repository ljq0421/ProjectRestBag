extends SceneTree

const GAME_STATE := preload("res://scripts/game_state.gd")
const TASK_SERVICE := preload("res://scripts/task_service.gd")
const TUTORIAL_PROGRESS := preload("res://scripts/tutorial_progress.gd")

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var state = GAME_STATE.new_game()
	var current_day := Time.get_date_string_from_system(false)
	state.sync_daily_tasks(current_day)
	var snapshot: Dictionary = TASK_SERVICE.build_task_snapshot(state)
	_expect_equal("Tutorial hides current tasks", (snapshot.get("current_entries", []) as Array).size(), 0)
	_expect_equal("Tutorial hides side tasks", (snapshot.get("side_entries", []) as Array).size(), 0)
	_open_task_system(state)
	state.sync_daily_tasks(current_day)
	snapshot = TASK_SERVICE.build_task_snapshot(state)
	var current_entries: Array = snapshot.get("current_entries", [])
	var side_entries: Array = snapshot.get("side_entries", [])
	_expect_equal("First post-tutorial current entries", current_entries.size(), 2)
	if not current_entries.is_empty():
		_expect_equal("First post-tutorial goal", String((current_entries[0] as Dictionary).get("id", "")), "growth_l1_sales_rhythm")
	_expect(_task_ids(current_entries).has("shop_upgrade_2"), "Shop upgrade remains available beside the growth goal")
	_expect_equal("Visible daily count", _tasks_of_type(side_entries, "daily").size(), 2)
	var visible_feature_ids := _task_ids(_tasks_of_type(side_entries, "feature"))
	for feature_id in ["feature_harvest_all", "feature_restock_all", "feature_make_all", "feature_list_all"]:
		_expect(visible_feature_ids.has(feature_id), "Available feature task should be visible in parallel: %s" % feature_id)
	_expect_equal("Side entries include selected dailies and all available features", side_entries.size(), 2 + visible_feature_ids.size())
	_expect_equal("Current slot count", int(snapshot.get("current_slot_count", -1)), 2)

	var selected_ids := _string_array(state.get("daily_task_selected_ids"))
	_expect_equal("Persisted daily selection count", selected_ids.size(), 2)
	var restored = GAME_STATE.from_dict(state.to_dict())
	restored.sync_daily_tasks(current_day)
	_expect_equal("Daily selection survives save roundtrip", _string_array(restored.get("daily_task_selected_ids")), selected_ids)

	_emit_all_daily_events(state)
	for daily_id in _all_enabled_daily_ids():
		if selected_ids.has(daily_id):
			continue
		_expect(not state.is_task_completed(daily_id), "Unselected daily must not complete: %s" % daily_id)
		_expect(not state.task_progress.has(daily_id), "Unselected daily must not gain progress: %s" % daily_id)

	state.record_task_event("business_round_completed", _sales_rhythm_report())
	var after_first: Dictionary = TASK_SERVICE.build_task_snapshot(state)
	var next_current: Array = after_first.get("current_entries", [])
	_expect(state.get_claimable_tasks().size() >= 1, "Completed growth card should be claimable")
	_expect_equal("Claimable growth card stays above active goals", next_current.size(), 3)
	if next_current.size() >= 2:
		_expect_equal("Claimable growth stays in current list", String((next_current[0] as Dictionary).get("id", "")), "growth_l1_sales_rhythm")
		_expect_equal("Retained growth status", String((next_current[0] as Dictionary).get("status", "")), "completed")
		_expect_equal("Retained growth claim status", String((next_current[0] as Dictionary).get("claim_status", "")), "claimable")
		_expect_equal("Next growth opens below retained reward", String((next_current[1] as Dictionary).get("id", "")), "growth_l1_leftover_decision")
	_expect_equal("Claimable growth does not consume current slot", int(after_first.get("current_slot_count", -1)), 2)
	_expect(state.claim_task_reward("growth_l1_sales_rhythm"), "Retained growth reward should be claimable")
	var after_tutorial_claim: Array = TASK_SERVICE.build_task_snapshot(state).get("current_entries", [])
	_expect_equal("Claimed growth disappears from current list", after_tutorial_claim.size(), 2)
	if not after_tutorial_claim.is_empty():
		_expect_equal("Next goal remains after claim", String((after_tutorial_claim[0] as Dictionary).get("id", "")), "growth_l1_leftover_decision")

	var side_state = GAME_STATE.new_game()
	_open_task_system(side_state)
	side_state.sync_daily_tasks(current_day)
	var side_selected_ids := _string_array(side_state.get("daily_task_selected_ids"))
	if not side_selected_ids.is_empty():
		var completed_daily_id := side_selected_ids[0]
		side_state.completed_tasks.append(completed_daily_id)
		var retained_side_snapshot: Dictionary = TASK_SERVICE.build_task_snapshot(side_state)
		var retained_side_entries: Array = retained_side_snapshot.get("side_entries", [])
		_expect(not retained_side_entries.is_empty(), "Claimable daily stays in side list")
		if not retained_side_entries.is_empty():
			_expect_equal("Claimable daily stays above active side tasks", String((retained_side_entries[0] as Dictionary).get("id", "")), completed_daily_id)
			_expect_equal("Retained daily claim status", String((retained_side_entries[0] as Dictionary).get("claim_status", "")), "claimable")
		_expect(_task_ids(retained_side_entries).has("feature_harvest_all"), "Harvest-all feature task should occupy an active side slot")
		var active_feature_count := _tasks_of_type(retained_side_entries, "feature").size()
		_expect_equal("Side slot count excludes retained daily and includes every feature task", int(retained_side_snapshot.get("side_slot_count", -1)), side_selected_ids.size() - 1 + active_feature_count)
		_expect(side_state.claim_task_reward(completed_daily_id), "Retained daily reward should be claimable")
		_expect(not _task_ids(TASK_SERVICE.build_task_snapshot(side_state).get("side_entries", [])).has(completed_daily_id), "Claimed daily disappears from side list")

	state.sync_daily_tasks("2099-12-31")
	_expect_equal("New day still selects two dailies", _string_array(state.get("daily_task_selected_ids")).size(), 2)
	_expect(state.is_task_completed("growth_l1_sales_rhythm"), "Daily reset must not clear growth completion")

	_finish()


func _open_task_system(state) -> void:
	for feature_id in ["output", "inventory", "research", "craft", "catalog", "list", "rulebook", "arrange", "business", "storefront_manage"]:
		state.unlock_core_feature(feature_id)
	state.tutorial_guide_step = TUTORIAL_PROGRESS.STEP_COMPLETE
	_expect(TUTORIAL_PROGRESS.close_guide(state), "Final grandma confirmation should open tasks")


func _sales_rhythm_report() -> Dictionary:
	return {
		"is_complete": true,
		"report_id": "visibility:sales_rhythm",
		"round_id": 1,
		"duration_ms": 30000,
		"counts": {"sold": 2, "refill_actions": 1},
		"max_product_sold": 2
	}


func _emit_all_daily_events(state) -> void:
	for _index in range(10):
		state.record_task_event("harvest", {"site_id": "farm", "item_id": "rice", "amount": 1})
	for _index in range(8):
		state.record_task_event("harvest", {"site_id": "ranch", "item_id": "milk", "amount": 1})
	for _index in range(5):
		state.record_task_event("harvest", {"site_id": "forest", "item_id": "strawberry", "amount": 1})
	for _index in range(5):
		state.record_task_event("research_attempt", {"device_id": "round_pot"})
	for _index in range(20):
		state.record_task_event("showcase_sale", {"recipe_id": "a", "quantity": 1})
	state.record_task_event("business_result", {
		"sold_count": 0,
		"sales": [
			{"recipe_id": "a", "quantity": 1},
			{"recipe_id": "b", "quantity": 1},
			{"recipe_id": "c", "quantity": 1}
		]
	})


func _all_enabled_daily_ids() -> Array[String]:
	return [
		"daily_farm_harvest",
		"daily_forest_harvest",
		"daily_product_sales",
		"daily_research_attempts",
		"daily_customer_orders",
		"daily_ranch_harvest"
	]


func _tasks_of_type(tasks: Array, task_type: String) -> Array:
	var result: Array = []
	for task_value: Variant in tasks:
		if task_value is Dictionary and String((task_value as Dictionary).get("type", "")) == task_type:
			result.append(task_value)
	return result


func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item: Variant in value:
			result.append(String(item))
	return result


func _task_ids(tasks: Array) -> Array[String]:
	var result: Array[String] = []
	for task_value: Variant in tasks:
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
		print("TASK_VISIBILITY_SELECTION_SELF_CHECK_PASS")
		quit(0)
	else:
		for failure in _failures:
			printerr("TASK_VISIBILITY_SELECTION_SELF_CHECK_FAIL: %s" % failure)
		quit(1)
