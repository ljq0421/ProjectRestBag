extends SceneTree

const MAIN_PATH := "res://scenes/challenge/challenge_main.tscn"
const EXPECTED_STAGES := 5

var _failures: Array[String] = []
var _save_path := OS.get_temp_dir().path_join("project_rest_two_stage3_mouse_self_check.json")
var _mouse_clicks := 0
var _mouse_drags := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	_cleanup()
	_expect(FileAccess.file_exists(MAIN_PATH), "challenge main scene should exist")
	var packed = load(MAIN_PATH)
	_expect(packed != null, "challenge main scene should load")
	if packed == null:
		_finish()
		return
	var main = packed.instantiate()
	main.save_path = _save_path
	root.add_child(main)
	await process_frame
	await process_frame
	var hub_start: Control = main.get_node("Root/PageHost/HubHost/HubView/Content/Actions/StartButton")
	await _click(_viewport_center(hub_start))
	await process_frame
	await process_frame
	_expect(main._page == "preparation", "mouse click should start a new short chain")
	var overlay: Control = main.get_node("TutorialLayer/TutorialOverlay")
	if overlay.visible:
		var dismiss_button: Button = overlay.get_node("HintHost/HintPanel/Margin/Content/ActionRow/DismissButton")
		await _click(_viewport_center(dismiss_button))
		await process_frame
	_expect(int(main.run_state.get("stage_index", -1)) == 0, "new short chain should start at stage zero")
	_expect(int(main.run_state.get("confidence", 0)) == 2, "new short chain should start with two confidence")
	for stage_index in range(EXPECTED_STAGES):
		if not await _play_stage_with_mouse(main, stage_index):
			break
	if _failures.is_empty():
		await _complete_meta_loop_with_mouse(main)
	main.queue_free()
	await process_frame
	_cleanup()
	_finish()

func _play_stage_with_mouse(main: Control, stage_index: int) -> bool:
	_expect(main._page == "preparation", "stage %d should begin on preparation" % stage_index)
	if main._page != "preparation":
		return false
	var encounter: Dictionary = main._session.current_encounter(main._save_data)
	_expect(not encounter.is_empty(), "stage %d should expose its encounter" % stage_index)
	_expect(int(main.run_state.get("stage_index", -1)) == stage_index, "stage %d identity should match" % stage_index)
	if encounter.is_empty():
		return false
	var preparation: Control = main.get_node("Root/PageHost/PreparationHost/PreparationView")
	var arranged := await _arrange_draft_with_mouse(preparation, encounter.get("validation_draft", {}))
	_expect(arranged, "stage %d validation draft should be assembled only through mouse drag" % stage_index)
	if not arranged:
		return false
	_expect(preparation.board().is_current_draft_valid(), "stage %d mouse draft should validate" % stage_index)
	var battle_button: Button = preparation.get_node("BattleButton")
	_expect(not battle_button.disabled, "stage %d battle button should enable after mouse arrangement" % stage_index)
	if battle_button.disabled:
		return false
	await _click(_viewport_center(battle_button))
	await process_frame
	_expect(main._page == "battle", "stage %d mouse click should open automatic battle" % stage_index)
	if main._page != "battle":
		return false
	main.advance_battle_for_test(int(encounter.get("duration_ms", 30000)))
	await process_frame
	await process_frame
	await process_frame
	var settlement = main.get_node("SettlementDialog")
	_expect(settlement.visible, "stage %d automatic battle should open its report" % stage_index)
	_expect(String(main.battle_state.get("outcome", "")) == "victory", "stage %d validation draft should win" % stage_index)
	if not settlement.visible or String(main.battle_state.get("outcome", "")) != "victory":
		return false
	var report_back: Button = settlement.get_node("Margin/Content/ActionRow/BackButton")
	await _click(_viewport_center(report_back))
	await process_frame
	await process_frame
	if stage_index < EXPECTED_STAGES - 1:
		_expect(main._page == "upgrade", "stage %d victory should open upgrade choice" % stage_index)
		if main._page != "upgrade":
			return false
		var offer: Dictionary = main.run_state.get("pending_upgrade_offer", {})
		var universal_index := _universal_candidate_index(offer)
		_expect(universal_index >= 0, "stage %d offer should contain a universal candidate" % stage_index)
		if universal_index < 0:
			return false
		var candidate: Button = main.get_node("Root/PageHost/UpgradeHost/UpgradeSelectView/Content/Candidates/Candidate%d" % universal_index)
		await _click(_viewport_center(candidate))
		await process_frame
		await process_frame
		_expect(main._page == "preparation", "stage %d mouse upgrade choice should reach next preparation" % stage_index)
		_expect(int(main.run_state.get("stage_index", -1)) == stage_index + 1, "stage %d upgrade should advance one stage" % stage_index)
		return main._page == "preparation"
	_expect(main._page == "summary", "final boss report should open run summary")
	_expect(String(main.run_state.get("phase", "")) == "run_complete", "fifth victory should complete the run")
	return main._page == "summary"

