class_name TaskConditionService
extends RefCounted

const SUPPORTED_LEAF_OPERATORS := ["eq", "gte", "lte", "contains", "not_contains"]
const SUPPORTED_GROUP_OPERATORS := ["all", "any"]


static func evaluate_condition(report: Dictionary, condition: Dictionary, history: Array = []) -> Dictionary:
	if not bool(report.get("is_complete", false)):
		return _invalid_result("营业报告不完整：%s" % ", ".join(_string_array(report.get("missing_fields", []))))
	var consecutive_runs := maxi(1, int(condition.get("consecutive_runs", 1)))
	if consecutive_runs <= 1:
		return _evaluate_single(report, condition)

	var single_condition := condition.duplicate(true)
	single_condition.erase("consecutive_runs")
	var consecutive_count := 0
	var reports: Array = [report]
	reports.append_array(history)
	for report_value in reports:
		if not report_value is Dictionary or not bool((report_value as Dictionary).get("is_complete", false)):
			break
		var round_result := _evaluate_single(report_value, single_condition)
		if not bool(round_result.get("valid", false)) or not bool(round_result.get("passed", false)):
			break
		consecutive_count += 1
	var passed := consecutive_count >= consecutive_runs
	return {
		"valid": true,
		"passed": passed,
		"field": String(condition.get("field", "")),
		"operator": String(condition.get("operator", "")),
		"target": consecutive_runs,
		"current": consecutive_count,
		"gap": maxi(0, consecutive_runs - consecutive_count),
		"reason": "已连续达成 %d 轮" % consecutive_count if passed else "连续轮次还差 %d 轮" % maxi(0, consecutive_runs - consecutive_count),
		"children": []
	}


static func evaluate_condition_group(report: Dictionary, condition: Dictionary, history: Array = []) -> Dictionary:
	return evaluate_condition(report, condition, history)


static func evaluate_tiers(report: Dictionary, tiers: Array, history: Array = []) -> Dictionary:
	if not bool(report.get("is_complete", false)):
		return {
			"valid": false,
			"highest_tier": "",
			"next_tier": "",
			"tier_results": [],
			"next_failures": [],
			"reason": "营业报告不完整：%s" % ", ".join(_string_array(report.get("missing_fields", [])))
		}
	var tier_results: Array = []
	var highest_tier := ""
	var highest_index := -1
	for tier_index in range(tiers.size()):
		var tier_value: Variant = tiers[tier_index]
		if not tier_value is Dictionary:
			return _invalid_tier_result("评级定义必须是字典")
		var tier: Dictionary = tier_value
		var tier_id := String(tier.get("id", ""))
		var condition_value: Variant = tier.get("condition", {})
		if tier_id.is_empty() or not condition_value is Dictionary:
			return _invalid_tier_result("评级缺少 id 或 condition")
		var evaluation := evaluate_condition(report, condition_value, history)
		var tier_result := {
			"id": tier_id,
			"valid": bool(evaluation.get("valid", false)),
			"passed": bool(evaluation.get("passed", false)),
			"evaluation": evaluation
		}
		tier_results.append(tier_result)
		if not bool(evaluation.get("valid", false)):
			return _invalid_tier_result(String(evaluation.get("reason", "评级条件无效")), tier_results)
		if bool(evaluation.get("passed", false)):
			highest_tier = tier_id
			highest_index = tier_index

	var next_index := highest_index + 1
	var next_tier := ""
	var next_failures: Array = []
	if next_index >= 0 and next_index < tier_results.size():
		var next_result: Dictionary = tier_results[next_index]
		next_tier = String(next_result.get("id", ""))
		next_failures = _failed_leaves(next_result.get("evaluation", {}))
	return {
		"valid": true,
		"highest_tier": highest_tier,
		"next_tier": next_tier,
		"tier_results": tier_results,
		"next_failures": next_failures,
		"reason": "已达到 %s" % highest_tier if not highest_tier.is_empty() else "尚未达到铜级"
	}


static func _evaluate_single(report: Dictionary, condition: Dictionary) -> Dictionary:
	var operator := String(condition.get("operator", ""))
	if SUPPORTED_GROUP_OPERATORS.has(operator):
		return _evaluate_group(report, condition, operator)
	if not SUPPORTED_LEAF_OPERATORS.has(operator):
		return _invalid_result("未知条件操作符：%s" % operator)
	var field := String(condition.get("field", ""))
	if field.is_empty() or not condition.has("value"):
		return _invalid_result("条件缺少 field 或 value")
	var resolved := _resolve_path(report, field)
	if not bool(resolved.get("found", false)):
		return _invalid_result("营业报告缺少字段：%s" % field, field, operator, condition.get("value"))
	return _evaluate_leaf(field, operator, resolved.get("value"), condition.get("value"))


