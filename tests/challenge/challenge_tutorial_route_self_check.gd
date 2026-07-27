extends SceneTree

const MAIN_PATH := "res://scenes/challenge/challenge_main.tscn"
const ChallengeSaveService = preload("res://scripts/challenge/challenge_save_service.gd")
const ChallengeRunService = preload("res://scripts/challenge/challenge_run_service.gd")

var _failures: Array[String] = []
var _save_path := OS.get_temp_dir().path_join("project_rest_two_tutorial_route_self_check.json")


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

	_expect(main.get_tutorial_state_for_test()["step_id"] == "boss_brief", "new save starts tutorial")
	var initial_overlay = main.get_node("TutorialCanvasLayer/TutorialOverlay")
	_expect(initial_overlay.visible, "root overlay is visible")
	_expect(not initial_overlay.get_target_rects_for_test().is_empty(), "initial boss step resolves its post-layout target")
	_expect(initial_overlay.get_node("Arrow").visible, "initial boss step visibly points at its target")
	_expect(
		not initial_overlay.get_arrow_rect_for_test().intersects(initial_overlay.get_hint_rect_for_test()),
		"initial boss arrow remains outside the hint card"
	)
	main.acknowledge_tutorial_for_test()
	_expect(main.get_tutorial_state_for_test()["step_id"] == "place_recipe", "boss acknowledgement advances")

	var board = main.get_node("Root/Body/PreparationPanel/MainColumns/ChallengeBoard")
	_expect(board.place_recipe("butter_cookie", [0, 0], 0, "cookie_1"), "real butter cookie placement succeeds")
	_expect(main.get_tutorial_state_for_test()["step_id"] == "rotate_recipe", "placement signal advances")
	_expect(not board.rotate_instance("cookie_1"), "non-rotatable cookie rotation is rejected")
	_expect(main.get_tutorial_state_for_test()["step_id"] == "rotate_recipe", "rejected rotation cannot advance")
	_expect(board.place_recipe("milk_pudding", [2, 0], 0, "pudding_1"), "real pudding placement succeeds")
	_expect(board.rotate_instance("pudding_1"), "pudding rotation succeeds")
	_expect(main.get_tutorial_state_for_test()["step_id"] == "read_risk", "real shape rotation advances")

	main.acknowledge_tutorial_for_test()
	_expect(main.get_tutorial_state_for_test()["step_id"] == "start_battle", "valid risk acknowledgement advances")
	main.set_draft_for_test(_passing_draft())
	main.start_battle()
	_expect(main.get_tutorial_state_for_test()["step_id"] == "observe_battle", "successful start battle advances")
	_expect(not String(main.get_tutorial_state_for_test()["pre_battle_draft_fingerprint"]).is_empty(), "successful start stores draft fingerprint")
	var loaded: Dictionary = ChallengeSaveService.load_from_path(_save_path)
	var saved_onboarding: Dictionary = (loaded.get("data", {}) as Dictionary).get("onboarding", {})
	_expect(not String(saved_onboarding.get("pre_battle_draft_fingerprint", "")).is_empty(), "successful start persists draft fingerprint")

	main.queue_free()
	await process_frame
	await _assert_result_branches()
	_cleanup()
	_finish()


