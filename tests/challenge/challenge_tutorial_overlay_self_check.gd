extends SceneTree

const OVERLAY_PATH := "res://scenes/challenge/challenge_tutorial_overlay.tscn"
const ChallengeTutorialOverlay = preload("res://scripts/challenge/ui/challenge_tutorial_overlay.gd")

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
	var primary_arrow := overlay.get_node("Arrow") as Control
	var primary_hint: Rect2 = overlay.get_hint_rect_for_test()
	var primary_arrow_rect: Rect2 = overlay.get_arrow_rect_for_test()
	_expect(primary_arrow.visible and primary_arrow_rect.has_area(), "target step shows a visible arrow")
	_expect(
		primary_arrow.z_index > overlay.get_node("HintHost").z_index,
		"arrow renders above the hint host"
	)
	_expect(not primary_arrow_rect.intersects(primary_hint), "arrow remains fully outside the hint card")

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
	_expect(is_equal_approx(offset_uniform.x, 120.0 / 900.0), "offset overlay normalizes target x locally")
	_expect(is_equal_approx(offset_uniform.y, 120.0 / 500.0), "offset overlay normalizes target y locally")
	_expect(is_equal_approx(offset_uniform.z, 180.0 / 900.0), "offset overlay normalizes target width locally")
	_expect(is_equal_approx(offset_uniform.w, 100.0 / 500.0), "offset overlay normalizes target height locally")
	var offset_outline := offset_overlay.get_node("OutlineHost/TargetOutline0") as Control
	_expect(offset_outline.position.is_equal_approx(Vector2(120, 120)), "offset overlay places outline exactly")
	_expect(offset_outline.size.is_equal_approx(Vector2(180, 100)), "offset overlay keeps exact target size")
	_expect(
		Rect2(Vector2(600, 300), Vector2(900, 500)).encloses(offset_overlay.get_hint_rect_for_test()),
		"offset overlay keeps hint inside its visible bounds"
	)

	var below_targets: Array[Rect2] = [Rect2(630, 680, 840, 80)]
	offset_overlay.show_step(4, 9, "下方目标", "箭头应从提示卡边缘指向下方。", below_targets)
	await process_frame
	await process_frame
	var below_arrow := offset_overlay.get_node("Arrow") as Control
	_expect(below_arrow.text == "↓", "arrow points downward toward a below target")
	_expect(
		below_arrow.get_global_rect().position.y > offset_overlay.get_hint_rect_for_test().end.y,
		"arrow sits fully outside the hint edge toward a below target"
	)

	var viewport := root.get_viewport()
	var original_canvas_transform := viewport.canvas_transform
	viewport.canvas_transform = Transform2D(Vector2(1.25, 0), Vector2(0, 1.25), Vector2(90, 60))
	var stretched_host := Control.new()
	stretched_host.position = Vector2(550, 240)
	stretched_host.size = Vector2(800, 440)
	root.add_child(stretched_host)
	var target_control := Control.new()
	target_control.position = Vector2(100, 100)
	target_control.size = Vector2(160, 80)
	stretched_host.add_child(target_control)
	var stretched_overlay = packed.instantiate()
	stretched_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stretched_host.add_child(stretched_overlay)
	await process_frame
	await process_frame
	var stretched_targets: Array[Rect2] = [ChallengeTutorialOverlay.control_screen_rect(target_control)]
	stretched_overlay.show_step(5, 9, "缩放画布", "get_global_rect 坐标必须保持正确。", stretched_targets)
	await process_frame
	var stretched_material := stretched_overlay.get_node("VisualOverlay").material as ShaderMaterial
	var stretched_uniform: Vector4 = stretched_material.get_shader_parameter("target_0")
	_expect(is_equal_approx(stretched_uniform.x, 100.0 / 800.0), "canvas transform keeps target x in containing canvas")
	_expect(is_equal_approx(stretched_uniform.y, 100.0 / 440.0), "canvas transform keeps target y in containing canvas")
	_expect(is_equal_approx(stretched_uniform.z, 160.0 / 800.0), "canvas transform keeps target width local")
	_expect(is_equal_approx(stretched_uniform.w, 80.0 / 440.0), "canvas transform keeps target height local")
	viewport.canvas_transform = original_canvas_transform

	root.size = Vector2i(1172, 1055)
	viewport.canvas_transform = Transform2D(
		Vector2(0.61, 0.0),
		Vector2(0.0, 0.97),
		Vector2(18.0, 7.0)
	)
	var default_canvas_target := Control.new()
	default_canvas_target.position = Vector2(700, 144)
	default_canvas_target.size = Vector2(1100, 640)
	root.add_child(default_canvas_target)
	var tutorial_layer := CanvasLayer.new()
	root.add_child(tutorial_layer)
	var layered_overlay = packed.instantiate()
	layered_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tutorial_layer.add_child(layered_overlay)
	await process_frame
	await process_frame
	var layered_targets: Array[Rect2] = [
		ChallengeTutorialOverlay.control_screen_rect(default_canvas_target)
	]
	layered_overlay.show_step(
		1,
		9,
		"layer target",
		"default-canvas targets and CanvasLayer overlays share logical coordinates",
		layered_targets
	)
	await process_frame
	var layered_outlines: Array[Rect2] = layered_overlay.get_target_rects_for_test()
	_expect(layered_outlines.size() == 1, "CanvasLayer target remains visible after conversion")
	if layered_outlines.size() == 1:
		_expect(
			layered_outlines[0].position.is_equal_approx(Vector2(700, 144)),
			"CanvasLayer conversion does not shift a right-side target to the left"
		)
		_expect(
			layered_outlines[0].size.is_equal_approx(Vector2(1100, 640)),
			"CanvasLayer conversion keeps target size in logical UI coordinates"
		)

	root.size = Vector2i(1832, 697)
	viewport.canvas_transform = original_canvas_transform
	await process_frame
	await process_frame
	var wide_targets: Array[Rect2] = [
		Rect2(20, 610, 390, 22),
		Rect2(729, 465, 1075, 171)
	]
	layered_overlay.show_step(
		4,
		9,
		"wide targets",
		"the hint must not cover either highlighted region",
		wide_targets
	)
	await process_frame
	await process_frame
	var wide_union := wide_targets[0].merge(wide_targets[1])
	_expect(
		not layered_overlay.get_hint_rect_for_test().intersects(wide_union),
		"wide target unions place the hint in remaining free space"
	)

	var bottom_target := Rect2(20, 667, 1784, 39)
	var bottom_targets: Array[Rect2] = [bottom_target]
	layered_overlay.show_step(
		5,
		9,
		"bottom target",
		"the arrow must stay attached to the hint edge",
		bottom_targets
	)
	await process_frame
	await process_frame
	var layered_hint: Rect2 = layered_overlay.get_hint_rect_for_test()
	var layered_arrow: Rect2 = layered_overlay.get_arrow_rect_for_test()
	var arrow_edge_gap: float = minf(
		minf(
			absf(layered_arrow.end.x - layered_hint.position.x),
			absf(layered_arrow.position.x - layered_hint.end.x)
		),
		minf(
			absf(layered_arrow.end.y - layered_hint.position.y),
			absf(layered_arrow.position.y - layered_hint.end.y)
		)
	)
	_expect(
		arrow_edge_gap <= 4.0,
		"arrow stays attached to the hint card edge"
	)

	root.size = Vector2i(1920, 1080)
	await process_frame

	var report_popup := PopupPanel.new()
	report_popup.min_size = Vector2i(900, 520)
	root.add_child(report_popup)
	var report_content := Control.new()
	report_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	report_popup.add_child(report_content)
	var report_target := Control.new()
	report_target.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	report_content.add_child(report_target)
	var report_overlay = packed.instantiate()
	report_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	report_popup.add_child(report_overlay)
	report_popup.popup(Rect2i(420, 260, 900, 520))
	report_popup.size = Vector2i(900, 520)
	report_target.position = Vector2(50, 170)
	report_target.size = Vector2(240, 100)
	report_target.scale = Vector2(1.15, 0.9)
	await process_frame
	await process_frame
	var report_target_screen := ChallengeTutorialOverlay.control_screen_rect(report_target)
	var report_targets: Array[Rect2] = [report_target_screen]
	report_overlay.show_step(7, 9, "战报目标", "弹窗目标必须以屏幕矩形跨画布换算。", report_targets)
	await process_frame
	var report_outline := report_overlay.get_node("OutlineHost/TargetOutline0") as Control
	var report_outline_screen := ChallengeTutorialOverlay.control_screen_rect(report_outline)
	var report_hint_screen: Rect2 = report_overlay.get_hint_rect_for_test()
	var report_arrow_screen: Rect2 = report_overlay.get_arrow_rect_for_test()
	var viewport_screen := Rect2(Vector2.ZERO, root.get_visible_rect().size)
	_expect(report_outline.visible, "popup target creates a visible outline")
	_expect(
		report_outline_screen.encloses(report_target_screen),
		"popup outline encloses its screen-space report target"
	)
	_expect(
		viewport_screen.encloses(report_hint_screen),
		"popup hint remains in the viewport after screen-space conversion"
	)
	_expect(
		report_arrow_screen.has_area() and viewport_screen.encloses(report_arrow_screen),
		"popup arrow remains visible and in bounds"
	)
	_expect(
		not report_hint_screen.intersects(report_outline_screen),
		"popup hint does not cover its highlighted report target"
	)

	overlay.queue_free()
	second.queue_free()
	popup_host.queue_free()
	stretched_host.queue_free()
	default_canvas_target.queue_free()
	tutorial_layer.queue_free()
	report_popup.queue_free()
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
