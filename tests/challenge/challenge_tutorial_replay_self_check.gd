extends SceneTree

const MAIN_PATH := "res://scenes/challenge/challenge_main.tscn"
const ChallengeSaveService = preload("res://scripts/challenge/challenge_save_service.gd")
const ChallengeRunService = preload("res://scripts/challenge/challenge_run_service.gd")

var _failures: Array[String] = []
var _paths: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	await _assert_dismiss_and_resume()
	await _assert_completed_replay_is_session_only()
	await _assert_missing_onboarding_contexts()
	await _assert_future_onboarding_is_not_rewritten()
	_cleanup()
	_finish()


func _assert_dismiss_and_resume() -> void:
	var main = await _create_main("dismiss", ChallengeSaveService.empty_save())
	main.acknowledge_tutorial_for_test()
	main.dismiss_tutorial()
	_expect(main.get_tutorial_state_for_test()["status"] == "dismissed", "dismiss stores status")
	var saved: Dictionary = ChallengeSaveService.load_from_path(main.save_path)
	_expect(
		String((saved.get("data", {}) as Dictionary).get("onboarding", {}).get("status", "")) == "dismissed",
		"dismiss writes immediately"
	)
	main.open_tutorial_help()
	_expect(main.get_tutorial_state_for_test()["status"] == "active", "help resumes incomplete tutorial")
	_expect(main.get_tutorial_state_for_test()["step_id"] == "place_recipe", "resume preserves compatible step")
	main.queue_free()
	await process_frame


func _assert_completed_replay_is_session_only() -> void:
	var data := ChallengeSaveService.empty_save()
	data["onboarding"] = {
		"version": 1,
		"status": "completed",
		"step_id": "complete",
		"completed_step_ids": ["boss_brief", "place_recipe", "rotate_recipe", "read_risk", "start_battle", "observe_battle", "read_report", "rearrange", "complete"],
		"pre_battle_draft_fingerprint": ""
	}
	var main = await _create_main("completed", data)
	var tutorial_before: Dictionary = main.get_tutorial_state_for_test()
	var run_before: Dictionary = main.run_state.duplicate(true)
	var draft_before: Dictionary = main.get_node("Root/Body/PreparationPanel/MainColumns/ChallengeBoard").get_draft()
	main.get_node("Root/TopBar/TutorialHelpButton").emit_signal("pressed")
	_expect(main.is_tutorial_replay_for_test(), "completed help starts replay mode")
	_expect(main.get_node("TutorialCanvasLayer/TutorialOverlay").visible, "replay uses root overlay with safe fallback")
	main.get_node("TutorialCanvasLayer/TutorialOverlay/HintHost/HintPanel/Margin/Content/ActionRow/NextButton").emit_signal("pressed")
	_expect(main.get_tutorial_state_for_test() == tutorial_before, "replay does not rewrite completion")
	_expect(main.run_state == run_before, "replay does not mutate the run")
	_expect(main.get_node("Root/Body/PreparationPanel/MainColumns/ChallengeBoard").get_draft() == draft_before, "replay does not mutate the board")
	main.get_node("TutorialCanvasLayer/TutorialOverlay/HintHost/HintPanel/Margin/Content/ActionRow/DismissButton").emit_signal("pressed")
	_expect(not main.is_tutorial_replay_for_test(), "dismiss exits replay without changing completion")
	_expect(main.get_tutorial_state_for_test() == tutorial_before, "replay dismissal does not rewrite completion")
	var settlement = main.get_node("SettlementDialog")
	settlement.popup_centered(Vector2i(1080, 820))
	settlement.get_node("Margin/Content/ActionRow/TutorialHelpButton").emit_signal("pressed")
	_expect(main.is_tutorial_replay_for_test(), "report help also starts the shared replay coordinator")
	_expect(settlement.get_node("TutorialReportOverlay").visible, "report replay uses its local safe fallback")
	settlement.get_node("TutorialReportOverlay/HintHost/HintPanel/Margin/Content/ActionRow/NextButton").emit_signal("pressed")
	settlement.get_node("TutorialReportOverlay/HintHost/HintPanel/Margin/Content/ActionRow/DismissButton").emit_signal("pressed")
	_expect(not main.is_tutorial_replay_for_test(), "report dismissal exits the shared replay coordinator")
	_expect(main.get_tutorial_state_for_test() == tutorial_before, "report replay keeps completion unchanged")
	main.queue_free()
	await process_frame


