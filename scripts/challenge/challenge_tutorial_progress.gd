class_name ChallengeTutorialProgress
extends RefCounted

const VERSION := 2
const VALID_STATUSES := ["active", "dismissed", "completed"]
const STEPS := [
	"boss_brief",
	"place_recipe",
	"rotate_recipe",
	"read_risk",
	"start_battle",
	"observe_battle",
	"read_report",
	"rearrange",
	"complete"
]
const ROTATABLE_RECIPE_IDS := ["milk_pudding", "blueberry_muffin"]
const STAGE_TWO_HINTS := [
	"five_stage_route",
	"upgrade_choice",
	"upgrade_prediction",
	"completion_reward",
	"research_unlock",
	"next_run_recipe"
]


static func default_state(start_step: String = "boss_brief") -> Dictionary:
	return {
		"version": VERSION,
		"status": "active",
		"step_id": start_step if STEPS.has(start_step) else "boss_brief",
		"completed_step_ids": [],
		"pre_battle_draft_fingerprint": "",
		"seen_stage_two_hint_ids": []
	}


func normalize(raw: Variant, context_surface: String = "preparation") -> Dictionary:
	var fallback_step := _context_step(context_surface)
	if not raw is Dictionary:
		return default_state(fallback_step)
	var value: Dictionary = raw.duplicate(true)
	var raw_version: Variant = value.get("version")
	var version := int(raw_version) if raw_version is int or raw_version is float else 0
	if version > VERSION:
		value["unsupported_newer_version"] = true
		return value
	value["version"] = VERSION
	var raw_status: Variant = value.get("status")
	if not raw_status is String or not VALID_STATUSES.has(raw_status):
		value["status"] = "active"
	var raw_step_id: Variant = value.get("step_id")
	if not raw_step_id is String or not STEPS.has(raw_step_id):
		value["step_id"] = fallback_step
	var completed: Array[String] = []
	var raw_completed_step_ids: Variant = value.get("completed_step_ids")
	if raw_completed_step_ids is Array:
		for step_value in raw_completed_step_ids:
			if step_value is String and STEPS.has(step_value) and not completed.has(step_value):
				completed.append(step_value)
	value["completed_step_ids"] = completed
	var raw_fingerprint: Variant = value.get("pre_battle_draft_fingerprint")
	value["pre_battle_draft_fingerprint"] = raw_fingerprint if raw_fingerprint is String else ""
	var seen_stage_two_hint_ids: Array[String] = []
	var raw_seen_stage_two_hint_ids: Variant = value.get("seen_stage_two_hint_ids")
	if raw_seen_stage_two_hint_ids is Array:
		for hint_value in raw_seen_stage_two_hint_ids:
			if (
				hint_value is String
				and STAGE_TWO_HINTS.has(hint_value)
				and not seen_stage_two_hint_ids.has(hint_value)
			):
				seen_stage_two_hint_ids.append(hint_value)
	value["seen_stage_two_hint_ids"] = seen_stage_two_hint_ids
	return value


func can_offer_stage_two_hint(state: Dictionary, hint_id: String) -> bool:
	var normalized := normalize(state)
	return (
		STAGE_TWO_HINTS.has(hint_id)
		and String(normalized.get("status", "")) == "completed"
		and not (normalized.get("seen_stage_two_hint_ids", []) as Array).has(hint_id)
	)


func mark_stage_two_hint_seen(state: Dictionary, hint_id: String) -> Dictionary:
	var next := normalize(state)
	if not STAGE_TWO_HINTS.has(hint_id):
		return next
	var seen: Array = next.get("seen_stage_two_hint_ids", [])
	if not seen.has(hint_id):
		seen.append(hint_id)
	next["seen_stage_two_hint_ids"] = seen
	return next


