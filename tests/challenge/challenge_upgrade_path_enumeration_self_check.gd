extends SceneTree

const RUN_SERVICE_PATH := "res://scripts/challenge/challenge_run_service.gd"
const UPGRADE_SERVICE_PATH := "res://scripts/challenge/run_upgrade_service.gd"
const RECIPE_CONFIG_PATH := "res://doc/challenge/challenge_recipes.json"
const UPGRADE_CONFIG_PATH := "res://doc/challenge/run_upgrades.json"
const PATH_COUNT := 81
const RADIX_WEIGHTS := [1, 3, 9, 27]

var _failures: Array[String] = []
var _choice_count := 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	for path in [RUN_SERVICE_PATH, UPGRADE_SERVICE_PATH, RECIPE_CONFIG_PATH, UPGRADE_CONFIG_PATH]:
		_expect(FileAccess.file_exists(path), "required file should exist: %s" % path)
	if not _failures.is_empty():
		_finish()
		return
	var run_script = load(RUN_SERVICE_PATH)
	var upgrade_script = load(UPGRADE_SERVICE_PATH)
	_expect(run_script != null and run_script.can_instantiate(), "run service should compile")
	_expect(upgrade_script != null and upgrade_script.can_instantiate(), "upgrade service should compile")
	if run_script == null or upgrade_script == null or not run_script.can_instantiate() or not upgrade_script.can_instantiate():
		_finish()
		return

	var run_service = run_script.new()
	var upgrade_service = upgrade_script.new()
	var recipe_config := _load_json(RECIPE_CONFIG_PATH)
	var upgrade_config := _load_json(UPGRADE_CONFIG_PATH)
	var recipe_defs: Dictionary = recipe_config.get("recipes", {})
	var upgrade_defs: Dictionary = upgrade_config.get("upgrades", {})
	var unlocked_ids: Array = (recipe_config.get("starter_recipe_ids", []) as Array).duplicate()
	unlocked_ids.append_array(recipe_config.get("research_recipe_ids", []))
	var validation: Dictionary = upgrade_service.validate_definitions(upgrade_defs, recipe_defs)
	for error in validation.get("errors", []):
		_fail("committed upgrade configuration should validate: %s" % String(error))
	_expect(bool(validation.get("valid", false)), "committed upgrade configuration should be valid")

	for path_index in range(PATH_COUNT):
		_enumerate_path(path_index, run_service, upgrade_service, recipe_defs, upgrade_defs, unlocked_ids)
	_finish()


