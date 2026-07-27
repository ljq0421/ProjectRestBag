extends SceneTree

const MAIN_VIEW_PATH := "res://scripts/main_view.gd"

var failures: Array[String] = []


func _init() -> void:
	var source := FileAccess.get_file_as_string(MAIN_VIEW_PATH)
	var process_block := _function_block(source, "_process")
	var workbench_block := _function_block(source, "_refresh_production_workbench")
	var render_block := _function_block(source, "_render_unified_production_queue")
	var search_block := _function_block(source, "_on_production_queue_search_changed")
	var tick_block := _function_block(source, "_refresh_production_queue_tick")
	var runtime_block := _function_block(source, "_production_queue_runtime_entries")

	_expect(
		process_block.find("_refresh_production_queue_tick(") >= 0,
		"one-second process must use the lightweight queue tick"
	)
	_expect(
		process_block.find("_refresh_production_workbench(") < 0,
		"one-second process must not rebuild production picker data"
	)
	_expect_equal(
		"event refresh builds one unified snapshot",
		workbench_block.count("_build_unified_production_queue_snapshot("),
		1
	)
	_expect(
		search_block.find("_build_unified_production_queue_snapshot(") < 0,
		"search must reuse the current structural snapshot"
	)
	_expect(
		render_block.find("\"completed_entries\"") >= 0 and render_block.find("\"queue_entries\"") >= 0,
		"renderer must pass completed and right-queue ownership separately"
	)
	_expect(
		tick_block.find("_build_unified_production_queue_snapshot(") < 0,
		"one-second runtime refresh must not rebuild structural data"
	)
	_expect_equal(
		"runtime tick computes active count once",
		tick_block.count("_production_active_batch_count("),
		1
	)
	_expect(
		tick_block.find("production_zone_shell.call(\"set_activity_state\"") >= 0,
		"runtime tick must reuse the active count for production-zone visual state"
	)
	_expect_equal(
		"structural render computes active count once",
		render_block.count("_production_active_batch_count("),
		1
	)
	_expect(
		render_block.find("production_zone_shell.call(\"set_activity_state\"") >= 0,
		"structural render must reuse the active count for production-zone visual state"
	)
	_expect(
		runtime_block.find("production_queue_snapshot.get(\"queue_entries\"") >= 0,
		"one-second runtime refresh must inspect only right-side queue entries"
	)
	_finish()


func _function_block(source: String, function_name: String) -> String:
	var start := source.find("func %s(" % function_name)
	if start < 0:
		return ""
	var next_function := source.find("\nfunc ", start + 1)
	return source.substr(start) if next_function < 0 else source.substr(start, next_function - start)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _expect_equal(label: String, actual: Variant, expected: Variant) -> void:
	if actual != expected:
		failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])


func _finish() -> void:
	if failures.is_empty():
		print("PRODUCTION_QUEUE_PERFORMANCE_SELF_CHECK_PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
