extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/Main.tscn"
const GAME_STATE := preload("res://scripts/game_state.gd")
const CORE_FEATURE_UNLOCK_SERVICE := preload("res://scripts/core_feature_unlock_service.gd")

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var packed := load(MAIN_SCENE_PATH) as PackedScene
	var main := packed.instantiate()
	main.set("save_path", OS.get_temp_dir().path_join("progression_access_self_check.json"))
	root.add_child(main)
	await process_frame
	await process_frame

	var state = GAME_STATE.new_game()
	main.set("state", state)
	main.call("_show_page", "purchase")
	await process_frame
	var purchase_grid := main.get_node("GlobalOverlayLayer/OverlayFrame/OverlayModeStack/PurchaseOverlay/PurchaseRegionsGrid")
	var farm := _region(purchase_grid, "农场")
	var ranch := _region(purchase_grid, "养殖场")
	var forest := _region(purchase_grid, "林场")
	var pond := _region(purchase_grid, "水塘")
	var supply := _region(purchase_grid, "辅料")
	var tools := _region(purchase_grid, "工具")
	for region in [farm, ranch, forest, pond, supply, tools]:
		_expect(region != null, "all purchase regions should remain visible")
	_expect(not bool(farm.get_meta("access_locked", true)), "farm should open at Lv0")
	for region in [ranch, forest, pond, supply, tools]:
		_expect(bool(region.get_meta("access_locked", false)), "%s should show a lock at Lv0" % String(region.get("category_id")))
	var rice_row := farm.call("row_for_item", "rice_seed") as Control
	var wheat_row := farm.call("row_for_item", "wheat_seed") as Control
	_expect(rice_row != null, "rice seed should be the only visible Lv0 farm item")
	_expect(wheat_row == null, "future farm ingredients should not expose mystery details")
	for locked_region in [ranch, forest, pond, supply, tools]:
		_expect((locked_region.call("item_rows") as Array).is_empty(), "locked purchase panel should hide item details")

	state.unlock_core_feature(CORE_FEATURE_UNLOCK_SERVICE.OUTPUT)
	state.unlock_core_feature(CORE_FEATURE_UNLOCK_SERVICE.INVENTORY)
	main.call("_show_page", "output")
	await process_frame
	var output_grid := main.get_node("GlobalOverlayLayer/OverlayFrame/OverlayModeStack/OutputOverlay/OutputScroll/OutputGridRow")
	_expect(not _output_region(output_grid, "farm").get_meta("access_locked", true), "farm output should open at Lv0")
	_expect(bool(_output_region(output_grid, "ranch").get_meta("access_locked", false)), "ranch output should lock until Lv1")
	_expect(bool(_output_region(output_grid, "pond").get_meta("access_locked", false)), "pond output should lock until Lv1")
	_expect(bool(_output_region(output_grid, "forest").get_meta("access_locked", false)), "forest output should lock until Lv2")

	state.level = 1
	main.call("_show_page", "purchase")
	await process_frame
	_expect(not bool(ranch.get_meta("access_locked", true)), "ranch purchase should open at Lv1")
	_expect(not bool(pond.get_meta("access_locked", true)), "pond purchase should open at Lv1")
	_expect(not bool(supply.get_meta("access_locked", true)), "supply purchase should open at Lv1")
	_expect(not bool(tools.get_meta("access_locked", true)), "tools purchase should open at Lv1")
	_expect(bool(forest.get_meta("access_locked", false)), "forest purchase should remain locked at Lv1")

	state.level = 2
	main.call("_refresh_purchase_page")
	await process_frame
	_expect(not bool(forest.get_meta("access_locked", true)), "forest purchase should open at Lv2")

	main.queue_free()
	_finish()


func _region(grid: Control, category_id: String) -> Control:
	for child in grid.get_children():
		if child is Control and String(child.get("category_id")) == category_id:
			return child
	return null


func _output_region(grid: Control, site_id: String) -> Control:
	for child in grid.get_children():
		if child is Control and String(child.get_meta("site_id", "")) == site_id:
			return child
	return null


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PROGRESSION_ACCESS_SELF_CHECK_PASS")
		quit(0)
		return
	for failure in _failures:
		printerr("PROGRESSION_ACCESS_SELF_CHECK_FAIL: %s" % failure)
	quit(1)
