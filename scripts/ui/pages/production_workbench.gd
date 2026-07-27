class_name ProductionWorkbench
extends VBoxContainer

signal search_changed(query: String)
signal bulk_action_requested(action: String)
signal kitchen_schedule_requested
signal make_requested(recipe_id: String)
signal process_requested(process_id: String)
signal restock_requested(recipe_id: String)

const QueueRowScene := preload("res://scenes/ui/pages/production_queue_recipe_row.tscn")
const CompletedStockCellScene := preload("res://scenes/ui/pages/production_completed_stock_cell.tscn")
const COMPLETED_PAGE_SIZE := 9
const BULK_MAKE_ALL := 0
const BULK_RESTOCK_ALL := 1
const BULK_LIST_ALL := 2

@onready var search_field: LineEdit = $ProductionQueueHeader/SearchField
@onready var automation_paused_label: Label = $ProductionQueueHeader/AutomationPausedLabel
@onready var bulk_action_button: MenuButton = $ProductionQueueHeader/BulkActionButton
@onready var kitchen_schedule_button: Button = $ProductionQueueHeader/KitchenScheduleButton
@onready var completed_cells: VBoxContainer = $ProductionColumns/CompletedColumn/CompletedScroll/CompletedCenter/CompletedCells
@onready var completed_previous_page_button: Button = $ProductionColumns/CompletedColumn/PreviousPageButton
@onready var completed_page_label: Label = $ProductionColumns/CompletedColumn/PageLabel
@onready var completed_next_page_button: Button = $ProductionColumns/CompletedColumn/NextPageButton
@onready var queue_rows: VBoxContainer = $ProductionColumns/QueueColumn/QueueScroll/QueueRows
@onready var empty_queue_panel: PanelContainer = $ProductionColumns/QueueColumn/QueueScroll/QueueRows/EmptyQueuePanel

var _completed_entries: Array = []
var _completed_page_index := 0


func _ready() -> void:
	_bind_nodes()
	var search_handler := Callable(self, "_on_search_text_changed")
	if not search_field.text_changed.is_connected(search_handler):
		search_field.text_changed.connect(search_handler)
	var schedule_handler := Callable(self, "_on_schedule_pressed")
	if not kitchen_schedule_button.pressed.is_connected(schedule_handler):
		kitchen_schedule_button.pressed.connect(schedule_handler)
	var popup := bulk_action_button.get_popup()
	popup.clear()
	popup.add_item("制作全部", BULK_MAKE_ALL)
	popup.add_item("一键补货", BULK_RESTOCK_ALL)
	popup.add_item("上架全部", BULK_LIST_ALL)
	var bulk_handler := Callable(self, "_on_bulk_action_id_pressed")
	if not popup.id_pressed.is_connected(bulk_handler):
		popup.id_pressed.connect(bulk_handler)
	var previous_page_handler := Callable(self, "_on_completed_previous_page_pressed")
	if not completed_previous_page_button.pressed.is_connected(previous_page_handler):
		completed_previous_page_button.pressed.connect(previous_page_handler)
	var next_page_handler := Callable(self, "_on_completed_next_page_pressed")
	if not completed_next_page_button.pressed.is_connected(next_page_handler):
		completed_next_page_button.pressed.connect(next_page_handler)


func refresh_queue(
	completed_entries: Array,
	queue_entries: Array,
	_active_batch_count: int = -1,
	automation_paused: bool = false
) -> void:
	_bind_nodes()
	_refresh_completed_cells(completed_entries)
	_refresh_queue_rows(queue_entries)
	automation_paused_label.visible = automation_paused


func _refresh_completed_cells(entries: Array) -> void:
	_completed_entries.clear()
	for entry_value: Variant in entries:
		if not entry_value is Dictionary:
			continue
		var entry: Dictionary = entry_value
		if String(entry.get("recipe_id", "")).is_empty():
			continue
		_completed_entries.append(entry)
	var page_count := _completed_page_count()
	_completed_page_index = clampi(
		_completed_page_index,
		0,
		maxi(0, page_count - 1)
	)
	_render_completed_page()


