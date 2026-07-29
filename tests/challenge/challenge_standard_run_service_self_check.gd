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

	_test_creation_and_locking(service)
	_test_full_five_stage_victory(service)
	_test_two_losses_end_run(service)
	_test_middle_stage_retry_and_idempotency(service)
	_finish()


func _test_creation_and_locking(service) -> void:
	var pool := {"recipe_ids": ["toast", "coffee"]}
	var run: Dictionary = service.create_standard_run("standard:profile-1:42", 42, "route-a", pool)
	pool["recipe_ids"].append("late-change")
	_expect(run.get("phase") == "run_create", "standard run should await locked encounters")
	_expect(int(run.get("stage_index", -1)) == 0, "standard run should start at stage zero")
	_expect(int(run.get("confidence", 0)) == 2, "standard run should start with two confidence")
	_expect((run.get("run_upgrades", []) as Array).is_empty(), "standard run should start without upgrades")
	_expect((run.get("stage_history", []) as Array).is_empty(), "standard run should start with empty history")
	_expect(
		(run.get("permanent_pool_snapshot", {}).get("recipe_ids", []) as Array).size() == 2,
		"permanent pool should be immutable"
	)

	var invalid_sequence := _encounters()
	invalid_sequence[3]["encounter_type"] = "normal"
	var rejected: Dictionary = service.lock_encounters(run, invalid_sequence)
	_expect(not bool(rejected.get("applied", true)), "invalid encounter sequence should be rejected")
	_expect((rejected.get("run", {}).get("encounter_instances", []) as Array).is_empty(), "rejected lock should not mutate run")

	var encounters := _encounters()
	var locked_result: Dictionary = service.lock_encounters(run, encounters)
	var locked: Dictionary = locked_result.get("run", {})
	encounters[0]["encounter_id"] = "mutated"
	_expect(bool(locked_result.get("applied", false)), "valid five encounter sequence should lock")
	_expect(locked.get("phase") == "preparation", "locked run should enter preparation")
	_expect(String(service.current_encounter(locked).get("encounter_id", "")) == "morning_rush", "locked encounter should be immutable")
	_expect(
		String(service.current_encounter(locked).get("encounter_instance_id", "")) == "standard:profile-1:42:stage:0",
		"encounter instance ID should be stable"
	)


