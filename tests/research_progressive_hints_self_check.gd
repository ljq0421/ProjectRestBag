extends SceneTree

const GameState := preload("res://scripts/game_state.gd")
const RecipeBook := preload("res://scripts/recipe_book.gd")
const MainScene := preload("res://scenes/Main.tscn")
const TEST_SAVE_PATH := "res://tests/research_progressive_hints_self_check.save.json"

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_state_defaults_and_sanitization()
	_test_progressive_hint_rules()
	_test_device_level_hint_increment()
	await _test_research_hint_ui()
	_cleanup_test_save()
	_finish()


func _test_state_defaults_and_sanitization() -> void:
	var fresh = GameState.new_game()
	_expect(fresh.get("research_hint_progress") is Dictionary and fresh.get("research_hint_progress") == {}, "new game should start without research hint progress")
	_expect(_string_property(fresh, "latest_research_hint_recipe_id") == "", "new game should start without a latest research hint")

	var loaded = GameState.from_dict({
		"research_hint_progress": {
			"sponge_cake": 2,
			"butter_cookie": 99,
			"missing_recipe": 3
		},
		"latest_research_hint_recipe_id": "sponge_cake"
	})
	_expect(_hint_level(loaded, "sponge_cake") == 2, "valid hint level should load")
	_expect(_hint_level(loaded, "butter_cookie") == 3, "hint level should clamp to three")
	var loaded_progress: Variant = loaded.get("research_hint_progress")
	_expect(loaded_progress is Dictionary and not (loaded_progress as Dictionary).has("missing_recipe"), "unknown recipe hint should be removed")
	_expect(_string_property(loaded, "latest_research_hint_recipe_id") == "sponge_cake", "valid latest hint target should load")

	var invalid_latest = GameState.from_dict({
		"research_hint_progress": {"sponge_cake": 1},
		"latest_research_hint_recipe_id": "missing_recipe"
	})
	_expect(_string_property(invalid_latest, "latest_research_hint_recipe_id") == "", "invalid latest hint target should clear")

	var round_trip = GameState.from_dict(loaded.to_dict())
	_expect(round_trip.get("research_hint_progress") == loaded.get("research_hint_progress"), "hint progress should survive round trip")
	_expect(_string_property(round_trip, "latest_research_hint_recipe_id") == "sponge_cake", "latest target should survive round trip")


func _hint_level(state, recipe_id: String) -> int:
	if not state.has_method("research_hint_level"):
		return -1
	return int(state.call("research_hint_level", recipe_id))


func _string_property(state, property_name: String) -> String:
	var value: Variant = state.get(property_name)
	return str(value) if value != null else ""


