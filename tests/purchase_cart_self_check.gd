extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/Main.tscn"
const GAME_STATE_PATH := "res://scripts/game_state.gd"
const VIEWPORT_SIZE := Vector2i(1920, 1080)

var _failures: Array[String] = []
var _save_path := ""


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = VIEWPORT_SIZE
	var packed_scene := load(MAIN_SCENE_PATH)
	if packed_scene == null:
		_fail("Main scene is missing")
		_finish()
		return

	var main: Control = (packed_scene as PackedScene).instantiate()
	_save_path = OS.get_temp_dir().path_join("purchase_cart_self_check_%d.json" % Time.get_ticks_usec())
	main.set("save_path", _save_path)
	root.add_child(main)
	await process_frame
	await process_frame

	var game_state_script := load(GAME_STATE_PATH)
	var state = game_state_script.new_game()
	state.level = 1
	state.shop_level = 1
	state.coins = 6
	main.set("state", state)
	main.call("_show_page", "purchase")
	await process_frame

	var regions_grid: GridContainer = main.get_node_or_null("GlobalOverlayLayer/OverlayFrame/OverlayModeStack/PurchaseOverlay/PurchaseRegionsGrid")
	var cart_label: Label = main.get_node_or_null("GlobalOverlayLayer/OverlayFrame/OverlayModeStack/PurchaseOverlay/PurchaseFooter/PurchaseCartLabel")
	var purchase_button: Button = main.get_node_or_null("GlobalOverlayLayer/OverlayFrame/OverlayModeStack/PurchaseOverlay/PurchaseFooter/PurchaseConfirmButton")
	var output_button: Button = main.get_node_or_null("Root/Body/MainArea/WorkbenchPanel/WorkbenchLauncher/OutputButton")
	var receipt_dialog: Control = main.get_node_or_null("PurchaseReceiptDialog")
	var task_popup: AcceptDialog = main.get_node_or_null("TaskPopup")
	if cart_label == null:
		_fail("purchase page should expose a cart summary label on the left side of ActionRow")
	if regions_grid == null:
		_fail("purchase page should expose the six-region grid")
	if purchase_button == null:
		_fail("purchase button should move to the right side of ActionRow")
	elif purchase_button.text != "购买":
		_fail("purchase button should keep the buy label")
	if receipt_dialog == null:
		_fail("purchase flow should expose a dedicated receipt dialog")
	if cart_label == null or regions_grid == null or purchase_button == null:
		main.queue_free()
		_finish()
		return

	var farm_region := _find_purchase_region(regions_grid, "农场")
	var forest_region := _find_purchase_region(regions_grid, "林场")
	var supply_region := _find_purchase_region(regions_grid, "辅料")
	var pond_region := _find_purchase_region(regions_grid, "水塘")
	if farm_region == null or forest_region == null or supply_region == null or pond_region == null:
		_fail("purchase grid should include farm, forest, supply, and pond regions")
		main.queue_free()
		_finish()
		return
	if receipt_dialog != null:
		purchase_button.emit_signal("pressed")
		await process_frame
		if receipt_dialog.visible:
			_fail("empty cart purchase should not show a receipt")

	main.set("purchase_cart_quantities", {})
	var rice_row := _find_purchase_row(farm_region, "rice_seed")
	if rice_row == null:
		_fail("farm purchase cart should show rice_seed row")
		main.queue_free()
		_finish()
		return
	if _row_child_index(rice_row, "PurchaseMinusButton") <= _row_child_index(rice_row, "PurchaseItemLabel"):
		_fail("purchase minus button should appear after the item label in the same row")
	var item_text := (rice_row.get_node("PurchaseItemLabel") as Label).text
	if item_text.find("金币") != -1 or item_text.find("库存") != -1:
		_fail("purchase row should use icons instead of visible coin and stock words")
	if (rice_row.get_node("PurchaseItemLabel") as Label).text_overrun_behavior != TextServer.OVERRUN_TRIM_ELLIPSIS:
		_fail("purchase item names should trim with an ellipsis inside narrow regions")
	var coin_icon := rice_row.get_node_or_null("PriceStat/CoinIcon") as TextureRect
	var stock_icon := rice_row.get_node_or_null("StockStat/StockIcon") as TextureRect
	if coin_icon == null or coin_icon.texture == null or coin_icon.tooltip_text != "单价":
		_fail("purchase row should expose a tooltip-backed coin icon")
	if stock_icon == null or stock_icon.texture == null or stock_icon.tooltip_text != "当前库存":
		_fail("purchase row should expose a tooltip-backed stock icon")
	_expect_quantity("rice_seed default quantity", rice_row, 0)
	_expect_cart_count(cart_label, 0)
	forest_region.call("populate", main.call("_purchase_region_entries", "农场"))
	var mirrored_rice_row := _find_purchase_row(forest_region, "rice_seed")
	if mirrored_rice_row == null:
		_fail("duplicate-source fixture should expose a second rice_seed row")
	else:
		_press_row_button(mirrored_rice_row, "PurchasePlusButton")
		await process_frame
		_expect_quantity("farm duplicate row sync", rice_row, 1)
		_expect_quantity("forest duplicate row sync", mirrored_rice_row, 1)
		_press_row_button(rice_row, "PurchaseMinusButton")
		await process_frame
		_expect_quantity("farm duplicate row reset", rice_row, 0)
		_expect_quantity("forest duplicate row reset", mirrored_rice_row, 0)
	main.call("_refresh_purchase_page")
	await process_frame
	rice_row = _find_purchase_row(farm_region, "rice_seed")

	var farm_scroll := farm_region.get_node("ContentMargin/RegionContent/ItemsScroll") as ScrollContainer
	farm_scroll.scroll_vertical = 12
	await process_frame
	var scroll_before_plus := farm_scroll.scroll_vertical
	_press_row_button(rice_row, "PurchasePlusButton")
	await process_frame
	if farm_scroll.scroll_vertical != scroll_before_plus:
		_fail("quantity changes should preserve the farm region scroll position")
	_press_row_button(rice_row, "PurchasePlusButton")
	await process_frame
	_expect_quantity("rice_seed quantity after plus", rice_row, 2)
	_expect_cart_count(cart_label, 2)

	var sugar_row := _find_purchase_row(supply_region, "sugar")
	if sugar_row == null:
		_fail("level-one supply purchase cart should show sugar row")
		main.queue_free()
		_finish()
		return
	_expect_quantity("sugar default quantity", sugar_row, 0)
	_expect_cart_count(cart_label, 2)
	_press_row_button(sugar_row, "PurchasePlusButton")
	await process_frame
	_expect_quantity("sugar quantity after plus", sugar_row, 1)
	_expect_cart_count(cart_label, 3)

	var water_starter_row := _find_purchase_row(pond_region, "spring_water_starter")
	if water_starter_row == null:
		_fail("level-one pond purchase cart should show spring_water_starter row")
		main.queue_free()
		_finish()
		return
	_expect_quantity("spring_water_starter default quantity", water_starter_row, 0)
	_press_row_button(water_starter_row, "PurchasePlusButton")
	await process_frame
	_expect_quantity("spring_water_starter quantity after plus", water_starter_row, 1)
	_expect_cart_count(cart_label, 4)
	if not (sugar_row.get_node("PurchasePlusButton") as Button).disabled:
		_fail("reaching the cart budget should disable plus buttons across all purchase regions")

	_expect_quantity("rice_seed quantity should survive cross-region changes", rice_row, 2)
	_press_row_button(rice_row, "PurchasePlusButton")
	await process_frame
	_expect_quantity("rice_seed plus should stop at affordable cart total", rice_row, 2)
	_expect_cart_count(cart_label, 4)

	var rice_before: int = state.get_ingredient_count("rice_seed")
	var sugar_before: int = state.get_ingredient_count("sugar")
	var water_starter_before: int = state.get_ingredient_count("spring_water_starter")
	_expect_stock("rice_seed visible stock before purchase", rice_row, rice_before)
	state.enqueue_notification("延后提示", "小票关闭后再展示。")
	main.call("_show_next_notification")
	await process_frame
	var deferred_notification_title := ""
	var deferred_notification_body := ""
	if task_popup == null or not task_popup.visible:
		_fail("notification fixture should be visible before opening the purchase receipt")
	else:
		deferred_notification_title = task_popup.title
		deferred_notification_body = task_popup.dialog_text
	purchase_button.emit_signal("pressed")
	await process_frame
	_expect_field_value("cart purchase coins", state.to_dict(), "coins", 0)
	_expect_field_value("cart purchase rice_seed stock", state.to_dict().get("ingredient_inventory", {}), "rice_seed", rice_before + 2)
	_expect_field_value("cart purchase sugar stock", state.to_dict().get("ingredient_inventory", {}), "sugar", sugar_before + 1)
	_expect_field_value("cart purchase spring_water_starter stock", state.to_dict().get("ingredient_inventory", {}), "spring_water_starter", water_starter_before + 1)
	_expect_cart_count(cart_label, 0)
	if not bool(main.get("purchase_page_refresh_pending")):
		_fail("successful purchase should defer the full purchase page refresh until receipt close")
	_expect_stock("receipt should keep the pre-purchase row snapshot visible", rice_row, rice_before)
	if receipt_dialog != null:
		if not receipt_dialog.visible:
			_fail("successful cart purchase should show a centered receipt dialog")
		if task_popup != null and task_popup.visible:
			_fail("pending notifications should wait while the purchase receipt is visible")
		var receipt_close_button := receipt_dialog.get_node_or_null("ReceiptFrame/ReceiptCloseButton") as Button
		if receipt_close_button == null or receipt_close_button.text != "收好小票":
			_fail("purchase receipt should expose the 收好小票 action")
		if receipt_dialog.get_node_or_null("ReceiptFrame/ReceiptBackdrop") != null:
			_fail("purchase receipt should not draw a solid yellow rectangle behind the transparent paper")
		if receipt_dialog.get_node_or_null("ReceiptFrame/ReceiptDragHandle") != null:
			_fail("purchase receipt should use the whole paper instead of an invisible drag handle")
		var receipt_body := receipt_dialog.get_node_or_null("ReceiptFrame/ReceiptBody") as ScrollContainer
		var receipt_grid := receipt_dialog.get_node_or_null("ReceiptFrame/ReceiptBody/ReceiptContent/ReceiptGrid") as GridContainer
		var receipt_summary := receipt_dialog.get_node_or_null("ReceiptFrame/ReceiptBody/ReceiptContent/ReceiptSummary") as Label
		if receipt_grid == null:
			_fail("purchase receipt should expose a four-column receipt grid")
		else:
			_expect_receipt_grid(receipt_grid, [
				["商品", "数量", "单价", "小计"],
				["水稻种子", "2", "1", "2"],
				["泉水引", "1", "1", "1"],
				["白糖", "1", "3", "3"]
			])
		if receipt_summary == null:
			_fail("purchase receipt should expose a separate summary")
		else:
			_expect_receipt_contains(receipt_summary.text, "商品总件数：4")
			_expect_receipt_contains(receipt_summary.text, "总支出：6 金币")
			_expect_receipt_contains(receipt_summary.text, "剩余金币：0")
		var receipt_frame := receipt_dialog.get_node_or_null("ReceiptFrame") as Control
		var receipt_rect := receipt_frame.get_global_rect() if receipt_frame != null else Rect2()
		if receipt_frame == null or receipt_body == null:
			_fail("purchase receipt should expose a draggable paper surface")
		else:
			var drag_start := receipt_body.get_global_rect().get_center()
			var frame_before_drag := receipt_frame.global_position
			var drag_press := InputEventMouseButton.new()
			drag_press.button_index = MOUSE_BUTTON_LEFT
			drag_press.pressed = true
			drag_press.position = drag_start
			drag_press.global_position = drag_start
			Input.parse_input_event(drag_press)
			await process_frame
			if not bool(receipt_dialog.get("receipt_dragging")):
				_fail("receipt drag handle should begin a drag on mouse press")
			var drag_motion := InputEventMouseMotion.new()
			drag_motion.position = drag_start + Vector2(48.0, 32.0)
			drag_motion.global_position = drag_motion.position
			drag_motion.relative = Vector2(48.0, 32.0)
			drag_motion.button_mask = MOUSE_BUTTON_MASK_LEFT
			Input.parse_input_event(drag_motion)
			await process_frame
			var drag_release := InputEventMouseButton.new()
			drag_release.button_index = MOUSE_BUTTON_LEFT
			drag_release.pressed = false
			drag_release.position = drag_motion.position
			drag_release.global_position = drag_motion.global_position
			Input.parse_input_event(drag_release)
			await process_frame
			if receipt_frame.global_position == frame_before_drag:
				_fail("dragging from the receipt table should move the receipt frame")
			receipt_frame.global_position = frame_before_drag
			var wheel_event := InputEventMouseButton.new()
			wheel_event.button_index = MOUSE_BUTTON_WHEEL_DOWN
			wheel_event.pressed = true
			wheel_event.position = receipt_body.get_global_rect().get_center()
			wheel_event.global_position = wheel_event.position
			if bool(receipt_dialog.call("handle_pointer_input", wheel_event)):
				_fail("purchase receipt should leave mouse-wheel events available for scrolling")
		if receipt_close_button != null:
			await _click_viewport_position(receipt_close_button.get_global_rect().get_center())
			if receipt_dialog.visible:
				_fail("receipt close action should hide the purchase receipt")
		await process_frame
		if bool(main.get("purchase_page_refresh_pending")):
			_fail("closing the receipt should consume the deferred purchase page refresh")
		rice_row = _find_purchase_row(farm_region, "rice_seed")
		_expect_stock("receipt close should refresh purchased stock", rice_row, rice_before + 2)
		if task_popup == null or not task_popup.visible:
			_fail("pending notifications should resume after the purchase receipt closes")
		elif task_popup.title != deferred_notification_title or task_popup.dialog_text != deferred_notification_body:
			_fail("purchase receipt should restore the same suspended notification")
		if task_popup != null:
			task_popup.hide()
		main.set("purchase_receipt_suspended_task_popup", true)
		receipt_dialog.show()
		await process_frame
		var background_click_position := output_button.get_global_rect().get_center() if output_button != null else Vector2(20.0, 20.0)
		if output_button == null:
			_fail("purchase receipt background-click check requires the output page button")
		elif receipt_rect.has_point(background_click_position):
			_fail("output page button should be outside the centered purchase receipt")
		var popup_before_background_click := String(main.get("global_popup_mode"))
		var cart_before_background_click: Dictionary = (main.get("purchase_cart_quantities") as Dictionary).duplicate(true)
		var coins_before_background_click: int = state.coins
		var rice_before_background_click: int = state.get_ingredient_count("rice_seed")
		var sugar_before_background_click: int = state.get_ingredient_count("sugar")
		var water_before_background_click: int = state.get_ingredient_count("spring_water_starter")
		await _click_viewport_position(background_click_position)
		if receipt_dialog.visible:
			_fail("purchase receipt should hide when the player clicks the background outside it")
		if String(main.get("global_popup_mode")) != popup_before_background_click:
			_fail("purchase receipt background click should not activate the underlying output page button")
		if (main.get("purchase_cart_quantities") as Dictionary) != cart_before_background_click:
			_fail("purchase receipt background click should not change the cleared purchase cart")
		_expect_field_value("background click coins", state.to_dict(), "coins", coins_before_background_click)
		_expect_field_value("background click rice_seed stock", state.to_dict().get("ingredient_inventory", {}), "rice_seed", rice_before_background_click)
		_expect_field_value("background click sugar stock", state.to_dict().get("ingredient_inventory", {}), "sugar", sugar_before_background_click)
		_expect_field_value("background click spring_water_starter stock", state.to_dict().get("ingredient_inventory", {}), "spring_water_starter", water_before_background_click)
		await process_frame
		if task_popup == null or not task_popup.visible:
			_fail("pending notifications should resume after the purchase receipt closes")
		elif task_popup.title != deferred_notification_title or task_popup.dialog_text != deferred_notification_body:
			_fail("purchase receipt should restore the same suspended notification")

	main.queue_free()
	_finish()


