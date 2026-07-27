class_name TaskCatalogService
extends RefCounted

const GAME_DATA_PATH := "res://game_data.json"
const Catalog = preload("res://scripts/catalog.gd")
const CATEGORIES := [
	"tutorial_tasks",
	"growth_tasks",
	"round_contracts",
	"side_tasks"
]
const ALLOWED_TYPES := ["tutorial", "growth", "contract", "daily", "feature"]
const ALLOWED_REWARD_KEYS := ["coins", "reputation", "ingredients", "tools", "unlock_tools", "unlock_devices", "unlock_automation", "unlock_features", "set_level", "starlight"]
const ALLOWED_OBJECTIVE_EFFECT_KEYS := ["unlock_tools", "unlock_devices", "unlock_automation"]
const ALLOWED_REPORT_FIELDS := [
	"report_id", "round_id", "kind", "challenge_id", "challenge_version", "duration_ms",
	"total_coins", "normal_income", "base_income", "market_income", "layout_extra_income",
	"max_product_sold", "sold_distinct_recipes", "layout.", "counts.", "products."
]
const ALLOWED_CONDITION_OPERATORS := ["eq", "gte", "lte", "contains", "not_contains", "all", "any"]


static func load_catalog() -> Dictionary:
	var data := load_game_data()
	var tasks_value: Variant = data.get("tasks", {})
	if not tasks_value is Dictionary:
		return {}
	var source: Dictionary = tasks_value
	var catalog := {}
	for category in CATEGORIES:
		var rows_value: Variant = source.get(category, [])
		catalog[category] = _normalize_value(rows_value) if rows_value is Array else []
	return catalog


