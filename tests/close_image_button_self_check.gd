extends SceneTree

const CLOSE_BUTTON_SCENE := "res://scenes/ui/common/close_image_button.tscn"
const MAIN_SCENE := "res://scenes/Main.tscn"
const AUTOMATION_OVERLAY_SCENE := "res://scenes/ui/overlays/automation_overlay.tscn"
const AUTOMATION_REPORT_SCENE := "res://scenes/ui/overlays/automation_report_dialog.tscn"
const RULEBOOK_SCENE := "res://scenes/ui/overlays/showcase_rulebook_dialog.tscn"
const SETTLEMENT_SCENE := "res://scenes/ui/overlays/showcase_round_settlement_dialog.tscn"

const TEXTURE_PATHS := {
	"normal": "res://resources/ui/skin_v1/close_large_normal.png",
	"hover": "res://resources/ui/skin_v1/close_large_hover.png",
	"pressed": "res://resources/ui/skin_v1/close_large_pressed.png",
	"selected": "res://resources/ui/skin_v1/close_large_selected.png"
}

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	_check_texture_files()
	await _check_button_states()
	_check_scene_contracts()
	await _check_global_close_geometry()
	await _check_dialog_closes()
	_finish()


func _check_texture_files() -> void:
	for state: String in TEXTURE_PATHS:
		var path: String = TEXTURE_PATHS[state]
		var texture := load(path) as Texture2D
		if texture == null:
			_fail("%s texture should load: %s" % [state, path])
			continue
		_expect_equal(texture.get_size(), Vector2(176, 180), "%s texture keeps the approved canvas" % state)
		var image := texture.get_image()
		if image == null:
			_fail("%s texture should expose image data for alpha validation" % state)
		else:
			_expect_close(image.get_pixel(0, 0).a, 0.0, 0.001, "%s texture keeps a transparent corner" % state)


func _check_button_states() -> void:
	var packed := load(CLOSE_BUTTON_SCENE) as PackedScene
	if packed == null:
		_fail("close image button scene should load")
		return
	var button := packed.instantiate() as Button
	root.add_child(button)
	await process_frame

	_expect_texture(button, "normal")
	button.mouse_entered.emit()
	_expect_texture(button, "hover")
	button.button_down.emit()
	_expect_texture(button, "pressed")
	button.button_up.emit()
	button.grab_focus()
	await process_frame
	_expect_texture(button, "selected")
	button.release_focus()
	button.mouse_exited.emit()
	_expect_texture(button, "normal")

	_expect_equal(button.text, "", "close image button should not render text")
	_expect_equal(button.tooltip_text, "关闭", "close image button should keep an accessible tooltip")
	_expect_equal(button.custom_minimum_size, Vector2(48, 48), "close image button keeps the approved 48 by 48 hit area")
	button.queue_free()


func _check_scene_contracts() -> void:
	var main := (load(MAIN_SCENE) as PackedScene).instantiate()
	var global_button := main.get_node_or_null("GlobalOverlayLayer/OverlayCloseButton") as Button
	if global_button == null:
		_fail("global overlay should own its close button directly")
	else:
		_expect_component_script(global_button, "global overlay")
		_expect_equal(global_button.get_parent().name, "GlobalOverlayLayer", "global close button anchors to the outer overlay shell")
		_expect_equal(global_button.custom_minimum_size, Vector2(48, 48), "global close button keeps the approved size")
	_expect_equal(main.get_node_or_null("GlobalOverlayLayer/OverlayFrame/OverlayHeader/OverlayCloseButton"), null, "overlay header no longer owns a drifting close button")
	main.free()

	var automation := (load(AUTOMATION_OVERLAY_SCENE) as PackedScene).instantiate()
	_expect_equal(automation.get_node_or_null("Footer/CloseButton"), null, "automation footer removes the duplicate close button")
	_expect_equal(automation.has_signal("close_requested"), true, "automation overlay keeps its public close signal contract")
	automation.free()


