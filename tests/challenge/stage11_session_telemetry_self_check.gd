extends SceneTree

const FixtureService = preload(
	"res://scripts/challenge/stage11_playtest_fixture_service.gd"
)
const SessionService = preload("res://scripts/challenge/challenge_session_service.gd")
const TelemetryService = preload(
	"res://scripts/challenge/stage11_playtest_telemetry_service.gd"
)

const SAVE_PATH := "res://tmp/stage11_session_telemetry_self_check.json"


func _initialize() -> void:
	var directory_error := DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("res://tmp")
	)
	_assert(directory_error == OK, "temporary directory should be writable")
	_cleanup()
	var fixture := FixtureService.new().build_fixture("P03")
	var session := SessionService.new()
	session.save_path = SAVE_PATH
	var menu_result := session.set_active_menu(
		fixture,
		(fixture.get("meta", {}) as Dictionary).get("active_menu_recipe_ids", [])
	)
	_assert(bool(menu_result.get("applied", false)), "fixture menu should save")
	var after_menu: Dictionary = menu_result.get("save_data", {})
	var run_result := session.create_standard_run(
		after_menu,
		"standard_short_chain",
		110031
	)
	_assert(bool(run_result.get("applied", false)), "fixture should start route A")
	var after_run: Dictionary = run_result.get("save_data", {})
	var state := TelemetryService.new().state(after_run.get("meta", {}))
	var event_types: Array[String] = []
	for value in state.get("events", []):
		if value is Dictionary:
			event_types.append(String(value.get("type", "")))
	_assert(event_types.has("menu_saved"), "session should record menu_saved")
	_assert(event_types.has("run_started"), "session should record run_started")
	_assert(
		int(state.get("event_sequence", 0)) == (state.get("events", []) as Array).size(),
		"event sequence should match event count"
	)
	_cleanup()
	print("STAGE11_SESSION_TELEMETRY_SELF_CHECK_PASS events=%d" % event_types.size())
	quit(0)


func _cleanup() -> void:
	for path in [SAVE_PATH, SAVE_PATH + ".tmp", SAVE_PATH + ".previous"]:
		var absolute := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(path):
			var error := DirAccess.remove_absolute(absolute)
			_assert(error == OK, "temporary save should be removable: %s" % path)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	_cleanup()
	quit(1)
