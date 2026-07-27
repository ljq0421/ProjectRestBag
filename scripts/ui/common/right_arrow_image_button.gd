class_name PaginationArrowImageButton
extends Button

const RIGHT_NORMAL_TEXTURE := preload("res://resources/ui/skin_v1/arrow_right_normal.png")
const RIGHT_HOVER_TEXTURE := preload("res://resources/ui/skin_v1/arrow_right_hover.png")
const RIGHT_PRESSED_TEXTURE := preload("res://resources/ui/skin_v1/arrow_right_pressed.png")
const RIGHT_SELECTED_TEXTURE := preload("res://resources/ui/skin_v1/arrow_right_selected.png")
const LEFT_NORMAL_TEXTURE := preload("res://resources/ui/skin_v1/arrow_left_normal.png")
const LEFT_HOVER_TEXTURE := preload("res://resources/ui/skin_v1/arrow_left_hover.png")
const LEFT_PRESSED_TEXTURE := preload("res://resources/ui/skin_v1/arrow_left_pressed.png")
const LEFT_SELECTED_TEXTURE := preload("res://resources/ui/skin_v1/arrow_left_selected.png")
const ENABLED_MODULATE := Color.WHITE
const DISABLED_MODULATE := Color(0.68, 0.68, 0.68, 0.58)

@export var points_left := false

var _hovered := false
var _pressed_visual := false
var _last_disabled := false


func _ready() -> void:
	text = ""
	toggle_mode = false
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)
	focus_entered.connect(_refresh_icon)
	focus_exited.connect(_refresh_icon)
	_last_disabled = disabled
	_refresh_icon()


func _process(_delta: float) -> void:
	if _last_disabled == disabled:
		return
	_last_disabled = disabled
	if disabled:
		_pressed_visual = false
	_refresh_icon()


func _on_mouse_entered() -> void:
	_hovered = true
	_refresh_icon()


func _on_mouse_exited() -> void:
	_hovered = false
	_pressed_visual = false
	_refresh_icon()


func _on_button_down() -> void:
	_pressed_visual = true
	_refresh_icon()


func _on_button_up() -> void:
	_pressed_visual = false
	_refresh_icon()


func _refresh_icon() -> void:
	if disabled:
		icon = _texture_for_state("normal")
		self_modulate = DISABLED_MODULATE
	elif _pressed_visual:
		icon = _texture_for_state("pressed")
		self_modulate = ENABLED_MODULATE
	elif has_focus():
		icon = _texture_for_state("selected")
		self_modulate = ENABLED_MODULATE
	elif _hovered:
		icon = _texture_for_state("hover")
		self_modulate = ENABLED_MODULATE
	else:
		icon = _texture_for_state("normal")
		self_modulate = ENABLED_MODULATE


func _texture_for_state(state: String) -> Texture2D:
	if points_left:
		match state:
			"hover":
				return LEFT_HOVER_TEXTURE
			"pressed":
				return LEFT_PRESSED_TEXTURE
			"selected":
				return LEFT_SELECTED_TEXTURE
			_:
				return LEFT_NORMAL_TEXTURE
	match state:
		"hover":
			return RIGHT_HOVER_TEXTURE
		"pressed":
			return RIGHT_PRESSED_TEXTURE
		"selected":
			return RIGHT_SELECTED_TEXTURE
		_:
			return RIGHT_NORMAL_TEXTURE
