extends VBoxContainer

@export var showcase_header_overlay_style: StyleBoxFlat

signal product_list_requested(recipe_id: String, target_slot_index: int)
signal product_move_requested(recipe_id: String, from_slot_index: int, target_slot_index: int)
signal product_rotate_requested(recipe_id: String)
signal listing_status_changed(message: String)
signal start_round_requested()
signal rulebook_requested()
signal expansion_tool_requested(tool: String)
signal expansion_confirm_requested()
signal expansion_cancel_requested()

@onready var showcase_grid: GridContainer = $ShowcaseGrid
@onready var start_round_button: Button = $RoundControlBar/StartRoundButton
@onready var rulebook_button: Button = $RoundControlBar/RulebookButton
@onready var task_progress_panel: PanelContainer = $TaskProgressPanel
@onready var task_progress_label: Label = $TaskProgressPanel/TaskProgressLabel
@onready var expansion_toolbar: PanelContainer = $ExpansionToolbar
@onready var expansion_quote_label: Label = $ExpansionToolbar/ExpansionContent/ExpansionQuoteLabel
@onready var expansion_confirm_button: Button = $ExpansionToolbar/ExpansionContent/ExpansionActionRow/ExpansionConfirmButton
@onready var expansion_cancel_button: Button = $ExpansionToolbar/ExpansionContent/ExpansionActionRow/ExpansionCancelButton
@onready var cell_tool_button: Button = $ExpansionToolbar/ExpansionContent/ExpansionToolRow/CellToolButton
@onready var row_tool_button: Button = $ExpansionToolbar/ExpansionContent/ExpansionToolRow/RowToolButton
@onready var column_tool_button: Button = $ExpansionToolbar/ExpansionContent/ExpansionToolRow/ColumnToolButton


func _ready() -> void:
	if not showcase_grid.item_rect_changed.is_connected(queue_redraw):
		showcase_grid.item_rect_changed.connect(queue_redraw)
	if not start_round_button.pressed.is_connected(_on_start_round_pressed):
		start_round_button.pressed.connect(_on_start_round_pressed)
	if not rulebook_button.pressed.is_connected(_on_rulebook_pressed):
		rulebook_button.pressed.connect(_on_rulebook_pressed)
	cell_tool_button.pressed.connect(func(): expansion_tool_requested.emit("cells"))
	row_tool_button.pressed.connect(func(): expansion_tool_requested.emit("row"))
	column_tool_button.pressed.connect(func(): expansion_tool_requested.emit("column"))
	expansion_confirm_button.pressed.connect(func(): expansion_confirm_requested.emit())
	expansion_cancel_button.pressed.connect(func(): expansion_cancel_requested.emit())


func _on_start_round_pressed() -> void:
	start_round_requested.emit()


func _on_rulebook_pressed() -> void:
	rulebook_requested.emit()


func _draw() -> void:
	if showcase_header_overlay_style != null and is_instance_valid(showcase_grid):
		draw_style_box(showcase_header_overlay_style, _showcase_header_overlay_rect())


func _showcase_header_overlay_rect() -> Rect2:
	var header_height := clampf(showcase_grid.position.y, 0.0, size.y)
	return Rect2(Vector2.ZERO, Vector2(size.x, header_height))


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func refresh(_state, _catalog, _now_unix: int) -> void:
	pass


func set_task_progress(lines: Array[String]) -> void:
	task_progress_panel.visible = not lines.is_empty()
	task_progress_label.text = "\n".join(lines)


func set_expansion_mode(active: bool, tool: String, summary: String, confirm_enabled: bool) -> void:
	expansion_toolbar.visible = active
	expansion_quote_label.text = summary
	expansion_confirm_button.disabled = not confirm_enabled
	cell_tool_button.button_pressed = tool == "cells"
	row_tool_button.button_pressed = tool == "row"
	column_tool_button.button_pressed = tool == "column"


func clear_drag_preview() -> void:
	pass


func cells_for_slot(_recipe_id: String, _slot_index: int) -> Array:
	return []
