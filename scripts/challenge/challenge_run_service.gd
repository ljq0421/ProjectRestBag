class_name ChallengeRunService
extends RefCounted


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


func register_result(run_state: Dictionary, settlement: Dictionary) -> Dictionary:
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