func _render_completed_page() -> void:
	var cells_by_recipe: Dictionary = {}
	for child_value: Variant in completed_cells.get_children():
		if not child_value is Control:
			continue
		var child := child_value as Control
		if child.is_queued_for_deletion():
			continue
		var child_recipe_id := String(child.get_meta("recipe_id", ""))
		if not child_recipe_id.is_empty():
			cells_by_recipe[child_recipe_id] = child

	var retained_ids: Dictionary = {}
	var visible_index := 0
	var page_start := _completed_page_index * COMPLETED_PAGE_SIZE
	var page_end := mini(page_start + COMPLETED_PAGE_SIZE, _completed_entries.size())
	for entry_index in range(page_start, page_end):
		var entry := _completed_entries[entry_index] as Dictionary
		var entry_recipe_id := String(entry.get("recipe_id", ""))
		var cell := cells_by_recipe.get(entry_recipe_id) as Control
		if cell == null:
			cell = CompletedStockCellScene.instantiate() as Control
			completed_cells.add_child(cell)
		cell.call("configure", entry)
		cell.visible = true
		completed_cells.move_child(cell, visible_index)
		retained_ids[entry_recipe_id] = true
		visible_index += 1

	for recipe_id_value: Variant in cells_by_recipe.keys():
		var recipe_id := String(recipe_id_value)
		if retained_ids.has(recipe_id):
			continue
		var stale_cell := cells_by_recipe[recipe_id] as Control
		if stale_cell != null:
			stale_cell.queue_free()
	_update_completed_pagination()


func _completed_page_count() -> int:
	if _completed_entries.is_empty():
		return 0
	return ceili(float(_completed_entries.size()) / float(COMPLETED_PAGE_SIZE))


func _update_completed_pagination() -> void:
	var page_count := _completed_page_count()
	completed_previous_page_button.disabled = page_count <= 1 or _completed_page_index <= 0
	completed_next_page_button.disabled = (
		page_count <= 1
		or _completed_page_index >= page_count - 1
	)
	completed_page_label.text = (
		"0 / 0"
		if page_count == 0
		else "%d / %d" % [_completed_page_index + 1, page_count]
	)


func _on_completed_previous_page_pressed() -> void:
	if _completed_page_index <= 0:
		return
	_completed_page_index -= 1
	_render_completed_page()


func _on_completed_next_page_pressed() -> void:
	var page_count := _completed_page_count()
	if _completed_page_index >= page_count - 1:
		return
	_completed_page_index += 1
	_render_completed_page()


func _refresh_queue_rows(entries: Array) -> void:
	var rows_by_key: Dictionary = {}
	for child_value: Variant in queue_rows.get_children():
		if not child_value is Control:
			continue
		var child := child_value as Control
		var entry_key := String(child.get_meta("entry_key", ""))
		if not entry_key.is_empty():
			rows_by_key[entry_key] = child

	var retained_keys: Dictionary = {}
	var visible_index := 0
	for entry_value: Variant in entries:
		if not entry_value is Dictionary:
			continue
		var entry: Dictionary = entry_value
		var entry_kind := String(entry.get("entry_kind", entry.get("kind", "finished")))
		var entry_id := String(entry.get("recipe_id", entry.get("id", "")))
		if entry_id.is_empty():
			continue
		var entry_key := "%s:%s" % [entry_kind, entry_id]
		var row: Control = rows_by_key.get(entry_key) as Control
		if row == null:
			row = QueueRowScene.instantiate() as Control
			queue_rows.add_child(row)
			_connect_row(row)
		row.call("configure", entry)
		row.visible = true
		queue_rows.move_child(row, visible_index + 1)
		retained_keys[entry_key] = true
		visible_index += 1

	for entry_key_value: Variant in rows_by_key.keys():
		var entry_key := String(entry_key_value)
		if retained_keys.has(entry_key):
			continue
		var stale_row := rows_by_key[entry_key] as Control
		if stale_row != null:
			stale_row.queue_free()

	empty_queue_panel.visible = visible_index == 0


