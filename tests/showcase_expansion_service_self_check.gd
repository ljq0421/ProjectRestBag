extends SceneTree

const Service = preload("res://scripts/showcase_expansion_service.gd")

var failures: Array[String] = []

func _init() -> void:
	_expect_equal(Service.max_unlocked_cells_for_level(0), 16, "Lv.0 cap")
	_expect_equal(Service.max_unlocked_cells_for_level(2), 36, "Lv.2 cap")
	_expect_equal(Service.max_unlocked_cells_for_level(3), 64, "Lv.3 cap")
	_expect_equal(Service.max_unlocked_cells_for_level(4), 100, "Lv.4 cap")
	_expect_equal(Service.max_unlocked_cells_for_level(5), 144, "Lv.5 cap")
	_expect_equal(Service.max_unlocked_cells_for_level(6), 168, "Lv.6 cap")
	_expect_equal(Service.cell_price(1), 300, "first cell price")
	_expect_equal(Service.cell_price(2), 310, "second cell price")
	_expect_equal(Service.cell_price(152), 1810, "last cell price")
	_expect_equal(int(Service.quote(16, 152).get("total_cost", 0)), 160360, "all outer cells cumulative price")
	var quote: Dictionary = Service.quote(16, 3)
	_expect_equal(int(quote.get("first_price", 0)), 300, "batch first price")
	_expect_equal(int(quote.get("last_price", 0)), 320, "batch last price")
	_expect_equal(int(quote.get("total_cost", 0)), 930, "batch arithmetic sum")

	var unlocked := [Vector2i(5, 6), Vector2i(5, 7)]
	_expect(Service.is_connected_purchase(unlocked, [Vector2i(5, 8), Vector2i(5, 9)]), "selection may extend outward through selected cells")
	_expect(not Service.is_connected_purchase(unlocked, [Vector2i(5, 9)]), "isolated selection should fail")
	_expect(Service.can_add_cell(unlocked, [Vector2i(5, 8)], Vector2i(5, 9)), "next selected cell may touch prior selection")
	_expect(not Service.can_add_cell(unlocked, [], Vector2i(8, 8)), "first selected cell must touch unlocked area")

	var initial: Array[Vector2i] = []
	for row in range(5, 9):
		for column in range(6, 10): initial.append(Vector2i(row, column))
	_expect_equal(Service.row_candidates(initial, 4), [Vector2i(4, 6), Vector2i(4, 7), Vector2i(4, 8), Vector2i(4, 9)], "row tool buys direct neighbors only")
	_expect_equal(Service.column_candidates(initial, 5), [Vector2i(5, 5), Vector2i(6, 5), Vector2i(7, 5), Vector2i(8, 5)], "column tool buys direct neighbors only")

	if failures.is_empty():
		print("SHOWCASE_EXPANSION_SERVICE_SELF_CHECK_PASS")
		quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)

func _expect(value: bool, message: String) -> void:
	if not value: failures.append(message)

func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected: failures.append("%s expected=%s actual=%s" % [message, expected, actual])
