extends Button

signal filter_selected(filter_id: String)

var _filter_id := ""


func configure(filter_id: String, label_text: String, selected_filter: String) -> void:
	_filter_id = filter_id
	text = label_text
	set_meta("filter_id", filter_id)
	button_pressed = filter_id == selected_filter


func _ready() -> void:
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)


func _on_pressed() -> void:
	filter_selected.emit(_filter_id)
