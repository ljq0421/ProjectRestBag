class_name EndlessClimbService
extends RefCounted


func validate_config(config: Dictionary, encounter_defs: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	for field in [
		"grid_rows", "grid_columns", "starting_confidence", "maximum_confidence",
		"minimum_supply_budget", "pickiness_per_floor", "budget_pressure_interval",
		"recovery_interval", "elite_interval", "boss_interval",
		"research_milestone_interval", "research_points_per_milestone",
		"research_points_run_cap"
	]:
		if int(config.get(field, 0)) <= 0:
			errors.append("%s must be a positive integer" % field)
	var normal_cycle: Variant = config.get("normal_encounter_cycle")
	if not normal_cycle is Array or normal_cycle.is_empty():
		errors.append("normal_encounter_cycle must not be empty")
	else:
		for encounter_id_value in normal_cycle:
			_validate_encounter_id(String(encounter_id_value), encounter_defs, errors)
	_validate_encounter_id(String(config.get("elite_encounter_id", "")), encounter_defs, errors)
	_validate_encounter_id(String(config.get("boss_encounter_id", "")), encounter_defs, errors)
	if int(config.get("starting_confidence", 0)) > int(config.get("maximum_confidence", 0)):
		errors.append("starting_confidence must not exceed maximum_confidence")
	return {"valid": errors.is_empty(), "errors": errors}


func create_run(
	run_id: String,
	seed: int,
	pool_snapshot: Dictionary,
	config: Dictionary,
	encounter_defs: Dictionary
) -> Dictionary:
	var validation := validate_config(config, encounter_defs)
	if not bool(validation.get("valid", false)):
		return {"ok": false, "errors": validation.get("errors", []), "run": {}}
	var run := {
		"run_id": run_id.strip_edges(),
		"mode": "endless",
		"seed": seed,
		"phase": "preparation",
		"route_id": String(config.get("id", "endless_climb")),
		"stage_index": 0,
		"confidence": int(config.get("starting_confidence", 2)),
		"permanent_pool_snapshot": pool_snapshot.duplicate(true),
		"run_upgrades": [],
		"encounter_instances": [],
		"loadout_draft": {"placements": []},
		"pending_upgrade_offer": {},
		"stage_history": [],
		"settled_settlement_ids": [],
		"applied_run_reward_transaction_ids": [],
		"next_attempt_index": 0,
		"current_battle_attempt_id": "",
		"current_encounter_instance_id": "",
		"research_rewarded": false,
		"endless_rewarded": false,
		"endless_record_finalized": false,
		"highest_cleared_floor": 0
	}
	var ensured := ensure_current_floor(run, config, encounter_defs)
	if not bool(ensured.get("ok", false)):
		return ensured
	return {"ok": true, "run": ensured.get("run", {}).duplicate(true)}


func ensure_current_floor(
	run_state: Dictionary,
	config: Dictionary,
	encounter_defs: Dictionary
) -> Dictionary:
	var next_run := run_state.duplicate(true)
	if String(next_run.get("mode", "")) != "endless":
		return {"ok": false, "error": "endless_run_required", "run": next_run}
	var stage_index := int(next_run.get("stage_index", 0))
	var encounters: Array = next_run.get("encounter_instances", [])
	for value in encounters:
		if value is Dictionary and int(value.get("stage_index", -1)) == stage_index:
			next_run["current_encounter_instance_id"] = String(value.get("encounter_instance_id", ""))
			return {"ok": true, "run": next_run, "encounter": value.duplicate(true)}
	var generated := generate_floor_encounter(
		String(next_run.get("run_id", "")),
		int(next_run.get("seed", 0)),
		stage_index + 1,
		next_run.get("permanent_pool_snapshot", {}),
		config,
		encounter_defs
	)
	if not bool(generated.get("ok", false)):
		return {"ok": false, "error": generated.get("error", "floor_generation_failed"), "run": next_run}
	var encounter: Dictionary = generated.get("encounter", {})
	encounters.append(encounter)
	next_run["encounter_instances"] = encounters
	next_run["current_encounter_instance_id"] = String(encounter.get("encounter_instance_id", ""))
	return {"ok": true, "run": next_run, "encounter": encounter.duplicate(true)}


func generate_floor_encounter(
	run_id: String,
	seed: int,
	floor_number: int,
	pool_snapshot: Dictionary,
	config: Dictionary,
	encounter_defs: Dictionary
) -> Dictionary:
	if floor_number <= 0:
		return {"ok": false, "error": "floor_number_must_be_positive", "encounter": {}}
	var encounter_id := encounter_id_for_floor(floor_number, config)
	if not encounter_defs.has(encounter_id) or not encounter_defs[encounter_id] is Dictionary:
		return {"ok": false, "error": "unknown_endless_encounter", "encounter": {}}
	var encounter: Dictionary = (encounter_defs[encounter_id] as Dictionary).duplicate(true)
	var stage_index := floor_number - 1
	var tier := int(stage_index / maxi(1, int(config.get("recovery_interval", 5))))
	var base_pickiness := int(encounter.get("initial_pickiness", 0))
	encounter["initial_pickiness"] = base_pickiness + stage_index * int(config.get("pickiness_per_floor", 8))
	var budget_interval := maxi(1, int(config.get("budget_pressure_interval", 4)))
	encounter["supply_budget"] = maxi(
		int(config.get("minimum_supply_budget", 10)),
		int(encounter.get("supply_budget", 16)) - int(stage_index / budget_interval)
	)
	var growth := mini(
		int(config.get("window_target_growth_cap_percent", 50)),
		stage_index * int(config.get("window_target_growth_percent_per_floor", 2))
	)
	var windows: Array = encounter.get("windows", [])
	for index in windows.size():
		if not windows[index] is Dictionary:
			continue
		var window: Dictionary = windows[index]
		var metric := String(window.get("metric", ""))
		if metric != "active_relation_count":
			window["target"] = int(ceil(float(int(window.get("target", 0))) * (100.0 + growth) / 100.0))
		window["reputation_damage"] = int(window.get("reputation_damage", 0)) + tier * int(
			config.get("reputation_damage_per_tier", 2)
		)
		windows[index] = window
	encounter["windows"] = windows
	encounter["id"] = encounter_id
	encounter["encounter_id"] = encounter_id
	encounter["base_encounter_id"] = encounter_id
	encounter["base_display_name"] = String(encounter.get("display_name", "客潮"))
	encounter["display_name"] = "第 %d 层 · %s" % [floor_number, String(encounter.get("base_display_name", "客潮"))]
	encounter["stage_index"] = stage_index
	encounter["floor_number"] = floor_number
	encounter["endless_tier"] = tier
	encounter["endless_pressure_level"] = stage_index
	encounter["encounter_instance_id"] = "%s:stage:%d" % [run_id, stage_index]
	encounter["encounter_seed"] = _derive_seed(seed, stage_index, 47)
	encounter["reward_seed"] = _derive_seed(seed, stage_index, 83)
	encounter["available_recipe_ids"] = (pool_snapshot.get("recipe_ids", []) as Array).duplicate()
	return {"ok": true, "encounter": encounter}


func encounter_id_for_floor(floor_number: int, config: Dictionary) -> String:
	var boss_interval := maxi(1, int(config.get("boss_interval", 10)))
	var elite_interval := maxi(1, int(config.get("elite_interval", 5)))
	if floor_number % boss_interval == 0:
		return String(config.get("boss_encounter_id", ""))
	if floor_number % elite_interval == 0:
		return String(config.get("elite_encounter_id", ""))
	var cycle: Array = config.get("normal_encounter_cycle", [])
	return String(cycle[posmod(floor_number - 1, cycle.size())]) if not cycle.is_empty() else ""


func apply_floor_recovery(run_state: Dictionary, config: Dictionary) -> Dictionary:
	var next_run := run_state.duplicate(true)
	var cleared_floor := int(next_run.get("highest_cleared_floor", 0))
	var interval := maxi(1, int(config.get("recovery_interval", 5)))
	var recovered := 0
	if cleared_floor > 0 and cleared_floor % interval == 0:
		var maximum := int(config.get("maximum_confidence", 2))
		var before := int(next_run.get("confidence", 0))
		next_run["confidence"] = mini(maximum, before + 1)
		recovered = int(next_run["confidence"]) - before
	return {"run": next_run, "confidence_recovered": recovered}


func completed_floor_count(run_state: Dictionary) -> int:
	var count := 0
	for value in run_state.get("stage_history", []):
		if value is Dictionary and String(value.get("kind", "")) == "battle" and String(value.get("outcome", "")) == "victory":
			count += 1
	return count


func research_reward_for_run(run_state: Dictionary, config: Dictionary) -> int:
	var interval := maxi(1, int(config.get("research_milestone_interval", 5)))
	var per_milestone := maxi(0, int(config.get("research_points_per_milestone", 1)))
	var cap := maxi(0, int(config.get("research_points_run_cap", 3)))
	return mini(cap, int(completed_floor_count(run_state) / interval) * per_milestone)


func build_record_snapshot(run_state: Dictionary, key_battle_report: Dictionary) -> Dictionary:
	return {
		"run_id": String(run_state.get("run_id", "")),
		"seed": int(run_state.get("seed", 0)),
		"highest_floor": completed_floor_count(run_state),
		"run_upgrades": (run_state.get("run_upgrades", []) as Array).duplicate(true),
		"loadout_snapshot": (run_state.get("last_battle_snapshot", {}) as Dictionary).duplicate(true),
		"key_battle_report": key_battle_report.duplicate(true)
	}


func _validate_encounter_id(encounter_id: String, encounter_defs: Dictionary, errors: Array[String]) -> void:
	if encounter_id.is_empty() or not encounter_defs.has(encounter_id):
		errors.append("unknown encounter: %s" % encounter_id)


func _derive_seed(run_seed: int, stage_index: int, salt: int) -> int:
	var mixed := posmod(run_seed, 2147483647)
	mixed = posmod(mixed * 1103515245 + 12345, 2147483647)
	mixed = posmod(mixed + (stage_index + 1) * 2654435761, 2147483647)
	mixed = posmod(mixed + salt * 1013904223, 2147483647)
	return int(mixed)
