extends Control

signal skip_requested
signal dialogue_acknowledged
signal close_requested
signal restart_requested

const ARROW_MARGIN := 14.0
const PULSE_DISTANCE := 4.0
const DIALOGUE_HEIGHT := 118.0
const ICON_SIZE := Vector2(48.0, 48.0)
const ICON_MARGIN := 12.0

enum DisplayPhase {
	DIALOGUE,
	ACTION,
	COMPLETION,
}

@onready var dimmer: ColorRect = $Dimmer
@onready var arrow: Polygon2D = $Arrow
@onready var grandma_icon_button: Button = $GrandmaIconButton
@onready var dialogue_panel: PanelContainer = $DialoguePanel
@onready var step_label: Label = $DialoguePanel/DialogueContent/DialogueBody/SpeakerRow/StepLabel
@onready var dialogue_label: Label = $DialoguePanel/DialogueContent/DialogueBody/DialogueLabel
@onready var skip_button: Button = $DialoguePanel/DialogueContent/DialogueBody/ActionRow/SkipButton
@onready var confirm_button: Button = $DialoguePanel/DialogueContent/DialogueBody/ActionRow/ConfirmButton
@onready var close_button: Button = $DialoguePanel/DialogueContent/DialogueBody/ActionRow/CloseButton
@onready var restart_button: Button = $DialoguePanel/DialogueContent/DialogueBody/ActionRow/RestartButton

var _target: Control
var _showcase_rect := Rect2()
var _presented := false
var _popup_paused := false
var _completion := false
var _display_phase := DisplayPhase.DIALOGUE
var _current_step_name := ""
var _dialogue_text := ""
var _action_hint := ""
var _showing_action_hint := false
var _pulse_elapsed := 0.0
var _arrow_anchor := Vector2.ZERO


func _ready() -> void:
	if not grandma_icon_button.pressed.is_connected(_on_grandma_icon_pressed):
		grandma_icon_button.pressed.connect(_on_grandma_icon_pressed)
	if not skip_button.pressed.is_connected(_on_skip_pressed):
		skip_button.pressed.connect(_on_skip_pressed)
	if not confirm_button.pressed.is_connected(_on_confirm_pressed):
		confirm_button.pressed.connect(_on_confirm_pressed)
	if not close_button.pressed.is_connected(_on_close_pressed):
		close_button.pressed.connect(_on_close_pressed)
	if not restart_button.pressed.is_connected(_on_restart_pressed):
		restart_button.pressed.connect(_on_restart_pressed)
	set_process(true)


func present_step(entry: Dictionary, target: Control, showcase_rect: Rect2, expanded: bool) -> void:
	var next_step_name := String(entry.get("step_name", "当前引导"))
	var preserve_action_hint := _presented \
		and not _completion \
		and _current_step_name == next_step_name \
		and _display_phase == DisplayPhase.DIALOGUE \
		and _showing_action_hint
	_presented = true
	_completion = false
	_target = target
	_showcase_rect = showcase_rect
	_apply_entry(entry)
	_showing_action_hint = preserve_action_hint or not expanded
	dialogue_label.text = _action_hint if _showing_action_hint else _dialogue_text
	skip_button.visible = true
	confirm_button.visible = true
	close_button.visible = false
	restart_button.visible = false
	_set_display_phase(DisplayPhase.DIALOGUE if expanded else DisplayPhase.ACTION)
	visible = not _popup_paused
	_update_layout()


func present_completion(entry: Dictionary, showcase_rect: Rect2) -> void:
	_presented = true
	_completion = true
	_target = null
	_showcase_rect = showcase_rect
	_apply_entry(entry)
	_showing_action_hint = false
	dialogue_label.text = _dialogue_text
	skip_button.visible = false
	confirm_button.visible = false
	close_button.visible = true
	restart_button.visible = true
	_set_display_phase(DisplayPhase.COMPLETION)
	visible = not _popup_paused
	_update_layout()


func set_popup_paused(paused: bool) -> void:
	_popup_paused = paused
	visible = _presented and not _popup_paused
	if visible:
		_update_layout()


func hide_guide() -> void:
	_presented = false
	_completion = false
	_display_phase = DisplayPhase.DIALOGUE
	_target = null
	arrow.visible = false
	dimmer.visible = false
	grandma_icon_button.visible = false
	dialogue_panel.visible = false
	visible = false


