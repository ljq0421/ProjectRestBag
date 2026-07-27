extends SceneTree

const ChallengeSaveService = preload("res://scripts/challenge/challenge_save_service.gd")
const ChallengeLoadoutService = preload("res://scripts/challenge/challenge_loadout_service.gd")
const BossBattleService = preload("res://scripts/challenge/boss_battle_service.gd")
const ChallengeRunService = preload("res://scripts/challenge/challenge_run_service.gd")
const ChallengeTutorialProgress = preload("res://scripts/challenge/challenge_tutorial_progress.gd")

const ROOT_SCENE_PATH := "res://scenes/challenge/challenge_main.tscn"
const REQUIRED_RESOURCES := [
	"res://scripts/challenge/challenge_save_service.gd",
	"res://scripts/challenge/challenge_config_validator.gd",
	"res://scripts/challenge/challenge_loadout_service.gd",
	"res://scripts/challenge/boss_battle_service.gd",
	"res://scripts/challenge/boss_battle_report_service.gd",
	"res://scripts/challenge/challenge_run_service.gd",
	"res://scripts/challenge/challenge_tutorial_progress.gd",
	"res://scripts/challenge/challenge_main_view.gd",
	"res://scripts/challenge/ui/challenge_supply_card.gd",
	"res://scripts/challenge/ui/challenge_board.gd",
	"res://scripts/challenge/ui/challenge_battle_view.gd",
	"res://scripts/challenge/ui/challenge_settlement_dialog.gd",
	"res://scripts/challenge/ui/challenge_tutorial_overlay.gd",
	"res://scenes/challenge/challenge_supply_card.tscn",
	"res://scenes/challenge/challenge_board.tscn",
	"res://scenes/challenge/challenge_battle_view.tscn",
	"res://scenes/challenge/challenge_settlement_dialog.tscn",
	"res://scenes/challenge/challenge_tutorial_overlay.tscn",
	"res://shaders/challenge/tutorial_spotlight.gdshader",
	ROOT_SCENE_PATH
]
const REQUIRED_FILES := [
	"res://doc/challenge/challenge_recipes.json",
	"res://doc/challenge/boss_encounters.json"
]
const FORBIDDEN_TOKENS := [
	"project_rest_new_save",
	"const TutorialProgress =",
	"tutorial_guide_overlay",
	"state.inventory",
	"display_items",
	"refill_item(",
	"production_queue",
	"RecipeBook.research",
	"purchase",
	"production",
	"crafting",
	"inventory"
]

