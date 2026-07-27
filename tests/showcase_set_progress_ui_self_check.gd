extends SceneTree

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const GAME_STATE := preload("res://scripts/game_state.gd")

var _failures: Array[String] = []
var _save_path := OS.get_temp_dir().path_join("showcase_set_progress_ui_self_check.json")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var view = MAIN_SCENE.instantiate()
	view.set("save_path", _save_path)
	view.set("broken_save_path", _save_path + ".broken")
	root.add_child(view)
	await process_frame

	var board := view.get_node("Root/Body/MainArea/StorefrontPanel/ShowcasePanel")
	var label := board.get_node_or_null("SetProgressLabel") as Label
	if label == null:
		_fail("showcase board should declare SetProgressLabel")
		_finish()
		return
	var round_bar := board.get_node("RoundControlBar") as Control
	_assert_equal(label.get_index(), round_bar.get_index() + 1, "set progress should sit directly below the round control bar")
	_assert_equal(label.horizontal_alignment, HORIZONTAL_ALIGNMENT_LEFT, "set progress should align to the left")
	_assert_equal(label.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART, "set progress should support multiline wrapping")
	_assert_equal(label.max_lines_visible, 2, "set progress should reserve at most two visible lines")
	_assert_equal(label.text_overrun_behavior, TextServer.OVERRUN_TRIM_ELLIPSIS, "overflowing set progress should end with an ellipsis")
	_assert_equal(label.mouse_filter, Control.MOUSE_FILTER_PASS, "set progress should accept hover events for its full-text tooltip")

	var empty_state = GAME_STATE.new_game()
	view.set("state", empty_state)
	view.call("_refresh_storefront_showcase")
	_assert_equal(label.visible, false, "set progress should hide when no listed product contributes to a set")

	var candidate_state = GAME_STATE.new_game()
	candidate_state.display_items = {
		"black_tea_latte": {"cells": [Vector2i(5, 5)], "stock": 1}
	}
	view.set("state", candidate_state)
	view.call("_refresh_storefront_showcase")
	_assert_equal(label.visible, true, "set progress should show when the display has set candidates")
	_assert_contains(label.text, "套装「经典下午茶三件套」还差", "candidate copy should name the afternoon tea set")
	_assert_contains(label.text, "套装「全茶风味套装」还差", "all candidates should render on the label")
	_assert_equal(label.text.split("\n").size() >= 3, true, "three or more candidates should render on separate lines")
	_assert_equal(label.tooltip_text, label.text, "the tooltip should preserve every set progress line")
	await process_frame
	await process_frame
	var root_layout := view.get_node("Root") as Control
	var pulse_summary := board.get_node("ShowcasePulseSummary") as Control
	var grid := board.get_node("ShowcaseGrid") as Control
	_assert_equal(round_bar.get_global_rect().end.y <= label.get_global_rect().position.y + 0.5, true, "round controls should not overlap the set progress")
	_assert_equal(label.get_global_rect().end.y <= pulse_summary.get_global_rect().position.y + 0.5, true, "set progress should not overlap the pulse summary")
	_assert_equal(pulse_summary.get_global_rect().end.y <= grid.get_global_rect().position.y + 0.5, true, "pulse summary should not overlap the showcase grid")
	_assert_equal(grid.get_global_rect().end.y <= float(root.size.y) + 0.5, true, "multiline set progress should keep the full showcase grid inside a 1080p viewport")
	_assert_equal(root_layout.get_global_rect().position.y >= -0.5, true, "multiline set progress should not push the page above the 1080p viewport")
	_assert_equal(root_layout.get_global_rect().end.y <= float(root.size.y) + 0.5, true, "multiline set progress should not push the status bar below the 1080p viewport")

	candidate_state.display_items = {
		"black_tea_latte": {"cells": [Vector2i(5, 5)], "stock": 1},
		"matcha_pudding": {"cells": [Vector2i(5, 6)], "stock": 1}
	}
	view.call("_refresh_storefront_showcase")
	_assert_contains(label.text, "套装「全茶风味套装」生效", "connected complete set should render active copy")

	_finish()


func _assert_contains(actual: String, expected: String, message: String) -> void:
	if actual.find(expected) == -1:
		_fail("%s; expected text=%s actual=%s" % [message, expected, actual])


func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_fail("%s; expected=%s actual=%s" % [message, expected, actual])


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("SHOWCASE_SET_PROGRESS_UI_SELF_CHECK_PASS")
		quit(0)
		return
	for failure in _failures:
		printerr("SHOWCASE_SET_PROGRESS_UI_SELF_CHECK_FAIL: %s" % failure)
	quit(1)
