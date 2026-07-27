extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/Main.tscn"
const OUTPUT_CELL_SCENE_PATH := "res://scenes/ui/pages/output_cell.tscn"
const GAME_STATE_PATH := "res://scripts/game_state.gd"
const VIEWPORT_SIZE := Vector2i(1920, 1080)
const LAYOUT_TOLERANCE := 1.0

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = VIEWPORT_SIZE
	_expect_output_cell_scene_contract()
	var packed_scene := load(MAIN_SCENE_PATH)
	if packed_scene == null:
		_fail("Main scene is missing: %s" % MAIN_SCENE_PATH)
		_finish()
		return

	var main: Control = (packed_scene as PackedScene).instantiate()
	var save_path := OS.get_temp_dir().path_join("output_layout_self_check.json")
	main.set("save_path", save_path)
	main.set("broken_save_path", save_path + ".broken")
	root.add_child(main)
	await process_frame
	await process_frame

	var game_state_script := load(GAME_STATE_PATH)
	main.set("state", game_state_script.new_game())
	main.call("_show_page", "purchase")
	await process_frame
	var storefront: Control = main.get_node("Root/Body/MainArea/StorefrontPanel")
	var workbench: Control = main.get_node("Root/Body/MainArea/WorkbenchPanel")
	var content: Control = main.get_node("Root/Body/MainArea/WorkbenchPanel/ProductionWorkbench")
	var output_button: Button = main.get_node("Root/Body/MainArea/WorkbenchPanel/WorkbenchLauncher/OutputButton")
	var purchase_store_rect := storefront.get_global_rect()
	var purchase_workbench_rect := workbench.get_global_rect()
	var purchase_content_rect := content.get_global_rect()
	_expect_left_right_ratio(purchase_store_rect, purchase_workbench_rect)

	var output_store_rect := purchase_store_rect
	var output_workbench_rect := purchase_workbench_rect
	var output_content_rect := purchase_content_rect
	for page in ["output", "research", "storefront_manage", "purchase"]:
		if page == "output":
			output_button.emit_signal("pressed")
		else:
			main.call("_show_page", page)
		await process_frame
		await process_frame
		var current_store_rect := storefront.get_global_rect()
		var current_workbench_rect := workbench.get_global_rect()
		var current_content_rect := content.get_global_rect()
		_expect_same_rect("storefront after %s page" % page, purchase_store_rect, current_store_rect)
		_expect_same_rect("workbench after %s page" % page, purchase_workbench_rect, current_workbench_rect)
		_expect_same_rect("content after %s page" % page, purchase_content_rect, current_content_rect)
		if page == "output":
			output_store_rect = current_store_rect
			output_workbench_rect = current_workbench_rect
			output_content_rect = current_content_rect

	main.call("_show_page", "research")
	await process_frame
	output_button.emit_signal("pressed")
	await process_frame
	await process_frame
	_expect_same_rect("storefront after research to output", purchase_store_rect, storefront.get_global_rect())
	_expect_same_rect("workbench after research to output", purchase_workbench_rect, workbench.get_global_rect())
	_expect_same_rect("content after research to output", purchase_content_rect, content.get_global_rect())

	if output_workbench_rect.end.y > VIEWPORT_SIZE.y - 34:
		_fail("output workbench should remain inside viewport, got end.y=%f" % output_workbench_rect.end.y)

	main.set("state", game_state_script.new_game())
	main.call("_show_page", "output")
	var output_scroll := main.get_node_or_null("GlobalOverlayLayer/OverlayFrame/OverlayModeStack/OutputOverlay/OutputScroll") as ScrollContainer
	if output_scroll == null:
		_fail("output page should place its single-column regions inside OutputScroll")
	var output_grid_row: GridContainer = main.get_node("GlobalOverlayLayer/OverlayFrame/OverlayModeStack/OutputOverlay/OutputScroll/OutputGridRow")
	var first_region := output_grid_row.get_child(0) if output_grid_row.get_child_count() > 0 else null
	var first_pager := first_region.get_node_or_null("OutputSiteBox/OutputSiteBody/PlotColumn/OutputSitePager") if first_region != null else null
	if first_pager == null or first_pager.get_parent().name != "PlotColumn":
		_fail("output site pager should sit below the production plots")
	var farm_grid := _find_output_site_grid(output_grid_row, "farm")
	if farm_grid == null or farm_grid.get_child_count() < 2:
		_fail("output page should render farm output cells")
	else:
		var idle_cell := farm_grid.get_child(0) as Button
		var locked_cell := farm_grid.get_child(1) as Button
		_expect_runtime_output_cell("idle", idle_cell, false)
		_expect_runtime_output_cell("locked", locked_cell, false)

	var managed_state = game_state_script.new_game()
	managed_state.level = 3
	managed_state.unlock_automation("output")
	managed_state.managed_production_sites.append("farm")
	managed_state.production_slots = [{
		"site_id": "farm",
		"item_id": "wheat_seed",
		"slot_index": 0,
		"started_at_unix": 0,
		"duration_seconds": 20,
		"ready_at_unix": 0,
		"automation_paused": true,
		"pause_reason": {
			"code": "missing_input",
			"item_id": "wheat_seed",
			"first_stopped_at_unix": 20
		}
	}]
	main.set("state", managed_state)
	main.call("_show_page", "output")
	farm_grid = _find_output_site_grid(output_grid_row, "farm")
	if farm_grid == null or farm_grid.get_child_count() < 1:
		_fail("managed output page should render the active farm cell")
	else:
		var managed_cell := farm_grid.get_child(0) as Button
		_expect_runtime_output_cell("managed", managed_cell, false)
		var managed_status := managed_cell.get_node_or_null("AutomationStatusLabel") as Label
		if managed_status == null or managed_status.visible:
			_fail("managed paused cell should keep per-cell status text hidden")
		if managed_cell.tooltip_text.find("小麦种子") == -1:
			_fail("managed paused cell tooltip should retain the actionable wheat seed reason")
		var drag_data: Variant = managed_cell.get("drag_data")
		if not drag_data is Dictionary or String((drag_data as Dictionary).get("kind", "")) != "active":
			_fail("scene-based managed cell should retain active-slot drag metadata")
	var coin_pause_display: Dictionary = main.call("_output_automation_status", {
		"automation_paused": true,
		"pause_reason": {
			"code": "insufficient_coins",
			"required": 4,
			"available": 3
		}
	}, true)
	if String(coin_pause_display.get("text", "")) != "金币不足 1":
		_fail("coin pause should show the missing amount 1, got %s" % String(coin_pause_display.get("text", "")))

	var state = main.get("state")
	for index in range(40):
		state.add_log("business_sale:layout_regression_%02d:这是一条较长的最近反馈内容，用来验证收银台文本不会撑开店面布局" % index)
	main.call("_refresh_current_page")
	await process_frame
	await process_frame
	var feedback_store_rect := storefront.get_global_rect()
	var feedback_workbench_rect := workbench.get_global_rect()
	var feedback_content_rect := content.get_global_rect()

	_expect_same_rect("storefront after feedback log growth", output_store_rect, feedback_store_rect)
	_expect_same_rect("workbench after feedback log growth", output_workbench_rect, feedback_workbench_rect)
	_expect_same_rect("content after feedback log growth", output_content_rect, feedback_content_rect)

	main.queue_free()
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
	if FileAccess.file_exists(save_path + ".broken"):
		DirAccess.remove_absolute(save_path + ".broken")
	_finish()


