extends SceneTree

const SHOWCASE_RULE_SERVICE := preload("res://scripts/showcase_rule_service.gd")

var _failures: Array[String] = []


func _init() -> void:
	var rule := {"unlock_cell_count": 36, "required_empty_perimeter": 2, "boutique_price_pct": 6, "crowded_speed_pct": -6}
	var initial_bounds := {"min_row": 5, "max_row": 8, "min_column": 6, "max_column": 9}
	var preview: Dictionary = SHOWCASE_RULE_SERVICE.spacing_bonus(
		[Vector2i(6, 7)],
		[Vector2i(6, 7)],
		[],
		initial_bounds,
		true,
		rule
	)
	_expect_equal("spacing is inactive before thirty-six cells", bool(preview.get("active", true)), false)
	_expect_equal("inactive spacing changes no price", float(preview.get("price_pct", 0.0)), 0.0)
	if "预告" not in "\n".join(preview.get("reasons", [])):
		_fail("inactive spacing should remain visible as a preview")

	var expanded_bounds := {"min_row": 4, "max_row": 9, "min_column": 5, "max_column": 10}
	var boutique_cells := [Vector2i(6, 7), Vector2i(6, 8)]
	var boutique: Dictionary = SHOWCASE_RULE_SERVICE.spacing_bonus(
		boutique_cells,
		boutique_cells,
		[],
		expanded_bounds,
		true,
		rule
	)
	_expect_equal("eligible product with open perimeter earns boutique price", float(boutique.get("price_pct", 0.0)), 6.0)
	if int(boutique.get("empty_perimeter_count", 0)) < 2:
		_fail("boutique rule should count unlocked orthogonal empty cells")

	var crowded_occupied := boutique_cells + [
		Vector2i(5, 7), Vector2i(5, 8), Vector2i(7, 7), Vector2i(7, 8), Vector2i(6, 6), Vector2i(6, 9)
	]
	var crowded: Dictionary = SHOWCASE_RULE_SERVICE.spacing_bonus(
		boutique_cells,
		crowded_occupied,
		[],
		expanded_bounds,
		true,
		rule
	)
	_expect_equal("zero open perimeter causes crowded speed loss", float(crowded.get("speed_pct", 0.0)), -6.0)
	_expect_equal("crowded product does not also earn boutique price", float(crowded.get("price_pct", 0.0)), 0.0)

	var prop_blocked: Dictionary = SHOWCASE_RULE_SERVICE.spacing_bonus(
		boutique_cells,
		boutique_cells,
		[Vector2i(5, 7), Vector2i(5, 8), Vector2i(7, 7), Vector2i(7, 8), Vector2i(6, 6), Vector2i(6, 9)],
		expanded_bounds,
		true,
		rule
	)
	_expect_equal("prop cells do not count as empty perimeter", int(prop_blocked.get("empty_perimeter_count", -1)), 0)
	_finish()


func _expect_equal(label: String, actual: Variant, expected: Variant) -> void:
	if actual != expected:
		_fail("%s expected %s, got %s" % [label, expected, actual])


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("SHOWCASE_SPACING_RULE_SELF_CHECK_PASS")
		quit(0)
		return
	for failure in _failures:
		printerr("SHOWCASE_SPACING_RULE_SELF_CHECK_FAIL: %s" % failure)
	quit(1)