func _complete_meta_loop_with_mouse(main: Control) -> void:
	var summary: Control = main.get_node("Root/PageHost/SummaryHost/RunSummaryView")
	var reward_button: Button = summary.get_node("Content/Actions/RewardButton")
	_expect(reward_button.visible, "completed run should expose research reward")
	await _click(_viewport_center(reward_button))
	await process_frame
	await process_frame
	_expect(int(main._save_data.get("meta", {}).get("research_points", 0)) == 3, "mouse reward claim should grant exactly three research points")
	var return_button: Button = summary.get_node("Content/Actions/ReturnButton")
	_expect(not return_button.disabled, "rewarded run should allow returning to hub")
	await _click(_viewport_center(return_button))
	await process_frame
	await process_frame
	_expect(main._page == "hub", "mouse return should reach hub")
	var research_button: Button = main.get_node("Root/PageHost/HubHost/HubView/Content/Actions/ResearchButton")
	await _click(_viewport_center(research_button))
	await process_frame
	await process_frame
	_expect(main._page == "research", "mouse click should open research tree")
	var research_view: Control = main.get_node("Root/PageHost/ResearchHost/ResearchView")
	var unlock_button := _first_enabled_research_button(
		research_view.get_node("Content/Branches/NodePanel/Content/NodeScroll/NodeList")
	)
	_expect(unlock_button != null, "three points and boss reveals should expose an unlockable recipe node")
	if unlock_button == null:
		return
	await _click(_viewport_center(unlock_button))
	await process_frame
	await process_frame
	var unlocked_ids: Array = main._save_data.get("meta", {}).get("unlocked_recipe_ids", [])
	_expect(unlocked_ids.size() == 7, "mouse research purchase should retain six starters plus one unlocked recipe; unlocked=%s" % [unlocked_ids])
	_expect(int(main._save_data.get("meta", {}).get("research_points", -1)) == 0, "research purchase should spend three points")
	var back_button: Button = research_view.get_node("Content/BackButton")
	await _click(_viewport_center(back_button))
	await process_frame
	await process_frame
	_expect(main._page == "hub", "research back button should return to hub")
	var researched_recipe_id := ""
	for recipe_id in unlocked_ids:
		if not (main._save_data.get("meta", {}).get("active_menu_recipe_ids", []) as Array).has(recipe_id):
			researched_recipe_id = String(recipe_id)
			break
	_expect(not researched_recipe_id.is_empty(), "new research recipe should enter collection without auto-changing the menu")
	var menu_button: Button = main.get_node("Root/PageHost/HubHost/HubView/Content/Actions/MenuButton")
	await _click(_viewport_center(menu_button))
	await process_frame
	await process_frame
	_expect(main._page == "menu", "mouse click should open the menu editor")
	var menu_view: Control = main.get_node("Root/PageHost/MenuHost/MenuView")
	var collection_button := _find_menu_recipe_button(menu_view, researched_recipe_id)
	_expect(collection_button != null, "newly researched recipe should appear in the permanent collection")
	if collection_button == null:
		return
	await _click(_viewport_center(collection_button))
	await process_frame
	var save_menu_button: Button = menu_view.get_node("Content/Body/MenuPanel/Menu/Actions/SaveButton")
	_expect(not save_menu_button.disabled, "seven-recipe menu should be valid")
	await _click(_viewport_center(save_menu_button))
	await process_frame
	await process_frame
	_expect(main._page == "hub", "saving the menu should return to the hub")
	var start_button: Button = main.get_node("Root/PageHost/HubHost/HubView/Content/Actions/StartButton")
	await _click(_viewport_center(start_button))
	await process_frame
	await process_frame
	_expect(main._page == "preparation", "mouse should start the post-research run")
	var supply_count: int = main.get_node(
		"Root/PageHost/PreparationHost/PreparationView"
	).supply_cards().size()
	_expect(supply_count == 7, "next run should expose six starters plus the researched recipe")