func _find_output_site_grid(output_row: GridContainer, site_id: String) -> GridContainer:
	for region_value: Variant in output_row.get_children():
		if not region_value is Control:
			continue
		var region := region_value as Control
		if String(region.get_meta("site_id", "")) != site_id:
			continue
		return region.get_node_or_null("OutputSiteBox/OutputSiteBody/PlotColumn/OutputSiteGrid") as GridContainer
	return null


func _expect_runtime_output_cell(label: String, cell: Button, automation_visible: bool) -> void:
	if cell == null:
		_fail("%s output cell should remain a Button" % label)
		return
	if cell.scene_file_path != OUTPUT_CELL_SCENE_PATH:
		_fail("%s output cell should be instantiated from output_cell.tscn" % label)
	if cell.custom_minimum_size.x < 112.0 or cell.custom_minimum_size.y < 112.0:
		_fail("%s output cell should be at least 112x112, got %s" % [label, str(cell.custom_minimum_size)])
	var toggle := cell.get_node_or_null("AutomationToggle") as BaseButton
	if toggle == null:
		_fail("%s output cell should keep the stable AutomationToggle" % label)
		return
	if toggle.visible != automation_visible:
		_fail("%s output cell automation visibility expected %s" % [label, str(automation_visible)])
	if toggle.visible:
		_fail("output cell should not expose a per-slot automation toggle")


