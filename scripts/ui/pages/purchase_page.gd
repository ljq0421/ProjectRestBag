extends VBoxContainer

signal purchase_requested(metadata: String)

var _selected_metadata := ""


func refresh(_state, _catalog, preferred_metadata: String = "") -> void:
	_selected_metadata = preferred_metadata


func selected_metadata() -> String:
	return _selected_metadata
