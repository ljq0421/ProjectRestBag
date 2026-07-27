class_name BusinessRoundService
extends RefCounted

const STANDARD_DURATION_MS := 30000


static func create_standard(round_id: int) -> Dictionary:
	return {
		"round_id": maxi(1, round_id),
		"kind": "standard",
		"phase": "adjusting",
		"duration_ms": STANDARD_DURATION_MS,
		"elapsed_ms": 0,
		"remaining_ms": STANDARD_DURATION_MS,
		"heat": 0,
		"paused": false
	}


static func create_challenge(round_id: int, duration_seconds: int, challenge: Dictionary) -> Dictionary:
	var duration_ms := maxi(1, duration_seconds) * 1000
	return {
		"round_id": maxi(1, round_id),
		"kind": "challenge",
		"phase": "adjusting",
		"duration_ms": duration_ms,
		"elapsed_ms": 0,
		"remaining_ms": duration_ms,
		"heat": 0,
		"paused": false,
		"challenge": challenge.duplicate(true)
	}


static func start_round(round_state: Dictionary, layout_snapshot: Dictionary, item_states: Dictionary) -> Dictionary:
	var result := round_state.duplicate(true)
	if String(result.get("phase", "")) != "adjusting":
		return result
	result["phase"] = "running"
	result["layout_snapshot"] = layout_snapshot.duplicate(true)
	result["item_states"] = item_states.duplicate(true)
	return result


static func advance(round_state: Dictionary, delta_ms: int) -> Dictionary:
	var result := round_state.duplicate(true)
	if String(result.get("phase", "")) != "running" or bool(result.get("paused", false)) or delta_ms <= 0:
		return result
	var duration_ms := maxi(1, int(result.get("duration_ms", STANDARD_DURATION_MS)))
	var elapsed_ms := mini(duration_ms, maxi(0, int(result.get("elapsed_ms", 0))) + delta_ms)
	result["elapsed_ms"] = elapsed_ms
	result["remaining_ms"] = duration_ms - elapsed_ms
	if elapsed_ms >= duration_ms:
		result["phase"] = "settlement"
	return result


static func pause(round_state: Dictionary) -> Dictionary:
	var result := round_state.duplicate(true)
	if String(result.get("phase", "")) == "running":
		result["paused"] = true
	return result


static func resume(round_state: Dictionary) -> Dictionary:
	var result := round_state.duplicate(true)
	if String(result.get("phase", "")) == "running":
		result["paused"] = false
	return result


static func complete_settlement(round_state: Dictionary) -> Dictionary:
	if String(round_state.get("phase", "")) != "settlement":
		return round_state.duplicate(true)
	var completed_round_id := maxi(1, int(round_state.get("round_id", 1)))
	var next_round := create_standard(completed_round_id + 1)
	next_round["previous_round_id"] = completed_round_id
	return next_round
