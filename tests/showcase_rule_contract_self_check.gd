extends SceneTree

const SHOP_SIMULATION := preload("res://scripts/shop_simulation.gd")
const SHOWCASE_RULE_SERVICE := preload("res://scripts/showcase_rule_service.gd")
const GAME_STATE := preload("res://scripts/game_state.gd")
const CATALOG := preload("res://scripts/catalog.gd")

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_adjacency_stacks_distinct_rules_once_each()
	_test_sets_require_complete_tag_coverage_and_minimal_members()
	_test_cluster_penalty_uses_connected_components()
	_test_sample_reputation_is_separate_from_price_reputation()
	_finish()


func _test_adjacency_stacks_distinct_rules_once_each() -> void:
	var cells := {
		"a": [Vector2i(1, 1), Vector2i(2, 1)],
		"b": [Vector2i(1, 2), Vector2i(2, 2)]
	}
	var recipes := {
		"a": {"name": "A", "tags": ["果香", "低负担"]},
		"b": {"name": "B", "tags": ["清爽"]}
	}
	var rules := {
		"fruit": {"priority": 20, "rule_name": "果香清爽", "trigger_tag_a": "果香", "trigger_tag_b": "清爽", "price_bonus_pct": 8, "speed_bonus_pct": 5},
		"light": {"priority": 10, "rule_name": "轻食清爽", "trigger_tag_a": "低负担", "trigger_tag_b": "清爽", "price_bonus_pct": 7, "speed_bonus_pct": 7}
	}
	var bonuses: Dictionary = SHOP_SIMULATION._calc_adjacency_tag_bonuses(cells, recipes, rules)
	_assert_equal(float((bonuses.get("a", {}) as Dictionary).get("price_pct", 0.0)), 15.0, "one adjacent pair should stack two different tag rules")
	_assert_equal(float((bonuses.get("b", {}) as Dictionary).get("speed_pct", 0.0)), 12.0, "both products should receive every matched tag rule")
	_assert_equal(((bonuses.get("a", {}) as Dictionary).get("reasons", []) as Array).size(), 2, "multi-cell contact should not duplicate the same rule")


func _test_sets_require_complete_tag_coverage_and_minimal_members() -> void:
	var set_rule := {
		"tea_set": {"set_name": "下午茶", "required_tags": ["茶香", "香脆", "浓郁"], "min_item_count": 3, "price_bonus_pct": 10, "speed_bonus_pct": 5}
	}
	var missing_cells := {
		"tea_a": [Vector2i(1, 1)],
		"crisp": [Vector2i(1, 2)],
		"tea_b": [Vector2i(1, 3)]
	}
	var missing_recipes := {
		"tea_a": {"name": "茶一", "tags": ["茶香"]},
		"crisp": {"name": "酥点", "tags": ["香脆"]},
		"tea_b": {"name": "茶二", "tags": ["茶香"]}
	}
	var missing: Dictionary = SHOP_SIMULATION._calc_set_bonuses(missing_cells, missing_recipes, set_rule)
	for recipe_id in missing.keys():
		_assert_equal(float((missing[recipe_id] as Dictionary).get("price_pct", 0.0)), 0.0, "a set missing a required tag must not trigger")

	var valid_cells := missing_cells.duplicate(true)
	valid_cells["rich"] = [Vector2i(1, 4)]
	var valid_recipes := missing_recipes.duplicate(true)
	valid_recipes["rich"] = {"name": "浓点", "tags": ["浓郁"]}
	var valid: Dictionary = SHOP_SIMULATION._calc_set_bonuses(valid_cells, valid_recipes, set_rule)
	_assert_equal(float((valid.get("tea_a", {}) as Dictionary).get("price_pct", 0.0)), 0.0, "an extra same-tag member should not be swept into the minimal set")
	for recipe_id in ["crisp", "tea_b", "rich"]:
		_assert_equal(float((valid.get(recipe_id, {}) as Dictionary).get("price_pct", 0.0)), 10.0, "the minimal connected tag-covering members should receive the set")


func _test_cluster_penalty_uses_connected_components() -> void:
	var recipes := {
		"a": {"name": "A", "tags": ["经典"]},
		"b": {"name": "B", "tags": ["经典"]},
		"c": {"name": "C", "tags": ["经典"]}
	}
	var rules := {
		"penalty_001": {"penalty_name": "同类扎堆", "price_penalty_pct": -5, "speed_penalty_pct": -3}
	}
	var separated: Dictionary = SHOP_SIMULATION._calc_conflict_penalties({
		"a": [Vector2i(1, 1)], "b": [Vector2i(1, 3)], "c": [Vector2i(1, 5)]
	}, recipes, rules)
	for recipe_id in separated.keys():
		_assert_equal(float((separated[recipe_id] as Dictionary).get("price_pct", 0.0)), 0.0, "separated same-tag products should not be treated as one cluster")

	var connected: Dictionary = SHOP_SIMULATION._calc_conflict_penalties({
		"a": [Vector2i(1, 1)], "b": [Vector2i(1, 2)], "c": [Vector2i(1, 3)]
	}, recipes, rules)
	_assert_equal(float((connected.get("a", {}) as Dictionary).get("price_pct", 0.0)), 0.0, "first connected cluster member should be safe")
	_assert_equal(float((connected.get("b", {}) as Dictionary).get("price_pct", 0.0)), 0.0, "second connected cluster member should be safe")
	_assert_equal(float((connected.get("c", {}) as Dictionary).get("price_pct", 0.0)), -5.0, "third connected cluster member should receive the penalty")


func _test_sample_reputation_is_separate_from_price_reputation() -> void:
	var definition: Dictionary = SHOWCASE_RULE_SERVICE.variant_definition("butter_cookie", "sample", {})
	_assert_equal(int(definition.get("reputation_delta", 0)), 1, "sample definition should disclose one extra reputation per real sale")

	var state = GAME_STATE.new_game()
	state.level = 2
	state.add_recipe("butter_cookie")
	state.add_product("butter_cookie", 1)
	if not state.list_display_item("butter_cookie", [Vector2i(6, 7)], 1, "sample"):
		_fail("sample variant should be placeable in an unlocked golden cell")
		return
	var catalog = CATALOG.new()
	var result: Dictionary = SHOWCASE_RULE_SERVICE.calculate(state, catalog.get_recipes(), catalog.get_display_rules())
	var item: Dictionary = (result.get("items", {}) as Dictionary).get("butter_cookie", {})
	var price_multiplier := float(item.get("price_multiplier", 1.0))
	var price_derived := int(round(clampf(((price_multiplier - 1.0) * 100.0) / 10.0, -3.0, 5.0)))
	_assert_equal(int(item.get("reputation_delta", 0)), price_derived + 1, "sample reputation should be added after price-derived reputation")


func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_fail("%s; expected=%s actual=%s" % [message, expected, actual])


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("SHOWCASE_RULE_CONTRACT_SELF_CHECK_PASS")
		quit(0)
		return
	for failure in _failures:
		printerr("SHOWCASE_RULE_CONTRACT_SELF_CHECK_FAIL: %s" % failure)
	quit(1)
