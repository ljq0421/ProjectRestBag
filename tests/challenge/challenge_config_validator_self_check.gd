extends SceneTree

const Catalog = preload("res://scripts/catalog.gd")
const VALIDATOR_PATH := "res://scripts/challenge/challenge_config_validator.gd"
const RECIPE_CONFIG_PATH := "res://doc/challenge/challenge_recipes.json"
const ENCOUNTER_CONFIG_PATH := "res://doc/challenge/boss_encounters.json"

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	for path in [VALIDATOR_PATH, RECIPE_CONFIG_PATH, ENCOUNTER_CONFIG_PATH]:
		if not FileAccess.file_exists(path):
			_fail("required challenge config file should exist: %s" % path)
	if not _failures.is_empty():
		_finish()
		return

	var validator_script = load(VALIDATOR_PATH)
	_expect(validator_script != null, "challenge config validator should load")
	_expect(validator_script != null and validator_script.can_instantiate(), "challenge config validator should compile")
	if validator_script == null or not validator_script.can_instantiate():
		_finish()
		return
	var validator = validator_script.new()

	var missing_recipe: Dictionary = validator.validate(
		{
			"grid_rows": 6,
			"grid_columns": 8,
			"supply_budget": 16,
			"starter_recipe_ids": ["not_in_catalog"],
			"research_recipe_ids": ["also_not_in_catalog"],
			"recipes": {
				"not_in_catalog": _valid_recipe(),
				"also_not_in_catalog": _valid_recipe()
			}
		},
		{"encounters": {"critic": _valid_encounter()}},
		{}
	)
	_expect(not bool(missing_recipe.get("valid", true)), "unknown catalog recipe should be invalid")

	var bad_window: Dictionary = _valid_encounter()
	bad_window["windows"][1]["at_ms"] = 8000
	var bad_order: Dictionary = validator.validate(
		_valid_recipe_config(),
		{"encounters": {"critic": bad_window}},
		{"butter_cookie": {}, "strawberry_jelly": {}}
	)
	_expect(not bool(bad_order.get("valid", true)), "demand windows should be strictly ordered")

	var tag_metrics_encounter: Dictionary = _valid_encounter()
	tag_metrics_encounter["windows"] = [
		{
			"id": "fast_sales",
			"at_ms": 8000,
			"metric": "tag_sales_count",
			"tag": "fast",
			"target": 1,
			"reputation_damage": 25
		},
		{
			"id": "fast_satisfaction",
			"at_ms": 16000,
			"from_ms": 8000,
			"metric": "tag_satisfaction",
			"tag": "fast",
			"target": 4,
			"reputation_damage": 30
		},
		{
			"id": "tag_variety",
			"at_ms": 24000,
			"metric": "distinct_tag_count",
			"target_tags": ["fast", "bake"],
			"target": 2,
			"reputation_damage": 45
		}
	]
	var tag_metrics_result: Dictionary = validator.validate(
		_valid_recipe_config(),
		{"encounters": {"critic": tag_metrics_encounter}},
		{"butter_cookie": {}, "strawberry_jelly": {}}
	)
	for error in tag_metrics_result.get("errors", []):
		_fail("valid tag metric encounter should validate: %s" % String(error))
	_expect(bool(tag_metrics_result.get("valid", false)), "new tag metrics should be theoretically reachable")

	var missing_tag_encounter: Dictionary = tag_metrics_encounter.duplicate(true)
	missing_tag_encounter["windows"][0].erase("tag")
	var missing_tag_result: Dictionary = validator.validate(
		_valid_recipe_config(),
		{"encounters": {"critic": missing_tag_encounter}},
		{"butter_cookie": {}, "strawberry_jelly": {}}
	)
	_expect(not bool(missing_tag_result.get("valid", true)), "tag metric without tag should be invalid")

	var duplicate_target_tags: Dictionary = tag_metrics_encounter.duplicate(true)
	duplicate_target_tags["windows"][2]["target_tags"] = ["fast", "fast"]
	var duplicate_tags_result: Dictionary = validator.validate(
		_valid_recipe_config(),
		{"encounters": {"critic": duplicate_target_tags}},
		{"butter_cookie": {}, "strawberry_jelly": {}}
	)
	_expect(not bool(duplicate_tags_result.get("valid", true)), "distinct tag metric should reject duplicate target tags")

	var recipe_config: Dictionary = _load_json(RECIPE_CONFIG_PATH)
	var encounter_config: Dictionary = _load_json(ENCOUNTER_CONFIG_PATH)
	var catalog_recipes: Dictionary = Catalog.new().get_recipes()
	var result: Dictionary = validator.validate(recipe_config, encounter_config, catalog_recipes)
	for error in result.get("errors", []):
		_fail("committed challenge config should validate: %s" % String(error))
	_expect(bool(result.get("valid", false)), "committed challenge config should be valid")

	var recipes: Dictionary = recipe_config.get("recipes", {})
	_expect(recipes.size() == 166, "committed challenge config should contain all 166 recipes")
	_expect((recipe_config.get("starter_recipe_ids", []) as Array).size() == 6, "challenge config should contain six starter recipes")
	_expect((recipe_config.get("research_recipe_ids", []) as Array).size() == 160, "challenge config should contain 160 research recipes")
	_expect(int(recipe_config.get("grid_rows", 0)) == 8, "challenge grid should reserve eight rows")
	_expect(int(recipe_config.get("grid_columns", 0)) == 14, "challenge grid should reserve fourteen columns")
	_expect(int(recipe_config.get("supply_budget", 0)) == 16, "challenge supply budget should be 16")
	for recipe_id in recipes:
		_expect(catalog_recipes.has(recipe_id), "challenge recipe should exist in Catalog: %s" % String(recipe_id))

	var encounters: Dictionary = encounter_config.get("encounters", {})
	_expect(encounters.size() == 15, "committed challenge config should contain three five-stage routes")
	var critic: Dictionary = encounters.get("picky_food_critic", {})
	var window_times: Array[int] = []
	for window in critic.get("windows", []):
		window_times.append(int(window.get("at_ms", 0)))
	_expect(window_times == [8000, 16000, 24000], "Boss windows should be exactly 8s, 16s, and 24s")
	_expect(int(critic.get("duration_ms", 0)) == 30000, "Boss final time should be 30 seconds")

	_finish()


