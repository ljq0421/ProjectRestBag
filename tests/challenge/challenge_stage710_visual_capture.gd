extends SceneTree

const MAIN_PATH := "res://scenes/challenge/challenge_main.tscn"
const SaveService = preload("res://scripts/challenge/challenge_save_service.gd")
const TutorialProgress = preload("res://scripts/challenge/challenge_tutorial_progress.gd")
const OUTPUT_DIR := "res://docs/superpowers/verification/2026-07-29-stage-7-10"

var _save_path := OS.get_temp_dir().path_join("project_rest_two_stage710_visual_capture.json")
var _main: Control


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("stage 7-10 visual capture requires a rendered display server")
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
	var recipe_config := _json("res://doc/challenge/challenge_recipes.json")
	var tree := _json("res://doc/challenge/research_tree.json")
	save["meta"]["onboarding"] = tutorial
	save["meta"]["research_points"] = 999
	save["meta"]["unlocked_recipe_ids"] = recipe_config.get("recipes", {}).keys()
	save["meta"]["revealed_research_node_ids"] = tree.get("nodes", {}).keys()
	save["meta"]["route_first_clear_ids"] = ["standard_short_chain", "flavor_texture_route"]
	save["meta"]["unlocked_route_ids"] = [
		"standard_short_chain", "flavor_texture_route", "grand_composition_route"
	]
	save["meta"]["completed_mastery_ids"] = ["route_a_first_clear", "route_b_first_clear"]
	save["meta"]["active_menu_recipe_ids"] = [
		"egg_milk_custard", "caramel_pudding_steamed", "rich_rice_drink",
		"milk_pudding", "butter_cookie", "sponge_cake"
	]
	SaveService.save_to_path(_save_path, save)
	_main = load(MAIN_PATH).instantiate()
	_main.save_path = _save_path
	root.add_child(_main)
	await _settle()

	_main._show_hub()
	_hide_tutorial()
	await _settle()
	var route_selector: OptionButton = _main.get_node(
		"Root/PageHost/HubHost/HubView/Content/RouteRow/RouteSelector"
	)
	route_selector.show_popup()
	await _settle()
	await _capture("01-three-route-hub-1920x1080.png")

	_main._show_menu()
	_hide_tutorial()
	await _settle()
	await _capture("02-complete-menu-1920x1080.png")

	_main._show_research()
	_hide_tutorial()
	await _settle()
	await _capture("03-eight-branch-research-1920x1080.png")

	_main._show_hub()
	_main._selected_route_id = "flavor_texture_route"
	_main.start_new_run(710)
	_hide_tutorial()
	await _settle()
	await _capture("04-route-b-preparation-1920x1080.png")

	print("CHALLENGE_STAGE710_VISUAL_CAPTURE_PASS images=4")
	_main.queue_free()
	await process_frame
	_cleanup()
	quit(0)


func _hide_tutorial() -> void:
	_main.get_node("TutorialLayer/TutorialOverlay").hide_step()


func _capture(file_name: String) -> void:
	await process_frame
	var image := root.get_texture().get_image()
	if image.get_width() != 1920 or image.get_height() != 1080:
		push_error("unexpected stage 7-10 capture size: %s" % image.get_size())
		quit(1)
		return
	var output_path := ProjectSettings.globalize_path(OUTPUT_DIR.path_join(file_name))
	var error := image.save_png(output_path)
	if error != OK:
		push_error("failed to save stage 7-10 capture: %s" % error_string(error))
		quit(1)


func _settle() -> void:
	await process_frame
	await process_frame
	await process_frame


func _json(path: String) -> Dictionary:
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return value if value is Dictionary else {}


func _cleanup() -> void:
	for suffix in ["", ".tmp", ".previous", ".broken", ".broken.previous"]:
		var path: String = _save_path + String(suffix)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
