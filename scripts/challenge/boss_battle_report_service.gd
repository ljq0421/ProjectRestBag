class_name BossBattleReportService
extends RefCounted

const SUGGESTION_BY_METRIC := {
	"sales_count": {
		"code": "increase_early_sales",
		"text": "增加短周期配方，或提高前段挑战备货。"
	},
	"active_relation_count": {
		"code": "build_drink_bake_relation",
		"text": "让饮品与烘焙配方正交相邻，激活组合关系。"
	},
	"window_satisfaction": {
		"code": "increase_window_satisfaction",
		"text": "提高中后段满足力，或避免关键配方过早耗尽。"
	},
	"tag_sales_count": {
		"code": "increase_tag_sales",
		"text": "增加目标标签配方的售卖次数，并确保它们在需求截止前出餐。"
	},
	"tag_satisfaction": {
		"code": "increase_tag_satisfaction",
		"text": "提高目标标签配方在指定区间内贡献的满足力。"
	},
	"distinct_tag_count": {
		"code": "increase_tag_variety",
		"text": "加入更多目标标签，并确保每种标签都能在截止前实际售出。"
	}
}


func build(battle_state: Dictionary, encounter: Dictionary) -> Dictionary:
	var windows: Array[Dictionary] = []
	var failed_windows: Array[Dictionary] = []
	var resolved_windows: Dictionary = battle_state.get("resolved_windows", {})
	for window_value in encounter.get("windows", []):
		if not window_value is Dictionary:
			continue
		var definition: Dictionary = window_value
		var window_id := String(definition.get("id", ""))
		var row := {
			"window_id": window_id,
			"at_ms": int(definition.get("at_ms", 0)),
			"metric": String(definition.get("metric", "")),
			"tag": String(definition.get("tag", "")),
			"target_tags": _target_tags(definition),
			"target": int(definition.get("target", 0)),
			"resolved": false,
			"actual": null,
			"passed": null,
			"base_reputation_damage": 0,
			"guard_absorbed": 0,
			"reputation_damage": 0,
			"reputation_after": int(battle_state.get("reputation", 0)),
			"upgrade_source_ids": []
		}
		if resolved_windows.has(window_id) and resolved_windows[window_id] is Dictionary:
			var resolved: Dictionary = resolved_windows[window_id]
			row["resolved"] = true
			row["actual"] = int(resolved.get("actual", 0))
			row["passed"] = bool(resolved.get("passed", false))
			row["base_reputation_damage"] = int(
				resolved.get("base_reputation_damage", resolved.get("reputation_damage", 0))
			)
			row["guard_absorbed"] = int(resolved.get("guard_absorbed", 0))
			row["reputation_damage"] = int(resolved.get("reputation_damage", 0))
			row["reputation_after"] = int(resolved.get("reputation_after", battle_state.get("reputation", 0)))
			row["upgrade_source_ids"] = _string_array(
				resolved.get("upgrade_source_ids", [])
			)
			if not bool(row["passed"]):
				failed_windows.append(row.duplicate(true))
		windows.append(row)

	var primary_failure: Dictionary = {}
	if not failed_windows.is_empty():
		primary_failure = failed_windows.back().duplicate(true)
	var suggestions := _build_suggestions(failed_windows)
	var contributions := _build_recipe_contributions(battle_state.get("events", []))

	return {
		"outcome": String(battle_state.get("outcome", "")),
		"elapsed_ms": int(battle_state.get("elapsed_ms", 0)),
		"pickiness_remaining": int(battle_state.get("pickiness", 0)),
		"reputation_remaining": int(battle_state.get("reputation", 0)),
		"windows": windows,
		"primary_failure": primary_failure,
		"suggestions": suggestions,
		"recipe_contributions": contributions,
		"applied_upgrades": (
			(battle_state.get("_snapshot", {}) as Dictionary).get(
				"applied_upgrades",
				[]
			) as Array
		).duplicate(true),
		"total_sales": _sum_field(contributions, "sales_count"),
		"total_satisfaction": _sum_field(contributions, "total_satisfaction")
	}


func _build_suggestions(failed_windows: Array[Dictionary]) -> Array[Dictionary]:
	var suggestions: Array[Dictionary] = []
	var seen_codes := {}
	for reverse_index in failed_windows.size():
		var failure: Dictionary = failed_windows[failed_windows.size() - 1 - reverse_index]
		var metric := String(failure.get("metric", ""))
		if not SUGGESTION_BY_METRIC.has(metric):
			continue
		var suggestion: Dictionary = SUGGESTION_BY_METRIC[metric].duplicate(true)
		var code := String(suggestion.get("code", ""))
		if seen_codes.has(code):
			continue
		suggestion["window_id"] = String(failure.get("window_id", ""))
		suggestion["actual"] = failure.get("actual")
		suggestion["target"] = failure.get("target")
		suggestions.append(suggestion)
		seen_codes[code] = true
	return suggestions


func _build_recipe_contributions(events: Array) -> Array[Dictionary]:
	var by_recipe := {}
	for event_value in events:
		if not event_value is Dictionary:
			continue
		var event: Dictionary = event_value
		if event.get("type") != "sale":
			continue
		var recipe_id := String(event.get("recipe_id", ""))
		if not by_recipe.has(recipe_id):
			by_recipe[recipe_id] = {
				"recipe_id": recipe_id,
				"sales_count": 0,
				"base_satisfaction": 0,
				"relation_bonus": 0,
				"total_satisfaction": 0,
				"upgrade_source_ids": []
			}
		var row: Dictionary = by_recipe[recipe_id]
		row["sales_count"] = int(row["sales_count"]) + 1
		row["base_satisfaction"] = int(row["base_satisfaction"]) + int(event.get("base_satisfaction", 0))
		row["relation_bonus"] = int(row["relation_bonus"]) + int(event.get("relation_bonus", 0))
		row["total_satisfaction"] = int(row["total_satisfaction"]) + int(event.get("final_satisfaction", 0))
		var source_ids := _string_array(row.get("upgrade_source_ids", []))
		for source_id in _string_array(event.get("upgrade_source_ids", [])):
			if not source_ids.has(source_id):
				source_ids.append(source_id)
		source_ids.sort()
		row["upgrade_source_ids"] = source_ids
		by_recipe[recipe_id] = row

	var rows: Array[Dictionary] = []
	for recipe_id in by_recipe:
		rows.append((by_recipe[recipe_id] as Dictionary).duplicate(true))
	rows.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_total := int(left.get("total_satisfaction", 0))
		var right_total := int(right.get("total_satisfaction", 0))
		if left_total != right_total:
			return left_total > right_total
		return String(left.get("recipe_id", "")) < String(right.get("recipe_id", ""))
	)
	return rows


func _sum_field(rows: Array[Dictionary], field: String) -> int:
	var total := 0
	for row in rows:
		total += int(row.get(field, 0))
	return total


func _target_tags(definition: Dictionary) -> Array[String]:
	var raw_tags: Variant = definition.get("target_tags", definition.get("tags", []))
	var tags: Array[String] = []
	if raw_tags is Array:
		for value in raw_tags:
			var tag := String(value)
			if not tag.is_empty() and not tags.has(tag):
				tags.append(tag)
	var single_tag := String(definition.get("tag", ""))
	if not single_tag.is_empty() and not tags.has(single_tag):
		tags.append(single_tag)
	tags.sort()
	return tags


func _string_array(values: Variant) -> Array[String]:
	var result: Array[String] = []
	if not values is Array:
		return result
	for value in values:
		var text := String(value)
		if not text.is_empty() and not result.has(text):
			result.append(text)
	result.sort()
	return result
