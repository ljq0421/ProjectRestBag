extends SceneTree

const SERVICE_PATH := "res://scripts/challenge/challenge_run_service.gd"

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	if not FileAccess.file_exists(SERVICE_PATH):
		_fail("challenge run service should exist")
		_finish()
		return
	var service_script = load(SERVICE_PATH)
	_expect(service_script != null and service_script.can_instantiate(), "challenge run service should compile")
	if service_script == null or not service_script.can_instantiate():
		_finish()
		return
	var service = service_script.new()

	var run: Dictionary = service.create_single_encounter("run-1", 42, "picky_food_critic")
	_expect(int(run.get("confidence", 0)) == 2, "run should start with two confidence")
	_expect(run.get("phase") == "preparation", "run should start in preparation")
	_expect(int(run.get("reward_seed", 0)) == 1042, "reward seed should be derived once")

	var first_loss: Dictionary = service.register_result(run, {
		"settlement_id": "settlement-1",
		"outcome": "loss_timeout",
		"encounter_id": "picky_food_critic"
	})
	var first_run: Dictionary = first_loss.get("run", {})
	_expect(bool(first_loss.get("applied", false)), "first settlement should apply")
	_expect(int(first_run.get("confidence", 0)) == 1, "first loss should consume one confidence")
	_expect(first_run.get("phase") == "preparation", "first loss should return to preparation")
	_expect(int(run.get("confidence", 0)) == 2, "register_result should not mutate its input")
	_expect(first_run.get("encounter_id") == "picky_food_critic", "retry should keep encounter ID")
	_expect(int(first_run.get("encounter_seed", 0)) == 42, "retry should keep encounter seed")
	_expect(int(first_run.get("reward_seed", 0)) == 1042, "retry should keep reward seed")

	var duplicate: Dictionary = service.register_result(first_run, {
		"settlement_id": "settlement-1",
		"outcome": "loss_timeout",
		"encounter_id": "picky_food_critic"
	})
	var duplicate_run: Dictionary = duplicate.get("run", {})
	_expect(not bool(duplicate.get("applied", true)), "duplicate settlement should not apply")
	_expect(int(duplicate_run.get("confidence", 0)) == 1, "duplicate settlement must not consume confidence")
	_expect((duplicate_run.get("settled_ids", []) as Array).size() == 1, "duplicate settlement ID should not be appended twice")

	var second_loss: Dictionary = service.register_result(duplicate_run, {
		"settlement_id": "settlement-2",
		"outcome": "loss_timeout",
		"encounter_id": "picky_food_critic"
	})
	var ended_run: Dictionary = second_loss.get("run", {})
	_expect(int(ended_run.get("confidence", -1)) == 0, "second unique loss should consume final confidence")
	_expect(ended_run.get("phase") == "ended", "second unique loss should end the run")
	_expect(ended_run.get("encounter_id") == "picky_food_critic", "ended run should preserve encounter ID")
	_expect(int(ended_run.get("reward_seed", 0)) == 1042, "ended run should preserve reward seed")

	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	if not _failures.has(message):
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("CHALLENGE_RUN_SERVICE_SELF_CHECK_PASS")
		quit(0)
		return
	for message in _failures:
		push_error(message)
	quit(1)
