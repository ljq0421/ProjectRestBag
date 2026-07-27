extends SceneTree

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const VIEWPORT_SIZE := Vector2i(1920, 1080)

var _failures: Array[String] = []
var _save_path := OS.get_temp_dir().path_join("research_overlay_production_workbench_self_check.json")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = VIEWPORT_SIZE
	var view := MAIN_SCENE.instantiate()
	view.set("save_path", _save_path)
	view.set("broken_save_path", _save_path + ".broken")
	root.add_child(view)
	await process_frame
	await process_frame

	var state = view.get("state")
	for feature_id in ["research", "craft", "list"]:
		state.unlock_core_feature(feature_id)
	state.unlock_feature("research_make_all")
	state.unlock_feature("research_list_all")
	view.call("_refresh_core_feature_access")
	view.call("_refresh_current_page")
	await process_frame
	await process_frame

	var production := view.get_node_or_null("Root/Body/MainArea/WorkbenchPanel/ProductionWorkbench") as Control
	var queue_rows := view.get_node_or_null("Root/Body/MainArea/WorkbenchPanel/ProductionWorkbench/QueueScroll/QueueRows") as VBoxContainer
	var search_field := view.get_node_or_null("Root/Body/MainArea/WorkbenchPanel/ProductionWorkbench/ProductionQueueHeader/SearchField") as LineEdit
	var bulk_button := view.get_node_or_null("Root/Body/MainArea/WorkbenchPanel/ProductionWorkbench/ProductionQueueHeader/BulkActionButton") as MenuButton
	var schedule_button := view.get_node_or_null("Root/Body/MainArea/WorkbenchPanel/ProductionWorkbench/ProductionQueueHeader/KitchenScheduleButton") as Button
	var schedule_overlay := view.get_node_or_null("GlobalOverlayLayer/OverlayFrame/OverlayModeStack/KitchenScheduleOverlay") as Control
	var kitchen := view.get_node_or_null("GlobalOverlayLayer/OverlayFrame/OverlayModeStack/KitchenScheduleOverlay/KitchenAutomationPanel") as Control
	var research_overlay := view.get_node_or_null("GlobalOverlayLayer/OverlayFrame/OverlayModeStack/ResearchOverlay") as Control
	var research_action := view.get_node_or_null("GlobalOverlayLayer/OverlayFrame/OverlayModeStack/ResearchOverlay/ActionRow/ResearchActionButton") as Button
	var research_grid := view.get_node_or_null("GlobalOverlayLayer/OverlayFrame/OverlayModeStack/ResearchOverlay/ResearchInputBar/InventoryGrid") as GridContainer
	var research_button := view.get_node_or_null("Root/Body/MainArea/WorkbenchPanel/WorkbenchLauncher/ResearchButton") as Button

	_expect(production != null and production.visible, "production workbench should remain visible")
	_expect(queue_rows != null, "production workbench should keep the unified queue")
	_expect(search_field != null and bulk_button != null, "production workbench should expose search and bulk actions in its header")
	_expect(production.get_node_or_null("RecipeScroll") == null, "production workbench should remove the legacy recipe scroll")
	_expect(production.get_node_or_null("RecipeEntryBar") == null, "production workbench should remove the old recipe-entry footer")
	_expect(production.get_node_or_null("KitchenAutomationPanel") == null, "production workbench should move the kitchen scheduler")
	_expect(view.get_node_or_null("GlobalOverlayLayer/OverlayFrame/OverlayModeStack/ProductionRecipePickerOverlay") == null, "old production picker should be absent")
	_expect(schedule_overlay != null and kitchen != null, "kitchen scheduler should live in the unified overlay stack")
	_expect(research_overlay != null, "research should live in the unified overlay stack")
	_expect(research_action != null, "research overlay should own the research action")
	_expect(research_button != null, "launcher should expose the research entry")
	_expect(view.get_node_or_null("Root/Body/MainArea/WorkbenchPanel/ResearchWorkbench") == null, "old mixed research workbench should be absent")

	if search_field != null:
		search_field.text = "米"
		search_field.text_changed.emit(search_field.text)
		await process_frame
		_expect(String(view.get("global_popup_mode")).is_empty(), "queue search should not open a popup")
	if schedule_button != null:
		schedule_button.emit_signal("pressed")
		await process_frame
		_expect(String(view.get("global_popup_mode")) == "kitchen_schedule", "schedule entry should open kitchen schedule mode")
		_expect(schedule_overlay != null and schedule_overlay.visible, "kitchen schedule should become visible")
		view.call("_close_global_popup")
		await process_frame

	if research_button != null:
		research_button.emit_signal("pressed")
		await process_frame
		_expect(String(view.get("global_popup_mode")) == "research", "research launcher signal should open research mode")
		_expect(research_overlay != null and research_overlay.visible, "research content should become visible")
		_expect(research_grid != null and research_grid.get_child_count() == 6, "research overlay should expose six material slots")
		_expect(production != null and production.visible, "production should remain visible behind research")
		research_button.emit_signal("pressed")
		await process_frame
		_expect(String(view.get("global_popup_mode")).is_empty(), "second research launcher click should close research mode")
		_expect(production != null and production.visible, "production should remain visible after research closes")

	view.queue_free()
	_cleanup()
	_finish()


func _click(position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	Input.parse_input_event(motion)
	await process_frame
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = position
	press.global_position = position
	Input.parse_input_event(press)
	await process_frame
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = position
	release.global_position = position
	Input.parse_input_event(release)
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error(message)


func _cleanup() -> void:
	for path in [_save_path, _save_path + ".broken"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _finish() -> void:
	if _failures.is_empty():
		print("RESEARCH_OVERLAY_PRODUCTION_WORKBENCH_SELF_CHECK_PASS")
		quit(0)
		return
	for failure in _failures:
		printerr("RESEARCH_OVERLAY_PRODUCTION_WORKBENCH_SELF_CHECK_FAIL: %s" % failure)
	quit(1)
