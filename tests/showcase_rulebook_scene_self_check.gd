extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/Main.tscn"
const GAME_STATE_PATH := "res://scripts/game_state.gd"

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var packed := load(MAIN_SCENE_PATH) as PackedScene
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var state = load(GAME_STATE_PATH).new_game()
	state.level = 2
	main.set("state", state)
	main.call("_show_page", "storefront_manage")
	await process_frame

	var board_path := "Root/Body/MainArea/StorefrontPanel/ShowcasePanel"
	var rulebook_button: Button = main.get_node_or_null(board_path + "/RoundControlBar/RulebookButton")
	if rulebook_button == null:
		_fail("showcase control bar should declare a persistent rulebook button")
	else:
		_assert_equal(rulebook_button.text, "构筑规则", "rulebook button should use the approved label")

	var dialog: Window = main.get_node_or_null("ShowcaseRulebookDialog")
	if dialog == null:
		_fail("main scene should declare a real centered rulebook dialog")
	else:
		_assert_equal(dialog.exclusive, false, "rulebook should allow background close")
		_assert_equal(dialog.popup_window, true, "rulebook should close as a popup window when focus leaves it")
		dialog.call("show_rules", state, main.get("catalog"))
		await process_frame
		var category_list: ItemList = dialog.get_node_or_null("RulebookBody/RulebookLayout/CategoryPanel/CategoryList")
		var rule_text: RichTextLabel = dialog.get_node_or_null("RulebookBody/RulebookLayout/RuleScroll/RuleText")
		if category_list == null:
			_fail("rulebook should declare category navigation")
		else:
			_assert_equal(category_list.item_count, 10, "rulebook should contain the approved categories plus expansion")
			var category_texts: Array[String] = []
			for index in range(category_list.item_count):
				category_texts.append(category_list.get_item_text(index))
			for expected in ["区域", "橱窗扩建", "四方向相邻", "连通套装", "冲突减损", "上架变体", "配方成长", "角色与热度连锁", "陈列道具", "橱窗主题"]:
				if not category_texts.has(expected):
					_fail("rulebook should expose category: %s" % expected)
		if rule_text == null:
			_fail("rulebook should declare a scrollable rule text area")
		else:
			var text := rule_text.text
			for expected in ["第5行", "第6-7行", "第8行", "第7-8列", "售价 -3%", "售速 +8%", "跨区"]:
				if text.find(expected) == -1:
					_fail("region rulebook page should explain current dynamic value: %s" % expected)
			dialog.call("select_category", "roles")
			text = rule_text.text
			for expected in ["四方向相邻", "静默终止", "不显示标记"]:
				if text.find(expected) == -1:
					_fail("role rulebook page should explicitly define: %s" % expected)
			dialog.call("select_category", "expansion")
			text = rule_text.text
			for expected in ["第一格 300", "每购买一格 +10", "单格/N格", "购买行/列", "Lv.2 36格"]:
				if text.find(expected) == -1:
					_fail("expansion rulebook page should explicitly define: %s" % expected)
		dialog.close_requested.emit()
		await process_frame
		_assert_equal(dialog.visible, false, "rulebook close request should hide the dialog")

	var build_panel: PanelContainer = main.get_node_or_null("GlobalOverlayLayer/OverlayFrame/OverlayModeStack/StorefrontManageOverlay/StorefrontManagePanel/ManagementCenterPages/OverviewPage/CurrentBuildPanel")
	var build_title: Label = main.get_node_or_null("GlobalOverlayLayer/OverlayFrame/OverlayModeStack/StorefrontManageOverlay/StorefrontManagePanel/ManagementCenterPages/OverviewPage/CurrentBuildPanel/CurrentBuildContent/CurrentBuildHeader/CurrentBuildTitle")
	var open_slots_value: Label = main.get_node_or_null("GlobalOverlayLayer/OverlayFrame/OverlayModeStack/StorefrontManageOverlay/StorefrontManagePanel/ManagementCenterPages/OverviewPage/CurrentBuildPanel/CurrentBuildContent/CurrentBuildMetrics/OpenSlotsMetric/OpenSlotsValue")
	var view_rules_button: Button = main.get_node_or_null("GlobalOverlayLayer/OverlayFrame/OverlayModeStack/StorefrontManageOverlay/StorefrontManagePanel/ManagementCenterPages/StrategyPage/StrategyColumns/StrategyLeft/CombinationBonusPanel/CombinationBonusContent/CombinationBonusHeader/ViewAllRulesButton")
	if build_panel == null or build_title == null or open_slots_value == null or view_rules_button == null:
		_fail("storefront management should declare the current-build card and rule entry")
	else:
		if build_title.text != "当前经营" or open_slots_value.text.find("16/168") == -1:
			_fail("current-build card should expose its title and unlocked capacity")

	var grid: GridContainer = main.get_node(board_path + "/ShowcaseGrid")
	_assert_region_cell(grid, 61, "front")
	_assert_region_cell(grid, 76, "golden")
	_assert_region_cell(grid, 103, "back")
	var locked: Button = grid.get_child(0)
	if locked.theme_type_variation != &"DessertShowcaseSlotLocked":
		_fail("locked skin should remain higher priority than region tint")

	main.queue_free()
	_finish()


func _assert_region_cell(grid: GridContainer, slot_index: int, expected_region: String) -> void:
	var button: Button = grid.get_child(slot_index)
	_assert_equal(String(button.get_meta("showcase_region_id", "")), expected_region, "unlocked cell should expose its dynamic region")
	if button.modulate == Color.WHITE:
		_fail("%s cell should receive a subtle region tint" % expected_region)


func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_fail("%s; expected=%s actual=%s" % [message, expected, actual])


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("SHOWCASE_RULEBOOK_SCENE_SELF_CHECK_PASS")
		quit(0)
		return
	for failure in _failures:
		printerr("SHOWCASE_RULEBOOK_SCENE_SELF_CHECK_FAIL: %s" % failure)
	quit(1)