func apply_event(state: Dictionary, event_id: String, context: Dictionary = {}) -> Dictionary:
	var next := normalize(state)
	if String(next.get("status", "")) != "active":
		return next
	var step := String(next.get("step_id", "boss_brief"))
	match step:
		"boss_brief":
			if event_id == "boss_acknowledged":
				_complete_and_advance(next, "place_recipe")
		"place_recipe":
			if event_id == "recipe_placed":
				_complete_and_advance(next, "rotate_recipe")
		"rotate_recipe":
			if (
				event_id == "instance_rotated"
				and ROTATABLE_RECIPE_IDS.has(String(context.get("recipe_id", "")))
				and bool(context.get("shape_changed", false))
			):
				_complete_and_advance(next, "read_risk")
		"read_risk":
			if event_id == "risk_acknowledged" and bool(context.get("draft_valid", false)):
				_complete_and_advance(next, "start_battle")
		"start_battle":
			if event_id == "battle_started" and context.get("draft") is Dictionary:
				next["pre_battle_draft_fingerprint"] = draft_fingerprint(context["draft"])
				_complete_and_advance(next, "observe_battle")
		"observe_battle":
			if event_id == "battle_finished":
				_complete_and_advance(next, "read_report")
		"read_report":
			if event_id == "report_exited":
				var outcome := String(context.get("outcome", ""))
				var confidence := int(context.get("confidence", 0))
				_complete_and_advance(
					next,
					"rearrange" if outcome.begins_with("loss_") and confidence > 0 else "complete"
				)
		"rearrange":
			if (
				event_id == "draft_changed"
				and bool(context.get("draft_valid", false))
				and draft_fingerprint(context.get("draft", {}))
					!= String(next.get("pre_battle_draft_fingerprint", ""))
			):
				_complete_and_advance(next, "complete")
		"complete":
			if event_id == "tutorial_completed":
				_mark_completed(next)
	return next


func dismiss(state: Dictionary) -> Dictionary:
	var next := normalize(state)
	if String(next.get("status", "")) != "completed":
		next["status"] = "dismissed"
	return next


func resume(state: Dictionary, context_surface: String) -> Dictionary:
	var next := normalize(state, context_surface)
	if String(next.get("status", "")) != "completed":
		next["status"] = "active"
		if not _step_is_compatible(String(next.get("step_id", "")), context_surface):
			next["step_id"] = _context_step(context_surface)
	return next


static func draft_fingerprint(draft: Dictionary) -> String:
	var normalized: Array[Dictionary] = []
	for placement_value in draft.get("placements", []):
		var placement: Dictionary = placement_value
		normalized.append({
			"instance_id": String(placement.get("instance_id", "")),
			"recipe_id": String(placement.get("recipe_id", "")),
			"origin": placement.get("origin", []).duplicate(),
			"rotation": posmod(int(placement.get("rotation", 0)), 360)
		})
	normalized.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a["instance_id"]) < String(b["instance_id"])
	)
	return JSON.stringify(normalized)


func _context_step(context_surface: String) -> String:
	match context_surface:
		"battle":
			return "observe_battle"
		"settlement":
			return "read_report"
		"finished":
			return "complete"
	return "boss_brief"


func _complete_and_advance(state: Dictionary, next_step: String) -> void:
	var completed: Array = state.get("completed_step_ids", [])
	var current := String(state.get("step_id", ""))
	if STEPS.has(current) and not completed.has(current):
		completed.append(current)
	state["completed_step_ids"] = completed
	state["step_id"] = next_step


func _mark_completed(state: Dictionary) -> void:
	var completed: Array = state.get("completed_step_ids", [])
	if not completed.has("complete"):
		completed.append("complete")
	state["completed_step_ids"] = completed
	state["status"] = "completed"


func _step_is_compatible(step_id: String, context_surface: String) -> bool:
	match context_surface:
		"battle":
			return step_id == "observe_battle"
		"settlement":
			return step_id == "read_report"
		"finished":
			return step_id == "complete"
	return step_id in [
		"boss_brief",
		"place_recipe",
		"rotate_recipe",
		"read_risk",
		"start_battle",
		"rearrange",
		"complete"
	]
