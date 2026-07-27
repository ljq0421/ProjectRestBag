extends VBoxContainer

signal close_requested()
signal inventory_restock_requested()
signal inventory_batch_list_requested()
signal inventory_item_selected(item_id: String)


func refresh(_state, _catalog) -> void:
	pass


func show_mode(_mode: String) -> void:
	visible = true


func hide_mode() -> void:
	visible = false


func refresh_grid(view) -> void:
	view.call("_clear_children", view.inventory_grid)
	view.call("_refresh_inventory_summary")
	view.inventory_grid.columns = view.INVENTORY_GRID_COLUMNS
	var entries: Array = view.call("_inventory_entries", view.selected_inventory_tab)
	var page_count := int(view.call("_inventory_page_count", entries))
	view.selected_inventory_page = clampi(view.selected_inventory_page, 0, page_count - 1)
	var start_index: int = view.selected_inventory_page * view.INVENTORY_CELLS_PER_PAGE
	for cell_index in range(view.INVENTORY_CELLS_PER_PAGE):
		var entry_index := start_index + cell_index
		if entry_index < entries.size():
			var entry: Dictionary = entries[entry_index]
			view.inventory_grid.add_child(view.call("_make_inventory_cell", "%s\nx%d" % [
				String(entry.get("name", "")),
				int(entry.get("count", 0))
			], entry))
		else:
			view.inventory_grid.add_child(view.call("_make_inventory_cell", "", {}))
	view.inventory_page_label.text = "%d/%d" % [view.selected_inventory_page + 1, page_count]
	view.inventory_prev_button.disabled = view.selected_inventory_page <= 0
	view.inventory_next_button.disabled = view.selected_inventory_page >= page_count - 1
