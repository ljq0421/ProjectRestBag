class_name ChallengeRunService
extends RefCounted

const STANDARD_ENCOUNTER_TYPES: Array[String] = [
	"normal",
	"normal",
	"normal",
	"elite",
	"final_boss"
]


func create_single_encounter(run_id: String, seed: int, encounter_id: String) -> Dictionary:
	return {
		"run_id": run_id,
		"mode": "vertical_slice",
		"seed": seed,
		"phase": "preparation",
		"confidence": 2,
		"encounter_id": encounter_id,
		"encounter_seed": seed,
		"reward_seed": seed + 1000,
		"settled_ids": []
	}


func create_standard_run(
	run_id: String,
	seed: int,
	route_id: String,
	permanent_pool_snapshot: Dictionary
) -> Dictionary:
	return {
		"run_id": run_id.strip_edges(),
		"mode": "standard",
		"seed": seed,
		"phase": "run_create",
		"route_id": route_id.strip_edges(),
		"stage_index": 0,
		"confidence": 2,
		"permanent_pool_snapshot": permanent_pool_snapshot.duplicate(true),
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
		"research_rewarded": false
	}


func lock_encounters(run_state: Dictionary, encounter_instances: Array) -> Dictionary:
	var next_run := run_state.duplicate(true)
	if String(next_run.get("mode", "")) != "standard":
		return _rejected(next_run, "standard_run_required")
	if String(next_run.get("phase", "")) != "run_create":
		return _rejected(next_run, "encounters_already_locked")
	if encounter_instances.size() != STANDARD_ENCOUNTER_TYPES.size():
		return _rejected(next_run, "five_encounters_required")

	var locked: Array = []
	var run_id := String(next_run.get("run_id", ""))
	for stage_index in range(STANDARD_ENCOUNTER_TYPES.size()):
		var value: Variant = encounter_instances[stage_index]
		if not value is Dictionary:
			return _rejected(next_run, "invalid_encounter")
		var encounter: Dictionary = (value as Dictionary).duplicate(true)
		if String(encounter.get("encounter_type", "")) != STANDARD_ENCOUNTER_TYPES[stage_index]:
			return _rejected(next_run, "invalid_encounter_sequence")
		if String(encounter.get("encounter_id", "")).strip_edges().is_empty():
			return _rejected(next_run, "encounter_id_required")
		var expected_instance_id := _encounter_instance_id(run_id, stage_index)
		var supplied_instance_id := String(encounter.get("encounter_instance_id", "")).strip_edges()
		if not supplied_instance_id.is_empty() and supplied_instance_id != expected_instance_id:
			return _rejected(next_run, "invalid_encounter_instance_id")
		encounter["encounter_instance_id"] = expected_instance_id
		encounter["stage_index"] = stage_index
		locked.append(encounter)

	next_run["encounter_instances"] = locked
	next_run["phase"] = "preparation"
	next_run["current_encounter_instance_id"] = _encounter_instance_id(run_id, 0)
	return _applied(next_run)


func current_encounter(run_state: Dictionary) -> Dictionary:
	if String(run_state.get("mode", "")) not in ["standard", "endless"]:
		return {}
	var encounters: Array = run_state.get("encounter_instances", [])
	var stage_index := int(run_state.get("stage_index", -1))
	if stage_index < 0 or stage_index >= encounters.size():
		return {}
	var value: Variant = encounters[stage_index]
	if not value is Dictionary:
		return {}
	return (value as Dictionary).duplicate(true)


func begin_battle(run_state: Dictionary) -> Dictionary:
	var next_run := run_state.duplicate(true)
	if String(next_run.get("mode", "")) not in ["standard", "endless"]:
		return _rejected(next_run, "challenge_run_required")
	var phase := String(next_run.get("phase", ""))
	if phase != "preparation" and phase != "battle_result_loss":
		return _rejected(next_run, "battle_cannot_begin")
	var encounter := current_encounter(next_run)
	if encounter.is_empty():
		return _rejected(next_run, "current_encounter_missing")

	var attempt_index := int(next_run.get("next_attempt_index", 0))
	var encounter_instance_id := String(encounter.get("encounter_instance_id", ""))
	var battle_attempt_id := "%s:attempt:%d" % [encounter_instance_id, attempt_index]
	next_run["next_attempt_index"] = attempt_index + 1
	next_run["current_battle_attempt_id"] = battle_attempt_id
	next_run["current_encounter_instance_id"] = encounter_instance_id
	next_run["phase"] = "battle"
	return {
		"applied": true,
		"run": next_run,
		"battle_attempt_id": battle_attempt_id,
		"encounter_instance_id": encounter_instance_id,
		"attempt_index": attempt_index
	}


