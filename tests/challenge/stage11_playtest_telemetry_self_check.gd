extends SceneTree

const TelemetryService = preload(
	"res://scripts/challenge/stage11_playtest_telemetry_service.gd"
)

var _failures: Array[String] = []


func _init() -> void:
	var service = TelemetryService.new()
	var untouched := service.record({"research_points": 0}, "menu_saved")
	_expect(not untouched.has("stage11_playtest"), "normal saves must not collect stage 11 events")
	var meta := service.begin({}, "P03", "mid")
	meta = service.record(meta, "route_started", {"route_id": "flavor_texture_route"})
	meta = service.record(meta, "menu_saved", {"recipe_ids": ["a", "b", "c", "d"]})
	var state := service.state(meta)
	_expect(int(state.get("event_sequence", 0)) == 2, "two events should receive two sequences")
	_expect((state.get("events", []) as Array).size() == 2, "two events should be retained")
	_expect(service.validate(state).is_empty(), "active telemetry state should validate")
	meta = service.complete(meta)
	state = service.state(meta)
	_expect(String(state.get("status", "")) == "completed", "completion should close the session")
	var after_complete := service.record(meta, "ignored")
	_expect(
		(service.state(after_complete).get("events", []) as Array).size() == 3,
		"events after completion must be ignored"
	)
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition and not _failures.has(message):
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("STAGE11_PLAYTEST_TELEMETRY_SELF_CHECK_PASS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
