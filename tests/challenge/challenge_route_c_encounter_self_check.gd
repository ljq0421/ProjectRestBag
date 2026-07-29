extends SceneTree

const EncounterService = preload("res://scripts/challenge/boss_encounter_service.gd")
var failures: Array[String] = []

func _init() -> void:
	var routes: Dictionary = _load("res://doc/challenge/standard_run.json").get("routes", {})
	var encounters: Dictionary = _load("res://doc/challenge/boss_encounters.json").get("encounters", {})
	var recipes: Dictionary = _load("res://doc/challenge/challenge_recipes.json")
	var result: Dictionary = EncounterService.new().validate_route(
		routes.get("grand_composition_route", {}), encounters, recipes.get("recipes", {}), recipes.get("starter_recipe_ids", [])
	)
	for error in result.get("errors", []): failures.append(String(error))
	_expect(bool(result.get("valid", false)), "route C should validate with guaranteed starter menu")
	_finish()

func _load(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ); var value: Variant = JSON.parse_string(file.get_as_text()); file.close()
	return value if value is Dictionary else {}
func _expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
func _finish() -> void:
	if failures.is_empty(): print("CHALLENGE_ROUTE_C_ENCOUNTER_SELF_CHECK_PASS"); quit(0); return
	for failure in failures: push_error(failure)
	quit(1)