func _test_full_five_stage_victory(service) -> void:
	var run := _locked_run(service, "standard:full:7", 7)
	for stage_index in range(5):
		var begun: Dictionary = service.begin_battle(run)
		_expect(bool(begun.get("applied", false)), "stage %d battle should begin" % stage_index)
		run = begun.get("run", {})
		var encounter: Dictionary = service.current_encounter(run)
		var battle_attempt_id := String(begun.get("battle_attempt_id", ""))
		_expect(
			battle_attempt_id == "standard:full:7:stage:%d:attempt:0" % stage_index,
			"first battle attempt ID should be stable for stage %d" % stage_index
		)
		var settlement_id := "%s:victory" % battle_attempt_id
		var settled: Dictionary = service.register_result(run, {
			"settlement_id": settlement_id,
			"outcome": "victory",
			"encounter_instance_id": encounter.get("encounter_instance_id")
		})
		_expect(bool(settled.get("applied", false)), "stage %d victory should apply" % stage_index)
		run = settled.get("run", {})

		var duplicate: Dictionary = service.register_result(run, {
			"settlement_id": settlement_id,
			"outcome": "victory",
			"encounter_instance_id": encounter.get("encounter_instance_id")
		})
		_expect(not bool(duplicate.get("applied", true)), "stage %d duplicate victory should be ignored" % stage_index)
		_expect(duplicate.get("run", {}) == run, "duplicate victory should not change state")

		if stage_index < 4:
			_expect(run.get("phase") == "battle_result_win", "non-final victory should await upgrade offer")
			var offer_id := "standard:full:7:upgrade:%d" % stage_index
			var offered: Dictionary = service.attach_upgrade_offer(run, {
				"offer_id": offer_id,
				"candidate_ids": [
					"upgrade-%d-a" % stage_index,
					"upgrade-%d-b" % stage_index,
					"upgrade-%d-c" % stage_index
				]
			})
			_expect(bool(offered.get("applied", false)), "stage %d offer should attach" % stage_index)
			run = offered.get("run", {})
			_expect(run.get("phase") == "upgrade_select", "attached offer should enter upgrade selection")
			var upgrade_id := "upgrade-%d-a" % stage_index
			var reward_tx := "%s:%s" % [offer_id, upgrade_id]
			var chosen: Dictionary = service.choose_upgrade(run, offer_id, upgrade_id, reward_tx)
			_expect(bool(chosen.get("applied", false)), "stage %d upgrade should apply" % stage_index)
			run = chosen.get("run", {})
			var duplicate_choice: Dictionary = service.choose_upgrade(run, offer_id, upgrade_id, reward_tx)
			_expect(not bool(duplicate_choice.get("applied", true)), "duplicate upgrade transaction should be ignored")
			_expect(duplicate_choice.get("run", {}) == run, "duplicate upgrade transaction should not change state")
			_expect(int(run.get("stage_index", -1)) == stage_index + 1, "upgrade should advance exactly one stage")
			_expect(run.get("phase") == "preparation", "upgrade should enter next preparation")
		else:
			_expect(run.get("phase") == "run_complete", "fifth victory should complete run")
			_expect((run.get("pending_upgrade_offer", {}) as Dictionary).is_empty(), "fifth victory should not create an upgrade")

	_expect((run.get("run_upgrades", []) as Array).size() == 4, "complete run should contain four upgrades")
	var research_tx := "standard:full:7:research-complete"
	var rewarded: Dictionary = service.mark_research_rewarded(run, research_tx)
	_expect(bool(rewarded.get("applied", false)), "research completion transaction should apply")
	run = rewarded.get("run", {})
	var duplicate_reward: Dictionary = service.mark_research_rewarded(run, research_tx)
	_expect(not bool(duplicate_reward.get("applied", true)), "duplicate research transaction should be ignored")
	_expect(duplicate_reward.get("run", {}) == run, "duplicate research transaction should not change state")
	_expect(run.get("phase") == "run_complete", "research reward should keep the run summary state")
	_expect(bool(run.get("research_rewarded", false)), "research reward should mark completion payout")
	var returned: Dictionary = service.return_to_hub(run)
	_expect(bool(returned.get("applied", false)), "rewarded complete run should return to hub")
	_expect(returned.get("run", {}).get("phase") == "meta_hub", "returned run should enter the hub state")


func _test_two_losses_end_run(service) -> void:
	var run := _locked_run(service, "standard:losses:11", 11)
	var encounter_instance_id := String(service.current_encounter(run).get("encounter_instance_id", ""))
	for attempt_index in range(2):
		var begun: Dictionary = service.begin_battle(run)
		run = begun.get("run", {})
		_expect(
			String(begun.get("battle_attempt_id", "")) == "%s:attempt:%d" % [encounter_instance_id, attempt_index],
			"retry should get a new battle attempt ID"
		)
		var settled: Dictionary = service.register_result(run, {
			"settlement_id": "%s:loss_timeout" % begun.get("battle_attempt_id"),
			"outcome": "loss_timeout",
			"encounter_instance_id": encounter_instance_id
		})
		run = settled.get("run", {})
		if attempt_index == 0:
			_expect(run.get("phase") == "battle_result_loss", "first loss should allow same-stage retry")
			_expect(int(run.get("confidence", 0)) == 1, "first loss should consume one confidence")
			_expect(String(service.current_encounter(run).get("encounter_instance_id", "")) == encounter_instance_id, "retry should preserve encounter identity")
		else:
			_expect(run.get("phase") == "run_failed", "second loss should fail run")
			_expect(int(run.get("confidence", -1)) == 0, "second loss should consume final confidence")
	var returned: Dictionary = service.return_to_hub(run)
	_expect(bool(returned.get("applied", false)), "failed run should return to hub")


