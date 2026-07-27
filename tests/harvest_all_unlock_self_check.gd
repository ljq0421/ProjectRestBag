extends SceneTree

const GAME_STATE_PATH := "res://scripts/game_state.gd"
const TASK_SERVICE_PATH := "res://scripts/task_service.gd"
const MAIN_SCENE_PATH := "res://scenes/Main.tscn"
const TASK_ENTRY_BUTTON_PATH := "res://scripts/ui/overlays/task_entry_button.gd"
const AUTOMATION_SERVICE_PATH := "res://scripts/automation_service.gd"
const PRODUCTION_SITE_PATH := "res://scripts/production_site.gd"
const FEATURE_TASK_ID := "feature_harvest_all"
const FEATURE_ID := "harvest_all"

var _save_path := OS.get_temp_dir().path_join("neighbor_dessert_harvest_all_unlock_self_check.json")
var _broken_save_path := OS.get_temp_dir().path_join("neighbor_dessert_harvest_all_unlock_self_check.broken.json")
var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var game_state_script = load(GAME_STATE_PATH)
	var task_service_script = load(TASK_SERVICE_PATH)
	_expect(game_state_script != null, "GameState should load")
	_expect(task_service_script != null, "TaskService should load")
	if game_state_script == null or task_service_script == null:
		_finish()
		return

	_expect_task_definition(task_service_script)
	_expect_event_index(task_service_script)
	_expect_interleaved_batch_deduplication(game_state_script)
	_expect_automation_does_not_count(game_state_script)
	var unlocked_state = _expect_unlock_progression(game_state_script)
	if unlocked_state != null:
		_expect_save_roundtrip(game_state_script, unlocked_state)
	await _expect_output_ui(game_state_script)
	_finish()


func _expect_task_definition(task_service_script) -> void:
	var definition: Dictionary = task_service_script.get_task_definitions().get(FEATURE_TASK_ID, {})
	_expect(not definition.is_empty(), "task catalog should define feature_harvest_all")
	_expect(String(definition.get("event", "")) == "manual_harvest", "harvest-all task should consume manual_harvest")
	_expect(int(definition.get("goal", 0)) == 30, "harvest-all task should require thirty manual harvests")
	var unlocks: Array = (definition.get("reward", {}) as Dictionary).get("unlock_features", [])
	_expect(unlocks.has(FEATURE_ID), "harvest-all task should reward the harvest_all feature")


func _expect_event_index(task_service_script) -> void:
	_expect(task_service_script.has_method("build_event_index"), "TaskService should expose an event-index builder")
	_expect(task_service_script.has_method("task_ids_for_event"), "TaskService should expose indexed event lookup")
	_expect(task_service_script.has_method("clear_task_caches"), "TaskService should clear definition and event caches together")
	if not task_service_script.has_method("build_event_index") or not task_service_script.has_method("task_ids_for_event"):
		return

	var synthetic := {
		"single": {"id": "single", "event": "alpha", "sort_order": 10},
		"multi": {"id": "multi", "events": ["alpha", "beta"], "sort_order": 20},
		"objective": {
			"id": "objective",
			"sort_order": 30,
			"objectives": [
				{"id": "one", "event": "gamma"},
				{"id": "two", "events": ["alpha", "delta"]}
			]
		}
	}
	var index: Dictionary = task_service_script.call("build_event_index", synthetic)
	_expect(index.get("alpha", []) == ["single", "multi", "objective"], "event index should merge single, multi, and objective subscriptions in task order")
	_expect(index.get("beta", []) == ["multi"], "event index should include secondary multi-event subscriptions")
	_expect(index.get("gamma", []) == ["objective"], "event index should include objective event subscriptions")
	_expect(index.get("delta", []) == ["objective"], "event index should include objective multi-event subscriptions")

	var manual_ids: Array = task_service_script.call("task_ids_for_event", "manual_harvest")
	_expect(manual_ids.has(FEATURE_TASK_ID), "manual_harvest lookup should include feature_harvest_all")
	_expect(not task_service_script.call("task_ids_for_event", "missing_event").size(), "missing events should have no indexed tasks")
	if task_service_script.has_method("clear_task_caches"):
		task_service_script.call("clear_task_caches")
		_expect((task_service_script.call("task_ids_for_event", "manual_harvest") as Array).has(FEATURE_TASK_ID), "event index should rebuild after caches are cleared")