func register_result(run_state: Dictionary, settlement: Dictionary) -> Dictionary:
	var mode := String(run_state.get("mode", ""))
	if mode == "standard":
		return _register_standard_result(run_state, settlement)
	if mode == "endless":
		return _register_endless_result(run_state, settlement)
	return _register_single_result(run_state, settlement)


func attach_upgrade_offer(run_state: Dictionary, offer: Dictionary) -> Dictionary:
	var next_run := run_state.duplicate(true)
	var mode := String(next_run.get("mode", ""))
	if mode not in ["standard", "endless"]:
		return _rejected(next_run, "challenge_run_required")
	if String(next_run.get("phase", "")) != "battle_result_win":
		return _rejected(next_run, "upgrade_offer_not_expected")
	var stage_index := int(next_run.get("stage_index", -1))
	if stage_index < 0 or (mode == "standard" and stage_index >= STANDARD_ENCOUNTER_TYPES.size() - 1):
		return _rejected(next_run, "upgrade_offer_not_expected")
	if not (next_run.get("pending_upgrade_offer", {}) as Dictionary).is_empty():
		return _rejected(next_run, "upgrade_offer_already_attached")

	var expected_offer_id := _upgrade_offer_id(String(next_run.get("run_id", "")), stage_index)
	if String(offer.get("offer_id", "")) != expected_offer_id:
		return _rejected(next_run, "invalid_upgrade_offer_id")
	var candidate_ids := _offer_candidate_ids(offer)
	if candidate_ids.size() != 3:
		return _rejected(next_run, "three_upgrade_candidates_required")
	var unique_ids: Array[String] = []
	for candidate_id in candidate_ids:
		if candidate_id.is_empty() or unique_ids.has(candidate_id):
			return _rejected(next_run, "invalid_upgrade_candidates")
		unique_ids.append(candidate_id)

	var locked_offer := offer.duplicate(true)
	locked_offer["offer_id"] = expected_offer_id
	locked_offer["candidate_ids"] = unique_ids.duplicate()
	next_run["pending_upgrade_offer"] = locked_offer
	next_run["phase"] = "upgrade_select"
	return _applied(next_run)


func choose_upgrade(
	run_state: Dictionary,
	offer_id: String,
	upgrade_id: String,
	reward_tx: String
) -> Dictionary:
	var next_run := run_state.duplicate(true)
	if String(next_run.get("mode", "")) not in ["standard", "endless"]:
		return _rejected(next_run, "challenge_run_required")
	var applied_transactions: Array = next_run.get("applied_run_reward_transaction_ids", [])
	if applied_transactions.has(reward_tx):
		return _rejected(next_run)
	if String(next_run.get("phase", "")) != "upgrade_select":
		return _rejected(next_run, "upgrade_choice_not_expected")

	var offer: Dictionary = next_run.get("pending_upgrade_offer", {})
	if offer_id != String(offer.get("offer_id", "")):
		return _rejected(next_run, "upgrade_offer_mismatch")
	if not _offer_candidate_ids(offer).has(upgrade_id):
		return _rejected(next_run, "upgrade_not_offered")
	var expected_reward_tx := "%s:%s" % [offer_id, upgrade_id]
	if reward_tx != expected_reward_tx:
		return _rejected(next_run, "invalid_upgrade_reward_transaction")

	applied_transactions.append(reward_tx)
	next_run["applied_run_reward_transaction_ids"] = applied_transactions
	var upgrades: Array = next_run.get("run_upgrades", [])
	upgrades.append(upgrade_id)
	next_run["run_upgrades"] = upgrades
	var history: Array = next_run.get("stage_history", [])
	history.append({
		"kind": "upgrade",
		"stage_index": int(next_run.get("stage_index", 0)),
		"offer_id": offer_id,
		"upgrade_id": upgrade_id,
		"reward_transaction_id": reward_tx
	})
	next_run["stage_history"] = history
	return _advance_after_upgrade(next_run)


