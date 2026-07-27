extends SceneTree

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const GAME_STATE := preload("res://scripts/game_state.gd")

var _failures: Array[String] = []
var _save_path := OS.get_temp_dir().path_join("showcase_backpack_scene_self_check.json")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	_delete_test_save()
	var view = MAIN_SCENE.instantiate()
	view.set("save_path", _save_path)
	view.set("broken_save_path", _save_path + ".broken")
	root.add_child(view)
	await process_frame
	await process_frame

	var state = GAME_STATE.new_game()
	state.add_recipe("sponge_cake")
	state.display_items["sponge_cake"] = {
		"cells": [Vector2i(4, 5), Vector2i(4, 6), Vector2i(5, 5), Vector2i(5, 6)],
		"stock": 2,
		"fresh_stock": 2,
		"carried_stock": 0,
		"variant_id": "standard",
		"base_sale_seconds": 10
	}
	state.active_business_round = {
		"round_id": 1,
		"phase": "running",
		"elapsed_ms": 5000,
		"remaining_ms": 25000,
		"duration_ms": 30000,
		"heat": 20,
		"environment": {"label": "甜食热潮｜晴朗天气"},
		"item_states": {
			"sponge_cake": {
				"fresh_stock": 2,
				"carried_stock": 0,
				"duration_ms": 10000,
				"cycle_elapsed_ms": 5000
			}
		}
	}
	view.set("state", state)
	view.call("_sync_showcase_slot_from_display_item", 46, "sponge_cake", 2)
	view.call("_show_page", "storefront_manage")
	await process_frame
	await process_frame

	if String(view.get("global_popup_mode")) != "storefront_manage":
		_fail("storefront management should open as an overlay")
	var stock_value: Label = view.get_node("GlobalOverlayLayer/OverlayFrame/OverlayModeStack/StorefrontManageOverlay/StorefrontManagePanel/ManagementCenterPages/OverviewPage/CurrentBuildPanel/CurrentBuildContent/CurrentBuildMetrics/ListedStockMetric/ListedStockValue")
	if stock_value.text.find("可售库存 2") == -1:
		_fail("current build should expose live listed stock")
	var weather_icon: TextureRect = view.get_node("Root/Body/MainArea/StorefrontPanel/ShowcasePanel/RoundControlBar/WeatherForecastIcon")
	if weather_icon.tooltip_text.find("甜食热潮｜晴朗天气") == -1 or weather_icon.tooltip_text.find("售价 +0%") == -1:
		_fail("round control weather icon should preserve the environment and price summary in its tooltip")

	var bars: Dictionary = view.get("showcase_progress_bars")
	var progress_bar := bars.get("sponge_cake") as ProgressBar
	if progress_bar == null:
		_fail("placed product should render one whole-item progress bar")
	elif progress_bar.size.x < 136.0 or progress_bar.value < 40.0 or progress_bar.value > 70.0:
		_fail("whole-item progress bar should span the 2x2 product and show round progress")

	state.active_business_round["item_states"]["sponge_cake"]["fresh_stock"] = 0
	state.active_business_round["item_states"]["sponge_cake"]["cycle_elapsed_ms"] = 0
	state.display_items["sponge_cake"]["stock"] = 0
	state.display_items["sponge_cake"]["fresh_stock"] = 0
	state.display_slots[46]["quantity"] = 0
	view.call("_refresh_storefront_showcase")
	await process_frame
	await process_frame
	var showcase_grid: GridContainer = view.get_node("Root/Body/MainArea/StorefrontPanel/ShowcasePanel/ShowcaseGrid")
	var anchor_button := showcase_grid.get_child(46) as Button
	var badge := anchor_button.get_node("StatusBadge") as Label
	if badge.text != "待补货":
		_fail("sold-out product should stay placed with a refill badge")

	view.queue_free()
	await process_frame
	_delete_test_save()
	_finish()


func _delete_test_save() -> void:
	for suffix_value: Variant in ["", ".tmp", ".previous", ".broken"]:
		var path: String = _save_path + String(suffix_value)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _finish() -> void:
	if _failures.is_empty():
		print("SHOWCASE_BACKPACK_SCENE_SELF_CHECK_PASS")
		quit(0)
		return
	for message in _failures:
		push_error(message)
	quit(1)


func _fail(message: String) -> void:
	if not _failures.has(message):
		_failures.append(message)
