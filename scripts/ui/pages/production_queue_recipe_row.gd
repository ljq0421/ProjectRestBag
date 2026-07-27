class_name ProductionQueueRecipeRow
extends PanelContainer

signal make_requested(recipe_id: String)
signal process_requested(process_id: String)
signal restock_requested(recipe_id: String)

const MATERIAL_ICON_SIZE := Vector2(18, 18)
const MATERIAL_FONT_SIZE := 13
const MATERIAL_ITEM_HEIGHT := 24.0
const MATERIAL_AREA_WIDTH := 300.0
const MATERIAL_FLOW_HORIZONTAL_GAP := 4.0
const MATERIAL_COLUMNS_PER_LINE := 3.0
const MATERIAL_INNER_GAP := 2.0
const MATERIAL_ITEM_WIDTH := (
	(MATERIAL_AREA_WIDTH - MATERIAL_FLOW_HORIZONTAL_GAP * (MATERIAL_COLUMNS_PER_LINE - 1.0))
	/ MATERIAL_COLUMNS_PER_LINE
)
const MATERIAL_NAME_MIN_WIDTH := 11.0
const MATERIAL_TEXT_COLOR := Color(0.31, 0.25, 0.21, 1.0)

@onready var progress_fill: ColorRect = $ProgressLayer/ProgressFill
@onready var product_icon_button: Button = $Content/ProductIconButton
@onready var product_texture: TextureRect = $Content/ProductIconButton/ProductTexture
@onready var recipe_name_label: Label = $Content/RecipeNameLabel
@onready var material_strip: HFlowContainer = $Content/MaterialStrip/MaterialItems
@onready var time_value: Label = $Content/TimeGroup/TimeValue
@onready var price_value: Label = $Content/PriceGroup/PriceValue
@onready var action_button: Button = $Content/ActionButton

var _entry: Dictionary = {}
var _progress := 0.0


func _ready() -> void:
	_bind_nodes()
	var action_handler := Callable(self, "_on_action_pressed")
	if not action_button.pressed.is_connected(action_handler):
		action_button.pressed.connect(action_handler)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_apply_progress_width()


func configure(entry: Dictionary) -> void:
	_bind_nodes()
	_entry = entry.duplicate(true)
	var entry_kind := String(entry.get("entry_kind", entry.get("kind", "finished")))
	var entry_id := String(entry.get("recipe_id", entry.get("id", "")))
	set_meta("recipe_id", entry_id)
	set_meta("entry_kind", entry_kind)
	set_meta("entry_key", "%s:%s" % [entry_kind, entry_id])
	product_texture.texture = entry.get("icon") as Texture2D
	recipe_name_label.text = String(entry.get("name", entry_id))
	price_value.text = str(maxi(0, int(entry.get("price", 0))))
	_bind_materials(entry.get("materials", []))
	_apply_runtime(entry)
	_apply_action(entry)


func refresh_runtime(entry: Dictionary) -> void:
	_bind_nodes()
	for key in ["is_active", "progress", "remaining_seconds", "duration_seconds", "action_kind", "disabled_reason"]:
		if entry.has(key):
			_entry[key] = entry[key]
	_apply_runtime(_entry)
	_apply_action(_entry)


func tutorial_target(action: String) -> Control:
	match action:
		"make", "restock":
			return action_button
		"list":
			return product_icon_button
	return self


func _bind_materials(materials_value: Variant) -> void:
	for child in material_strip.get_children():
		child.queue_free()
	if not materials_value is Array:
		return
	for material_value: Variant in materials_value:
		if not material_value is Dictionary:
			continue
		material_strip.add_child(_make_material_item(material_value as Dictionary))


func _material_text_width(text: String) -> float:
	var font := get_theme_font("font", "Label")
	return ceilf(font.get_string_size(
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		MATERIAL_FONT_SIZE
	).x)


func _material_name_width(material_name: String, quantity_text: String) -> float:
	var reserved_width := (
		MATERIAL_ICON_SIZE.x
		+ MATERIAL_INNER_GAP * 2.0
		+ _material_text_width(quantity_text)
	)
	var available_width := maxf(
		MATERIAL_NAME_MIN_WIDTH,
		MATERIAL_ITEM_WIDTH - reserved_width
	)
	return clampf(
		_material_text_width(material_name),
		MATERIAL_NAME_MIN_WIDTH,
		available_width
	)


