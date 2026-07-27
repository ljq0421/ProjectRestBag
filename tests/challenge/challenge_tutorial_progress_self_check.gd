extends SceneTree

const TutorialProgress = preload("res://scripts/challenge/challenge_tutorial_progress.gd")

var _failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var service = TutorialProgress.new()
	var state := service.normalize(null, "preparation")
	_expect(state["version"] == 1, "tutorial version defaults to 1")
	_expect(state["status"] == "active", "missing state auto activates")
	_expect(state["step_id"] == "boss_brief", "preparation starts at boss brief")

	state = service.apply_event(state, "boss_acknowledged")
	_expect(state["step_id"] == "place_recipe", "boss acknowledgement advances")
	_expect(service.apply_event(state, "drag_started")["step_id"] == "place_recipe", "drag start cannot advance")
	state = service.apply_event(state, "recipe_placed", {"recipe_id": "butter_cookie"})
	_expect(state["step_id"] == "rotate_recipe", "successful placement advances")
	_expect(service.apply_event(state, "instance_rotated", {
		"recipe_id": "butter_cookie",
		"shape_changed": false
	})["step_id"] == "rotate_recipe", "non-rotatable recipe cannot advance")
	state = service.apply_event(state, "instance_rotated", {
		"recipe_id": "milk_pudding",
		"shape_changed": true
	})
	_expect(state["step_id"] == "read_risk", "real rotatable shape change advances")

	var initial_draft := {"placements": [{
		"instance_id": "milk_pudding_1",
		"recipe_id": "milk_pudding",
		"origin": [1, 1],
		"rotation": 90
	}]}
	state = service.apply_event(state, "risk_acknowledged", {"draft_valid": true})
	state = service.apply_event(state, "battle_started", {"draft": initial_draft})
	_expect(state["step_id"] == "observe_battle", "successful battle start advances")
	_expect(not String(state["pre_battle_draft_fingerprint"]).is_empty(), "battle stores draft fingerprint")
	state = service.apply_event(state, "battle_finished")
	_expect(state["step_id"] == "read_report", "real battle finish opens report step")

	var victory := service.apply_event(state, "report_exited", {
		"outcome": "victory",
		"confidence": 2
	})
	_expect(victory["step_id"] == "complete", "victory skips rearrange")

	var retryable_loss := service.apply_event(state, "report_exited", {
		"outcome": "loss_timeout",
		"confidence": 1
	})
	_expect(retryable_loss["step_id"] == "rearrange", "retryable loss requires rearrange")
	_expect(service.apply_event(retryable_loss, "draft_changed", {
		"draft": initial_draft,
		"draft_valid": true
	})["step_id"] == "rearrange", "same fingerprint does not advance")

	var changed_draft := initial_draft.duplicate(true)
	changed_draft["placements"][0]["origin"] = [2, 1]
	retryable_loss = service.apply_event(retryable_loss, "draft_changed", {
		"draft": changed_draft,
		"draft_valid": true
	})
	_expect(retryable_loss["step_id"] == "complete", "real valid rearrangement advances")

	var terminal_loss := service.apply_event(state, "report_exited", {
		"outcome": "loss_reputation",
		"confidence": 0
	})
	_expect(terminal_loss["step_id"] == "complete", "terminal loss cannot deadlock")

	var dismissed := service.dismiss(state)
	_expect(dismissed["status"] == "dismissed", "dismiss stores status")
	var resumed_settlement := service.resume(dismissed, "settlement")
	_expect(resumed_settlement["status"] == "active", "help resumes dismissed tutorial")
	_expect(resumed_settlement["step_id"] == "read_report", "resume coerces to current surface")

	var future_raw := {"version": 2, "future_field": {"keep": true}}
	var newer_state := service.normalize(future_raw)
	_expect(newer_state.get("future_field", {}) == {"keep": true}, "newer version fields survive normalization")
	_expect(newer_state.get("unsupported_newer_version", false), "newer version gains runtime marker")
	_expect(not future_raw.has("unsupported_newer_version"), "normalization does not mutate future-version save data")

	var malformed_raw := {
		"version": {},
		"status": ["active"],
		"step_id": {"value": "read_report"},
		"completed_step_ids": null,
		"pre_battle_draft_fingerprint": ["not", "a", "string"],
		"unknown_nested": {"keep": [1, {"value": true}]}
	}
	var sanitized := service.normalize(malformed_raw, "settlement")
	_expect(sanitized["version"] == 1, "malformed version falls back without conversion")
	_expect(sanitized["status"] == "active", "malformed status falls back without conversion")
	_expect(sanitized["step_id"] == "read_report", "malformed step falls back to current surface")
	_expect(sanitized["completed_step_ids"] == [], "non-array completed steps sanitize without iteration")
	_expect(sanitized["pre_battle_draft_fingerprint"] == "", "non-string fingerprint sanitizes")
	_expect(
		sanitized["unknown_nested"] == {"keep": [1, {"value": true}]},
		"unknown onboarding fields survive malformed-field sanitization"
	)
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	_failed = true
	push_error(message)


func _finish() -> void:
	if _failed:
		quit(1)
		return
	print("CHALLENGE_TUTORIAL_PROGRESS_SELF_CHECK_PASS")
	quit(0)
