extends SceneTree

const ENDLESS_PATH := "res://scripts/challenge/endless_climb_service.gd"
const RUN_PATH := "res://scripts/challenge/challenge_run_service.gd"

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var config: Dictionary = _json("res://doc/challenge/endless_run.json")
	var encounters: Dictionary = _json("res://doc/challenge/boss_encounters.json").get("encounters", {})
	var recipes: Dictionary = _json("res://doc/challenge/challenge_recipes.json").get("recipes", {})
	var pool := {"recipe_ids": recipes.keys(), "recipe_defs": recipes}
	var endless = load(ENDLESS_PATH).new()
	var run_service = load(RUN_PATH).new()
	var validation: Dictionary = endless.validate_config(config, encounters)
	_expect(bool(validation.get("valid", false)), "endless config should validate")
	var created: Dictionary = endless.create_run("endless:31415", 31415, pool, config, encounters)
	_expect(bool(created.get("ok", false)), "endless run should be created")
	var run: Dictionary = created.get("run", {})
	_expect(String(run.get("mode", "")) == "endless", "created run should use endless mode")
	_expect(int(run.get("confidence", 0)) == 2, "endless run should start with two confidence")
	_expect((run.get("encounter_instances", []) as Array).size() == 1, "only current endless floor should be generated initially")

	var last_pickiness_by_template := {}
	for floor_number in range(1, 101):
		var generated: Dictionary = endless.generate_floor_encounter(
			"endless:31415", 31415, floor_number, pool, config, encounters
		)
		var duplicate: Dictionary = endless.generate_floor_encounter(
			"endless:31415", 31415, floor_number, pool, config, encounters
		)
		_expect(bool(generated.get("ok", false)), "floor %d should generate" % floor_number)
		var encounter: Dictionary = generated.get("encounter", {})
		_expect(encounter == duplicate.get("encounter", {}), "floor generation should be deterministic")
		_expect(int(encounter.get("endless_pressure_level", -1)) == floor_number - 1, "pressure level should rise every floor")
		_expect(int(encounter.get("supply_budget", 0)) >= int(config.get("minimum_supply_budget", 10)), "budget should respect its floor")
		var template_id := String(encounter.get("base_encounter_id", ""))
		if last_pickiness_by_template.has(template_id):
			_expect(
				int(encounter.get("initial_pickiness", 0)) > int(last_pickiness_by_template[template_id]),
				"repeated encounter templates should become pickier"
			)
		last_pickiness_by_template[template_id] = int(encounter.get("initial_pickiness", 0))
		if floor_number == 5:
			_expect(String(encounter.get("encounter_type", "")) == "elite", "floor 5 should be elite")
		if floor_number == 10:
			_expect(String(encounter.get("encounter_type", "")) == "final_boss", "floor 10 should be final boss")

	var begun: Dictionary = run_service.begin_battle(run)
	_expect(bool(begun.get("applied", false)), "endless battle should begin through shared state machine")
	run = begun.get("run", {})
	var current: Dictionary = run_service.current_encounter(run)
	var settled: Dictionary = run_service.register_result(run, {
		"settlement_id": "%s:victory" % begun.get("battle_attempt_id"),
		"outcome": "victory",
		"encounter_instance_id": current.get("encounter_instance_id")
	})
	_expect(bool(settled.get("applied", false)), "endless victory should settle")
	run = settled.get("run", {})
	_expect(String(run.get("phase", "")) == "battle_result_win", "endless victory should await upgrade")
	_expect(int(run.get("highest_cleared_floor", 0)) == 1, "victory should advance cleared-floor record")
	var offer_id := "endless:31415:upgrade:0"
	var offered: Dictionary = run_service.attach_upgrade_offer(run, {
		"offer_id": offer_id,
		"candidate_ids": ["a", "b", "c"]
	})
	_expect(bool(offered.get("applied", false)), "endless victory should accept three upgrade choices")
	run = offered.get("run", {})
	var chosen: Dictionary = run_service.choose_upgrade(run, offer_id, "a", "%s:a" % offer_id)
	_expect(bool(chosen.get("applied", false)), "endless upgrade choice should apply")
	run = chosen.get("run", {})
	var ensured: Dictionary = endless.ensure_current_floor(run, config, encounters)
	_expect(bool(ensured.get("ok", false)), "next endless floor should generate after upgrade")
	_expect(int(ensured.get("run", {}).get("stage_index", -1)) == 1, "upgrade should advance to floor 2")

	var reward_run := run.duplicate(true)
	reward_run["stage_history"] = []
	for floor_number in range(1, 41):
		reward_run["stage_history"].append({"kind": "battle", "outcome": "victory", "floor_number": floor_number})
	_expect(endless.research_reward_for_run(reward_run, config) == 3, "endless research reward should cap at three")
	_finish()


func _json(path: String) -> Dictionary:
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return value if value is Dictionary else {}


func _expect(condition: bool, message: String) -> void:
	if not condition and not _failures.has(message):
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("ENDLESS_CLIMB_SERVICE_SELF_CHECK_PASS floors=100")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
