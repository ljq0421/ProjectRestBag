class_name ChallengeTutorialOverlay
extends Control

signal confirm_requested
signal dismiss_requested
signal next_requested

const SAFE_MARGIN := 24.0
const TARGET_PADDING := 0.0
const TARGET_AVOIDANCE_PADDING := 8.0
const ARROW_GAP := 6.0
const MAX_TARGETS := 4

var _targets: Array[Rect2] = []
var _screen_targets: Array[Rect2] = []


func _ready() -> void:
	resized.connect(_reapply_targets_after_resize)
	$HintHost/HintPanel.resized.connect(_layout_hint)
	$HintHost/HintPanel/Margin/Content/ActionRow/DismissButton.pressed.connect(func() -> void: dismiss_requested.emit())
	$HintHost/HintPanel/Margin/Content/ActionRow/ConfirmButton.pressed.connect(func() -> void: confirm_requested.emit())
	$HintHost/HintPanel/Margin/Content/ActionRow/NextButton.pressed.connect(func() -> void: next_requested.emit())


func show_step(step_number: int, total_steps: int, title: String, body: String, targets: Array[Rect2], confirm_text: String = "", replay_mode: bool = false) -> void:
	visible = true
	$HintHost/HintPanel/Margin/Content/StepLabel.text = "%d / %d" % [step_number, total_steps]
	$HintHost/HintPanel/Margin/Content/TitleLabel.text = title
	$HintHost/HintPanel/Margin/Content/BodyLabel.text = body
	var confirm_button: Button = $HintHost/HintPanel/Margin/Content/ActionRow/ConfirmButton
	confirm_button.visible = not confirm_text.is_empty()
	confirm_button.text = confirm_text
	$HintHost/HintPanel/Margin/Content/ActionRow/NextButton.visible = replay_mode
	set_targets(targets)


func set_targets(targets: Array[Rect2]) -> void:
	_screen_targets = targets.duplicate()
	_apply_targets()


func _apply_targets() -> void:
	_targets.clear()
	var visible_rect := Rect2(Vector2.ZERO, size)
	for target in _screen_targets.slice(0, MAX_TARGETS):
		var local_target := _screen_rect_to_local(target)
		var padded := _pixel_aligned_rect(
			local_target.grow(TARGET_PADDING).intersection(visible_rect)
		)
		if padded.has_area():
			_targets.append(padded)
	var material := $VisualOverlay.material as ShaderMaterial
	material.set_shader_parameter("target_count", _targets.size())
	for index in range(MAX_TARGETS):
		var normalized := Vector4()
		if index < _targets.size() and visible_rect.size.x > 0.0 and visible_rect.size.y > 0.0:
			var rect := _targets[index]
			normalized = Vector4(rect.position.x / visible_rect.size.x, rect.position.y / visible_rect.size.y, rect.size.x / visible_rect.size.x, rect.size.y / visible_rect.size.y)
		material.set_shader_parameter("target_%d" % index, normalized)
		var outline := $OutlineHost.get_child(index) as Control
		outline.visible = index < _targets.size()
		if outline.visible:
			outline.position = _targets[index].position
			outline.size = _targets[index].size
	$Arrow.visible = not _targets.is_empty()
	call_deferred("_layout_hint")


func hide_step() -> void:
	visible = false
	_targets.clear()
	_screen_targets.clear()
	$Arrow.visible = false


func is_showing_step() -> bool:
	return visible


func get_hint_rect_for_test() -> Rect2:
	return control_screen_rect($HintHost/HintPanel)


func get_target_rects_for_test() -> Array[Rect2]:
	return _targets.duplicate()


func get_arrow_rect_for_test() -> Rect2:
	return control_screen_rect($Arrow)