func _assert_result_branches() -> void:
	var victory_main = await _create_battle_ready_main("challenge_tutorial_victory.json", 2)
	victory_main.set_draft_for_test(_passing_draft())
	victory_main.start_battle()
	victory_main.advance_battle_for_test(30000)
	await process_frame
	await process_frame
	_expect(victory_main.get_tutorial_state_for_test()["step_id"] == "read_report", "victory opens report step")
	_expect(victory_main.get_node("SettlementDialog").visible, "victory shows the settlement report")
	_expect(victory_main.get_tutorial_state_for_test()["step_id"] == "read_report", "showing a report does not count as report exit")
	var victory_actions: Array[String] = []
	var victory_settlement = victory_main.get_node("SettlementDialog")
	var victory_targets = victory_settlement.resolve_tutorial_targets("victory", false)
	_expect(victory_targets.size() == 3, "victory report exposes content, contribution, and exit targets")
	_expect(
		victory_targets.back() == ChallengeTutorialOverlay.control_screen_rect(
			victory_settlement.get_node("Margin/Content/ActionRow/BackButton")
		),
		"victory report highlights Back as its third target"
	)
	var victory_body: String = victory_settlement.get_node(
		"TutorialOverlayHost/TutorialReportOverlay/HintHost/HintPanel/Margin/Content/BodyLabel"
	).text
	_expect(victory_body.find("返回") >= 0, "victory report copy explicitly directs the player to exit")
	victory_settlement.report_action_requested.connect(func(action: String) -> void:
		victory_actions.append("report:%s" % action)
	)
	victory_settlement.back_requested.connect(func() -> void:
		victory_actions.append("back")
	)
	victory_settlement.close_requested.emit()
	await process_frame
	_expect(victory_settlement.visible, "window close request cannot dismiss settlement")
	_expect(victory_main.get_tutorial_state_for_test()["step_id"] == "read_report", "window close request cannot advance report")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	victory_settlement.push_input(escape)
	await process_frame
	_expect(victory_settlement.visible, "Escape cannot dismiss settlement")
	_expect(victory_main.get_tutorial_state_for_test()["step_id"] == "read_report", "Escape cannot advance report")
	victory_settlement.hide()
	await process_frame
	await process_frame
	_expect(victory_settlement.visible, "non-action hide is restored")
	_expect(victory_main.get_tutorial_state_for_test()["step_id"] == "read_report", "non-action hide cannot strand or advance report")
	_expect(victory_actions.is_empty(), "non-action close paths emit no report action")
	victory_settlement.get_node("Margin/Content/ActionRow/BackButton").emit_signal("pressed")
	await process_frame
	_expect(victory_actions == ["report:back", "back"], "report action precedes the real victory back behavior")
	_expect(victory_main.get_tutorial_state_for_test()["step_id"] == "complete", "victory completes only after report action")
	_expect(victory_main.get_node("TutorialCanvasLayer/TutorialOverlay").visible, "victory exit visibly presents completion")
	victory_settlement.get_node("Margin/Content/ActionRow/BackButton").emit_signal("pressed")
	_expect(victory_actions == ["report:back", "back"], "settlement action guard prevents double report exit")
	victory_main.queue_free()
	await process_frame

	var loss_main = await _create_battle_ready_main("challenge_tutorial_retryable_loss.json", 2)
	loss_main.set_draft_for_test(_fast_losing_draft())
	loss_main.start_battle()
	loss_main.advance_battle_for_test(30000)
	await process_frame
	await process_frame
	_expect(loss_main.run_state["confidence"] == 1, "first loss leaves one confidence")
	var retry_actions: Array[String] = []
	var loss_settlement = loss_main.get_node("SettlementDialog")
	loss_settlement.report_action_requested.connect(func(action: String) -> void:
		retry_actions.append("report:%s" % action)
	)
	loss_settlement.retry_requested.connect(func() -> void:
		retry_actions.append("retry")
	)
	loss_settlement.get_node("Margin/Content/ActionRow/RetryButton").emit_signal("pressed")
	await process_frame
	_expect(retry_actions == ["report:retry", "retry"], "report action precedes the real retry behavior")
	_expect(loss_main.get_tutorial_state_for_test()["step_id"] == "rearrange", "retryable loss waits for rearrangement")
	_expect(loss_main.get_node("TutorialCanvasLayer/TutorialOverlay").visible, "retry exit visibly presents rearrangement")
	_expect(loss_main.get_tutorial_state_for_test()["step_id"] == "rearrange", "return alone does not complete")
	var loss_board = loss_main.get_node("Root/Body/PreparationPanel/MainColumns/ChallengeBoard")
	_expect(loss_board.move_instance("cookie_1", [1, 0]), "real valid board move succeeds")
	_expect(loss_main.get_tutorial_state_for_test()["step_id"] == "complete", "real valid move completes rearrangement")
	loss_main.queue_free()
	await process_frame

	var terminal_main = await _create_battle_ready_main("challenge_tutorial_terminal_loss.json", 1)
	terminal_main.set_draft_for_test(_fast_losing_draft())
	terminal_main.start_battle()
	terminal_main.advance_battle_for_test(30000)
	await process_frame
	await process_frame
	_expect(terminal_main.run_state["confidence"] == 0, "terminal loss consumes final confidence")
	var terminal_settlement = terminal_main.get_node("SettlementDialog")
	_expect(terminal_settlement.get_node("Margin/Content/ActionRow/RetryButton").disabled, "terminal report keeps retry disabled")
	_expect(terminal_settlement.get_node("TutorialOverlayHost/TutorialReportOverlay").visible, "terminal report guide is visible")
	var terminal_targets = terminal_settlement.resolve_tutorial_targets("loss_timeout", false)
	_expect(
		terminal_targets.back() == ChallengeTutorialOverlay.control_screen_rect(terminal_settlement.get_node("Margin/Content/ActionRow/BackButton")),
		"terminal report highlights return instead of disabled retry"
	)
	terminal_settlement.get_node("Margin/Content/ActionRow/BackButton").emit_signal("pressed")
	await process_frame
	_expect(terminal_main.get_tutorial_state_for_test()["step_id"] == "complete", "terminal loss completes after report action")
	_expect(terminal_main.get_node("TutorialCanvasLayer/TutorialOverlay").visible, "terminal exit visibly presents completion")
	terminal_main.queue_free()
	await process_frame