func _test_middle_stage_retry_and_idempotency(service) -> void:
	var run := _locked_run(service, "standard:retry:23", 23)
	run = _win_stage_and_choose(service, run, "retry-upgrade-0")
	run = _win_stage_and_choose(service, run, "retry-upgrade-1")
	_expect(int(run.get("stage_index", -1)) == 2, "setup should reach middle stage")

	var encounter_before: Dictionary = service.current_encounter(run)
	var first_attempt: Dictionary = service.begin_battle(run)
	run = first_attempt.get("run", {})
	var loss_id := "%s:loss_window" % first_attempt.get("battle_attempt_id")
	var loss: Dictionary = service.register_result(run, {
		"settlement_id": loss_id,
		"outcome": "loss_window",
		"encounter_instance_id": encounter_before.get("encounter_instance_id")
	})
	run = loss.get("run", {})
	var duplicate_loss: Dictionary = service.register_result(run, {
		"settlement_id": loss_id,
		"outcome": "loss_window",
		"encounter_instance_id": encounter_before.get("encounter_instance_id")
	})
	_expect(not bool(duplicate_loss.get("applied", true)), "duplicate middle-stage loss should not consume confidence")
	_expect(int(duplicate_loss.get("run", {}).get("confidence", 0)) == 1, "duplicate loss should preserve confidence")

	var retry: Dictionary = service.begin_battle(run)
	_expect(first_attempt.get("battle_attempt_id") != retry.get("battle_attempt_id"), "retry battle identity should change")
	_expect(first_attempt.get("encounter_instance_id") == retry.get("encounter_instance_id"), "retry encounter identity should remain")


func _win_stage_and_choose(service, run_state: Dictionary, upgrade_id: String) -> Dictionary:
	var begun: Dictionary = service.begin_battle(run_state)
	var run: Dictionary = begun.get("run", {})
	var encounter: Dictionary = service.current_encounter(run)
	var settled: Dictionary = service.register_result(run, {
		"settlement_id": "%s:victory" % begun.get("battle_attempt_id"),
		"outcome": "victory",
		"encounter_instance_id": encounter.get("encounter_instance_id")
	})
	run = settled.get("run", {})
	var offer_id := "%s:upgrade:%d" % [run.get("run_id"), run.get("stage_index")]
	var offered: Dictionary = service.attach_upgrade_offer(run, {
		"offer_id": offer_id,
		"candidate_ids": [upgrade_id, "%s-b" % upgrade_id, "%s-c" % upgrade_id]
	})
	run = offered.get("run", {})
	return service.choose_upgrade(run, offer_id, upgrade_id, "%s:%s" % [offer_id, upgrade_id]).get("run", {})


func _locked_run(service, run_id: String, seed: int) -> Dictionary:
	var created: Dictionary = service.create_standard_run(run_id, seed, "standard-route", {"recipe_ids": ["toast"]})
	return service.lock_encounters(created, _encounters()).get("run", {})


func _encounters() -> Array:
	return [
		{"encounter_id": "morning_rush", "encounter_type": "normal", "encounter_seed": 10, "reward_seed": 1010},
		{"encounter_id": "pairing_tasting", "encounter_type": "normal", "encounter_seed": 20, "reward_seed": 1020},
		{"encounter_id": "afternoon_wave", "encounter_type": "normal", "encounter_seed": 30, "reward_seed": 1030},
		{"encounter_id": "weekend_feature", "encounter_type": "elite", "encounter_seed": 40, "reward_seed": 1040},
		{"encounter_id": "picky_food_critic", "encounter_type": "final_boss", "encounter_seed": 50, "reward_seed": 1050}
	]


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	if not _failures.has(message):
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("CHALLENGE_STANDARD_RUN_SERVICE_SELF_CHECK_PASS")
		quit(0)
		return
	for message in _failures:
		push_error(message)
	quit(1)
