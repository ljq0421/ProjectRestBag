extends SceneTree

const WorkbenchScene := preload("res://scenes/ui/pages/production_workbench.tscn")
const QueueRowScene := preload("res://scenes/ui/pages/production_queue_recipe_row.tscn")

var failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var workbench := WorkbenchScene.instantiate()
	root.add_child(workbench)
	workbench.size = Vector2(820, 766)
	_expect_equal("workbench minimum height", int(workbench.custom_minimum_size.y), 766)
	var header := workbench.get_node_or_null("ProductionQueueHeader") as Control
	var title_icon := workbench.get_node_or_null("ProductionQueueHeader/TitleIcon") as TextureRect
	var body := workbench.get_node_or_null("ProductionColumns") as HBoxContainer
	var completed_column := workbench.get_node_or_null("ProductionColumns/CompletedColumn") as Control
	var completed_scroll := workbench.get_node_or_null(
		"ProductionColumns/CompletedColumn/CompletedScroll"
	) as ScrollContainer
	var shelf_frame := workbench.get_node_or_null(
		"ProductionColumns/CompletedColumn/ShelfFrame"
	) as TextureRect
	var previous_page_button := workbench.get_node_or_null(
		"ProductionColumns/CompletedColumn/PreviousPageButton"
	) as Button
	var page_label := workbench.get_node_or_null(
		"ProductionColumns/CompletedColumn/PageLabel"
	) as Label
	var next_page_button := workbench.get_node_or_null(
		"ProductionColumns/CompletedColumn/NextPageButton"
	) as Button
	var completed_cells := workbench.get_node_or_null(
		"ProductionColumns/CompletedColumn/CompletedScroll/CompletedCenter/CompletedCells"
	) as VBoxContainer
	var queue_column := workbench.get_node_or_null("ProductionColumns/QueueColumn") as Control
	var queue_scroll := workbench.get_node_or_null(
		"ProductionColumns/QueueColumn/QueueScroll"
	) as ScrollContainer
	var queue_rows := workbench.get_node_or_null(
		"ProductionColumns/QueueColumn/QueueScroll/QueueRows"
	) as VBoxContainer
	_expect(header != null, "header must be declared")
	_expect(title_icon != null, "header must declare the mixer title icon")
	_expect(body != null, "two-column body must be declared")
	_expect(completed_column != null, "completed fixed-width column must be declared")
	_expect(completed_scroll != null, "completed stock scroll must be declared")
	_expect(shelf_frame != null, "completed stock shelf frame must be declared")
	_expect(previous_page_button != null, "completed shelf must declare an up-page button")
	_expect(page_label != null, "completed shelf must declare a page indicator")
	_expect(next_page_button != null, "completed shelf must declare a down-page button")
	_expect(completed_cells != null, "completed stock cells must be declared")
	_expect(queue_scroll != null, "queue scroll must be declared")
	_expect(queue_column != null, "queue fixed-width column must be declared")
	_expect(queue_rows != null, "queue rows must be declared")
	if header != null:
		_expect_equal("header height", int(header.custom_minimum_size.y), 54)
	if title_icon != null:
		_expect_equal("title icon minimum", title_icon.custom_minimum_size, Vector2(24, 24))
		_expect_equal("title icon ignores mouse", title_icon.mouse_filter, Control.MOUSE_FILTER_IGNORE)
		_expect(
			title_icon.texture != null
			and title_icon.texture.resource_path == "res://resources/device_icons/mixer.png",
			"title icon must reuse the existing mixer asset"
		)
	if body != null:
		_expect_equal("body width", int(body.custom_minimum_size.x), 820)
		_expect_equal("body height", int(body.custom_minimum_size.y), 702)
		_expect_equal("column gap", body.get_theme_constant("separation"), 8)
	if completed_scroll != null:
		_expect_equal("completed vertical mode", completed_scroll.vertical_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED)
		_expect_equal("completed horizontal mode", completed_scroll.horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED)
	if completed_column != null:
		_expect_equal("completed column width", int(completed_column.custom_minimum_size.x), 104)
	if queue_scroll != null:
		_expect_equal("queue horizontal mode", queue_scroll.horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED)
	if queue_column != null:
		_expect_equal("queue column width", int(queue_column.custom_minimum_size.x), 708)
		_expect_equal("queue viewport height", int(queue_column.custom_minimum_size.y), 702)
	if queue_rows != null:
		_expect_equal("row separation", queue_rows.get_theme_constant("separation"), 6)
	if completed_cells != null:
		_expect_equal("completed cell separation", completed_cells.get_theme_constant("separation"), 2)
	if previous_page_button != null:
		_expect_equal("previous page button height", int(previous_page_button.size.y), 26)
	if page_label != null:
		_expect_equal("page indicator height", int(page_label.size.y), 18)
	if next_page_button != null:
		_expect_equal("next page button height", int(next_page_button.size.y), 26)
	_expect(workbench.get_node_or_null("ProductionColumns/CompletedTitleLabel") == null, "left column must not declare a category title")
	_expect(workbench.get_node_or_null("ProductionColumns/CompletedColumn/CompletedScroll/CompletedCenter/CompletedCells/EmptyLabel") == null, "left column must not declare an empty label")
	_expect(workbench.get_node_or_null("ProductionQueueHeader/SearchField") is LineEdit, "search must live in header")
	_expect(workbench.get_node_or_null("ProductionQueueHeader/BulkActionButton") is MenuButton, "bulk menu must live in header")
	_expect(workbench.get_node_or_null("ProductionQueueHeader/KitchenScheduleButton") is Button, "automation entry must live in header")
	_expect(workbench.get_node_or_null("RecipeEntryBar") == null, "old footer must be absent")
	_expect_equal("nine rows fit fully", 9 * 68 + 8 * 6 <= 702, true)
	_expect_equal("tenth row remains scrollable", 10 * 68 + 9 * 6 > 702, true)
	_expect_equal("nine shelf cells fit", 9 * 68 + 8 * 2, 628)
	var queue_fixtures: Array = []
	for fixture_index in range(11):
		queue_fixtures.append({
			"entry_kind": "finished",
			"recipe_id": "fixture_%d" % fixture_index,
			"name": "配方%d" % fixture_index,
			"materials": [],
			"duration_seconds": 4,
			"price": 16,
			"action_kind": "make",
			"action_enabled": true
		})
	workbench.call("refresh_queue", [
		{
			"recipe_id": "rice_milk_drink",
			"name": "米浆饮",
			"completed_stock_count": 3,
			"price": 12,
			"tags": ["经典"],
			"drag_data": {"kind": "inventory_product", "recipe_id": "rice_milk_drink"}
		}
	], queue_fixtures, 0, false)
	await process_frame
	await process_frame
	_expect_equal("runtime workbench width with scrollbar", int(workbench.size.x), 820)
	if body != null:
		_expect_equal("runtime body width with scrollbar", int(body.size.x), 820)
	if completed_scroll != null:
		_expect_equal("runtime completed width", int(completed_scroll.size.x), 104)
	if queue_scroll != null:
		_expect_equal("runtime queue width with scrollbar", int(queue_scroll.size.x), 708)
	if completed_cells != null:
		_expect_equal("completed entry renders in left column", completed_cells.get_child_count(), 1)
	if queue_rows != null:
		_expect_equal("queue entries render beside empty panel", queue_rows.get_child_count(), 12)

	var row := QueueRowScene.instantiate()
	root.add_child(row)
	row.size = Vector2(708, 68)
	_expect_equal("row minimum height", int(row.custom_minimum_size.y), 68)
	var icon_button := row.get_node_or_null("Content/ProductIconButton") as Button
	var product_texture := row.get_node_or_null("Content/ProductIconButton/ProductTexture") as TextureRect
	_expect(icon_button != null, "row must declare product icon button")
	_expect(product_texture != null, "row must declare a full-size product texture")
	if icon_button != null:
		_expect_equal("product icon width", int(icon_button.custom_minimum_size.x), 68)
		_expect_equal("product icon height", int(icon_button.custom_minimum_size.y), 68)
		_expect(not icon_button.has_method("configure_drag"), "right row icon must not own completed-stock drag")
	if product_texture != null:
		_expect_equal("product texture minimum", product_texture.custom_minimum_size, Vector2(68, 68))
	_expect_equal("row content separation", (row.get_node("Content") as HBoxContainer).get_theme_constant("separation"), 4)
	_expect_equal("name width", (row.get_node("Content/RecipeNameLabel") as Label).custom_minimum_size.x, 90.0)
	_expect_equal("material width", (row.get_node("Content/MaterialStrip") as Control).custom_minimum_size.x, 300.0)
	_expect_equal("time width", (row.get_node("Content/TimeGroup") as HBoxContainer).custom_minimum_size.x, 60.0)
	_expect_equal("price width", (row.get_node("Content/PriceGroup") as HBoxContainer).custom_minimum_size.x, 60.0)
	_expect_equal("action width", (row.get_node("Content/ActionButton") as Button).custom_minimum_size.x, 76.0)
	var progress_layer := row.get_node_or_null("ProgressLayer") as Control
	var progress_fill := row.get_node_or_null("ProgressLayer/ProgressFill") as ColorRect
	_expect(progress_layer != null, "whole-row progress layer must be declared")
	_expect(progress_fill != null, "whole-row progress fill must live below the progress layer")
	_expect(row.get_node_or_null("ProgressFill") == null, "progress fill must not be managed directly by the row container")
	if progress_layer != null:
		_expect_equal("progress layer ignores mouse input", progress_layer.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	if progress_fill != null:
		_expect_equal("progress fill ignores mouse input", progress_fill.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	_expect(row.get_node_or_null("Content/TimeGroup/ClockIcon") is TextureRect, "clock icon must be declared")
	_expect(row.get_node_or_null("Content/PriceGroup/CoinIcon") is TextureRect, "coin icon must be declared")
	_expect(not _tree_contains_type(row, "ProgressBar"), "row must not contain a ProgressBar")
	_expect(row.get_node_or_null("Content/BatchSlots") == null, "per-batch slots must be absent")

	row.call("configure", {
		"entry_kind": "processing",
		"recipe_id": "rice_flour_process",
		"name": "大米粉",
		"materials": [
			{"name": "大米", "owned_count": 3, "required_count": 1, "display_text": "大米 3/1", "missing": false},
			{"name": "泉水", "owned_count": 0, "required_count": 1, "display_text": "泉水 0/1", "missing": true}
		],
		"duration_seconds": 2,
		"remaining_seconds": 1,
		"price": 0,
		"is_active": true,
		"progress": 0.5,
		"action_kind": "active",
		"completed_stock_count": 0
	})
	await process_frame
	var material_strip := row.get_node("Content/MaterialStrip/MaterialItems") as HFlowContainer
	_expect(material_strip != null, "material items must use a horizontal flow container")
	if material_strip != null:
		_expect_equal(
			"material horizontal gap",
			material_strip.get_theme_constant("h_separation"),
			4
		)
		_expect_equal(
			"material vertical gap",
			material_strip.get_theme_constant("v_separation"),
			4
		)
	_expect_equal(
		"runtime material strip width",
		int((row.get_node("Content/MaterialStrip") as Control).size.x),
		300
	)
	_expect_equal("material chip count", material_strip.get_child_count(), 2)
	if material_strip.get_child_count() == 2:
		_expect(_node_text_contains(material_strip.get_child(0), "大米"), "material chip must show its name")
		_expect(_node_text_contains(material_strip.get_child(0), "×1"), "material chip must show its quantity")
		_expect(_node_text_contains(material_strip.get_child(1), "泉水"), "missing chip must show its name")
		_expect(_node_text_contains(material_strip.get_child(1), "0/1"), "missing chip must show current and required quantity")
	if material_strip.get_child_count() == 2:
		var sufficient_item := material_strip.get_child(0) as HBoxContainer
		var missing_item := material_strip.get_child(1) as HBoxContainer
		_expect(sufficient_item != null, "sufficient material must use an unboxed row")
		_expect(missing_item != null, "missing material must use an unboxed row")
		_expect(
			not material_strip.get_child(0) is PanelContainer,
			"material must not render a panel frame"
		)
		_expect(
			not material_strip.get_child(1) is PanelContainer,
			"missing material must not render a panel frame"
		)
		if sufficient_item != null and missing_item != null:
			var sufficient_name := sufficient_item.get_node("MaterialNameLabel") as Label
			var sufficient_quantity := sufficient_item.get_node("MaterialQuantityLabel") as Label
			var missing_name := missing_item.get_node("MaterialNameLabel") as Label
			_expect_equal(
				"material name font size",
				sufficient_name.get_theme_font_size("font_size"),
				13
			)
			_expect_equal(
				"material quantity font size",
				sufficient_quantity.get_theme_font_size("font_size"),
				13
			)
			_expect_equal(
				"missing material text stays neutral",
				missing_name.get_theme_color("font_color"),
				sufficient_name.get_theme_color("font_color")
			)
	_expect_equal("processing price displays zero", (row.get_node("Content/PriceGroup/PriceValue") as Label).text, "0")
	_expect_equal("active time displays remaining seconds", (row.get_node("Content/TimeGroup/TimeValue") as Label).text, "1s")
	_expect_equal("active action is disabled", (row.get_node("Content/ActionButton") as Button).disabled, true)
	row.call("_apply_progress_width")
	_expect(is_equal_approx(progress_fill.size.x, row.size.x * 0.5), "whole row should fill to runtime progress")
	row.queue_sort()
	await process_frame
	await process_frame
	_expect(
		is_equal_approx(progress_fill.size.x, row.size.x * 0.5),
		"row container sorting must not overwrite active progress width"
	)

	var dense_materials: Array = []
	for material_index in range(6):
		dense_materials.append({
			"name": "超长材料名称%d" % material_index,
			"owned_count": 0,
			"required_count": 10,
			"display_text": "超长材料名称%d 0/10" % material_index,
			"missing": true
		})
	row.call("configure", {
		"entry_kind": "finished",
		"recipe_id": "three_material_recipe",
		"name": "三材料配方",
		"materials": dense_materials.slice(0, 3),
		"duration_seconds": 8,
		"price": 30,
		"action_kind": "restock",
		"action_enabled": true
	})
	await process_frame
	await process_frame
	_expect_equal("three materials stay on one line", material_strip.get_line_count(), 1)

	row.call("configure", {
		"entry_kind": "finished",
		"recipe_id": "four_material_recipe",
		"name": "四材料配方",
		"materials": dense_materials.slice(0, 4),
		"duration_seconds": 8,
		"price": 30,
		"action_kind": "restock",
		"action_enabled": true
	})
	await process_frame
	await process_frame
	_expect_equal("four materials use two lines", material_strip.get_line_count(), 2)
	var first_of_four := material_strip.get_child(0) as Control
	var fourth_of_four := material_strip.get_child(3) as Control
	_expect_equal(
		"fourth material starts the second line",
		fourth_of_four.position.x,
		first_of_four.position.x
	)
	_expect(
		fourth_of_four.position.y > first_of_four.position.y,
		"fourth material must sit below the first"
	)

	row.call("configure", {
		"entry_kind": "finished",
		"recipe_id": "six_material_recipe",
		"name": "六材料配方",
		"materials": dense_materials,
		"duration_seconds": 8,
		"price": 30,
		"action_kind": "restock",
		"action_enabled": true
	})
	await process_frame
	await process_frame
	_expect_equal("six material chips remain declared", material_strip.get_child_count(), 6)
	_expect_equal("dense material container stays 300px", int(material_strip.size.x), 300)
	_expect_equal("six materials use two lines", material_strip.get_line_count(), 2)
	var first_of_six := material_strip.get_child(0) as Control
	var second_of_six := material_strip.get_child(1) as Control
	var fourth_of_six := material_strip.get_child(3) as Control
	var fifth_of_six := material_strip.get_child(4) as Control
	_expect_equal(
		"six materials use three columns",
		fourth_of_six.position.x,
		first_of_six.position.x
	)
	_expect_equal(
		"second row keeps the second column",
		fifth_of_six.position.x,
		second_of_six.position.x
	)
	for material_chip_value: Variant in material_strip.get_children():
		var material_chip := material_chip_value as HBoxContainer
		var quantity_label := material_chip.get_node("MaterialQuantityLabel") as Label
		_expect(
			is_equal_approx(material_chip.size.x, 292.0 / 3.0),
			"material item must use one-third width"
		)
		_expect_equal("dense quantity remains complete", quantity_label.text, "0/10")
		_expect_equal("dense quantity does not clip", quantity_label.clip_text, false)
		_expect(
			material_chip.position.x + material_chip.size.x \
					<= material_strip.size.x + 0.1,
			"dense material chips must stay inside the 300px strip"
		)
		_expect(
			material_chip.position.y + material_chip.size.y \
					<= material_strip.size.y + 0.1,
			"dense material chips must stay inside the 68px strip"
		)

	row.call("configure", {
		"entry_kind": "finished",
		"recipe_id": "rice_milk_drink",
		"name": "米浆饮",
		"materials": [{"name": "大米", "display_text": "大米 ×1", "missing": false}],
		"duration_seconds": 2,
		"price": 12,
		"is_active": false,
		"action_kind": "make",
		"completed_stock_count": 2,
		"completed_stock_drag_enabled": true,
		"completed_stock_tooltip": "拖到橱窗上架",
		"drag_data": {"kind": "inventory_product", "recipe_id": "rice_milk_drink"},
		"drag_preview_text": "米浆饮",
		"drag_preview_data": {"shape_rows": 1, "shape_cols": 1}
	})
	row.queue_sort()
	await process_frame
	await process_frame
	_expect(
		is_zero_approx(progress_fill.size.x),
		"row container sorting must keep inactive progress width at zero"
	)
	_expect(not _tree_text_contains(row, "耗时"), "row must not display the duration label")
	_expect(not _tree_text_contains(row, "售价"), "row must not display the price label")
	_expect(not _tree_text_contains(row, "%"), "row must not display a progress percentage")

	row.queue_free()
	workbench.queue_free()
	_finish()


func _tree_contains_type(node: Node, class_name_value: String) -> bool:
	if node.is_class(class_name_value):
		return true
	for child in node.get_children():
		if _tree_contains_type(child, class_name_value):
			return true
	return false


func _tree_text_contains(node: Node, needle: String) -> bool:
	if node is Label and (node as Label).text.find(needle) >= 0:
		return true
	if node is Button and (node as Button).text.find(needle) >= 0:
		return true
	for child in node.get_children():
		if _tree_text_contains(child, needle):
			return true
	return false


func _node_text_contains(node: Node, needle: String) -> bool:
	return _tree_text_contains(node, needle)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _expect_equal(label: String, actual: Variant, expected: Variant) -> void:
	if actual != expected:
		failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])


func _finish() -> void:
	if failures.is_empty():
		print("PRODUCTION_QUEUE_SCENE_SELF_CHECK_PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