func _layout_hint() -> void:
	var hint := $HintHost/HintPanel as Control
	var visible_rect := Rect2(Vector2.ZERO, size)
	var safe := visible_rect.grow(-SAFE_MARGIN)
	var target_union := Rect2(visible_rect.get_center(), Vector2.ZERO)
	if not _targets.is_empty():
		target_union = _targets[0]
		for target in _targets.slice(1):
			target_union = target_union.merge(target)
		target_union = target_union.grow(TARGET_AVOIDANCE_PADDING)
	var candidates := [Vector2(target_union.end.x + 24.0, target_union.position.y), Vector2(target_union.position.x - hint.size.x - 24.0, target_union.position.y), Vector2(target_union.position.x, target_union.end.y + 24.0), Vector2(target_union.position.x, target_union.position.y - hint.size.y - 24.0)]
	var chosen := safe.get_center() - hint.size * 0.5
	for candidate in candidates:
		var candidate_rect := Rect2(candidate, hint.size)
		if safe.encloses(candidate_rect) and not candidate_rect.intersects(target_union):
			chosen = candidate
			break
	hint.position = chosen
	if _targets.is_empty():
		$Arrow.visible = false
		return
	var hint_rect := Rect2(hint.position, hint.size)
	var hint_center := hint_rect.get_center()
	var target_center := target_union.get_center()
	var glyph := _direction_glyph(target_center - hint_center)
	$Arrow.text = glyph
	$Arrow.size = $Arrow.get_combined_minimum_size()
	var hint_edge := _hint_edge_toward(hint_rect, target_center)
	match glyph:
		"→":
			$Arrow.position = hint_edge + Vector2(ARROW_GAP, -$Arrow.size.y * 0.5)
		"←":
			$Arrow.position = hint_edge - Vector2($Arrow.size.x + ARROW_GAP, $Arrow.size.y * 0.5)
		"↓":
			$Arrow.position = hint_edge + Vector2(-$Arrow.size.x * 0.5, ARROW_GAP)
		"↑":
			$Arrow.position = hint_edge - Vector2($Arrow.size.x * 0.5, $Arrow.size.y + ARROW_GAP)


static func control_screen_rect(control: Control) -> Rect2:
	control.force_update_transform()
	return _transform_rect(control.get_screen_transform(), Rect2(Vector2.ZERO, control.size))


static func control_content_screen_rect(control: Control) -> Rect2:
	control.force_update_transform()
	var content_size := control.get_combined_minimum_size()
	if control is RichTextLabel:
		content_size.x = float(control.call("get_content_width"))
		content_size.y = float(control.call("get_content_height"))
	content_size.x = clampf(content_size.x, 1.0, control.size.x)
	content_size.y = clampf(content_size.y, 1.0, control.size.y)
	return _transform_rect(
		control.get_screen_transform(),
		Rect2(Vector2.ZERO, content_size)
	)


func _screen_rect_to_local(screen_rect: Rect2) -> Rect2:
	force_update_transform()
	return _transform_rect(get_screen_transform().affine_inverse(), screen_rect)


func _reapply_targets_after_resize() -> void:
	if visible and not _screen_targets.is_empty():
		call_deferred("_apply_targets")


func _pixel_aligned_rect(rect: Rect2) -> Rect2:
	if not rect.has_area():
		return rect
	var start := rect.position.floor()
	var finish := rect.end.ceil()
	return Rect2(start, finish - start)


static func _transform_rect(transform: Transform2D, rect: Rect2) -> Rect2:
	var top_left := transform * rect.position
	var top_right := transform * Vector2(rect.end.x, rect.position.y)
	var bottom_left := transform * Vector2(rect.position.x, rect.end.y)
	var bottom_right := transform * rect.end
	var transformed := Rect2(top_left, Vector2.ZERO)
	transformed = transformed.expand(top_right)
	transformed = transformed.expand(bottom_left)
	return transformed.expand(bottom_right)


func _direction_glyph(direction: Vector2) -> String:
	if abs(direction.x) >= abs(direction.y):
		return "→" if direction.x >= 0.0 else "←"
	return "↓" if direction.y >= 0.0 else "↑"


func _hint_edge_toward(hint_rect: Rect2, target_center: Vector2) -> Vector2:
	var hint_center := hint_rect.get_center()
	var direction := target_center - hint_center
	if direction.is_zero_approx():
		return hint_center
	var half_size := hint_rect.size * 0.5
	var scale: float = max(
		abs(direction.x) / max(half_size.x, 1.0),
		abs(direction.y) / max(half_size.y, 1.0)
	)
	return hint_center + direction / scale