func finalize_upgrade_choice(
	run_state: Dictionary,
	offer_id: String,
	upgrade_id: String,
	reward_tx: String
) -> Dictionary:
	var next_run := run_state.duplicate(true)
	if String(next_run.get("mode", "")) not in ["standard", "endless"]:
		return _rejected(next_run, "challenge_run_required")
	if String(next_run.get("phase", "")) != "upgrade_select":
		return _rejected(next_run, "upgrade_choice_not_expected")
	var offer: Dictionary = next_run.get("pending_upgrade_offer", {})
	if String(offer.get("offer_id", "")) != offer_id:
		return _rejected(next_run, "upgrade_offer_mismatch")
	if not _offer_candidate_ids(offer).has(upgrade_id):
		return _rejected(next_run, "upgrade_not_offered")
	if reward_tx != "%s:%s" % [offer_id, upgrade_id]:
		return _rejected(next_run, "invalid_upgrade_reward_transaction")
	if not (next_run.get("applied_run_reward_transaction_ids", []) as Array).has(reward_tx):
		return _rejected(next_run, "upgrade_effect_not_applied")
	if not _run_has_upgrade(next_run.get("run_upgrades", []), upgrade_id):
		return _rejected(next_run, "upgrade_effect_not_applied")
	var history: Array = next_run.get("stage_history", [])
	history.append({
		"kind": "upgrade",
		"stage_index": int(next_run.get("stage_index", 0)),
		"offer_id": offer_id,
		"upgrade_id": upgrade_id,
		"reward_transaction_id": reward_tx
	})
	next_run["stage_history"] = history
	return _advance_after_upgrade(next_run)


func acknowledge_battle_result(run_state: Dictionary) -> Dictionary:
	var next_run := run_state.duplicate(true)
	var phase := String(next_run.get("phase", ""))
	if phase == "battle_result_loss":
		next_run["phase"] = "preparation"
	elif phase != "battle_result_win" and phase != "run_complete" and phase != "run_failed":
		return _rejected(next_run, "battle_result_not_ready")
	next_run["battle_result_acknowledged"] = true
	return _applied(next_run)


func _advance_after_upgrade(next_run: Dictionary) -> Dictionary:
	next_run["stage_index"] = int(next_run.get("stage_index", 0)) + 1
	next_run["next_attempt_index"] = 0
	next_run["current_battle_attempt_id"] = ""
	next_run["current_encounter_instance_id"] = _encounter_instance_id(
		String(next_run.get("run_id", "")),
		int(next_run["stage_index"])
	)
	next_run["pending_upgrade_offer"] = {}
	next_run["phase"] = "preparation"
	return _applied(next_run)


func _run_has_upgrade(upgrades: Array, upgrade_id: String) -> bool:
	for value in upgrades:
		if value is Dictionary and String(value.get("upgrade_id", "")) == upgrade_id:
			return true
		if value is String and String(value) == upgrade_id:
			return true
	return false


func mark_research_rewarded(run_state: Dictionary, reward_tx: String) -> Dictionary:
	var next_run := run_state.duplicate(true)
	if String(next_run.get("mode", "")) != "standard":
		return _rejected(next_run, "standard_run_required")
	var transactions: Array = next_run.get("applied_run_reward_transaction_ids", [])
	if transactions.has(reward_tx):
		return _rejected(next_run)
	if String(next_run.get("phase", "")) != "run_complete":
		return _rejected(next_run, "research_reward_not_expected")
	var expected_reward_tx := "%s:research-complete" % String(next_run.get("run_id", ""))
	if reward_tx != expected_reward_tx:
		return _rejected(next_run, "invalid_research_reward_transaction")
	transactions.append(reward_tx)
	next_run["applied_run_reward_transaction_ids"] = transactions
	next_run["research_reward_transaction_id"] = reward_tx
	next_run["research_rewarded"] = true
	return _applied(next_run)


