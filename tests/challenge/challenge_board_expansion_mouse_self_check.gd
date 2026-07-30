extends SceneTree

const MAIN_PATH := "res://scenes/challenge/challenge_main.tscn"

var _failures: Array[String] = []
var _save_path := OS.get_temp_dir().path_join("project_rest_two_expansion_mouse_self_check.json")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	_cleanup()
	var packed = load(MAIN_PATH)
	var main = packed.instantiate()
	main.save_path = _save_path
	root.add_child(main)
	await process_frame
	await process_frame
	main.start_new_run_for_test(73)
	await process_frame
	await process_frame
	var overlay: Control = main.get_node("TutorialLayer/TutorialOverlay")
	if overlay.visible:
		overlay.hide_step()

	var meta: Dictionary = main._save_data.get("meta", {})
	meta["expansion_tickets"] = 4
	main._save_data["meta"] = meta
	main._show_preparation()
	await process_frame
	await process_frame

	var preparation: Control = main.get_node(
		"Root/PageHost/PreparationHost/PreparationView"
	)
	var entry: Button = preparation.get_node(
		"MainColumns/RightSidebar/ExpansionButton"
	)
	await _click(entry.get_global_rect().get_center())
	await process_frame
	var panel: Control = preparation.get_node(
		"MainColumns/RightSidebar/ExpansionPanel"
	)
	_expect(panel.visible, "expansion entry click must open the shop panel")

	var l4_button: Button = panel.get_node("Content/ProductGrid/Product4")
	await _click(l4_button.get_global_rect().get_center())
	await process_frame
	var board: Control = preparation.board()
	var grid: GridContainer = board.get_node("BoardFrame/BoardGrid")
	var target: Control = grid.get_child(2 * 14 + 3)
	await _click(target.get_global_rect().get_center())
	await process_frame
	await process_frame

	var next_meta: Dictionary = main._save_data.get("meta", {})
	_expect(
		int(next_meta.get("expansion_tickets", -1)) == 0,
		"L 4 placement must charge four expansion tickets"
	)
	_expect(
		(
			(next_meta.get("board_expansion", {}) as Dictionary)
			.get("unlocked_cells", []) as Array
		).size() == 20,
		"L 4 placement must unlock four connected cells"
	)
	_expect(
		not panel.visible,
		"successful purchase must return to preparation and refresh the board"
	)
	main.queue_free()
	await process_frame
	_cleanup()
	if _failures.is_empty():
		print("PASS challenge_board_expansion_mouse_self_check")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _click(position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	Input.parse_input_event(motion)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = position
	press.global_position = position
	press.pressed = true
	Input.parse_input_event(press)
	await process_frame
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = position
	release.global_position = position
	release.pressed = false
	Input.parse_input_event(release)
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition and not _failures.has(message):
		_failures.append(message)


func _cleanup() -> void:
	for suffix in ["", ".tmp", ".previous", ".broken", ".broken.previous"]:
		var path: String = _save_path + String(suffix)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
