extends SceneTree

const SESSION_PATH := "res://scripts/challenge/challenge_session_service.gd"

var _failures: Array[String] = []
var _save_path := OS.get_temp_dir().path_join("project_rest_two_endless_session_self_check.json")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_cleanup()
	var session = load(SESSION_PATH).new()
	session.save_path = _save_path
	var loaded: Dictionary = session.load_or_create()
	_expect(bool(loaded.get("applied", false)), "session should bootstrap")
	var save_data: Dictionary = loaded.get("save_data", {})
	var locked: Dictionary = session.create_endless_run(save_data, 7001)
	_expect(not bool(locked.get("applied", true)), "endless should be locked before a standard completion")
	_expect(String(locked.get("error", "")) == "endless_not_unlocked", "locked endless should explain its gate")

	var meta: Dictionary = save_data.get("meta", {})
	var records: Dictionary = meta.get("endless_records", {})
	records["unlocked"] = true
	meta["endless_records"] = records
	save_data["meta"] = meta
	var created: Dictionary = session.create_endless_run(save_data, 7001)
	_expect(bool(created.get("applied", false)), "unlocked endless run should start")
	save_data = created.get("save_data", {})
	_expect(String(save_data.get("active_run", {}).get("mode", "")) == "endless", "active run should be endless")

	for cleared_floor in range(5):
		var encounter: Dictionary = session.current_encounter(save_data)
		_expect(int(encounter.get("floor_number", 0)) == cleared_floor + 1, "current endless floor should be stable")
		var started: Dictionary = _start_with_fitting_draft(session, save_data, encounter)
		_expect(bool(started.get("applied", false)), "floor %d validation draft should enter battle" % (cleared_floor + 1))
		if not bool(started.get("applied", false)):
			break
		save_data = started.get("save_data", {})
		var battle: Dictionary = (save_data.get("active_battle", {}) as Dictionary).duplicate(true)
		battle["phase"] = "finished"
		battle["outcome"] = "victory"
		var settled: Dictionary = session.settle_battle(save_data, battle)
		_expect(bool(settled.get("applied", false)), "floor %d victory should settle" % (cleared_floor + 1))
		save_data = settled.get("save_data", {})
		if cleared_floor == 4:
			_expect(int(settled.get("confidence_recovered", 0)) == 0, "full confidence recovery node should remain capped")
		var acknowledged: Dictionary = session.acknowledge_battle_result(save_data)
		_expect(bool(acknowledged.get("applied", false)), "victory report should acknowledge")
		save_data = acknowledged.get("save_data", {})
		var run: Dictionary = save_data.get("active_run", {})
		var offered: Dictionary = session.prepare_upgrade_offer(save_data, run.get("last_battle_snapshot", {}))
		_expect(bool(offered.get("applied", false)), "every endless victory should offer an upgrade")
		save_data = offered.get("save_data", {})
		if cleared_floor == 0:
			var recovered_session = load(SESSION_PATH).new()
			recovered_session.save_path = _save_path
			var recovered: Dictionary = recovered_session.load_or_create()
			_expect(
				String(recovered.get("save_data", {}).get("active_run", {}).get("phase", "")) == "upgrade_select",
				"reload should restore pending endless upgrade"
			)
			session = recovered_session
			save_data = recovered.get("save_data", {})
		run = save_data.get("active_run", {})
		var offer: Dictionary = run.get("pending_upgrade_offer", {})
		var candidates: Array = offer.get("candidates", [])
		_expect(candidates.size() == 3, "endless offer should contain three candidates")
		if candidates.size() != 3:
			break
		var upgrade_id := String((candidates[0] as Dictionary).get("upgrade_id", ""))
		var chosen: Dictionary = session.choose_upgrade(save_data, String(offer.get("offer_id", "")), upgrade_id)
		_expect(bool(chosen.get("applied", false)), "endless upgrade should apply")
		save_data = chosen.get("save_data", {})
		_expect(int(save_data.get("active_run", {}).get("stage_index", -1)) == cleared_floor + 1, "upgrade should generate the next floor")

	var failing_run: Dictionary = (save_data.get("active_run", {}) as Dictionary).duplicate(true)
	failing_run["confidence"] = 1
	save_data["active_run"] = failing_run
	var failing_encounter: Dictionary = session.current_encounter(save_data)
	var loss_started: Dictionary = _start_with_fitting_draft(session, save_data, failing_encounter)
	if not bool(loss_started.get("applied", false)):
		_fail("terminal floor should begin: %s %s" % [loss_started.get("error", ""), loss_started.get("errors", [])])
		_finish()
		return
	save_data = loss_started.get("save_data", {})
	var losing_battle: Dictionary = (save_data.get("active_battle", {}) as Dictionary).duplicate(true)
	losing_battle["phase"] = "finished"
	losing_battle["outcome"] = "loss_timeout"
	var lost: Dictionary = session.settle_battle(save_data, losing_battle)
	_expect(bool(lost.get("applied", false)), "terminal loss should settle")
	save_data = lost.get("save_data", {})
	var ended_run: Dictionary = save_data.get("active_run", {})
	_expect(String(ended_run.get("phase", "")) == "run_failed", "zero confidence should end endless run")
	_expect(int(ended_run.get("highest_cleared_floor", 0)) == 5, "five cleared floors should be recorded")
	var ended_records: Dictionary = save_data.get("meta", {}).get("endless_records", {})
	_expect(int(ended_records.get("best_floor", 0)) == 5, "meta should save the highest cleared floor")
	_expect(not (ended_records.get("best_snapshot", {}) as Dictionary).is_empty(), "best run should keep a build snapshot")
	_expect(not (ended_records.get("best_snapshot", {}).get("key_battle_report", {}) as Dictionary).is_empty(), "best run should keep a key battle report")

	var rewarded: Dictionary = session.grant_completion_reward(save_data)
	_expect(bool(rewarded.get("applied", false)), "endless staged reward should apply")
	_expect(int(rewarded.get("points_granted", 0)) == 1, "five floors should award one research point")
	save_data = rewarded.get("save_data", {})
	var duplicate: Dictionary = session.grant_completion_reward(save_data)
	_expect(not bool(duplicate.get("applied", true)), "endless reward transaction should be idempotent")
	var returned: Dictionary = session.return_to_hub(save_data)
	_expect(bool(returned.get("applied", false)), "rewarded endless run should return to hub")
	save_data = returned.get("save_data", {})
	_expect(save_data.get("active_run") == null, "returning should clear active endless run")

	var final_session = load(SESSION_PATH).new()
	final_session.save_path = _save_path
	var final_loaded: Dictionary = final_session.load_or_create()
	var final_data: Dictionary = final_loaded.get("save_data", {})
	_expect(final_data.get("active_run") == null, "cleared hub state should survive reload")
	_expect(int(final_data.get("meta", {}).get("endless_records", {}).get("best_floor", 0)) == 5, "endless record should survive reload")
	_expect(int(final_data.get("meta", {}).get("research_points", 0)) == 1, "staged research reward should survive reload")
	_cleanup()
	_finish()


func _start_with_fitting_draft(session: Variant, save_data: Dictionary, encounter: Dictionary) -> Dictionary:
	var draft: Dictionary = (encounter.get("validation_draft", {}) as Dictionary).duplicate(true)
	var placements: Array = draft.get("placements", [])
	var result: Dictionary = session.start_battle(save_data, draft)
	while not bool(result.get("applied", false)) and placements.size() > 1:
		placements.pop_back()
		draft["placements"] = placements.duplicate(true)
		result = session.start_battle(save_data, draft)
	return result


func _cleanup() -> void:
	for suffix in ["", ".tmp", ".previous", ".broken", ".broken.previous"]:
		var path: String = _save_path + String(suffix)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	if not _failures.has(message):
		_failures.append(message)


func _finish() -> void:
	_cleanup()
	if _failures.is_empty():
		print("CHALLENGE_ENDLESS_SESSION_SELF_CHECK_PASS floors=5 reward=1")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