func _test_progressive_hint_rules() -> void:
	var state = GameState.new_game()
	state.level = 2
	state.shop_level = 2
	for item_id in ["flour", "egg", "vanilla", "coffee"]:
		state.add_ingredient(item_id, 5)

	var first: Dictionary = RecipeBook.research(state, "oven", ["flour", "egg", "vanilla"])
	var first_hint: Dictionary = first.get("hint", {})
	_expect(not bool(first.get("ok", false)), "close combination should fail before exact match")
	_expect(str(first_hint.get("target_recipe_id", "")) == "sponge_cake", "closest target should be sponge cake")
	_expect(int(first_hint.get("level", 0)) == 1, "first close failure should grant level one")
	_expect(str(first_hint.get("recipe_name", "")) == "", "level one should hide recipe name")
	_expect(str(first.get("message", "")).find("海绵杯蛋糕") == -1, "level one status should not leak recipe name")
	_expect(str(first.get("message", "")).find("白糖") == -1, "level one status should not leak exact missing material")

	var second: Dictionary = RecipeBook.research(state, "oven", ["flour", "egg", "coffee"])
	var second_hint: Dictionary = second.get("hint", {})
	_expect(str(second_hint.get("target_recipe_id", "")) == "sponge_cake", "changed materials should keep the same closest target")
	_expect(int(second_hint.get("level", 0)) == 2, "second close failure should grant level two")
	_expect(str(second_hint.get("recipe_name", "")) == "海绵杯蛋糕", "level two should reveal recipe name")
	_expect(str(second_hint.get("correct_device_id", "")) == "oven", "level two should reveal the correct device")
	_expect(_array_has(second_hint.get("missing_categories", []), "调味"), "level two should reveal missing material category")
	_expect(str(second.get("message", "")).find("海绵杯蛋糕") != -1, "level two status should reveal recipe name")
	_expect(str(second.get("message", "")).find("白糖") == -1, "level two status should still hide exact missing material")

	var third: Dictionary = RecipeBook.research(state, "oven", ["flour", "egg", "vanilla"])
	var third_hint: Dictionary = third.get("hint", {})
	_expect(int(third_hint.get("level", 0)) == 3, "third close failure should grant level three")
	_expect(_array_has(third_hint.get("missing_material_ids", []), "sugar"), "level three should reveal missing sugar")
	_expect(_array_has(third_hint.get("extra_material_ids", []), "vanilla"), "level three should reveal extra vanilla")
	_expect(_array_size(third_hint.get("material_statuses", [])) >= 4, "level three should expose full material statuses")
	_expect(str(third.get("message", "")).find("白糖") != -1, "level three status should reveal exact missing material")
	_expect(state.research_hint_level("sponge_cake") == 3, "state should persist the highest hint level")
	_expect(state.latest_research_hint_recipe_id == "sponge_cake", "state should remember latest valid target")

	var capped: Dictionary = RecipeBook.research(state, "oven", ["flour", "egg", "coffee"])
	_expect(int((capped.get("hint", {}) as Dictionary).get("level", 0)) == 3, "further failures should stay capped at three")

	if not _recipe_book_has_method("research_hint_view"):
		_expect(false, "RecipeBook should expose read-only research_hint_view")
		return

	var unrelated_state = GameState.new_game()
	unrelated_state.level = 1
	unrelated_state.shop_level = 1
	var unrelated_before: Dictionary = unrelated_state.research_hint_progress.duplicate(true)
	var unrelated: Dictionary = _research_hint_view(unrelated_state, "oven", ["coffee", "mint"])
	_expect(unrelated.is_empty(), "unrelated materials should not bind an arbitrary target")
	_expect(unrelated_state.research_hint_progress == unrelated_before, "read-only hint view should not mutate progress")

	var low_level = GameState.new_game()
	low_level.level = 1
	low_level.shop_level = 1
	var hidden: Dictionary = _research_hint_view(low_level, "mixer", ["sponge_cake", "cream", "strawberry"])
	_expect(hidden.is_empty(), "higher-level or locked-device recipe should not leak")

	var unlocked = GameState.new_game()
	unlocked.level = 2
	unlocked.shop_level = 2
	_expect(unlocked.add_recipe("sponge_cake"), "unlocked candidate fixture should successfully add sponge cake")
	var unlocked_hint: Dictionary = _research_hint_view(unlocked, "oven", ["flour", "egg", "vanilla"])
	_expect(str(unlocked_hint.get("target_recipe_id", "")) != "sponge_cake", "unlocked recipe should leave the candidate pool")

	var tie_state = GameState.new_game()
	tie_state.level = 1
	tie_state.shop_level = 1
	var stable_target := ""
	for attempt in range(5):
		var tie_hint: Dictionary = _research_hint_view(tie_state, "oven", ["flour"])
		var target_id := str(tie_hint.get("target_recipe_id", ""))
		if attempt == 0:
			stable_target = target_id
		_expect(target_id == stable_target, "equal-score target selection should remain stable")

	var duplicate_view: Dictionary = _research_hint_view(tie_state, "oven", ["flour", "flour", "egg"])
	_expect(int(duplicate_view.get("matched_count", 0)) <= int(duplicate_view.get("required_count", 0)), "duplicate selections should use multiset counts")

	var wrong_device_state = GameState.new_game()
	wrong_device_state.level = 2
	wrong_device_state.shop_level = 2
	for item_id in ["flour", "butter", "sugar"]:
		wrong_device_state.add_ingredient(item_id, 2)
	RecipeBook.research(wrong_device_state, "mixer", ["flour", "butter", "sugar"])
	var wrong_device_second: Dictionary = RecipeBook.research(wrong_device_state, "mixer", ["flour", "butter", "sugar"])
	var wrong_device_hint: Dictionary = wrong_device_second.get("hint", {})
	_expect(int(wrong_device_hint.get("level", 0)) == 2, "second wrong-device failure should grant level two")
	_expect(_array_size(wrong_device_hint.get("missing_categories", [])) == 0, "wrong-device exact materials should have no missing category")
	_expect(str(wrong_device_second.get("message", "")).find("材料已齐") != -1, "wrong-device level two should say materials are complete")


