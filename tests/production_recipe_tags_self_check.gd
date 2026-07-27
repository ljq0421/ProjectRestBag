extends SceneTree

const GameState := preload("res://scripts/game_state.gd")
const MainScene := preload("res://scenes/Main.tscn")
const TEST_SAVE_PATH := "res://tests/production_recipe_tags_self_check.save.json"

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var view = MainScene.instantiate()
	view.set("save_path", TEST_SAVE_PATH)
	root.add_child(view)
	await process_frame

	var state = GameState.new_game()
	state.tutorial_guide_skipped = true
	state.level = 2
	state.add_recipe("rice_milk_drink")
	state.unlock_device("round_pot")
	state.unlock_device("grinder")
	state.unlock_ingredient_process("rice_flour")
	state.add_ingredient("rice", 3)
	state.add_ingredient("spring_water", 2)
	view.set("state", state)

	var craftable_entries: Array = view.call("_production_picker_entries", "craftable")
	var rice_entry := _entry_for_id(craftable_entries, "rice_milk_drink")
	_expect(not rice_entry.is_empty(), "craftable picker should include the unlocked rice milk drink")
	if not rice_entry.is_empty():
		var search_haystack := String(rice_entry.get("search_haystack", ""))
		_expect(search_haystack.find("经典") >= 0, "recipe search should include the classic flavor tag")
		_expect(search_haystack.find("清爽") >= 0, "recipe search should include the refreshing flavor tag")
		for unwanted_text in ["今日需求", "匹配", "橱窗"]:
			_expect(search_haystack.find(unwanted_text) == -1, "recipe search should not include operational copy: %s" % unwanted_text)

	var process_entry := _entry_for_id(craftable_entries, "rice_flour_process")
	_expect(not process_entry.is_empty(), "craftable picker should include available rice flour processing")
	if not process_entry.is_empty():
		var process_search := String(process_entry.get("search_haystack", ""))
		_expect(process_search.find("大米粉") >= 0, "processing search should include the output ingredient name")
		_expect(process_search.find("大米") >= 0, "processing search should include its source material")
		_expect(process_search.find("经典") == -1, "processing entries should not inherit recipe flavor tags")

	view.queue_free()
	await process_frame
	_cleanup_test_save()
	_finish()


func _entry_for_id(entries: Array, item_id: String) -> Dictionary:
	for entry_value: Variant in entries:
		if entry_value is Dictionary and String((entry_value as Dictionary).get("id", "")) == item_id:
			return entry_value as Dictionary
	return {}


func _cleanup_test_save() -> void:
	var path := ProjectSettings.globalize_path(TEST_SAVE_PATH)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("PRODUCTION_RECIPE_TAGS_SELF_CHECK: PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
