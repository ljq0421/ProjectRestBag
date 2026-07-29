extends Node

const MAIN_SCENE := preload("res://scenes/challenge/challenge_main.tscn")
const SaveService := preload("res://scripts/challenge/challenge_save_service.gd")
const TutorialProgress := preload("res://scripts/challenge/challenge_tutorial_progress.gd")

var save_path := OS.get_temp_dir().path_join("project_rest_two_endless_visual_fixture.json")
var main: Control


func _ready() -> void:
	for suffix in ["", ".tmp", ".previous", ".broken", ".broken.previous"]:
		var path: String = save_path + String(suffix)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	var data: Dictionary = SaveService.empty_save()
	data["meta"]["onboarding"] = TutorialProgress.new().default_state()
	data["meta"]["onboarding"]["status"] = "completed"
	data["meta"]["onboarding"]["step_id"] = "complete"
	data["meta"]["onboarding"]["completed_step_ids"] = TutorialProgress.STEPS.duplicate()
	data["meta"]["endless_records"] = {
		"unlocked": true,
		"best_floor": 12,
		"best_snapshot": {"run_upgrades": []},
		"last_run_snapshot": {},
		"total_runs": 2,
		"standard_completion_count": 1,
		"standard_completion_run_ids": ["visual-standard"]
	}
	SaveService.save_to_path(save_path, data)
	main = MAIN_SCENE.instantiate()
	main.save_path = save_path
	add_child(main)


func show_preparation() -> void:
	if main.run_state.is_empty():
		main.start_endless_run(4242)
	main.get_node("TutorialLayer/TutorialOverlay").hide_step()
	main._show_preparation()


func show_battle() -> void:
	show_preparation()
	var encounter: Dictionary = main._session.current_encounter(main._save_data)
	main.set_draft_for_test(encounter.get("validation_draft", {}))
	main.start_battle()
	main.get_node("Root/PageHost/BattleView").set_paused(true)


func show_upgrade() -> void:
	show_battle()
	var encounter: Dictionary = main._session.current_encounter(main._save_data)
	main.advance_battle_for_test(int(encounter.get("duration_ms", 30000)))
	main.get_node("SettlementDialog").close_after_report_action()
	main._on_report_back()


func show_summary() -> void:
	show_upgrade()
	var run: Dictionary = (main._save_data.get("active_run", {}) as Dictionary).duplicate(true)
	run["phase"] = "run_failed"
	run["confidence"] = 0
	run["highest_cleared_floor"] = 12
	run["endless_record_finalized"] = true
	run["endless_rewarded"] = false
	main._save_data["active_run"] = run
	main._adopt({"save_data": main._save_data})
	main._show_summary()