func _valid_recipe() -> Dictionary:
	return {
		"shape_cells": [[0, 0]],
		"supply_cost": 2,
		"copy_limit": 1,
		"virtual_stock": 6,
		"cycle_ms": 4000,
		"satisfaction": 4,
		"tags": ["fast", "bake"],
		"rotatable": false
	}


func _valid_recipe_config() -> Dictionary:
	return {
		"grid_rows": 6,
		"grid_columns": 8,
		"supply_budget": 16,
		"starter_recipe_ids": ["butter_cookie"],
		"research_recipe_ids": ["strawberry_jelly"],
		"recipes": {
			"butter_cookie": _valid_recipe(),
			"strawberry_jelly": _valid_recipe()
		}
	}


func _valid_encounter() -> Dictionary:
	return {
		"id": "critic",
		"display_name": "Test Critic",
		"encounter_type": "normal",
		"rule_tags": ["early_tempo"],
		"required_mechanism_tags": ["timed_sales"],
		"blueprint_hint_id": "blueprint_test",
		"duration_ms": 30000,
		"supply_budget": 16,
		"initial_pickiness": 4,
		"initial_reputation": 100,
		"relation_bonus_pct": 25,
		"relation": {
			"id": "drink_bake_pair",
			"left_tag": "drink",
			"right_tag": "bake"
		},
		"windows": [
			{"id": "early_tempo", "at_ms": 8000, "metric": "sales_count", "target": 1, "reputation_damage": 25},
			{"id": "linked_display", "at_ms": 16000, "metric": "active_relation_count", "target": 0, "reputation_damage": 30},
			{"id": "sustained_service", "at_ms": 24000, "from_ms": 16000, "metric": "window_satisfaction", "target": 1, "reputation_damage": 45}
		],
		"validation_draft": {
			"placements": [
				{"instance_id": "cookie", "recipe_id": "butter_cookie", "origin": [0, 0], "rotation": 0}
			]
		}
	}


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
		print("CHALLENGE_CONFIG_VALIDATOR_SELF_CHECK_PASS")
		quit(0)
		return
	for message in _failures:
		push_error(message)
	quit(1)
