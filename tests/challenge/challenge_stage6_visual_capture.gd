extends SceneTree

const MAIN_PATH := "res://scenes/challenge/challenge_main.tscn"
const SaveService = preload("res://scripts/challenge/challenge_save_service.gd")
const TutorialProgress = preload("res://scripts/challenge/challenge_tutorial_progress.gd")
const OUTPUT_DIR := "res://docs/superpowers/verification/2026-07-29-stage-5-6"

var _save_path := OS.get_temp_dir().path_join("project_rest_two_stage6_visual_capture.json")
var _main: Control


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("stage 6 visual capture requires a rendered display server")
		quit(1)
		return
	root.size = Vector2i(1920, 1080)
	_cleanup()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var save := SaveService.empty_save()
	var tutorial := TutorialProgress.new().default_state()
	tutorial["status"] = "completed"
	tutorial["step_id"] = "complete"
	tutorial["completed_step_ids"] = TutorialProgress.STEPS.duplicate()
	tutorial["seen_stage_two_hint_ids"] = TutorialProgress.STAGE_TWO_HINTS.duplicate()
	save["meta"]["onboarding"] = tutorial
	save["meta"]["research_points"] = 10
	save["meta"]["revealed_research_node_ids"] = [
		"vanilla_scone", "chocolate_cookie", "blueberry_mousse",
		"strawberry_mousse", "cream_shortcake", "caramel_mousse"
	]
	SaveService.save_to_path(_save_path, save)
	_main = load(MAIN_PATH).instantiate()
	_main.save_path = _save_path
	root.add_child(_main)
	await _settle()

	_main._show_menu()
	_main.get_node("TutorialLayer/TutorialOverlay").hide_step()
	await _settle()
	await _capture("01-menu-editor-1920x1080.png")

	_main._show_research()
	_main.get_node("TutorialLayer/TutorialOverlay").hide_step()
	await _settle()
	await _capture("02-research-tree-1920x1080.png")

	_main._show_hub()
	_main.start_new_run(606)
	_main.get_node("TutorialLayer/TutorialOverlay").hide_step()
	await _settle()
	await _capture("03-grouped-preparation-1920x1080.png")

	print("CHALLENGE_STAGE6_VISUAL_CAPTURE_PASS images=3")
	_main.queue_free()
	await process_frame
	_cleanup()
	quit(0)


func _capture(file_name: String) -> void:
	await process_frame
	var image := root.get_texture().get_image()
	if image.get_width() != 1920 or image.get_height() != 1080:
		push_error("unexpected stage 6 capture size: %s" % image.get_size())
		quit(1)
		return
	var output_path := ProjectSettings.globalize_path(OUTPUT_DIR.path_join(file_name))
	var error := image.save_png(output_path)
	if error != OK:
		push_error("failed to save stage 6 capture: %s" % error_string(error))
		quit(1)


func _settle() -> void:
	await process_frame
	await process_frame
	await process_frame


func _cleanup() -> void:
	for suffix in ["", ".tmp", ".previous", ".broken", ".broken.previous"]:
		if FileAccess.file_exists(_save_path + suffix):
			DirAccess.remove_absolute(_save_path + suffix)
