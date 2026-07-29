extends SceneTree

const MAIN_PATH := "res://scenes/challenge/challenge_main.tscn"

var _failures: Array[String] = []
var _save_path := OS.get_temp_dir().path_join("project_rest_two_main_scene_self_check.json")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	_cleanup()
	var packed: PackedScene = load(MAIN_PATH)
	_expect(packed != null, "challenge main scene should load")
	if packed == null:
		_finish()
		return
	var view = packed.instantiate()
	view.save_path = _save_path
	root.add_child(view)
	await process_frame
	await process_frame

	_expect(view.get_node("Root/PageHost/HubHost").visible, "new save should open challenge hub")
	_expect(view.has_node("Root/GlobalTopBar/TutorialHelpButton"), "global top bar should keep tutorial entry")
	_expect(view.has_node("Root/PageHost/PreparationHost/PreparationView"), "main scene should own preparation view")
	_expect(view.has_node("Root/PageHost/BattleView"), "main scene should own battle view")
	_expect(view.has_node("Root/PageHost/UpgradeHost/UpgradeSelectView"), "main scene should own upgrade view")
	_expect(view.has_node("Root/PageHost/ResearchHost/ResearchView"), "main scene should own research view")
	_expect(view.has_node("Root/PageHost/SummaryHost/RunSummaryView"), "main scene should own summary view")
	_expect(view.has_node("SettlementDialog"), "main scene should keep settlement dialog")
	_expect(view.has_node("TutorialLayer/TutorialOverlay"), "main scene should keep tutorial layer")

	view.start_new_run_for_test(42)
	await process_frame
	_expect(view.get_node("Root/PageHost/PreparationHost").visible, "starting run should open preparation")
	var preparation = view.get_node("Root/PageHost/PreparationHost/PreparationView")
	_expect(
		preparation.get_node("SupplyScroll/SupplyStrip").get_child_count() == 6,
		"first run should dynamically show six starter recipes"
	)
	var run: Dictionary = view.run_state
	_expect((run.get("encounter_instances", []) as Array).size() == 5, "root flow should freeze five encounters")
	_expect(int(run.get("confidence", 0)) == 2, "root flow should start with two confidence")

	var encounters: Array = run.get("encounter_instances", [])
	var encounter: Dictionary = encounters[0]
	view.set_draft_for_test(encounter.get("validation_draft", {}))
	view.start_battle()
	_expect(view.get_node("Root/PageHost/BattleView").visible, "battle page should become visible")
	view.advance_battle_for_test(int(encounter.get("duration_ms", 0)))
	await process_frame
	await process_frame
	_expect(view.get_node("SettlementDialog").visible, "finished battle should open settlement report")
	_expect(String(view.battle_state.get("outcome", "")) == "victory", "stage validation draft should win")

	view.get_node("SettlementDialog/Margin/Content/ActionRow/BackButton").emit_signal("pressed")
	await process_frame
	_expect(view.get_node("Root/PageHost/UpgradeHost").visible, "first victory should open persisted upgrade choice")
	var upgrade_view = view.get_node("Root/PageHost/UpgradeHost/UpgradeSelectView")
	_expect(
		upgrade_view.get_node("Content/Candidates/Candidate0").visible
		and upgrade_view.get_node("Content/Candidates/Candidate2").visible,
		"upgrade page should show three candidates"
	)
	upgrade_view.get_node("Content/Candidates/Candidate0").emit_signal("pressed")
	await process_frame
	_expect(view.get_node("Root/PageHost/PreparationHost").visible, "upgrade choice should advance to next preparation")
	_expect(int(view.run_state.get("stage_index", -1)) == 1, "upgrade choice should advance exactly one stage")
	_expect((view.run_state.get("run_upgrades", []) as Array).size() == 1, "chosen upgrade should be stored as structured run effect")

	var main_text := FileAccess.get_file_as_string("res://scripts/challenge/challenge_main_view.gd")
	_expect(
		main_text.find("run_state[\"phase\"] =") == -1,
		"main view must not write run phases directly"
	)
	_expect(
		main_text.find("settlement_id :=") == -1
		and main_text.find("reward_transaction_id :=") == -1,
		"main view must not manufacture transaction identities"
	)

	view.queue_free()
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
	_cleanup()
	if _failures.is_empty():
		print("CHALLENGE_MAIN_SCENE_SELF_CHECK_PASS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
