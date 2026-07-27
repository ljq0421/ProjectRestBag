extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/Main.tscn"
const GAME_STATE_PATH := "res://scripts/game_state.gd"
const VIEWPORT_SIZE := Vector2i(1920, 1080)

var _failures: Array[String] = []


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
	main.set("save_path", OS.get_temp_dir().path_join("console_tabs_purchase_drawer_self_check_save.json"))
	root.add_child(main)
	await process_frame
	await process_frame

	var game_state_script := load(GAME_STATE_PATH)
	var state = game_state_script.new_game()
	state.tutorial_guide_skipped = true
	state.level = 1
	state.shop_level = 1
	state.coins = 300
	state.add_recipe("sponge_cake")
	state.add_product("sponge_cake", 1)
	state.unlock_feature("research_make_all")
	state.unlock_feature("research_list_all")
	main.set("state", state)
	main.call("_show_page", "purchase")
	await process_frame

	var workbench: Control = main.get_node("Root/Body/MainArea/WorkbenchPanel")
	if not workbench is VBoxContainer:
		_fail("WorkbenchPanel should stack research above the launcher")
	if main.get_node_or_null("Root/Body/MainArea/WorkbenchPanel/WorkbenchTabs") != null:
		_fail("old left vertical WorkbenchTabs should be removed")
	if main.get_node_or_null("Root/Body/MainArea/WorkbenchPanel/ConsoleTabs") != null:
		_fail("old top ConsoleTabs should be removed")
	var launcher: HBoxContainer = main.get_node_or_null("Root/Body/MainArea/WorkbenchPanel/WorkbenchLauncher")
	if launcher == null:
		_fail("right console should expose a bottom WorkbenchLauncher")
	else:
		var expected_entries := ["StarlightButton", "TaskButton", "InventoryButton", "CatalogButton", "PurchaseButton", "OutputButton", "StorefrontManageButton"]
		for button_name in expected_entries:
			var button := launcher.get_node_or_null(button_name) as Button
			if button == null:
				_fail("WorkbenchLauncher should include %s" % button_name)
			elif not button.text.is_empty() or button.icon == null or button.tooltip_text.is_empty():
				_fail("WorkbenchLauncher entry %s should remain a tooltip-backed icon button" % button_name)

	if main.get_node_or_null("Root/Body/MainArea/StorefrontPanel/DoorAnimationPanel") != null:
		_fail("storefront should not reserve the old door waiting area")

	var showcase: Control = main.get_node("Root/Body/MainArea/StorefrontPanel/ShowcasePanel")
	if main.get_node_or_null("Root/Body/MainArea/StorefrontPanel/CashierPanel") != null:
		_fail("cashier and recent feedback should move out of the left storefront")
	if showcase.size_flags_stretch_ratio < 99.0:
		_fail("showcase should take the full left storefront width")

	var page_description: RichTextLabel = main.get_node("GlobalOverlayLayer/OverlayFrame/OverlayModeStack/PurchaseOverlay/PageDescription")
	var purchase_overlay: Control = main.get_node("GlobalOverlayLayer/OverlayFrame/OverlayModeStack/PurchaseOverlay")
	var purchase_regions_grid := purchase_overlay.get_node_or_null("PurchaseRegionsGrid") as GridContainer
	var primary_action: Button = main.get_node("GlobalOverlayLayer/OverlayFrame/OverlayModeStack/PurchaseOverlay/PurchaseFooter/PurchaseConfirmButton")

	if page_description.custom_minimum_size.y > 36.0:
		_fail("PageDescription should be a compact right-side summary")
	if primary_action.text != "购买":
		_fail("purchase primary action should use short label")
	if purchase_overlay.get_node_or_null("PurchaseCategoryTabs") != null:
		_fail("purchase source tabs should be removed after the six-region layout")
	if purchase_overlay.get_node_or_null("PrimaryItemList") != null:
		_fail("legacy purchase ItemList should be removed after the six-region layout")
	if purchase_regions_grid == null:
		_fail("purchase page should expose PurchaseRegionsGrid")
	else:
		if purchase_regions_grid.columns != 3:
			_fail("purchase region grid should use three columns")
		var expected_categories := ["农场", "养殖场", "林场", "水塘", "辅料", "工具"]
		if purchase_regions_grid.get_child_count() != expected_categories.size():
			_fail("purchase page should expose six source regions")
		for index in range(mini(purchase_regions_grid.get_child_count(), expected_categories.size())):
			var region := purchase_regions_grid.get_child(index)
			if String(region.get("category_id")) != expected_categories[index]:
				_fail("purchase region %d should be %s" % [index, expected_categories[index]])
			if region.get_node_or_null("ContentMargin/RegionContent/ItemsScroll") == null:
				_fail("purchase region %s should own an independent scroll container" % expected_categories[index])
			if region.has_method("item_rows") and (region.call("item_rows") as Array).is_empty() and expected_categories[index] == "农场":
				_fail("farm purchase region should show unlocked quantity rows")

	main.call("_show_page", "output")
	await process_frame
	if String(main.get("global_popup_mode")) != "output":
		_fail("output launcher destination should open the output overlay")

	main.call("_show_page", "research")
	await process_frame
	var secondary_action: Button = main.get_node("Root/Body/MainArea/WorkbenchPanel/ProductionWorkbench/ActionRow/SecondaryActionButton")
	if not secondary_action.visible or secondary_action.text != "制作全部":
		_fail("research page should expose make-all action")
	var tertiary_action: Button = main.get_node("Root/Body/MainArea/WorkbenchPanel/ProductionWorkbench/ActionRow/TertiaryActionButton")
	if not tertiary_action.visible or tertiary_action.text != "上架全部":
		_fail("research page should expose list-all action")

	main.call("_show_page", "storefront_manage")
	await process_frame
	if String(main.get("global_popup_mode")) != "storefront_manage":
		_fail("storefront manage launcher destination should open its overlay")

	main.queue_free()
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
		print("CONSOLE_TABS_PURCHASE_DRAWER_SELF_CHECK_PASS")
		quit(0)
	else:
		for failure in _failures:
			printerr("CONSOLE_TABS_PURCHASE_DRAWER_SELF_CHECK_FAIL: %s" % failure)
		quit(1)
