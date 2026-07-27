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
	await _assert_terminal_settlement_dismiss_resume_survives_restart()
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
	var root_overlay = main.get_node("TutorialCanvasLayer/TutorialOverlay")
	var root_next = root_overlay.get_node("HintHost/HintPanel/Margin/Content/ActionRow/NextButton")
	_expect(root_overlay.visible, "replay uses root overlay with safe fallback")
	_expect(root_overlay.get_node("HintHost/HintPanel/Margin/Content/StepLabel").text == "1 / 9", "replay starts at the first step")
	root_next.emit_signal("pressed")
	_expect(root_overlay.get_node("HintHost/HintPanel/Margin/Content/StepLabel").text == "2 / 9", "root next changes the replay step")
	for _index in range(4):
		root_next.emit_signal("pressed")
	_expect(root_overlay.get_node("HintHost/HintPanel/Margin/Content/StepLabel").text == "6 / 9", "replay traverses to unavailable battle guidance")
	_expect(not root_overlay.get_node("Arrow").visible, "unavailable battle replay has no arrow")
	_expect(not root_overlay.get_node("OutlineHost/TargetOutline0").visible, "unavailable battle replay has no target outline")
	root_next.emit_signal("pressed")
	_expect(root_overlay.get_node("HintHost/HintPanel/Margin/Content/StepLabel").text == "7 / 9", "root next traverses unavailable report guidance")
	_expect(not root_overlay.get_node("Arrow").visible, "unavailable report replay has no arrow")
	_expect(main.get_tutorial_state_for_test() == tutorial_before, "replay does not rewrite completion")
	_expect(main.run_state == run_before, "replay does not mutate the run")
	_expect(main.get_node("Root/Body/PreparationPanel/MainColumns/ChallengeBoard").get_draft() == draft_before, "replay does not mutate the board")
	root_overlay.get_node("HintHost/HintPanel/Margin/Content/ActionRow/DismissButton").emit_signal("pressed")
	_expect(not main.is_tutorial_replay_for_test(), "dismiss exits replay without changing completion")
	_expect(main.get_tutorial_state_for_test() == tutorial_before, "replay dismissal does not rewrite completion")
	var settlement = main.get_node("SettlementDialog")
	main.run_state["phase"] = "ended"
	main.run_state["confidence"] = 0
	main.battle_state = {"phase": "ended", "outcome": "loss_reputation"}
	settlement.popup_centered(Vector2i(1080, 820))
	settlement.show_tutorial_report("loss_reputation", false, false)
	var report_title: String = settlement.get_node("TutorialReportOverlay/HintHost/HintPanel/Margin/Content/TitleLabel").text
	var report_body: String = settlement.get_node("TutorialReportOverlay/HintHost/HintPanel/Margin/Content/BodyLabel").text
	settlement.get_node("Margin/Content/ActionRow/TutorialHelpButton").emit_signal("pressed")
	_expect(main.is_tutorial_replay_for_test(), "report help also starts the shared replay coordinator")
	_expect(settlement.get_node("TutorialReportOverlay").visible, "report replay uses its local safe fallback")
	var report_next = settlement.get_node("TutorialReportOverlay/HintHost/HintPanel/Margin/Content/ActionRow/NextButton")
	for _index in range(6):
		report_next.emit_signal("pressed")
	_expect(settlement.get_node("TutorialReportOverlay/HintHost/HintPanel/Margin/Content/StepLabel").text == "7 / 9", "report next reaches report replay step")
	_expect(settlement.get_node("TutorialReportOverlay/HintHost/HintPanel/Margin/Content/TitleLabel").text == report_title, "report replay reuses outcome-specific report title")
	_expect(settlement.get_node("TutorialReportOverlay/HintHost/HintPanel/Margin/Content/BodyLabel").text == report_body, "report replay reuses outcome-specific report body")
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
	var settlement_saved: Dictionary = ChallengeSaveService.load_from_path(settlement.save_path)
	_expect(
		String((settlement_saved.get("data", {}) as Dictionary).get("onboarding", {}).get("step_id", "")) == "read_report",
		"visible settlement migration persists immediately"
	)
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


func _assert_terminal_settlement_dismiss_resume_survives_restart() -> void:
	var data := ChallengeSaveService.empty_save()
	data["active_run"] = ChallengeRunService.new().create_single_encounter("terminal-restart", 42, "picky_food_critic")
	data["active_run"]["phase"] = "ended"
	data["active_run"]["confidence"] = 0
	data["active_run"]["last_outcome"] = "loss_reputation"
	data["onboarding"] = {
		"version": 1,
		"status": "active",
		"step_id": "read_report",
		"completed_step_ids": ["boss_brief", "place_recipe", "rotate_recipe", "read_risk", "start_battle", "observe_battle"],
		"pre_battle_draft_fingerprint": ""
	}
	var main = await _create_main("terminal_restart", data)
	main.battle_state = {"phase": "ended", "outcome": "loss_reputation"}
	main.get_node("Root/Body/PreparationPanel").visible = false
	main.get_node("Root/Body/BattlePanel").visible = true
	main.get_node("SettlementDialog").popup_centered(Vector2i(1080, 820))
	main.dismiss_tutorial()
	main.open_tutorial_help()
	var saved: Dictionary = ChallengeSaveService.load_from_path(main.save_path)
	var saved_data: Dictionary = saved.get("data", {})
	_expect(saved_data.get("active_battle", "missing") == null, "terminal settlement dismiss/resume never persists a finished battle")
	_expect(String((saved_data.get("active_run", {}) as Dictionary).get("phase", "")) == "ended", "terminal settlement dismiss/resume preserves ended phase")
	_expect(String((saved_data.get("active_run", {}) as Dictionary).get("last_outcome", "")) == "loss_reputation", "terminal settlement dismiss/resume preserves outcome")
	var restart_path: String = main.save_path
	main.queue_free()
	await process_frame
	var restarted = await _restart_main(restart_path)
	_expect(String(restarted.run_state.get("phase", "")) == "ended", "restart keeps ended run phase")
	_expect(String(restarted.run_state.get("last_outcome", "")) == "loss_reputation", "restart keeps terminal outcome")
	restarted.queue_free()
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
	var saved_onboarding: Dictionary = (saved.get("data", {}) as Dictionary).get("onboarding", {})
	_expect(
		saved_onboarding == future_before,
		"unrelated save preserves future onboarding byte for byte"
	)
	_expect(JSON.stringify(saved_onboarding) == JSON.stringify(future_before), "unrelated save preserves future onboarding semantic JSON")
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


func _restart_main(path: String) -> Node:
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