func is_dialogue_expanded() -> bool:
	return _presented and _display_phase != DisplayPhase.ACTION


func _process(delta: float) -> void:
	if not visible or not _presented:
		return
	_pulse_elapsed += delta
	_update_layout()
	if arrow.visible:
		var pulse := sin(_pulse_elapsed * 5.0) * PULSE_DISTANCE
		arrow.position = _arrow_anchor + Vector2(0.0, pulse).rotated(arrow.rotation)


func _apply_entry(entry: Dictionary) -> void:
	_current_step_name = String(entry.get("step_name", "当前引导"))
	_dialogue_text = String(entry.get("dialogue", entry.get("action_hint", "完成当前引导目标。")))
	_action_hint = String(entry.get("action_hint", _dialogue_text))
	step_label.text = _current_step_name
	confirm_button.text = String(entry.get("confirm_label", "我知道了"))


func _set_display_phase(phase: DisplayPhase) -> void:
	_display_phase = phase
	var dialogue_visible := _display_phase != DisplayPhase.ACTION
	dimmer.visible = dialogue_visible
	dialogue_panel.visible = dialogue_visible
	grandma_icon_button.visible = _display_phase == DisplayPhase.ACTION and _presented
	if _display_phase != DisplayPhase.ACTION:
		arrow.visible = false


func _update_layout() -> void:
	if not _presented:
		return
	var local_showcase_rect := Rect2(_showcase_rect.position - global_position, _showcase_rect.size)
	if local_showcase_rect.size.x <= 0.0 or local_showcase_rect.size.y <= 0.0:
		local_showcase_rect = Rect2(Vector2.ZERO, size)

	var dialogue_size := Vector2(
		minf(local_showcase_rect.size.x, size.x),
		minf(DIALOGUE_HEIGHT, size.y)
	)
	dialogue_panel.size = dialogue_size
	var desired_dialogue_position := Vector2(
		local_showcase_rect.position.x,
		local_showcase_rect.end.y - dialogue_panel.size.y
	)
	dialogue_panel.position = Vector2(
		clampf(desired_dialogue_position.x, 0.0, maxf(0.0, size.x - dialogue_panel.size.x)),
		clampf(desired_dialogue_position.y, 0.0, maxf(0.0, size.y - dialogue_panel.size.y))
	)
	grandma_icon_button.size = ICON_SIZE
	var desired_icon_position := Vector2(
		local_showcase_rect.position.x + ICON_MARGIN,
		local_showcase_rect.end.y - grandma_icon_button.size.y - ICON_MARGIN
	)
	grandma_icon_button.position = Vector2(
		clampf(desired_icon_position.x, 0.0, maxf(0.0, size.x - grandma_icon_button.size.x)),
		clampf(desired_icon_position.y, 0.0, maxf(0.0, size.y - grandma_icon_button.size.y))
	)

	if _display_phase != DisplayPhase.ACTION or not _is_target_available():
		arrow.visible = false
		return
	var target_rect := _target.get_global_rect()
	target_rect.position -= global_position
	var place_above := target_rect.position.y >= 74.0
	arrow.rotation = 0.0 if place_above else PI
	_arrow_anchor = Vector2(
		target_rect.get_center().x,
		target_rect.position.y - ARROW_MARGIN if place_above else target_rect.end.y + ARROW_MARGIN
	)
	arrow.position = _arrow_anchor
	arrow.visible = true


func _is_target_available() -> bool:
	return is_instance_valid(_target) \
		and _target.is_inside_tree() \
		and _target.is_visible_in_tree() \
		and _target.size.x > 0.0 \
		and _target.size.y > 0.0


func _on_grandma_icon_pressed() -> void:
	_showing_action_hint = true
	dialogue_label.text = _action_hint
	_set_display_phase(DisplayPhase.DIALOGUE)
	_update_layout()


func _on_skip_pressed() -> void:
	skip_requested.emit()


func _on_confirm_pressed() -> void:
	dialogue_acknowledged.emit()
	_showing_action_hint = true
	dialogue_label.text = _action_hint
	_set_display_phase(DisplayPhase.ACTION)
	_update_layout()


func _on_close_pressed() -> void:
	close_requested.emit()


func _on_restart_pressed() -> void:
	restart_requested.emit()