static func load_game_data() -> Dictionary:
	var file := FileAccess.open(GAME_DATA_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return (parsed as Dictionary).duplicate(true) if parsed is Dictionary else {}


static func definitions_by_id(catalog: Dictionary) -> Dictionary:
	var definitions := {}
	for category in CATEGORIES:
		var rows_value: Variant = catalog.get(category, [])
		if not rows_value is Array:
			continue
		for row_value: Variant in rows_value:
			if not row_value is Dictionary:
				continue
			var task: Dictionary = (row_value as Dictionary).duplicate(true)
			var task_id := String(task.get("id", ""))
			if task_id.is_empty() or definitions.has(task_id):
				continue
			definitions[task_id] = task
	return definitions


static func task_ids_with_reset_policy(catalog: Dictionary, reset_policy: String) -> Array[String]:
	var ids: Array[String] = []
	for task_value: Variant in definitions_by_id(catalog).values():
		if not task_value is Dictionary:
			continue
		var task: Dictionary = task_value
		if String(task.get("reset_policy", "")) == reset_policy:
			ids.append(String(task.get("id", "")))
	ids.sort()
	return ids


static func validate_catalog(catalog: Dictionary, game_data: Dictionary = {}) -> Array[String]:
	var errors: Array[String] = []
	var seen_ids := {}
	for category in CATEGORIES:
		if not catalog.has(category):
			errors.append("missing category: %s" % category)
			continue
		var rows_value: Variant = catalog.get(category, [])
		if not rows_value is Array:
			errors.append("category should be an array: %s" % category)
			continue
		for index in (rows_value as Array).size():
			var task_value: Variant = (rows_value as Array)[index]
			if not task_value is Dictionary:
				errors.append("%s[%d] should be a dictionary" % [category, index])
				continue
			var task: Dictionary = task_value
			var task_id := String(task.get("id", ""))
			if task_id.is_empty():
				errors.append("%s[%d] has no id" % [category, index])
				continue
			if seen_ids.has(task_id):
				errors.append("duplicate task id: %s" % task_id)
			else:
				seen_ids[task_id] = true
			if int(task.get("version", 0)) <= 0:
				errors.append("task version should be positive: %s" % task_id)
			if not ALLOWED_TYPES.has(String(task.get("type", ""))):
				errors.append("unsupported task type: %s" % task_id)
			var objectives_value: Variant = task.get("objectives", [])
			if objectives_value is Array and not (objectives_value as Array).is_empty():
				_validate_objectives(objectives_value, task_id, errors)
			else:
				if maxi(0, int(task.get("goal", 0))) <= 0:
					errors.append("task goal should be positive: %s" % task_id)
				if not task.get("condition", {}) is Dictionary and not task.get("conditions", []) is Array:
					errors.append("task condition should be structured: %s" % task_id)

	for task_value: Variant in definitions_by_id(catalog).values():
		if not task_value is Dictionary:
			continue
		var task: Dictionary = task_value
		var task_id := String(task.get("id", ""))
		var prerequisites_value: Variant = task.get("prerequisites", [])
		if not prerequisites_value is Array:
			errors.append("task prerequisites should be an array: %s" % task_id)
			continue
		for prerequisite_value: Variant in prerequisites_value:
			var prerequisite := String(prerequisite_value)
			if not seen_ids.has(prerequisite):
				errors.append("missing prerequisite %s for %s" % [prerequisite, task_id])
		var reward_value: Variant = task.get("reward", {})
		if reward_value is Dictionary:
			for reward_key in (reward_value as Dictionary).keys():
				if not ALLOWED_REWARD_KEYS.has(String(reward_key)):
					errors.append("unsupported reward key %s for %s" % [reward_key, task_id])
		if int(task.get("level", 0)) >= 1 and reward_value is Dictionary and (reward_value as Dictionary).has("set_level"):
			errors.append("Lv.1+ task must not set level: %s" % task_id)
		var task_type := String(task.get("type", ""))
		if int(task.get("level", 0)) >= 3 and ["growth", "contract"].has(task_type) and String(task.get("event", "")) != "business_round_completed":
			errors.append("Lv.3+ build task must consume a round report: %s" % task_id)
		var condition_value: Variant = task.get("condition", {})
		if condition_value is Dictionary and String((condition_value as Dictionary).get("kind", "")) == "round_report":
			_validate_report_condition(condition_value, task_id, errors)
		var tiers_value: Variant = task.get("tiers", [])
		if ["tutorial", "growth"].has(task_type) and (task.has("tiers") or task.has("required_tier")):
			errors.append("tutorial and growth tasks must not use tiers: %s" % task_id)
		elif task_type == "contract" and (not tiers_value is Array or (tiers_value as Array).is_empty()):
			errors.append("contract tiers should be populated: %s" % task_id)
		elif tiers_value is Array and not (tiers_value as Array).is_empty():
			_validate_tiers(tiers_value, task_id, errors)
	_validate_prerequisite_cycles(definitions_by_id(catalog), errors)

	var environment_ids := _environment_ids(game_data)
	for task_value in definitions_by_id(catalog).values():
		if not task_value is Dictionary:
			continue
		var environment_id := String((task_value as Dictionary).get("environment_id", ""))
		if not environment_id.is_empty() and not environment_ids.has(environment_id):
			errors.append("missing environment %s for %s" % [environment_id, String((task_value as Dictionary).get("id", ""))])

	var automation_value: Variant = game_data.get("automation", {})
	if automation_value is Dictionary:
		var automation: Dictionary = automation_value
		if automation.has("feature_tasks"):
			errors.append("automation.feature_tasks should be migrated into tasks")
		var feature_unlocks_value: Variant = automation.get("feature_unlocks", {})
		if feature_unlocks_value is Dictionary:
			for feature_id_value: Variant in (feature_unlocks_value as Dictionary).keys():
				var feature_value: Variant = (feature_unlocks_value as Dictionary).get(feature_id_value, {})
				if not feature_value is Dictionary:
					continue
				var referenced_task_id := String((feature_value as Dictionary).get("task_id", ""))
				if referenced_task_id.is_empty() or not seen_ids.has(referenced_task_id):
					errors.append("automation feature task does not resolve: %s" % String(feature_id_value))
	return errors


static func _validate_objectives(objectives_value: Variant, task_id: String, errors: Array[String]) -> void:
	if not objectives_value is Array or (objectives_value as Array).is_empty():
		errors.append("task objectives should be a non-empty array: %s" % task_id)
		return
	var seen_ids := {}
	for index in (objectives_value as Array).size():
		var objective_value: Variant = (objectives_value as Array)[index]
		if not objective_value is Dictionary:
			errors.append("objective should be a dictionary for %s[%d]" % [task_id, index])
			continue
		var objective: Dictionary = objective_value
		var objective_id := String(objective.get("id", ""))
		if objective_id.is_empty():
			errors.append("objective id is missing for %s[%d]" % [task_id, index])
		elif seen_ids.has(objective_id):
			errors.append("duplicate objective id %s for %s" % [objective_id, task_id])
		else:
			seen_ids[objective_id] = true
		if String(objective.get("title", "")).is_empty():
			errors.append("objective title is missing for %s:%s" % [task_id, objective_id])
		var events_value: Variant = objective.get("events", [])
		if String(objective.get("event", "")).is_empty() and (not events_value is Array or (events_value as Array).is_empty()):
			errors.append("objective event is missing for %s:%s" % [task_id, objective_id])
		if maxi(0, int(objective.get("goal", 0))) <= 0:
			errors.append("objective goal should be positive for %s:%s" % [task_id, objective_id])
		var condition_value: Variant = objective.get("condition", {})
		if not condition_value is Dictionary:
			errors.append("objective condition should be structured for %s:%s" % [task_id, objective_id])
		else:
			var condition: Dictionary = condition_value
			if String(condition.get("kind", "")) == "round_report":
				_validate_report_condition(condition, "%s:%s" % [task_id, objective_id], errors)
			if condition.has("item_ids"):
				_validate_objective_item_ids(condition.get("item_ids"), task_id, objective_id, errors)
		var effect_value: Variant = objective.get("effect", {})
		if effect_value is Dictionary:
			for effect_key_value: Variant in (effect_value as Dictionary).keys():
				if not ALLOWED_OBJECTIVE_EFFECT_KEYS.has(String(effect_key_value)):
					errors.append("unsupported objective effect %s for %s:%s" % [String(effect_key_value), task_id, objective_id])
		if objective.has("notification"):
			var notification_value: Variant = objective.get("notification")
			if not notification_value is Dictionary:
				errors.append("objective notification should be a dictionary for %s:%s" % [task_id, objective_id])
			else:
				var notification: Dictionary = notification_value
				if String(notification.get("title", "")).strip_edges().is_empty():
					errors.append("objective notification title is missing for %s:%s" % [task_id, objective_id])
				if String(notification.get("body", "")).strip_edges().is_empty():
					errors.append("objective notification body is missing for %s:%s" % [task_id, objective_id])


static func _validate_objective_item_ids(item_ids_value: Variant, task_id: String, objective_id: String, errors: Array[String]) -> void:
	if not item_ids_value is Array or (item_ids_value as Array).is_empty():
		errors.append("objective item_ids should be a non-empty array for %s:%s" % [task_id, objective_id])
		return
	var ingredients := Catalog.new().get_ingredients()
	for item_id_value: Variant in item_ids_value as Array:
		var item_id := String(item_id_value).strip_edges()
		if item_id.is_empty() or not ingredients.has(item_id):
			errors.append("objective item_id %s does not resolve for %s:%s" % [item_id, task_id, objective_id])


static func _validate_prerequisite_cycles(definitions: Dictionary, errors: Array[String]) -> void:
	var visiting := {}
	var visited := {}
	for task_id_value: Variant in definitions.keys():
		_visit_prerequisites(String(task_id_value), definitions, visiting, visited, errors)


static func _visit_prerequisites(task_id: String, definitions: Dictionary, visiting: Dictionary, visited: Dictionary, errors: Array[String]) -> void:
	if visited.has(task_id):
		return
	if visiting.has(task_id):
		errors.append("task prerequisite cycle includes: %s" % task_id)
		return
	visiting[task_id] = true
	var task_value: Variant = definitions.get(task_id, {})
	if task_value is Dictionary:
		for prerequisite_value: Variant in (task_value as Dictionary).get("prerequisites", []):
			var prerequisite := String(prerequisite_value)
			if definitions.has(prerequisite):
				_visit_prerequisites(prerequisite, definitions, visiting, visited, errors)
	visiting.erase(task_id)
	visited[task_id] = true


static func _validate_report_condition(condition_value: Variant, task_id: String, errors: Array[String]) -> void:
	if not condition_value is Dictionary:
		errors.append("round report condition should be a dictionary: %s" % task_id)
		return
	var condition: Dictionary = condition_value
	var operator := String(condition.get("operator", ""))
	if operator.is_empty() and String(condition.get("kind", "")) == "round_report" and condition.size() == 1:
		return
	if not ALLOWED_CONDITION_OPERATORS.has(operator):
		errors.append("unsupported condition operator %s for %s" % [operator, task_id])
		return
	if ["all", "any"].has(operator):
		var children_value: Variant = condition.get("conditions", [])
		if not children_value is Array or (children_value as Array).is_empty():
			errors.append("empty condition group for %s" % task_id)
			return
		for child in children_value as Array:
			_validate_report_condition(child, task_id, errors)
		return
	var field := String(condition.get("field", ""))
	var allowed := false
	for prefix in ALLOWED_REPORT_FIELDS:
		if field == prefix or prefix.ends_with(".") and field.begins_with(prefix):
			allowed = true
			break
	if not allowed:
		errors.append("unsupported report field %s for %s" % [field, task_id])
	if not condition.has("value"):
		errors.append("condition target is missing for %s" % task_id)


static func _validate_tiers(tiers_value: Variant, task_id: String, errors: Array[String]) -> void:
	if not tiers_value is Array:
		return
	var previous_targets := {}
	for tier_value in tiers_value as Array:
		if not tier_value is Dictionary:
			errors.append("tier should be a dictionary for %s" % task_id)
			continue
		var tier: Dictionary = tier_value
		var condition_value: Variant = tier.get("condition", {})
		_validate_report_condition(condition_value, task_id, errors)
		var current_targets := {}
		_collect_numeric_targets(condition_value, current_targets)
		for key_value in current_targets.keys():
			if not previous_targets.has(key_value):
				continue
			var parts := String(key_value).split("|")
			var operator := parts[1] if parts.size() > 1 else ""
			var current := float(current_targets.get(key_value, 0.0))
			var previous := float(previous_targets.get(key_value, 0.0))
			if operator == "gte" and current < previous or operator == "lte" and current > previous:
				errors.append("tier target becomes easier for %s: %s" % [task_id, parts[0]])
		previous_targets = current_targets


static func _collect_numeric_targets(condition_value: Variant, output: Dictionary) -> void:
	if not condition_value is Dictionary:
		return
	var condition: Dictionary = condition_value
	for child in condition.get("conditions", []):
		_collect_numeric_targets(child, output)
	var operator := String(condition.get("operator", ""))
	if ["gte", "lte"].has(operator) and condition.get("value") is int or condition.get("value") is float:
		output["%s|%s" % [String(condition.get("field", "")), operator]] = condition.get("value")


static func _environment_ids(game_data: Dictionary) -> Dictionary:
	var result := {}
	var file := FileAccess.open("res://doc/showcase_round_rules.json", FileAccess.READ)
	if file == null:
		return result
	var rules_value: Variant = JSON.parse_string(file.get_as_text())
	if not rules_value is Dictionary:
		return result
	var environment_value: Variant = (rules_value as Dictionary).get("environment", {})
	if environment_value is Dictionary:
		for category in ["markets", "weather", "festivals", "waves"]:
			for entry_value in (environment_value as Dictionary).get(category, []):
				if entry_value is Dictionary:
					result[String((entry_value as Dictionary).get("id", ""))] = true
	return result


static func _normalize_value(value: Variant) -> Variant:
	if value is float and is_equal_approx(float(value), round(float(value))):
		return int(round(float(value)))
	if value is Array:
		var result: Array = []
		for item: Variant in value:
			result.append(_normalize_value(item))
		return result
	if value is Dictionary:
		var result := {}
		for key_value: Variant in (value as Dictionary).keys():
			result[key_value] = _normalize_value((value as Dictionary).get(key_value))
		return result
	return value
