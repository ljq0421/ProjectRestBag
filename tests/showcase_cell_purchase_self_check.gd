extends SceneTree

const GAME_STATE_PATH := "res://scripts/game_state.gd"

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var game_state_script := load(GAME_STATE_PATH)
	var state = game_state_script.new_game()
	state.coins = 10000

	var adjacent := Vector2i(4, 6)
	var locked_quote: Dictionary = state.quote_showcase_cell_purchase([adjacent])
	_assert_equal(locked_quote.get("reason", ""), "level_required", "Lv.0 should not be allowed to expand")

	state.level = 2
	state.active_business_round = {"phase": "adjusting", "hotspot": {"id": "stale_hotspot", "cells": [Vector2i(5, 6)]}}
	var first_quote: Dictionary = state.quote_showcase_cell_purchase([adjacent])
	_assert_equal(first_quote.get("ok", false), true, "Lv.2 should be allowed to buy an adjacent cell")
	_assert_equal(first_quote.get("total_cost", 0), 300, "the first outer cell should cost 300 coins")
	_assert_equal(first_quote.get("max_unlocked_cells", 0), 36, "Lv.2 should cap the showcase at 36 cells")
	var first_result: Dictionary = state.purchase_showcase_cells([adjacent])
	_assert_equal(first_result.get("ok", false), true, "an affordable adjacent purchase should succeed")
	_assert_equal(state.coins, 9700, "successful purchase should deduct exactly the quote")
	_assert_equal(state.get_showcase_unlocked_cells().size(), 17, "successful purchase should unlock one cell")
	_assert_equal(state.active_business_round.get("hotspot", {}), {}, "successful expansion should invalidate the cached hotspot")
	var reloaded = game_state_script.from_dict(state.to_dict())
	_assert_equal(reloaded.is_showcase_cell_unlocked(adjacent), true, "purchased irregular cells should survive save and reload")
	_assert_equal(reloaded.get_showcase_unlocked_cells().size(), 17, "reload should preserve the exact unlocked cell count")

	var chained := [Vector2i(3, 6), Vector2i(2, 6)]
	var chained_quote: Dictionary = state.quote_showcase_cell_purchase(chained)
	_assert_equal(chained_quote.get("ok", false), true, "a connected batch may extend multiple layers")
	_assert_equal(chained_quote.get("first_price", 0), 310, "the next cell price should increase by 10")
	_assert_equal(chained_quote.get("last_price", 0), 320, "each cell in the batch should keep increasing")
	_assert_equal(chained_quote.get("total_cost", 0), 630, "two chained cells after the first purchase should cost 630")

	var isolated_quote: Dictionary = state.quote_showcase_cell_purchase([Vector2i(1, 1)])
	_assert_equal(isolated_quote.get("reason", ""), "disconnected", "an isolated cell should be rejected")

	var cap_state = game_state_script.new_game()
	cap_state.level = 2
	cap_state.coins = 100000
	cap_state.set_showcase_unlocked_bounds({"min_row": 3, "max_row": 8, "min_column": 4, "max_column": 9})
	var cap_coins_before: int = cap_state.coins
	var cap_quote: Dictionary = cap_state.quote_showcase_cell_purchase([Vector2i(2, 4)])
	_assert_equal(cap_quote.get("reason", ""), "level_cap", "Lv.2 should reject purchases above 36 cells")
	var cap_result: Dictionary = cap_state.purchase_showcase_cells([Vector2i(2, 4)])
	_assert_equal(cap_result.get("ok", true), false, "a cap-rejected purchase should fail atomically")
	_assert_equal(cap_state.coins, cap_coins_before, "a cap-rejected purchase should not deduct coins")
	_assert_equal(cap_state.get_showcase_unlocked_cells().size(), 36, "a cap-rejected purchase should not change cells")

	var poor_state = game_state_script.new_game()
	poor_state.level = 2
	poor_state.coins = 299
	var poor_result: Dictionary = poor_state.purchase_showcase_cells([adjacent])
	_assert_equal(poor_result.get("reason", ""), "insufficient_coins", "insufficient coins should be explained")
	_assert_equal(poor_state.coins, 299, "failed payment should leave coins unchanged")
	_assert_equal(poor_state.get_showcase_unlocked_cells().size(), 16, "failed payment should leave cells unchanged")

	var running_state = game_state_script.new_game()
	running_state.level = 2
	running_state.coins = 1000
	running_state.active_business_round = {"phase": "running"}
	var running_result: Dictionary = running_state.purchase_showcase_cells([adjacent])
	_assert_equal(running_result.get("reason", ""), "layout_locked", "running rounds should lock expansion")
	_assert_equal(running_state.coins, 1000, "layout lock should not deduct coins")

	_finish()


func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_fail("%s; expected=%s actual=%s" % [message, expected, actual])


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("SHOWCASE_CELL_PURCHASE_SELF_CHECK_PASS")
		quit(0)
		return
	for failure in _failures:
		printerr("SHOWCASE_CELL_PURCHASE_SELF_CHECK_FAIL: %s" % failure)
	quit(1)
