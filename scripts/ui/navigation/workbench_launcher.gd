extends HBoxContainer

signal starlight_requested
signal task_requested
signal inventory_requested
signal catalog_requested
signal research_requested
signal purchase_requested
signal output_requested
signal storefront_manage_requested

const SIGNAL_BY_BUTTON := {
	"StarlightButton": "starlight_requested",
	"TaskButton": "task_requested",
	"InventoryButton": "inventory_requested",
	"CatalogButton": "catalog_requested",
	"ResearchButton": "research_requested",
	"PurchaseButton": "purchase_requested",
	"OutputButton": "output_requested",
	"StorefrontManageButton": "storefront_manage_requested",
}


func _ready() -> void:
	for button_name in SIGNAL_BY_BUTTON:
		var button := get_node_or_null(NodePath(String(button_name))) as Button
		if button == null:
			continue
		var handler := Callable(self, "_emit_entry_requested").bind(String(button_name))
		if not button.pressed.is_connected(handler):
			button.pressed.connect(handler)


func set_badge(button_name: String, text: String) -> void:
	var badge := get_node_or_null(NodePath("%s/Badge" % button_name)) as Label
	if badge == null:
		return
	badge.text = text
	badge.visible = not text.is_empty()


func set_entry_enabled(button_name: String, enabled: bool, tooltip: String = "") -> void:
	var button := get_node_or_null(NodePath(button_name)) as Button
	if button == null:
		return
	button.disabled = false
	button.set_meta("access_locked", not enabled)
	button.modulate = Color(1, 1, 1, 1) if enabled else Color(0.58, 0.58, 0.58, 1)
	button.tooltip_text = tooltip
	var lock_badge := _lock_badge(button)
	lock_badge.visible = not enabled


func press_entry_at_global_position(global_position: Vector2) -> bool:
	for button_name in SIGNAL_BY_BUTTON:
		var button := get_node_or_null(NodePath(String(button_name))) as Button
		if button == null or not button.is_visible_in_tree():
			continue
		if button.get_global_rect().has_point(global_position):
			button.emit_signal("pressed")
			return true
	return false


func _emit_entry_requested(button_name: String) -> void:
	var signal_name := StringName(String(SIGNAL_BY_BUTTON.get(button_name, "")))
	if not signal_name.is_empty():
		emit_signal(signal_name)


func _lock_badge(button: Button) -> Label:
	var existing := button.get_node_or_null("AccessLockBadge") as Label
	if existing != null:
		return existing
	var badge := Label.new()
	badge.name = "AccessLockBadge"
	badge.set_anchors_preset(Control.PRESET_TOP_LEFT)
	badge.position = Vector2(2, 2)
	badge.size = Vector2(24, 24)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.text = "🔒"
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 16)
	button.add_child(badge)
	return badge
