extends SceneTree

const ChallengeTutorialProgress = preload(
	"res://scripts/challenge/challenge_tutorial_progress.gd"
)

var _failures: Array[String] = []


func _init() -> void:
	var tutorial = ChallengeTutorialProgress.new()
	var state := tutorial.default_state()
	_expect(
		not tutorial.can_offer_stage_two_hint(state, "five_stage_route"),
		"stage two hints wait until the core tutorial is complete"
	)
	state["status"] = "completed"
	_expect(
		tutorial.can_offer_stage_two_hint(state, "five_stage_route"),
		"completed players receive the five-stage hint"
	)
	var seen := tutorial.mark_stage_two_hint_seen(state, "five_stage_route")
	_expect(
		not tutorial.can_offer_stage_two_hint(seen, "five_stage_route"),
		"seen stage two hints are not repeated"
	)
	_expect(
		tutorial.can_offer_stage_two_hint(seen, "upgrade_choice"),
		"each stage two topic is tracked independently"
	)
	var normalized := tutorial.normalize({
		"version": 2,
		"status": "completed",
		"step_id": "complete",
		"completed_step_ids": ChallengeTutorialProgress.STEPS.duplicate(),
		"pre_battle_draft_fingerprint": "",
		"seen_stage_two_hint_ids": [
			"five_stage_route",
			"five_stage_route",
			"unknown_hint"
		]
	})
	_expect(
		normalized["seen_stage_two_hint_ids"] == ["five_stage_route"],
		"normalization deduplicates and filters contextual hints"
	)
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition and not _failures.has(message):
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("CHALLENGE_STAGE_TWO_TUTORIAL_SELF_CHECK_PASS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
