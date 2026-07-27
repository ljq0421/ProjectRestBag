extends SceneTree

const SHOWCASE_RULE_SERVICE := preload("res://scripts/showcase_rule_service.gd")

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var service = SHOWCASE_RULE_SERVICE.new()
	if not service.has_method("set_progress"):
		_fail("ShowcaseRuleService should expose set_progress")
		_finish()
		return
	_test_candidates_exclude_unrelated_sets()
	_test_missing_count_uses_smallest_recipe_combination()
	_test_complete_but_disconnected_set_needs_connection()
	_test_connected_set_is_active()
	_test_results_sort_by_status_gap_and_config_order()
	_finish()


func _test_candidates_exclude_unrelated_sets() -> void:
	var result: Array = _set_progress(
		{"tea": {"cells": [Vector2i(1, 1)]}},
		{
			"tea": {"tags": ["茶香"]},
			"crisp": {"tags": ["香脆"]},
			"fruit": {"tags": ["果香"]}
		},
		{
			"tea_set": {"set_name": "下午茶", "required_tags": ["茶香", "香脆"], "min_item_count": 2},
			"fruit_set": {"set_name": "果味", "required_tags": ["果香", "清爽"], "min_item_count": 2}
		}
	)
	_assert_equal(result.size(), 1, "only a set with a currently contributing item should be a candidate")
	if not result.is_empty():
		_assert_equal(String((result[0] as Dictionary).get("set_id", "")), "tea_set", "candidate should keep the configured set id")


func _test_missing_count_uses_smallest_recipe_combination() -> void:
	var result: Array = _set_progress(
		{"tea": {"cells": [Vector2i(1, 1)]}},
		{
			"tea": {"tags": ["茶香"]},
			"crisp_rich": {"tags": ["香脆", "浓郁"]},
			"crisp": {"tags": ["香脆"]},
			"rich": {"tags": ["浓郁"]}
		},
		{
			"tea_set": {"set_name": "下午茶", "required_tags": ["茶香", "香脆", "浓郁"], "min_item_count": 2}
		}
	)
	_assert_equal(result.size(), 1, "tag-contributing display should produce one candidate")
	if not result.is_empty():
		var entry: Dictionary = result[0]
		_assert_equal(String(entry.get("status", "")), "missing_items", "incomplete set should report missing items")
		_assert_equal(int(entry.get("missing_count", -1)), 1, "one recipe covering two missing tags should count as one missing item")


func _test_complete_but_disconnected_set_needs_connection() -> void:
	var result: Array = _set_progress(
		{
			"tea": {"cells": [Vector2i(1, 1)]},
			"crisp": {"cells": [Vector2i(4, 4)]}
		},
		{
			"tea": {"tags": ["茶香"]},
			"crisp": {"tags": ["香脆"]}
		},
		{
			"tea_set": {"set_name": "下午茶", "required_tags": ["茶香", "香脆"], "min_item_count": 2}
		}
	)
	_assert_equal(String((result[0] as Dictionary).get("status", "")), "needs_connection", "complete tags without adjacency should ask for connected placement")
	_assert_equal(int((result[0] as Dictionary).get("missing_count", -1)), 0, "connection-only candidate should not claim missing items")


func _test_connected_set_is_active() -> void:
	var result: Array = _set_progress(
		{
			"tea": {"cells": [Vector2i(1, 1)]},
			"crisp": {"cells": [Vector2i(1, 2)]}
		},
		{
			"tea": {"tags": ["茶香"]},
			"crisp": {"tags": ["香脆"]}
		},
		{
			"tea_set": {"set_name": "下午茶", "required_tags": ["茶香", "香脆"], "min_item_count": 2}
		}
	)
	_assert_equal(String((result[0] as Dictionary).get("status", "")), "active", "connected complete set should use the real active contract")


func _test_results_sort_by_status_gap_and_config_order() -> void:
	var result: Array = _set_progress(
		{
			"tea": {"cells": [Vector2i(1, 1)]},
			"crisp": {"cells": [Vector2i(1, 2)]},
			"fruit": {"cells": [Vector2i(6, 6)]}
		},
		{
			"tea": {"tags": ["茶香"]},
			"crisp": {"tags": ["香脆"]},
			"fruit": {"tags": ["果香"]},
			"clear": {"tags": ["清爽"]},
			"cool": {"tags": ["清凉"]},
			"rich": {"tags": ["浓郁"]}
		},
		{
			"missing_two": {"set_name": "缺二", "required_tags": ["果香", "清爽", "清凉"], "min_item_count": 3},
			"missing_one_a": {"set_name": "缺一甲", "required_tags": ["茶香", "浓郁"], "min_item_count": 2},
			"missing_one_b": {"set_name": "缺一乙", "required_tags": ["香脆", "浓郁"], "min_item_count": 2},
			"active": {"set_name": "已生效", "required_tags": ["茶香", "香脆"], "min_item_count": 2}
		}
	)
	var ids: Array[String] = []
	for entry_value in result:
		ids.append(String((entry_value as Dictionary).get("set_id", "")))
	_assert_equal(ids, ["active", "missing_one_a", "missing_one_b", "missing_two"], "results should sort by active state, missing count, then config order")


func _set_progress(display_items: Dictionary, recipes: Dictionary, set_rules: Dictionary) -> Array:
	var service = SHOWCASE_RULE_SERVICE.new()
	return service.call("set_progress", display_items, recipes, set_rules)


func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_fail("%s; expected=%s actual=%s" % [message, expected, actual])


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("SHOWCASE_SET_PROGRESS_SELF_CHECK_PASS")
		quit(0)
		return
	for failure in _failures:
		printerr("SHOWCASE_SET_PROGRESS_SELF_CHECK_FAIL: %s" % failure)
	quit(1)
