extends SceneTree

const MAIN_PATH := "res://scenes/challenge/challenge_main.tscn"

var _failures: Array[String] = []
var _save_path := OS.get_temp_dir().path_join("project_rest_two_menu_mouse_self_check.json")
var _clicks := 0


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
	var menu_button: Button = main.get_node(
		"Root/PageHost/HubHost/HubView/Content/Actions/MenuButton"
	)
	await _click(_center(menu_button))
	_expect(main._page == "menu", "hub menu button should open the menu editor through a real click")
	var menu_view: Control = main.get_node("Root/PageHost/MenuHost/MenuView")
	for recipe_id in ["butter_cookie", "strawberry_jelly"]:
		var button := _collection_button(menu_view, recipe_id)
		_expect(button != null, "selected starter should appear in collection: %s" % recipe_id)
		if button != null:
			await _click(_center(button))
			await process_frame
	_expect(menu_view.selected_recipe_ids().size() == 4, "two real clicks should reduce default menu from six to four")
	var save_button: Button = menu_view.get_node(
		"Content/Body/MenuPanel/Menu/Actions/SaveButton"
	)
	_expect(not save_button.disabled, "four-recipe lower bound should remain saveable")
	await _click(_center(save_button))
	_expect(main._page == "hub", "saving menu through mouse should return to hub")
	var start_button: Button = main.get_node(
		"Root/PageHost/HubHost/HubView/Content/Actions/StartButton"
	)
	await _click(_center(start_button))
	_expect(main._page == "preparation", "mouse should start a run from the saved menu")
	var snapshot: Dictionary = main.run_state.get("permanent_pool_snapshot", {})
	_expect((snapshot.get("recipe_ids", []) as Array).size() == 4, "run should freeze the four-recipe menu")
	main.queue_free()
	_cleanup()
	_finish()


func _collection_button(menu_view: Control, recipe_id: String) -> Button:
	var grid = menu_view.get_node(
		"Content/Body/CollectionPanel/Collection/CollectionScroll/CollectionGrid"
	)
	for child in grid.get_children():
		if child is Button and String(child.get_meta("recipe_id", "")) == recipe_id:
			return child
	return null


func _click(position: Vector2) -> void:
	var hover := InputEventMouseMotion.new()
	hover.position = position
	hover.global_position = position
	Input.parse_input_event(hover)
	await process_frame
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.position = position
		event.global_position = position
		Input.parse_input_event(event)
		await process_frame
	_clicks += 1


func _center(control: Control) -> Vector2:
	return control.get_screen_transform() * (control.size * 0.5)


func _cleanup() -> void:
	for suffix in ["", ".tmp", ".previous", ".broken", ".broken.previous"]:
		if FileAccess.file_exists(_save_path + suffix):
			DirAccess.remove_absolute(_save_path + suffix)


func _expect(condition: bool, message: String) -> void:
	if not condition and not _failures.has(message):
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("CHALLENGE_MENU_MOUSE_SELF_CHECK_PASS clicks=%d" % _clicks)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
