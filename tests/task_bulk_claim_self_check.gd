extends SceneTree

const GAME_STATE_PATH := "res://scripts/game_state.gd"
const MAIN_SCENE_PATH := "res://scenes/Main.tscn"
const VIEWPORT_SIZE := Vector2i(1920, 1080)

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = VIEWPORT_SIZE
	var game_state_script := load(GAME_STATE_PATH)
	var packed_scene := load(MAIN_SCENE_PATH)
	if game_state_script == null or packed_scene == null or not packed_scene is PackedScene:
		_fail("Task bulk claim self-check could not load the required scene or state")
		_finish()
		return

	var main: Control = (packed_scene as PackedScene).instantiate()
	main.set("save_path", OS.get_temp_dir().path_join("neighbor_dessert_task_bulk_claim_self_check_save.json"))
	main.set("broken_save_path", OS.get_temp_dir().path_join("neighbor_dessert_task_bulk_claim_self_check_save.broken.json"))
	root.add_child(main)
	await process_frame
	await process_frame

	var state = game_state_script.new_game()
	for feature_id in ["output", "inventory", "research", "craft", "catalog", "list", "rulebook", "arrange", "business", "storefront_manage", "task"]:
		state.unlock_core_feature(feature_id)
	state.level = 1
	state.sync_daily_tasks(Time.get_date_string_from_system(false))
	state.daily_task_selected_ids.assign(["daily_farm_harvest", "daily_product_sales"])
	state.completed_tasks.append("growth_l1_sales_rhythm")
	state.completed_tasks.append("daily_farm_harvest")
	state.pending_notifications.clear()
	main.set("state", state)
	main.set("selected_task_filter", "current")
	main.set("selected_task_id", "growth_l1_sales_rhythm")
	main.call("_refresh_resource_bar")
	main.call("_show_task_global_popup")
	await process_frame
	await process_frame

	var snapshot: Dictionary = load("res://scripts/task_service.gd").build_task_snapshot(state)
	var expected_summary := "成长任务 %d｜支线 %d｜待领取 %d" % [
		int(snapshot.get("current_slot_count", 0)),
		int(snapshot.get("side_slot_count", 0)),
		(snapshot.get("claimable", []) as Array).size()
	]
	var summary := String((main.get_node("GlobalOverlayLayer/OverlayFrame/OverlayHeader/OverlaySummary") as Label).text)
	_expect(summary == expected_summary, "Task summary should exclude retained rewards from active side count")
	var list_panel := main.get_node("GlobalOverlayLayer/OverlayFrame/OverlayModeStack/TaskOverlay/TaskBody/TaskListScroll/TaskListPanel")
	var listed_before := _listed_task_ids(list_panel)
	_expect(listed_before.has("growth_l1_sales_rhythm"), "Current list should retain the claimable growth reward")
	_expect(listed_before.has("growth_l1_leftover_decision"), "Current list should expose the next growth goal")
	var button := main.get_node_or_null("GlobalOverlayLayer/OverlayFrame/OverlayModeStack/TaskOverlay/TaskRewardActions/TaskClaimAllRewardsButton") as Button
	_expect(button != null, "Task overlay should include a one-click claim button")
	if button != null:
		_expect(not button.disabled, "One-click claim button should be enabled for claimable tasks")
		_expect(button.text.find("2") != -1, "One-click claim button should show the claimable task count")
		(main.get_node("TaskPopup") as AcceptDialog).hide()
		var coins_before_claim := int(state.coins)
		button.emit_signal("pressed")
		await process_frame
		_expect(int(state.coins) == coins_before_claim + 185, "One-click claim should grant the growth and retained daily rewards")
	await process_frame
	await process_frame

	_expect(state.get_claimable_tasks().is_empty(), "One-click claim should clear all claimable tasks")
	var task_launcher_button := main.get_node("Root/Body/MainArea/WorkbenchPanel/WorkbenchLauncher/TaskButton") as Button
	var task_badge := task_launcher_button.get_node_or_null("Badge") as Label if task_launcher_button != null else null
	_expect(task_launcher_button != null and task_launcher_button.text.is_empty(), "One-click claim should keep the task launcher icon-only")
	_expect(task_badge != null and not task_badge.visible, "One-click claim should clear the task reward badge")
	_expect((main.get_node("TaskPopup") as AcceptDialog).visible, "One-click claim should show one aggregate notification")
	_expect(state.pending_notifications.is_empty(), "Aggregate notification should replace per-task reward notifications")
	_expect(not _listed_task_ids(list_panel).has("growth_l1_sales_rhythm"), "Bulk-claimed growth reward should disappear from the current list")
	main.queue_free()
	_finish()


func _listed_task_ids(list_panel: Node) -> Array[String]:
	var ids: Array[String] = []
	for child in list_panel.get_children():
		ids.append(String(child.get("_task_id")))
	return ids


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Task bulk claim self-check passed.")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)