func return_to_hub(run_state: Dictionary) -> Dictionary:
	var next_run := run_state.duplicate(true)
	var mode := String(next_run.get("mode", ""))
	if mode not in ["standard", "endless"]:
		return _rejected(next_run, "challenge_run_required")
	var phase := String(next_run.get("phase", ""))
	var ready := false
	if mode == "standard":
		ready = phase == "run_failed" or (phase == "run_complete" and bool(next_run.get("research_rewarded", false)))
	else:
		ready = phase == "run_failed" and bool(next_run.get("endless_rewarded", false))
	if not ready:
		return _rejected(next_run, "run_not_ready_to_return")
	next_run["phase"] = "meta_hub"
	return _applied(next_run)


func _register_single_result(run_state: Dictionary, settlement: Dictionary) -> Dictionary:
	var next_run: Dictionary = run_state.duplicate(true)
	var settlement_id := String(settlement.get("settlement_id", "")).strip_edges()
	if settlement_id.is_empty():
		return {
			"applied": false,
			"error": "settlement_id_required",
			"run": next_run
		}
	var settled_ids: Array = next_run.get("settled_ids", [])
	if settled_ids.has(settlement_id):
		return {
			"applied": false,
			"run": next_run
		}
	if String(settlement.get("encounter_id", "")) != String(next_run.get("encounter_id", "")):
		return {
			"applied": false,
			"error": "encounter_mismatch",
			"run": next_run
		}
	if String(next_run.get("phase", "")) == "ended" or String(next_run.get("phase", "")) == "completed":
		return {
			"applied": false,
			"error": "run_already_finished",
			"run": next_run
		}

	var outcome := String(settlement.get("outcome", ""))
	if outcome != "victory" and not outcome.begins_with("loss_"):
		return {
			"applied": false,
			"error": "unknown_outcome",
			"run": next_run
		}

	settled_ids.append(settlement_id)
	next_run["settled_ids"] = settled_ids
	next_run["last_settlement_id"] = settlement_id
	next_run["last_outcome"] = outcome
	if outcome == "victory":
		next_run["phase"] = "completed"
	else:
		next_run["confidence"] = maxi(0, int(next_run.get("confidence", 0)) - 1)
		next_run["phase"] = "preparation" if int(next_run["confidence"]) > 0 else "ended"
	return {
		"applied": true,
		"run": next_run
	}


func _register_standard_result(run_state: Dictionary, settlement: Dictionary) -> Dictionary:
	var next_run := run_state.duplicate(true)
	var outcome := String(settlement.get("outcome", ""))
	if outcome != "victory" and not outcome.begins_with("loss_"):
		return _rejected(next_run, "unknown_outcome")
	var battle_attempt_id := String(next_run.get("current_battle_attempt_id", ""))
	var expected_settlement_id := "%s:%s" % [battle_attempt_id, outcome]
	var settlement_id := String(settlement.get("settlement_id", expected_settlement_id)).strip_edges()
	var settled_ids: Array = next_run.get("settled_settlement_ids", [])
	if settled_ids.has(settlement_id):
		return _rejected(next_run)
	if String(next_run.get("phase", "")) != "battle" or battle_attempt_id.is_empty():
		return _rejected(next_run, "battle_not_active")
	if settlement_id != expected_settlement_id:
		return _rejected(next_run, "invalid_settlement_id")

	var encounter := current_encounter(next_run)
	if encounter.is_empty():
		return _rejected(next_run, "current_encounter_missing")
	var encounter_instance_id := String(encounter.get("encounter_instance_id", ""))
	var supplied_encounter_instance_id := String(
		settlement.get("encounter_instance_id", settlement.get("encounter_id", ""))
	)
	if supplied_encounter_instance_id != encounter_instance_id:
		return _rejected(next_run, "encounter_mismatch")

	settled_ids.append(settlement_id)
	next_run["settled_settlement_ids"] = settled_ids
	next_run["last_settlement_id"] = settlement_id
	next_run["last_outcome"] = outcome
	var history: Array = next_run.get("stage_history", [])
	history.append({
		"kind": "battle",
		"stage_index": int(next_run.get("stage_index", 0)),
		"encounter_id": String(encounter.get("encounter_id", "")),
		"encounter_instance_id": encounter_instance_id,
		"battle_attempt_id": battle_attempt_id,
		"settlement_id": settlement_id,
		"outcome": outcome
	})
	next_run["stage_history"] = history

	if outcome == "victory":
		if int(next_run.get("stage_index", 0)) == STANDARD_ENCOUNTER_TYPES.size() - 1:
			next_run["phase"] = "run_complete"
			next_run["pending_upgrade_offer"] = {}
		else:
			next_run["phase"] = "battle_result_win"
	else:
		next_run["confidence"] = maxi(0, int(next_run.get("confidence", 0)) - 1)
		next_run["phase"] = "battle_result_loss" if int(next_run["confidence"]) > 0 else "run_failed"

	return {
		"applied": true,
		"run": next_run,
		"settlement_id": settlement_id
	}


