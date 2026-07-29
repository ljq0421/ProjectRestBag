class_name BossEncounterService
extends RefCounted

const ChallengeLoadoutServiceScript = preload("res://scripts/challenge/challenge_loadout_service.gd")
const BossBattleServiceScript = preload("res://scripts/challenge/boss_battle_service.gd")

const EXPECTED_TYPES := ["normal", "normal", "normal", "elite", "final_boss"]
const KNOWN_RULE_TAGS := [
	"early_tempo",
	"pairing_focus",
	"sustained_service",
	"mixed_windows",
	"tight_budget",
	"combined_exam"
]
const KNOWN_MECHANISM_TAGS := [
	"timed_sales",
	"adjacency_relation",
	"window_satisfaction",
	"supply_budget"
]


func validate_route(
	route_def: Dictionary,
	encounter_defs: Dictionary,
	recipe_defs: Dictionary,
	starter_pool: Variant
) -> Dictionary:
	var errors: Array[String] = []
	var route_id := String(route_def.get("id", "")).strip_edges()
	if route_id.is_empty():
		errors.append("route: id must be a non-empty string")
	if String(route_def.get("display_name", "")).strip_edges().is_empty():
		errors.append("%s: display_name must be a non-empty string" % _label(route_id, "route"))
	var rows := _positive_int(route_def.get("grid_rows"))
	var columns := _positive_int(route_def.get("grid_columns"))
	var default_budget := _positive_int(route_def.get("supply_budget"))
	if rows <= 0:
		errors.append("%s: grid_rows must be a positive integer" % _label(route_id, "route"))
	if columns <= 0:
		errors.append("%s: grid_columns must be a positive integer" % _label(route_id, "route"))
	if default_budget <= 0:
		errors.append("%s: supply_budget must be a positive integer" % _label(route_id, "route"))

	var available_recipe_ids := _pool_ids(starter_pool)
	if available_recipe_ids.is_empty():
		errors.append("%s: starter pool must not be empty" % _label(route_id, "route"))
	for recipe_id in available_recipe_ids:
		if not recipe_defs.has(recipe_id) or not recipe_defs[recipe_id] is Dictionary:
			errors.append("%s: starter pool contains unknown recipe %s" % [_label(route_id, "route"), recipe_id])

	var stages_value = route_def.get("stages")
	if not stages_value is Array or stages_value.size() != EXPECTED_TYPES.size():
		errors.append("%s: stages must contain exactly five entries" % _label(route_id, "route"))
		return {"valid": false, "errors": errors}

	var seen_encounter_ids := {}
	var loadout_service = ChallengeLoadoutServiceScript.new()
	var battle_service = BossBattleServiceScript.new()
	for stage_index in EXPECTED_TYPES.size():
		var stage_value = stages_value[stage_index]
		var prefix := "%s.stage_%d" % [_label(route_id, "route"), stage_index]
		if not stage_value is Dictionary:
			errors.append("%s: stage must be a dictionary" % prefix)
			continue
		var stage: Dictionary = stage_value
		if int(stage.get("stage_index", -1)) != stage_index:
			errors.append("%s: stage_index must equal its route position" % prefix)
		var encounter_type := String(stage.get("encounter_type", ""))
		if encounter_type != EXPECTED_TYPES[stage_index]:
			errors.append("%s: encounter_type must be %s" % [prefix, EXPECTED_TYPES[stage_index]])
		var encounter_id := String(stage.get("encounter_id", "")).strip_edges()
		if encounter_id.is_empty():
			errors.append("%s: encounter_id must be a non-empty string" % prefix)
			continue
		if seen_encounter_ids.has(encounter_id):
			errors.append("%s: encounter IDs must be unique" % prefix)
		seen_encounter_ids[encounter_id] = true
		if not encounter_defs.has(encounter_id) or not encounter_defs[encounter_id] is Dictionary:
			errors.append("%s: unknown encounter %s" % [prefix, encounter_id])
			continue
		var encounter: Dictionary = encounter_defs[encounter_id]
		_validate_encounter_contract(encounter_id, encounter, encounter_type, errors)
		var draft_value = encounter.get("validation_draft")
		if not draft_value is Dictionary:
			continue
		var draft: Dictionary = draft_value
		_validate_draft_pool(encounter_id, draft, available_recipe_ids, errors)
		var budget := int(encounter.get("supply_budget", default_budget))
		var built: Dictionary = loadout_service.build_snapshot(
			draft,
			recipe_defs,
			encounter,
			rows,
			columns,
			budget
		)
		if not bool(built.get("ok", false)):
			for error in built.get("errors", []):
				errors.append("%s.validation_draft: %s" % [encounter_id, String(error)])
			continue
		var battle: Dictionary = battle_service.simulate(
			built.get("snapshot", {}),
			encounter,
			_derive_seed(1701, stage_index, 11)
		)
		if String(battle.get("outcome", "")) != "victory":
			errors.append(
				"%s.validation_draft: real battle simulation ended with %s" %
				[encounter_id, String(battle.get("outcome", "unfinished"))]
			)

	return {
		"valid": errors.is_empty(),
		"errors": errors
	}


