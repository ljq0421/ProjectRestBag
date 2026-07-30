extends SceneTree

const MAIN_PATH := "res://scenes/challenge/challenge_main.tscn"
const ChallengeSaveService = preload("res://scripts/challenge/challenge_save_service.gd")
const ChallengeTutorialOverlay = preload("res://scripts/challenge/ui/challenge_tutorial_overlay.gd")

var _failures: Array[String] = []
var _save_path := OS.get_temp_dir().path_join(
	"project_rest_two_tutorial_route_self_check.json"
)


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1172, 1055)
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

	var overlay = main.get_node("TutorialLayer/TutorialOverlay")
	var preparation = main.get_node("Root/PageHost/PreparationHost/PreparationView")
	var board = preparation.board()
	_expect(main.get_tutorial_state_for_test()["step_id"] == "boss_brief", "new run starts core tutorial")
	_expect(overlay.visible, "core tutorial is visible in preparation")
	var timeline_block := preparation.get_node(
		"MainColumns/RightSidebar/BossBrief/Content/TimelineBlock"
	) as Control
	var boss_brief := preparation.get_node("MainColumns/RightSidebar/BossBrief") as Control
	var boss_targets: Array[Rect2] = main.resolve_tutorial_targets("boss_brief")
	var expected_timeline_rect := ChallengeTutorialOverlay.control_screen_rect(timeline_block)
	_expect(boss_targets.size() == 1, "boss brief step highlights one precise target")
	if boss_targets.size() == 1:
		_expect(
			boss_targets[0].position.is_equal_approx(expected_timeline_rect.position)
				and boss_targets[0].size.is_equal_approx(expected_timeline_rect.size),
			"boss brief step targets the demand timeline block exactly"
		)
		_expect(
			boss_targets[0].size.y
				< ChallengeTutorialOverlay.control_screen_rect(boss_brief).size.y * 0.5,
			"boss brief step does not frame the entire right panel"
		)
	var rendered_targets: Array[Rect2] = overlay.get_target_rects_for_test()
	_expect(
		rendered_targets.size() == 1,
		"boss brief step renders one outline: targets=%s expected=%s overlay_size=%s overlay_transform=%s timeline_transform=%s"
			% [
				rendered_targets,
				expected_timeline_rect,
				overlay.size,
				overlay.get_global_transform(),
				timeline_block.get_global_transform()
			]
	)
	if rendered_targets.size() == 1:
		_expect(
			rendered_targets[0].position.is_equal_approx(expected_timeline_rect.position.floor())
				and rendered_targets[0].size.is_equal_approx(expected_timeline_rect.size.ceil()),
			"rendered 1/9 outline stays on the demand timeline at the narrow window size"
		)
	main.acknowledge_tutorial_for_test()
	_expect(main.get_tutorial_state_for_test()["step_id"] == "place_recipe", "boss acknowledgement advances")

	_expect(board.place_recipe("butter_cookie", [2, 5], 0, "cookie_1"), "real placement succeeds")
	_expect(main.get_tutorial_state_for_test()["step_id"] == "rotate_recipe", "real placement advances")
	_expect(board.place_recipe("milk_pudding", [4, 5], 0, "pudding_1"), "rotatable recipe placement succeeds")
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
