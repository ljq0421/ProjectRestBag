extends SceneTree

const ChallengeSessionService = preload("res://scripts/challenge/challenge_session_service.gd")
const ChallengeSaveService = preload("res://scripts/challenge/challenge_save_service.gd")
const BossBattleService = preload("res://scripts/challenge/boss_battle_service.gd")

var _failures: Array[String] = []
var _save_path := OS.get_temp_dir().path_join("challenge_session_recovery_self_check.json")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_cleanup()
	var session := ChallengeSessionService.new()
	session.save_path = _save_path
	var loaded := session.load_or_create()
	_expect(bool(loaded.get("applied", false)), "empty current save should load and bootstrap")
	var save_data: Dictionary = loaded.get("save_data", {})
	_expect(
		(save_data.get("meta", {}).get("unlocked_recipe_ids", []) as Array).size() == 6,
		"new development save should start with six permanent recipes"
	)

	var created := session.create_standard_run(save_data, "standard_short_chain", 202)
	_expect(bool(created.get("applied", false)), "standard run should be created")
	save_data = created.get("save_data", {})
	var run: Dictionary = save_data.get("active_run", {})
	_expect((run.get("encounter_instances", []) as Array).size() == 5, "run should freeze five encounters")
	_expect(int(run.get("confidence", 0)) == 2, "run should start with two confidence")
	var first_encounter_instance_id := String(run.get("current_encounter_instance_id", ""))
	var first_reward_seed := int((run.get("encounter_instances", []) as Array)[0].get("reward_seed", 0))

	var started := session.start_battle(save_data, session.current_encounter(save_data).get("validation_draft", {}))
	_expect(bool(started.get("applied", false)), "first battle should start")
	save_data = started.get("save_data", {})
	var first_attempt_id := String((save_data.get("active_battle", {}) as Dictionary).get("battle_attempt_id", ""))
	var recovered := session.recover(save_data)
	_expect(bool(recovered.get("applied", false)), "running battle should persist a paused recovery marker")
	save_data = recovered.get("save_data", {})
	_expect(
		bool((save_data.get("active_battle", {}) as Dictionary).get("recovery_paused", false)),
		"recovered running battle should remain paused"
	)

	var fake_loss: Dictionary = (save_data.get("active_battle", {}) as Dictionary).duplicate(true)
	fake_loss["phase"] = "finished"
	fake_loss["outcome"] = "loss_timeout"
	var lost := session.settle_battle(save_data, fake_loss)
	_expect(bool(lost.get("applied", false)), "first loss should settle")
	save_data = lost.get("save_data", {})
	run = save_data.get("active_run", {})
	_expect(int(run.get("confidence", 0)) == 1, "first loss should consume one confidence")
	_expect(run.get("phase") == "battle_result_loss", "loss should wait for report acknowledgement")
	var duplicate_loss := session.settle_battle(save_data, fake_loss)
	_expect(not bool(duplicate_loss.get("applied", true)), "duplicate settlement should be idempotent")
	_expect(duplicate_loss.get("save_data", {}) == save_data, "duplicate settlement should not mutate save")

	var acknowledged_loss := session.acknowledge_battle_result(save_data)
	_expect(bool(acknowledged_loss.get("applied", false)), "loss report should be acknowledged")
	save_data = acknowledged_loss.get("save_data", {})
	var retry := session.start_battle(
		save_data,
		session.current_encounter(save_data).get("validation_draft", {})
	)
	_expect(bool(retry.get("applied", false)), "same encounter should be retryable")
	save_data = retry.get("save_data", {})
	run = save_data.get("active_run", {})
	_expect(
		String(run.get("current_encounter_instance_id", "")) == first_encounter_instance_id,
		"retry should keep the encounter instance"
	)
	_expect(
		int((run.get("encounter_instances", []) as Array)[0].get("reward_seed", 0)) == first_reward_seed,
		"retry should keep the reward seed"
	)
	_expect(
		String((save_data.get("active_battle", {}) as Dictionary).get("battle_attempt_id", "")) != first_attempt_id,
		"retry should use a new battle attempt identity"
	)

	for stage_index in range(5):
		run = save_data.get("active_run", {})
		if String(run.get("phase", "")) == "preparation":
			var encounter := session.current_encounter(save_data)
			var stage_started := session.start_battle(save_data, encounter.get("validation_draft", {}))
			_expect(bool(stage_started.get("applied", false)), "stage %d should start" % stage_index)
			save_data = stage_started.get("save_data", {})
		var battle: Dictionary = save_data.get("active_battle", {})
		var battle_service := BossBattleService.new()
		var finished := battle_service.advance(
			battle,
			int((battle.get("_encounter", {}) as Dictionary).get("duration_ms", 0))
		)
		_expect(String(finished.get("outcome", "")) == "victory", "stage %d validation draft should win" % stage_index)
		var settled := session.settle_battle(save_data, finished)
		_expect(bool(settled.get("applied", false)), "stage %d victory should settle" % stage_index)
		save_data = settled.get("save_data", {})
		var frozen_snapshot: Dictionary = (
			save_data.get("active_battle", {}) as Dictionary
		).get("snapshot", {})
		var acknowledged := session.acknowledge_battle_result(save_data)
		_expect(bool(acknowledged.get("applied", false)), "stage %d report should acknowledge" % stage_index)
		save_data = acknowledged.get("save_data", {})
		if stage_index < 4:
			var offered := session.prepare_upgrade_offer(save_data, frozen_snapshot)
			_expect(
				bool(offered.get("applied", false)),
				"stage %d should persist an upgrade offer: %s" % [
					stage_index,
					String(offered.get("error", "unknown"))
				]
			)
			if not bool(offered.get("applied", false)):
				_cleanup()
				_finish()
				return
			save_data = offered.get("save_data", {})
			var offer: Dictionary = offered.get("offer", {})
			var reloaded := ChallengeSaveService.load_from_path(_save_path)
			_expect(bool(reloaded.get("ok", false)), "pending offer save should reload")
			var reloaded_data: Dictionary = reloaded.get("data", {})
			var reloaded_run_value: Variant = reloaded_data.get("active_run")
			var reloaded_offer: Dictionary = (
				(reloaded_run_value as Dictionary).get("pending_upgrade_offer", {})
				if reloaded_run_value is Dictionary
				else {}
			)
			_expect(
				reloaded_run_value is Dictionary
				and String(reloaded_offer.get("offer_id", "")) == String(offer.get("offer_id", ""))
				and reloaded_offer.get("candidate_ids", []) == offer.get("candidate_ids", [])
				and String(reloaded_offer.get("input_signature", "")) == String(offer.get("input_signature", "")),
				"pending offer identity and order should survive reload"
			)
			var candidate_ids: Array = offer.get("candidate_ids", [])
			var chosen := session.choose_upgrade(
				save_data,
				String(offer.get("offer_id", "")),
				String(candidate_ids[0])
			)
			_expect(bool(chosen.get("applied", false)), "stage %d upgrade should apply" % stage_index)
			save_data = chosen.get("save_data", {})

	run = save_data.get("active_run", {})
	_expect(run.get("phase") == "run_complete", "fifth victory should complete the run")
	_expect((run.get("run_upgrades", []) as Array).size() == 4, "run should contain four structured upgrades")
	var rewarded := session.grant_completion_reward(save_data)
	_expect(bool(rewarded.get("applied", false)), "completion reward should apply")
	save_data = rewarded.get("save_data", {})
	_expect(int((save_data.get("meta", {}) as Dictionary).get("research_points", 0)) == 3, "completion should grant three research points")
	var duplicate_reward := session.grant_completion_reward(save_data)
	_expect(not bool(duplicate_reward.get("applied", true)), "completion reward should be idempotent")
	_expect(duplicate_reward.get("save_data", {}) == save_data, "duplicate reward should not mutate save")

	var research_unlock := session.unlock_research(save_data, "vanilla_scone")
	_expect(bool(research_unlock.get("applied", false)), "revealed three-point research node should unlock")
	save_data = research_unlock.get("save_data", {})
	_expect(int((save_data.get("meta", {}) as Dictionary).get("research_points", -1)) == 0, "research unlock should spend three points")
	var returned := session.return_to_hub(save_data)
	_expect(bool(returned.get("applied", false)), "rewarded run should return to hub")
	save_data = returned.get("save_data", {})
	_expect(save_data.get("active_run") == null, "returning to hub should clear active run")

	var next_created := session.create_standard_run(save_data, "standard_short_chain", 303)
	_expect(bool(next_created.get("applied", false)), "next run should be creatable")
	var next_run: Dictionary = next_created.get("save_data", {}).get("active_run", {})
	_expect(
		(next_run.get("permanent_pool_snapshot", {}).get("recipe_ids", []) as Array).has("vanilla_scone"),
		"newly unlocked recipe should appear only in the next run pool"
	)
	_expect((next_run.get("run_upgrades", []) as Array).is_empty(), "run upgrades should not persist between runs")

	var corrupted: Dictionary = next_created.get("save_data", {}).duplicate(true)
	var corrupted_battle: Dictionary = session.start_battle(
		corrupted,
		session.current_encounter(corrupted).get("validation_draft", {})
	).get("save_data", {})
	var bad_battle: Dictionary = corrupted_battle.get("active_battle", {})
	bad_battle["stage_index"] = 99
	corrupted_battle["active_battle"] = bad_battle
	var repaired := session.recover(corrupted_battle)
	_expect(bool(repaired.get("applied", false)), "identity mismatch should be repaired")
	_expect(repaired.get("save_data", {}).get("active_battle") == null, "bad active battle should be cleared")
	_expect(
		(repaired.get("save_data", {}).get("active_run", {}) as Dictionary).get("phase") == "preparation",
		"identity mismatch should return to same-stage preparation"
	)

	_cleanup()
	_finish()


func _cleanup() -> void:
	for suffix in ["", ".tmp", ".previous", ".broken", ".broken.previous"]:
		var path: String = _save_path + suffix
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _expect(condition: bool, message: String) -> void:
	if not condition and not _failures.has(message):
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("CHALLENGE_SESSION_RECOVERY_SELF_CHECK_PASS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
