class_name Stage11PlaytestTelemetryService
extends RefCounted

const VERSION := 1
const FIELD := "stage11_playtest"
const VALID_COHORTS := ["new", "mid", "late"]


func begin(meta: Dictionary, participant_id: String, cohort: String) -> Dictionary:
	var clean_id := participant_id.strip_edges()
	var clean_cohort := cohort.strip_edges()
	if clean_id.is_empty() or clean_cohort not in VALID_COHORTS:
		return meta.duplicate(true)
	var next_meta := meta.duplicate(true)
	next_meta[FIELD] = {
		"version": VERSION,
		"enabled": true,
		"participant_id": clean_id,
		"cohort": clean_cohort,
		"status": "active",
		"started_unix_ms": Time.get_unix_time_from_system() * 1000,
		"completed_unix_ms": 0,
		"event_sequence": 0,
		"events": []
	}
	return next_meta


func record(meta: Dictionary, event_type: String, payload: Dictionary = {}) -> Dictionary:
	var next_meta := meta.duplicate(true)
	var state_value: Variant = next_meta.get(FIELD)
	if not state_value is Dictionary:
		return next_meta
	var state: Dictionary = (state_value as Dictionary).duplicate(true)
	if not bool(state.get("enabled", false)) or String(state.get("status", "")) != "active":
		return next_meta
	var clean_type := event_type.strip_edges()
	if clean_type.is_empty():
		return next_meta
	var sequence := int(state.get("event_sequence", 0)) + 1
	var events: Array = (state.get("events", []) as Array).duplicate(true)
	events.append({
		"sequence": sequence,
		"type": clean_type,
		"unix_ms": Time.get_unix_time_from_system() * 1000,
		"payload": payload.duplicate(true)
	})
	state["event_sequence"] = sequence
	state["events"] = events
	next_meta[FIELD] = state
	return next_meta


func complete(meta: Dictionary) -> Dictionary:
	var next_meta := record(meta, "session_completed")
	var state_value: Variant = next_meta.get(FIELD)
	if not state_value is Dictionary:
		return next_meta
	var state: Dictionary = (state_value as Dictionary).duplicate(true)
	state["status"] = "completed"
	state["completed_unix_ms"] = Time.get_unix_time_from_system() * 1000
	next_meta[FIELD] = state
	return next_meta


func state(meta: Dictionary) -> Dictionary:
	var value: Variant = meta.get(FIELD)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func validate(state_value: Variant) -> Array[String]:
	var errors: Array[String] = []
	if not state_value is Dictionary:
		return ["stage11 playtest state must be a dictionary"]
	var state: Dictionary = state_value
	if int(state.get("version", 0)) != VERSION:
		errors.append("stage11 playtest version must equal %d" % VERSION)
	if String(state.get("participant_id", "")).strip_edges().is_empty():
		errors.append("stage11 participant_id is required")
	if String(state.get("cohort", "")) not in VALID_COHORTS:
		errors.append("stage11 cohort must be new, mid, or late")
	if String(state.get("status", "")) not in ["active", "completed"]:
		errors.append("stage11 status must be active or completed")
	if not state.get("events", []) is Array:
		errors.append("stage11 events must be an array")
	return errors