func _expect_interleaved_batch_deduplication(game_state_script) -> void:
	var state = game_state_script.new_game()
	state.record_task_event("manual_harvest", {"harvest_batch_id": "dedupe:a"})
	state.record_task_event("manual_harvest", {"harvest_batch_id": "dedupe:b"})
	state.record_task_event("manual_harvest", {"harvest_batch_id": "dedupe:a"})
	_expect(int(state.task_progress.get(FEATURE_TASK_ID, {}).get("count", 0)) == 2, "interleaved duplicate harvest batches should only count once")
	var restored = game_state_script.from_dict(state.to_dict())
	restored.record_task_event("manual_harvest", {"harvest_batch_id": "dedupe:a"})
	_expect(int(restored.task_progress.get(FEATURE_TASK_ID, {}).get("count", 0)) == 2, "harvest-batch deduplication should survive save roundtrip")


func _expect_automation_does_not_count(game_state_script) -> void:
	var automation_service_script = load(AUTOMATION_SERVICE_PATH)
	var production_site_script = load(PRODUCTION_SITE_PATH)
	var state = game_state_script.new_game()
	state.level = 3
	state.unlock_automation("output")
	state.production_slot_unlocks["farm"] = 1
	state.ingredient_inventory = {"wheat_seed": 1}
	_expect(production_site_script.start_slot(state, "farm", "wheat_seed", 0, 1000), "automation fixture should start one output slot")
	automation_service_script.set_output_site_managed(state, "farm", true)
	automation_service_script.settle(state, 1000, 1080, 7200)
	_expect(state.get_ingredient_count("wheat") > 0, "automation fixture should actually harvest output")
	_expect(not state.task_progress.has(FEATURE_TASK_ID), "automatic and offline harvest settlement should not count as manual harvest")


func _expect_unlock_progression(game_state_script):
	var state = game_state_script.new_game()
	_expect(state.has_method("is_feature_unlocked"), "GameState should query feature unlocks")
	if not state.has_method("is_feature_unlocked"):
		return null
	_expect(not state.call("is_feature_unlocked", FEATURE_ID), "new games should keep one-click harvest locked")

	for index in range(29):
		state.record_task_event("manual_harvest", {"harvest_batch_id": "manual:%d" % index})
	_expect(int(state.task_progress.get(FEATURE_TASK_ID, {}).get("count", 0)) == 29, "twenty-nine manual harvests should produce 29/30 progress")
	_expect(not state.is_task_completed(FEATURE_TASK_ID), "twenty-nine manual harvests should not complete the task")
	_expect(not state.call("is_feature_unlocked", FEATURE_ID), "twenty-nine manual harvests should not unlock one-click harvest")

	state.record_task_event("manual_harvest", {"harvest_batch_id": "manual:29"})
	_expect(state.is_task_completed(FEATURE_TASK_ID), "the thirtieth manual harvest should complete the task")
	_expect(state.call("is_feature_unlocked", FEATURE_ID), "the thirtieth manual harvest should unlock one-click harvest")
	_expect(state.is_task_reward_claimed(FEATURE_TASK_ID), "progression-only unlock should be marked applied automatically")
	_expect(not state.claim_task_reward(FEATURE_TASK_ID), "harvest-all unlock should not require manual reward claiming")
	_expect(not _task_ids(state.get_claimable_tasks()).has(FEATURE_TASK_ID), "harvest-all task should not enter the claimable list")
	_expect(_notifications_contain(state, "一键收获已开放"), "task completion should visibly announce the unlock")

	var notification_count: int = state.pending_notifications.size()
	state.record_task_event("manual_harvest", {"harvest_batch_id": "manual:30"})
	_expect(int(state.task_progress.get(FEATURE_TASK_ID, {}).get("count", 0)) == 30, "completed task progress should remain capped at 30/30")
	_expect(state.pending_notifications.size() == notification_count, "later manual harvests should not repeat the unlock notification")
	return state


func _expect_save_roundtrip(game_state_script, state) -> void:
	var restored = game_state_script.from_dict(state.to_dict())
	_expect(restored.call("is_feature_unlocked", FEATURE_ID), "feature unlock should survive save roundtrip")

	var legacy_data: Dictionary = state.to_dict()
	legacy_data.erase("feature_unlocks")
	var repaired = game_state_script.from_dict(legacy_data)
	_expect(repaired.call("is_feature_unlocked", FEATURE_ID), "completed task should repair a missing feature-unlock field")


