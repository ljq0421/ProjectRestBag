class_name ChallengeTutorialOverlay
extends Control

signal confirm_requested
signal dismiss_requested
signal next_requested

const SAFE_MARGIN := 24.0
const TARGET_PADDING := 8.0
const MAX_TARGETS := 4

var _targets: Array[Rect2] = []


func _ready() -> void:
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
	_targets.clear()
	var viewport_rect := Rect2(Vector2.ZERO, get_viewport_rect().size)
	for target in targets.slice(0, MAX_TARGETS):
		var padded: Rect2 = target.grow(TARGET_PADDING).intersection(viewport_rect)
		if padded.has_area():
			_targets.append(padded)
	var material := $VisualOverlay.material as ShaderMaterial
	material.set_shader_parameter("target_count", _targets.size())
	for index in range(MAX_TARGETS):
		var normalized := Vector4()
		if index < _targets.size() and viewport_rect.size.x > 0.0 and viewport_rect.size.y > 0.0:
			var rect := _targets[index]
			normalized = Vector4(rect.position.x / viewport_rect.size.x, rect.position.y / viewport_rect.size.y, rect.size.x / viewport_rect.size.x, rect.size.y / viewport_rect.size.y)
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
	$Arrow.visible = false


func is_showing_step() -> bool:
	return visible


func get_hint_rect_for_test() -> Rect2:
	return $HintHost/HintPanel.get_global_rect()


func _layout_hint() -> void:
	var hint := $HintHost/HintPanel as Control
	var viewport_rect := Rect2(Vector2.ZERO, get_viewport_rect().size)
	var safe := viewport_rect.grow(-SAFE_MARGIN)
	var target_union := Rect2(viewport_rect.get_center(), Vector2.ZERO)
	if not _targets.is_empty():
		target_union = _targets[0]
		for target in _targets.slice(1):
			target_union = target_union.merge(target)
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
	var hint_center := hint.get_global_rect().get_center()
	var target_center := target_union.get_center()
	$Arrow.position = (hint_center + target_center) * 0.5 - $Arrow.size * 0.5
	$Arrow.text = "→" if target_center.x >= hint_center.x else "←"
