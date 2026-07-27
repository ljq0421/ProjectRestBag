extends SceneTree

const MAIN_SCENE := preload("res://scenes/Main.tscn")

var _failures: Array[String] = []
var _save_path := OS.get_temp_dir().path_join("workbench_output_overlay_self_check.json")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var view := MAIN_SCENE.instantiate()
	view.set("save_path", _save_path)
	view.set("broken_save_path", _save_path + ".broken")
	root.add_child(view)
	await process_frame
	await process_frame

	var output_button := view.get_node("Root/Body/MainArea/WorkbenchPanel/WorkbenchLauncher/OutputButton") as Button
	output_button.emit_signal("pressed")
	await process_frame

	var base := "GlobalOverlayLayer/OverlayFrame/OverlayModeStack/OutputOverlay/"
	var description := view.get_node_or_null(base + "PageDescription") as RichTextLabel
	var grid := view.get_node_or_null(base + "OutputScroll/OutputGridRow") as GridContainer
	var primary := view.get_node_or_null(base + "OutputActions/OutputPrimaryActionButton") as Button
	var refresh := view.get_node_or_null(base + "OutputActions/OutputRefreshButton") as Button
	_expect_equal("output description exists", description != null, true)
	_expect_equal("output grid exists", grid != null, true)
	_expect_equal("output primary action exists", primary != null, true)
	_expect_equal("output refresh action exists", refresh != null, true)
	if description != null:
		_expect_equal("output description summarizes harvest state", description.text.find("可收") >= 0, true)
	if grid != null:
		_expect_equal("output renders four site regions", grid.get_child_count(), 4)
	if refresh != null:
		_expect_equal("output exposes a refresh action", refresh.text, "刷新")

	view.queue_free()
	_cleanup_save()
	_finish()


func _expect_equal(label: String, actual: Variant, expected: Variant) -> void:
	if actual != expected:
		_fail("%s expected %s, got %s" % [label, expected, actual])


func _cleanup_save() -> void:
	for path in [_save_path, _save_path + ".broken"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("WORKBENCH_OUTPUT_OVERLAY_SELF_CHECK_PASS")
		quit(0)
	else:
		for failure in _failures:
			printerr("WORKBENCH_OUTPUT_OVERLAY_SELF_CHECK_FAIL: %s" % failure)
		quit(1)
