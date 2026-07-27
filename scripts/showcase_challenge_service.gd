class_name ShowcaseChallengeService
extends RefCounted

const TaskConditionService = preload("res://scripts/task_condition_service.gd")


static func create_task_challenge(
	task: Dictionary,
	round_id: int,
	rules: Dictionary,
	unlock_context: Dictionary = {}
) -> Dictionary:
	if String(task.get("type", "")) != "contract":
		return {}
	var availability: Dictionary = task.get("availability", {})
	if int(unlock_context.get("level", int(task.get("level", 0)))) < int(availability.get("min_level", task.get("level", 0))):
		return {}
	var task_id := String(task.get("id", ""))
	var version := maxi(1, int(task.get("version", 1)))
	if task_id.is_empty():
		return {}
	var snapshot := task.duplicate(true)
	snapshot["id"] = task_id
	snapshot["task_id"] = task_id
	snapshot["round_id"] = maxi(1, round_id)
	snapshot["instance_id"] = "%s:v%d:r%d" % [task_id, version, maxi(1, round_id)]
	snapshot["environment"] = _resolve_environment(String(task.get("environment_id", "")), rules)
	snapshot["resolved_recipe_ids"] = (unlock_context.get("unlocked_recipe_ids", []) as Array).duplicate(true) if unlock_context.get("unlocked_recipe_ids", []) is Array else []
	snapshot["resolved_tags"] = (unlock_context.get("unlocked_tags", []) as Array).duplicate(true) if unlock_context.get("unlocked_tags", []) is Array else []
	snapshot["deposit"] = maxi(0, int(task.get("deposit", 0))) if String(task.get("risk", "normal")) == "high" else 0
	snapshot["task_reward"] = (task.get("reward", {}) as Dictionary).duplicate(true) if task.get("reward", {}) is Dictionary else {}
	return snapshot


static func generate_contract_choices(
	level: int,
	round_id: int,
	task_definitions: Array,
	rules: Dictionary,
	unlock_context: Dictionary = {},
	choice_count: int = 3
) -> Array[Dictionary]:
	var available: Array[Dictionary] = []
	var resolved_context := unlock_context.duplicate(true)
	resolved_context["level"] = level
	for task_value in task_definitions:
		if not task_value is Dictionary:
			continue
		var task: Dictionary = task_value
		var availability: Dictionary = task.get("availability", {})
		if level < int(availability.get("min_level", task.get("level", 0))):
			continue
		var snapshot := create_task_challenge(task, round_id, rules, resolved_context)
		if not snapshot.is_empty():
			available.append(snapshot)
	available.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return String(left.get("task_id", "")) < String(right.get("task_id", ""))
	)
	var result: Array[Dictionary] = []
	if available.is_empty():
		return result
	var start_index := posmod(round_id, available.size())
	for offset in range(mini(maxi(0, choice_count), available.size())):
		result.append(available[(start_index + offset) % available.size()].duplicate(true))
	return result


static func evaluate_business_challenge(snapshot: Dictionary, round_report: Dictionary) -> Dictionary:
	var tiers_value: Variant = snapshot.get("tiers", [])
	if tiers_value is Array and not (tiers_value as Array).is_empty():
		var evaluation := TaskConditionService.evaluate_tiers(round_report, tiers_value)
		var valid := bool(evaluation.get("valid", false))
		var highest_tier := String(evaluation.get("highest_tier", ""))
		var success := valid and not highest_tier.is_empty()
		return {
			"instance_id": String(snapshot.get("instance_id", "")),
			"challenge_id": String(snapshot.get("task_id", snapshot.get("id", ""))),
			"task_id": String(snapshot.get("task_id", snapshot.get("id", ""))),
			"version": int(snapshot.get("version", 1)),
			"round_id": int(snapshot.get("round_id", 0)),
			"report_id": String(round_report.get("report_id", "")),
			"status": "success" if success else "failed" if valid else "invalid",
			"valid": valid,
			"success": success,
			"highest_tier": highest_tier,
			"evaluation": evaluation,
			"reward_coins": 0,
			"deposit_returned": int(snapshot.get("deposit", 0)) if success else 0,
			"deposit_lost": int(snapshot.get("deposit", 0)) if valid and not success else 0,
			"normal_income_delta": 0
		}
	return {
		"instance_id": String(snapshot.get("instance_id", "")),
		"challenge_id": String(snapshot.get("task_id", snapshot.get("id", ""))),
		"task_id": String(snapshot.get("task_id", snapshot.get("id", ""))),
		"version": int(snapshot.get("version", 1)),
		"round_id": int(snapshot.get("round_id", 0)),
		"report_id": String(round_report.get("report_id", "")),
		"status": "invalid",
		"valid": false,
		"success": false,
		"highest_tier": "",
		"evaluation": {"valid": false, "reason": "挑战快照缺少评级定义"},
		"reward_coins": 0,
		"deposit_returned": 0,
		"deposit_lost": 0,
		"normal_income_delta": 0
	}


static func _resolve_environment(environment_id: String, rules: Dictionary) -> Dictionary:
	var environment_value: Variant = rules.get("environment", {})
	if not environment_value is Dictionary:
		return {"id": environment_id}
	for category in ["markets", "weather", "festivals", "waves"]:
		for entry_value in (environment_value as Dictionary).get(category, []):
			if not entry_value is Dictionary or String((entry_value as Dictionary).get("id", "")) != environment_id:
				continue
			var entry: Dictionary = (entry_value as Dictionary).duplicate(true)
			entry["total_price_pct"] = float(entry.get("price_pct", 0.0))
			entry["total_speed_pct"] = float(entry.get("speed_pct", 0.0))
			return entry
	return {"id": environment_id, "label": environment_id, "total_price_pct": 0.0, "total_speed_pct": 0.0}
