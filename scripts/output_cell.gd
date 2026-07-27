extends Button

signal automation_toggled(site_id: String, slot_index: int, managed: bool)

const SINGLE_PRODUCT_ICON_SIZE := Vector2(92, 92)
const DUAL_PRODUCT_ICON_SIZE := Vector2(60, 60)
const SINGLE_PRODUCT_ICON_POSITION := Vector2(10, 2)
const PRIMARY_DUAL_ICON_POSITION := Vector2(0, 8)
const SECONDARY_DUAL_ICON_POSITION := Vector2(52, 28)

var drag_data: Dictionary = {}
var drag_preview_text := ""
var drag_preview_data: Dictionary = {}
var drag_start_callable := Callable()
var drag_end_callable := Callable()
var active_drag_end_callable := Callable()
var drop_target_kind := ""
var drop_target_data: Dictionary = {}
var can_drop_callable := Callable()
var drop_callable := Callable()


func _ready() -> void:
	var toggle := get_node_or_null("AutomationToggle") as BaseButton
	if toggle != null:
		var handler := Callable(self, "_on_automation_toggle_toggled")
		if not toggle.toggled.is_connected(handler):
			toggle.toggled.connect(handler)


func configure_products(products: Array[Dictionary]) -> void:
	clear_product_display()
	var visible_products: Array[Dictionary] = []
	for product_value: Variant in products:
		if not product_value is Dictionary:
			continue
		var product: Dictionary = product_value
		if String(product.get("id", "")).is_empty() or int(product.get("amount", 0)) <= 0:
			continue
		visible_products.append(product)
	if visible_products.is_empty():
		return

	var display_area := get_node_or_null("ProductDisplayArea") as Control
	var primary := get_node_or_null("ProductDisplayArea/PrimaryProductIcon") as TextureRect
	var secondary := get_node_or_null("ProductDisplayArea/SecondaryProductIcon") as TextureRect
	if display_area == null or primary == null or secondary == null:
		return

	display_area.visible = true
	text = ""
	var dual := visible_products.size() >= 2
	_bind_product_icon(
		primary,
		visible_products[0],
		DUAL_PRODUCT_ICON_SIZE if dual else SINGLE_PRODUCT_ICON_SIZE,
		PRIMARY_DUAL_ICON_POSITION if dual else SINGLE_PRODUCT_ICON_POSITION
	)
	if dual:
		_bind_product_icon(secondary, visible_products[1], DUAL_PRODUCT_ICON_SIZE, SECONDARY_DUAL_ICON_POSITION)

	var overflow := get_node_or_null("ProductDisplayArea/OverflowLabel") as Label
	if overflow != null and visible_products.size() > 2:
		overflow.visible = true
		overflow.text = "+%d" % (visible_products.size() - 2)

	var output_ids: Array[String] = []
	var tooltip_lines: Array[String] = []
	for product: Dictionary in visible_products:
		output_ids.append(String(product.get("id", "")))
		tooltip_lines.append("%s ×%d" % [String(product.get("name", product.get("id", ""))), int(product.get("amount", 0))])
	set_meta("displayed_output_ids", output_ids)
	tooltip_text = "\n".join(tooltip_lines)
	var automation_status := get_node_or_null("AutomationStatusLabel") as Label
	if automation_status != null:
		automation_status.visible = false


func clear_product_display() -> void:
	var display_area := get_node_or_null("ProductDisplayArea") as Control
	if display_area != null:
		display_area.visible = false
	for path in ["ProductDisplayArea/PrimaryProductIcon", "ProductDisplayArea/SecondaryProductIcon"]:
		var icon := get_node_or_null(path) as TextureRect
		if icon == null:
			continue
		icon.visible = false
		icon.texture = null
		icon.remove_meta("item_id")
		var missing := icon.get_node_or_null("MissingIconLabel") as Label
		if missing != null:
			missing.visible = false
		var quantity := icon.get_node_or_null("QuantityLabel") as Label
		if quantity != null:
			quantity.text = ""
	var overflow := get_node_or_null("ProductDisplayArea/OverflowLabel") as Label
	if overflow != null:
		overflow.visible = false
		overflow.text = ""
	remove_meta("displayed_output_ids")
	tooltip_text = ""


func _bind_product_icon(icon: TextureRect, product: Dictionary, icon_size: Vector2, icon_position: Vector2) -> void:
	icon.custom_minimum_size = icon_size
	icon.position = icon_position
	icon.size = icon_size
	icon.texture = product.get("texture") as Texture2D
	icon.set_meta("item_id", String(product.get("id", "")))
	icon.visible = true
	var missing := icon.get_node_or_null("MissingIconLabel") as Label
	if missing != null:
		missing.visible = icon.texture == null
	var quantity := icon.get_node_or_null("QuantityLabel") as Label
	if quantity != null:
		quantity.text = "×%d" % int(product.get("amount", 0))
		quantity.visible = true


func _has_product_display() -> bool:
	var display_area := get_node_or_null("ProductDisplayArea") as Control
	return display_area != null and display_area.visible


func configure_automation(managed: bool, available: bool, status_text: String, pause_reason: Variant) -> void:
	var toggle := get_node_or_null("AutomationToggle") as BaseButton
	var status := get_node_or_null("AutomationStatusLabel") as Label
	var tooltip := _automation_pause_tooltip(status_text, pause_reason)
	if toggle != null:
		toggle.visible = false
		toggle.set_pressed_no_signal(managed)
		toggle.tooltip_text = "托管开关已移动到产地板块标题。"
	if status != null:
		status.visible = available and not status_text.is_empty() and not _has_product_display()
		status.text = status_text
		status.tooltip_text = tooltip
		status.theme_type_variation = _automation_status_variation(managed, pause_reason)
	if _has_product_display() and available and not tooltip.is_empty() and tooltip_text.find(tooltip) == -1:
		tooltip_text = tooltip if tooltip_text.is_empty() else "%s\n%s" % [tooltip_text, tooltip]


