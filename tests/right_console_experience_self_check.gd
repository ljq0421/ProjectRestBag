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
	main.set("save_path", OS.get_temp_dir().path_join("right_console_experience_self_check_save.json"))
	root.add_child(main)
	await process_frame
	await process_frame

	var game_state_script := load(GAME_STATE_PATH)
	var state = game_state_script.new_game()
	state.tutorial_guide_skipped = true
	for feature_id in ["output", "inventory", "research", "craft", "catalog", "list", "rulebook", "arrange", "business", "storefront_manage"]:
		state.unlock_core_feature(feature_id)
	state.unlock_feature("harvest_all")
	state.unlock_feature("research_make_all")
	state.unlock_feature("research_list_all")
	state.level = 6
	state.shop_level = 6
	state.coins = 30000
	state.add_recipe("sponge_cake")
	state.add_product("sponge_cake", 2)
	state.add_ingredient("rice_seed", 2)
	state.production_slots = [{
		"site_id": "farm",
		"slot_index": 0,
		"item_id": "rice_seed",
		"started_at_unix": 0,
		"duration_seconds": 1,
		"ready_at_unix": 1
	}]
	main.set("state", state)

	var page_description: RichTextLabel = main.get_node("GlobalOverlayLayer/OverlayFrame/OverlayModeStack/ResearchOverlay/PageDescription")
	var primary_action: Button = main.get_node("GlobalOverlayLayer/OverlayFrame/OverlayModeStack/ResearchOverlay/ActionRow/ResearchActionButton")
	var production_workbench: Control = main.get_node("Root/Body/MainArea/WorkbenchPanel/ProductionWorkbench")
	var bulk_action_button: MenuButton = production_workbench.get_node("ProductionQueueHeader/BulkActionButton")
	var status_label: Label = main.get_node("Root/StatusBar/StatusLabel")
	var storefront_manage_panel: Control = main.get_node_or_null("GlobalOverlayLayer/OverlayFrame/OverlayModeStack/StorefrontManageOverlay/StorefrontManagePanel")
	var purchase_page_button: Button = main.get_node("Root/Body/MainArea/WorkbenchPanel/WorkbenchLauncher/PurchaseButton")

	main.call("_show_page", "purchase")
	await process_frame
	var purchase_regions_grid: GridContainer = main.get_node("GlobalOverlayLayer/OverlayFrame/OverlayModeStack/PurchaseOverlay/PurchaseRegionsGrid")
	if purchase_regions_grid.columns != 3 or purchase_regions_grid.get_child_count() != 6:
		_fail("purchase page should expose six source regions in three columns")
	if not production_workbench.visible:
		_fail("opening purchase should keep the production workbench visible underneath")

	main.call("_show_page", "output")
	await process_frame
	var output_description: RichTextLabel = main.get_node("GlobalOverlayLayer/OverlayFrame/OverlayModeStack/OutputOverlay/PageDescription")
	var output_primary_action: Button = main.get_node("GlobalOverlayLayer/OverlayFrame/OverlayModeStack/OutputOverlay/OutputActions/OutputPrimaryActionButton")
	if output_description.text.find("可收") == -1:
		_fail("output page should summarize ready harvest count")
	if not output_primary_action.visible or output_primary_action.text != "一键收获":
		_fail("output page should expose one-click harvest as the primary action")
	var rice_before: int = int(state.get_ingredient_count("rice"))
	output_primary_action.emit_signal("pressed")
	await process_frame
	if state.get_ingredient_count("rice") <= rice_before:
		_fail("one-click harvest should add ready output inventory")
	if status_label.text.find("一键收获") == -1:
		_fail("one-click harvest should summarize harvested items in status text")

	main.call("_show_page", "research")
	await process_frame
	if page_description.text.find("研发制作") == -1:
		_fail("research page should show the current research summary")
	if not primary_action.visible or primary_action.text != "研发":
		_fail("research page should keep compact research action")
	var bulk_popup := bulk_action_button.get_popup()
	if bulk_popup.item_count != 3 or bulk_popup.get_item_text(0) != "制作全部":
		_fail("research page should expose make-all in the production queue header")
	if bulk_popup.item_count != 3 or bulk_popup.get_item_text(2) != "上架全部":
		_fail("research page should expose list-all in the production queue header")

	main.call("_show_page", "storefront_manage")
	await process_frame
	if not production_workbench.visible:
		_fail("storefront manage overlay should leave the production workbench intact")
	if storefront_manage_panel == null:
		_fail("storefront manage page should use a dedicated structured panel")
	elif not storefront_manage_panel.visible:
		_fail("storefront manage panel should be visible on storefront manage page")
	else:
		var pages_base := "ManagementCenterPages/"
		var overview_base := pages_base + "OverviewPage/"
		var strategy_left_base := pages_base + "StrategyPage/StrategyColumns/StrategyLeft/"
		var strategy_base := pages_base + "StrategyPage/StrategyColumns/"
		var current_build_panel := storefront_manage_panel.get_node_or_null(overview_base + "CurrentBuildPanel") as PanelContainer
		var bonus_panel := storefront_manage_panel.get_node_or_null(strategy_left_base + "CombinationBonusPanel") as PanelContainer
		var forecast_panel := storefront_manage_panel.get_node_or_null(overview_base + "RoundForecastPanel") as PanelContainer
		var props_theme_panel := storefront_manage_panel.get_node_or_null(strategy_base + "PropsThemePanel") as PanelContainer
		for section_panel in [current_build_panel, bonus_panel, forecast_panel, props_theme_panel]:
			if section_panel == null:
				_fail("storefront manage page should declare current build, bonus, forecast, and props/theme sections")
				break
			if section_panel.get_theme_stylebox("panel") == null:
				_fail("storefront manage section should keep a visible panel style")
		for outer_panel in [current_build_panel, bonus_panel, forecast_panel]:
			if outer_panel != null and outer_panel.theme_type_variation != &"DessertSectionPanel":
				_fail("storefront summary sections should keep only their outer panel material")
		var main_panel_metric_paths := [
			overview_base + "CurrentBuildPanel/CurrentBuildContent/CurrentBuildMetrics/OpenSlotsMetric",
			overview_base + "CurrentBuildPanel/CurrentBuildContent/CurrentBuildMetrics/PlacedMetric",
			overview_base + "CurrentBuildPanel/CurrentBuildContent/CurrentBuildMetrics/ListedStockMetric",
			strategy_left_base + "CombinationBonusPanel/CombinationBonusContent/BonusGrid/RegionBonusCell",
			strategy_left_base + "CombinationBonusPanel/CombinationBonusContent/BonusGrid/FlavorBonusCell",
			strategy_left_base + "CombinationBonusPanel/CombinationBonusContent/BonusGrid/SetBonusCell",
			strategy_left_base + "CombinationBonusPanel/CombinationBonusContent/BonusGrid/ConflictBonusCell",
			strategy_left_base + "CombinationBonusPanel/CombinationBonusContent/BonusGrid/PropBonusCell",
			strategy_left_base + "CombinationBonusPanel/CombinationBonusContent/BonusGrid/ThemeBonusCell",
			overview_base + "RoundForecastPanel/RoundForecastContent/ForecastMetricGrid/IncomeMetric",
			overview_base + "RoundForecastPanel/RoundForecastContent/ForecastMetricGrid/ReputationMetric",
			overview_base + "RoundForecastPanel/RoundForecastContent/ForecastMetricGrid/SoldMetric",
			overview_base + "RoundForecastPanel/RoundForecastContent/ForecastMetricGrid/LowStockMetric"
		]
		for metric_path in main_panel_metric_paths:
			var metric_panel := storefront_manage_panel.get_node_or_null(metric_path) as PanelContainer
			if metric_panel == null:
				_fail("storefront metric should remain declared: %s" % metric_path)
			elif metric_panel.theme_type_variation != &"DessertMetricPanel":
				_fail("storefront metric should use the compact main panel material: %s" % metric_path)
			else:
				var metric_style := metric_panel.get_theme_stylebox("panel") as StyleBoxTexture
				if metric_style == null or metric_style.texture == null or metric_style.texture.resource_path != "res://resources/ui/skin/neighborhood_dessert/runtime/panel_main_normal.png":
					_fail("storefront metric should resolve panel_main_normal.png: %s" % metric_path)
				elif metric_style.get_content_margin(SIDE_LEFT) != 16.0 \
						or metric_style.get_content_margin(SIDE_TOP) != 14.0 \
						or metric_style.get_content_margin(SIDE_RIGHT) != 16.0 \
						or metric_style.get_content_margin(SIDE_BOTTOM) != 14.0:
					_fail("storefront metric should keep compact content margins: %s" % metric_path)
		var bonus_grid := storefront_manage_panel.get_node_or_null(strategy_left_base + "CombinationBonusPanel/CombinationBonusContent/BonusGrid") as GridContainer
		if bonus_grid == null or bonus_grid.columns != 3 or bonus_grid.get_child_count() != 6:
			_fail("combination bonuses should use a 2 by 3 grid with six cells")
		var forecast_grid := storefront_manage_panel.get_node_or_null(overview_base + "RoundForecastPanel/RoundForecastContent/ForecastMetricGrid") as GridContainer
		var product_rate_grid := storefront_manage_panel.get_node_or_null(overview_base + "RoundForecastPanel/RoundForecastContent/ProductRateGrid") as GridContainer
		if forecast_grid == null or forecast_grid.columns != 4 or forecast_grid.get_child_count() != 4:
			_fail("round forecast should expose four compact metrics")
		if product_rate_grid == null or product_rate_grid.columns != 4 or product_rate_grid.get_child_count() != 4:
			_fail("product profit rate Top4 should be four parallel columns")
		var props_column := storefront_manage_panel.get_node_or_null(strategy_base + "PropsThemePanel/PropsThemeContent/PropsThemeColumns/PropsColumn/PropScroll/PropButtons") as VBoxContainer
		var theme_buttons := storefront_manage_panel.get_node_or_null(strategy_base + "PropsThemePanel/PropsThemeContent/PropsThemeColumns/ThemeColumn/ThemeScroll/ThemeButtons") as VBoxContainer
		if props_column == null or props_column.get_child_count() != 5:
			_fail("props panel should show all five prop choices")
		if theme_buttons == null or theme_buttons.get_child_count() != 4:
			_fail("theme panel should show none plus all three themes at once")
		if props_column != null and (props_column.get_child(0) as Button).theme_type_variation.is_empty():
			_fail("prop choices should keep button material")
		if theme_buttons != null and (theme_buttons.get_child(0) as Button).theme_type_variation.is_empty():
			_fail("theme choices should keep button material")
		var entrance_row := storefront_manage_panel.get_node_or_null(strategy_left_base + "StrategyActionRow") as HBoxContainer
		var report_button := storefront_manage_panel.get_node_or_null(overview_base + "CurrentBuildPanel/CurrentBuildContent/CurrentBuildHeader/RecentReportButton") as Button
		if entrance_row == null or entrance_row.get_child_count() != 2 or report_button == null:
			_fail("management center should keep strategy actions and the overview report entry")
		for removed_panel in ["StorefrontEnvironmentPanel", "StorefrontSettlePanel", "StorefrontBonusPanel", "StorefrontReceiptPanel", "StorefrontRiskPanel"]:
			if storefront_manage_panel.find_child(removed_panel, true, false) != null:
				_fail("storefront manage page should remove %s" % removed_panel)
		for retired_panel in ["StorefrontOverviewPanel", "StorefrontChallengePanel", "StorefrontBottomRow"]:
			if storefront_manage_panel.find_child(retired_panel, true, false) != null:
				_fail("new storefront management layout should retire %s" % retired_panel)
		if storefront_manage_panel is ScrollContainer:
			_fail("management center should not use whole-page scrolling")
		var open_slots_value := storefront_manage_panel.get_node_or_null(overview_base + "CurrentBuildPanel/CurrentBuildContent/CurrentBuildMetrics/OpenSlotsMetric/OpenSlotsValue") as Label
		var first_rate := storefront_manage_panel.get_node_or_null(overview_base + "RoundForecastPanel/RoundForecastContent/ProductRateGrid/ProductRate1") as RichTextLabel
		var low_stock_value := storefront_manage_panel.get_node_or_null(overview_base + "RoundForecastPanel/RoundForecastContent/ForecastMetricGrid/LowStockMetric/LowStockValue") as Label
		if open_slots_value == null or open_slots_value.text.find("16/168") == -1:
			_fail("current build should show unlocked showcase capacity")
		if first_rate == null or first_rate.text.find("金币/s") == -1:
			_fail("Top4 cells should show product name and coins per second")
		if low_stock_value == null or low_stock_value.text.is_empty():
			_fail("round forecast should always explain low stock state")
		var challenge_dialog := main.get_node_or_null("StorefrontChallengeDialog") as AcceptDialog
		var report_dialog := main.get_node_or_null("StorefrontRecentReportDialog") as AcceptDialog
		if challenge_dialog == null or report_dialog == null:
			_fail("challenge and recent report entrances should open scene-declared dialogs")
		elif entrance_row != null:
			if challenge_dialog.exclusive or not challenge_dialog.popup_window:
				_fail("special challenge should be a background-close entry dialog")
			if report_dialog.exclusive or not report_dialog.popup_window:
				_fail("recent report should be a background-close entry dialog")
			var challenge_entry := entrance_row.get_node_or_null("SpecialChallengeButton") as Button
			var report_entry := report_button
			if challenge_entry == null or report_entry == null:
				_fail("management center should expose challenge and report buttons")
			else:
				challenge_entry.emit_signal("pressed")
				await process_frame
				if not challenge_dialog.visible:
					_fail("special challenge entry should open its dialog")
				if challenge_dialog.size != Vector2i(560, 330):
					_fail("special challenge dialog should open at 560 by 330, got %s" % challenge_dialog.size)
				var popup_before_background_close := String(main.get("global_popup_mode"))
				await _click_viewport_position(purchase_page_button.get_global_rect().get_center())
				if challenge_dialog.visible:
					_fail("special challenge should close when its background is clicked")
				if String(main.get("global_popup_mode")) != popup_before_background_close:
					_fail("special challenge background close should not activate the underlying page tab")
				report_entry.emit_signal("pressed")
				await process_frame
				if not report_dialog.visible:
					_fail("recent report entry should open its dialog")
				if report_dialog.size != Vector2i(600, 300):
					_fail("recent report dialog should open at 600 by 300, got %s" % report_dialog.size)
				await _click_viewport_position(purchase_page_button.get_global_rect().get_center())
				if report_dialog.visible:
					_fail("recent report should close when its background is clicked")
				if String(main.get("global_popup_mode")) != popup_before_background_close:
					_fail("recent report background close should not activate the underlying page tab")

	main.queue_free()
	_finish()


func _joined_list_text(list: ItemList) -> String:
	var parts: Array[String] = []
	for index in range(list.item_count):
		parts.append(list.get_item_text(index))
	return "\n".join(parts)


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


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("RIGHT_CONSOLE_EXPERIENCE_SELF_CHECK_PASS")
		quit(0)
	else:
		for failure in _failures:
			printerr("RIGHT_CONSOLE_EXPERIENCE_SELF_CHECK_FAIL: %s" % failure)
		quit(1)
