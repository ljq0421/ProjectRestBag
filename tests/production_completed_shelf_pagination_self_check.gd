extends SceneTree

const WorkbenchScene := preload("res://scenes/ui/pages/production_workbench.tscn")
const PAGE_SIZE := 9

var failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var workbench := WorkbenchScene.instantiate()
	root.add_child(workbench)
	workbench.size = Vector2(820, 766)
	await process_frame

	var completed_cells := workbench.get_node(
		"ProductionColumns/CompletedColumn/CompletedScroll/CompletedCenter/CompletedCells"
	) as VBoxContainer
	var previous_button := workbench.get_node(
		"ProductionColumns/CompletedColumn/PreviousPageButton"
	) as Button
	var page_label := workbench.get_node(
		"ProductionColumns/CompletedColumn/PageLabel"
	) as Label
	var next_button := workbench.get_node(
		"ProductionColumns/CompletedColumn/NextPageButton"
	) as Button

	var entries := _completed_entries(20)
	workbench.call("refresh_queue", entries, [], 0, false)
	await process_frame
	await process_frame

	_expect_equal("first page cell count", completed_cells.get_child_count(), PAGE_SIZE)
	_expect_equal("first page label", page_label.text, "1 / 3")
	_expect_equal("first page previous disabled", previous_button.disabled, true)
	_expect_equal("first page next enabled", next_button.disabled, false)
	_expect_equal("first page first recipe", _cell_recipe_id(completed_cells, 0), "ready_00")
	_expect_equal("first page last recipe", _cell_recipe_id(completed_cells, 8), "ready_08")

	next_button.pressed.emit()
	await process_frame
	_expect_equal("second page cell count", completed_cells.get_child_count(), PAGE_SIZE)
	_expect_equal("second page label", page_label.text, "2 / 3")
	_expect_equal("second page first recipe", _cell_recipe_id(completed_cells, 0), "ready_09")
	_expect_equal("second page last recipe", _cell_recipe_id(completed_cells, 8), "ready_17")

	next_button.pressed.emit()
	await process_frame
	_expect_equal("last page cell count", completed_cells.get_child_count(), 2)
	_expect_equal("last page label", page_label.text, "3 / 3")
	_expect_equal("last page next disabled", next_button.disabled, true)
	_expect_equal("last page first recipe", _cell_recipe_id(completed_cells, 0), "ready_18")
	_expect_equal("last page last recipe", _cell_recipe_id(completed_cells, 1), "ready_19")

	workbench.call("refresh_queue", entries.slice(0, 5), [], 0, false)
	await process_frame
	await process_frame
	_expect_equal("shrinking entries clamps page", page_label.text, "1 / 1")
	_expect_equal("clamped page cell count", completed_cells.get_child_count(), 5)
	_expect_equal("single page previous disabled", previous_button.disabled, true)
	_expect_equal("single page next disabled", next_button.disabled, true)
	var first_cell := completed_cells.get_child(0) as Control
	var drag_button := first_cell.get_node("DragButton") as Button
	_expect_equal(
		"drag contract remains inventory product",
		String((drag_button.get("drag_data") as Dictionary).get("kind", "")),
		"inventory_product"
	)

	workbench.queue_free()
	await process_frame
	_finish()


func _completed_entries(count: int) -> Array:
	var result: Array = []
	for index in range(count):
		result.append({
			"recipe_id": "ready_%02d" % index,
			"name": "待上架商品%02d" % index,
			"completed_stock_count": index + 1,
			"price": 10 + index,
			"tags": ["测试"],
			"drag_data": {
				"kind": "inventory_product",
				"recipe_id": "ready_%02d" % index
			},
			"drag_preview_text": "待上架商品%02d" % index,
			"drag_preview_data": {},
			"drag_end_callable": Callable()
		})
	return result


func _cell_recipe_id(cells: VBoxContainer, index: int) -> String:
	if index < 0 or index >= cells.get_child_count():
		return ""
	return String((cells.get_child(index) as Control).call("recipe_id"))


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)


func _expect_equal(label: String, actual: Variant, expected: Variant) -> void:
	if actual != expected:
		_expect(false, "%s: expected %s, got %s" % [label, str(expected), str(actual)])


func _finish() -> void:
	if failures.is_empty():
		print("PRODUCTION_COMPLETED_SHELF_PAGINATION_SELF_CHECK_PASS")
		quit(0)
		return
	for failure: String in failures:
		printerr("PRODUCTION_COMPLETED_SHELF_PAGINATION_SELF_CHECK_FAIL: %s" % failure)
	quit(1)
