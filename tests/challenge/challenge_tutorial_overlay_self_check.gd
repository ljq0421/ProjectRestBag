extends SceneTree

const OVERLAY_PATH := "res://scenes/challenge/challenge_tutorial_overlay.tscn"

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	_expect(ResourceLoader.exists(OVERLAY_PATH), "tutorial overlay scene should exist")
	if not ResourceLoader.exists(OVERLAY_PATH):
		_finish()
		return
	var packed := load(OVERLAY_PATH) as PackedScene
	_expect(packed != null, "tutorial overlay scene should load")
	if packed == null:
		_finish()
		return

	var overlay = packed.instantiate()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(overlay)
	await process_frame
	await process_frame

	_expect(
		overlay.get_node("VisualOverlay").mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"visual layer passes input"
	)
	_expect(
		overlay.get_node("HintHost/HintPanel/Margin/Content/ActionRow/DismissButton").mouse_filter
			== Control.MOUSE_FILTER_STOP,
		"dismiss button receives input"
	)

	var signals := {"confirm": 0, "dismiss": 0, "next": 0}
	overlay.confirm_requested.connect(func() -> void: signals["confirm"] += 1)
	overlay.dismiss_requested.connect(func() -> void: signals["dismiss"] += 1)
	overlay.next_requested.connect(func() -> void: signals["next"] += 1)
	var primary_targets: Array[Rect2] = [Rect2(40, 180, 420, 240)]
	overlay.show_step(
		2,
		9,
		"挑一份挑战备货",
		"把任意配方拖进展示柜。",
		primary_targets,
		"",
		false
	)
	await process_frame
	_expect(overlay.is_showing_step(), "overlay becomes visible")
	_expect(
		Rect2(Vector2.ZERO, Vector2(1920, 1080)).encloses(overlay.get_hint_rect_for_test()),
		"hint remains in viewport"
	)

	overlay.get_node("HintHost/HintPanel/Margin/Content/ActionRow/DismissButton").emit_signal("pressed")
	var empty_targets: Array[Rect2] = []
	overlay.show_step(2, 9, "挑一份挑战备货", "把任意配方拖进展示柜。", empty_targets, "确认", true)
	overlay.get_node("HintHost/HintPanel/Margin/Content/ActionRow/ConfirmButton").emit_signal("pressed")
	overlay.get_node("HintHost/HintPanel/Margin/Content/ActionRow/NextButton").emit_signal("pressed")
	_expect(signals["dismiss"] == 1, "dismiss emits request")
	_expect(signals["confirm"] == 1, "confirm emits request")
	_expect(signals["next"] == 1, "replay next emits request")

	overlay.set_targets(empty_targets)
	await process_frame
	_expect(not overlay.get_node("Arrow").visible, "missing target hides arrow")
	_expect(overlay.get_node("HintHost/HintPanel").visible, "missing target keeps safe hint")

	var second = packed.instantiate()
	second.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(second)
	await process_frame
	var second_targets: Array[Rect2] = [Rect2(1100, 700, 280, 160)]
	second.show_step(1, 9, "另一处目标", "独立材质验证。", second_targets)
	await process_frame
	var first_material := overlay.get_node("VisualOverlay").material as ShaderMaterial
	var second_material := second.get_node("VisualOverlay").material as ShaderMaterial
	_expect(first_material != second_material, "overlay instances use independent shader materials")
	_expect(
		first_material.get_shader_parameter("target_0") != second_material.get_shader_parameter("target_0"),
		"overlay instances keep independent target uniforms"
	)

	overlay.queue_free()
	second.queue_free()
	await process_frame
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition and not _failures.has(message):
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("CHALLENGE_TUTORIAL_OVERLAY_SELF_CHECK_PASS")
		quit(0)
		return
	for message in _failures:
		push_error(message)
	quit(1)