func _expect_output_cell_scene_contract() -> void:
	if not FileAccess.file_exists(OUTPUT_CELL_SCENE_PATH):
		_fail("output cell scene is missing: %s" % OUTPUT_CELL_SCENE_PATH)
		return
	var packed_scene := load(OUTPUT_CELL_SCENE_PATH)
	if not packed_scene is PackedScene:
		_fail("output cell scene should load as PackedScene")
		return
	var cell := (packed_scene as PackedScene).instantiate()
	if not cell is Button:
		_fail("OutputCell root should remain a draggable Button")
		cell.free()
		return
	for child_name in ["ProductDisplayArea", "ProductionProgressBar", "AutomationStatusLabel", "AutomationToggle"]:
		if cell.get_node_or_null(child_name) == null:
			_fail("OutputCell should contain stable child %s" % child_name)
	var progress := cell.get_node_or_null("ProductionProgressBar") as Control
	var status := cell.get_node_or_null("AutomationStatusLabel") as Control
	var toggle := cell.get_node_or_null("AutomationToggle") as Control
	if progress != null and progress.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		_fail("ProductionProgressBar should ignore mouse input so dragging still works")
	if status != null and status.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		_fail("AutomationStatusLabel should ignore mouse input so dragging still works")
	if toggle != null and toggle.mouse_filter != Control.MOUSE_FILTER_STOP:
		_fail("AutomationToggle should intercept only its own clicks")
	if not cell.has_signal("automation_toggled"):
		_fail("OutputCell should expose automation_toggled")
	if not cell.has_method("configure_automation"):
		_fail("OutputCell should expose configure_automation")
	else:
		cell.call("configure_automation", false, false, "", {})
		if toggle != null and toggle.visible:
			_fail("unavailable automation should hide the toggle")
		if status != null and status.visible:
			_fail("unavailable automation should hide the status label")
		cell.call("configure_automation", true, true, "缺少小麦种子", {
			"code": "missing_input",
			"item_id": "wheat_seed",
			"next_step": "补充小麦种子后将自动继续"
		})
		if toggle != null and toggle.visible:
			_fail("active automation should keep the per-slot toggle hidden")
		if status is Label:
			if not status.visible or (status as Label).text != "缺少小麦种子":
				_fail("paused automation should show its specific reason")
			if (status as Label).tooltip_text.find("补充小麦种子") == -1:
				_fail("paused automation tooltip should explain the next action")
		cell.call("configure_automation", true, true, "已全局暂停", "请在自动化中枢恢复全部自动化")
		if status is Label and (status as Label).tooltip_text != "请在自动化中枢恢复全部自动化":
			_fail("configure_automation should accept a String pause reason as the tooltip contract")
	cell.free()


func _expect_same_rect(label: String, before: Rect2, after: Rect2) -> void:
	if absf(before.position.x - after.position.x) > LAYOUT_TOLERANCE:
		_fail("%s x changed from %.1f to %.1f" % [label, before.position.x, after.position.x])
	if absf(before.position.y - after.position.y) > LAYOUT_TOLERANCE:
		_fail("%s y changed from %.1f to %.1f" % [label, before.position.y, after.position.y])
	if absf(before.size.x - after.size.x) > LAYOUT_TOLERANCE:
		_fail("%s width changed from %.1f to %.1f" % [label, before.size.x, after.size.x])
	if absf(before.size.y - after.size.y) > LAYOUT_TOLERANCE:
		_fail("%s height changed from %.1f to %.1f" % [label, before.size.y, after.size.y])


func _expect_left_right_ratio(storefront_rect: Rect2, workbench_rect: Rect2) -> void:
	if storefront_rect.position.x >= workbench_rect.position.x:
		_fail("storefront should remain left of the production queue")
	if absf(workbench_rect.size.x - 820.0) > LAYOUT_TOLERANCE:
		_fail("production queue should remain 820px wide, got %.1f" % workbench_rect.size.x)
	if storefront_rect.size.x < 1008.0 - LAYOUT_TOLERANCE:
		_fail("storefront should retain its 1008px minimum width, got %.1f" % storefront_rect.size.x)


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("OUTPUT_LAYOUT_SELF_CHECK_PASS")
		quit(0)
	else:
		for failure in _failures:
			printerr("OUTPUT_LAYOUT_SELF_CHECK_FAIL: %s" % failure)
		quit(1)