func _arrange_draft_with_mouse(preparation: Control, target_draft: Dictionary) -> bool:
	var board: Control = preparation.board()
	while not (board.get_draft().get("placements", []) as Array).is_empty():
		var occupied := _first_occupied_cell(board)
		if occupied == null:
			_fail("board draft contains placements but no occupied cell")
			return false
		var before_count := (board.get_draft().get("placements", []) as Array).size()
		await _drag(_viewport_center(occupied), _viewport_center(preparation.get_node("MainColumns/BossBrief")))
		await process_frame
		var after_count := (board.get_draft().get("placements", []) as Array).size()
		if after_count != before_count - 1:
			_fail("mouse drag outside board should remove exactly one placement")
			return false
	var target_placements: Array = target_draft.get("placements", [])
	for placement_value in target_placements:
		if not placement_value is Dictionary:
			_fail("validation draft placement should be a dictionary")
			return false
		var placement: Dictionary = placement_value
		var recipe_id := String(placement.get("recipe_id", ""))
		var card := _find_supply_card(preparation, recipe_id)
		if card == null:
			_fail("supply strip should contain %s" % recipe_id)
			return false
		var origin: Array = placement.get("origin", [])
		if origin.size() != 2:
			_fail("validation placement %s should have a two-value origin" % recipe_id)
			return false
		var cell := _board_cell(board, int(origin[0]), int(origin[1]))
		if cell == null:
			_fail("validation placement %s should target a real board cell" % recipe_id)
			return false
		var before_count := (board.get_draft().get("placements", []) as Array).size()
		await _drag(_viewport_center(card), _viewport_center(cell))
		await process_frame
		var after_count := (board.get_draft().get("placements", []) as Array).size()
		if after_count != before_count + 1:
			_fail("mouse drag should place %s at %s; draft=%s; risk=%s" % [recipe_id, origin, board.get_draft(), board.get_node("RiskLabel").text])
			return false
	return (board.get_draft().get("placements", []) as Array).size() == target_placements.size()

func _complete_tutorial_precondition(main: Control) -> void:
	var tutorial: Dictionary = main._tutorial_progress.default_state()
	tutorial["status"] = "completed"
	tutorial["current_step"] = "complete"
	tutorial["completed_step_ids"] = main._tutorial_progress.STEPS.duplicate()
	main._adopt(main._session.update_onboarding(main._save_data, tutorial))
	main._initialize_tutorial()
	main._show_hub()

func _universal_candidate_index(offer: Dictionary) -> int:
	var candidates: Array = offer.get("candidates", [])
	for index in range(candidates.size()):
		if candidates[index] is Dictionary and String(candidates[index].get("category", "")) == "universal":
			return index
	return -1

func _first_enabled_research_button(root_node: Node) -> Button:
	for child in root_node.get_children():
		if child is Button and child.visible and not child.disabled:
			return child
		var nested := _first_enabled_research_button(child)
		if nested != null:
			return nested
	return null

func _find_supply_card(preparation: Control, recipe_id: String) -> Control:
	for card in preparation.supply_cards():
		if String(card.get("recipe_id")) == recipe_id:
			return card
	return null


func _find_menu_recipe_button(menu_view: Control, recipe_id: String) -> Button:
	var grid = menu_view.get_node(
		"Content/Body/CollectionPanel/Collection/CollectionScroll/CollectionGrid"
	)
	for button in grid.get_children():
		if button is Button and String(button.get_meta("recipe_id", "")) == recipe_id:
			return button
	return null

func _first_occupied_cell(board: Control) -> Control:
	for cell in board.get_node("BoardFrame/BoardGrid").get_children():
		if not String(cell.get_meta("instance_id", "")).is_empty():
			return cell
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
		var path := _save_path + String(suffix)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)

func _fail(message: String) -> void:
	if not _failures.has(message):
		_failures.append(message)

func _finish() -> void:
	if _failures.is_empty():
		print("CHALLENGE_STANDARD_RUN_MOUSE_SELF_CHECK_PASS stages=%d clicks=%d drags=%d" % [EXPECTED_STAGES, _mouse_clicks, _mouse_drags])
		quit(0)
		return
	for message in _failures:
		push_error(message)
	quit(1)
