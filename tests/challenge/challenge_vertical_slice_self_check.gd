extends SceneTree

const ChallengeSaveService = preload("res://scripts/challenge/challenge_save_service.gd")
const ChallengeSessionService = preload("res://scripts/challenge/challenge_session_service.gd")

const ROOT_SCENE_PATH := "res://scenes/challenge/challenge_main.tscn"
const REQUIRED_RESOURCES := [
	"res://scripts/challenge/challenge_save_service.gd",
	"res://scripts/challenge/challenge_session_service.gd",
	"res://scripts/challenge/challenge_config_validator.gd",
	"res://scripts/challenge/challenge_loadout_service.gd",
	"res://scripts/challenge/boss_battle_service.gd",
	"res://scripts/challenge/boss_battle_report_service.gd",
	"res://scripts/challenge/boss_encounter_service.gd",
	"res://scripts/challenge/challenge_run_service.gd",
	"res://scripts/challenge/run_upgrade_service.gd",
	"res://scripts/challenge/recipe_research_service.gd",
	"res://scripts/challenge/challenge_tutorial_progress.gd",
	"res://scripts/challenge/challenge_main_view.gd",
	"res://scenes/challenge/challenge_hub_view.tscn",
	"res://scenes/challenge/challenge_preparation_view.tscn",
	"res://scenes/challenge/challenge_battle_view.tscn",
	"res://scenes/challenge/challenge_upgrade_select_view.tscn",
	"res://scenes/challenge/challenge_research_view.tscn",
	"res://scenes/challenge/challenge_run_summary_view.tscn",
	ROOT_SCENE_PATH
]
const REQUIRED_FILES := [
	"res://doc/challenge/challenge_recipes.json",
	"res://doc/challenge/boss_encounters.json",
	"res://doc/challenge/standard_run.json",
	"res://doc/challenge/run_upgrades.json",
	"res://doc/challenge/research_tree.json"
]
const FORBIDDEN_TOKENS := [
	"project_rest_new_save",
	"state.inventory",
	"display_items",
	"refill_item(",
	"production_queue",
	"RecipeBook.research",
	"production",
	"crafting",
	"inventory"
]

var _failures: Array[String] = []
var _save_path := OS.get_temp_dir().path_join(
	"project_rest_two_stage_two_boundary_self_check.json"
)
var _scanned_script_paths: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	_cleanup()
	for path in REQUIRED_RESOURCES:
		_expect(ResourceLoader.exists(path), "required challenge resource should exist: %s" % path)
	for path in REQUIRED_FILES:
		_expect(FileAccess.file_exists(path), "required challenge data should exist: %s" % path)
	if not _failures.is_empty():
		_finish()
		return

	var view = load(ROOT_SCENE_PATH).instantiate()
	view.save_path = _save_path
	root.add_child(view)
	await process_frame
	await process_frame
	_expect(view.get_node("Root/PageHost/HubHost").visible, "challenge opens at the hub")
	_expect(view.has_node("Root/GlobalTopBar/TutorialHelpButton"), "global tutorial help remains available")
	_expect(view.has_node("TutorialLayer/TutorialOverlay"), "root owns one tutorial overlay")
	_expect(
		view.has_node("SettlementDialog/TutorialOverlayHost/TutorialReportOverlay"),
		"settlement keeps its report-local guide"
	)

	var save_data := ChallengeSaveService.empty_save()
	var session = ChallengeSessionService.new()
	session.save_path = _save_path
	var created := session.create_standard_run(
		save_data,
		"standard_short_chain",
		42
	)
	_expect(bool(created.get("applied", false)), "current save can create a standard short chain")
	var current: Dictionary = created.get("save_data", {})
	var run: Dictionary = current.get("active_run", {})
	_expect(String(run.get("mode", "")) == "standard", "active run uses standard mode")
	_expect((run.get("encounter_instances", []) as Array).size() == 5, "standard route freezes five encounters")
	_expect(int(run.get("confidence", 0)) == 2, "standard route starts with two confidence")
	_expect(
		(current.get("meta", {}) as Dictionary).has("onboarding"),
		"onboarding lives under permanent meta"
	)
	_expect(not current.has("active_draft"), "deprecated top-level draft is absent")

	_scan_forbidden_tokens("res://scripts/challenge")
	_expect(
		_scanned_script_paths.has("res://scripts/challenge/challenge_session_service.gd"),
		"dependency scan covers the session coordinator"
	)
	_expect(
		_scanned_script_paths.has("res://scripts/challenge/ui/challenge_settlement_dialog.gd"),
		"dependency scan recursively covers challenge UI"
	)

	view.queue_free()
	await process_frame
	_finish()


func _scan_forbidden_tokens(directory_path: String) -> void:
	for file_name in DirAccess.get_files_at(directory_path):
		if not file_name.ends_with(".gd"):
			continue
		var path := directory_path.path_join(file_name)
		_scanned_script_paths.append(path)
		var text := FileAccess.get_file_as_string(path)
		for token in FORBIDDEN_TOKENS:
			_expect(
				text.find(token) == -1,
				"challenge code must not contain forbidden dependency token %s in %s" % [
					token,
					path
				]
			)
	for child_directory in DirAccess.get_directories_at(directory_path):
		_scan_forbidden_tokens(directory_path.path_join(child_directory))


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
		print("CHALLENGE_VERTICAL_SLICE_SELF_CHECK_PASS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