func _expect_output_ui(game_state_script) -> void:
	DirAccess.remove_absolute(_save_path)
	DirAccess.remove_absolute(_broken_save_path)
	var packed_scene = load(MAIN_SCENE_PATH)
	_expect(packed_scene is PackedScene, "Main scene should load")
	if not packed_scene is PackedScene:
		return
	var main: Control = (packed_scene as PackedScene).instantiate()
	main.set("save_path", _save_path)
	main.set("broken_save_path", _broken_save_path)
	root.add_child(main)
	await process_frame
	await process_frame
	var applied_task := {"status": "completed", "claim_status": "claimed", "reward": {"unlock_features": [FEATURE_ID]}}
	_expect(String(main.call("_task_claim_status_text", applied_task)) == "已生效", "automatic unlock task status should read applied instead of claimed")
	_expect(String(main.call("_task_claim_status_text", {"status": "completed", "claim_status": "claimable", "reward": {"coins": 10}})) == "待领取", "claimable rewards should still read pending claim")
	var entry_button = load(TASK_ENTRY_BUTTON_PATH).new()
	entry_button.configure(applied_task.merged({"id": FEATURE_TASK_ID, "title": "熟练收获"}), FEATURE_TASK_ID)
	_expect(entry_button.text.find("已生效") != -1, "automatic unlock task entry should read applied")
	entry_button.queue_free()

	var state = game_state_script.new_game()
	state.tutorial_guide_skipped = true
	state.ingredient_inventory = {"rice_seed": 3}
	state.production_slots = [{
		"site_id": "farm",
		"slot_index": 0,
		"item_id": "rice_seed",
		"started_at_unix": 1,
		"duration_seconds": 1,
		"ready_at_unix": 2,
		"ready": true,
		"accelerator_id": ""
	}]
	main.set("state", state)
	main.call("_show_page", "output")
	await process_frame

	var primary_action: Button = main.get("primary_action_button")
	_expect(not primary_action.visible, "one-click harvest button should stay hidden until the feature is unlocked")
	var rice_before: int = int(state.get_ingredient_count("rice"))
	_expect(not bool(main.call("_harvest_all_ready_outputs")), "direct bulk-harvest entry should reject locked use")
	_expect(int(state.get_ingredient_count("rice")) == rice_before, "locked bulk harvest should not change inventory")

	main.call("_select_output_slot", 0, 0)
	_expect(primary_action.visible and primary_action.text == "收获产出", "selecting a ready slot should still expose the manual-harvest action")
	_expect(bool(main.call("_harvest_output_slot", 0)), "single-slot manual harvest should remain available while bulk harvest is locked")
	_expect(int(state.task_progress.get(FEATURE_TASK_ID, {}).get("count", 0)) == 1, "successful single-slot harvest should emit manual_harvest")
	for index in range(1, 30):
		state.record_task_event("manual_harvest", {"harvest_batch_id": "ui:%d" % index})
	main.call("_show_page", "output")
	await process_frame
	_expect(primary_action.visible and primary_action.text == "一键收获", "completed task should reveal the one-click harvest button")
	state.production_slots = [
		{"site_id": "farm", "slot_index": 0, "item_id": "rice_seed", "started_at_unix": 1, "duration_seconds": 1, "ready_at_unix": 2, "ready": true, "accelerator_id": ""},
		{"site_id": "farm", "slot_index": 1, "item_id": "rice_seed", "started_at_unix": 1, "duration_seconds": 1, "ready_at_unix": 2, "ready": true, "accelerator_id": ""}
	]
	var bulk_rice_before: int = int(state.get_ingredient_count("rice"))
	_expect(bool(main.call("_harvest_all_ready_outputs")), "unlocked one-click harvest should harvest multiple ready slots")
	_expect(int(state.get_ingredient_count("rice")) > bulk_rice_before, "one-click harvest should add outputs from ready slots")
	_expect(int(state.task_progress.get(FEATURE_TASK_ID, {}).get("count", 0)) == 30, "one-click harvest should not increase manual-harvest progress")

	main.queue_free()
	await process_frame


func _task_ids(tasks: Array) -> Array[String]:
	var ids: Array[String] = []
	for task_value: Variant in tasks:
		if task_value is Dictionary:
			ids.append(String((task_value as Dictionary).get("id", "")))
	return ids


func _notifications_contain(state, expected: String) -> bool:
	for notification_value: Variant in state.pending_notifications:
		if not notification_value is Dictionary:
			continue
		var notification: Dictionary = notification_value
		if String(notification.get("title", "")).find(expected) != -1 or String(notification.get("body", "")).find(expected) != -1:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("HARVEST_ALL_UNLOCK_SELF_CHECK_PASS")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)