func _assert_missing_onboarding_contexts() -> void:
	var preparation = await _create_main("migration_preparation", _save_without_onboarding("preparation"))
	_expect(preparation.get_tutorial_state_for_test().get("step_id", "") == "boss_brief", "missing preparation onboarding starts at boss brief")
	preparation.queue_free()
	await process_frame

	var battle_data := _save_without_onboarding("battle")
	battle_data["active_battle"] = _restorable_battle()
	battle_data["active_run"]["phase"] = "battle"
	var battle = await _create_main("migration_battle", battle_data)
	_expect(battle.get_tutorial_state_for_test().get("step_id", "") == "observe_battle", "missing battle onboarding starts at observe battle")
	battle.queue_free()
	await process_frame

	var settlement = await _create_main("migration_settlement", _save_without_onboarding("settlement"))
	settlement.get_node("SettlementDialog").popup_centered(Vector2i(1080, 820))
	var settlement_data: Dictionary = settlement.get("_save_data")
	settlement_data.erase("onboarding")
	settlement_data["last_outcome"] = "loss_timeout"
	settlement.set("_save_data", settlement_data)
	settlement.call("_initialize_tutorial")
	_expect(settlement.get_tutorial_state_for_test().get("step_id", "") == "read_report", "visible settlement migrates to read report")
	settlement.queue_free()
	await process_frame

	var finished_data := _save_without_onboarding("finished")
	finished_data["active_run"]["phase"] = "completed"
	var finished = await _create_main("migration_finished", finished_data)
	_expect(finished.get_tutorial_state_for_test().get("step_id", "") == "complete", "finished run migrates to complete")
	_expect(finished.get_tutorial_state_for_test().get("status", "") == "active", "finished migration remains help-accessible")
	_expect(not finished.get_node("TutorialCanvasLayer/TutorialOverlay").visible, "finished migration does not auto display")
	finished.open_tutorial_help()
	_expect(finished.get_node("TutorialCanvasLayer/TutorialOverlay").visible, "finished migration help displays completion safely")
	finished.queue_free()
	await process_frame


func _assert_future_onboarding_is_not_rewritten() -> void:
	var data := ChallengeSaveService.empty_save()
	var future := {
		"version": 2,
		"status": "future-status",
		"step_id": "future-step",
		"unknown_nested": {"keep": [1, {"value": true}]}
	}
	data["onboarding"] = future.duplicate(true)
	var main = await _create_main("future", data)
	_expect(bool(main.get_tutorial_state_for_test().get("unsupported_newer_version", false)), "future onboarding exposes only a runtime diagnostic")
	var future_before: Dictionary = (ChallengeSaveService.load_from_path(main.save_path).get("data", {}) as Dictionary).get("onboarding", {}).duplicate(true)
	main.set_draft_for_test({"placements": []})
	main.call("_save_now", false)
	var saved: Dictionary = ChallengeSaveService.load_from_path(main.save_path)
	_expect(
		(saved.get("data", {}) as Dictionary).get("onboarding", {}) == future_before,
		"unrelated save preserves future onboarding byte for byte"
	)
	main.queue_free()
	await process_frame


func _save_without_onboarding(_context: String) -> Dictionary:
	var data := ChallengeSaveService.empty_save()
	data.erase("onboarding")
	data["active_run"] = ChallengeRunService.new().create_single_encounter("tutorial-migration", 42, "picky_food_critic")
	return data


func _restorable_battle() -> Dictionary:
	return {
		"phase": "running",
		"elapsed_ms": 0,
		"item_states": {},
		"events": [],
		"_snapshot": {},
		"_encounter": {}
	}


func _create_main(label: String, data: Dictionary) -> Node:
	var path := OS.get_temp_dir().path_join("project_rest_two_tutorial_replay_%s.json" % label)
	_paths.append(path)
	_cleanup_path(path)
	_expect(bool(ChallengeSaveService.save_to_path(path, data).get("ok", false)), "%s fixture saves" % label)
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
		var candidate: String = path + String(suffix)
		if FileAccess.file_exists(candidate):
			DirAccess.remove_absolute(candidate)


func _expect(condition: bool, message: String) -> void:
	if not condition and not _failures.has(message):
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("CHALLENGE_TUTORIAL_REPLAY_SELF_CHECK_PASS")
		quit(0)
		return
	for message in _failures:
		push_error(message)
	quit(1)
