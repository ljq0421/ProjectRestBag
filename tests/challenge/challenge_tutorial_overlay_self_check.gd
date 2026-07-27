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

	var popup_host := Control.new()
	popup_host.position = Vector2(600, 300)
	popup_host.size = Vector2(900, 500)
	root.add_child(popup_host)
	var offset_overlay = packed.instantiate()
	offset_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup_host.add_child(offset_overlay)
	await process_frame
	await process_frame
	var offset_targets: Array[Rect2] = [Rect2(720, 420, 180, 100)]
	offset_overlay.show_step(3, 9, "弹窗内目标", "全局目标必须换算为覆盖层局部坐标。", offset_targets)
	await process_frame
	var offset_material := offset_overlay.get_node("VisualOverlay").material as ShaderMaterial
	var offset_uniform: Vector4 = offset_material.get_shader_parameter("target_0")
	_expect(is_equal_approx(offset_uniform.x, 112.0 / 900.0), "offset overlay normalizes target x locally")
	_expect(is_equal_approx(offset_uniform.y, 112.0 / 500.0), "offset overlay normalizes target y locally")
	_expect(is_equal_approx(offset_uniform.z, 196.0 / 900.0), "offset overlay normalizes target width locally")
	_expect(is_equal_approx(offset_uniform.w, 116.0 / 500.0), "offset overlay normalizes target height locally")
	var offset_outline := offset_overlay.get_node("OutlineHost/TargetOutline0") as Control
	_expect(offset_outline.position.is_equal_approx(Vector2(112, 112)), "offset overlay places outline locally")
	_expect(offset_outline.size.is_equal_approx(Vector2(196, 116)), "offset overlay keeps padded outline size")
	_expect(
		Rect2(Vector2(600, 300), Vector2(900, 500)).encloses(offset_overlay.get_hint_rect_for_test()),
		"offset overlay keeps hint inside its visible bounds"
	)

	var below_targets: Array[Rect2] = [Rect2(630, 680, 840, 80)]
	offset_overlay.show_step(4, 9, "下方目标", "箭头应从提示卡边缘指向下方。", below_targets)
	await process_frame
	var below_arrow := offset_overlay.get_node("Arrow") as Control
	_expect(below_arrow.text == "↓", "arrow points downward toward a below target")
	_expect(
		is_equal_approx(
			below_arrow.get_global_rect().get_center().y,
			offset_overlay.get_hint_rect_for_test().end.y
		),
		"arrow sits on the hint edge toward a below target"
	)

	overlay.queue_free()
	second.queue_free()
	popup_host.queue_free()
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