func _check_global_close_geometry() -> void:
	var main := (load(MAIN_SCENE) as PackedScene).instantiate() as Control
	root.add_child(main)
	await process_frame
	var overlay_layer := main.get_node("GlobalOverlayLayer") as Control
	var close_button := overlay_layer.get_node("OverlayCloseButton") as Button
	for viewport_size in [Vector2i(1920, 1080), Vector2i(1280, 720)]:
		root.size = viewport_size
		await process_frame
		for mode in ["catalog", "storefront_manage", "task"]:
			main.call("_apply_global_overlay_layout", mode)
			await process_frame
			_assert_outer_close_geometry(overlay_layer.get_global_rect(), close_button, "global %s at %s" % [mode, viewport_size])
	await _check_task_popup_ok_only(main)
	main.queue_free()
	await process_frame


func _check_task_popup_ok_only(main: Control) -> void:
	var popup := main.get_node("TaskPopup") as AcceptDialog
	var title_label := popup.get_node("TaskPopupContent/TitleLabel") as Label
	var body_label := popup.get_node("TaskPopupContent/BodyLabel") as Label
	_expect_equal(popup.borderless, true, "task notifications remove the native title-bar close button")
	_expect_equal(popup.get_ok_button().visible, true, "task notifications keep OK as the only close action")
	_expect_equal(popup.get_label().visible, false, "task notifications hide the duplicate native body label")
	_expect_equal(popup.find_child("CloseButton", true, false), null, "task notifications do not add an image close button")
	for child in main.get_children():
		if child is Window:
			(child as Window).hide()
	var view_state = main.get("state")
	view_state.pending_notifications.clear()
	view_state.pending_automation_report.clear()
	view_state.enqueue_notification("成长目标完成", "继续经营或提升店铺等级。")
	main.call("_show_next_notification")
	await process_frame
	_expect_equal(popup.visible, true, "task notification should open")
	_expect_equal(title_label.text, "成长目标完成", "task notification keeps its dynamic title in the content area")
	_expect_equal(body_label.text, "继续经营或提升店铺等级。", "task notification keeps its body in the content area")
	popup.get_ok_button().pressed.emit()
	await process_frame
	_expect_equal(popup.visible, false, "task notification OK closes the popup")


func _check_dialog_closes() -> void:
	await _check_rulebook_close()
	await _check_report_close()
	await _check_settlement_close()


func _check_rulebook_close() -> void:
	var dialog := (load(RULEBOOK_SCENE) as PackedScene).instantiate() as AcceptDialog
	root.add_child(dialog)
	await process_frame
	_expect_equal(dialog.borderless, true, "rulebook removes the duplicate native title-bar close button")
	_expect_equal(dialog.get_ok_button().visible, false, "rulebook hides the old bottom close button")
	var close_button := dialog.get_node_or_null("DialogChrome/CloseButton") as Button
	if close_button == null:
		_fail("rulebook should declare a top-right close image button")
	else:
		_expect_component_script(close_button, "rulebook")
		await _show_and_check_dialog_at_viewports(dialog, close_button, Vector2i(980, 720), "rulebook")
		close_button.pressed.emit()
		await process_frame
		_expect_equal(dialog.visible, false, "rulebook image close button hides the dialog")
	dialog.queue_free()
	await process_frame


func _check_report_close() -> void:
	var dialog := (load(AUTOMATION_REPORT_SCENE) as PackedScene).instantiate() as AcceptDialog
	root.add_child(dialog)
	await process_frame
	_expect_equal(dialog.borderless, true, "automation report removes the native title-bar close button")
	_expect_equal(dialog.get_ok_button().visible, true, "automation report keeps its semantic bottom confirmation")
	var close_button := dialog.get_node_or_null("DialogChrome/CloseButton") as Button
	if close_button == null:
		_fail("automation report should declare a top-right close image button")
	else:
		_expect_component_script(close_button, "automation report")
		await _show_and_check_dialog_at_viewports(dialog, close_button, Vector2i(720, 600), "automation report")
		var close_event := [false]
		dialog.close_requested.connect(func() -> void: close_event[0] = true)
		close_button.pressed.emit()
		await process_frame
		_expect_equal(dialog.visible, false, "automation report image close button hides the dialog")
		_expect_equal(close_event[0], true, "automation report image close button forwards close_requested")
	dialog.queue_free()
	await process_frame


