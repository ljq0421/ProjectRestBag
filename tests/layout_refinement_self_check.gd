extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/Main.tscn"
const GAME_STATE_PATH := "res://scripts/game_state.gd"
const CORE_FEATURE_UNLOCK_SERVICE := preload("res://scripts/core_feature_unlock_service.gd")
const VIEWPORT_SIZE := Vector2i(1920, 1080)

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	if String(ProjectSettings.get_setting("display/window/stretch/aspect", "ignore")) != "keep":
		_fail("the 1920x1080 game page should preserve its aspect ratio instead of shifting or clipping")
	root.size = VIEWPORT_SIZE
	var packed_scene := load(MAIN_SCENE_PATH)
	if packed_scene == null:
		_fail("Main scene is missing")
		_finish()
		return

	var main: Control = (packed_scene as PackedScene).instantiate()
	var test_save_path := OS.get_temp_dir().path_join("layout_refinement_self_check_save_%d.json" % OS.get_process_id())
	var test_broken_save_path := OS.get_temp_dir().path_join("layout_refinement_self_check_broken_%d.json" % OS.get_process_id())
	DirAccess.remove_absolute(test_save_path)
	DirAccess.remove_absolute(test_broken_save_path)
	main.set("save_path", test_save_path)
	main.set("broken_save_path", test_broken_save_path)
	root.add_child(main)
	await process_frame
	await process_frame

	var game_state_script := load(GAME_STATE_PATH)
	var state = game_state_script.new_game()
	state.tutorial_guide_skipped = true
	state.level = 1
	state.shop_level = 1
	state.coins = 300
	state.add_recipe("rice_milk_drink")
	state.add_recipe("sponge_cake")
	state.add_ingredient("rice", 2)
	state.add_ingredient("spring_water", 2)
	state.add_ingredient("sugar", 2)
	state.add_product("sponge_cake", 1)
	state.unlock_feature("research_make_all")
	state.unlock_feature("research_list_all")
	state.unlock_core_feature(CORE_FEATURE_UNLOCK_SERVICE.OUTPUT)
	state.unlock_core_feature(CORE_FEATURE_UNLOCK_SERVICE.INVENTORY)
	state.unlock_core_feature(CORE_FEATURE_UNLOCK_SERVICE.RESEARCH)
	main.set("state", state)

	var storefront: Control = main.get_node("Root/Body/MainArea/StorefrontPanel")
	var workbench: Control = main.get_node("Root/Body/MainArea/WorkbenchPanel")
	var showcase_panel: Control = main.get_node("Root/Body/MainArea/StorefrontPanel/ShowcasePanel")
	if main.get_node_or_null("Root/Body/MainArea/StorefrontPanel/CashierPanel") != null:
		_fail("cashier and recent feedback should be removed from the left storefront")
	if main.get_node_or_null("Root/Body/MainArea/StorefrontPanel/StorefrontBusinessPanel") != null:
		_fail("hidden storefront business panel should be removed from the storefront tree")
	if main.get_node_or_null("Root/Body/MainArea/StorefrontPanel/StorefrontStatusPanel") != null:
		_fail("hidden storefront status placeholder should be removed")
	if main.get_node_or_null("Root/Body/MainArea/WorkbenchPanel/ProductionWorkbench/PageTitle") != null:
		_fail("hidden PageTitle should be removed")
	for node_name in ["OutputSiteTabs", "SiteOptions", "ItemOptions", "RecipeOptions", "SlotOptions"]:
		if main.get_node_or_null("Root/Body/MainArea/WorkbenchPanel/ProductionWorkbench/%s" % node_name) != null:
			_fail("legacy option node should be removed: %s" % node_name)
	if storefront.size_flags_stretch_ratio != 63.0:
		_fail("storefront should receive half of the removed cashier width")
	if workbench.custom_minimum_size.x != 820.0 or absf(workbench.size.x - 820.0) > 1.0:
		_fail("the fixed production queue should remain 820px wide, got %.1f" % workbench.size.x)
	if showcase_panel.size_flags_stretch_ratio < 99.0:
		_fail("left storefront should be effectively all showcase")

	var purchase_overlay: Control = main.get_node("GlobalOverlayLayer/OverlayFrame/OverlayModeStack/PurchaseOverlay")
	var production_workbench: Control = main.get_node("Root/Body/MainArea/WorkbenchPanel/ProductionWorkbench")
	var research_overlay: Control = main.get_node("GlobalOverlayLayer/OverlayFrame/OverlayModeStack/ResearchOverlay")
	var output_grid_row: GridContainer = main.get_node("GlobalOverlayLayer/OverlayFrame/OverlayModeStack/OutputOverlay/OutputScroll/OutputGridRow")
	var research_input_bar: HBoxContainer = research_overlay.get_node("ResearchInputBar")
	var research_tool_slot: Button = research_input_bar.get_node("ToolSlot")
	var research_inventory_grid: GridContainer = research_input_bar.get_node("InventoryGrid")
	var queue_scroll: ScrollContainer = production_workbench.get_node("QueueScroll")
	var page_description: RichTextLabel = research_overlay.get_node("PageDescription")
	var primary_action: Button = research_overlay.get_node("ActionRow/ResearchActionButton")
	var bulk_action_button: MenuButton = production_workbench.get_node("ProductionQueueHeader/BulkActionButton")

	main.call("_show_page", "purchase")
	await process_frame
	var purchase_regions_grid := purchase_overlay.get_node_or_null("PurchaseRegionsGrid") as GridContainer
	if purchase_overlay.get_node_or_null("PurchaseCategoryTabs") != null:
		_fail("purchase overlay should remove source tabs")
	if purchase_regions_grid == null:
		_fail("purchase overlay should expose a source region grid")
	else:
		if purchase_regions_grid.columns != 3:
			_fail("purchase source region grid should use three columns")
		if purchase_regions_grid.get_child_count() != 6:
			_fail("purchase source region grid should expose six regions")
		if purchase_regions_grid.get_parent() != purchase_overlay:
			_fail("purchase region grid should remain a direct page section above the footer")
		var first_row_height := -1.0
		for index in range(purchase_regions_grid.get_child_count()):
			var region := purchase_regions_grid.get_child(index) as Control
			if region == null:
				continue
			if index == 0:
				first_row_height = region.size.y
			elif absf(region.size.y - first_row_height) > 1.0:
				_fail("purchase regions should keep equal heights")
	if not production_workbench.visible:
		_fail("purchase overlay should not hide the fixed production workbench")

	var purchase_workbench_width := workbench.size.x
	var purchase_storefront_width := storefront.size.x

	main.call("_show_page", "output")
	await process_frame
	if output_grid_row.columns != 1:
		_fail("output page should stack the four production areas in one column")
	if output_grid_row.get_child_count() != 4:
		_fail("output page should render four production area rows")
	var output_primary_action: Button = main.get_node("GlobalOverlayLayer/OverlayFrame/OverlayModeStack/OutputOverlay/OutputActions/OutputPrimaryActionButton")
	if output_primary_action.visible:
		_fail("output page should hide one-click harvest for a new game")

	main.call("_show_page", "research")
	await process_frame
	if absf(workbench.size.x - purchase_workbench_width) > 1.0:
		_fail("research page should not resize the right console width")
	if absf(storefront.size.x - purchase_storefront_width) > 1.0:
		_fail("research page should not shift the storefront width")
	if not research_overlay.visible:
		_fail("research destination should open the research overlay")
	if research_overlay.get_child_count() < 2 or research_overlay.get_child(1) != research_input_bar:
		_fail("research overlay should contain the horizontal input strip")
	if research_input_bar.get_theme_constant("separation") != 16:
		_fail("research tool and material regions should keep a 16px gap")
	if research_inventory_grid.columns != 6 or research_inventory_grid.get_child_count() != 6:
		_fail("research material row should show six material slots")
	if research_inventory_grid.get_theme_constant("h_separation") != 8:
		_fail("research material slots should keep 8px gaps")
	var first_material_slot := research_inventory_grid.get_child(0) as Button
	if research_tool_slot.custom_minimum_size != Vector2(104, 104):
		_fail("research tool slot should be a 104x104 square")
	if first_material_slot.custom_minimum_size != Vector2(88, 88):
		_fail("research material slots should be 88x88 squares")
	if research_tool_slot.size != Vector2(104, 104):
		_fail("research tool slot visual size should be 104x104, got %s" % str(research_tool_slot.size))
	if first_material_slot.size != Vector2(88, 88):
		_fail("research material slot visual size should be 88x88, got %s" % str(first_material_slot.size))
	if page_description.text.find("研发成功率") != -1:
		_fail("research page should not show a fake random success rate")
	if page_description.text.find("至少选择 2 个食材") == -1:
		_fail("research page should explain how to start research")
	if research_overlay.get_node_or_null("ResearchHintPanel") != null:
		_fail("research overlay should not restore the retired persistent notebook")
	if primary_action.get_parent() != research_overlay.get_node("ActionRow") or primary_action.text != "研发":
		_fail("research action should remain in the research overlay action row")
	if not queue_scroll.visible:
		_fail("production workbench should show the unified production queue")
	var bulk_popup := bulk_action_button.get_popup()
	if bulk_popup.item_count != 3:
		_fail("production queue header should expose the three bulk operations")
	else:
		if bulk_popup.get_item_text(0) != "制作全部":
			_fail("production queue header should expose make-all")
		if bulk_popup.get_item_text(2) != "上架全部":
			_fail("production queue header should expose list-all")

	main.call("_show_page", "storefront_manage")
	await process_frame
	if absf(workbench.size.x - purchase_workbench_width) > 1.0:
		_fail("storefront manage page should not resize the right console width: purchase %.1f, storefront %.1f" % [purchase_workbench_width, workbench.size.x])
	if absf(storefront.size.x - purchase_storefront_width) > 1.0:
		_fail("storefront manage page should not shift the storefront width: purchase %.1f, storefront %.1f" % [purchase_storefront_width, storefront.size.x])

	var page_rect_before_guide := (main.get_node("Root") as Control).get_global_rect()
	var active_guide_state = game_state_script.new_game()
	main.set("state", active_guide_state)
	main.call("_close_global_popup")
	for blocking_popup_path in ["TaskPopup", "AutomationReportDialog", "PurchaseReceiptDialog", "RecipeRestockDialog", "ShowcaseRoundSettlementDialog", "RecipeGrowthChoiceDialog", "StorefrontChallengeDialog", "StorefrontRecentReportDialog", "ShowcaseRulebookDialog"]:
		var blocking_popup := main.get_node_or_null(blocking_popup_path)
		if blocking_popup != null:
			blocking_popup.hide()
	main.call("_refresh_tutorial_guide")
	await process_frame
	var page_rect_with_guide := (main.get_node("Root") as Control).get_global_rect()
	if page_rect_with_guide != page_rect_before_guide:
		_fail("showing grandma dialogue should not move or resize the game page")
	var tutorial_overlay := main.get_node("TutorialGuideOverlay") as Control
	var dialogue_panel := tutorial_overlay.get_node("DialoguePanel") as Control
	if not tutorial_overlay.visible or not dialogue_panel.visible:
		_fail("an active guide should render the grandma dialogue on the main game page")
	var showcase_rect := showcase_panel.get_global_rect()
	var dialogue_rect := dialogue_panel.get_global_rect()
	if dialogue_rect.position.x < showcase_rect.position.x - 1.0 \
			or dialogue_rect.end.x > showcase_rect.end.x + 1.0 \
			or dialogue_rect.position.y < showcase_rect.position.y - 1.0 \
			or dialogue_rect.end.y > showcase_rect.end.y + 1.0:
		_fail("grandma dialogue should remain fully inside the storefront showcase region")
	main.queue_free()
	DirAccess.remove_absolute(test_save_path)
	DirAccess.remove_absolute(test_broken_save_path)
	_finish()


func _joined_list_text(list: ItemList) -> String:
	var parts: Array[String] = []
	for index in range(list.item_count):
		parts.append(list.get_item_text(index))
	return "\n".join(parts)


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("LAYOUT_REFINEMENT_SELF_CHECK_PASS")
		quit(0)
	else:
		for failure in _failures:
			printerr("LAYOUT_REFINEMENT_SELF_CHECK_FAIL: %s" % failure)
		quit(1)
