extends SceneTree

const MAIN_PATH := "res://scenes/challenge/challenge_main.tscn"

var _failures: Array[String] = []
var _save_path := OS.get_temp_dir().path_join("project_rest_two_tutorial_input_self_check.json")
var _drag_was_active := false


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
	main.start_new_run_for_test(42)
	await process_frame
	await process_frame
	await process_frame

	var overlay: Control = main.get_node("TutorialLayer/TutorialOverlay")
	var preparation: Control = main.get_node("Root/PageHost/PreparationHost/PreparationView")
	var board: Control = preparation.get_node("MainColumns/ChallengeBoard")
	var pudding_card: Control = _find_supply_card(preparation, "milk_pudding")
	var observed := {"source_drag_started": false}
	_expect(pudding_card != null, "dynamic supply strip should contain milk pudding")
	if pudding_card == null:
		main.queue_free()
		await process_frame
		_finish()
		return
	pudding_card.recipe_drag_started.connect(
		func(_recipe_id: String) -> void: observed["source_drag_started"] = true
	)
	_expect(main.get_tutorial_state_for_test()["step_id"] == "boss_brief", "new input path starts at boss brief")
	_expect(overlay.visible, "root overlay is visible before input")
	_expect(overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE, "root overlay ignores pointer input")

	var confirm: Control = overlay.get_node("HintHost/HintPanel/Margin/Content/ActionRow/ConfirmButton")
	_expect(confirm.visible, "boss brief exposes a real confirm button")
	await _click(_viewport_center(confirm))
	_expect(main.get_tutorial_state_for_test()["step_id"] == "place_recipe", "real confirm press advances boss brief")
	_expect(overlay.visible, "overlay remains visible for placement")
	var supply_scroll: ScrollContainer = preparation.get_node(
		"MainColumns/RecipeLibrary/Content/SupplyScroll"
	)
	supply_scroll.ensure_control_visible(pudding_card)
	await process_frame
	await process_frame

	var board_cells: Array = board.get_node("BoardFrame/BoardGrid").get_children()
	_expect(not board_cells.is_empty(), "board exposes real drop cells")
	if not board_cells.is_empty():
		await _drag(
			_viewport_center(pudding_card),
			_viewport_center(board_cells[2 * 14 + 5])
		)
	await process_frame
	await process_frame
	var draft: Dictionary = board.get_draft()
	_expect(bool(observed["source_drag_started"]), "mouse drag reaches the milk pudding card drag source")
	_expect(_drag_was_active, "engine enters a real GUI drag after source motion")
	_expect(
		(draft.get("placements", []) as Array).any(func(placement: Dictionary) -> bool: return String(placement.get("recipe_id", "")) == "milk_pudding"),
		"mouse press/motion/release places milk pudding through the board drop handler"
	)
	_expect(main.get_tutorial_state_for_test()["step_id"] == "rotate_recipe", "real drag advances to rotation")
	_expect(overlay.visible, "overlay stays visible while the successful drag passes through it")

	var occupied_cell: Control = null
	for cell in board_cells:
		if not String(cell.get_meta("instance_id", "")).is_empty():
			occupied_cell = cell
			break
	_expect(occupied_cell != null, "successful real drag produces an occupied board cell")
	if occupied_cell != null:
		await _right_click(_viewport_center(occupied_cell))
	await process_frame
	_expect(main.get_tutorial_state_for_test()["step_id"] == "read_risk", "real right-click rotates pudding and advances")

	main.queue_free()
	await process_frame
	_finish()


func _find_supply_card(preparation: Control, recipe_id: String) -> Control:
	for card in preparation.supply_cards():
		if String(card.get_meta("recipe_id", "")) == recipe_id:
			return card
	return null


func _click(position: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.position = position
		event.global_position = position
		Input.parse_input_event(event)
		await process_frame


func _viewport_center(control: Control) -> Vector2:
	return control.get_screen_transform() * (control.size * 0.5)


func _drag(from: Vector2, to: Vector2) -> void:
	var hover := InputEventMouseMotion.new()
	hover.position = from
	hover.global_position = from
	Input.parse_input_event(hover)
	await process_frame

	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.button_mask = MOUSE_BUTTON_MASK_LEFT
	press.position = from
	press.global_position = from
	Input.parse_input_event(press)
	await process_frame

	var start_motion := InputEventMouseMotion.new()
	start_motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	start_motion.position = from + Vector2(24, 0)
	start_motion.global_position = start_motion.position
	start_motion.relative = Vector2(24, 0)
	start_motion.screen_relative = start_motion.relative
	Input.parse_input_event(start_motion)
	await process_frame
	_drag_was_active = root.gui_is_dragging()

	var drag_motion := InputEventMouseMotion.new()
	drag_motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	drag_motion.position = to
	drag_motion.global_position = to
	drag_motion.relative = to - start_motion.position
	drag_motion.screen_relative = drag_motion.relative
	Input.parse_input_event(drag_motion)
	await process_frame

	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.button_mask = 0
	release.position = to
	release.global_position = to
	Input.parse_input_event(release)
	await process_frame


func _right_click(position: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_RIGHT
		event.pressed = pressed
		event.button_mask = MOUSE_BUTTON_MASK_RIGHT if pressed else 0
		event.position = position
		event.global_position = position
		Input.parse_input_event(event)
		await process_frame
	await process_frame


func _cleanup() -> void:
	for suffix in ["", ".tmp", ".previous", ".broken", ".broken.previous"]:
		var path: String = _save_path + String(suffix)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _expect(condition: bool, message: String) -> void:
	if not condition and not _failures.has(message):
		_failures.append(message)


func _finish() -> void:
	_cleanup()
	if _failures.is_empty():
		print("CHALLENGE_TUTORIAL_INPUT_SELF_CHECK_PASS")
		quit(0)
		return
	for message in _failures:
		push_error(message)
	quit(1)
