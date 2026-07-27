extends PanelContainer

signal quantity_delta_requested(item_key: String, delta: int)

const PurchaseQuantityRowScene = preload("res://scenes/ui/pages/purchase_quantity_row.tscn")
const DEFAULT_EMPTY_TEXT := "当前暂无可采购商品"

@export var category_id := ""
@export var region_title := ""

@onready var title_label: Label = $ContentMargin/RegionContent/RegionTitle
@onready var items_scroll: ScrollContainer = $ContentMargin/RegionContent/ItemsScroll
@onready var item_rows_container: VBoxContainer = $ContentMargin/RegionContent/ItemsScroll/ItemRows
@onready var empty_state: Label = $ContentMargin/RegionContent/EmptyState


func _ready() -> void:
	title_label.text = region_title


func populate(entries: Array[Dictionary], access_locked: bool = false, locked_reason: String = "") -> void:
	var previous_scroll := items_scroll.scroll_vertical
	set_meta("access_locked", access_locked)
	title_label.text = "🔒 %s" % region_title if access_locked else region_title
	title_label.tooltip_text = locked_reason if access_locked else region_title
	tooltip_text = locked_reason if access_locked else ""
	_clear_rows()
	if access_locked:
		items_scroll.visible = false
		empty_state.visible = true
		empty_state.text = locked_reason
		return
	empty_state.text = DEFAULT_EMPTY_TEXT
	for entry in entries:
		var row := PurchaseQuantityRowScene.instantiate() as HBoxContainer
		row.call(
			"configure",
			String(entry.get("item_key", "")),
			String(entry.get("name", "")),
			int(entry.get("price", 0)),
			int(entry.get("stock", 0)),
			int(entry.get("quantity", 0)),
			bool(entry.get("can_increase", false))
		)
		row.connect("quantity_delta_requested", _on_row_quantity_delta_requested)
		item_rows_container.add_child(row)
	items_scroll.visible = not entries.is_empty()
	empty_state.visible = entries.is_empty()
	if not entries.is_empty():
		_restore_scroll.call_deferred(previous_scroll)


func update_item(item_key: String, stock: int, quantity: int, can_increase: bool) -> void:
	for row in item_rows():
		if String(row.get_meta("purchase_cart_item_key", "")) == item_key:
			row.call("update_state", stock, quantity, can_increase)


func item_rows() -> Array[Control]:
	var rows: Array[Control] = []
	for child in item_rows_container.get_children():
		if child is Control:
			rows.append(child as Control)
	return rows


func row_for_item(item_key: String) -> Control:
	for row in item_rows():
		if String(row.get_meta("purchase_cart_item_key", "")) == item_key:
			return row
	return null


func tutorial_target_for_item(item_key: String, action: String) -> Control:
	var row := row_for_item(item_key)
	if row == null:
		return null
	items_scroll.ensure_control_visible(row)
	if row.has_method("tutorial_target"):
		return row.call("tutorial_target", action) as Control
	return row


func _on_row_quantity_delta_requested(item_key: String, delta: int) -> void:
	quantity_delta_requested.emit(item_key, delta)


func _clear_rows() -> void:
	for child in item_rows_container.get_children():
		item_rows_container.remove_child(child)
		child.queue_free()


func _restore_scroll(value: int) -> void:
	items_scroll.scroll_vertical = value
