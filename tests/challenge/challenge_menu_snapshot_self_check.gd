extends SceneTree

const SessionService = preload("res://scripts/challenge/challenge_session_service.gd")
const SaveService = preload("res://scripts/challenge/challenge_save_service.gd")

var _failures: Array[String] = []
var _path := OS.get_temp_dir().path_join("project_rest_two_menu_snapshot_self_check.json")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_cleanup()
	var session = SessionService.new()
	session.configure(
		_load_json("res://doc/challenge/challenge_recipes.json"),
		_load_json("res://doc/challenge/boss_encounters.json").get("encounters", {}),
		_load_json("res://doc/challenge/standard_run.json").get("routes", {}),
		_load_json("res://doc/challenge/run_upgrades.json").get("upgrades", {}),
		_load_json("res://doc/challenge/research_tree.json"),
		_path,
		_load_json("res://doc/challenge/endless_run.json")
	)
	var save := SaveService.empty_save()
	save["meta"]["unlocked_recipe_ids"] = [
		"butter_cookie", "strawberry_jelly", "milk_pudding", "blueberry_muffin",
		"sponge_cake", "chocolate_lava_cake", "vanilla_scone"
	]
	save["meta"]["active_menu_recipe_ids"] = [
		"butter_cookie", "strawberry_jelly", "milk_pudding", "blueberry_muffin",
		"sponge_cake", "vanilla_scone"
	]
	var created := session.create_standard_run(save, "standard_short_chain", 71)
	_expect(bool(created.get("applied", false)), "standard run should start from a valid six-recipe menu")
	var active_save: Dictionary = created.get("save_data", {})
	var run: Dictionary = active_save.get("active_run", {})
	var frozen_ids: Array = (run.get("permanent_pool_snapshot", {}) as Dictionary).get("recipe_ids", [])
	_expect(frozen_ids == save["meta"]["active_menu_recipe_ids"], "run snapshot should freeze the active menu order")
	var rejected := session.set_active_menu(
		active_save,
		["butter_cookie", "strawberry_jelly", "milk_pudding", "chocolate_lava_cake"]
	)
	_expect(not bool(rejected.get("applied", true)), "active run should lock menu editing")
	_expect(String(rejected.get("error", "")) == "active_run_menu_locked", "menu lock should have an explicit error")
	var still_frozen: Array = (
		((rejected.get("save_data", {}) as Dictionary).get("active_run", {}) as Dictionary)
		.get("permanent_pool_snapshot", {}) as Dictionary
	).get("recipe_ids", [])
	_expect(still_frozen == frozen_ids, "rejected edit should not mutate the active run snapshot")
	_cleanup()
	_finish()


func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Dictionary else {}


func _cleanup() -> void:
	for suffix in ["", ".tmp", ".previous", ".broken"]:
		if FileAccess.file_exists(_path + suffix):
			DirAccess.remove_absolute(_path + suffix)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("CHALLENGE_MENU_SNAPSHOT_SELF_CHECK_PASS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
