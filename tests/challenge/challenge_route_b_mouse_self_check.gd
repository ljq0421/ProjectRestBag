extends SceneTree

const MAIN_PATH := "res://scenes/challenge/challenge_main.tscn"
const ROUTE_B := "flavor_texture_route"

var _failures: Array[String] = []
var _save_path := OS.get_temp_dir().path_join("project_rest_two_route_b_mouse_self_check.json")
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
	var save_data: Dictionary = main._save_data.duplicate(true)
	var meta: Dictionary = save_data.get("meta", {}).duplicate(true)
	meta["route_first_clear_ids"] = ["standard_short_chain"]
	meta["unlocked_route_ids"] = ["standard_short_chain", ROUTE_B]
	save_data["meta"] = meta
	main._adopt({"save_data": save_data})
	main._show_hub()
	await process_frame

	var selector: OptionButton = main.get_node(
		"Root/PageHost/HubHost/HubView/Content/RouteRow/RouteSelector"
	)
	_expect(selector.item_count == 3, "hub should expose all three standard routes")
	await _click(_center(selector))
	await process_frame
	var popup := selector.get_popup()
	_expect(popup.visible, "mouse click should open the route selector popup")
	if popup.visible:
		var item_position := Vector2(popup.position) + Vector2(
			float(popup.size.x) * 0.5,
			float(popup.size.y) * 1.5 / float(selector.item_count)
		)
		await _click(item_position)
		await process_frame
	_expect(selector.selected == 1, "mouse should select route B")
	_expect(
		String(selector.get_item_metadata(selector.selected)) == ROUTE_B,
		"selected option metadata should identify route B"
	)

	var start_button: Button = main.get_node(
		"Root/PageHost/HubHost/HubView/Content/Actions/StartButton"
	)
	_expect(not start_button.disabled, "unlocked route B should be startable")
	await _click(_center(start_button))
	await process_frame
	await process_frame
	_expect(main._page == "preparation", "route B mouse start should open preparation")
	_expect(String(main.run_state.get("route_id", "")) == ROUTE_B, "run snapshot should freeze route B")
	_expect(
		(main.run_state.get("encounter_instances", []) as Array).size() == 5,
		"route B should contain five executable encounters"
	)
	main.queue_free()
	await process_frame
	_cleanup()
	_finish()


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
		var path: String = _save_path + String(suffix)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _expect(condition: bool, message: String) -> void:
	if not condition and not _failures.has(message):
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("CHALLENGE_ROUTE_B_MOUSE_SELF_CHECK_PASS clicks=%d" % _clicks)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
