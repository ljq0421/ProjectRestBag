extends SceneTree

const MAIN_PATH := "res://scenes/challenge/challenge_main.tscn"
const SAVE_SERVICE_PATH := "res://scripts/challenge/challenge_save_service.gd"

var _failures: Array[String] = []
var _save_path := OS.get_temp_dir().path_join("project_rest_two_endless_mouse_self_check.json")
var _mouse_clicks := 0
var _mouse_drags := 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	_cleanup()
	var save_service = load(SAVE_SERVICE_PATH)
	var unlocked: Dictionary = save_service.empty_save()
	unlocked["meta"]["endless_records"] = {"unlocked": true, "best_floor": 12, "best_snapshot": {}}
	var prepared: Dictionary = save_service.save_to_path(_save_path, unlocked)
	_expect(bool(prepared.get("ok", false)), "mouse test should prepare an unlocked endless save")
	var packed: PackedScene = load(MAIN_PATH)
	_expect(packed != null, "challenge main scene should load")
	if packed == null:
		_finish()
		return
	var main = packed.instantiate()
	main.save_path = _save_path
	root.add_child(main)
	await process_frame
	await process_frame
	var endless_button: Button = main.get_node("Root/PageHost/HubHost/HubView/Content/Actions/EndlessButton")
	_expect(endless_button.visible and not endless_button.disabled, "unlocked hub should expose endless entry")
	await _click(_viewport_center(endless_button))
	await process_frame
	await process_frame
	_expect(main._page == "preparation", "mouse click should enter endless preparation")
	_expect(String(main.run_state.get("mode", "")) == "endless", "mouse-started run should be endless")
	var overlay: Control = main.get_node("TutorialLayer/TutorialOverlay")
	if overlay.visible:
		var dismiss_button: Button = overlay.get_node("HintHost/HintPanel/Margin/Content/ActionRow/DismissButton")
		await _click(_viewport_center(dismiss_button))
		await process_frame
	var encounter: Dictionary = main._session.current_encounter(main._save_data)
	var preparation: Control = main.get_node("Root/PageHost/PreparationHost/PreparationView")
	var arranged := await _arrange_draft_with_mouse(preparation, encounter.get("validation_draft", {}))
	_expect(arranged, "floor 1 should be assembled with real mouse drags")
	_expect(preparation.board().is_current_draft_valid(), "mouse-built endless draft should validate")
	var battle_button: Button = preparation.get_node("BattleButton")
	await _click(_viewport_center(battle_button))
	await process_frame
	_expect(main._page == "battle", "mouse click should start automatic endless battle")
	main.advance_battle_for_test(int(encounter.get("duration_ms", 30000)))
	await process_frame
	await process_frame
	await process_frame
	_expect(String(main.battle_state.get("outcome", "")) == "victory", "floor 1 validation draft should win")
	var settlement = main.get_node("SettlementDialog")
	_expect(settlement.visible, "automatic endless battle should open report")
	var back_button: Button = settlement.get_node("Margin/Content/ActionRow/BackButton")
	await _click(_viewport_center(back_button))
	await process_frame
	await process_frame
	_expect(main._page == "upgrade", "endless victory should open upgrade choice")
	var offer: Dictionary = main.run_state.get("pending_upgrade_offer", {})
	var candidate_index := _universal_candidate_index(offer)
	_expect(candidate_index >= 0, "endless offer should contain a universal choice")
	if candidate_index >= 0:
		var candidate: Button = main.get_node("Root/PageHost/UpgradeHost/UpgradeSelectView/Content/Candidates/Candidate%d" % candidate_index)
		await _click(_viewport_center(candidate))
		await process_frame
		await process_frame
		_expect(main._page == "preparation", "mouse upgrade should continue endless climb")
		_expect(int(main.run_state.get("stage_index", -1)) == 1, "mouse path should reach floor 2")
		_expect(main._session.current_encounter(main._save_data).get("floor_number") == 2, "floor 2 encounter should be generated")
	main.queue_free()
	await process_frame
	_cleanup()
	_finish()


func _arrange_draft_with_mouse(preparation: Control, target_draft: Dictionary) -> bool:
	var board: Control = preparation.board()
	for placement_value in target_draft.get("placements", []):
		if not placement_value is Dictionary:
			return false
		var placement: Dictionary = placement_value
		var recipe_id := String(placement.get("recipe_id", ""))
		var card := _find_supply_card(preparation, recipe_id)
		var origin: Array = placement.get("origin", [])
		if card == null or origin.size() != 2:
			return false
		var cell := _board_cell(board, int(origin[0]), int(origin[1]))
		if cell == null:
			return false
		var before_count := (board.get_draft().get("placements", []) as Array).size()
		await _drag(_viewport_center(card), _viewport_center(cell))
		await process_frame
		if (board.get_draft().get("placements", []) as Array).size() != before_count + 1:
			return false
	return true


func _universal_candidate_index(offer: Dictionary) -> int:
	var candidates: Array = offer.get("candidates", [])
	for index in range(candidates.size()):
		if candidates[index] is Dictionary and String(candidates[index].get("category", "")) == "universal":
			return index
	return -1


func _find_supply_card(preparation: Control, recipe_id: String) -> Control:
	for card in preparation.supply_cards():
		if String(card.get("recipe_id")) == recipe_id:
			return card
	return null


func _board_cell(board: Control, row: int, column: int) -> Control:
	var path := "BoardFrame/BoardGrid/Cell_%d_%d" % [row, column]
	return board.get_node(path) if board.has_node(path) else null


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
	_mouse_clicks += 1


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
	_expect(root.gui_is_dragging(), "engine should enter real GUI drag state")
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
	_mouse_drags += 1


func _viewport_center(control: Control) -> Vector2:
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
		print("CHALLENGE_ENDLESS_MOUSE_SELF_CHECK_PASS floors=2 clicks=%d drags=%d" % [_mouse_clicks, _mouse_drags])
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
