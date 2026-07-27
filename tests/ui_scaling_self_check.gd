extends SceneTree

const EXPECTED_STRETCH_MODE := "canvas_items"
const EXPECTED_STRETCH_ASPECT := "keep"

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var stretch_mode := String(ProjectSettings.get_setting("display/window/stretch/mode", "disabled"))
	var stretch_aspect := String(ProjectSettings.get_setting("display/window/stretch/aspect", "ignore"))
	if stretch_mode != EXPECTED_STRETCH_MODE:
		_fail("display/window/stretch/mode should be %s, got %s" % [EXPECTED_STRETCH_MODE, stretch_mode])
	if stretch_aspect != EXPECTED_STRETCH_ASPECT:
		_fail("display/window/stretch/aspect should be %s, got %s" % [EXPECTED_STRETCH_ASPECT, stretch_aspect])
	_finish()


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("UI_SCALING_SELF_CHECK_PASS")
		quit(0)
	else:
		for failure in _failures:
			printerr("UI_SCALING_SELF_CHECK_FAIL: %s" % failure)
		quit(1)
