extends SceneTree

const GameState = preload("res://scripts/game_state.gd")

var failures: Array[String] = []

func _init() -> void:
	var state: GameState = GameState.new_game()
	_expect_equal(state.get_showcase_unlocked_cells().size(), 16, "new game cell count")
	_expect(state.is_showcase_cell_unlocked(Vector2i(5, 6)), "initial cell should be unlocked")
	_expect(not state.is_showcase_cell_unlocked(Vector2i(4, 6)), "outer cell should be locked")

	state.set_showcase_unlocked_cells([Vector2i(5, 6), Vector2i(4, 6), Vector2i(4, 6), Vector2i(0, 6), Vector2i(13, 6)])
	_expect_equal(state.get_showcase_unlocked_cells(), [Vector2i(4, 6), Vector2i(5, 6)], "cells should sort, deduplicate and clip")
	_expect_equal(state.get_showcase_unlocked_bounds(), {"min_row": 4, "max_row": 5, "min_column": 6, "max_column": 6}, "bounds should be derived from cells")

	var restored: GameState = GameState.from_dict(state.to_dict())
	_expect_equal(restored.get_showcase_unlocked_cells(), state.get_showcase_unlocked_cells(), "cell set should save and restore")

	var legacy: GameState = GameState.from_dict({"showcase_unlocked_bounds": {"min_row": 4, "max_row": 5, "min_column": 7, "max_column": 9}})
	_expect_equal(legacy.get_showcase_unlocked_cells().size(), 6, "legacy bounds should expand to cells")
	_expect(legacy.is_showcase_cell_unlocked(Vector2i(5, 9)), "legacy rectangle edge should restore")
	_expect(not legacy.is_showcase_cell_unlocked(Vector2i(5, 10)), "outside legacy rectangle should stay locked")

	if failures.is_empty():
		print("SHOWCASE_UNLOCKED_CELLS_STATE_SELF_CHECK_PASS")
		quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)

func _expect(value: bool, message: String) -> void:
	if not value: failures.append(message)

func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected: failures.append("%s expected=%s actual=%s" % [message, expected, actual])
