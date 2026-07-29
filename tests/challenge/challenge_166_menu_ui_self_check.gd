extends SceneTree

const MAIN_PATH := "res://scenes/challenge/challenge_main.tscn"
const MAX_BIND_MS := 2000

var _failures: Array[String] = []
var _save_path := OS.get_temp_dir().path_join("project_rest_two_166_menu_ui_self_check.json")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	_cleanup()
	var main = load(MAIN_PATH).instantiate()
	main.save_path = _save_path
	root.add_child(main)
	await process_frame
	await process_frame
	var save_data: Dictionary = main._save_data.duplicate(true)
	var meta: Dictionary = save_data.get("meta", {}).duplicate(true)
	var all_ids: Array[String] = main._session.available_recipe_ids(
		{"meta": {"unlocked_recipe_ids": main._session.recipe_definitions().keys()}}
	)
	meta["unlocked_recipe_ids"] = all_ids.duplicate()
	save_data["meta"] = meta
	main._adopt({"save_data": save_data})
	var started_at := Time.get_ticks_msec()
	main._show_menu()
	await process_frame
	var elapsed_ms := Time.get_ticks_msec() - started_at
	var menu_view: Control = main.get_node("Root/PageHost/MenuHost/MenuView")
	var grid: GridContainer = menu_view.get_node(
		"Content/Body/CollectionPanel/Collection/CollectionScroll/CollectionGrid"
	)
	_expect(grid.get_child_count() == 166, "complete collection should render 166 recipe buttons")
	_expect(elapsed_ms <= MAX_BIND_MS, "166-recipe menu should bind within %d ms; got %d" % [
		MAX_BIND_MS,
		elapsed_ms
	])
	var search: LineEdit = menu_view.get_node(
		"Content/Body/CollectionPanel/Collection/Filters/Search"
	)
	search.text = "butter_cookie"
	search.text_changed.emit(search.text)
	await process_frame
	await process_frame
	var filtered_count := _visible_button_count(grid)
	_expect(
		filtered_count > 0 and filtered_count < 166,
		"recipe ID search should narrow the collection; got %d" % filtered_count
	)
	_expect(_has_recipe_button(grid, "butter_cookie"), "search results should include exact recipe ID")
	search.text = ""
	search.text_changed.emit(search.text)
	await process_frame
	await process_frame
	_expect(_visible_button_count(grid) == 166, "clearing search should restore the complete collection")
	main.queue_free()
	await process_frame
	_cleanup()
	_finish(elapsed_ms)


func _cleanup() -> void:
	for suffix in ["", ".tmp", ".previous", ".broken", ".broken.previous"]:
		var path: String = _save_path + String(suffix)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _expect(condition: bool, message: String) -> void:
	if not condition and not _failures.has(message):
		_failures.append(message)


func _visible_button_count(grid: GridContainer) -> int:
	var count := 0
	for child in grid.get_children():
		if child is Button and not child.is_queued_for_deletion():
			count += 1
	return count


func _has_recipe_button(grid: GridContainer, recipe_id: String) -> bool:
	for child in grid.get_children():
		if (
			child is Button
			and not child.is_queued_for_deletion()
			and String(child.get_meta("recipe_id", "")) == recipe_id
		):
			return true
	return false


func _finish(elapsed_ms: int) -> void:
	if _failures.is_empty():
		print("CHALLENGE_166_MENU_UI_SELF_CHECK_PASS bind_ms=%d" % elapsed_ms)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
