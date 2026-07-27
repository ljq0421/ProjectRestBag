class_name PurchaseReceiptDialog
extends Control

const HEADER_CELL_COUNT := 4
const ITEM_CELL_MIN_WIDTH := 128.0
const NUMERIC_CELL_MIN_WIDTH := 62.0
const RECEIPT_FONT_SIZE := 16
const RECEIPT_DIALOG_SIZE := Vector2i(600, 800)

@onready var receipt_frame: Control = $ReceiptFrame
@onready var receipt_grid: GridContainer = $ReceiptFrame/ReceiptBody/ReceiptContent/ReceiptGrid
@onready var receipt_summary: Label = $ReceiptFrame/ReceiptBody/ReceiptContent/ReceiptSummary
@onready var receipt_close_button: Button = $ReceiptFrame/ReceiptCloseButton

var receipt_dragging := false
var receipt_drag_offset := Vector2.ZERO


func _ready() -> void:
	if not receipt_close_button.pressed.is_connected(_on_close_requested):
		receipt_close_button.pressed.connect(_on_close_requested)


func show_receipt(receipt: Dictionary) -> void:
	if not is_node_ready():
		await ready
	_clear_receipt_rows()
	for entry_value: Variant in receipt.get("entries", []):
		if not entry_value is Dictionary:
			continue
		var entry: Dictionary = entry_value
		_add_receipt_cell(String(entry.get("name", entry.get("item_key", "商品"))), false)
		_add_receipt_cell(str(int(entry.get("quantity", 0))), true)
		_add_receipt_cell(str(int(entry.get("unit_price", 0))), true)
		_add_receipt_cell(str(int(entry.get("subtotal", 0))), true)
	receipt_summary.text = "商品总件数：%d\n总支出：%d 金币\n剩余金币：%d" % [
		int(receipt.get("total_units", 0)),
		int(receipt.get("total_cost", 0)),
		int(receipt.get("remaining_coins", 0))
	]
	receipt_dragging = false
	show()


func _on_close_requested() -> void:
	hide()


func handle_pointer_input(event: InputEvent) -> bool:
	if not visible:
		return false
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return false
		if not mouse_event.pressed:
			var was_dragging := receipt_dragging
			receipt_dragging = false
			return was_dragging
		var mouse_position := mouse_event.position
		if receipt_close_button.get_global_rect().has_point(mouse_position):
			receipt_dragging = false
			hide()
			return true
		if receipt_frame.get_global_rect().has_point(mouse_position):
			receipt_dragging = true
			receipt_drag_offset = receipt_frame.global_position - mouse_position
			return true
		receipt_dragging = false
		hide()
		return true
	if event is InputEventMouseMotion:
		if receipt_dragging:
			_move_receipt_frame((event as InputEventMouseMotion).position + receipt_drag_offset)
			return true
	return false


func _move_receipt_frame(target_position: Vector2) -> void:
	var viewport_size := get_viewport_rect().size
	var max_position := Vector2(
		maxf(0.0, viewport_size.x - receipt_frame.size.x),
		maxf(0.0, viewport_size.y - receipt_frame.size.y)
	)
	receipt_frame.global_position = Vector2(
		clampf(target_position.x, 0.0, max_position.x),
		clampf(target_position.y, 0.0, max_position.y)
	)


func _clear_receipt_rows() -> void:
	while receipt_grid.get_child_count() > HEADER_CELL_COUNT:
		var cell := receipt_grid.get_child(HEADER_CELL_COUNT)
		receipt_grid.remove_child(cell)
		cell.queue_free()


func _add_receipt_cell(value: String, numeric: bool) -> void:
	var cell := Label.new()
	cell.text = value
	cell.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if numeric:
		cell.custom_minimum_size = Vector2(NUMERIC_CELL_MIN_WIDTH, 32.0)
		cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	else:
		cell.custom_minimum_size = Vector2(ITEM_CELL_MIN_WIDTH, 32.0)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	cell.add_theme_font_size_override("font_size", RECEIPT_FONT_SIZE)
	receipt_grid.add_child(cell)
