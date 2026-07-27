extends SceneTree

const REGION_SERVICE_PATH := "res://scripts/showcase_region_service.gd"
const GAME_STATE_PATH := "res://scripts/game_state.gd"
const SHOP_SIMULATION_PATH := "res://scripts/shop_simulation.gd"

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var region_script := load(REGION_SERVICE_PATH)
	if region_script == null:
		_fail("ShowcaseRegionService should exist")
		_finish()
		return

	var initial_bounds := {
		"min_row": 5,
		"max_row": 8,
		"min_column": 6,
		"max_column": 9
	}
	var layout: Dictionary = region_script.resolve_regions(initial_bounds)
	_assert_equal(layout.get("unlocked_count", 0), 16, "initial bounds should unlock sixteen cells")
	_assert_equal(layout.get("front_rows", []), [5], "row five should be the front region")
	_assert_equal(layout.get("middle_rows", []), [6, 7], "rows six and seven should be the middle region")
	_assert_equal(layout.get("back_rows", []), [8], "row eight should be the back region")
	_assert_equal(layout.get("golden_rows", []), [6, 7], "golden rows should use the middle forty percent")
	_assert_equal(layout.get("golden_columns", []), [7, 8], "golden columns should use the middle forty percent")

	_assert_equal(region_script.zone_for_cell(Vector2i(5, 6), initial_bounds), "front", "front row should resolve to front")
	_assert_equal(region_script.zone_for_cell(Vector2i(6, 7), initial_bounds), "golden", "middle intersection should resolve to golden")
	_assert_equal(region_script.zone_for_cell(Vector2i(6, 6), initial_bounds), "middle", "middle non-golden cell should remain neutral")
	_assert_equal(region_script.zone_for_cell(Vector2i(8, 9), initial_bounds), "back", "back row should resolve to back")
	_assert_equal(region_script.zone_for_cell(Vector2i(4, 6), initial_bounds), "locked", "outside bounds should resolve to locked")

	var irregular_cells: Array[Vector2i] = []
	for row in range(5, 9):
		for column in range(6, 10): irregular_cells.append(Vector2i(row, column))
	irregular_cells.erase(Vector2i(6, 7))
	irregular_cells.append(Vector2i(4, 6))
	irregular_cells.append(Vector2i(8, 10))
	var irregular: Dictionary = region_script.resolve_regions_for_cells(irregular_cells)
	_assert_equal(irregular.get("unlocked_count", 0), 17, "irregular layout counts actual cells")
	_assert_equal(irregular.get("effective_rows", []), [4, 5, 6, 7, 8], "irregular layout uses occupied rows")
	_assert_equal(irregular.get("effective_columns", []), [6, 7, 8, 9, 10], "irregular layout uses occupied columns")
	_assert_equal(region_script.zone_for_cell_in_cells(Vector2i(6, 7), irregular_cells), "locked", "a hole inside bounds stays locked")
	_assert_equal(region_script.zone_for_cell_in_cells(Vector2i(4, 6), irregular_cells), "front", "front protrusion uses effective row rank")
	_assert_equal(region_script.zone_for_cell_in_cells(Vector2i(8, 10), irregular_cells), "back", "back protrusion stays classified")
	_assert_equal(region_script.zone_for_cells_in_cells([Vector2i(6, 6), Vector2i(6, 7)], irregular_cells), "", "multi-cell placement cannot cross a locked hole")

	_assert_equal(
		region_script.zone_for_cells([Vector2i(6, 7), Vector2i(6, 8)], initial_bounds),
		"golden",
		"a product fully inside golden cells should receive the golden zone"
	)
	_assert_equal(
		region_script.zone_for_cells([Vector2i(5, 7), Vector2i(6, 7)], initial_bounds),
		"",
		"a product crossing functional regions should receive no zone"
	)
	_assert_equal(
		region_script.zone_for_cells([Vector2i(6, 6), Vector2i(7, 6)], initial_bounds),
		"middle",
		"a product fully inside neutral middle cells should be classified consistently"
	)

	for bounds in [
		{"min_row": 4, "max_row": 6, "min_column": 5, "max_column": 7},
		{"min_row": 3, "max_row": 7, "min_column": 4, "max_column": 10},
		{"min_row": 2, "max_row": 9, "min_column": 3, "max_column": 12}
	]:
		var expanded: Dictionary = region_script.resolve_regions(bounds)
		if (expanded.get("front_rows", []) as Array).is_empty():
			_fail("front region should contain at least one row for %s" % [bounds])
		if (expanded.get("middle_rows", []) as Array).is_empty():
			_fail("middle region should contain at least one row for %s" % [bounds])
		if (expanded.get("back_rows", []) as Array).is_empty():
			_fail("back region should contain at least one row for %s" % [bounds])
		if (expanded.get("golden_rows", []) as Array).is_empty():
			_fail("golden region should contain at least one row for %s" % [bounds])
		if (expanded.get("golden_columns", []) as Array).is_empty():
			_fail("golden region should contain at least one column for %s" % [bounds])

	var game_state_script := load(GAME_STATE_PATH)
	var state = game_state_script.new_game()
	_assert_equal(
		state.get_showcase_unlocked_bounds(),
		initial_bounds,
		"new games should persist the initial four by four unlocked rectangle"
	)
	var unlocked_count := 0
	for row in range(1, 13):
		for column in range(1, 15):
			if state.is_showcase_cell_unlocked(Vector2i(row, column)):
				unlocked_count += 1
	_assert_equal(unlocked_count, 16, "GameState should unlock exactly sixteen showcase cells")
	if not state.is_showcase_cell_unlocked(Vector2i(5, 6)) or not state.is_showcase_cell_unlocked(Vector2i(8, 9)):
		_fail("GameState should unlock both corners of the initial rectangle")
	if state.is_showcase_cell_unlocked(Vector2i(4, 6)) or state.is_showcase_cell_unlocked(Vector2i(5, 5)):
		_fail("GameState should keep cells immediately outside the initial rectangle locked")
	state.add_recipe("butter_cookie")
	if state.place_display_item("butter_cookie", [Vector2i(5, 5)]):
		_fail("normal product placement should reject a locked showcase cell")
	if state.place_display_prop("cake_stand", [Vector2i(5, 5)]):
		_fail("display prop placement should reject a locked showcase cell")

	var saved: Dictionary = state.to_dict()
	_assert_equal(saved.get("showcase_unlocked_bounds", {}), initial_bounds, "save data should include unlocked bounds")
	# Simulate a legacy save that predates the cell-set field. New saves prefer
	# showcase_unlocked_cells because irregular shapes cannot be represented by bounds.
	saved.erase("showcase_unlocked_cells")
	var expanded_bounds := {"min_row": 4, "max_row": 9, "min_column": 5, "max_column": 10}
	saved["showcase_unlocked_bounds"] = expanded_bounds
	var loaded_state = game_state_script.from_dict(saved)
	_assert_equal(loaded_state.get_showcase_unlocked_bounds(), expanded_bounds, "loaded games should restore unlocked bounds")

	saved["showcase_unlocked_bounds"] = {"min_row": 99, "max_row": -2, "min_column": 88, "max_column": -4}
	var sanitized_state = game_state_script.from_dict(saved)
	_assert_equal(
		sanitized_state.get_showcase_unlocked_bounds(),
		{"min_row": 1, "max_row": 12, "min_column": 1, "max_column": 14},
		"loaded bounds should be clamped and ordered inside the board"
	)

	var shop_simulation := load(SHOP_SIMULATION_PATH)
	var zone_rules := {
		"zone_001": {"region_id": "front", "zone_name": "引流前排位", "price_bonus_pct": -3, "speed_bonus_pct": 8},
		"zone_002": {"region_id": "golden", "zone_name": "黄金C位区", "price_bonus_pct": 5, "speed_bonus_pct": 0, "adjacency_multiplier": 1.2},
		"zone_003": {"region_id": "back", "zone_name": "宝藏深处位", "price_bonus_pct": 8, "speed_bonus_pct": -4}
	}
	var front_bonus: Dictionary = shop_simulation._calc_zone_bonus([Vector2i(5, 6)], zone_rules, initial_bounds)
	_assert_equal(front_bonus.get("region_id", ""), "front", "front bonus should expose its stable region id")
	_assert_equal(front_bonus.get("price_pct", 0), -3, "front region should reduce price by three percent")
	_assert_equal(front_bonus.get("speed_pct", 0), 8, "front region should increase speed by eight percent")
	var golden_bonus: Dictionary = shop_simulation._calc_zone_bonus([Vector2i(6, 7), Vector2i(6, 8)], zone_rules, initial_bounds)
	_assert_equal(golden_bonus.get("region_id", ""), "golden", "golden bonus should expose its stable region id")
	_assert_equal(golden_bonus.get("price_pct", 0), 5, "golden region should increase price by five percent")
	if not shop_simulation._is_in_golden_zone([Vector2i(6, 7), Vector2i(7, 8)], zone_rules, initial_bounds):
		_fail("golden-zone multiplier should use the dynamic region service")
	var back_bonus: Dictionary = shop_simulation._calc_zone_bonus([Vector2i(8, 6)], zone_rules, initial_bounds)
	_assert_equal(back_bonus.get("region_id", ""), "back", "back bonus should expose its stable region id")
	_assert_equal(back_bonus.get("price_pct", 0), 8, "back region should increase price by eight percent")
	_assert_equal(back_bonus.get("speed_pct", 0), -4, "back region should reduce speed by four percent")
	var cross_bonus: Dictionary = shop_simulation._calc_zone_bonus([Vector2i(5, 7), Vector2i(6, 7)], zone_rules, initial_bounds)
	_assert_equal(cross_bonus.get("price_pct", 0.0), 0.0, "cross-region products should not receive a fixed zone effect")
	_assert_equal(cross_bonus.get("region_id", "missing"), "", "cross-region products should expose an empty region id")
	if "跨区" not in "\n".join(cross_bonus.get("reasons", [])):
		_fail("cross-region bonus reason should explicitly explain the risk")

	_finish()


func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_fail("%s; expected=%s actual=%s" % [message, expected, actual])


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("SHOWCASE_REGION_SERVICE_SELF_CHECK_PASS")
		quit(0)
		return
	for failure in _failures:
		printerr("SHOWCASE_REGION_SERVICE_SELF_CHECK_FAIL: %s" % failure)
	quit(1)
