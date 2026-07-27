extends Control

@onready var drag_button := $DragButton as Button
@onready var product_texture := $DragButton/ProductTexture as TextureRect
@onready var stock_badge := $DragButton/StockBadge as Label

var _recipe_id := ""


func configure(entry: Dictionary) -> void:
	_bind_nodes()
	_recipe_id = String(entry.get("recipe_id", ""))
	set_meta("recipe_id", _recipe_id)
	drag_button.set_meta("recipe_id", _recipe_id)
	product_texture.texture = entry.get("icon") as Texture2D
	var stock_count := maxi(0, int(entry.get("completed_stock_count", 0)))
	stock_badge.text = str(stock_count)
	stock_badge.visible = stock_count > 0
	drag_button.tooltip_text = _tooltip(entry)
	drag_button.disabled = not bool(entry.get("completed_stock_drag_enabled", true))
	drag_button.call(
		"configure_drag",
		entry.get("drag_data", {}),
		String(entry.get("drag_preview_text", "")),
		entry.get("drag_preview_data", {}),
		entry.get("drag_end_callable", Callable()),
		Callable()
	)


func recipe_id() -> String:
	return _recipe_id


func _bind_nodes() -> void:
	if is_instance_valid(drag_button):
		return
	drag_button = get_node("DragButton") as Button
	product_texture = get_node("DragButton/ProductTexture") as TextureRect
	stock_badge = get_node("DragButton/StockBadge") as Label


func _tooltip(entry: Dictionary) -> String:
	var tag_values: Array[String] = []
	for tag_value: Variant in entry.get("tags", []):
		tag_values.append(String(tag_value))
	return "%s\n库存：%d\n售价：%d\n标签：%s" % [
		String(entry.get("name", "")),
		maxi(0, int(entry.get("completed_stock_count", 0))),
		maxi(0, int(entry.get("price", 0))),
		"、".join(tag_values) if not tag_values.is_empty() else "无"
	]
