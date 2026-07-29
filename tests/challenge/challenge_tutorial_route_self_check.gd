extends SceneTree

const MAIN_PATH := "res://scenes/challenge/challenge_main.tscn"
const ChallengeSaveService = preload("res://scripts/challenge/challenge_save_service.gd")

var _failures: Array[String] = []
var _save_path := OS.get_temp_dir().path_join(
	"project_rest_two_tutorial_route_self_check.json"
)


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

	var overlay = main.get_node("TutorialLayer/TutorialOverlay")
	var preparation = main.get_node("Root/PageHost/PreparationHost/PreparationView")
	var board = preparation.board()
	_expect(main.get_tutorial_state_for_test()["step_id"] == "boss_brief", "new run starts core tutorial")
	_expect(overlay.visible, "core tutorial is visible in preparation")
	main.acknowledge_tutorial_for_test()
	_expect(main.get_tutorial_state_for_test()["step_id"] == "place_recipe", "boss acknowledgement advances")

	_expect(board.place_recipe("butter_cookie", [0, 0], 0, "cookie_1"), "real placement succeeds")
	_expect(main.get_tutorial_state_for_test()["step_id"] == "rotate_recipe", "real placement advances")
	_expect(board.place_recipe("milk_pudding", [2, 0], 0, "pudding_1"), "rotatable recipe placement succeeds")
	_expect(board.rotate_instance("pudding_1"), "real rotation succeeds")
	_expect(main.get_tutorial_state_for_test()["step_id"] == "read_risk", "shape-changing rotation advances")

	var encounter_instances: Array = main.run_state.get("encounter_instances", [])
	var encounter: Dictionary = encounter_instances[0]
	main.set_draft_for_test(encounter.get("validation_draft", {}))
	main.acknowledge_tutorial_for_test()
	_expect(main.get_tutorial_state_for_test()["step_id"] == "start_battle", "valid coverage acknowledgement advances")
	main.start_battle()
	_expect(main.get_tutorial_state_for_test()["step_id"] == "observe_battle", "battle start advances")
	var loaded: Dictionary = ChallengeSaveService.load_from_path(_save_path)
	var meta: Dictionary = (loaded.get("data", {}) as Dictionary).get("meta", {})
	_expect(
		not String((meta.get("onboarding", {}) as Dictionary).get(
			"pre_battle_draft_fingerprint", ""
		)).is_empty(),
		"battle start persists the draft fingerprint in meta.onboarding"
	)

	main.advance_battle_for_test(int(encounter.get("duration_ms", 0)))
	await process_frame
	await process_frame
	_expect(main.get_node("SettlementDialog").visible, "finished battle opens the report")
	_expect(main.get_tutorial_state_for_test()["step_id"] == "read_report", "finished battle advances to report")
	main.get_node(
		"SettlementDialog/Margin/Content/ActionRow/BackButton"
	).emit_signal("pressed")
	await process_frame
	_expect(main.get_tutorial_state_for_test()["step_id"] == "complete", "report acknowledgement reaches core completion")
	main.acknowledge_tutorial_for_test()
	_expect(main.get_tutorial_state_for_test()["status"] == "completed", "core tutorial can be completed")

	main.queue_free()
	await process_frame
	_cleanup()
	_finish()


func _cleanup() -> void:
	for suffix in ["", ".tmp", ".previous", ".broken", ".broken.previous"]:
		var path: String = _save_path + suffix
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _expect(condition: bool, message: String) -> void:
	if not condition and not _failures.has(message):
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("CHALLENGE_TUTORIAL_ROUTE_SELF_CHECK_PASS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
