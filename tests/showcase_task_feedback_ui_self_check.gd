extends SceneTree

var _failures: Array[String] = []


func _init() -> void:
	var board := FileAccess.get_file_as_string("res://scenes/ui/storefront/showcase_board.tscn")
	var dialog := FileAccess.get_file_as_string("res://scenes/ui/overlays/showcase_round_settlement_dialog.tscn")
	var main_script := FileAccess.get_file_as_string("res://scripts/main_view.gd")
	_expect(board.contains("TaskProgressPanel"), "Showcase board should declare a stable task progress panel")
	_expect(board.contains("mouse_filter = 2"), "Task progress feedback should not block showcase input")
	_expect(dialog.contains("RatingSummaryLabel"), "Settlement dialog should declare a rating summary")
	_expect(main_script.contains("conditions.slice(0, 3)"), "Live contract feedback should show at most three metrics")
	_expect(main_script.contains("_showcase_report_value"), "Live feedback should read the same report field paths")
	var dialog_script = load("res://scripts/ui/overlays/showcase_round_settlement_dialog.gd")
	_expect(_script_declares_method(dialog_script, "show_rating_result"), "Settlement dialog should expose final rating presentation")
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _script_declares_method(script: Script, method_name: String) -> bool:
	for method_value in script.get_script_method_list():
		if method_value is Dictionary and String((method_value as Dictionary).get("name", "")) == method_name:
			return true
	return false


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("SHOWCASE_TASK_FEEDBACK_UI_SELF_CHECK_PASS")
		quit(0)
	else:
		for failure in _failures:
			printerr("SHOWCASE_TASK_FEEDBACK_UI_SELF_CHECK_FAIL: %s" % failure)
		quit(1)
