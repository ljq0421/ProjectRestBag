extends SceneTree

const MainScene := preload("res://scenes/Main.tscn")
const GameState := preload("res://scripts/game_state.gd")
const VIEWPORT_SIZE := Vector2i(1920, 1080)

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = VIEWPORT_SIZE
	var main := MainScene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var state = GameState.new_game()
	state.tutorial_guide_skipped = true
	state.level = 6
	state.shop_level = 6
	state.coins = 5000
	state.unlock_device("round_pot")
	state.unlock_device("oven")
	state.unlock_device("chiller")
	state.unlock_device("griddle")
	state.unlock_device("mixer")
	main.state = state
	main.call("_show_page", "storefront_manage")
	await process_frame

	var base := "GlobalOverlayLayer/OverlayFrame/OverlayModeStack/StorefrontManageOverlay/StorefrontManagePanel"
	var panel := main.get_node_or_null(base) as Control
	var tabs := main.get_node_or_null(base + "/ManagementCenterTabs") as HBoxContainer
	var overview_tab := main.get_node_or_null(base + "/ManagementCenterTabs/OverviewTab") as Button
	var strategy_tab := main.get_node_or_null(base + "/ManagementCenterTabs/StrategyTab") as Button
	var device_tab := main.get_node_or_null(base + "/ManagementCenterTabs/DeviceGrowthTab") as Button
	var pages := main.get_node_or_null(base + "/ManagementCenterPages") as Control
	var overview_page := main.get_node_or_null(base + "/ManagementCenterPages/OverviewPage") as Control
	var strategy_page := main.get_node_or_null(base + "/ManagementCenterPages/StrategyPage") as Control
	var device_page := main.get_node_or_null(base + "/ManagementCenterPages/DeviceGrowthPage") as Control
	for required in [panel, tabs, overview_tab, strategy_tab, device_tab, pages, overview_page, strategy_page, device_page]:
		_expect(required != null, "management center should declare every tab and page in the scene")
	if _failures.size() > 0:
		main.queue_free()
		await process_frame
		_finish()
		return

	_expect(not panel is ScrollContainer, "management center should not use a page-level ScrollContainer")
	_expect(overview_page.visible and not strategy_page.visible and not device_page.visible, "management center should open on overview only")
	_expect(main.get_node_or_null(base + "/ManagementCenterPages/OverviewPage/CurrentBuildPanel") != null, "overview should own current build")
	_expect(main.get_node_or_null(base + "/ManagementCenterPages/OverviewPage/RoundForecastPanel") != null, "overview should own round forecast")
	_expect(main.get_node_or_null(base + "/ManagementCenterPages/StrategyPage/StrategyColumns/StrategyLeft/CombinationBonusPanel") != null, "strategy should own combination bonuses")
	_expect(main.get_node_or_null(base + "/ManagementCenterPages/StrategyPage/StrategyColumns/PropsThemePanel") != null, "strategy should own props and themes")
	_expect(device_page.has_method("refresh"), "device growth page should bind state through refresh")
	_expect(device_page.has_method("upgrade_ready_count"), "device growth page should expose the ready-device count")
	_expect(device_page.has_signal("upgrade_requested"), "device growth page should emit upgrade requests")
	_expect(device_page.has_signal("catalog_filter_requested"), "device growth page should emit catalog filter requests")

	var frame := main.get_node("GlobalOverlayLayer/OverlayFrame") as Control
	var initial_frame_size := frame.size
	var initial_panel_size := panel.size
	strategy_tab.emit_signal("pressed")
	await process_frame
	_expect(not overview_page.visible and strategy_page.visible and not device_page.visible, "strategy tab should show only strategy")
	_expect(frame.size == initial_frame_size and panel.size == initial_panel_size, "strategy tab should not resize the management center")
	device_tab.emit_signal("pressed")
	await process_frame
	_expect(not overview_page.visible and not strategy_page.visible and device_page.visible, "device tab should show only device growth")
	_expect(frame.size == initial_frame_size and panel.size == initial_panel_size, "device tab should not resize the management center")

	_expect(main.get_node_or_null("GlobalOverlayLayer/OverlayFrame/OverlayModeStack/ResearchOverlay/DeviceGrowthBar") == null, "research overlay should not retain DeviceGrowthBar")
	_expect(main.get_node_or_null("DeviceGrowthDrawer") == null, "Main should not retain nested DeviceGrowthDrawer")
	_expect(String(main.get("global_popup_mode")) == "storefront_manage", "internal storefront_manage route should stay stable")
	var overlay_title := main.get_node("GlobalOverlayLayer/OverlayFrame/OverlayHeader/OverlayTitle") as Label
	_expect(overlay_title.text == "经营中心", "player-facing popup title should be 经营中心")

	main.queue_free()
	await process_frame
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("MANAGEMENT_CENTER_LAYOUT_SELF_CHECK_PASS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
