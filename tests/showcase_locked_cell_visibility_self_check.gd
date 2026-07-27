extends SceneTree

const MainScene := preload("res://scenes/Main.tscn")
const GameState := preload("res://scripts/game_state.gd")

var failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var main = MainScene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var state = GameState.new_game()
	state.level = 2
	state.shop_level = 2
	state.coins = 1000
	main.set("state", state)
	main.call("_show_page", "storefront_manage")
	await process_frame

	var grid: GridContainer = main.get_node("Root/Body/MainArea/StorefrontPanel/ShowcasePanel/ShowcaseGrid")
	_expect(grid.get_child_count() == 168, "showcase should retain all coordinate nodes")
	var locked_button := grid.get_child(0) as Button
	_expect(is_zero_approx(locked_button.modulate.a), "locked cell should be visually hidden outside expansion mode")
	_expect(locked_button.mouse_filter == Control.MOUSE_FILTER_IGNORE, "hidden locked cell should ignore pointer input")
	_expect(locked_button.focus_mode == Control.FOCUS_NONE, "hidden locked cell should ignore keyboard focus")
	var unlocked_button := grid.get_child(76) as Button
	_expect(unlocked_button.modulate.a > 0.99, "unlocked cell should remain visible")
	_expect(unlocked_button.mouse_filter == Control.MOUSE_FILTER_STOP, "unlocked cell should remain interactive")

	main.call("_enter_showcase_expansion_mode")
	await process_frame
	var frontier_button := grid.get_child(47) as Button
	_expect(frontier_button.modulate.a > 0.99, "adjacent expansion candidate should become visible")
	_expect(frontier_button.mouse_filter == Control.MOUSE_FILTER_STOP, "adjacent expansion candidate should be interactive")
	var chained_button := grid.get_child(33) as Button
	_expect(is_zero_approx(chained_button.modulate.a), "second-ring cell should stay hidden before a connected cell is selected")
	locked_button = grid.get_child(0) as Button
	_expect(is_zero_approx(locked_button.modulate.a), "non-candidate locked cell should stay hidden in expansion mode")
	_expect(locked_button.mouse_filter == Control.MOUSE_FILTER_IGNORE, "non-candidate locked cell should stay non-interactive")
	_expect(locked_button.focus_mode == Control.FOCUS_NONE, "non-candidate locked cell should stay out of keyboard focus")

	main.call("_select_showcase_expansion_from_slot", 47)
	frontier_button = grid.get_child(47) as Button
	var selected: Array = main.get("showcase_expansion_selected_cells")
	_expect(selected == [Vector2i(4, 6)], "cell tool should record the selected expansion cell")
	_expect(frontier_button.modulate.a > 0.99, "selected expansion cell should remain visible")
	_expect(frontier_button.text.begins_with("已选"), "selected expansion cell should expose selected feedback")
	chained_button = grid.get_child(33) as Button
	_expect(chained_button.modulate.a > 0.99, "cell tool should reveal the next connected expansion candidate")

	main.call("_select_showcase_expansion_from_slot", 47)
	selected = main.get("showcase_expansion_selected_cells")
	_expect(selected.is_empty(), "clicking a selected expansion cell should cancel it")
	chained_button = grid.get_child(33) as Button
	_expect(is_zero_approx(chained_button.modulate.a), "cancelling should hide the no-longer-connected candidate")

	main.call("_set_showcase_expansion_tool", "row")
	main.call("_select_showcase_expansion_from_slot", 47)
	selected = main.get("showcase_expansion_selected_cells")
	_expect(selected.size() > 1, "row tool should select the unlocked-frontier cells in that row")
	_expect(_selected_cells_are_visible(grid, selected), "row tool selected cells should all stay visible and selected")

	main.call("_set_showcase_expansion_tool", "column")
	main.call("_select_showcase_expansion_from_slot", 47)
	selected = main.get("showcase_expansion_selected_cells")
	_expect(selected.size() > 1, "column tool should select the unlocked-frontier cells in that column")
	_expect(_selected_cells_are_visible(grid, selected), "column tool selected cells should all stay visible and selected")

	main.queue_free()
	_finish()


func _selected_cells_are_visible(grid: GridContainer, cells: Array) -> bool:
	for cell_value in cells:
		if not cell_value is Vector2i:
			return false
		var cell := cell_value as Vector2i
		var slot_index := (cell.x - 1) * 14 + cell.y - 1
		var button := grid.get_child(slot_index) as Button
		if button.modulate.a < 0.99 or button.mouse_filter != Control.MOUSE_FILTER_STOP or not button.text.begins_with("已选"):
			return false
	return true


func _expect(value: bool, message: String) -> void:
	if not value:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("SHOWCASE_LOCKED_CELL_VISIBILITY_SELF_CHECK_PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