func _make_material_item(material: Dictionary) -> HBoxContainer:
	var item := HBoxContainer.new()
	item.custom_minimum_size = Vector2(MATERIAL_ITEM_WIDTH, MATERIAL_ITEM_HEIGHT)
	item.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	item.add_theme_constant_override("separation", int(MATERIAL_INNER_GAP))
	item.tooltip_text = String(material.get("tooltip", ""))

	var owned_count := maxi(0, int(material.get("owned_count", 0)))
	var required_count := maxi(0, int(material.get("required_count", 0)))
	var quantity_text := (
		"%d/%d" % [owned_count, required_count]
		if bool(material.get("missing", false))
		else "×%d" % required_count
	)

	var icon := TextureRect.new()
	icon.name = "MaterialIcon"
	icon.custom_minimum_size = MATERIAL_ICON_SIZE
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = material.get("icon") as Texture2D
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	item.add_child(icon)

	var material_name := String(material.get("name", ""))
	var name_label := Label.new()
	name_label.name = "MaterialNameLabel"
	name_label.custom_minimum_size.x = _material_name_width(material_name, quantity_text)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", MATERIAL_FONT_SIZE)
	name_label.add_theme_color_override("font_color", MATERIAL_TEXT_COLOR)
	name_label.text = material_name
	item.add_child(name_label)

	var quantity_label := Label.new()
	quantity_label.name = "MaterialQuantityLabel"
	quantity_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	quantity_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	quantity_label.add_theme_font_size_override("font_size", MATERIAL_FONT_SIZE)
	quantity_label.add_theme_color_override("font_color", MATERIAL_TEXT_COLOR)
	quantity_label.text = quantity_text
	item.add_child(quantity_label)
	return item


func _apply_runtime(entry: Dictionary) -> void:
	var active := bool(entry.get("is_active", false))
	var duration_seconds := maxi(0, int(entry.get("duration_seconds", 0)))
	var remaining_seconds := maxi(0, int(entry.get("remaining_seconds", duration_seconds)))
	time_value.text = "%ds" % (remaining_seconds if active else duration_seconds)
	_progress = clampf(float(entry.get("progress", 0.0)), 0.0, 1.0) if active else 0.0
	_apply_progress_width()


func _apply_progress_width() -> void:
	if not is_instance_valid(progress_fill):
		return
	progress_fill.position = Vector2.ZERO
	progress_fill.size = Vector2(size.x * _progress, size.y)


func _apply_action(entry: Dictionary) -> void:
	var action_kind := String(entry.get("action_kind", "make"))
	match action_kind:
		"active":
			action_button.text = "制作中"
			action_button.disabled = true
		"restock":
			action_button.text = "补货"
			action_button.disabled = not bool(entry.get("action_enabled", false))
		_:
			action_button.text = "制作"
			action_button.disabled = not bool(entry.get("action_enabled", true))
	action_button.tooltip_text = String(entry.get("disabled_reason", ""))


func _on_action_pressed() -> void:
	var entry_kind := String(_entry.get("entry_kind", _entry.get("kind", "finished")))
	var entry_id := String(_entry.get("recipe_id", _entry.get("id", "")))
	if entry_id.is_empty():
		return
	match String(_entry.get("action_kind", "make")):
		"restock":
			restock_requested.emit(entry_id)
		"make":
			if entry_kind == "processing":
				process_requested.emit(entry_id)
			else:
				make_requested.emit(entry_id)


func _bind_nodes() -> void:
	if is_instance_valid(product_icon_button):
		return
	progress_fill = get_node("ProgressLayer/ProgressFill") as ColorRect
	product_icon_button = get_node("Content/ProductIconButton") as Button
	product_texture = get_node("Content/ProductIconButton/ProductTexture") as TextureRect
	recipe_name_label = get_node("Content/RecipeNameLabel") as Label
	material_strip = get_node("Content/MaterialStrip/MaterialItems") as HFlowContainer
	time_value = get_node("Content/TimeGroup/TimeValue") as Label
	price_value = get_node("Content/PriceGroup/PriceValue") as Label
	action_button = get_node("Content/ActionButton") as Button