var _failures: Array[String] = []
var _save_path := OS.get_temp_dir().path_join("project_rest_two_vertical_slice_self_check.json")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	_cleanup()
	for path in REQUIRED_RESOURCES:
		_expect(ResourceLoader.exists(path), "required Stage 1 resource should exist: %s" % path)
	for path in REQUIRED_FILES:
		_expect(FileAccess.file_exists(path), "required Stage 1 data file should exist: %s" % path)
	if not _failures.is_empty():
		_finish()
		return

	var root_scene = load(ROOT_SCENE_PATH)
	var view = root_scene.instantiate()
	view.set("save_path", _save_path)
	root.add_child(view)
	await process_frame
	await process_frame
	_expect(view.size.x >= 1920.0 and view.size.y >= 1080.0, "challenge root should fill 1920x1080 viewport")
	_expect(view.get_node("Root/Body/PreparationPanel").visible, "challenge root should open in preparation")
	_expect(view.has_node("Root/TopBar/TutorialHelpButton"), "default main scene exposes tutorial help")
	_expect(view.has_node("TutorialCanvasLayer/TutorialOverlay"), "default main scene owns the root tutorial overlay")
	_expect(view.has_node("SettlementDialog/TutorialReportOverlay"), "settlement should own a scene-local tutorial overlay")
	_expect(view.has_node("SettlementDialog/Margin/Content/ActionRow/TutorialHelpButton"), "settlement should expose a scene-local tutorial help entry")

	var recipe_config := _load_json("res://doc/challenge/challenge_recipes.json")
	var encounter_config := _load_json("res://doc/challenge/boss_encounters.json")
	var defs: Dictionary = recipe_config.get("recipes", {})
	var encounter: Dictionary = (encounter_config.get("encounters", {}) as Dictionary).get("picky_food_critic", {})
	var passing_draft := {"placements": [
		{"instance_id": "pudding_1", "recipe_id": "milk_pudding", "origin": [0, 0], "rotation": 0},
		{"instance_id": "muffin_1", "recipe_id": "blueberry_muffin", "origin": [1, 0], "rotation": 0},
		{"instance_id": "pudding_2", "recipe_id": "milk_pudding", "origin": [0, 3], "rotation": 0},
		{"instance_id": "muffin_2", "recipe_id": "blueberry_muffin", "origin": [1, 3], "rotation": 0},
		{"instance_id": "cookie_1", "recipe_id": "butter_cookie", "origin": [4, 0], "rotation": 0},
		{"instance_id": "cookie_2", "recipe_id": "butter_cookie", "origin": [4, 1], "rotation": 0}
	]}
	var loadout_service = ChallengeLoadoutService.new()
	var built: Dictionary = loadout_service.build_snapshot(passing_draft, defs, encounter, 6, 8, 16)
	_expect(bool(built.get("ok", false)), "valid aggregate loadout should build a snapshot")
	var snapshot: Dictionary = built.get("snapshot", {})
	_expect(int(snapshot.get("spent_budget", 0)) == 16, "aggregate loadout should spend exactly 16 supply")
	_expect((snapshot.get("relations", []) as Array).size() == 2, "aggregate loadout should form two relations")

	var battle_service = BossBattleService.new()
	var first: Dictionary = battle_service.simulate(snapshot, encounter, 42)
	var second: Dictionary = battle_service.simulate(snapshot, encounter, 42)
	_expect(first.get("events", []) == second.get("events", []), "aggregate simulation should be deterministic")
	_expect(first.get("outcome") == "victory", "aggregate passing loadout should win")
	_expect(int(first.get("total_satisfaction", 0)) == 212, "aggregate passing loadout should produce 212 satisfaction")

	var fast_built: Dictionary = loadout_service.build_snapshot(
		{"placements": [
			{"instance_id": "c1", "recipe_id": "butter_cookie", "origin": [0, 0], "rotation": 0},
			{"instance_id": "c2", "recipe_id": "butter_cookie", "origin": [0, 2], "rotation": 0},
			{"instance_id": "c3", "recipe_id": "butter_cookie", "origin": [0, 4], "rotation": 0},
			{"instance_id": "j1", "recipe_id": "strawberry_jelly", "origin": [2, 0], "rotation": 0},
			{"instance_id": "j2", "recipe_id": "strawberry_jelly", "origin": [2, 2], "rotation": 0},
			{"instance_id": "j3", "recipe_id": "strawberry_jelly", "origin": [2, 4], "rotation": 0}
		]},
		defs,
		encounter,
		6,
		8,
		16
	)
	var fast_result: Dictionary = battle_service.simulate(fast_built.get("snapshot", {}), encounter, 42)
	_expect(fast_result.get("outcome") == "loss_timeout", "fast-only build should expose a total-satisfaction timeout")
	_expect(int(fast_result.get("total_satisfaction", 0)) == 147, "fast-only build should produce 147 satisfaction")

	var signature_built: Dictionary = loadout_service.build_snapshot(
		{"placements": [
			{"instance_id": "sponge", "recipe_id": "sponge_cake", "origin": [0, 0], "rotation": 0},
			{"instance_id": "lava", "recipe_id": "chocolate_lava_cake", "origin": [0, 3], "rotation": 0},
			{"instance_id": "c1", "recipe_id": "butter_cookie", "origin": [3, 0], "rotation": 0},
			{"instance_id": "c2", "recipe_id": "butter_cookie", "origin": [3, 2], "rotation": 0},
			{"instance_id": "c3", "recipe_id": "butter_cookie", "origin": [3, 4], "rotation": 0}
		]},
		defs,
		encounter,
		6,
		8,
		16
	)
	var signature_result: Dictionary = battle_service.simulate(signature_built.get("snapshot", {}), encounter, 42)
	_expect(signature_result.get("outcome") == "victory", "signature build should win despite missing the relation window")
	_expect(int(signature_result.get("total_satisfaction", 0)) == 225, "signature build should produce 225 satisfaction")
	_expect(
		not bool((signature_result.get("resolved_windows", {}) as Dictionary).get("linked_display", {}).get("passed", true)),
		"signature build should make a distinct no-relation tradeoff"
	)

	var losing_built: Dictionary = loadout_service.build_snapshot(
		{"placements": [{"instance_id": "cookie_only", "recipe_id": "butter_cookie", "origin": [0, 0], "rotation": 0}]},
		defs,
		encounter,
		6,
		8,
		16
	)
	var loss: Dictionary = battle_service.simulate(losing_built.get("snapshot", {}), encounter, 42)
	_expect(String(loss.get("outcome", "")).begins_with("loss_"), "aggregate deliberate weak loadout should lose")

	var run_service = ChallengeRunService.new()
	var run: Dictionary = run_service.create_single_encounter("aggregate-run", 42, "picky_food_critic")
	var registered_loss: Dictionary = run_service.register_result(run, {
		"settlement_id": "aggregate-loss",
		"outcome": String(loss.get("outcome", "")),
		"encounter_id": "picky_food_critic"
	})
	var retry_run: Dictionary = registered_loss.get("run", {})
	_expect(int(retry_run.get("confidence", 0)) == 1, "aggregate retry should retain confidence 1")
	_expect(retry_run.get("phase") == "preparation", "aggregate retry should return to preparation")
	var registered_victory: Dictionary = run_service.register_result(retry_run, {
		"settlement_id": "aggregate-victory",
		"outcome": "victory",
		"encounter_id": "picky_food_critic"
	})
	_expect((registered_victory.get("run", {}) as Dictionary).get("phase") == "completed", "aggregate retry victory should complete run")

	var save_data := ChallengeSaveService.empty_save()
	_expect(
		int((save_data.get("onboarding", {}) as Dictionary).get("version", 0)) == 1,
		"default challenge save contains onboarding version 1"
	)
	save_data["active_run"] = retry_run
	save_data["active_battle"] = battle_service.create_state(snapshot, encounter, 42)
	var saved: Dictionary = ChallengeSaveService.save_to_path(_save_path, save_data)
	_expect(bool(saved.get("ok", false)), "aggregate save should succeed")
	var loaded: Dictionary = ChallengeSaveService.load_from_path(_save_path)
	_expect(bool(loaded.get("ok", false)), "aggregate save should load")
	var loaded_data: Dictionary = loaded.get("data", {})
	_expect((loaded_data.get("active_run", {}) as Dictionary).get("encounter_id") == "picky_food_critic", "save round trip should preserve encounter")
	_expect((loaded_data.get("active_battle", {}) as Dictionary).get("phase") == "running", "save round trip should preserve active battle")

	var tutorial = ChallengeTutorialProgress.new()
	var first_tutorial_state := tutorial.default_state()
	var second_tutorial_state := tutorial.default_state()
	for event_id in ["boss_acknowledged"]:
		first_tutorial_state = tutorial.apply_event(first_tutorial_state, event_id)
		second_tutorial_state = tutorial.apply_event(second_tutorial_state, event_id)
	_expect(first_tutorial_state == second_tutorial_state, "identical tutorial input events produce identical progress state")

	_scan_forbidden_tokens("res://scripts/challenge")

	view.queue_free()
	await process_frame
	_finish()


func _scan_forbidden_tokens(directory_path: String) -> void:
	for file_name in DirAccess.get_files_at(directory_path):
		if not file_name.ends_with(".gd"):
			continue
		var path := directory_path.path_join(file_name)
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			_fail("forbidden-token scan could not read: %s" % path)
			continue
		var text := file.get_as_text()
		file.close()
		for token in FORBIDDEN_TOKENS:
			_expect(text.find(token) == -1, "challenge code must not contain forbidden dependency token %s in %s" % [token, path])
	for child_directory in DirAccess.get_directories_at(directory_path):
		_scan_forbidden_tokens(directory_path.path_join(child_directory))


func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_fail("could not open JSON: %s" % path)
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		_fail("JSON root should be a dictionary: %s" % path)
		return {}
	return parsed


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
		print("CHALLENGE_VERTICAL_SLICE_SELF_CHECK_PASS")
		quit(0)
		return
	for message in _failures:
		push_error(message)
	quit(1)
