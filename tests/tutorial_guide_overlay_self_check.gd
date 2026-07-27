extends SceneTree

const OVERLAY_SCENE_PATH := "res://scenes/ui/overlays/tutorial_guide_overlay.tscn"

var _failures: Array[String] = []
var _skip_emitted := false
var _acknowledged_emitted := false
var _close_emitted := false
var _restart_emitted := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_expect(ResourceLoader.exists(OVERLAY_SCENE_PATH), "tutorial guide overlay scene should exist")
	if not ResourceLoader.exists(OVERLAY_SCENE_PATH):
		_finish()
		return
	var packed := load(OVERLAY_SCENE_PATH) as PackedScene
	_expect(packed != null, "tutorial guide overlay should load")
	if packed == null:
		_finish()
		return

	var host := Control.new()
	host.size = Vector2(1280, 720)
	root.add_child(host)
	var target := Button.new()
	target.position = Vector2(840, 180)
	target.size = Vector2(120, 44)
	host.add_child(target)
	var overlay := packed.instantiate() as Control
	host.add_child(overlay)
	await process_frame

	_expect(overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE, "overlay body should not consume gameplay input while collapsed")
	_expect(overlay.has_signal("skip_requested"), "overlay should expose skip_requested")
	_expect(overlay.has_signal("dialogue_acknowledged"), "overlay should expose dialogue_acknowledged")
	_expect(overlay.has_signal("close_requested"), "overlay should expose close_requested")
	_expect(overlay.has_signal("restart_requested"), "overlay should expose restart_requested")
	_expect(overlay.has_method("present_step"), "overlay should present one grandma dialogue step")
	_expect(overlay.has_method("present_completion"), "overlay should present completion in the same dialogue panel")
	_expect(overlay.has_method("set_popup_paused"), "overlay should pause behind global popups")

	var icon_button := overlay.get_node_or_null("GrandmaIconButton") as Button
	var dialogue_panel := overlay.get_node_or_null("DialoguePanel") as PanelContainer
	var portrait := overlay.get_node_or_null("DialoguePanel/DialogueContent/PortraitFrame/PortraitSilhouette")
	var speaker_label := overlay.get_node_or_null("DialoguePanel/DialogueContent/DialogueBody/SpeakerRow/SpeakerLabel") as Label
	var step_label := overlay.get_node_or_null("DialoguePanel/DialogueContent/DialogueBody/SpeakerRow/StepLabel") as Label
	var dialogue_label := overlay.get_node_or_null("DialoguePanel/DialogueContent/DialogueBody/DialogueLabel") as Label
	var skip_button := overlay.get_node_or_null("DialoguePanel/DialogueContent/DialogueBody/ActionRow/SkipButton") as Button
	var confirm_button := overlay.get_node_or_null("DialoguePanel/DialogueContent/DialogueBody/ActionRow/ConfirmButton") as Button
	var close_button := overlay.get_node_or_null("DialoguePanel/DialogueContent/DialogueBody/ActionRow/CloseButton") as Button
	var restart_button := overlay.get_node_or_null("DialoguePanel/DialogueContent/DialogueBody/ActionRow/RestartButton") as Button
	var dimmer := overlay.get_node_or_null("Dimmer") as ColorRect

	_expect(icon_button != null, "overlay should declare the collapsed grandma icon button")
	_expect(dialogue_panel != null, "overlay should declare the expanded grandma dialogue panel")
	_expect(portrait != null, "overlay should declare a themed grandma silhouette")
	_expect(speaker_label != null and speaker_label.text == "外婆", "dialogue should identify grandma as the speaker")
	_expect(step_label != null, "dialogue should declare a visible step name")
	_expect(dialogue_label != null and dialogue_label.max_lines_visible == 2, "dialogue copy should be limited to two lines")
	_expect(skip_button != null, "dialogue should include skip current step")
	_expect(confirm_button != null, "dialogue should include an acknowledge button")
	_expect(close_button != null and restart_button != null, "completion should reuse the dialogue panel actions")
	_expect(dimmer != null and dimmer.mouse_filter == Control.MOUSE_FILTER_STOP, "expanded dialogue should block background input")
	if icon_button == null or dialogue_panel == null or confirm_button == null:
		host.queue_free()
		await process_frame
		_finish()
		return

	overlay.connect("skip_requested", func(): _skip_emitted = true)
	overlay.connect("dialogue_acknowledged", func(): _acknowledged_emitted = true)
	overlay.connect("close_requested", func(): _close_emitted = true)
	overlay.connect("restart_requested", func(): _restart_emitted = true)

	var showcase_rect := Rect2(Vector2(40, 70), Vector2(700, 560))
	var entry := {
		"step_name": "种下水稻",
		"dialogue": "很好，种子已经备好了。光靠采购可撑不起一家店，我们去农场把它种下吧。",
		"action_hint": "在农场种下水稻种子，成熟后手动收获大米。",
		"confirm_label": "去农场看看",
	}
	overlay.call("present_step", entry, target, showcase_rect, true)
	await process_frame
	_expect(overlay.visible, "active guide should show the overlay")
	_expect(dialogue_panel.visible, "active dialogue should expand for a new step")
	_expect(not icon_button.visible, "expanded dialogue should hide the grandma icon")
	_expect(dimmer.visible, "expanded dialogue should show the input blocker")
	_expect_equal("dialogue step name", step_label.text, "种下水稻")
	_expect_equal("dialogue body", dialogue_label.text, String(entry.dialogue))
	_expect_equal("dialogue confirm label", confirm_button.text, "去农场看看")
	_expect_close("dialogue matches showcase width", dialogue_panel.size.x, showcase_rect.size.x, 1.0)
	_expect(dialogue_panel.size.y <= 122.0, "dialogue should remain close to the approved 118px height")
	_expect_close("dialogue anchors to showcase left", dialogue_panel.position.x, showcase_rect.position.x, 1.0)
	_expect_close("dialogue anchors inside showcase bottom", dialogue_panel.position.y + dialogue_panel.size.y, showcase_rect.end.y, 1.0)
	var arrow := overlay.get_node("Arrow") as Polygon2D
	_expect(not arrow.visible, "expanded grandma dialogue should hide the target arrow")

	confirm_button.emit_signal("pressed")
	await process_frame
	_expect(_acknowledged_emitted, "confirming grandma dialogue should emit dialogue_acknowledged")
	_expect(not dialogue_panel.visible, "acknowledged dialogue should collapse")
	_expect(icon_button.visible, "collapsed dialogue should leave only the grandma icon")
	_expect(not dimmer.visible, "collapsed grandma icon should restore background input")
	_expect(arrow.visible, "acknowledged dialogue should reveal the valid target arrow")
	_expect(icon_button.size.x <= 52.0 and icon_button.size.y <= 52.0, "grandma icon should stay close to 48 by 48")
	_expect_close("grandma icon anchors to showcase left", icon_button.position.x, showcase_rect.position.x + 12.0, 1.0)
	_expect_close("grandma icon anchors to showcase bottom", icon_button.position.y + icon_button.size.y, showcase_rect.end.y - 12.0, 1.0)

	icon_button.emit_signal("pressed")
	await process_frame
	_expect(dialogue_panel.visible, "clicking the grandma icon should reopen current dialogue")
	_expect(not icon_button.visible, "reopened dialogue should hide the icon")
	_expect(not arrow.visible, "reopened dialogue should hide the target arrow")
	_expect_equal("reopened dialogue uses current action hint", dialogue_label.text, String(entry.action_hint))

	if skip_button != null:
		skip_button.emit_signal("pressed")
		_expect(_skip_emitted, "skip button should emit skip_requested")

	overlay.call("set_popup_paused", true)
	_expect(not overlay.visible, "popup pause should hide grandma dialogue")
	overlay.call("set_popup_paused", false)
	_expect(overlay.visible and dialogue_panel.visible, "closing popup should restore the previously expanded dialogue")
	_expect(not arrow.visible, "restored dialogue should keep the target arrow hidden")

	confirm_button.emit_signal("pressed")
	await process_frame
	_expect(icon_button.visible and arrow.visible, "confirming a reopened dialogue should restore action guidance")
	overlay.call("set_popup_paused", true)
	overlay.call("set_popup_paused", false)
	_expect(icon_button.visible and not dialogue_panel.visible and arrow.visible, "popup pause should restore the previously active action guidance")

	overlay.call("present_step", entry, target, showcase_rect, false)
	await process_frame
	_expect(icon_button.visible and not dialogue_panel.visible and arrow.visible, "an acknowledged step should present icon and target arrow")
	overlay.call("set_popup_paused", true)
	overlay.call("set_popup_paused", false)
	_expect(icon_button.visible and not dialogue_panel.visible and arrow.visible, "popup pause should restore the previously collapsed icon and arrow")
	var clipped_showcase_rect := Rect2(Vector2(-24, 650), Vector2(700, 200))
	overlay.call("present_step", entry, target, clipped_showcase_rect, false)
	await process_frame
	_expect(dialogue_panel.position.x >= 0.0 and dialogue_panel.position.y >= 0.0, "dialogue should clamp its top-left corner inside the viewport")
	_expect(dialogue_panel.position.x + dialogue_panel.size.x <= overlay.size.x, "dialogue should clamp its right edge inside the viewport")
	_expect(dialogue_panel.position.y + dialogue_panel.size.y <= overlay.size.y, "dialogue should clamp its bottom edge inside the viewport")
	_expect(icon_button.position.x >= 0.0 and icon_button.position.y >= 0.0, "grandma icon should clamp inside the viewport")
	_expect(icon_button.position.x + icon_button.size.x <= overlay.size.x and icon_button.position.y + icon_button.size.y <= overlay.size.y, "grandma icon should keep every edge inside the viewport")

	target.queue_free()
	await process_frame
	await process_frame
	_expect(icon_button.visible, "an unavailable target should keep the grandma icon visible during action guidance")
	_expect(not arrow.visible, "an unavailable target should hide the target arrow")

	overlay.call("present_completion", {
		"step_name": "第一轮开店完成",
		"dialogue": "很好，你已经独立走完了第一轮开店流程。",
		"action_hint": "引导已完成。",
		"confirm_label": "结束引导",
	}, showcase_rect)
	await process_frame
	_expect(dialogue_panel.visible and dimmer.visible, "completion should actively open the same dialogue panel")
	_expect(close_button.visible and restart_button.visible, "completion should show close and replay actions")
	_expect(not skip_button.visible and not confirm_button.visible, "completion should hide ordinary step actions")
	_expect(not icon_button.visible and not arrow.visible, "completion should hide the grandma icon and target arrow")
	close_button.emit_signal("pressed")
	restart_button.emit_signal("pressed")
	_expect(_close_emitted, "completion close should emit close_requested")
	_expect(_restart_emitted, "completion replay should emit restart_requested")

	host.queue_free()
	await process_frame
	_finish()


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _expect_equal(label: String, actual: Variant, expected: Variant) -> void:
	_expect(actual == expected, "%s expected %s, got %s" % [label, expected, actual])


func _expect_close(label: String, actual: float, expected: float, tolerance: float) -> void:
	_expect(absf(actual - expected) <= tolerance, "%s expected %s +/- %s, got %s" % [label, expected, tolerance, actual])


func _finish() -> void:
	if _failures.is_empty():
		print("TUTORIAL_GUIDE_OVERLAY_SELF_CHECK_PASS")
		quit(0)
		return
	for failure in _failures:
		printerr("TUTORIAL_GUIDE_OVERLAY_SELF_CHECK_FAIL: %s" % failure)
	quit(1)
