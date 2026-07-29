extends SceneTree

const MAIN_PATH := "res://scenes/challenge/challenge_main.tscn"
const ChallengeSaveService = preload("res://scripts/challenge/challenge_save_service.gd")

var _failures: Array[String] = []
var _paths: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	await _assert_dismiss_and_resume()
	await _assert_completed_replay_is_session_only()
	_cleanup()
	_finish()


func _assert_dismiss_and_resume() -> void:
	var data := ChallengeSaveService.empty_save()
	var main = await _create_main("dismiss", data)
	main.start_new_run_for_test(42)
	await process_frame
	main.acknowledge_tutorial_for_test()
	main.dismiss_tutorial()
	_expect(main.get_tutorial_state_for_test()["status"] == "dismissed", "dismiss stores status")
	var saved: Dictionary = ChallengeSaveService.load_from_path(main.save_path)
	var saved_meta: Dictionary = (saved.get("data", {}) as Dictionary).get("meta", {})
	_expect(
		String((saved_meta.get("onboarding", {}) as Dictionary).get("status", "")) == "dismissed",
		"dismiss persists inside meta.onboarding"
	)
	main.open_tutorial_help()
	_expect(main.get_tutorial_state_for_test()["status"] == "active", "help resumes dismissed tutorial")
	main.queue_free()
	await process_frame


func _assert_completed_replay_is_session_only() -> void:
	var data := ChallengeSaveService.empty_save()
	data["meta"]["onboarding"] = {
		"version": 2,
		"status": "completed",
		"step_id": "complete",
		"completed_step_ids": [
			"boss_brief",
			"place_recipe",
			"rotate_recipe",
			"read_risk",
			"start_battle",
			"observe_battle",
			"read_report",
			"complete"
		],
		"pre_battle_draft_fingerprint": "",
		"seen_stage_two_hint_ids": []
	}
	var main = await _create_main("replay", data)
	main.open_tutorial_help()
	_expect(main.is_tutorial_replay_for_test(), "completed tutorial opens replay mode")
	var overlay = main.get_node("TutorialLayer/TutorialOverlay")
	_expect(overlay.visible, "replay displays the root overlay")
	for _index in range(9):
		main.advance_tutorial_replay()
	_expect(not main.is_tutorial_replay_for_test(), "replay closes after the last core step")
	var saved: Dictionary = ChallengeSaveService.load_from_path(main.save_path)
	var meta: Dictionary = (saved.get("data", {}) as Dictionary).get("meta", {})
	_expect(
		String((meta.get("onboarding", {}) as Dictionary).get("status", "")) == "completed",
		"replay does not rewrite completed progress"
	)
	main.queue_free()
	await process_frame


func _create_main(label: String, data: Dictionary) -> Node:
	var path := OS.get_temp_dir().path_join(
		"project_rest_two_tutorial_replay_%s.json" % label
	)
	_paths.append(path)
	_cleanup_path(path)
	_expect(
		bool(ChallengeSaveService.save_to_path(path, data).get("ok", false)),
		"%s fixture saves" % label
	)
	var instance = load(MAIN_PATH).instantiate()
	instance.save_path = path
	root.add_child(instance)
	await process_frame
	await process_frame
	return instance


func _cleanup() -> void:
	for path in _paths:
		_cleanup_path(path)


func _cleanup_path(path: String) -> void:
	for suffix in ["", ".tmp", ".previous", ".broken", ".broken.previous"]:
		var candidate: String = path + suffix
		if FileAccess.file_exists(candidate):
			DirAccess.remove_absolute(candidate)


func _expect(condition: bool, message: String) -> void:
	if not condition and not _failures.has(message):
		_failures.append(message)


func _finish() -> void:
	_cleanup()
	if _failures.is_empty():
		print("CHALLENGE_TUTORIAL_REPLAY_SELF_CHECK_PASS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