func _create_battle_ready_main(file_name: String, confidence: int) -> Node:
	var path := OS.get_temp_dir().path_join(file_name)
	_cleanup_path(path)
	var data := ChallengeSaveService.empty_save()
	data["active_run"] = ChallengeRunService.new().create_single_encounter("tutorial-route", 42, "picky_food_critic")
	data["active_run"]["confidence"] = confidence
	data["onboarding"] = {
		"version": 1,
		"status": "active",
		"step_id": "start_battle",
		"completed_step_ids": ["boss_brief", "place_recipe", "rotate_recipe", "read_risk"],
		"pre_battle_draft_fingerprint": ""
	}
	_expect(bool(ChallengeSaveService.save_to_path(path, data).get("ok", false)), "battle-ready tutorial save writes")
	var instance = load(MAIN_PATH).instantiate()
	instance.save_path = path
	root.add_child(instance)
	await process_frame
	await process_frame
	return instance


func _passing_draft() -> Dictionary:
	return {"placements": [
		{"instance_id": "pudding_1", "recipe_id": "milk_pudding", "origin": [0, 0], "rotation": 0},
		{"instance_id": "muffin_1", "recipe_id": "blueberry_muffin", "origin": [1, 0], "rotation": 0},
		{"instance_id": "pudding_2", "recipe_id": "milk_pudding", "origin": [0, 3], "rotation": 0},
		{"instance_id": "muffin_2", "recipe_id": "blueberry_muffin", "origin": [1, 3], "rotation": 0},
		{"instance_id": "cookie_1", "recipe_id": "butter_cookie", "origin": [4, 0], "rotation": 0},
		{"instance_id": "cookie_2", "recipe_id": "butter_cookie", "origin": [4, 1], "rotation": 0}
	]}


func _fast_losing_draft() -> Dictionary:
	return {"placements": [
		{"instance_id": "cookie_1", "recipe_id": "butter_cookie", "origin": [0, 0], "rotation": 0},
		{"instance_id": "cookie_2", "recipe_id": "butter_cookie", "origin": [0, 2], "rotation": 0},
		{"instance_id": "cookie_3", "recipe_id": "butter_cookie", "origin": [0, 4], "rotation": 0},
		{"instance_id": "jelly_1", "recipe_id": "strawberry_jelly", "origin": [2, 0], "rotation": 0},
		{"instance_id": "jelly_2", "recipe_id": "strawberry_jelly", "origin": [2, 2], "rotation": 0},
		{"instance_id": "jelly_3", "recipe_id": "strawberry_jelly", "origin": [2, 4], "rotation": 0}
	]}


func _cleanup() -> void:
	_cleanup_path(_save_path)


func _cleanup_path(path: String) -> void:
	for suffix in ["", ".tmp", ".previous", ".broken", ".broken.previous"]:
		var candidate: String = path + suffix
		if FileAccess.file_exists(candidate):
			DirAccess.remove_absolute(candidate)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	if not _failures.has(message):
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("CHALLENGE_TUTORIAL_ROUTE_SELF_CHECK_PASS")
		quit(0)
		return
	for message in _failures:
		push_error(message)
	quit(1)
