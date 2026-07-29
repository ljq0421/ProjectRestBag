class_name ChallengeUiStyle
extends RefCounted


static func apply_primary(button: Button, color: Color = Color("#546BDD")) -> void:
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color("#E7E3EF"))
	button.add_theme_stylebox_override("normal", _button_style(color, color.lightened(0.08), 2))
	button.add_theme_stylebox_override("hover", _button_style(color.lightened(0.08), Color("#FFC857"), 3))
	button.add_theme_stylebox_override("pressed", _button_style(color.darkened(0.08), Color("#FFC857"), 3))
	button.add_theme_stylebox_override("focus", _button_style(color, Color("#FFC857"), 3))
	button.add_theme_stylebox_override("disabled", _button_style(Color("#AAA6B2"), Color("#AAA6B2"), 1))


static func apply_secondary(button: Button) -> void:
	button.add_theme_color_override("font_color", Color("#29213D"))
	button.add_theme_color_override("font_hover_color", Color("#29213D"))
	button.add_theme_color_override("font_pressed_color", Color("#29213D"))
	button.add_theme_color_override("font_disabled_color", Color("#8B8794"))
	button.add_theme_stylebox_override("normal", _button_style(Color("#F1EEFA"), Color("#8B7FAD"), 2))
	button.add_theme_stylebox_override("hover", _button_style(Color("#FFFFFF"), Color("#546BDD"), 3))
	button.add_theme_stylebox_override("pressed", _button_style(Color("#E6E1F4"), Color("#546BDD"), 3))
	button.add_theme_stylebox_override("focus", _button_style(Color("#F1EEFA"), Color("#FFC857"), 3))
	button.add_theme_stylebox_override("disabled", _button_style(Color("#E2DFE8"), Color("#C1BCCB"), 1))


static func apply_choice(button: Button, category: String) -> void:
	var color := Color("#546BDD")
	match category:
		"compatible":
			color = Color("#2D9A6A")
		"pivot":
			color = Color("#E34B72")
	button.add_theme_color_override("font_color", Color("#29213D"))
	button.add_theme_color_override("font_hover_color", Color("#29213D"))
	button.add_theme_color_override("font_pressed_color", Color("#29213D"))
	button.add_theme_color_override("font_disabled_color", Color("#8B8794"))
	button.add_theme_stylebox_override("normal", _button_style(Color("#FFFFFF"), color, 3))
	button.add_theme_stylebox_override("hover", _button_style(color.lightened(0.72), color, 5))
	button.add_theme_stylebox_override("pressed", _button_style(color.lightened(0.62), Color("#FFC857"), 5))
	button.add_theme_stylebox_override("focus", _button_style(Color("#FFFFFF"), Color("#FFC857"), 5))
	button.add_theme_stylebox_override("disabled", _button_style(Color("#E2DFE8"), Color("#C1BCCB"), 2))


static func _button_style(fill: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.content_margin_left = 18
	style.content_margin_top = 12
	style.content_margin_right = 18
	style.content_margin_bottom = 12
	return style
