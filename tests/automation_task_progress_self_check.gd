extends SceneTree

const GAME_STATE_PATH := "res://scripts/game_state.gd"
const TASK_SERVICE_PATH := "res://scripts/task_service.gd"
const AUTOMATION_OVERLAY_SCENE_PATH := "res://scenes/ui/overlays/automation_overlay.tscn"
const TASK_OVERLAY_SCENE_PATH := "res://scenes/ui/overlays/task_overlay.tscn"
const TASK_ENTRY_BUTTON_SCENE_PATH := "res://scenes/ui/overlays/task_entry_button.tscn"

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var game_state_script := load(GAME_STATE_PATH)
	var task_service_script := load(TASK_SERVICE_PATH)
	_expect(game_state_script != null, "GameState script should load")
	_expect(task_service_script != null, "TaskService script should load")
	if game_state_script == null or task_service_script == null:
		_finish()
		return

	_expect(task_service_script.has_method("format_task_progress_detail"), "TaskService should format detailed automation task progress")
	if task_service_script.has_method("format_task_progress_detail"):
		var state = game_state_script.new_game()
		for index in range(10):
			state.record_task_event("manual_harvest", {"harvest_batch_id": "automation-setup:%d" % index})
		state.level = 3
		state.recipe_starlight_total = 12
		state.record_task_event("harvest", {"site_id": "farm", "item_id": "rice", "amount": 1})
		state.record_task_event("harvest", {"site_id": "ranch", "item_id": "milk", "amount": 1})
		state.record_task_event("output_next_set", {"site_id": "farm", "item_id": "rice_seed"})
		var task: Dictionary = task_service_script.get_task_definitions().get("feature_output_automation", {})
		var progress: Dictionary = state.task_progress.get("feature_output_automation", {})
		_expect(
			task_service_script.format_task_progress_detail(task, progress) == "手动收获 2/6 批｜产地 2/2 类｜下一轮 1/3 次",
			"output automation task should expose all three player-facing progress dimensions"
		)
		var task_overlay = load(TASK_OVERLAY_SCENE_PATH).instantiate()
		var snapshot: Dictionary = task_service_script.build_task_snapshot(state)
		var automation_entries: Array = []
		for entry_value: Variant in task_overlay.call("_task_entries", snapshot, "side"):
			if entry_value is Dictionary and String((entry_value as Dictionary).get("type", "")) == "feature":
				automation_entries.append(entry_value)
		var output_entry := _entry_by_id(automation_entries, "feature_output_automation")
		_expect(not output_entry.is_empty(), "side tasks should include the active output automation task")
		if not output_entry.is_empty():
			var task_entry = load(TASK_ENTRY_BUTTON_SCENE_PATH).instantiate()
			task_entry.call("configure", output_entry, "")
			_expect(task_entry.text.find("手动收获 2/6 批｜产地 2/2 类｜下一轮 1/3 次") != -1, "automation task list entry should show detailed progress")
			task_entry.queue_free()
		task_overlay.queue_free()

		var automation_overlay = load(AUTOMATION_OVERLAY_SCENE_PATH).instantiate()
		root.add_child(automation_overlay)
		await process_frame
		automation_overlay.call("refresh", state)
		var output_status := (automation_overlay.get_node("OutputSection/OutputStatusLabel") as Label).text
		_expect(output_status.find("产地轮转：手动收获 2/6 批｜产地 2/2 类｜下一轮 1/3 次") != -1, "automation hub should show output task progress while locked")
		automation_overlay.queue_free()

	_finish()


func _entry_by_id(entries: Array, task_id: String) -> Dictionary:
	for entry_value: Variant in entries:
		if entry_value is Dictionary and String((entry_value as Dictionary).get("id", "")) == task_id:
			return entry_value
	return {}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Automation task progress self-check passed.")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)