static func _evaluate_group(report: Dictionary, condition: Dictionary, operator: String) -> Dictionary:
	var conditions_value: Variant = condition.get("conditions", [])
	if not conditions_value is Array or (conditions_value as Array).is_empty():
		return _invalid_result("%s 条件组不能为空" % operator, "", operator)
	var children: Array = []
	var valid := true
	var passed := operator == "all"
	for child_value in conditions_value as Array:
		if not child_value is Dictionary:
			return _invalid_result("条件组子项必须是字典", "", operator)
		var child := _evaluate_single(report, child_value)
		children.append(child)
		valid = valid and bool(child.get("valid", false))
		if operator == "all":
			passed = passed and bool(child.get("passed", false))
		else:
			passed = passed or bool(child.get("passed", false))
	if not valid:
		passed = false
	return {
		"valid": valid,
		"passed": passed,
		"field": "",
		"operator": operator,
		"target": conditions_value.size(),
		"current": _passed_child_count(children),
		"gap": _failed_leaves({"children": children}).size(),
		"reason": "全部条件已达成" if passed and operator == "all" else "任一条件已达成" if passed else "仍有条件未达成",
		"children": children
	}


static func _evaluate_leaf(field: String, operator: String, current: Variant, target: Variant) -> Dictionary:
	var passed := false
	var gap: Variant = 0
	match operator:
		"eq":
			passed = current == target or _both_numeric(current, target) and float(current) == float(target)
			gap = absf(float(current) - float(target)) if _both_numeric(current, target) else (0 if passed else 1)
		"gte":
			if not _both_numeric(current, target):
				return _invalid_result("gte 只支持数值字段", field, operator, target, current)
			passed = float(current) >= float(target)
			gap = maxf(0.0, float(target) - float(current))
		"lte":
			if not _both_numeric(current, target):
				return _invalid_result("lte 只支持数值字段", field, operator, target, current)
			passed = float(current) <= float(target)
			gap = maxf(0.0, float(current) - float(target))
		"contains", "not_contains":
			var contains := _value_contains(current, target)
			passed = contains if operator == "contains" else not contains
			gap = 0 if passed else 1
	var reason := "已达成"
	if not passed:
		match operator:
			"gte": reason = "%s 还差 %s" % [field, _format_number(gap)]
			"lte": reason = "%s 超出 %s" % [field, _format_number(gap)]
			"eq": reason = "%s 当前为 %s，目标为 %s" % [field, current, target]
			"contains": reason = "%s 缺少 %s" % [field, target]
			"not_contains": reason = "%s 仍包含 %s" % [field, target]
	return {
		"valid": true,
		"passed": passed,
		"field": field,
		"operator": operator,
		"target": target,
		"current": current,
		"gap": gap,
		"reason": reason,
		"children": []
	}


static func _resolve_path(root: Dictionary, path: String) -> Dictionary:
	var current: Variant = root
	for segment in path.split("."):
		if current is Dictionary and (current as Dictionary).has(segment):
			current = (current as Dictionary).get(segment)
		elif current is Array and segment.is_valid_int() and int(segment) >= 0 and int(segment) < (current as Array).size():
			current = (current as Array)[int(segment)]
		else:
			return {"found": false}
	return {"found": true, "value": current}


static func _failed_leaves(result_value: Variant) -> Array:
	var result: Array = []
	if not result_value is Dictionary:
		return result
	var evaluation: Dictionary = result_value
	var children_value: Variant = evaluation.get("children", [])
	if children_value is Array and not (children_value as Array).is_empty():
		for child in children_value as Array:
			result.append_array(_failed_leaves(child))
	elif bool(evaluation.get("valid", false)) and not bool(evaluation.get("passed", false)):
		result.append(evaluation.duplicate(true))
	return result


static func _invalid_result(reason: String, field: String = "", operator: String = "", target: Variant = null, current: Variant = null) -> Dictionary:
	return {
		"valid": false,
		"passed": false,
		"field": field,
		"operator": operator,
		"target": target,
		"current": current,
		"gap": 0,
		"reason": reason,
		"children": []
	}


static func _invalid_tier_result(reason: String, tier_results: Array = []) -> Dictionary:
	return {
		"valid": false,
		"highest_tier": "",
		"next_tier": "",
		"tier_results": tier_results,
		"next_failures": [],
		"reason": reason
	}


static func _passed_child_count(children: Array) -> int:
	var result := 0
	for child_value in children:
		if child_value is Dictionary and bool((child_value as Dictionary).get("passed", false)):
			result += 1
	return result


static func _value_contains(current: Variant, target: Variant) -> bool:
	if current is Array:
		return (current as Array).has(target)
	if current is Dictionary:
		return (current as Dictionary).has(target)
	if current is String:
		return String(current).contains(String(target))
	return false


static func _both_numeric(left: Variant, right: Variant) -> bool:
	return (left is int or left is float) and (right is int or right is float)


static func _format_number(value: Variant) -> String:
	if value is float and is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return str(value)


static func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for child in value as Array:
			result.append(String(child))
	return result