func _click_viewport_position(position: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = position
	press.global_position = position
	Input.parse_input_event(press)
	await process_frame
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = position
	release.global_position = position
	Input.parse_input_event(release)
	await process_frame


func _find_purchase_region(grid: GridContainer, category_id: String) -> Control:
	for child in grid.get_children():
		if child is Control and String(child.get("category_id")) == category_id:
			return child as Control
	return null


func _find_purchase_row(region: Control, item_key: String) -> HBoxContainer:
	if region == null:
		return null
	var rows := region.get_node("ContentMargin/RegionContent/ItemsScroll/ItemRows") as VBoxContainer
	for child in rows.get_children():
		if child is HBoxContainer and String(child.get_meta("purchase_cart_item_key", "")) == item_key:
			return child as HBoxContainer
	return null


func _press_row_button(row: HBoxContainer, button_name: String) -> void:
	var button := row.get_node_or_null(button_name)
	if button == null or not button is Button:
		_fail("purchase row should expose %s" % button_name)
		return
	(button as Button).emit_signal("pressed")


func _row_child_index(row: HBoxContainer, child_name: String) -> int:
	for index in range(row.get_child_count()):
		if row.get_child(index).name == child_name:
			return index
	return -1


func _expect_quantity(context: String, row: HBoxContainer, expected: int) -> void:
	if row == null:
		_fail("%s missing row" % context)
		return
	var label := row.get_node_or_null("PurchaseQuantityLabel")
	if label == null or not label is Label:
		_fail("%s missing quantity label" % context)
		return
	var actual := int(String((label as Label).text))
	if actual != expected:
		_fail("%s expected %d, got %d" % [context, expected, actual])


func _expect_stock(context: String, row: HBoxContainer, expected: int) -> void:
	if row == null:
		_fail("%s missing row" % context)
		return
	var label := row.get_node_or_null("StockStat/StockLabel")
	if label == null or not label is Label:
		_fail("%s missing stock label" % context)
		return
	var actual := int(String((label as Label).text))
	if actual != expected:
		_fail("%s expected %d, got %d" % [context, expected, actual])


func _expect_cart_count(label: Label, expected: int) -> void:
	if label == null:
		_fail("cart label missing while expecting count %d" % expected)
		return
	if label.text.find("购物车") == -1:
		_fail("cart label should include 购物车, got %s" % label.text)
	if label.text.find("%d 件" % expected) == -1:
		_fail("cart label should show %d units, got %s" % [expected, label.text])


func _expect_field_value(context: String, values: Dictionary, key: String, expected: Variant) -> void:
	var actual: Variant = values.get(key, null)
	if actual != expected:
		_fail("%s expected %s, got %s" % [context, str(expected), str(actual)])


func _expect_receipt_grid(grid: GridContainer, expected_rows: Array) -> void:
	if grid.columns != 4:
		_fail("purchase receipt grid should use four columns, got %d" % grid.columns)
	var expected_cell_count := expected_rows.size() * 4
	if grid.get_child_count() != expected_cell_count:
		_fail("purchase receipt grid should expose %d cells, got %d" % [expected_cell_count, grid.get_child_count()])
		return
	for row_index in range(expected_rows.size()):
		var expected_row: Array = expected_rows[row_index]
		for column_index in range(4):
			var cell := grid.get_child(row_index * 4 + column_index) as Label
			if cell == null or cell.text != String(expected_row[column_index]):
				_fail("purchase receipt cell %d,%d expected %s, got %s" % [row_index, column_index, String(expected_row[column_index]), cell.text if cell != null else "<missing>"])
			if column_index > 0 and cell != null and cell.horizontal_alignment != HORIZONTAL_ALIGNMENT_RIGHT:
				_fail("purchase receipt numeric cell %d,%d should be right aligned" % [row_index, column_index])


func _expect_receipt_contains(receipt_text: String, expected: String) -> void:
	if receipt_text.find(expected) == -1:
		_fail("purchase receipt should contain %s, got %s" % [expected, receipt_text])


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if not _save_path.is_empty():
		DirAccess.remove_absolute(_save_path)
	if _failures.is_empty():
		print("PURCHASE_CART_SELF_CHECK_PASS")
		quit(0)
	else:
		for failure in _failures:
			printerr("PURCHASE_CART_SELF_CHECK_FAIL: %s" % failure)
		quit(1)
