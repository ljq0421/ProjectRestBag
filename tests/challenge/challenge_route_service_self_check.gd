extends SceneTree

const RouteService = preload("res://scripts/challenge/challenge_route_service.gd")

var failures: Array[String] = []

func _init() -> void:
	var routes: Dictionary = _load("res://doc/challenge/standard_run.json").get("routes", {})
	var service = RouteService.new()
	var meta := service.bootstrap_meta({}, routes)
	_expect((meta.get("unlocked_route_ids", []) as Array) == ["standard_short_chain"], "only route A should start unlocked")
	var states := service.all_states(meta, routes)
	_expect(states.size() == 3, "route service should expose three routes")
	_expect(not bool(states[1].get("unlocked", true)), "route B should start locked")
	var cleared := service.record_first_clear(meta, "standard_short_chain", routes)
	_expect(bool(cleared.get("applied", false)), "route A first clear should apply once")
	meta = cleared.get("meta", {})
	_expect((meta.get("unlocked_route_ids", []) as Array).has("flavor_texture_route"), "route A clear should unlock route B")
	var duplicate := service.record_first_clear(meta, "standard_short_chain", routes)
	_expect(not bool(duplicate.get("applied", true)), "route first clear should be idempotent")
	_finish("CHALLENGE_ROUTE_SERVICE_SELF_CHECK_PASS")

func _load(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	var value: Variant = JSON.parse_string(file.get_as_text()) if file else {}
	if file: file.close()
	return value if value is Dictionary else {}

func _expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _finish(marker: String) -> void:
	if failures.is_empty(): print(marker); quit(0); return
	for failure in failures: push_error(failure)
	quit(1)
