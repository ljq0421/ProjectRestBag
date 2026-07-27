extends SceneTree

const MAIN_PATH := "res://scenes/challenge/challenge_main.tscn"

var _failures: Array[String] = []
var _save_path := OS.get_temp_dir().path_join("project_rest_two_main_scene_self_check.json")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	_cleanup()
	if not ResourceLoader.exists(MAIN_PATH):
		_fail("challenge main scene should exist")
		_finish()
		return
	var main_scene = load(MAIN_PATH)
	_expect(main_scene != null, "challenge main scene should load")
	if main_scene == null:
		_finish()
		return
	var view = main_scene.instantiate()
	view.set("save_path", _save_path)
	root.add_child(view)
	await process_frame
	await process_frame

	_expect(view.get_node("Root/TopBar/ConfidenceLabel").text.find("2") >= 0, "run should start with two confidence")
	_expect(view.get_node("Root/Body/PreparationPanel").visible, "preparation should be visible first")
	_expect(not view.get_node("Root/Body/BattlePanel").visible, "battle should be hidden before start")

	var failing_draft := {"placements": [
		{"instance_id": "cookie_only", "recipe_id": "butter_cookie", "origin": [0, 0], "rotation": 0}
	]}
	view.call("set_draft_for_test", failing_draft)
	view.call("start_battle")
	_expect(view.get_node("Root/Body/BattlePanel").visible, "battle should become visible")
	view.call("advance_battle_for_test", 30000)
	await process_frame
	_expect(view.get_node("SettlementDialog").visible, "settlement should open")

	var run_before_retry: Dictionary = view.get("run_state")
	var encounter_before := String(run_before_retry.get("encounter_id", ""))
	view.get_node("SettlementDialog/Margin/Content/ActionRow/RetryButton").emit_signal("pressed")
	await process_frame
	var run_after_retry: Dictionary = view.get("run_state")
	_expect(int(run_after_retry.get("confidence", 0)) == 1, "retry should retain one confidence")
	_expect(String(run_after_retry.get("encounter_id", "")) == encounter_before, "retry should preserve encounter")
	_expect(view.get_node("Root/Body/PreparationPanel").visible, "retry should return to preparation")

	var passing_draft := {"placements": [
		{"instance_id": "pudding_1", "recipe_id": "milk_pudding", "origin": [0, 0], "rotation": 0},
		{"instance_id": "muffin_1", "recipe_id": "blueberry_muffin", "origin": [1, 0], "rotation": 0},
		{"instance_id": "pudding_2", "recipe_id": "milk_pudding", "origin": [0, 3], "rotation": 0},
		{"instance_id": "muffin_2", "recipe_id": "blueberry_muffin", "origin": [1, 3], "rotation": 0},
		{"instance_id": "cookie_1", "recipe_id": "butter_cookie", "origin": [4, 0], "rotation": 0},
		{"instance_id": "cookie_2", "recipe_id": "butter_cookie", "origin": [4, 1], "rotation": 0}
	]}
	view.call("set_draft_for_test", passing_draft)
	view.call("start_battle")
	view.call("advance_battle_for_test", 30000)
	await process_frame
	var final_battle: Dictionary = view.get("battle_state")
	_expect(String(final_battle.get("outcome", "")) == "victory", "reworked draft should win")
	_expect(int(final_battle.get("total_satisfaction", 0)) == 212, "winning draft should produce 212 total satisfaction")
	_expect(int(final_battle.get("pickiness", -1)) == 0, "winning draft should clear Boss pickiness")

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
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	if not _failures.has(message):
		_failures.append(message)


func _finish() -> void:
	_cleanup()
	if _failures.is_empty():
		print("CHALLENGE_MAIN_SCENE_SELF_CHECK_PASS")
		quit(0)
		return
	for message in _failures:
		push_error(message)
	quit(1)