func _check_settlement_close() -> void:
	var dialog := (load(SETTLEMENT_SCENE) as PackedScene).instantiate() as ConfirmationDialog
	root.add_child(dialog)
	await process_frame
	_expect_equal(dialog.borderless, true, "settlement removes the native title-bar close button")
	_expect_equal(dialog.get_ok_button().visible, true, "settlement keeps its semantic confirmation button")
	var close_button := dialog.get_node_or_null("DialogChrome/CloseButton") as Button
	if close_button == null:
		_fail("settlement should declare a top-right close image button")
	else:
		_expect_component_script(close_button, "settlement")
		await _show_and_check_dialog_at_viewports(dialog, close_button, Vector2i(840, 660), "settlement")
		var close_event := [false]
		dialog.close_requested.connect(func() -> void: close_event[0] = true)
		close_button.pressed.emit()
		await process_frame
		_expect_equal(dialog.visible, false, "settlement image close button hides without confirming")
		_expect_equal(close_event[0], true, "settlement image close button forwards close_requested")
	dialog.queue_free()
	await process_frame


func _show_and_check_dialog_at_viewports(dialog: Window, close_button: Button, popup_size: Vector2i, label: String) -> void:
	for viewport_size in [Vector2i(1920, 1080), Vector2i(1280, 720)]:
		root.size = viewport_size
		dialog.popup_centered(popup_size)
		await process_frame
		_assert_dialog_close_geometry(dialog, close_button, "%s at %s" % [label, viewport_size])
		dialog.hide()
		await process_frame
	dialog.popup_centered(popup_size)
	await process_frame


func _assert_dialog_close_geometry(dialog: Window, close_button: Button, label: String) -> void:
	_expect_equal(close_button.size, Vector2(48, 48), "%s close button keeps the approved rendered size" % label)
	var right_gap := float(dialog.size.x) - close_button.position.x - close_button.size.x
	_expect_close(right_gap, 16.0, 1.0, "%s close button stays 16 px from the right edge" % label)
	_expect_close(close_button.position.y, 16.0, 1.0, "%s close button stays 16 px from the top edge" % label)


func _assert_outer_close_geometry(outer_rect: Rect2, close_button: Button, label: String) -> void:
	var button_rect := close_button.get_global_rect()
	_expect_equal(close_button.size, Vector2(48, 48), "%s close button keeps the approved rendered size" % label)
	_expect_close(outer_rect.end.x - button_rect.end.x, 16.0, 1.0, "%s close button stays 16 px from the right edge" % label)
	_expect_close(button_rect.position.y - outer_rect.position.y, 16.0, 1.0, "%s close button stays 16 px from the top edge" % label)


func _expect_texture(button: Button, state: String) -> void:
	if button.icon == null:
		_fail("%s state should provide an icon" % state)
		return
	_expect_equal(button.icon.resource_path, TEXTURE_PATHS[state], "%s state uses the approved texture" % state)


func _expect_component_script(button: Button, owner_label: String) -> void:
	var script := button.get_script() as Script
	if script == null:
		_fail("%s close button should have the four-state component script" % owner_label)
		return
	_expect_equal(script.resource_path, "res://scripts/ui/common/close_image_button.gd", "%s uses the four-state close component" % owner_label)


func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_fail("%s; expected=%s actual=%s" % [message, expected, actual])


func _expect_close(actual: float, expected: float, tolerance: float, message: String) -> void:
	if absf(actual - expected) > tolerance:
		_fail("%s; expected=%.2f actual=%.2f" % [message, expected, actual])


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("CLOSE_IMAGE_BUTTON_SELF_CHECK_PASS")
		quit(0)
		return
	for failure: String in _failures:
		printerr("CLOSE_IMAGE_BUTTON_SELF_CHECK_FAIL: %s" % failure)
	quit(1)