func _register_endless_result(run_state: Dictionary, settlement: Dictionary) -> Dictionary:
	var next_run := run_state.duplicate(true)
	var outcome := String(settlement.get("outcome", ""))
	if outcome != "victory" and not outcome.begins_with("loss_"):
		return _rejected(next_run, "unknown_outcome")
	var battle_attempt_id := String(next_run.get("current_battle_attempt_id", ""))
	var expected_settlement_id := "%s:%s" % [battle_attempt_id, outcome]
	var settlement_id := String(settlement.get("settlement_id", expected_settlement_id)).strip_edges()
	var settled_ids: Array = next_run.get("settled_settlement_ids", [])
	if settled_ids.has(settlement_id):
		return _rejected(next_run)
	if String(next_run.get("phase", "")) != "battle" or battle_attempt_id.is_empty():
		return _rejected(next_run, "battle_not_active")
	if settlement_id != expected_settlement_id:
		return _rejected(next_run, "invalid_settlement_id")
	var encounter := current_encounter(next_run)
	if encounter.is_empty():
		return _rejected(next_run, "current_encounter_missing")
	var encounter_instance_id := String(encounter.get("encounter_instance_id", ""))
	if String(settlement.get("encounter_instance_id", "")) != encounter_instance_id:
		return _rejected(next_run, "encounter_mismatch")
	settled_ids.append(settlement_id)
	next_run["settled_settlement_ids"] = settled_ids
	next_run["last_settlement_id"] = settlement_id
	next_run["last_outcome"] = outcome
	var history: Array = next_run.get("stage_history", [])
	history.append({
		"kind": "battle",
		"stage_index": int(next_run.get("stage_index", 0)),
		"floor_number": int(next_run.get("stage_index", 0)) + 1,
		"encounter_id": String(encounter.get("encounter_id", "")),
		"encounter_instance_id": encounter_instance_id,
		"battle_attempt_id": battle_attempt_id,
		"settlement_id": settlement_id,
		"outcome": outcome
	})
	next_run["stage_history"] = history
	if outcome == "victory":
		next_run["highest_cleared_floor"] = int(next_run.get("stage_index", 0)) + 1
		next_run["phase"] = "battle_result_win"
	else:
		next_run["confidence"] = maxi(0, int(next_run.get("confidence", 0)) - 1)
		next_run["phase"] = "battle_result_loss" if int(next_run["confidence"]) > 0 else "run_failed"
	return {"applied": true, "run": next_run, "settlement_id": settlement_id}


func _offer_candidate_ids(offer: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var source: Variant = offer.get("candidate_ids", offer.get("candidates", []))
	if not source is Array:
		return result
	for value in source as Array:
		var candidate_id := ""
		if value is Dictionary:
			candidate_id = String((value as Dictionary).get("upgrade_id", (value as Dictionary).get("id", "")))
		else:
			candidate_id = String(value)
		result.append(candidate_id.strip_edges())
	return result


func _encounter_instance_id(run_id: String, stage_index: int) -> String:
	return "%s:stage:%d" % [run_id, stage_index]


func _upgrade_offer_id(run_id: String, stage_index: int) -> String:
	return "%s:upgrade:%d" % [run_id, stage_index]


func _applied(run_state: Dictionary) -> Dictionary:
	return {
		"applied": true,
		"run": run_state
	}


func _rejected(run_state: Dictionary, error := "") -> Dictionary:
	var result := {
		"applied": false,
		"run": run_state
	}
	if not error.is_empty():
		result["error"] = error
	return result
