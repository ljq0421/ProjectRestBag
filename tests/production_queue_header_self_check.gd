extends SceneTree

const WorkbenchScene := preload("res://scenes/ui/pages/production_workbench.tscn")

var failures: Array[String] = []
var search_value := ""
var bulk_action := ""


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var workbench := WorkbenchScene.instantiate()
	root.add_child(workbench)
	await process_frame
	workbench.search_changed.connect(func(query: String) -> void: search_value = query)
	workbench.bulk_action_requested.connect(func(action: String) -> void: bulk_action = action)

	var search := workbench.get_node("ProductionQueueHeader/SearchField") as LineEdit
	var bulk := workbench.get_node("ProductionQueueHeader/BulkActionButton") as MenuButton
	var popup := bulk.get_popup()
	_expect_equal("bulk action count", popup.item_count, 3)
	_expect_equal("first bulk action", popup.get_item_text(0), "制作全部")
	_expect_equal("second bulk action", popup.get_item_text(1), "一键补货")
	_expect_equal("third bulk action", popup.get_item_text(2), "上架全部")

	search.text = "米浆"
	search.text_changed.emit(search.text)
	_expect_equal("search emits header query", search_value, "米浆")
	popup.id_pressed.emit(0)
	_expect_equal("make-all action routes from header", bulk_action, "make_all")
	popup.id_pressed.emit(1)
	_expect_equal("restock-all action routes from header", bulk_action, "restock_all")
	popup.id_pressed.emit(2)
	_expect_equal("list-all action routes from header", bulk_action, "list_all")

	workbench.call("refresh_bulk_action_unlocks", true, false, true)
	_expect(not popup.is_item_disabled(popup.get_item_index(0)), "unlocked make-all should be enabled")
	_expect(popup.is_item_disabled(popup.get_item_index(1)), "locked restock-all should be disabled")
	_expect(not popup.is_item_disabled(popup.get_item_index(2)), "unlocked list-all should be enabled")

	_expect(not ResourceLoader.exists("res://scenes/ui/overlays/production_recipe_picker_overlay.tscn"), "old production picker scene must be removed")
	_expect(not ResourceLoader.exists("res://scenes/ui/overlays/production_recipe_card.tscn"), "old production card scene must be removed")

	workbench.queue_free()
	await process_frame
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _expect_equal(label: String, actual: Variant, expected: Variant) -> void:
	if actual != expected:
		failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])


func _finish() -> void:
	if failures.is_empty():
		print("PRODUCTION_QUEUE_HEADER_SELF_CHECK_PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
