extends SceneTree

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const GAME_STATE := preload("res://scripts/game_state.gd")
const SAVE_SYSTEM := preload("res://scripts/save_system.gd")

const RECIPE_ID := "rice_milk_drink"
const GRID_COLUMNS := 14

var _failures: Array[String] = []
var _case_index := 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	await _expect_first_drag_from_covered_cell(
		"horizontal",
		[Vector2i(8, 8), Vector2i(8, 9)],
		Vector2i(8, 9),
		Vector2i(9, 9),
		[Vector2i(9, 8), Vector2i(9, 9)]
	)
	await _expect_first_right_click_from_covered_cell(
		"horizontal",
		[Vector2i(8, 8), Vector2i(8, 9)],
		Vector2i(8, 9),
		[Vector2i(8, 8), Vector2i(9, 8)]
	)
	await _expect_first_drag_from_covered_cell(
		"vertical",
		[Vector2i(8, 8), Vector2i(9, 8)],
		Vector2i(9, 8),
		Vector2i(8, 9),
		[Vector2i(7, 9), Vector2i(8, 9)]
	)
	await _expect_first_right_click_from_covered_cell(
		"vertical",
		[Vector2i(8, 8), Vector2i(9, 8)],
		Vector2i(9, 8),
		[Vector2i(8, 8), Vector2i(8, 9)]
	)

	if _failures.is_empty():
		print("SHOWCASE_INITIAL_MULTICELL_INTERACTION_SELF_CHECK_PASS")
		quit(0)
	else:
		for failure in _failures:
			printerr("SHOWCASE_INITIAL_MULTICELL_INTERACTION_SELF_CHECK_FAIL: %s" % failure)
		quit(1)


func _expect_first_drag_from_covered_cell(
	orientation: String,
	cells: Array[Vector2i],
	covered_cell: Vector2i,
	target_cell: Vector2i,
	expected_cells: Array[Vector2i]
) -> void:
	var fixture := await _load_fixture(cells)
	var view: Control = fixture["view"]
	var state = view.get("state")
	var grid: GridContainer = fixture["grid"]
	var covered_button := grid.get_child(_slot_index(covered_cell)) as Button
	var target_button := grid.get_child(_slot_index(target_cell)) as Button
	var drag_data: Variant = covered_button.get("drag_data")
	_expect(
		drag_data is Dictionary and String((drag_data as Dictionary).get("recipe_id", "")) == RECIPE_ID,
		"%s rice milk drink covered cell should be a drag source on its first interaction" % orientation
	)
	await _drag_mouse(covered_button.get_global_rect().get_center(), target_button.get_global_rect().get_center())
	_expect_same_cells(
		state.get_display_item_cells(RECIPE_ID),
		expected_cells,
		"%s rice milk drink should move when its covered cell is the first drag source" % orientation
	)
	await _free_fixture(fixture)


func _expect_first_right_click_from_covered_cell(
	orientation: String,
	cells: Array[Vector2i],
	covered_cell: Vector2i,
	expected_cells: Array[Vector2i]
) -> void:
	var fixture := await _load_fixture(cells)
	var view: Control = fixture["view"]
	var state = view.get("state")
	var grid: GridContainer = fixture["grid"]
	var covered_button := grid.get_child(_slot_index(covered_cell)) as Button
	await _right_click(covered_button.get_global_rect().get_center())
	_expect_same_cells(
		state.get_display_item_cells(RECIPE_ID),
		expected_cells,
		"%s rice milk drink should rotate when its covered cell receives the first right click" % orientation
	)
	await _free_fixture(fixture)


func _load_fixture(cells: Array[Vector2i]) -> Dictionary:
	_case_index += 1
	var save_path := OS.get_temp_dir().path_join("showcase_initial_multicell_interaction_%d.json" % _case_index)
	_cleanup_save(save_path)
	var state = GAME_STATE.new_game()
	state.level = 99
	state.shop_level = 99
	state.add_recipe(RECIPE_ID)
	state.add_product(RECIPE_ID, 2)
	_expect(state.list_display_item(RECIPE_ID, cells, 1, "standard", 20), "fixture should list rice milk drink")
	var anchor_index := _slot_index(cells[0])
	state.display_slots[anchor_index] = {"recipe_id": RECIPE_ID, "quantity": 1}
	for cell in cells:
		var cell_index := _slot_index(cell)
		if cell_index != anchor_index:
			state.display_slots[cell_index] = {"covered_by": anchor_index}
	_expect(SAVE_SYSTEM.save_game(state, save_path, 1000), "fixture should save rice milk drink layout")

	var view := MAIN_SCENE.instantiate()
	view.set("save_path", save_path)
	view.set("broken_save_path", save_path + ".broken")
	root.add_child(view)
	await process_frame
	await process_frame
	return {
		"view": view,
		"grid": view.get_node("Root/Body/MainArea/StorefrontPanel/ShowcasePanel/ShowcaseGrid"),
		"save_path": save_path,
	}


func _free_fixture(fixture: Dictionary) -> void:
	var view: Node = fixture["view"]
	var save_path := String(fixture["save_path"])
	view.queue_free()
	await process_frame
	_cleanup_save(save_path)


func _drag_mouse(from: Vector2, to: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = from
	press.global_position = from
	Input.parse_input_event(press)
	await process_frame

	var start_motion := InputEventMouseMotion.new()
	start_motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	start_motion.position = from + Vector2(24, 0)
	start_motion.global_position = start_motion.position
	start_motion.relative = Vector2(24, 0)
	Input.parse_input_event(start_motion)
	await process_frame

	var drag_motion := InputEventMouseMotion.new()
	drag_motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	drag_motion.position = to
	drag_motion.global_position = to
	drag_motion.relative = to - start_motion.position
	Input.parse_input_event(drag_motion)
	await process_frame

	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = to
	release.global_position = to
	Input.parse_input_event(release)
	await process_frame
	await process_frame


func _right_click(position: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_RIGHT
	press.pressed = true
	press.position = position
	press.global_position = position
	Input.parse_input_event(press)
	await process_frame
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_RIGHT
	release.pressed = false
	release.position = position
	release.global_position = position
	Input.parse_input_event(release)
	await process_frame
	await process_frame


func _expect_same_cells(actual: Array, expected: Array[Vector2i], message: String) -> void:
	var actual_keys := {}
	for cell_value in actual:
		if cell_value is Vector2i:
			actual_keys["%d:%d" % [cell_value.x, cell_value.y]] = true
	var expected_keys := {}
	for cell in expected:
		expected_keys["%d:%d" % [cell.x, cell.y]] = true
	_expect(actual_keys == expected_keys, "%s; expected=%s actual=%s" % [message, expected, actual])


func _slot_index(cell: Vector2i) -> int:
	return (cell.x - 1) * GRID_COLUMNS + cell.y - 1


func _cleanup_save(path: String) -> void:
	for suffix in ["", ".tmp", ".previous", ".broken", ".broken.json"]:
		var candidate: String = path + String(suffix)
		if FileAccess.file_exists(candidate):
			DirAccess.remove_absolute(candidate)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)