func create_standard_encounters(
	run_id: String,
	seed: int,
	route_def: Dictionary,
	encounter_defs: Dictionary,
	pool_snapshot: Variant
) -> Dictionary:
	var errors: Array[String] = []
	if run_id.strip_edges().is_empty():
		errors.append("run_id must be a non-empty string")
	var stages_value = route_def.get("stages")
	if not stages_value is Array or stages_value.size() != EXPECTED_TYPES.size():
		errors.append("route must contain exactly five stages")
		return {"ok": false, "errors": errors, "encounter_instances": []}

	var pool_ids := _pool_ids(pool_snapshot)
	var instances: Array[Dictionary] = []
	for stage_index in EXPECTED_TYPES.size():
		var stage_value = stages_value[stage_index]
		if not stage_value is Dictionary:
			errors.append("stage_%d must be a dictionary" % stage_index)
			continue
		var stage: Dictionary = stage_value
		var encounter_id := String(stage.get("encounter_id", ""))
		if not encounter_defs.has(encounter_id) or not encounter_defs[encounter_id] is Dictionary:
			errors.append("stage_%d references unknown encounter %s" % [stage_index, encounter_id])
			continue
		var definition: Dictionary = encounter_defs[encounter_id]
		var instance: Dictionary = definition.duplicate(true)
		instance["id"] = encounter_id
		instance["encounter_id"] = encounter_id
		instance["stage_index"] = stage_index
		instance["encounter_instance_id"] = "%s:stage:%d" % [run_id, stage_index]
		instance["encounter_seed"] = _derive_seed(seed, stage_index, 11)
		instance["reward_seed"] = _derive_seed(seed, stage_index, 29)
		instance["available_recipe_ids"] = pool_ids.duplicate()
		instances.append(instance)

	return {
		"ok": errors.is_empty(),
		"errors": errors,
		"encounter_instances": instances.duplicate(true)
	}


func encounter_for_stage(encounter_instances: Array, stage_index: int) -> Dictionary:
	if stage_index < 0:
		return {}
	for value in encounter_instances:
		if value is Dictionary and int(value.get("stage_index", -1)) == stage_index:
			return (value as Dictionary).duplicate(true)
	return {}


func _validate_encounter_contract(
	encounter_id: String,
	encounter: Dictionary,
	expected_type: String,
	errors: Array[String]
) -> void:
	if String(encounter.get("id", "")) != encounter_id:
		errors.append("%s: id must match its dictionary key" % encounter_id)
	if String(encounter.get("display_name", "")).strip_edges().is_empty():
		errors.append("%s: display_name must be a non-empty string" % encounter_id)
	if String(encounter.get("encounter_type", "")) != expected_type:
		errors.append("%s: encounter_type must be %s" % [encounter_id, expected_type])
	_validate_known_string_array(encounter_id, encounter, "rule_tags", KNOWN_RULE_TAGS, errors)
	_validate_known_string_array(
		encounter_id,
		encounter,
		"required_mechanism_tags",
		KNOWN_MECHANISM_TAGS,
		errors
	)
	if String(encounter.get("blueprint_hint_id", "")).strip_edges().is_empty():
		errors.append("%s: blueprint_hint_id must be a non-empty string" % encounter_id)
	if not encounter.get("windows") is Array or encounter.get("windows", []).is_empty():
		errors.append("%s: windows must be a non-empty array" % encounter_id)
	if not encounter.get("validation_draft") is Dictionary:
		errors.append("%s: validation_draft must be a dictionary" % encounter_id)
	if _positive_int(encounter.get("supply_budget")) <= 0:
		errors.append("%s: supply_budget must be a positive integer" % encounter_id)


func _validate_known_string_array(
	prefix: String,
	source: Dictionary,
	key: String,
	known_values: Array,
	errors: Array[String]
) -> void:
	var value = source.get(key)
	if not value is Array or value.is_empty():
		errors.append("%s: %s must be a non-empty array" % [prefix, key])
		return
	var seen := {}
	for entry_value in value:
		var entry := String(entry_value).strip_edges()
		if entry.is_empty():
			errors.append("%s: %s entries must be non-empty strings" % [prefix, key])
		elif seen.has(entry):
			errors.append("%s: %s entries must be unique" % [prefix, key])
		elif not known_values.has(entry):
			errors.append("%s: unknown %s value %s" % [prefix, key, entry])
		seen[entry] = true


func _validate_draft_pool(
	encounter_id: String,
	draft: Dictionary,
	available_recipe_ids: Array[String],
	errors: Array[String]
) -> void:
	var placements_value = draft.get("placements")
	if not placements_value is Array or placements_value.is_empty():
		errors.append("%s.validation_draft: placements must be a non-empty array" % encounter_id)
		return
	for placement_value in placements_value:
		if not placement_value is Dictionary:
			continue
		var recipe_id := String(placement_value.get("recipe_id", ""))
		if not available_recipe_ids.has(recipe_id):
			errors.append(
				"%s.validation_draft: recipe %s is not in the current starter pool" %
				[encounter_id, recipe_id]
			)


func _pool_ids(pool_snapshot: Variant) -> Array[String]:
	var ids: Array[String] = []
	if pool_snapshot is Array:
		for value in pool_snapshot:
			var recipe_id := String(value).strip_edges()
			if not recipe_id.is_empty() and not ids.has(recipe_id):
				ids.append(recipe_id)
	elif pool_snapshot is Dictionary:
		for value in pool_snapshot.get("recipe_ids", []):
			var recipe_id := String(value).strip_edges()
			if not recipe_id.is_empty() and not ids.has(recipe_id):
				ids.append(recipe_id)
	ids.sort()
	return ids


func _derive_seed(run_seed: int, stage_index: int, salt: int) -> int:
	var mixed := posmod(run_seed, 2147483647)
	mixed = posmod(mixed * 1103515245 + 12345, 2147483647)
	mixed = posmod(mixed + (stage_index + 1) * 2654435761, 2147483647)
	mixed = posmod(mixed + salt * 1013904223, 2147483647)
	return int(mixed)


func _positive_int(value: Variant) -> int:
	if value is int:
		return int(value) if int(value) > 0 else 0
	if value is float and is_equal_approx(value, float(int(value))):
		return int(value) if int(value) > 0 else 0
	return 0


func _label(value: String, fallback: String) -> String:
	return value if not value.is_empty() else fallback