func _enumerate_path(
	path_index: int,
	run_service,
	upgrade_service,
	recipe_defs: Dictionary,
	upgrade_defs: Dictionary,
	unlocked_ids: Array
) -> void:
	var run_id := "standard:path:%02d" % path_index
	var pool_snapshot := {
		"recipe_ids": unlocked_ids.duplicate(),
		"recipe_defs": recipe_defs.duplicate(true)
	}
	var run: Dictionary = run_service.create_standard_run(run_id, 7300 + path_index, "standard_short_chain", pool_snapshot)
	var locked: Dictionary = run_service.lock_encounters(run, _encounters(run_id, path_index))
	_expect(bool(locked.get("applied", false)), "path %02d should lock five encounters" % path_index)
	if not bool(locked.get("applied", false)):
		return
	run = (locked.get("run", {}) as Dictionary).duplicate(true)
	var draft_analysis := _draft_analysis()

	for choice_step in range(4):
		var begun: Dictionary = run_service.begin_battle(run)
		_expect(bool(begun.get("applied", false)), "path %02d stage %d should begin" % [path_index, choice_step])
		if not bool(begun.get("applied", false)):
			return
		run = (begun.get("run", {}) as Dictionary).duplicate(true)
		var encounter: Dictionary = run_service.current_encounter(run)
		var settled: Dictionary = run_service.register_result(run, {
			"settlement_id": "%s:victory" % String(begun.get("battle_attempt_id", "")),
			"outcome": "victory",
			"encounter_instance_id": encounter.get("encounter_instance_id")
		})
		_expect(bool(settled.get("applied", false)), "path %02d stage %d should settle victory" % [path_index, choice_step])
		if not bool(settled.get("applied", false)):
			return
		run = (settled.get("run", {}) as Dictionary).duplicate(true)

		var generated: Dictionary = upgrade_service.generate_offer(run, draft_analysis, unlocked_ids, upgrade_defs)
		_expect(bool(generated.get("ok", false)), "path %02d stage %d should generate an offer" % [path_index, choice_step])
		if not bool(generated.get("ok", false)):
			return
		var offer: Dictionary = generated.get("offer", {})
		var candidate_ids: Array = offer.get("candidate_ids", [])
		_expect(candidate_ids.size() == 3, "path %02d stage %d should have three candidates" % [path_index, choice_step])
		_expect(_unique_string_count(candidate_ids) == 3, "path %02d stage %d candidates should be unique" % [path_index, choice_step])
		if candidate_ids.size() != 3:
			return
		var attached: Dictionary = run_service.attach_upgrade_offer(run, offer)
		_expect(bool(attached.get("applied", false)), "path %02d stage %d should attach offer" % [path_index, choice_step])
		if not bool(attached.get("applied", false)):
			return
		run = (attached.get("run", {}) as Dictionary).duplicate(true)

		var candidate_index := int(path_index / RADIX_WEIGHTS[choice_step]) % 3
		var upgrade_id := String(candidate_ids[candidate_index])
		var applied: Dictionary = upgrade_service.apply_choice(run, offer, upgrade_id)
		_expect(bool(applied.get("applied", false)), "path %02d stage %d choice %d (%s) should apply" % [path_index, choice_step, candidate_index, upgrade_id])
		if not bool(applied.get("applied", false)):
			return
		var reward_tx := String(applied.get("reward_transaction_id", ""))
		var finalized: Dictionary = run_service.finalize_upgrade_choice(
			applied.get("run", {}),
			String(offer.get("offer_id", "")),
			upgrade_id,
			reward_tx
		)
		_expect(bool(finalized.get("applied", false)), "path %02d stage %d choice should finalize" % [path_index, choice_step])
		if not bool(finalized.get("applied", false)):
			return
		run = (finalized.get("run", {}) as Dictionary).duplicate(true)
		_choice_count += 1
		_expect(String(run.get("phase", "")) == "preparation", "path %02d stage %d should reach next preparation" % [path_index, choice_step])
		_expect(int(run.get("stage_index", -1)) == choice_step + 1, "path %02d should advance exactly one stage after choice %d" % [path_index, choice_step])
		var resolved: Dictionary = upgrade_service.resolve_context(recipe_defs, {"supply_budget": 16}, run.get("run_upgrades", []))
		_expect((resolved.get("recipe_defs", {}) as Dictionary).size() == recipe_defs.size(), "path %02d stage %d should resolve a complete recipe context" % [path_index, choice_step])

	_expect((run.get("applied_run_reward_transaction_ids", []) as Array).size() == 4, "path %02d should retain four unique upgrade transactions" % path_index)
	_expect(_unique_string_count(run.get("applied_run_reward_transaction_ids", [])) == 4, "path %02d upgrade transactions should be unique" % path_index)
	_expect(int(run.get("stage_index", -1)) == 4, "path %02d should reach final boss preparation" % path_index)
	if int(run.get("stage_index", -1)) != 4:
		return

	var final_begun: Dictionary = run_service.begin_battle(run)
	_expect(bool(final_begun.get("applied", false)), "path %02d final boss should begin" % path_index)
	if not bool(final_begun.get("applied", false)):
		return
	run = (final_begun.get("run", {}) as Dictionary).duplicate(true)
	var final_encounter: Dictionary = run_service.current_encounter(run)
	var final_settled: Dictionary = run_service.register_result(run, {
		"settlement_id": "%s:victory" % String(final_begun.get("battle_attempt_id", "")),
		"outcome": "victory",
		"encounter_instance_id": final_encounter.get("encounter_instance_id")
	})
	_expect(bool(final_settled.get("applied", false)), "path %02d final boss should settle" % path_index)
	run = (final_settled.get("run", {}) as Dictionary).duplicate(true)
	_expect(String(run.get("phase", "")) == "run_complete", "path %02d should complete the five-encounter chain" % path_index)
	_expect((run.get("pending_upgrade_offer", {}) as Dictionary).is_empty(), "path %02d final boss should not create a fifth offer" % path_index)


func _encounters(run_id: String, path_index: int) -> Array:
	var types := ["normal", "normal", "normal", "elite", "final_boss"]
	var ids := ["morning_rush", "pairing_tasting", "afternoon_wave", "weekend_feature", "picky_food_critic"]
	var encounters: Array = []
	for stage_index in range(5):
		encounters.append({
			"encounter_id": ids[stage_index],
			"encounter_type": types[stage_index],
			"encounter_seed": 100000 + path_index * 10 + stage_index,
			"reward_seed": 200000 + path_index * 10 + stage_index,
			"encounter_instance_id": "%s:stage:%d" % [run_id, stage_index]
		})
	return encounters


func _draft_analysis() -> Dictionary:
	return {
		"instances": [
			{"recipe_id": "butter_cookie", "tags": ["fast", "bake"]},
			{"recipe_id": "strawberry_jelly", "tags": ["fast", "fruit"]},
			{"recipe_id": "milk_pudding", "tags": ["cold", "milk"]},
			{"recipe_id": "blueberry_muffin", "tags": ["bake", "fruit"]},
			{"recipe_id": "sponge_cake", "tags": ["bake", "cake"]},
			{"recipe_id": "chocolate_lava_cake", "tags": ["bake", "chocolate"]}
		]
	}


func _unique_string_count(values: Array) -> int:
	var unique := {}
	for value in values:
		unique[String(value)] = true
	return unique.size()


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
		print("CHALLENGE_UPGRADE_PATH_ENUMERATION_SELF_CHECK_PASS paths=%d choices=%d" % [PATH_COUNT, _choice_count])
		quit(0)
		return
	for message in _failures:
		push_error(message)
	quit(1)
