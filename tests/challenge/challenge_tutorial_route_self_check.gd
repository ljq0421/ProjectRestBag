extends SceneTree

const MAIN_PATH := "res://scenes/challenge/challenge_main.tscn"
const ChallengeSaveService = preload("res://scripts/challenge/challenge_save_service.gd")

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
	_expect(main.get_node("TutorialCanvasLayer/TutorialOverlay").visible, "root overlay is visible")
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
	_cleanup()
	_finish()


func _passing_draft() -> Dictionary:
	return {"placements": [
		{"instance_id": "pudding_1", "recipe_id": "milk_pudding", "origin": [0, 0], "rotation": 0},
		{"instance_id": "muffin_1", "recipe_id": "blueberry_muffin", "origin": [1, 0], "rotation": 0},
		{"instance_id": "pudding_2", "recipe_id": "milk_pudding", "origin": [0, 3], "rotation": 0},
		{"instance_id": "muffin_2", "recipe_id": "blueberry_muffin", "origin": [1, 3], "rotation": 0},
		{"instance_id": "cookie_1", "recipe_id": "butter_cookie", "origin": [4, 0], "rotation": 0},
		{"instance_id": "cookie_2", "recipe_id": "butter_cookie", "origin": [4, 1], "rotation": 0}
	]}


func _cleanup() -> void:
	for suffix in ["", ".tmp", ".previous", ".broken", ".broken.previous"]:
		var path: String = _save_path + suffix
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
		print("CHALLENGE_TUTORIAL_ROUTE_SELF_CHECK_PASS")
		quit(0)
		return
	for message in _failures:
		push_error(message)
	quit(1)
