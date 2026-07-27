extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene := load("res://scenes/ui/pages/production_completed_stock_cell.tscn") as PackedScene
	_expect(scene != null, "completed stock cell scene must exist")
	if scene == null:
		_finish()
		return

	var cell := scene.instantiate() as Control
	root.add_child(cell)
	var icon := GradientTexture2D.new()
	icon.width = 128
	icon.height = 128
	cell.call("configure", {
		"recipe_id": "caramel_pudding_steamed",
		"name": "焦糖布丁",
		"icon": icon,
		"completed_stock_count": 3,
		"price": 20,
		"tags": ["奶香", "甜"],
		"drag_data": {
			"kind": "inventory_product",
			"recipe_id": "caramel_pudding_steamed"
		},
		"drag_preview_text": "焦糖布丁",
		"drag_preview_data": {},
		"drag_end_callable": Callable()
	})
	await process_frame

	var drag_button := cell.get_node("DragButton") as Button
	var product_texture := cell.get_node("DragButton/ProductTexture") as TextureRect
	var stock_badge := cell.get_node("DragButton/StockBadge") as Label
	_expect_equal("cell size", cell.custom_minimum_size, Vector2(68, 68))
	_expect_equal("cell runtime size", cell.size, Vector2(68, 68))
	_expect_equal("texture canvas size", product_texture.size, Vector2(68, 68))
	_expect_equal("texture binding", product_texture.texture, icon)
	_expect_equal("badge text", stock_badge.text, "3")
	_expect_equal(
		"tooltip",
		drag_button.tooltip_text,
		"焦糖布丁\n库存：3\n售价：20\n标签：奶香、甜"
	)
	_expect_equal("recipe id accessor", String(cell.call("recipe_id")), "caramel_pudding_steamed")
	_expect_equal("recipe id metadata", String(cell.get_meta("recipe_id", "")), "caramel_pudding_steamed")
	_expect_equal("drag kind", String((drag_button.get("drag_data") as Dictionary).get("kind", "")), "inventory_product")
	_expect(not drag_button.text.contains("拖拽"), "cell must not show drag instructions")

	cell.queue_free()
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
		print("PRODUCTION_COMPLETED_STOCK_CELL_SELF_CHECK_PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
