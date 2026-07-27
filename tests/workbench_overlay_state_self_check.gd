extends SceneTree

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const VIEWPORT_SIZE := Vector2i(1920, 1080)

var _failures: Array[String] = []
var _save_path := OS.get_temp_dir().path_join("workbench_overlay_state_self_check.json")


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
	state.tutorial_guide_skipped = true
	for feature_id in ["output", "inventory", "research", "craft", "catalog", "list", "rulebook", "arrange", "business", "storefront_manage", "task", "starlight"]:
		state.unlock_core_feature(feature_id)
	state.unlock_device("round_pot")
	view.call("_refresh_core_feature_access")
	view.call("_refresh_tutorial_guide")
	await process_frame

	var production := view.get_node_or_null("Root/Body/MainArea/WorkbenchPanel/ProductionWorkbench") as Control
	var purchase_button := view.get_node_or_null("Root/Body/MainArea/WorkbenchPanel/WorkbenchLauncher/PurchaseButton") as Button
	var overlay_layer := view.get_node_or_null("GlobalOverlayLayer") as Control
	var backdrop := view.get_node_or_null("GlobalPopupBackdrop") as Control
	_expect_equal("production workbench exists", production != null, true)
	_expect_equal("purchase launcher exists", purchase_button != null, true)

	var selected_materials: Array[String] = ["rice", "spring_water"]
	view.set("selected_research_material_ids", selected_materials)
	view.set("selected_research_tool_id", "round_pot")
	var modes := [
		["StarlightButton", "automation", "AutomationOverlay"],
		["TaskButton", "task", "TaskOverlay"],
		["InventoryButton", "inventory", "InventoryOverlay"],
		["CatalogButton", "catalog", "CatalogOverlay"],
		["ResearchButton", "research", "ResearchOverlay"],
		["PurchaseButton", "purchase", "PurchaseOverlay"],
		["OutputButton", "output", "OutputOverlay"],
		["StorefrontManageButton", "storefront_manage", "StorefrontManageOverlay"],
	]
	for mode_index in range(modes.size()):
		var mode_entry: Array = modes[mode_index]
		var button_name := String(mode_entry[0])
		var expected_mode := String(mode_entry[1])
		var content_name := String(mode_entry[2])
		var button := view.get_node_or_null("Root/Body/MainArea/WorkbenchPanel/WorkbenchLauncher/%s" % button_name) as Button
		var content := view.get_node_or_null("GlobalOverlayLayer/OverlayFrame/OverlayModeStack/%s" % content_name) as Control
		_expect_equal("%s launcher exists" % expected_mode, button != null, true)
		_expect_equal("%s content exists" % expected_mode, content != null, true)
		if button == null:
			continue
		await _click_viewport_position(button.get_global_rect().get_center())
		_expect_equal("%s mode opens" % expected_mode, String(view.get("global_popup_mode")), expected_mode)
		_expect_equal("%s uses global overlay" % expected_mode, overlay_layer != null and overlay_layer.visible, true)
		_expect_equal("%s uses backdrop" % expected_mode, backdrop != null and backdrop.visible, true)
		_expect_equal("%s content becomes visible" % expected_mode, content != null and content.visible, true)
		_expect_equal("production remains visible behind %s" % expected_mode, production != null and production.visible, true)
		_expect_equal("research selection survives %s open" % expected_mode, view.get("selected_research_material_ids"), selected_materials)
		_expect_equal("research tool survives %s open" % expected_mode, String(view.get("selected_research_tool_id")), "round_pot")

		var next_entry: Array = modes[(mode_index + 1) % modes.size()]
		var next_button_name := String(next_entry[0])
		var next_mode := String(next_entry[1])
		var next_content_name := String(next_entry[2])
		var next_button := view.get_node_or_null("Root/Body/MainArea/WorkbenchPanel/WorkbenchLauncher/%s" % next_button_name) as Button
		var next_content := view.get_node_or_null("GlobalOverlayLayer/OverlayFrame/OverlayModeStack/%s" % next_content_name) as Control
		_expect_equal("%s switch launcher exists" % next_mode, next_button != null, true)
		if next_button == null:
			view.call("_close_global_popup")
			continue
		await _click_viewport_position(next_button.get_global_rect().get_center())
		_expect_equal("%s switches directly to %s" % [expected_mode, next_mode], String(view.get("global_popup_mode")), next_mode)
		_expect_equal("global overlay stays open while switching to %s" % next_mode, overlay_layer != null and overlay_layer.visible, true)
		_expect_equal("%s content becomes visible after switch" % next_mode, next_content != null and next_content.visible, true)
		_expect_equal("research selection survives switch to %s" % next_mode, view.get("selected_research_material_ids"), selected_materials)

		await _click_viewport_position(next_button.get_global_rect().get_center())
		_expect_equal("second %s click closes the mode" % next_mode, String(view.get("global_popup_mode")), "")
		_expect_equal("global overlay closes after %s" % next_mode, overlay_layer != null and not overlay_layer.visible, true)
		_expect_equal("research selection survives %s close" % next_mode, view.get("selected_research_material_ids"), selected_materials)

	await _click_viewport_position(purchase_button.get_global_rect().get_center())
	_expect_equal("purchase reopens before backdrop check", String(view.get("global_popup_mode")), "purchase")
	var backdrop_click_position := Vector2(50.0, 100.0)
	_expect_equal("backdrop check position is inside backdrop", backdrop != null and backdrop.get_global_rect().has_point(backdrop_click_position), true)
	await _click_viewport_position(backdrop_click_position)
	_expect_equal("ordinary backdrop click still closes the mode", String(view.get("global_popup_mode")), "")

	view.call("_open_workbench_destination", "output")
	await process_frame
	_expect_equal("destination route opens output overlay", String(view.get("global_popup_mode")), "output")
	view.call("_open_workbench_destination", "research")
	await process_frame
	_expect_equal("research destination opens the research overlay", String(view.get("global_popup_mode")), "research")
	_expect_equal("destination routing preserves research selection", view.get("selected_research_material_ids"), selected_materials)
	view.call("_open_workbench_destination", "production")
	await process_frame
	_expect_equal("production destination closes the overlay", String(view.get("global_popup_mode")), "")

	view.queue_free()
	_cleanup_save()
	_finish()


func _click_viewport_position(position: Vector2) -> void:
	var hover := InputEventMouseMotion.new()
	hover.position = position
	hover.global_position = position
	Input.parse_input_event(hover)
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


func _expect_equal(label: String, actual: Variant, expected: Variant) -> void:
	if actual != expected:
		_fail("%s expected %s, got %s" % [label, expected, actual])


func _cleanup_save() -> void:
	for path in [_save_path, _save_path + ".broken"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("WORKBENCH_OVERLAY_STATE_SELF_CHECK_PASS")
		quit(0)
	else:
		for failure in _failures:
			printerr("WORKBENCH_OVERLAY_STATE_SELF_CHECK_FAIL: %s" % failure)
		quit(1)
