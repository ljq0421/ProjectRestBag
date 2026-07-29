extends SceneTree

const RouteService = preload("res://scripts/challenge/challenge_route_service.gd")
var failures: Array[String] = []

func _init() -> void:
	var file := FileAccess.open("res://doc/challenge/standard_run.json", FileAccess.READ)
	var routes: Dictionary = (JSON.parse_string(file.get_as_text()) as Dictionary).get("routes", {})
	file.close()
	var service = RouteService.new()
	var meta := service.bootstrap_meta({}, routes)
	meta = service.record_first_clear(meta, "standard_short_chain", routes).get("meta", {})
	_expect(bool(service.route_state(meta, "flavor_texture_route", routes).get("unlocked", false)), "route B should unlock after A")
	_expect(not bool(service.route_state(meta, "grand_composition_route", routes).get("unlocked", true)), "route C should remain locked")
	meta = service.record_first_clear(meta, "flavor_texture_route", routes).get("meta", {})
	_expect(bool(service.route_state(meta, "grand_composition_route", routes).get("unlocked", false)), "route C should unlock after B")
	_finish()

func _expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
func _finish() -> void:
	if failures.is_empty(): print("CHALLENGE_ROUTE_UNLOCK_SELF_CHECK_PASS"); quit(0); return
	for failure in failures: push_error(failure)
	quit(1)