func _automation_status_variation(managed: bool, pause_reason: Variant) -> StringName:
	if not managed:
		return &"DessertStatusTagNormal"
	if pause_reason is Dictionary and not (pause_reason as Dictionary).is_empty():
		return &"DessertStatusTagWarning"
	if pause_reason is String and not String(pause_reason).strip_edges().is_empty():
		return &"DessertStatusTagWarning"
	return &"DessertStatusTagPositive"


func _on_automation_toggle_toggled(managed: bool) -> void:
	automation_toggled.emit(
		String(get_meta("site_id", "")),
		int(get_meta("slot_index", -1)),
		managed
	)


func _automation_pause_tooltip(status_text: String, pause_reason: Variant) -> String:
	if pause_reason is String:
		var reason_text := String(pause_reason).strip_edges()
		return reason_text if not reason_text.is_empty() else status_text
	if not pause_reason is Dictionary:
		return status_text
	var reason: Dictionary = pause_reason
	if reason.is_empty():
		return status_text
	var next_step := String(reason.get("next_step", ""))
	if next_step.is_empty():
		return status_text
	if status_text.is_empty():
		return next_step
	return "%s\n%s" % [status_text, next_step]


func configure_drag(
	data: Dictionary,
	preview_text: String,
	preview_data: Dictionary = {},
	end_callable: Callable = Callable(),
	start_callable: Callable = Callable()
) -> void:
	drag_data = data.duplicate(true)
	drag_preview_text = preview_text
	drag_preview_data = preview_data.duplicate(true)
	drag_start_callable = start_callable
	drag_end_callable = end_callable


func clear_drag() -> void:
	drag_data.clear()
	drag_preview_text = ""
	drag_preview_data.clear()
	drag_start_callable = Callable()
	drag_end_callable = Callable()


func configure_drop(target_kind: String, can_callable: Callable, apply_callable: Callable, target_data: Dictionary = {}) -> void:
	drop_target_kind = target_kind
	drop_target_data = target_data.duplicate(true)
	can_drop_callable = can_callable
	drop_callable = apply_callable


func _get_drag_data(_at_position: Vector2) -> Variant:
	if drag_data.is_empty():
		return null

	active_drag_end_callable = drag_end_callable
	set_drag_preview(_make_drag_preview())
	if drag_start_callable.is_valid():
		drag_start_callable.call_deferred()
	return drag_data.duplicate(true)


func _notification(what: int) -> void:
	if what != NOTIFICATION_DRAG_END or not active_drag_end_callable.is_valid():
		return
	var callback := active_drag_end_callable
	active_drag_end_callable = Callable()
	callback.call()


func _make_drag_preview() -> Control:
	# Exception: this is a transient drag preview, not a stable page or row layout.
	var preview := PanelContainer.new()
	preview.theme_type_variation = &"DessertDragPreviewPanel"
	preview.custom_minimum_size = Vector2(132, 58)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var label := Label.new()
	label.text = drag_preview_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(label)
	var rows := maxi(0, int(drag_preview_data.get("shape_rows", drag_data.get("shape_rows", 0))))
	var cols := maxi(0, int(drag_preview_data.get("shape_cols", drag_data.get("shape_cols", 0))))
	if rows > 0 and cols > 0:
		var occupied_cells := _preview_shape_cell_keys()
		var grid := GridContainer.new()
		grid.columns = cols
		grid.add_theme_constant_override("h_separation", 2)
		grid.add_theme_constant_override("v_separation", 2)
		grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		for row_index in range(rows):
			for col_index in range(cols):
				var cell := ColorRect.new()
				cell.custom_minimum_size = Vector2(16, 16)
				var cell_key := "%d:%d" % [row_index + 1, col_index + 1]
				var occupied := occupied_cells.is_empty() or occupied_cells.has(cell_key)
				cell.color = Color(0.35, 0.72, 1.0, 0.9) if occupied else Color(0.35, 0.72, 1.0, 0.18)
				grid.add_child(cell)
		box.add_child(grid)
	preview.add_child(box)
	return preview


func _preview_shape_cell_keys() -> Dictionary:
	var keys := {}
	var raw_cells: Variant = drag_preview_data.get("shape_cells", drag_data.get("shape_cells", []))
	if not raw_cells is Array:
		return keys
	for cell_value in raw_cells:
		var cell := Vector2i.ZERO
		if cell_value is Vector2i:
			cell = cell_value
		elif cell_value is Array and cell_value.size() == 2:
			cell = Vector2i(int(cell_value[0]), int(cell_value[1]))
		if cell != Vector2i.ZERO:
			keys["%d:%d" % [cell.x, cell.y]] = true
	return keys


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if drop_target_kind.is_empty() or not can_drop_callable.is_valid():
		return false
	return bool(can_drop_callable.call(drop_target_kind, _with_drop_target_data(data)))


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not _can_drop_data(_at_position, data):
		return
	if drop_callable.is_valid():
		drop_callable.call(drop_target_kind, _with_drop_target_data(data))


func _with_drop_target_data(data: Variant) -> Variant:
	if drop_target_data.is_empty() or not data is Dictionary:
		return data
	var merged: Dictionary = data.duplicate(true)
	for key in drop_target_data.keys():
		merged[key] = drop_target_data[key]
	return merged
