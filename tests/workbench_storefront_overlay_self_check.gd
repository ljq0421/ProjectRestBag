extends SceneTree

const MAIN_SCENE := preload("res://scenes/Main.tscn")

var _failures: Array[String] = []
var _save_path := OS.get_temp_dir().path_join("workbench_storefront_overlay_self_check.json")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var view := MAIN_SCENE.instantiate()
	view.set("save_path", _save_path)
	view.set("broken_save_path", _save_path + ".broken")
	root.add_child(view)
	await process_frame
	await process_frame

	var launcher := view.get_node("Root/Body/MainArea/WorkbenchPanel/WorkbenchLauncher/StorefrontManageButton") as Button
	launcher.emit_signal("pressed")
	await process_frame

	var base := "GlobalOverlayLayer/OverlayFrame/OverlayModeStack/StorefrontManageOverlay/StorefrontManagePanel/ManagementCenterPages/"
	for panel_path in [
		"OverviewPage/CurrentBuildPanel",
		"OverviewPage/RoundForecastPanel",
		"StrategyPage/StrategyColumns/StrategyLeft/CombinationBonusPanel",
		"StrategyPage/StrategyColumns/PropsThemePanel"
	]:
		var panel := view.get_node_or_null(base + panel_path) as PanelContainer
		_expect_equal("storefront keeps %s" % panel_path, panel != null, true)
	for button_path in [
		"OverviewPage/CurrentBuildPanel/CurrentBuildContent/CurrentBuildHeader/RecentReportButton",
		"StrategyPage/StrategyColumns/StrategyLeft/StrategyActionRow/SpecialChallengeButton",
		"StrategyPage/StrategyColumns/StrategyLeft/StrategyActionRow/StorefrontExpansionButton"
	]:
		var button := view.get_node_or_null(base + button_path) as Button
		_expect_equal("storefront keeps %s" % button_path, button != null, true)
	var open_slots := view.get_node_or_null(base + "OverviewPage/CurrentBuildPanel/CurrentBuildContent/CurrentBuildMetrics/OpenSlotsMetric/OpenSlotsValue") as Label
	_expect_equal("storefront live metric exists", open_slots != null, true)
	if open_slots != null:
		_expect_equal("storefront live metric is refreshed", open_slots.text.find("开放格位") >= 0, true)

	view.queue_free()
	_cleanup_save()
	_finish()


func _expect_equal(label: String, actual: Variant, expected: Variant) -> void:
	if actual != expected:
		_fail("%s expected %s, got %s" % [label, expected, actual])


func _cleanup_save() -> void:
	for path in [_save_path, _save_path + ".broken"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("WORKBENCH_STOREFRONT_OVERLAY_SELF_CHECK_PASS")
		quit(0)
	else:
		for failure in _failures:
			printerr("WORKBENCH_STOREFRONT_OVERLAY_SELF_CHECK_FAIL: %s" % failure)
		quit(1)
