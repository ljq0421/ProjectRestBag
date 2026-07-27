extends SceneTree

const TASK_OVERLAY := preload("res://scenes/ui/overlays/task_overlay.tscn")
const MAIN := preload("res://scenes/Main.tscn")
const GAME_STATE := preload("res://scripts/game_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var overlay = TASK_OVERLAY.instantiate()
	_expect(overlay.get_node_or_null("TaskRewardTrack") == null, "Task overlay should remove the misleading weekly activity track")
	var script_text := FileAccess.get_file_as_string("res://scripts/ui/overlays/task_overlay.gd")
	_expect(not script_text.contains("本周活跃度"), "Task overlay should not calculate fake weekly activity")
	for label in ["成长任务", "支线任务"]:
		_expect(script_text.contains(label), "Task overlay should declare filter %s" % label)
	for removed_label in ["主线课程", "资源支线"]:
		_expect(not script_text.contains(removed_label), "Task overlay should remove filter %s" % removed_label)
	overlay.free()

	var main = MAIN.instantiate()
	main.set("save_path", OS.get_temp_dir().path_join("showcase_task_overlay_filter_self_check.json"))
	main.set("broken_save_path", OS.get_temp_dir().path_join("showcase_task_overlay_filter_self_check.broken.json"))
	root.add_child(main)
	await process_frame
	await process_frame
	var state = GAME_STATE.new_game()
	for feature_id in ["output", "inventory", "research", "craft", "catalog", "list", "rulebook", "arrange", "business", "storefront_manage", "task"]:
		state.unlock_core_feature(feature_id)
	state.level = 1
	state.record_task_event("business_round_completed", {
		"is_complete": true,
		"report_id": "overlay:sales_rhythm",
		"round_id": 1,
		"duration_ms": 30000,
		"counts": {"sold": 2, "refill_actions": 1},
		"max_product_sold": 2
	})
	main.set("state", state)
	_expect_equal("growth task destination", String(main.call("_task_destination_page", "growth_l1_sales_rhythm")), "storefront_manage")
	main.set("selected_task_filter", "current")
	main.set("selected_task_id", "growth_l1_sales_rhythm")
	main.call("_show_task_global_popup")
	await process_frame
	var list_panel: Node = main.get_node("GlobalOverlayLayer/OverlayFrame/OverlayModeStack/TaskOverlay/TaskBody/TaskListScroll/TaskListPanel")
	var current_ids := _listed_task_ids(list_panel)
	_expect(current_ids.has("growth_l1_sales_rhythm"), "Claimable growth task should stay in the current list")
	_expect(current_ids.has("growth_l1_leftover_decision"), "Next growth goal should appear beside the retained reward")
	var action_button := main.get_node("GlobalOverlayLayer/OverlayFrame/OverlayModeStack/TaskOverlay/TaskBody/TaskDetailPanel/TaskDetailContent/TaskActionButton") as Button
	_expect_equal("claimable detail action", action_button.text, "领取奖励")
	(main.get_node("TaskPopup") as AcceptDialog).hide()
	action_button.emit_signal("pressed")
	await process_frame
	_expect((main.get("state") as Object).call("is_task_reward_claimed", "growth_l1_sales_rhythm"), "claimable detail action should claim the selected reward")
	_expect_equal("claimed task disappears and selects next goal", String(main.get("selected_task_id")), "growth_l1_leftover_decision")
	main.set("selected_task_filter", "side")
	main.set("selected_task_id", "")
	main.call("_show_task_global_popup")
	await process_frame

	for filter_id in ["current", "side"]:
		_expect(_press_filter_button(main, filter_id), "Task overlay should expose filter button %s" % filter_id)
		await process_frame
		_expect_equal("Main accepts filter %s" % filter_id, String(main.get("selected_task_filter")), filter_id)
		_expect(list_panel.get_child_count() > 0, "%s should restore visible task entries" % filter_id)
	var summary := String((main.get_node("GlobalOverlayLayer/OverlayFrame/OverlayHeader/OverlaySummary") as Label).text)
	var task_snapshot: Dictionary = (main.get("state") as Object).call("get_task_snapshot")
	var expected_summary := "成长任务 %d｜支线 %d｜待领取 %d" % [
		int(task_snapshot.get("current_slot_count", 0)),
		int(task_snapshot.get("side_slot_count", 0)),
		(task_snapshot.get("claimable", []) as Array).size()
	]
	_expect_equal("Task summary counts exposed entries", summary, expected_summary)
	var objective_list := main.get_node_or_null("GlobalOverlayLayer/OverlayFrame/OverlayModeStack/TaskOverlay/TaskBody/TaskDetailPanel/TaskDetailContent/TaskObjectiveList")
	_expect(objective_list != null, "Task detail should declare a stable objective list")
	main.queue_free()
	_finish()


func _press_filter_button(main, filter_id: String) -> bool:
	var tabs: Node = main.get_node("GlobalOverlayLayer/OverlayFrame/OverlayModeStack/TaskOverlay/TaskBody/TaskTabs")
	for button_value in tabs.get_children():
		if button_value is Button and String((button_value as Button).get_meta("filter_id", "")) == filter_id:
			(button_value as Button).call("_on_pressed")
			return true
	return false


func _listed_task_ids(list_panel: Node) -> Array[String]:
	var ids: Array[String] = []
	for child in list_panel.get_children():
		ids.append(String(child.get("_task_id")))
	return ids


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
		print("SHOWCASE_TASK_OVERLAY_SELF_CHECK_PASS")
		quit(0)
	else:
		for failure in _failures:
			printerr("SHOWCASE_TASK_OVERLAY_SELF_CHECK_FAIL: %s" % failure)
		quit(1)
