class_name CloseImageButton
extends Button

const NORMAL_TEXTURE := preload("res://resources/ui/skin_v1/close_large_normal.png")
const HOVER_TEXTURE := preload("res://resources/ui/skin_v1/close_large_hover.png")
const PRESSED_TEXTURE := preload("res://resources/ui/skin_v1/close_large_pressed.png")
const SELECTED_TEXTURE := preload("res://resources/ui/skin_v1/close_large_selected.png")

var _hovered := false
var _pressed_visual := false


func _ready() -> void:
	text = ""
	toggle_mode = false
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)
	focus_entered.connect(_refresh_icon)
	focus_exited.connect(_refresh_icon)
	_refresh_icon()


func _on_mouse_entered() -> void:
	_hovered = true
	_refresh_icon()


func _on_mouse_exited() -> void:
	_hovered = false
	_refresh_icon()


func _on_button_down() -> void:
	_pressed_visual = true
	_refresh_icon()


func _on_button_up() -> void:
	_pressed_visual = false
	_refresh_icon()


func _refresh_icon() -> void:
	if _pressed_visual:
		icon = PRESSED_TEXTURE
	elif has_focus():
		icon = SELECTED_TEXTURE
	elif _hovered:
		icon = HOVER_TEXTURE
	else:
		icon = NORMAL_TEXTURE
