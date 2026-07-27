class_name StarProgressionService
extends RefCounted

const GAME_DATA_PATH := "res://game_data.json"
const Catalog = preload("res://scripts/catalog.gd")


static func get_config() -> Dictionary:
	var data := _load_game_data()
	return _sanitize_dictionary(data.get("automation", {}))


static func feature_gate(feature_id: String) -> Dictionary:
	var unlocks: Dictionary = get_config().get("feature_unlocks", {})
	return _sanitize_dictionary(unlocks.get(feature_id, {}))


static func upgrade_definition(upgrade_id: String) -> Dictionary:
	var upgrades: Dictionary = get_config().get("upgrades", {})
	return _sanitize_dictionary(upgrades.get(upgrade_id, {}))


static func task_starlight_amount(task_id: String) -> int:
	var rewards: Dictionary = get_config().get("starlight_rewards", {})
	var tasks: Dictionary = rewards.get("tasks", {})
	return maxi(0, int(tasks.get(task_id, 0)))


static func resolved_automation_effects(state) -> Dictionary:
	var config := get_config()
	var resolved := _sanitize_dictionary(config.get("base_effects", {}))
	if state == null:
		return resolved
	var purchased: Dictionary = state.automation_upgrades if state.automation_upgrades is Dictionary else {}
	var upgrades: Dictionary = config.get("upgrades", {}) if config.get("upgrades", {}) is Dictionary else {}
	for upgrade_id_value: Variant in purchased.keys():
		if not bool(purchased.get(upgrade_id_value, false)):
			continue
		var upgrade_value: Variant = upgrades.get(String(upgrade_id_value), {})
		if not upgrade_value is Dictionary:
			continue
		var effect_value: Variant = (upgrade_value as Dictionary).get("effect", {})
		if not effect_value is Dictionary:
			continue
		for effect_id_value: Variant in (effect_value as Dictionary).keys():
			var effect_id := String(effect_id_value)
			var candidate: Variant = (effect_value as Dictionary).get(effect_id_value)
			if candidate is bool:
				resolved[effect_id] = bool(resolved.get(effect_id, false)) or bool(candidate)
			elif candidate is int or candidate is float:
				var current := int(resolved.get(effect_id, 0))
				var candidate_int := int(candidate)
				resolved[effect_id] = -1 if current == -1 or candidate_int == -1 else maxi(current, candidate_int)
	return resolved


static func automation_effect_int(state, effect_id: String, fallback: int = 0) -> int:
	return int(resolved_automation_effects(state).get(effect_id, fallback))


static func automation_effect_enabled(state, effect_id: String) -> bool:
	return bool(resolved_automation_effects(state).get(effect_id, false))


static func claimable_recipe_rewards(state, recipe_id: String = "") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if state == null:
		return result
	var rewards: Dictionary = get_config().get("starlight_rewards", {})
	var unlock_amount := maxi(0, int(rewards.get("recipe_unlock", 0)))
	var mastery_rewards: Dictionary = rewards.get("recipe_mastery", {})
	var recipe_ids: Array = state.unlocked_recipes.duplicate()
	for raw_id: Variant in recipe_ids:
		var id := String(raw_id)
		if not recipe_id.is_empty() and id != recipe_id:
			continue
		_append_if_unclaimed(result, state, "recipe_unlock:%s" % id, unlock_amount, id, "解锁配方")
		var mastery := int(state.get_recipe_growth(id).get("mastery_level", 0))
		for level in range(1, mastery + 1):
			_append_if_unclaimed(result, state, "recipe_mastery:%s:%d" % [id, level], int(mastery_rewards.get(str(level), 0)), id, "配方成长")
	if recipe_id.is_empty():
		var task_rewards: Dictionary = rewards.get("tasks", {})
		for task_id_value: Variant in state.completed_tasks:
			var task_id := String(task_id_value)
			_append_if_unclaimed(result, state, "task:%s" % task_id, int(task_rewards.get(task_id, 0)), "", "阶段与挑战")
		var total_recipes := maxi(1, Catalog.new().get_recipes().size())
		var unlocked_count: int = state.unlocked_recipes.size()
		var milestone_rewards: Dictionary = rewards.get("catalog_milestones", {})
		for percent_value in milestone_rewards.keys():
			var percent := int(percent_value)
			var target := int(ceil(float(total_recipes) * float(percent) / 100.0))
			if unlocked_count >= target:
				_append_if_unclaimed(result, state, "catalog_milestone:%d" % percent, int(milestone_rewards[percent_value]), "", "图鉴里程碑")
	return result


static func _append_if_unclaimed(
	result: Array[Dictionary],
	state,
	reward_key: String,
	amount: int,
	recipe_id: String,
	source: String
) -> void:
	if amount <= 0 or state.claimed_starlight_rewards.has(reward_key):
		return
	result.append(_reward_entry(reward_key, amount, recipe_id, source))


static func _reward_entry(reward_key: String, amount: int, recipe_id: String, source: String) -> Dictionary:
	return {
		"key": reward_key,
		"amount": amount,
		"recipe_id": recipe_id,
		"source": source
	}.duplicate(true)


static func _sanitize_dictionary(raw_value: Variant) -> Dictionary:
	return (raw_value as Dictionary).duplicate(true) if raw_value is Dictionary else {}


static func _load_game_data() -> Dictionary:
	if not FileAccess.file_exists(GAME_DATA_PATH):
		return {}
	var file := FileAccess.open(GAME_DATA_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return _sanitize_dictionary(parsed)
