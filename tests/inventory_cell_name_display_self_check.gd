extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/Main.tscn"

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed_scene := load(MAIN_SCENE_PATH) as PackedScene
	if packed_scene == null:
		_fail("Main scene is missing")
		_finish()
		return

	var main := packed_scene.instantiate()
	_check_icon_cell(main, {
		"kind": "ingredient",
		"kind_label": "调味",
		"id": "sugar",
		"name": "白糖",
		"count": 3,
		"source": "采购"
	}, "白糖", 3)
	_check_icon_cell(main, {
		"kind": "product",
		"kind_label": "成品",
		"id": "rice_milk_drink",
		"name": "米浆饮",
		"count": 2,
		"source": "圆锅"
	}, "米浆饮", 2)

	var tool_cell := main.call("_make_inventory_cell", "", {
		"kind": "tool",
		"kind_label": "工具",
		"id": "farm_accelerator",
		"name": "农场加速器",
		"count": 1,
		"source": "工具箱"
	}) as Button
	if tool_cell == null or tool_cell.text.find("农场加速器") == -1:
		_fail("text-only inventory cells should display the Chinese item name")
	if tool_cell != null:
		_check_no_source_display(tool_cell)
		tool_cell.free()

	main.free()
	_finish()


func _check_icon_cell(main: Node, entry: Dictionary, expected_name: String, expected_count: int) -> void:
	var cell := main.call("_make_inventory_cell", "", entry) as Button
	if cell == null:
		_fail("inventory cell should be created for %s" % expected_name)
		return
	var name_label := cell.get_node_or_null("NameLabel") as Label
	if name_label == null:
		_fail("icon inventory cell should include NameLabel for %s" % expected_name)
	elif name_label.text != expected_name:
		_fail("inventory NameLabel should show %s, got %s" % [expected_name, name_label.text])
	var quantity_badge := cell.get_node_or_null("QuantityBadge") as Label
	if quantity_badge == null or quantity_badge.text != str(expected_count):
		_fail("inventory cell should keep quantity %d for %s" % [expected_count, expected_name])
	elif quantity_badge.offset_bottom - quantity_badge.offset_top < 20.0:
		_fail("inventory quantity badge should keep a visible height for %s" % expected_name)
	_check_no_source_display(cell)
	cell.free()


func _check_no_source_display(cell: Button) -> void:
	var pending: Array[Node] = [cell]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if node != cell and node is Button and node.has_meta("inventory_source_action"):
			_fail("inventory cell should not include a clickable source label")
		if node is Label or node is Button:
			var text_value := String(node.get("text"))
			if text_value in ["采购", "农场", "养殖场", "林场", "水塘"]:
				_fail("inventory cell should not display source text: %s" % text_value)
		for child in node.get_children():
			pending.append(child)


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("INVENTORY_CELL_NAME_DISPLAY_SELF_CHECK_PASS")
		quit(0)
		return
	for failure in _failures:
		printerr("INVENTORY_CELL_NAME_DISPLAY_SELF_CHECK_FAIL: %s" % failure)
	quit(1)