func _test_device_level_hint_increment() -> void:
	var state = GameState.new_game()
	state.level = 2
	state.shop_level = 2
	state.device_growth["oven"] = {
		"level": 2,
		"use_count": 10,
		"research_count": 10,
		"production_batch_count": 0
	}
	for item_id in ["flour", "egg", "vanilla"]:
		state.add_ingredient(item_id, 2)
	var result: Dictionary = RecipeBook.research(state, "oven", ["flour", "egg", "vanilla"])
	_expect(not bool(result.get("ok", false)), "near recipe should still fail at device L2")
	_expect(int((result.get("hint", {}) as Dictionary).get("level", 0)) == 2, "device L2 should advance a research hint by two levels")
	_expect(int(state.get_device_growth("oven").get("use_count", -1)) == 10, "failed research should not add an effective device use")


func _recipe_book_has_method(method_name: String) -> bool:
	var script: GDScript = load("res://scripts/recipe_book.gd") as GDScript
	for method_value: Variant in script.get_script_method_list():
		var method: Dictionary = method_value
		if str(method.get("name", "")) == method_name:
			return true
	return false


func _research_hint_view(state, device_id: String, material_ids: Array) -> Dictionary:
	var script: GDScript = load("res://scripts/recipe_book.gd") as GDScript
	var value: Variant = script.call("research_hint_view", state, device_id, material_ids)
	return value as Dictionary if value is Dictionary else {}


func _array_has(value: Variant, expected: String) -> bool:
	if not value is Array:
		return false
	for entry: Variant in value:
		if str(entry) == expected:
			return true
	return false


func _array_size(value: Variant) -> int:
	return (value as Array).size() if value is Array else 0


