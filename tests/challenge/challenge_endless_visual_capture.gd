extends SceneTree

const MAIN_PATH := "res://scenes/challenge/challenge_main.tscn"
const SAVE_SERVICE_PATH := "res://scripts/challenge/challenge_save_service.gd"
const OUTPUT_DIR := "res://docs/superpowers/verification/2026-07-29-stage-4"

var _save_path := OS.get_temp_dir().path_join("project_rest_two_endless_visual_capture.json")
var _main: Control


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("visual capture requires a rendered editor run, not the headless display server")
		quit(1)
		return
	root.size = Vector2i(1920, 1080)
	_cleanup()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var save_service = load(SAVE_SERVICE_PATH)
	var save_data: Dictionary = save_service.empty_save()
	save_data["meta"]["endless_records"] = {
		"unlocked": true,
		"best_floor": 12,
		"best_snapshot": {"run_upgrades": []},
		"last_run_snapshot": {},
		"total_runs": 2,
		"standard_completion_count": 1,
		"standard_completion_run_ids": ["visual-standard"]
	}
	save_service.save_to_path(_save_path, save_data)
	_main = load(MAIN_PATH).instantiate()
	_main.save_path = _save_path
	root.add_child(_main)
	await _settle_frames()
	await _capture("01-hub-endless-1920x1080.png")

	_main.start_endless_run(4242)
	await _settle_frames()
	var overlay: Control = _main.get_node("TutorialLayer/TutorialOverlay")
	if overlay.visible:
		overlay.hide_step()
	await _settle_frames()
	await _capture("02-endless-preparation-1920x1080.png")

	var encounter: Dictionary = _main._session.current_encounter(_main._save_data)
	_main.set_draft_for_test(encounter.get("validation_draft", {}))
	_main.start_battle()
	await _settle_frames()
	await _capture("03-endless-battle-1920x1080.png")
	_main.advance_battle_for_test(12000)
	await _settle_frames()
	await _capture("04-endless-battle-pressure-1920x1080.png")
	_main.advance_battle_for_test(int(encounter.get("duration_ms", 30000)))
	await _settle_frames()
	await _capture("05-endless-report-1920x1080.png")
	_main.get_node("SettlementDialog/Margin/Content/ActionRow/BackButton").emit_signal("pressed")
	await _settle_frames()
	await _capture("06-endless-upgrade-1920x1080.png")

	var candidate: Button = _main.get_node("Root/PageHost/UpgradeHost/UpgradeSelectView/Content/Candidates/Candidate0")
	candidate.emit_signal("pressed")
	await _settle_frames()
	var run: Dictionary = (_main._save_data.get("active_run", {}) as Dictionary).duplicate(true)
	run["confidence"] = 1
	_main._save_data["active_run"] = run
	_main._adopt({"save_data": _main._save_data})
	_main._show_preparation()
	var floor_two: Dictionary = _main._session.current_encounter(_main._save_data)
	_main.set_draft_for_test(floor_two.get("validation_draft", {}))
	_main.start_battle()
	await _settle_frames()
	var losing: Dictionary = (_main._save_data.get("active_battle", {}) as Dictionary).duplicate(true)
	losing["phase"] = "finished"
	losing["outcome"] = "loss_timeout"
	_main._on_battle_finished(losing)
	await _settle_frames()
	_main.get_node("SettlementDialog/Margin/Content/ActionRow/BackButton").emit_signal("pressed")
	await _settle_frames()
	await _capture("07-endless-summary-1920x1080.png")
	print("CHALLENGE_ENDLESS_VISUAL_CAPTURE_PASS images=7")
	_main.queue_free()
	await process_frame
	_cleanup()
	quit(0)


func _capture(file_name: String) -> void:
	await process_frame
	var image := root.get_texture().get_image()
	if image.get_width() != 1920 or image.get_height() != 1080:
		push_error("unexpected capture size: %s" % image.get_size())
		quit(1)
		return
	var error := image.save_png(ProjectSettings.globalize_path(OUTPUT_DIR.path_join(file_name)))
	if error != OK:
		push_error("failed to save capture %s: %s" % [file_name, error_string(error)])
		quit(1)


func _settle_frames() -> void:
	await process_frame
	await process_frame
	await process_frame


func _cleanup() -> void:
	for suffix in ["", ".tmp", ".previous", ".broken", ".broken.previous"]:
		var path: String = _save_path + String(suffix)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
