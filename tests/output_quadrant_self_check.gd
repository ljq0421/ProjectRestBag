extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/Main.tscn"
const GAME_STATE_PATH := "res://scripts/game_state.gd"
const ProductionSite = preload("res://scripts/production_site.gd")

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed_scene := load(MAIN_SCENE_PATH)
	var game_state_script := load(GAME_STATE_PATH)
	if packed_scene == null or game_state_script == null:
		_fail("missing main scene or game state script")
		_finish()
		return

	var main: Control = (packed_scene as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var state = game_state_script.new_game()
	state.tutorial_guide_skipped = true
	state.unlock_feature("harvest_all")
	state.level = 5
	state.shop_level = 5
	state.add_ingredient("rice", 2)
	state.add_ingredient("rice_seed", 2)
	state.add_ingredient("chick", 1)
	state.add_ingredient("strawberry_seed", 1)
	state.add_tool("farm_accelerator", 1)
	main.set("state", state)
	main.call("_show_page", "output")
	await process_frame

	var bag_tabs_node := main.get_node_or_null("GlobalOverlayLayer/OverlayFrame/OverlayModeStack/OutputOverlay/OutputScroll/OutputGridRow/OutputBagPanel/OutputBagTabs")
	var grid_row_node: Node = main.get_node("GlobalOverlayLayer/OverlayFrame/OverlayModeStack/OutputOverlay/OutputScroll/OutputGridRow")
	var primary_action: Button = main.get_node_or_null("GlobalOverlayLayer/OverlayFrame/OverlayModeStack/OutputOverlay/OutputActions/OutputPrimaryActionButton")
	var context_menu: PopupMenu = main.get_node("GlobalOverlayLayer/OverlayFrame/OverlayModeStack/OutputOverlay/OutputContextMenu")
	_expect_output_context_menu_text_colors(context_menu)

	if main.get_node_or_null("GlobalOverlayLayer/OverlayFrame/OverlayModeStack/OutputOverlay/OutputSiteTabs") != null:
		_fail("output page should not keep legacy site tabs")
	if bag_tabs_node != null and bag_tabs_node is TabBar and (bag_tabs_node as TabBar).visible:
		_fail("output page should not expose output bag tabs")
	if primary_action == null or not primary_action.visible or primary_action.text != "一键收获":
		_fail("output page should expose the one-click harvest action")
	if not grid_row_node is GridContainer:
		_fail("output page quadrant root should be a GridContainer")
		main.queue_free()
		_finish()
		return

	var grid_row: GridContainer = grid_row_node
	if grid_row.columns != 1:
		_fail("output page should stack regions into one column")

	var visible_regions := []
	for child in grid_row.get_children():
		if child is Control and (child as Control).visible:
			visible_regions.append(child)
	if visible_regions.size() != 4:
		_fail("output page should render exactly four visible output regions, got %d" % visible_regions.size())
	for region in visible_regions:
		if not region is PanelContainer:
			_fail("each direct output region should be a PanelContainer, got %s" % region.get_class())

	var farm_grid := _find_site_grid(grid_row, "farm")
	if farm_grid == null:
		_fail("output page should render a farm region grid")
	else:
		_expect_site_grid_page("farm", farm_grid, 0, 0)
		_expect_output_cells_have_top_progress_bars("farm", farm_grid)
		var farm_cell := _find_grid_cell_by_meta(farm_grid, "slot_index", 0)
		if farm_cell == null:
			_fail("farm region should expose slot 0")
		else:
			main.call("_show_output_plant_menu", "farm", 0, Vector2(48, 48))
			if _find_popup_item_id_containing(context_menu, "rice_seed") == -1 and _find_popup_item_id_containing(context_menu, "水稻种子") == -1:
				_fail("left-click plant menu should include rice seed details")
			var start_id := _first_enabled_popup_id(context_menu)
			if start_id == -1:
				_fail("left-click plant menu should expose an enabled start action")
			else:
				main.call("_on_output_context_menu_id_pressed", start_id)
				if state.production_slots.size() != 1:
					_fail("plant menu action should start production in the clicked farm slot")
				main.call("_show_output_plant_menu", "farm", 0, Vector2(48, 48))
				if _find_popup_item_id_containing(context_menu, "下轮：") == -1:
					_fail("left-clicking an active output slot should expose next-round seed actions")

			main.call("_show_output_accelerator_menu", "farm", 0, Vector2(48, 48))
			var equip_id := _find_popup_item_id_containing(context_menu, "农场加速器")
			if equip_id == -1:
				_fail("right-click accelerator menu should include farm accelerator")
			else:
				main.call("_on_output_context_menu_id_pressed", equip_id)
				if state.get_equipped_accelerator("farm:0") != "farm_accelerator":
					_fail("accelerator should be equipped to farm:0, not a seed item")
				if state.get_equipped_accelerator("rice_seed") != "":
					_fail("accelerator should not be equipped to rice_seed")
			var farm_next_page_button := _find_site_region_button(grid_row, "farm", "OutputNextPageButton")
			if farm_next_page_button == null:
				_fail("farm region should expose a next page button")
			else:
				farm_next_page_button.emit_signal("pressed")
				await process_frame
				var farm_page_two_grid := _find_site_grid(grid_row, "farm")
				if farm_page_two_grid == null:
					_fail("farm region should remain after switching to page 2")
				else:
					_expect_site_grid_page("farm", farm_page_two_grid, 1, 4)

	var other_site_cases := [
		{"site_id": "ranch", "start_menu_text": "小鸡仔", "expected_inventory": {"egg": 2, "chicken": 1}},
		{"site_id": "forest", "start_menu_text": "草莓种子", "expected_inventory": {"strawberry": 3}},
		{"site_id": "pond", "start_menu_text": "泉水引", "starter_inventory": {"spring_water_starter": 1}, "expected_inventory": {"spring_water": 2}}
	]
	for case_value in other_site_cases:
		var case: Dictionary = case_value
		await _expect_site_region_can_start_and_harvest(main, grid_row, context_menu, state, case)

	main.queue_free()
	_finish()


func _find_site_grid(grid_row: GridContainer, site_id: String) -> GridContainer:
	var region := _find_site_region(grid_row, site_id)
	if region == null:
		return null
	return _find_descendant_grid(region)


func _find_site_region(grid_row: GridContainer, site_id: String) -> Node:
	for region in grid_row.get_children():
		if not region is Node:
			continue
		if not region.has_meta("site_id") or String(region.get_meta("site_id")) != site_id:
			continue
		return region
	return null


func _find_descendant_grid(node: Node) -> GridContainer:
	for child in node.get_children():
		if child is GridContainer:
			return child
		var nested := _find_descendant_grid(child)
		if nested != null:
			return nested
	return null


func _find_site_region_button(grid_row: GridContainer, site_id: String, button_name: String) -> Button:
	var region := _find_site_region(grid_row, site_id)
	if region == null:
		return null
	return region.find_child(button_name, true, false) as Button


func _find_site_region_label(grid_row: GridContainer, site_id: String, label_name: String) -> Label:
	var region := _find_site_region(grid_row, site_id)
	if region == null:
		return null
	return region.find_child(label_name, true, false) as Label


func _expect_site_region_can_start_and_harvest(
	main: Control,
	grid_row: GridContainer,
	context_menu: PopupMenu,
	state,
	case: Dictionary
) -> void:
	var site_id := String(case.get("site_id", ""))
	var expected_inventory: Dictionary = case.get("expected_inventory", {})
	var starter_inventory: Dictionary = case.get("starter_inventory", {})
	for starter_id: String in starter_inventory.keys():
		state.add_ingredient(starter_id, int(starter_inventory[starter_id]))
	var site_grid := _find_site_grid(grid_row, site_id)
	if site_grid == null:
		_fail("output page should render %s region grid" % site_id)
		return
	_expect_site_grid_page(site_id, site_grid, 0, 0)
	_expect_output_cells_have_top_progress_bars(site_id, site_grid)

	var idle_cell := _find_grid_cell_by_meta(site_grid, "slot_index", 0)
	if idle_cell == null:
		_fail("%s region should expose slot 0" % site_id)
		return

	main.call("_show_output_plant_menu", site_id, 0, Vector2(48, 48))
	var start_menu_text := String(case.get("start_menu_text", ""))
	var start_id := _find_popup_item_id_containing(context_menu, start_menu_text) if not start_menu_text.is_empty() else _first_enabled_popup_id(context_menu)
	if start_id == -1:
		_fail("%s plant menu should expose an enabled start action" % site_id)
		return

	var slots_before: int = state.production_slots.size()
	main.call("_on_output_context_menu_id_pressed", start_id)
	if state.production_slots.size() != slots_before + 1:
		var status := main.get_node("Root/StatusBar/StatusLabel") as Label
		_fail("%s plant menu action should start production in the clicked slot (id=%d, mode=%s, status=%s)" % [site_id, start_id, String(main.get("global_popup_mode")), status.text])
		return

	var slot_array_index := _find_slot_array_index(state, site_id, 0)
	if slot_array_index == -1:
		_fail("%s should keep an active slot after starting production" % site_id)
		return

	var slot: Dictionary = state.production_slots[slot_array_index]
	slot["started_at_unix"] = 100
	slot["duration_seconds"] = 20
	slot["ready_at_unix"] = 120
	state.production_slots[slot_array_index] = slot
	var stock_before: Dictionary = {}
	for harvest_item_id: String in expected_inventory.keys():
		stock_before[harvest_item_id] = int(state.get_ingredient_count(harvest_item_id))
	main.call("_refresh_current_page")
	await process_frame

	var refreshed_grid := _find_site_grid(grid_row, site_id)
	if refreshed_grid == null:
		_fail("%s region should remain after refresh" % site_id)
		return
	var active_cell := _find_grid_cell_by_meta(refreshed_grid, "slot_index", 0)
	if active_cell == null:
		_fail("%s active slot should remain clickable after refresh" % site_id)
		return
	_expect_active_cell_has_top_progress_bar(site_id, active_cell)
	_expect_active_cell_progress_increases(site_id, main, state, active_cell)
	main.call("_refresh_output_countdown_texts", 121)
	var title_label := _find_site_region_label(grid_row, site_id, "OutputSiteTitle")
	if title_label == null:
		_fail("%s region should expose OutputSiteTitle" % site_id)
	elif title_label.text.find("可收:1") == -1:
		_fail("%s region title should refresh ready count after countdown tick, got %s" % [site_id, title_label.text])
	elif title_label.text.find("进行:0") == -1:
		_fail("%s region title should move ready slots out of in-progress count, got %s" % [site_id, title_label.text])
	var page_description: RichTextLabel = main.get_node("GlobalOverlayLayer/OverlayFrame/OverlayModeStack/OutputOverlay/PageDescription")
	_expect_output_page_description_counts(site_id, page_description.text, state, 121)

	active_cell.emit_signal("pressed")
	for harvest_item_id: String in expected_inventory.keys():
		var expected_delta := int(expected_inventory[harvest_item_id])
		var actual_delta := int(state.get_ingredient_count(harvest_item_id)) - int(stock_before.get(harvest_item_id, 0))
		if actual_delta < expected_delta:
			var status_node: Label = main.get_node("Root/StatusBar/StatusLabel")
			_fail("%s clicking ready active slot should harvest %s x%d, got delta %d, kind=%s ready=%s status=%s" % [
				site_id,
				harvest_item_id,
				expected_delta,
				actual_delta,
				String(active_cell.get_meta("output_kind", "")),
				str(ProductionSite.is_slot_ready(state, slot_array_index)),
				status_node.text
			])


func _find_slot_array_index(state, site_id: String, site_slot_index: int) -> int:
	for index in range(state.production_slots.size()):
		var slot_value: Variant = state.production_slots[index]
		if not slot_value is Dictionary:
			continue
		var slot: Dictionary = slot_value
		if String(slot.get("site_id", "")) == site_id and int(slot.get("slot_index", -1)) == site_slot_index:
			return index
	return -1


func _find_grid_cell_by_meta(grid: GridContainer, key: String, expected: Variant) -> Button:
	for child in grid.get_children():
		if child is Button and child.has_meta(key) and child.get_meta(key) == expected:
			return child
	return null


func _expect_site_grid_page(site_id: String, grid: GridContainer, expected_page: int, expected_first_slot_index: int) -> void:
	if grid.columns != 4:
		_fail("%s output site page should use four columns, got columns=%d" % [site_id, grid.columns])
	if grid.get_child_count() != 4:
		_fail("%s output site page %d should show four cells, got %d" % [site_id, expected_page + 1, grid.get_child_count()])
	for child_index in range(grid.get_child_count()):
		var child := grid.get_child(child_index)
		if not child is Button:
			_fail("%s output page child should be a Button" % site_id)
			continue
		var button: Button = child
		var expected_slot := expected_first_slot_index + child_index
		if not button.has_meta("slot_index") or int(button.get_meta("slot_index")) != expected_slot:
			_fail("%s output page %d child %d should expose slot_index %d, got %s" % [
				site_id,
				expected_page + 1,
				child_index,
				expected_slot,
				str(button.get_meta("slot_index", null))
			])
		if int(button.custom_minimum_size.x) < 112 or int(button.custom_minimum_size.y) < 112:
			_fail("%s output cells should be larger square cells, got %s" % [site_id, str(button.custom_minimum_size)])
		if int(button.custom_minimum_size.x) != int(button.custom_minimum_size.y):
			_fail("%s output cells should remain square, got %s" % [site_id, str(button.custom_minimum_size)])


func _expect_output_cells_have_top_progress_bars(site_id: String, grid: GridContainer) -> void:
	for child in grid.get_children():
		if not child is Button:
			continue
		var progress_bar := (child as Button).get_node_or_null("ProductionProgressBar")
		if progress_bar == null:
			_fail("%s output cell should render a top ProductionProgressBar" % site_id)
			continue
		if not progress_bar is ProgressBar:
			_fail("%s output cell ProductionProgressBar should be a ProgressBar, got %s" % [site_id, progress_bar.get_class()])


func _expect_active_cell_has_top_progress_bar(site_id: String, cell: Button) -> void:
	if not cell.has_meta("production_progress_fraction"):
		_fail("%s active output cell should expose production_progress_fraction metadata" % site_id)
	var progress_value := float(cell.get_meta("production_progress_fraction", -1.0))
	if progress_value < 0.0 or progress_value > 1.0:
		_fail("%s active output cell progress should stay in 0..1, got %.2f" % [site_id, progress_value])
	var progress_bar := cell.get_node_or_null("ProductionProgressBar")
	if progress_bar == null:
		_fail("%s active output cell should render a top ProductionProgressBar" % site_id)
		return
	if not progress_bar is ProgressBar:
		_fail("%s ProductionProgressBar should be a ProgressBar, got %s" % [site_id, progress_bar.get_class()])
		return
	var bar: ProgressBar = progress_bar
	if bar.anchor_top != 0.0 or bar.anchor_bottom != 0.0 or bar.anchor_left != 0.0 or bar.anchor_right != 1.0:
		_fail("%s ProductionProgressBar should be anchored across the top of the cell" % site_id)


func _expect_active_cell_progress_increases(site_id: String, main: Control, state, cell: Button) -> void:
	main.call("_refresh_output_countdown_texts", 105)
	var before := float(cell.get_meta("production_progress_fraction", -1.0))
	var bar_before := _production_progress_bar_value(cell)
	main.call("_refresh_output_countdown_texts", 115)
	var after := float(cell.get_meta("production_progress_fraction", -1.0))
	var bar_after := _production_progress_bar_value(cell)
	if not after > before:
		_fail("%s active output cell progress should increase over time, before=%.2f after=%.2f" % [site_id, before, after])
	if not bar_after > bar_before:
		_fail("%s top progress bar value should increase over time, before=%.2f after=%.2f" % [site_id, bar_before, bar_after])
	var page_description: RichTextLabel = main.get_node("GlobalOverlayLayer/OverlayFrame/OverlayModeStack/OutputOverlay/PageDescription")
	_expect_output_page_description_counts(site_id, page_description.text, state, 115)


func _expect_output_page_description_counts(site_id: String, text: String, state, now_unix: int) -> void:
	var expected_ready := _expected_ready_output_count(state, now_unix)
	var expected_in_progress := _expected_in_progress_output_count(state, now_unix)
	if text.find("可收 %d" % expected_ready) == -1:
		_fail("%s output page description should refresh ready count at %d, expected %d, got %s" % [site_id, now_unix, expected_ready, text])
	if text.find("进行 %d" % expected_in_progress) == -1:
		_fail("%s output page description should refresh in-progress count at %d, expected %d, got %s" % [site_id, now_unix, expected_in_progress, text])


func _expected_ready_output_count(state, now_unix: int) -> int:
	var count := 0
	for index in range(state.production_slots.size()):
		if ProductionSite.is_slot_ready(state, index, now_unix):
			count += 1
	return count


func _expected_in_progress_output_count(state, now_unix: int) -> int:
	var count := 0
	for index in range(state.production_slots.size()):
		var slot_value: Variant = state.production_slots[index]
		if slot_value is Dictionary and not ProductionSite.is_slot_ready(state, index, now_unix):
			count += 1
	return count


func _production_progress_bar_value(cell: Button) -> float:
	var progress_bar := cell.get_node_or_null("ProductionProgressBar")
	if progress_bar is ProgressBar:
		return float((progress_bar as ProgressBar).value)
	return -1.0


func _find_popup_item_id_containing(menu: PopupMenu, expected: String) -> int:
	for index in range(menu.item_count):
		if menu.get_item_text(index).find(expected) != -1:
			return menu.get_item_id(index)
	return -1


func _first_enabled_popup_id(menu: PopupMenu) -> int:
	for index in range(menu.item_count):
		if not menu.is_item_disabled(index):
			return menu.get_item_id(index)
	return -1


func _expect_output_context_menu_text_colors(menu: PopupMenu) -> void:
	var expected_font_color := Color("502611")
	var expected_disabled_color := Color("795548")
	var actual_font_color := menu.get_theme_color("font_color")
	var actual_disabled_color := menu.get_theme_color("font_disabled_color")
	if not actual_font_color.is_equal_approx(expected_font_color):
		_fail("output context menu font should be dark brown %s, got %s" % [expected_font_color, actual_font_color])
	if not actual_disabled_color.is_equal_approx(expected_disabled_color):
		_fail("output context menu disabled font should stay readable %s, got %s" % [expected_disabled_color, actual_disabled_color])


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("OUTPUT_QUADRANT_SELF_CHECK_PASS")
		quit(0)
	else:
		for failure in _failures:
			printerr("OUTPUT_QUADRANT_SELF_CHECK_FAIL: %s" % failure)
		quit(1)
