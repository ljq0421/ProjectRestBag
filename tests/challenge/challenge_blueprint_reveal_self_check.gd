extends SceneTree

const MasteryService = preload("res://scripts/challenge/challenge_mastery_service.gd")
var failures: Array[String] = []

func _init() -> void:
	var file := FileAccess.open("res://doc/challenge/challenge_masteries.json", FileAccess.READ)
	var defs: Dictionary = (JSON.parse_string(file.get_as_text()) as Dictionary).get("masteries", {}); file.close()
	var meta := {
		"route_first_clear_ids": ["standard_short_chain", "flavor_texture_route", "grand_composition_route"],
		"completed_mastery_ids": [], "revealed_research_node_ids": [], "endless_records": {"best_floor": 20}
	}
	var result := MasteryService.new().evaluate(meta, defs)
	_expect((result.get("completed_mastery_ids", []) as Array).has("route_triad"), "three-route mastery should complete")
	_expect((result.get("completed_mastery_ids", []) as Array).has("endless_20"), "endless mastery should complete")
	_expect((result.get("revealed_node_ids", []) as Array).size() == 3, "late masteries should reveal three deterministic blueprints")
	_finish()

func _expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
func _finish() -> void:
	if failures.is_empty(): print("CHALLENGE_BLUEPRINT_REVEAL_SELF_CHECK_PASS"); quit(0); return
	for failure in failures: push_error(failure)
	quit(1)
