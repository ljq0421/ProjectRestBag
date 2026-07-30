extends SceneTree

const SERVICE_PATH := "res://scripts/challenge/challenge_loadout_service.gd"
const RECIPE_CONFIG_PATH := "res://doc/challenge/challenge_recipes.json"
const ENCOUNTER_CONFIG_PATH := "res://doc/challenge/boss_encounters.json"

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	if not FileAccess.file_exists(SERVICE_PATH):
		_fail("challenge loadout service should exist")
		_finish()
		return
	var service_script = load(SERVICE_PATH)
	_expect(service_script != null and service_script.can_instantiate(), "challenge loadout service should compile")
	if service_script == null or not service_script.can_instantiate():
		_finish()
		return
	var service = service_script.new()
	var recipe_config := _load_json(RECIPE_CONFIG_PATH)
	var encounter_config := _load_json(ENCOUNTER_CONFIG_PATH)
	var defs: Dictionary = recipe_config.get("recipes", {})
	var encounter: Dictionary = (encounter_config.get("encounters", {}) as Dictionary).get("picky_food_critic", {})

	var valid_draft := {"placements": [
		{"instance_id": "pudding_1", "recipe_id": "milk_pudding", "origin": [2, 2], "rotation": 0},
		{"instance_id": "muffin_1", "recipe_id": "blueberry_muffin", "origin": [2, 3], "rotation": 0}
	]}
	var valid: Dictionary = service.analyze(valid_draft, defs, 6, 8, 16, encounter)
	_expect(bool(valid.get("valid", false)), "adjacent set pair should be valid")
	_expect((valid.get("relations", []) as Array).size() == 1, "drink and bake pair should form one relation")
	var valid_instances: Array = valid.get("instances", [])
	if not valid_instances.is_empty():
		_expect(
			valid_instances[0].get("cells", []) == [[2, 2], [3, 2]],
			"shape coordinates (0,0),(0,1) should resolve as a vertical two-cell recipe"
		)
	var built: Dictionary = service.build_snapshot(valid_draft, defs, encounter, 6, 8, 16)
	_expect(bool(built.get("ok", false)), "valid draft should build a battle snapshot")
	var snapshot_text := JSON.stringify(built.get("snapshot", {}))
	_expect(snapshot_text.find("inventory") == -1, "snapshot must not contain inventory state")
	valid_draft["placements"].clear()
	_expect((built.get("snapshot", {}).get("instances", []) as Array).size() == 2, "snapshot should be isolated from later draft mutation")

	var overlap := {"placements": [
		{"instance_id": "a", "recipe_id": "sponge_cake", "origin": [0, 0], "rotation": 0},
		{"instance_id": "b", "recipe_id": "butter_cookie", "origin": [1, 1], "rotation": 0}
	]}
	var overlap_result: Dictionary = service.analyze(overlap, defs, 6, 8, 16, encounter)
	_expect(not bool(overlap_result.get("valid", true)), "overlap should be invalid")
	_expect(
		(overlap_result.get("errors", []) as Array).has("无法放置：目标格子已被其他配方占用"),
		"overlap placement error should be user-facing Chinese"
	)

	var out_of_bounds := {"placements": [
		{"instance_id": "edge", "recipe_id": "sponge_cake", "origin": [5, 7], "rotation": 0}
	]}
	var out_of_bounds_result: Dictionary = service.analyze(out_of_bounds, defs, 6, 8, 16, encounter)
	_expect(not bool(out_of_bounds_result.get("valid", true)), "out-of-bounds placement should be invalid")
	_expect(
		(out_of_bounds_result.get("errors", []) as Array).has("无法放置：配方会超出展示柜边界"),
		"out-of-bounds placement error should be user-facing Chinese"
	)

	var unknown := {"placements": [
		{"instance_id": "mystery", "recipe_id": "not_a_recipe", "origin": [0, 0], "rotation": 0}
	]}
	_expect(not bool(service.analyze(unknown, defs, 6, 8, 16, encounter).get("valid", true)), "unknown recipe should be invalid")

	var duplicate_instance := {"placements": [
		{"instance_id": "same", "recipe_id": "butter_cookie", "origin": [0, 0], "rotation": 0},
		{"instance_id": "same", "recipe_id": "strawberry_jelly", "origin": [0, 2], "rotation": 0}
	]}
	_expect(not bool(service.analyze(duplicate_instance, defs, 6, 8, 16, encounter).get("valid", true)), "duplicate instance ID should be invalid")

	var copy_overflow := {"placements": [
		{"instance_id": "p1", "recipe_id": "milk_pudding", "origin": [0, 0], "rotation": 0},
		{"instance_id": "p2", "recipe_id": "milk_pudding", "origin": [1, 0], "rotation": 0},
		{"instance_id": "p3", "recipe_id": "milk_pudding", "origin": [2, 0], "rotation": 0}
	]}
	_expect(not bool(service.analyze(copy_overflow, defs, 6, 8, 16, encounter).get("valid", true)), "copy-limit overflow should be invalid")

	var budget_overflow := {"placements": [
		{"instance_id": "cake", "recipe_id": "sponge_cake", "origin": [0, 0], "rotation": 0},
		{"instance_id": "lava", "recipe_id": "chocolate_lava_cake", "origin": [0, 3], "rotation": 0},
		{"instance_id": "p1", "recipe_id": "milk_pudding", "origin": [3, 0], "rotation": 0},
		{"instance_id": "p2", "recipe_id": "milk_pudding", "origin": [4, 0], "rotation": 0},
		{"instance_id": "cookie", "recipe_id": "butter_cookie", "origin": [5, 7], "rotation": 0}
	]}
	_expect(not bool(service.analyze(budget_overflow, defs, 6, 8, 16, encounter).get("valid", true)), "budget overflow should be invalid")

	var rotated := {"placements": [
		{"instance_id": "rotated_pudding", "recipe_id": "milk_pudding", "origin": [1, 1], "rotation": 90}
	]}
	var rotated_result: Dictionary = service.analyze(rotated, defs, 6, 8, 16, encounter)
	_expect(bool(rotated_result.get("valid", false)), "90-degree milk pudding rotation should be valid")
	var rotated_instances: Array = rotated_result.get("instances", [])
	if not rotated_instances.is_empty():
		_expect(rotated_instances[0].get("cells", []) == [[1, 1], [1, 2]], "90-degree rotation should produce a horizontal two-cell shape")

	var forbidden_rotation := {"placements": [
		{"instance_id": "square", "recipe_id": "sponge_cake", "origin": [0, 0], "rotation": 90}
	]}
	_expect(not bool(service.analyze(forbidden_rotation, defs, 6, 8, 16, encounter).get("valid", true)), "non-rotatable recipe should reject non-zero rotation")

	var angled := {"placements": [
		{"instance_id": "angled", "recipe_id": "milk_pudding", "origin": [0, 0], "rotation": 45}
	]}
	_expect(not bool(service.analyze(angled, defs, 6, 8, 16, encounter).get("valid", true)), "rotation not divisible by 90 should be invalid")

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
		print("CHALLENGE_LOADOUT_SERVICE_SELF_CHECK_PASS")
		quit(0)
		return
	for message in _failures:
		push_error(message)
	quit(1)
