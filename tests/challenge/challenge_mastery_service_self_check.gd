extends SceneTree

const MasteryService = preload("res://scripts/challenge/challenge_mastery_service.gd")
var failures: Array[String] = []

func _init() -> void:
	var file := FileAccess.open("res://doc/challenge/challenge_masteries.json", FileAccess.READ)
	var defs: Dictionary = (JSON.parse_string(file.get_as_text()) as Dictionary).get("masteries", {}); file.close()
	var meta := {"route_first_clear_ids": ["standard_short_chain"], "completed_mastery_ids": [], "revealed_research_node_ids": [], "endless_records": {"best_floor": 0}}
	var service = MasteryService.new()
	var result := service.evaluate(meta, defs)
	_expect(bool(result.get("applied", false)), "route A mastery should complete")
	meta = result.get("meta", {})
	_expect((meta.get("completed_mastery_ids", []) as Array).has("route_a_first_clear"), "completion should persist")
	var duplicate := service.evaluate(meta, defs)
	_expect(not (duplicate.get("completed_mastery_ids", []) as Array).has("route_a_first_clear"), "mastery should not reward twice")
	_finish()

func _expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
func _finish() -> void:
	if failures.is_empty(): print("CHALLENGE_MASTERY_SERVICE_SELF_CHECK_PASS"); quit(0); return
	for failure in failures: push_error(failure)
	quit(1)