func _test_research_hint_ui() -> void:
	var view = MainScene.instantiate()
	view.set("save_path", TEST_SAVE_PATH)
	root.add_child(view)
	await process_frame

	var state = GameState.new_game()
	state.level = 2
	state.shop_level = 2
	state.research_hint_progress = {"sponge_cake": 2}
	state.latest_research_hint_recipe_id = "sponge_cake"
	for item_id in ["flour", "egg", "milk"]:
		state.add_ingredient(item_id, 2)
	state.add_recipe("butter_cookie")
	state.add_product("butter_cookie", 1)
	state.add_tool("farm_accelerator", 1)
	view.set("state", state)
	view.set("selected_research_tool_id", "oven")
	var selected_materials: Array[String] = ["flour", "egg", "milk"]
	view.set("selected_research_material_ids", selected_materials)
	_expect(state.get_ingredient_count("flour") == 2 and state.get_ingredient_count("egg") == 2 and state.get_ingredient_count("milk") == 2, "UI fixture should own selected materials")
	_expect(_array_size(view.get("selected_research_material_ids")) == 3, "UI fixture should assign three selected materials")
	view.call("_show_page", "research")
	await process_frame

	var page_description = view.get_node_or_null("GlobalOverlayLayer/OverlayFrame/OverlayModeStack/ResearchOverlay/PageDescription")
	var hint_panel = view.get_node_or_null("GlobalOverlayLayer/OverlayFrame/OverlayModeStack/ResearchOverlay/ResearchHintPanel")
	_expect(page_description is RichTextLabel, "research page should expose PageDescription")
	_expect(hint_panel == null, "research page should move ResearchHintPanel into the result dialog")
	if not page_description is RichTextLabel:
		view.queue_free()
		await process_frame
		return

	_expect(page_description.text.find("研发成功率") == -1, "research page should remove fake success rate")
	_expect(page_description.text.find("海绵杯蛋糕") == -1, "research page summary should not leak the migrated notebook target")
	_expect(page_description.text.find("接近度") == -1, "research page summary should not retain notebook match details")
	_expect(page_description.text.find("已选择 3 个材料") != -1, "research page summary should retain input guidance")

	view.call("_on_research_material_slot_pressed", 0)
	_expect(String(view.get("selected_inventory_tab")) == "all", "research material picker should open the complete inventory")
	var product_entry: Dictionary = {}
	for entry_value: Variant in view.call("_inventory_entries", "all"):
		if entry_value is Dictionary and String((entry_value as Dictionary).get("id", "")) == "butter_cookie":
			product_entry = entry_value as Dictionary
			break
	_expect(not product_entry.is_empty(), "research material picker fixture should expose stocked finished products")
	if not product_entry.is_empty():
		var product_cell: Button = null
		var product_key := String(view.call("_inventory_entry_key", product_entry))
		var tool_cell: Button = null
		for cell_value: Variant in view.get("inventory_grid").get_children():
			if not cell_value is Button:
				continue
			var cell := cell_value as Button
			var entry_key := String(cell.get_meta("inventory_key", ""))
			if entry_key == product_key:
				product_cell = cell
			elif entry_key == "tool:farm_accelerator":
				tool_cell = cell
		_expect(product_cell != null and not product_cell.disabled, "research material picker should enable a finished product")
		_expect(tool_cell != null and tool_cell.disabled, "research material picker should disable non-material inventory entries")
		if product_cell != null:
			product_cell.pressed.emit()
			_expect(String(view.get("selected_research_material_ids")[0]) == "butter_cookie", "finished product selection should fill the requested research slot")
			_expect(int(view.get("pending_research_material_slot_index")) == -1, "finished product selection should complete the pending research slot")
			var research_status_label := view.get_node("Root/StatusBar/StatusLabel") as Label
			_expect(research_status_label != null and research_status_label.text.find("黄油曲奇") != -1, "finished product selection should name the selected product")
			var research_grid := view.get_node("GlobalOverlayLayer/OverlayFrame/OverlayModeStack/ResearchOverlay/ResearchInputBar/InventoryGrid") as GridContainer
			var selected_slot := research_grid.get_child(0) as Button
			_expect(selected_slot != null and selected_slot.get_node_or_null("Icon") != null, "selected finished product should render a material icon")

	_expect(view.has_method("_research_hint_title_text"), "main view should expose notebook title formatting for the result dialog")
	_expect(view.has_method("_research_hint_body_text"), "main view should expose notebook body formatting for the result dialog")
	if not view.has_method("_research_hint_title_text") or not view.has_method("_research_hint_body_text"):
		view.queue_free()
		await process_frame
		return
	var level_two_hint := _research_hint_view(state, "oven", ["flour", "egg", "milk"])
	var level_two_title: String = str(view.call("_research_hint_title_text", level_two_hint))
	var level_two_body: String = str(view.call("_research_hint_body_text", level_two_hint))
	_expect(level_two_title.find("线索等级 2") != -1, "dialog notebook title should show saved level")
	_expect(level_two_body.find("正确设备：烤箱") != -1, "dialog level two notebook should show correct device")
	_expect(level_two_body.find("调味") != -1, "dialog level two notebook should show missing category")
	var complete_materials_body: String = str(view.call("_research_hint_body_text", {
		"level": 2,
		"matched_count": 3,
		"required_count": 3,
		"correct_device_id": "oven",
		"missing_categories": []
	}))
	_expect(complete_materials_body.find("材料已齐") != -1, "level two notebook should explain complete materials when only device is wrong")
	state.research_hint_progress["sponge_cake"] = 3
	var level_three_hint := _research_hint_view(state, "oven", ["flour", "egg", "milk"])
	var level_three_title: String = str(view.call("_research_hint_title_text", level_three_hint))
	var level_three_body: String = str(view.call("_research_hint_body_text", level_three_hint))
	_expect(level_three_title.find("完整线索") != -1, "level three dialog title should mark complete hint")
	_expect(level_three_body.find("白糖：缺少") != -1, "level three dialog notebook should name missing sugar")
	_expect(level_three_body.find("牛奶：选错") != -1, "level three dialog notebook should name extra milk, got: %s" % level_three_body)

	var saved_title := level_three_title
	var unrelated_materials: Array[String] = ["coffee", "mint"]
	var unrelated_hint := _research_hint_view(state, "oven", unrelated_materials)
	var unrelated_title: String = str(view.call("_research_hint_title_text", unrelated_hint))
	var unrelated_body: String = str(view.call("_research_hint_body_text", unrelated_hint))
	_expect(unrelated_title == saved_title, "unrelated selection should not replace latest valid dialog notebook target")
	_expect(unrelated_body.find("白糖") != -1, "latest complete notebook should remain available for the result dialog after unrelated selection")

	view.call("_set_status", "研发线索提升至 3 级。")
	view.set("save_path", "res://tests/missing_hint_save_dir/save.json")
	var save_value: Variant = view.call("_save_game")
	var status_label: Label = view.get_node("Root/StatusBar/StatusLabel")
	_expect(save_value == false, "invalid save directory should report failure")
	_expect(status_label.text.find("研发线索提升至 3 级") != -1, "save failure should preserve research feedback")
	_expect(status_label.text.find("存档失败") != -1, "save failure should append persistence warning")

	view.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("RESEARCH_PROGRESSIVE_HINTS_SELF_CHECK: PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _cleanup_test_save() -> void:
	for path in [TEST_SAVE_PATH, "%s.tmp" % TEST_SAVE_PATH]:
		var absolute_path := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(absolute_path):
			DirAccess.remove_absolute(absolute_path)
