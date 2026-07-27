extends VBoxContainer


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	var panel_style := get_theme_stylebox(&"panel")
	if panel_style != null:
		draw_style_box(panel_style, Rect2(Vector2.ZERO, size))


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_THEME_CHANGED:
		queue_redraw()