func refresh_queue_runtime(entries: Array, _active_batch_count: int = -1, automation_paused: bool = false) -> void:
	_bind_nodes()
	var rows_by_key: Dictionary = {}
	for child_value: Variant in queue_rows.get_children():
		if not child_value is Control:
			continue
		var child := child_value as Control
		var entry_key := String(child.get_meta("entry_key", ""))
		if not entry_key.is_empty():
			rows_by_key[entry_key] = child
	for entry_value: Variant in entries:
		if not entry_value is Dictionary:
			continue
		var entry: Dictionary = entry_value
		var entry_kind := String(entry.get("entry_kind", entry.get("kind", "finished")))
		var entry_id := String(entry.get("recipe_id", entry.get("id", "")))
		var row := rows_by_key.get("%s:%s" % [entry_kind, entry_id]) as Control
		if row != null:
			row.call("refresh_runtime", entry)
	automation_paused_label.visible = automation_paused


func refresh_bulk_action_unlocks(make_all: bool, restock_all: bool, list_all: bool) -> void:
	_bind_nodes()
	var popup := bulk_action_button.get_popup()
	popup.set_item_disabled(popup.get_item_index(BULK_MAKE_ALL), not make_all)
	popup.set_item_disabled(popup.get_item_index(BULK_RESTOCK_ALL), not restock_all)
	popup.set_item_disabled(popup.get_item_index(BULK_LIST_ALL), not list_all)


func tutorial_target(kind: String) -> Control:
	_bind_nodes()
	match kind:
		"craftable", "search":
			return search_field
		"bulk":
			return bulk_action_button
		"kitchen_schedule":
			return kitchen_schedule_button
	return null


func row_tutorial_target(entry_kind: String, entry_id: String, action: String) -> Control:
	_bind_nodes()
	var key := "%s:%s" % [entry_kind, entry_id]
	for child_value: Variant in queue_rows.get_children():
		if child_value is Control and String((child_value as Control).get_meta("entry_key", "")) == key:
			return (child_value as Control).call("tutorial_target", action) as Control
	return null


func _connect_row(row: Control) -> void:
	row.connect("make_requested", func(recipe_id: String) -> void: make_requested.emit(recipe_id))
	row.connect("process_requested", func(process_id: String) -> void: process_requested.emit(process_id))
	row.connect("restock_requested", func(recipe_id: String) -> void: restock_requested.emit(recipe_id))


func _on_search_text_changed(query: String) -> void:
	search_changed.emit(query)


func _on_schedule_pressed() -> void:
	kitchen_schedule_requested.emit()


func _on_bulk_action_id_pressed(id: int) -> void:
	var action: String = String({
		BULK_MAKE_ALL: "make_all",
		BULK_RESTOCK_ALL: "restock_all",
		BULK_LIST_ALL: "list_all"
	}.get(id, ""))
	if not action.is_empty():
		bulk_action_requested.emit(action)


func _bind_nodes() -> void:
	if is_instance_valid(search_field):
		return
	search_field = get_node("ProductionQueueHeader/SearchField") as LineEdit
	automation_paused_label = get_node("ProductionQueueHeader/AutomationPausedLabel") as Label
	bulk_action_button = get_node("ProductionQueueHeader/BulkActionButton") as MenuButton
	kitchen_schedule_button = get_node("ProductionQueueHeader/KitchenScheduleButton") as Button
	completed_cells = get_node(
		"ProductionColumns/CompletedColumn/CompletedScroll/CompletedCenter/CompletedCells"
	) as VBoxContainer
	completed_previous_page_button = get_node(
		"ProductionColumns/CompletedColumn/PreviousPageButton"
	) as Button
	completed_page_label = get_node(
		"ProductionColumns/CompletedColumn/PageLabel"
	) as Label
	completed_next_page_button = get_node(
		"ProductionColumns/CompletedColumn/NextPageButton"
	) as Button
	queue_rows = get_node("ProductionColumns/QueueColumn/QueueScroll/QueueRows") as VBoxContainer
	empty_queue_panel = get_node(
		"ProductionColumns/QueueColumn/QueueScroll/QueueRows/EmptyQueuePanel"
	) as PanelContainer
