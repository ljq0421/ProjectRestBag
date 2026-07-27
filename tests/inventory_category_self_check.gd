extends SceneTree

const MAIN := preload("res://scenes/Main.tscn")
const GAME_STATE := preload("res://scripts/game_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var main := MAIN.instantiate()
	var temp_dir := OS.get_temp_dir()
	main.set("save_path", temp_dir.path_join("project_rest_new_inventory_category_self_check.json"))
	main.set("broken_save_path", temp_dir.path_join("project_rest_new_inventory_category_self_check.broken.json"))
	root.add_child(main)
	await process_frame
	main.call("_show_inventory_global_popup")
	await process_frame

	var tabs := main.get_node(
		"GlobalOverlayLayer/OverlayFrame/OverlayModeStack/InventoryOverlay/InventoryBody/InventoryMainPanel/InventoryTabs"
	) as TabBar
	_expect(tabs.tab_count == 5, "inventory should expose five category tabs")
	var expected_tabs := [
		{"id": "all", "label": "全部"},
		{"id": "products", "label": "成品"},
		{"id": "ingredients", "label": "食材"},
		{"id": "seeds", "label": "种养"},
		{"id": "tools", "label": "工具"}
	]
	if tabs.tab_count == expected_tabs.size():
		for index in range(expected_tabs.size()):
			var expected: Dictionary = expected_tabs[index]
			_expect(
				String(tabs.get_tab_metadata(index)) == String(expected.get("id", "")),
				"inventory tab %d should use %s metadata" % [index, expected.get("id", "")]
			)
			_expect(
				tabs.get_tab_title(index) == String(expected.get("label", "")),
				"inventory tab %d should be labeled %s" % [index, expected.get("label", "")]
			)

	var inventory_state = GAME_STATE.new_game()
	inventory_state.ingredient_inventory.clear()
	inventory_state.add_ingredient("sugar", 4)
	inventory_state.add_ingredient("rice_seed", 3)
	inventory_state.add_ingredient("chick", 2)
	inventory_state.add_ingredient("calf", 1)
	main.set("state", inventory_state)

	var ingredient_ids := _entry_ids(main.call("_inventory_entries", "ingredients"))
	_expect(ingredient_ids.has("sugar"), "ingredient tab should keep cooking ingredients")
	_expect(not ingredient_ids.has("rice_seed"), "ingredient tab should exclude seeds")
	_expect(not ingredient_ids.has("chick"), "ingredient tab should exclude chicks")
	_expect(not ingredient_ids.has("calf"), "ingredient tab should exclude calves")

	var cultivation_ids := _entry_ids(main.call("_inventory_entries", "seeds"))
	_expect(not cultivation_ids.has("sugar"), "cultivation tab should exclude cooking ingredients")
	_expect(cultivation_ids.has("rice_seed"), "cultivation tab should include seeds")
	_expect(cultivation_ids.has("chick"), "cultivation tab should include chicks")
	_expect(cultivation_ids.has("calf"), "cultivation tab should include calves")

	main.queue_free()
	await process_frame
	_finish()


func _entry_ids(entries: Array) -> Array[String]:
	var ids: Array[String] = []
	for entry_value in entries:
		if entry_value is Dictionary:
			ids.append(String((entry_value as Dictionary).get("id", "")))
	return ids


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("INVENTORY_CATEGORY_SELF_CHECK_PASS")
		quit(0)
		return
	for failure in _failures:
		printerr("INVENTORY_CATEGORY_SELF_CHECK_FAIL: %s" % failure)
	quit(1)
