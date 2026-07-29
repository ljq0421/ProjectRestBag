extends SceneTree

const SERVICE_PATH := "res://scripts/challenge/boss_encounter_service.gd"
const ROUTE_CONFIG_PATH := "res://doc/challenge/standard_run.json"
const RECIPE_CONFIG_PATH := "res://doc/challenge/challenge_recipes.json"
const ENCOUNTER_CONFIG_PATH := "res://doc/challenge/boss_encounters.json"
const EXPECTED_IDS := [
	"morning_rush",
	"pairing_tasting",
	"afternoon_wave",
	"weekend_feature",
	"picky_food_critic"
]
const EXPECTED_TYPES := ["normal", "normal", "normal", "elite", "final_boss"]

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	for path in [SERVICE_PATH, ROUTE_CONFIG_PATH, RECIPE_CONFIG_PATH, ENCOUNTER_CONFIG_PATH]:
		if not FileAccess.file_exists(path):
			_fail("required file should exist: %s" % path)
	if not _failures.is_empty():
		_finish()
		return

	var service_script = load(SERVICE_PATH)
	_expect(service_script != null, "boss encounter service should load")
	_expect(service_script != null and service_script.can_instantiate(), "boss encounter service should compile")
	if service_script == null or not service_script.can_instantiate():
		_finish()
		return
	var service = service_script.new()

	var route_config := _load_json(ROUTE_CONFIG_PATH)
	var recipe_config := _load_json(RECIPE_CONFIG_PATH)
	var encounter_config := _load_json(ENCOUNTER_CONFIG_PATH)
	var route: Dictionary = (route_config.get("routes", {}) as Dictionary).get("standard_short_chain", {})
	var recipe_defs: Dictionary = recipe_config.get("recipes", {})
	var starter_pool: Array = recipe_config.get("starter_recipe_ids", [])
	var encounter_defs: Dictionary = encounter_config.get("encounters", {})

	var validation: Dictionary = service.validate_route(route, encounter_defs, recipe_defs, starter_pool)
	for error in validation.get("errors", []):
		_fail("committed standard route should validate: %s" % String(error))
	_expect(bool(validation.get("valid", false)), "all validation drafts should win through the real battle services")

	var created: Dictionary = service.create_standard_encounters(
		"standard:test:424242",
		424242,
		route,
		encounter_defs,
		starter_pool
	)
	_expect(bool(created.get("ok", false)), "standard encounters should be created")
	var instances: Array = created.get("encounter_instances", [])
	_expect(instances.size() == 5, "standard route should create exactly five encounter instances")
	for stage_index in instances.size():
		var instance: Dictionary = instances[stage_index]
		_expect(String(instance.get("id", "")) == EXPECTED_IDS[stage_index], "encounter order should be fixed")
		_expect(String(instance.get("encounter_id", "")) == EXPECTED_IDS[stage_index], "run service encounter ID should be explicit")
		_expect(String(instance.get("encounter_type", "")) == EXPECTED_TYPES[stage_index], "encounter type order should be fixed")
		_expect(int(instance.get("stage_index", -1)) == stage_index, "instance should preserve its stage index")
		_expect(
			String(instance.get("encounter_instance_id", "")) == "standard:test:424242:stage:%d" % stage_index,
			"encounter instance identity should be stable"
		)
		_expect(instance.get("validation_draft") is Dictionary, "frozen instance should contain its validation draft")
		_expect(not String(instance.get("blueprint_hint_id", "")).is_empty(), "frozen instance should contain its blueprint hint")

	var recreated: Dictionary = service.create_standard_encounters(
		"standard:test:424242",
		424242,
		route,
		encounter_defs,
		starter_pool
	)
	_expect(
		JSON.stringify(created.get("encounter_instances", [])) ==
		JSON.stringify(recreated.get("encounter_instances", [])),
		"same run seed and route should create byte-equivalent encounter instances"
	)

	var stage_two_before: Dictionary = service.encounter_for_stage(instances, 2)
	var original_name := String(stage_two_before.get("display_name", ""))
	encounter_defs["afternoon_wave"]["display_name"] = "mutated source definition"
	var stage_two_after: Dictionary = service.encounter_for_stage(instances, 2)
	_expect(
		String(stage_two_after.get("display_name", "")) == original_name,
		"locked encounter should be isolated from later config mutation"
	)
	stage_two_after["display_name"] = "mutated caller copy"
	_expect(
		String(service.encounter_for_stage(instances, 2).get("display_name", "")) == original_name,
		"encounter lookup should not expose the locked instance for mutation"
	)
	_expect(
		int(stage_two_before.get("encounter_seed", -1)) ==
		int(service.encounter_for_stage(instances, 2).get("encounter_seed", -2)),
		"retry lookup should reuse the locked encounter seed"
	)
	_expect(
		int(stage_two_before.get("reward_seed", -1)) ==
		int(service.encounter_for_stage(instances, 2).get("reward_seed", -2)),
		"retry lookup should reuse the locked reward seed"
	)

	var bad_route: Dictionary = route.duplicate(true)
	bad_route["stages"][3]["encounter_type"] = "normal"
	_expect(
		not bool(service.validate_route(bad_route, encounter_defs, recipe_defs, starter_pool).get("valid", true)),
		"route should reject an incorrect elite stage type"
	)

	var bad_encounters: Dictionary = encounter_defs.duplicate(true)
	bad_encounters["morning_rush"]["required_mechanism_tags"] = ["unknown_mechanism"]
	_expect(
		not bool(service.validate_route(route, bad_encounters, recipe_defs, starter_pool).get("valid", true)),
		"route should reject an unknown mechanism tag"
	)

	_finish()


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


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	if not _failures.has(message):
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("BOSS_ENCOUNTER_SERVICE_SELF_CHECK_PASS")
		quit(0)
		return
	for message in _failures:
		push_error(message)
	quit(1)
