extends SceneTree

const MAIN := preload("res://scenes/Main.tscn")
const GAME_STATE := preload("res://scripts/game_state.gd")

var _failures: Array[String] = []
var _save_path := OS.get_temp_dir().path_join("showcase_round_ui_self_check.json")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var view = MAIN.instantiate()
	var initial_pulse_summary := view.get_node_or_null("Root/Body/MainArea/StorefrontPanel/ShowcasePanel/ShowcasePulseSummary") as Label
	if initial_pulse_summary != null:
		_expect_equal("scene pulse summary starts without refill hint", initial_pulse_summary.text.find("待补货") >= 0, false)
		_expect_equal("scene pulse summary starts with heat", initial_pulse_summary.text.find("热度") >= 0, true)
	view.set("save_path", _save_path)
	view.set("broken_save_path", _save_path + ".broken")
	root.add_child(view)
	await process_frame
	var pages_base := "GlobalOverlayLayer/OverlayFrame/OverlayModeStack/StorefrontManageOverlay/StorefrontManagePanel/ManagementCenterPages/"
	var overview_base := pages_base + "OverviewPage/"
	var strategy_base := pages_base + "StrategyPage/StrategyColumns/StrategyLeft/"
	var weather_icon := view.get_node_or_null("Root/Body/MainArea/StorefrontPanel/ShowcasePanel/RoundControlBar/WeatherForecastIcon") as TextureRect
	var pulse_summary := view.get_node_or_null("Root/Body/MainArea/StorefrontPanel/ShowcasePanel/ShowcasePulseSummary") as Label
	var open_slots_value := view.get_node_or_null(overview_base + "CurrentBuildPanel/CurrentBuildContent/CurrentBuildMetrics/OpenSlotsMetric/OpenSlotsValue") as Label
	var placed_value := view.get_node_or_null(overview_base + "CurrentBuildPanel/CurrentBuildContent/CurrentBuildMetrics/PlacedMetric/PlacedValue") as Label
	var stock_value := view.get_node_or_null(overview_base + "CurrentBuildPanel/CurrentBuildContent/CurrentBuildMetrics/ListedStockMetric/ListedStockValue") as Label
	var bonus_grid := view.get_node_or_null(strategy_base + "CombinationBonusPanel/CombinationBonusContent/BonusGrid") as GridContainer
	var region_bonus_value := view.get_node_or_null(strategy_base + "CombinationBonusPanel/CombinationBonusContent/BonusGrid/RegionBonusCell/Content/Value") as Label
	var forecast_income := view.get_node_or_null(overview_base + "RoundForecastPanel/RoundForecastContent/ForecastMetricGrid/IncomeMetric/IncomeValue") as Label
	var forecast_sold := view.get_node_or_null(overview_base + "RoundForecastPanel/RoundForecastContent/ForecastMetricGrid/SoldMetric/SoldValue") as Label
	var forecast_low_stock := view.get_node_or_null(overview_base + "RoundForecastPanel/RoundForecastContent/ForecastMetricGrid/LowStockMetric/LowStockValue") as Label
	var product_rate_grid := view.get_node_or_null(overview_base + "RoundForecastPanel/RoundForecastContent/ProductRateGrid") as GridContainer
	var entrance_row := view.get_node_or_null(strategy_base + "StrategyActionRow") as HBoxContainer
	var challenge_summary := view.get_node_or_null("StorefrontChallengeDialog/ChallengeContent/ChallengeSummary") as RichTextLabel
	var sprint_button := view.get_node_or_null("StorefrontChallengeDialog/ChallengeContent/ChallengeButtons/SprintChallengeButton") as Button
	var value_button := view.get_node_or_null("StorefrontChallengeDialog/ChallengeContent/ChallengeButtons/ValueChallengeButton") as Button
	var chain_button := view.get_node_or_null("StorefrontChallengeDialog/ChallengeContent/ChallengeButtons/ChainChallengeButton") as Button
	var report_label := view.get_node_or_null("StorefrontRecentReportDialog/ReportLabel") as RichTextLabel
	for required in [weather_icon, pulse_summary, open_slots_value, placed_value, stock_value, bonus_grid, region_bonus_value, forecast_income, forecast_sold, forecast_low_stock, product_rate_grid, entrance_row, challenge_summary, sprint_button, value_button, chain_button, report_label]:
		if required == null:
			_fail("storefront scene should declare build, bonuses, forecast, full choices, dialogs, and entrance row")
			break
	for removed_panel in ["StorefrontEnvironmentPanel", "StorefrontSettlePanel", "StorefrontBonusPanel", "StorefrontReceiptPanel", "StorefrontRiskPanel"]:
		_expect_equal("storefront removes %s" % removed_panel, view.get_node_or_null(pages_base + removed_panel), null)
	var dialog := view.get_node_or_null("ShowcaseRoundSettlementDialog")
	if dialog != null:
		_expect_equal("settlement removes summary/detail tabs", dialog.get_node_or_null("SettlementBody/SettlementContent/SettlementTabs"), null)
		_expect_equal("settlement places round detail after summary", dialog.get_node_or_null("SettlementBody/SettlementContent/RoundDetailGrid") is GridContainer, true)

	var state = GAME_STATE.new_game()
	for feature_id in ["output", "inventory", "research", "craft", "catalog", "list", "rulebook", "arrange", "business", "storefront_manage"]:
		state.unlock_core_feature(feature_id)
	state.level = 6
	state.shop_level = 6
	state.coins = 100000
	state.business_round_id = 2
	state.active_business_round = {
		"round_id": 2, "phase": "adjusting", "duration_ms": 30000, "remaining_ms": 30000, "heat": 0,
		"environment": {"label": "甜食热潮｜晴朗天气", "total_price_pct": 8.0, "total_speed_pct": 3.0}
	}
	state.recent_showcase_round_reports = [{
		"round_id": 1, "kind": "standard", "total_coins": 188, "sold_count": 6,
		"base_income": 140, "market_income": 12, "layout_extra_income": 31, "clearance_income": 5,
		"top_recipe_id": "sponge_cake"
	}]
	state.add_recipe("sponge_cake")
	state.add_product("sponge_cake", 3)
	state.list_display_item("sponge_cake", [Vector2i(5, 6), Vector2i(5, 7), Vector2i(6, 6), Vector2i(6, 7)], 2)
	view.set("state", state)
	view.call("_sync_showcase_slot_from_display_item", 76, "sponge_cake", 2)
	view.call("_show_page", "storefront_manage")
	var adjusting_tooltip := String(view.call("_showcase_slot_tooltip", 76, 0))
	_expect_equal("adjusting tooltip shows expected completed sales", adjusting_tooltip.find("预计完整成交") >= 0, true)
	_expect_equal("adjusting tooltip shows next threshold gap", adjusting_tooltip.find("距离下一档") >= 0, true)
	_expect_equal("adjusting tooltip states continuous-stock premise", adjusting_tooltip.find("库存持续充足") >= 0, true)
	if weather_icon != null:
		_expect_equal("round control weather tooltip keeps environment label", weather_icon.tooltip_text.find("甜食热潮｜晴朗天气") >= 0, true)
		_expect_equal("round control weather tooltip appends environment price", weather_icon.tooltip_text.find("售价 +8%") >= 0, true)
		_expect_equal("round control weather tooltip appends environment speed", weather_icon.tooltip_text.find("售速 +3%") >= 0, true)
	if pulse_summary != null:
		_expect_equal("pulse summary does not repeat environment", pulse_summary.text.find("甜食热潮") >= 0, false)
		_expect_equal("pulse summary does not restore refill hint", pulse_summary.text.find("待补货") >= 0, false)
		_expect_equal("pulse summary keeps live stock", pulse_summary.text.find("可售库存") >= 0, true)
	if open_slots_value != null:
		_expect_equal("current build shows unlocked capacity", open_slots_value.text.find("16/168") >= 0, true)
	if placed_value != null:
		_expect_equal("current build shows placed count", placed_value.text.find("1 件") >= 0, true)
	if stock_value != null:
		_expect_equal("current build shows listed stock", stock_value.text.find("2 份") >= 0, true)
	if bonus_grid != null:
		_expect_equal("combination bonus grid uses three columns", bonus_grid.columns, 3)
		_expect_equal("combination bonus grid has six cells", bonus_grid.get_child_count(), 6)
	if region_bonus_value != null:
		_expect_equal("combination bonus grid explains per-product rate impact", region_bonus_value.tooltip_text.find("单品收益率") >= 0, true)
	if not view.has_method("_storefront_rate_impact_percent"):
		_fail("combination bonus should expose multiplicative product rate impact")
	else:
		_expect_equal(
			"combination bonus combines price and speed multiplicatively",
			int(round(float(view.call("_storefront_rate_impact_percent", 10.0, 10.0)))),
			21
		)
	if forecast_income != null:
		_expect_equal("round forecast shows income", forecast_income.text.find("预估收益") >= 0, true)
		_expect_equal("round forecast simulates nonzero income", forecast_income.text.find("+0 金币") == -1, true)
	if forecast_sold != null:
		_expect_equal("round forecast simulates sellable stock", forecast_sold.text.find("0 件") == -1, true)
	if forecast_low_stock != null:
		_expect_equal("round forecast includes low stock state", forecast_low_stock.text.find("低库存提示") >= 0, true)
	if product_rate_grid != null:
		var first_rate := product_rate_grid.get_child(0) as RichTextLabel
		_expect_equal("Top4 first cell shows product", first_rate.text.find("海绵杯蛋糕") >= 0, true)
		_expect_equal("Top4 first cell shows coins per second", first_rate.text.find("金币/s") >= 0, true)
	if report_label != null:
		_expect_equal("right page shows recent report total", report_label.text.find("188") >= 0, true)
		_expect_equal("right page shows report attribution", report_label.text.find("布局") >= 0, true)
	if sprint_button != null:
		_expect_equal("unlocked challenge can be accepted while adjusting", sprint_button.disabled, false)
	if chain_button != null:
		_expect_equal("level six challenge is visible", chain_button.visible, true)
	if challenge_summary != null:
		_expect_equal("challenge summary points to standard round action", challenge_summary.text.find("左侧“开始营业”将开始标准 30 秒营业") >= 0, true)

	var visible_copy := "%s\n%s\n%s\n%s\n%s" % [
		String(view.get("cashier_receipt_text")),
		String(weather_icon.tooltip_text if weather_icon != null else ""),
		String(open_slots_value.text if open_slots_value != null else ""),
		String(challenge_summary.text if challenge_summary != null else ""),
		String(report_label.text if report_label != null else "")
	]
	for obsolete in ["自动结算", "缺货损失", "离线汇总", "本轮成交", "当前加成", "最近成交", "补货提示"]:
		_expect_equal("visible storefront copy removes %s" % obsolete, visible_copy.find(obsolete), -1)

	var started := bool(view.call("_start_showcase_business_round"))
	_expect_equal("business round starts from the management page", started, true)
	if sprint_button != null:
		_expect_equal("business start immediately locks challenge acceptance", sprint_button.disabled, true)
	var running_item_states: Dictionary = state.active_business_round.get("item_states", {})
	var running_item: Dictionary = running_item_states.get("sponge_cake", {}).duplicate(true)
	running_item["fresh_stock"] = 0
	running_item["carried_stock"] = 0
	running_item["waiting_for_refill"] = true
	running_item_states["sponge_cake"] = running_item
	state.active_business_round["item_states"] = running_item_states
	if stock_value != null:
		stock_value.text = "STALE"
	if forecast_low_stock != null:
		forecast_low_stock.text = "STALE"
	view.call("_process_showcase_business_round_delta", 1.0)
	if stock_value != null:
		_expect_equal("running cadence refreshes current build from live stock", stock_value.text.find("0 份") >= 0, true)
	if forecast_low_stock != null:
		_expect_equal("running cadence refreshes low-stock forecast", forecast_low_stock.text.find("0份") >= 0, true)
	_finish(view)


func _expect_equal(label: String, actual: Variant, expected: Variant) -> void:
	if actual != expected:
		_fail("%s expected %s, got %s" % [label, expected, actual])


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish(view) -> void:
	view.queue_free()
	if _failures.is_empty():
		print("SHOWCASE_ROUND_UI_SELF_CHECK_PASS")
		quit(0)
	else:
		for failure in _failures:
			printerr("SHOWCASE_ROUND_UI_SELF_CHECK_FAIL: %s" % failure)
		quit(1)
