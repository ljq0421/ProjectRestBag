class_name TaskService
extends RefCounted

const GAME_DATA_PATH := "res://game_data.json"
const Catalog = preload("res://scripts/catalog.gd")
const StarProgressionService = preload("res://scripts/star_progression_service.gd")
const TaskCatalogService = preload("res://scripts/task_catalog_service.gd")
const TaskConditionService = preload("res://scripts/task_condition_service.gd")

static var _task_definitions_cache: Dictionary = {}
static var _event_task_ids_cache: Dictionary = {}
static var _progression_task_ids_cache: Array[String] = []
static var _feature_task_ids_cache: Array[String] = []
static var _route_task_ids_cached := false


static func get_unlock_route_summary() -> Array:
	var data := _load_game_data()
	var raw_route: Variant = data.get("unlock_route", [])
	var route: Array = []
	if not raw_route is Array:
		return route

	for raw_entry: Variant in raw_route:
		if not raw_entry is Dictionary:
			continue
		var entry: Dictionary = raw_entry
		route.append({
			"level": int(entry.get("level", 0)),
			"core": String(entry.get("core", "")),
			"new_origins": _sanitize_string_array(entry.get("new_origins", [])),
			"new_equipment": _sanitize_string_array(entry.get("new_equipment", [])),
			"new_ingredients": _sanitize_string_array(entry.get("new_ingredients", [])),
			"new_functions": _sanitize_string_array(entry.get("new_functions", [])),
			"upgrade_condition": _sanitize_string_array(entry.get("upgrade_condition", []))
		})
	return route


static func get_task_definitions() -> Dictionary:
	if not _task_definitions_cache.is_empty():
		return _task_definitions_cache
	var definitions := TaskCatalogService.definitions_by_id(TaskCatalogService.load_catalog())
	for task_id_value: Variant in definitions.keys():
		var task_value: Variant = definitions.get(task_id_value, {})
		if not task_value is Dictionary:
			continue
		var task: Dictionary = task_value
		task["events"] = _sanitize_string_array(task.get("events", []))
		definitions[task_id_value] = task
	_attach_task_starlight_rewards(definitions)
	_task_definitions_cache = definitions
	return _task_definitions_cache


static func clear_task_caches() -> void:
	_task_definitions_cache.clear()
	_event_task_ids_cache.clear()
	_progression_task_ids_cache.clear()
	_feature_task_ids_cache.clear()
	_route_task_ids_cached = false


static func build_event_index(definitions: Dictionary) -> Dictionary:
	var index: Dictionary = {}
	for task_id in _sorted_task_ids(definitions):
		var task_value: Variant = definitions.get(task_id, {})
		if not task_value is Dictionary:
			continue
		for event_name in _definition_event_names(task_value as Dictionary):
			var task_ids: Array = index.get(event_name, [])
			if not task_ids.has(task_id):
				task_ids.append(task_id)
			index[event_name] = task_ids
	return index


static func task_ids_for_event(event_name: String) -> Array:
	if event_name.is_empty():
		return []
	if _event_task_ids_cache.is_empty():
		_event_task_ids_cache = build_event_index(get_task_definitions())
	var task_ids_value: Variant = _event_task_ids_cache.get(event_name, [])
	return (task_ids_value as Array).duplicate() if task_ids_value is Array else []


static func _definition_event_names(definition: Dictionary) -> Array[String]:
	var event_names: Array[String] = []
	var single_event := String(definition.get("event", ""))
	if not single_event.is_empty():
		event_names.append(single_event)
	for event_name in _sanitize_string_array(definition.get("events", [])):
		if not event_name.is_empty() and not event_names.has(event_name):
			event_names.append(event_name)
	var objectives_value: Variant = definition.get("objectives", [])
	if objectives_value is Array:
		for objective_value: Variant in objectives_value:
			if not objective_value is Dictionary:
				continue
			for event_name in _definition_event_names(objective_value as Dictionary):
				if not event_names.has(event_name):
					event_names.append(event_name)
	return event_names


static func ensure_daily_tasks_current(state, day_key: String = "") -> void:
	if state == null:
		return
	var actual_day_key := day_key.strip_edges()
	if actual_day_key.is_empty():
		actual_day_key = Time.get_date_string_from_system(false)
	if String(state.daily_task_day_key) == actual_day_key and not state.daily_task_selected_ids.is_empty():
		return
	var daily_ids := TaskCatalogService.task_ids_with_reset_policy(TaskCatalogService.load_catalog(), "daily")
	if String(state.daily_task_day_key) != actual_day_key:
		for daily_id in daily_ids:
			state.completed_tasks.erase(daily_id)
			state.claimed_tasks.erase(daily_id)
			state.task_progress.erase(daily_id)
	state.daily_task_day_key = actual_day_key
	state.daily_task_selected_ids = _select_daily_task_ids(state, actual_day_key)
	state.add_log("daily_tasks_sync:%s" % actual_day_key)


static func _attach_task_starlight_rewards(definitions: Dictionary) -> void:
	for key_value: Variant in definitions.keys():
		var key := String(key_value)
		var task_value: Variant = definitions.get(key_value, {})
		if not task_value is Dictionary:
			continue
		var task: Dictionary = task_value
		var task_id := String(task.get("id", key))
		var amount := StarProgressionService.task_starlight_amount(task_id)
		if amount <= 0:
			continue
		var reward_value: Variant = task.get("reward", {})
		var reward: Dictionary = reward_value.duplicate(true) if reward_value is Dictionary else {}
		reward["starlight"] = amount
		task["reward"] = reward
		definitions[key_value] = task


static func apply_event(state, event_name: String, payload: Dictionary) -> Array:
	var completed: Array = []
	if state == null or event_name.is_empty() or not _task_system_open(state):
		return completed
	ensure_daily_tasks_current(state)

	var definitions := get_task_definitions()
	var task_ids := task_ids_for_event(event_name)
	var progression_ids: Array[String] = []
	var progression_resolved := false
	for task_id in task_ids:
		var task: Dictionary = definitions[task_id]
		var task_type := String(task.get("type", ""))
		var processable := false
		match task_type:
			"tutorial", "growth":
				if not progression_resolved:
					progression_ids = available_progression_task_ids(state, definitions)
					progression_resolved = true
				processable = progression_ids.has(task_id)
			"daily":
				processable = state.daily_task_selected_ids.has(task_id)
			"feature":
				# Feature candidates are already narrowed by the event index.
				processable = true
			"contract":
				var pending_value: Variant = state.pending_showcase_challenge
				if pending_value is Dictionary and not (pending_value as Dictionary).is_empty():
					processable = task_id == String((pending_value as Dictionary).get("task_id", (pending_value as Dictionary).get("id", "")))
		if not processable:
			continue
		if state.is_task_completed(task_id):
			continue
		if not _is_task_available(state, task):
			continue
		if not _task_accepts_event(task, event_name):
			continue

		var progress := _progress_for_task(state, task_id)
		var objectives_value: Variant = task.get("objectives", [])
		var has_objectives := objectives_value is Array and not (objectives_value as Array).is_empty()
		var goal: int = (objectives_value as Array).size() if has_objectives else maxi(1, int(task.get("goal", 1)))
		var updated_progress := _event_progress_for_objectives(state, task, event_name, payload, progress) if has_objectives else _event_progress_for_task(state, task, event_name, payload, progress, goal)
		if updated_progress.is_empty():
			continue
		progress = updated_progress
		state.task_progress[task_id] = progress

		if int(progress.get("count", 0)) >= goal:
			_complete_task(state, task)
			completed.append(task_id)

	return completed


static func evaluate_business_task(task: Dictionary, report: Dictionary, history: Array = []) -> Dictionary:
	var tiers_value: Variant = task.get("tiers", [])
	if tiers_value is Array and not (tiers_value as Array).is_empty():
		return TaskConditionService.evaluate_tiers(report, tiers_value, history)
	var condition_value: Variant = task.get("condition", {})
	if not condition_value is Dictionary:
		return {"valid": false, "passed": false, "reason": "任务缺少营业报告条件"}
	var condition: Dictionary = (condition_value as Dictionary).duplicate(true)
	condition.erase("kind")
	return TaskConditionService.evaluate_condition(report, condition, history)


static func get_visible_tasks(state) -> Array:
	var visible: Array = []
	if state == null or not _task_system_open(state):
		return visible
	ensure_daily_tasks_current(state)
	visible.append_array(get_current_goal_tasks(state))
	visible.append_array(get_side_tasks(state))
	return visible


static func get_current_goal_tasks(state) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if state == null or not _task_system_open(state):
		return entries
	ensure_daily_tasks_current(state)
	var definitions := get_task_definitions()
	for progression_id in available_progression_task_ids(state, definitions):
		entries.append(_active_entry(definitions[progression_id], state))
	var upgrade_task := build_shop_upgrade_task(state)
	if not upgrade_task.is_empty():
		entries.append(upgrade_task)
	var pending_value: Variant = state.pending_showcase_challenge
	if pending_value is Dictionary and not (pending_value as Dictionary).is_empty():
		var pending: Dictionary = pending_value
		var task_id := String(pending.get("task_id", pending.get("id", "")))
		if definitions.has(task_id) and not state.is_task_completed(task_id):
			entries.append(_active_entry(definitions[task_id], state))
	return entries


static func build_shop_upgrade_task(state) -> Dictionary:
	if state == null or int(state.level) < 1 or not state.has_method("upgrade_eligibility"):
		return {}
	var eligibility: Dictionary = state.upgrade_eligibility()
	if String(eligibility.get("reason", "")) == "definition_missing":
		return {}
	var target_level := int(eligibility.get("target_level", int(state.level) + 1))
	var cost := maxi(0, int(eligibility.get("cost", 0)))
	var required_reputation := maxi(0, int(eligibility.get("required_reputation", 0)))
	var coin_count := mini(maxi(0, int(state.coins)), cost)
	var reputation_count := mini(maxi(0, int(state.reputation)), required_reputation)
	var coins_complete := int(eligibility.get("missing_coins", 0)) <= 0
	var reputation_complete := int(eligibility.get("missing_reputation", 0)) <= 0
	var completed_count := int(coins_complete) + int(reputation_complete)
	var device_id := String(eligibility.get("device_id", ""))
	var effect_text := "开放 Lv.%d 经营内容" % target_level
	if not device_id.is_empty():
		var device: Dictionary = Catalog.new().get_devices().get(device_id, {})
		effect_text = "解锁新设备：%s" % String(device.get("name", device_id))
	var progress := {
		"count": completed_count,
		"goal": 2,
		"objectives": {
			"upgrade_coins": {"count": coin_count, "completed": coins_complete},
			"cumulative_reputation": {"count": reputation_count, "completed": reputation_complete}
		}
	}
	var progress_detail := "升级资金 %d/%d｜累计口碑 %d/%d" % [coin_count, cost, reputation_count, required_reputation]
	return {
		"id": "shop_upgrade_%d" % target_level,
		"type": "upgrade",
		"level": int(state.level),
		"title": "店铺升级｜升至 Lv.%d" % target_level,
		"description": "准备升级资金并达到累计口碑要求。升级会扣除金币，口碑不会扣除。",
		"source_stage": "店铺成长",
		"status": "active",
		"action_kind": "shop_upgrade",
		"target_level": target_level,
		"cost": cost,
		"required_reputation": required_reputation,
		"effect_text": effect_text,
		"can_upgrade": bool(eligibility.get("ok", false)),
		"missing_coins": maxi(0, int(eligibility.get("missing_coins", 0))),
		"missing_reputation": maxi(0, int(eligibility.get("missing_reputation", 0))),
		"progress": progress,
		"progress_text": progress_detail,
		"progress_detail": progress_detail,
		"goal": 2,
		"objectives": [
			{"id": "upgrade_coins", "title": "升级资金", "goal": maxi(1, cost)},
			{"id": "cumulative_reputation", "title": "累计口碑", "goal": maxi(1, required_reputation)}
		],
		"reward": {}
	}


static func get_side_tasks(state) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if state == null or not _task_system_open(state):
		return entries
	ensure_daily_tasks_current(state)
	var definitions := get_task_definitions()
	for task_id in state.daily_task_selected_ids:
		if not definitions.has(task_id) or state.is_task_completed(task_id):
			continue
		var task: Dictionary = definitions[task_id]
		if _is_task_available(state, task):
			entries.append(_active_entry(task, state))
	for feature_id in _available_feature_task_ids(state, definitions):
		entries.append(_active_entry(definitions[feature_id], state))
	return entries


static func get_completed_tasks(state) -> Array:
	var completed: Array = []
	if state == null or not _task_system_open(state):
		return completed
	ensure_daily_tasks_current(state)

	var definitions := get_task_definitions()
	var completed_ids: Array = state.completed_tasks.duplicate()
	for task_id_value: Variant in completed_ids:
		var task_id := String(task_id_value)
		var task: Dictionary = definitions.get(task_id, {
			"id": task_id,
			"title": task_id,
			"type": "unknown",
			"level": 0,
			"source_stage": "其他"
		})
		var entry := task.duplicate(true)
		entry["status"] = "completed"
		var claimable_reward := format_claimable_reward(task.get("reward", {}))
		entry["claim_status"] = "claimed" if state.is_task_reward_claimed(task_id) or claimable_reward.is_empty() else "claimable"
		entry["progress"] = _progress_for_task(state, task_id)
		entry["progress_detail"] = format_task_progress_detail(task, entry["progress"])
		completed.append(entry)
	return completed


static func get_claimable_tasks(state) -> Array:
	var claimable: Array = []
	for task_value: Variant in get_completed_tasks(state):
		if not task_value is Dictionary:
			continue
		var task: Dictionary = task_value
		if String(task.get("claim_status", "")) == "claimable":
			claimable.append(task)
	return claimable


static func build_task_snapshot(state, contract_choices: Array = []) -> Dictionary:
	var active_current_entries: Array = get_current_goal_tasks(state)
	var progression_complete := _progression_route_complete(state)
	if state != null and int(state.level) >= 6 and progression_complete and state.pending_showcase_challenge.is_empty():
		for choice_value: Variant in contract_choices:
			if choice_value is Dictionary:
				var choice: Dictionary = (choice_value as Dictionary).duplicate(true)
				choice["status"] = "candidate"
				choice["type"] = "contract"
				choice["id"] = String(choice.get("task_id", choice.get("id", "")))
				active_current_entries.append(choice)
	var active_side_entries: Array = get_side_tasks(state)
	var claimable := get_claimable_tasks(state)
	var claimable_current: Array = []
	var claimable_side: Array = []
	for index in range(claimable.size() - 1, -1, -1):
		var task_value: Variant = claimable[index]
		if not task_value is Dictionary:
			continue
		var task: Dictionary = task_value
		match String(task.get("type", "")):
			"tutorial", "growth", "contract":
				claimable_current.append(task)
			"daily", "feature":
				claimable_side.append(task)
	var current_entries := _merge_task_entries(claimable_current, active_current_entries)
	var side_entries := _merge_task_entries(claimable_side, active_side_entries)
	var current_empty_text := "当前成长目标已完成，继续经营或提升店铺等级。"
	if state != null and int(state.level) >= 6 and progression_complete and state.pending_showcase_challenge.is_empty() and current_entries.is_empty():
		current_empty_text = "请选择一个经营合同作为本轮目标。"
	return {
		"active": active_current_entries + active_side_entries,
		"current_entries": current_entries,
		"side_entries": side_entries,
		"current_slot_count": active_current_entries.size(),
		"side_slot_count": active_side_entries.size(),
		"current_empty_text": current_empty_text,
		"side_empty_text": "今日支线已全部完成。",
		"completed": get_completed_tasks(state),
		"claimable": claimable,
		"pending_notifications": state.pending_notifications.duplicate(true) if state != null else []
	}


static func _merge_task_entries(first: Array, second: Array) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var seen_ids := {}
	for source in [first, second]:
		for task_value: Variant in source:
			if not task_value is Dictionary:
				continue
			var task: Dictionary = task_value
			var task_id := String(task.get("id", ""))
			if task_id.is_empty() or seen_ids.has(task_id):
				continue
			seen_ids[task_id] = true
			entries.append(task)
	return entries


static func format_task_panel(state) -> String:
	var lines: Array[String] = ["任务"]
	var snapshot := build_task_snapshot(state)

	lines.append("进行中")
	var active: Array = snapshot.get("active", [])
	if active.is_empty():
		lines.append("- 暂无")
	else:
		var shown := 0
		for raw_task: Variant in active:
			if shown >= 5:
				break
			if not raw_task is Dictionary:
				continue
			var task: Dictionary = raw_task
			lines.append("- Lv.%d %s：%s %s" % [
				int(task.get("level", 0)),
				String(task.get("title", task.get("id", ""))),
				String(task.get("progress_text", "")),
				_progress_suffix(task.get("progress", {}), int(task.get("goal", 1)))
			])
			shown += 1

	lines.append("可领取")
	var claimable: Array = snapshot.get("claimable", [])
	if claimable.is_empty():
		lines.append("- 暂无")
	else:
		for task_value: Variant in claimable:
			if not task_value is Dictionary:
				continue
			var task: Dictionary = task_value
			lines.append("- %s：%s" % [
				String(task.get("title", task.get("id", ""))),
				format_claimable_reward(task.get("reward", {}))
			])

	lines.append("已完成")
	var completed: Array = snapshot.get("completed", [])
	if completed.is_empty():
		lines.append("- 暂无")
	else:
		var start_index := maxi(0, completed.size() - 6)
		for index in range(start_index, completed.size()):
			var task_value: Variant = completed[index]
			if not task_value is Dictionary:
				continue
			var task: Dictionary = task_value
			lines.append("- %s" % String(task.get("title", task.get("id", ""))))

	var notifications: Array = snapshot.get("pending_notifications", [])
	if notifications.is_empty():
		lines.append("待领取提示：暂无")
	else:
		lines.append("待领取提示：%d 条" % notifications.size())
	return "\n".join(lines)


static func _complete_task(state, task: Dictionary) -> void:
	var task_id := String(task.get("id", ""))
	if task_id.is_empty():
		return
	if not state.complete_task(task_id):
		return

	var reward_value: Variant = task.get("reward", {})
	var previous_level := int(state.level)
	_apply_progression_effects(state, reward_value)
	if int(state.level) > previous_level:
		_enqueue_level_up_notification(state, int(state.level))

	var claimable_text := format_claimable_reward(reward_value)
	if claimable_text.is_empty() and not state.is_task_reward_claimed(task_id):
		state.claimed_tasks.append(task_id)

	var body_parts: Array[String] = []
	var notification_body := String(task.get("notification_body", ""))
	if not notification_body.is_empty():
		body_parts.append(notification_body)
	var progression_text := format_progression_effects(reward_value)
	if not progression_text.is_empty():
		body_parts.append("已生效：%s" % progression_text)
	if not claimable_text.is_empty():
		body_parts.append("奖励待领取：%s" % claimable_text)
	state.enqueue_notification(String(task.get("notification_title", "任务完成")), "\n".join(body_parts))


static func claim_task_reward(state, task_id: String, enqueue_notification := true) -> bool:
	if state == null or task_id.is_empty() or not _task_system_open(state):
		return false
	ensure_daily_tasks_current(state)
	if not state.is_task_completed(task_id):
		return false
	if state.is_task_reward_claimed(task_id):
		return false
	var definitions := get_task_definitions()
	if not definitions.has(task_id):
		return false

	var task: Dictionary = definitions[task_id]
	var reward_value: Variant = task.get("reward", {})
	var reward_text := format_claimable_reward(reward_value)
	if reward_text.is_empty():
		return false
	_apply_claimable_reward(state, reward_value)
	state.claimed_tasks.append(task_id)
	state.add_log("task_reward_claim:%s" % task_id)
	if enqueue_notification:
		var title := "领取任务奖励：%s" % String(task.get("title", task_id))
		state.enqueue_notification(title, reward_text)
	return true


static func _task_system_open(state) -> bool:
	if state == null:
		return false
	if state.has_method("is_core_feature_unlocked"):
		return bool(state.is_core_feature_unlocked("task"))
	return true


static func _apply_progression_effects(state, reward_value: Variant) -> void:
	if not reward_value is Dictionary:
		return
	var reward: Dictionary = reward_value
	for tool_id in _sanitize_string_array(reward.get("unlock_tools", [])):
		state.unlock_tool(tool_id)
	for device_id in _sanitize_string_array(reward.get("unlock_devices", [])):
		state.unlock_device(device_id)
	for feature_id in _sanitize_string_array(reward.get("unlock_automation", [])):
		state.unlock_automation(feature_id)
	for feature_id in _sanitize_string_array(reward.get("unlock_features", [])):
		state.unlock_feature(feature_id)


static func _apply_claimable_reward(state, reward_value: Variant) -> void:
	if not reward_value is Dictionary:
		return
	var reward: Dictionary = reward_value
	state.coins = maxi(0, int(state.coins) + maxi(0, int(reward.get("coins", 0))))
	state.reputation = maxi(0, int(state.reputation) + maxi(0, int(reward.get("reputation", 0))))
	if reward.has("set_level"):
		var target_level := int(reward.get("set_level", state.level))
		if target_level > int(state.level):
			state.level = target_level

	var tool_rewards: Variant = reward.get("tools", {})
	if tool_rewards is Dictionary:
		for tool_id: Variant in (tool_rewards as Dictionary).keys():
			var amount := int((tool_rewards as Dictionary)[tool_id])
			if amount > 0:
				state.add_tool(String(tool_id), amount)

	var ingredient_rewards: Variant = reward.get("ingredients", {})
	if ingredient_rewards is Dictionary:
		for item_id: Variant in (ingredient_rewards as Dictionary).keys():
			var amount := int((ingredient_rewards as Dictionary)[item_id])
			if amount > 0:
				state.add_ingredient(String(item_id), amount)


static func format_claimable_reward(reward_value: Variant) -> String:
	if not reward_value is Dictionary:
		return ""
	var reward: Dictionary = reward_value
	var parts: Array[String] = []
	if reward.has("set_level"):
		parts.append("店铺等级提升至 Lv.%d" % int(reward.get("set_level", 0)))
	if int(reward.get("starlight", 0)) > 0:
		parts.append("食谱星辉 +%d" % int(reward.get("starlight", 0)))
	if int(reward.get("coins", 0)) > 0:
		parts.append("金币 +%d" % int(reward.get("coins", 0)))
	if int(reward.get("reputation", 0)) > 0:
		parts.append("口碑 +%d" % int(reward.get("reputation", 0)))
	var tool_rewards: Variant = reward.get("tools", {})
	if tool_rewards is Dictionary:
		for tool_id: Variant in (tool_rewards as Dictionary).keys():
			var amount := int((tool_rewards as Dictionary)[tool_id])
			if amount > 0:
				parts.append("%s x%d" % [_tool_name(String(tool_id)), amount])
	var ingredient_rewards: Variant = reward.get("ingredients", {})
	if ingredient_rewards is Dictionary:
		var ingredients := Catalog.new().get_ingredients()
		for item_id: Variant in (ingredient_rewards as Dictionary).keys():
			var item: Dictionary = ingredients.get(String(item_id), {})
			var amount := int((ingredient_rewards as Dictionary)[item_id])
			if amount > 0:
				parts.append("%s x%d" % [String(item.get("name", item_id)), amount])
	return "、".join(parts)


static func format_task_progress_detail(task: Dictionary, progress: Dictionary) -> String:
	var objectives_value: Variant = task.get("objectives", [])
	if objectives_value is Array and not (objectives_value as Array).is_empty():
		return "已完成 %d/%d 项" % [
			maxi(0, int(progress.get("count", 0))),
			(objectives_value as Array).size()
		]
	var condition: Dictionary = task.get("condition", {})
	match String(condition.get("kind", "")):
		"output_automation_practice":
			return "手动收获 %d/%d 批｜产地 %d/%d 类｜下一轮 %d/%d 次" % [
				maxi(0, int(progress.get("harvest_count", 0))),
				maxi(0, int(condition.get("harvest_count", 0))),
				_sanitize_string_array(progress.get("harvest_site_ids", [])).size(),
				maxi(0, int(condition.get("site_count", 0))),
				maxi(0, int(progress.get("next_set_count", 0))),
				maxi(0, int(condition.get("next_set_count", 0)))
			]
		"kitchen_automation_practice":
			return "批量制作 %d/%d 次｜设备 %d/%d 类（每次至少 %d 批）" % [
				maxi(0, int(progress.get("completion_count", 0))),
				maxi(0, int(condition.get("completion_count", 0))),
				_sanitize_string_array(progress.get("device_ids", [])).size(),
				maxi(0, int(condition.get("device_count", 0))),
				maxi(1, int(condition.get("min_batches", 1)))
			]
	return ""


static func task_objective_entries(task: Dictionary, progress: Dictionary) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var objectives_value: Variant = task.get("objectives", [])
	if not objectives_value is Array:
		return entries
	var saved_value: Variant = progress.get("objectives", {})
	var saved: Dictionary = saved_value if saved_value is Dictionary else {}
	for objective_value: Variant in objectives_value:
		if not objective_value is Dictionary:
			continue
		var objective: Dictionary = objective_value
		var objective_id := String(objective.get("id", ""))
		var objective_progress_value: Variant = saved.get(objective_id, {})
		var objective_progress: Dictionary = objective_progress_value if objective_progress_value is Dictionary else {}
		entries.append({
			"id": objective_id,
			"title": String(objective.get("title", objective_id)),
			"count": maxi(0, int(objective_progress.get("count", 0))),
			"goal": maxi(1, int(objective.get("goal", 1))),
			"completed": bool(objective_progress.get("completed", false))
		})
	return entries


static func format_progression_effects(reward_value: Variant) -> String:
	if not reward_value is Dictionary:
		return ""
	var reward: Dictionary = reward_value
	var parts: Array[String] = []
	for device_id in _sanitize_string_array(reward.get("unlock_devices", [])):
		parts.append("解锁 %s" % _device_name(device_id))
	for tool_id in _sanitize_string_array(reward.get("unlock_tools", [])):
		parts.append("解锁 %s" % _tool_name(tool_id))
	for feature_id in _sanitize_string_array(reward.get("unlock_automation", [])):
		parts.append("解锁 %s" % _automation_feature_name(feature_id))
	for feature_id in _sanitize_string_array(reward.get("unlock_features", [])):
		parts.append("解锁 %s" % _feature_name(feature_id))
	return "、".join(parts)


static func _feature_name(feature_id: String) -> String:
	match feature_id:
		"harvest_all": return "一键收获"
		"research_bulk_restock": return "一键补货"
		"research_make_all": return "制作全部"
		"research_list_all": return "上架全部"
		_: return feature_id


static func _device_name(device_id: String) -> String:
	var device: Dictionary = Catalog.new().get_devices().get(device_id, {})
	return String(device.get("name", device_id))


static func _tool_name(tool_id: String) -> String:
	var tool: Dictionary = Catalog.new().get_tools().get(tool_id, {})
	return String(tool.get("name", tool_id))


static func _automation_feature_name(feature_id: String) -> String:
	match feature_id:
		"output":
			return "产地管家"
		"kitchen":
			return "厨房排程台"
	return feature_id


static func _enqueue_level_up_notification(state, level: int) -> void:
	if state == null or level <= 0:
		return
	var upgrade: Dictionary = Catalog.new().get_upgrade_definition(level)
	var level_name := String(upgrade.get("name", ""))
	var unlocks_value: Variant = upgrade.get("unlocks", [])
	var unlocks: Array[String] = _sanitize_string_array(unlocks_value)
	var title := "店铺升级 Lv.%d" % level
	if not level_name.is_empty():
		title = "店铺升级 Lv.%d：%s" % [level, level_name]
	var body := "新的食材、设备和顾客偏好已开放。"
	if not unlocks.is_empty():
		body = "新增解锁：%s。" % "、".join(unlocks.slice(0, mini(6, unlocks.size())))
	state.enqueue_notification(title, body)


static func _event_progress_for_task(state, task: Dictionary, event_name: String, payload: Dictionary, progress: Dictionary, goal: int) -> Dictionary:
	var condition: Dictionary = task.get("condition", {})
	var tiers_value: Variant = task.get("tiers", [])
	if event_name == "business_round_completed" and (
		String(condition.get("kind", "")) == "round_report"
		or tiers_value is Array and not (tiers_value as Array).is_empty()
	):
		if String(task.get("type", "")) == "contract" and String(payload.get("challenge_id", "")) != String(task.get("id", "")):
			return {}
		var history_value: Variant = progress.get("round_history", [])
		var history: Array = history_value if history_value is Array else []
		var evaluation := evaluate_business_task(task, payload, history)
		if not bool(evaluation.get("valid", false)):
			return {}
		var report_progress := progress.duplicate(true)
		report_progress["goal"] = goal
		report_progress["title"] = String(task.get("title", task.get("id", "")))
		report_progress["evaluation"] = evaluation.duplicate(true)
		var next_history: Array = [payload.duplicate(true)]
		next_history.append_array(history)
		if next_history.size() > 10:
			next_history.resize(10)
		report_progress["round_history"] = next_history
		var passed := bool(evaluation.get("passed", false))
		if tiers_value is Array and not (tiers_value as Array).is_empty():
			var required_tier := String(task.get("required_tier", String(((tiers_value as Array)[0] as Dictionary).get("id", ""))))
			var highest_tier := String(evaluation.get("highest_tier", ""))
			report_progress["best_tier"] = highest_tier
			passed = _tier_index(tiers_value, highest_tier) >= _tier_index(tiers_value, required_tier)
		report_progress["count"] = goal if passed else 0
		return report_progress
	if not _base_condition_matches(condition, payload):
		return {}
	match String(condition.get("kind", "")):
		"output_automation_practice":
			return _output_automation_progress(task, event_name, payload, progress, goal)
		"kitchen_automation_practice":
			return _kitchen_automation_progress(task, event_name, payload, progress, goal)

	var updated := progress.duplicate(true)
	updated["goal"] = goal
	updated["title"] = String(task.get("title", task.get("id", "")))
	if String(condition.get("kind", "")) == "event_count" and event_name in ["harvest", "manual_harvest"]:
		var harvest_batch_id := String(payload.get("harvest_batch_id", ""))
		if not harvest_batch_id.is_empty():
			var harvest_batch_ids := _sanitize_string_array(progress.get("harvest_batch_ids", []))
			var legacy_last_batch_id := String(progress.get("last_harvest_batch_id", ""))
			if not legacy_last_batch_id.is_empty() and not harvest_batch_ids.has(legacy_last_batch_id):
				harvest_batch_ids.append(legacy_last_batch_id)
			if harvest_batch_ids.has(harvest_batch_id):
				return {}
			harvest_batch_ids.append(harvest_batch_id)
			while harvest_batch_ids.size() > goal:
				harvest_batch_ids.pop_front()
			updated["harvest_batch_ids"] = harvest_batch_ids
			updated["last_harvest_batch_id"] = harvest_batch_id

	if condition.has("min_coins") or condition.has("min_reputation"):
		if int(state.coins) < int(condition.get("min_coins", 0)):
			return {}
		if int(state.reputation) < int(condition.get("min_reputation", 0)):
			return {}
		updated["count"] = goal
		return updated

	if condition.has("consecutive_runs"):
		var min_sold := int(condition.get("min_sold_count", 1))
		var current_count := maxi(0, int(progress.get("count", 0)))
		if int(payload.get("sold_count", 0)) >= min_sold:
			updated["count"] = mini(goal, current_count + 1)
			return updated
		if current_count > 0:
			updated["count"] = 0
			return updated
		return {}

	if condition.has("customer_ids"):
		return _progress_unique_sales_dimension(task, payload, progress, goal, "customer_id", "customer_ids", "matched_customer_ids")

	if condition.has("device_ids"):
		return _progress_unique_sales_dimension(task, payload, progress, goal, "device_id", "device_ids", "matched_device_ids")

	if condition.has("item_ids"):
		return _progress_unique_event_dimension(task, payload, progress, goal, "item_id", "item_ids", "matched_item_ids")

	if condition.has("min_distinct_recipes"):
		if _business_distinct_recipe_count(payload) < int(condition.get("min_distinct_recipes", 1)):
			return {}
		updated["count"] = goal
		return updated

	var increment := _event_increment(task, payload)
	if increment <= 0:
		return {}

	var current_count := maxi(0, int(progress.get("count", 0)))
	updated["count"] = mini(goal, current_count + increment)
	return updated


static func _event_progress_for_objectives(state, task: Dictionary, event_name: String, payload: Dictionary, progress: Dictionary) -> Dictionary:
	var objectives_value: Variant = task.get("objectives", [])
	if not objectives_value is Array or (objectives_value as Array).is_empty():
		return {}
	var updated := progress.duplicate(true)
	var saved_value: Variant = updated.get("objectives", {})
	var saved: Dictionary = saved_value.duplicate(true) if saved_value is Dictionary else {}
	var changed := false
	for objective_value: Variant in objectives_value:
		if not objective_value is Dictionary:
			continue
		var objective: Dictionary = objective_value
		var objective_id := String(objective.get("id", ""))
		if objective_id.is_empty():
			continue
		var objective_progress_value: Variant = saved.get(objective_id, {})
		var objective_progress: Dictionary = objective_progress_value.duplicate(true) if objective_progress_value is Dictionary else {}
		if bool(objective_progress.get("completed", false)) or not _definition_accepts_event(objective, event_name):
			continue
		var objective_goal := maxi(1, int(objective.get("goal", 1)))
		var next_progress := _event_progress_for_task(state, objective, event_name, payload, objective_progress, objective_goal)
		if next_progress.is_empty():
			continue
		if int(next_progress.get("count", 0)) >= objective_goal:
			next_progress["completed"] = true
			if _apply_objective_effects(state, objective.get("effect", {})):
				var notification_value: Variant = objective.get("notification", {})
				if notification_value is Dictionary:
					var notification: Dictionary = notification_value
					var title := String(notification.get("title", "")).strip_edges()
					var body := String(notification.get("body", "")).strip_edges()
					if not title.is_empty() and not body.is_empty():
						state.enqueue_notification(title, body)
		saved[objective_id] = next_progress
		changed = true
	if not changed:
		return {}
	var completed_count := 0
	for objective_value: Variant in objectives_value:
		if not objective_value is Dictionary:
			continue
		var objective_id := String((objective_value as Dictionary).get("id", ""))
		var objective_progress_value: Variant = saved.get(objective_id, {})
		if objective_progress_value is Dictionary and bool((objective_progress_value as Dictionary).get("completed", false)):
			completed_count += 1
	updated["objectives"] = saved
	updated["count"] = completed_count
	updated["goal"] = (objectives_value as Array).size()
	updated["title"] = String(task.get("title", task.get("id", "")))
	return updated


static func _apply_objective_effects(state, effect_value: Variant) -> bool:
	if state == null or not effect_value is Dictionary:
		return false
	var effect: Dictionary = effect_value
	var changed := false
	for tool_id in _sanitize_string_array(effect.get("unlock_tools", [])):
		changed = state.unlock_tool(tool_id) or changed
	for device_id in _sanitize_string_array(effect.get("unlock_devices", [])):
		changed = state.unlock_device(device_id) or changed
	for feature_id in _sanitize_string_array(effect.get("unlock_automation", [])):
		changed = state.unlock_automation(feature_id) or changed
	return changed


static func _tier_index(tiers_value: Variant, tier_id: String) -> int:
	if not tiers_value is Array or tier_id.is_empty():
		return -1
	for index in range((tiers_value as Array).size()):
		var tier_value: Variant = (tiers_value as Array)[index]
		if tier_value is Dictionary and String((tier_value as Dictionary).get("id", "")) == tier_id:
			return index
	return -1


static func _output_automation_progress(task: Dictionary, event_name: String, payload: Dictionary, progress: Dictionary, goal: int) -> Dictionary:
	var updated := progress.duplicate(true)
	var harvest_site_ids := _sanitize_string_array(progress.get("harvest_site_ids", []))
	var harvest_count := maxi(0, int(progress.get("harvest_count", 0)))
	var next_set_count := maxi(0, int(progress.get("next_set_count", 0)))
	if event_name == "harvest":
		var harvest_batch_id := String(payload.get("harvest_batch_id", ""))
		if not harvest_batch_id.is_empty() and harvest_batch_id == String(progress.get("last_harvest_batch_id", "")):
			return {}
		var site_id := String(payload.get("site_id", ""))
		if site_id.is_empty():
			return {}
		harvest_count += 1
		if not harvest_site_ids.has(site_id):
			harvest_site_ids.append(site_id)
		if not harvest_batch_id.is_empty():
			updated["last_harvest_batch_id"] = harvest_batch_id
	elif event_name == "output_next_set":
		if String(payload.get("site_id", "")).is_empty() or String(payload.get("item_id", "")).is_empty():
			return {}
		next_set_count += 1
	else:
		return {}

	var condition: Dictionary = task.get("condition", {})
	updated["goal"] = goal
	updated["title"] = String(task.get("title", task.get("id", "")))
	updated["harvest_site_ids"] = harvest_site_ids
	updated["harvest_count"] = harvest_count
	updated["next_set_count"] = next_set_count
	updated["count"] = 1 if (
		harvest_count >= int(condition.get("harvest_count", 0))
		and harvest_site_ids.size() >= int(condition.get("site_count", 0))
		and next_set_count >= int(condition.get("next_set_count", 0))
	) else 0
	return updated


static func _kitchen_automation_progress(task: Dictionary, event_name: String, payload: Dictionary, progress: Dictionary, goal: int) -> Dictionary:
	if event_name != "recipe_queue_complete":
		return {}
	var condition: Dictionary = task.get("condition", {})
	if int(payload.get("batches", 0)) < int(condition.get("min_batches", 1)):
		return {}
	var device_id := String(payload.get("device_id", ""))
	if device_id.is_empty():
		return {}

	var updated := progress.duplicate(true)
	var device_ids := _sanitize_string_array(progress.get("device_ids", []))
	if not device_ids.has(device_id):
		device_ids.append(device_id)
	var completion_count := maxi(0, int(progress.get("completion_count", 0))) + 1
	updated["goal"] = goal
	updated["title"] = String(task.get("title", task.get("id", "")))
	updated["device_ids"] = device_ids
	updated["completion_count"] = completion_count
	updated["count"] = 1 if (
		completion_count >= int(condition.get("completion_count", 0))
		and device_ids.size() >= int(condition.get("device_count", 0))
	) else 0
	return updated


static func _base_condition_matches(condition: Dictionary, payload: Dictionary) -> bool:
	if condition.has("item_id") and String(payload.get("item_id", "")) != String(condition.get("item_id", "")):
		return false
	if condition.has("site_id") and String(payload.get("site_id", "")) != String(condition.get("site_id", "")):
		return false
	if condition.has("recipe_id") and String(payload.get("recipe_id", "")) != String(condition.get("recipe_id", "")):
		return false
	if condition.has("recipe_ids") and not _sanitize_string_array(condition.get("recipe_ids", [])).has(String(payload.get("recipe_id", ""))):
		return false
	if condition.has("device_id"):
		var has_sales := payload.has("sales") and payload.get("sales") is Array
		if not has_sales and String(payload.get("device_id", "")) != String(condition.get("device_id", "")):
			return false
	if condition.has("challenge_id") and String(payload.get("challenge_id", "")) != String(condition.get("challenge_id", "")):
		return false
	return true


static func _progress_unique_sales_dimension(
	task: Dictionary,
	payload: Dictionary,
	progress: Dictionary,
	goal: int,
	sale_field: String,
	condition_field: String,
	progress_field: String
) -> Dictionary:
	var required_ids := _sanitize_string_array((task.get("condition", {}) as Dictionary).get(condition_field, []))
	if required_ids.is_empty():
		return {}
	var matched_ids := _sanitize_string_array(progress.get(progress_field, []))
	var before_count := matched_ids.size()
	var recipes := Catalog.new().get_recipes()
	var sales_value: Variant = payload.get("sales", [])
	if not sales_value is Array:
		return {}

	for sale_value: Variant in sales_value:
		if not sale_value is Dictionary:
			continue
		var sale: Dictionary = sale_value
		var matched_id := ""
		if sale_field == "device_id":
			var recipe_id := String(sale.get("recipe_id", ""))
			matched_id = String(recipes.get(recipe_id, {}).get("device", ""))
		else:
			matched_id = String(sale.get(sale_field, ""))
		if required_ids.has(matched_id) and not matched_ids.has(matched_id):
			matched_ids.append(matched_id)

	if matched_ids.size() == before_count:
		return {}

	var updated := progress.duplicate(true)
	updated["goal"] = goal
	updated["title"] = String(task.get("title", task.get("id", "")))
	updated[progress_field] = matched_ids
	updated["count"] = mini(goal, matched_ids.size())
	return updated


static func _progress_unique_event_dimension(
	task: Dictionary,
	payload: Dictionary,
	progress: Dictionary,
	goal: int,
	payload_field: String,
	condition_field: String,
	progress_field: String
) -> Dictionary:
	var required_ids := _sanitize_string_array((task.get("condition", {}) as Dictionary).get(condition_field, []))
	var matched_id := String(payload.get(payload_field, ""))
	if required_ids.is_empty() or not required_ids.has(matched_id):
		return {}
	var matched_ids := _sanitize_string_array(progress.get(progress_field, []))
	if matched_ids.has(matched_id):
		return {}
	matched_ids.append(matched_id)
	var updated := progress.duplicate(true)
	updated["goal"] = goal
	updated["title"] = String(task.get("title", task.get("id", "")))
	updated[progress_field] = matched_ids
	updated["count"] = mini(goal, matched_ids.size())
	return updated


static func _event_increment(task: Dictionary, payload: Dictionary) -> int:
	var condition: Dictionary = task.get("condition", {})
	if condition.has("item_id") and String(payload.get("item_id", "")) != String(condition.get("item_id", "")):
		return 0
	if condition.has("site_id") and String(payload.get("site_id", "")) != String(condition.get("site_id", "")):
		return 0
	if condition.has("recipe_id") and String(payload.get("recipe_id", "")) != String(condition.get("recipe_id", "")):
		return 0
	if condition.has("recipe_ids") and not _sanitize_string_array(condition.get("recipe_ids", [])).has(String(payload.get("recipe_id", ""))):
		return 0
	if condition.has("device_id"):
		var has_sales := payload.has("sales") and payload.get("sales") is Array
		if not has_sales and String(payload.get("device_id", "")) != String(condition.get("device_id", "")):
			return 0
	if condition.has("challenge_id") and String(payload.get("challenge_id", "")) != String(condition.get("challenge_id", "")):
		return 0
	match String(condition.get("kind", "")):
		"event_count":
			return 1
		"order_count":
			var sales_value: Variant = payload.get("sales", [])
			return (sales_value as Array).size() if sales_value is Array else 0
	if condition.has("tag"):
		return _business_sales_count(payload, condition)
	if condition.has("customer_id") or condition.has("recipe_unlock_level") or (condition.has("device_id") and payload.has("sales")):
		return _business_sales_count(payload, condition)
	if String(task.get("event", "")) == "business_result":
		return maxi(0, int(payload.get("sold_count", 0)))
	if String(task.get("event", "")) == "showcase_sale":
		return maxi(0, int(payload.get("quantity", 0)))
	return maxi(1, int(payload.get("amount", payload.get("quantity", 1))))


static func _business_sales_count(payload: Dictionary, condition: Dictionary) -> int:
	var sales_value: Variant = payload.get("sales", [])
	if not sales_value is Array:
		return 0
	var recipes := Catalog.new().get_recipes()
	var count := 0
	for sale_value: Variant in sales_value:
		if not sale_value is Dictionary:
			continue
		var sale: Dictionary = sale_value
		if not _sale_matches_condition(sale, recipes, condition):
			continue
		count += maxi(1, int(sale.get("quantity", 1)))
	return count


static func _sale_matches_condition(sale: Dictionary, recipes: Dictionary, condition: Dictionary) -> bool:
	var recipe_id := String(sale.get("recipe_id", ""))
	var recipe: Dictionary = recipes.get(recipe_id, {})
	if condition.has("customer_id") and String(sale.get("customer_id", "")) != String(condition.get("customer_id", "")):
		return false
	if condition.has("tag") and not _sanitize_string_array(recipe.get("tags", [])).has(String(condition.get("tag", ""))):
		return false
	if condition.has("recipe_unlock_level") and int(recipe.get("unlock_level", -1)) != int(condition.get("recipe_unlock_level", -1)):
		return false
	if condition.has("device_id") and String(recipe.get("device", "")) != String(condition.get("device_id", "")):
		return false
	return true


static func _business_distinct_recipe_count(payload: Dictionary) -> int:
	var sales_value: Variant = payload.get("sales", [])
	if not sales_value is Array:
		return 0
	var recipe_ids: Array[String] = []
	for sale_value: Variant in sales_value:
		if not sale_value is Dictionary:
			continue
		var recipe_id := String((sale_value as Dictionary).get("recipe_id", ""))
		if not recipe_id.is_empty() and not recipe_ids.has(recipe_id):
			recipe_ids.append(recipe_id)
	return recipe_ids.size()


static func _business_tag_count(tag: String, payload: Dictionary) -> int:
	if tag.is_empty():
		return 0
	var sales_value: Variant = payload.get("sales", [])
	if not sales_value is Array:
		return 0
	var recipes := Catalog.new().get_recipes()
	var count := 0
	for sale_value: Variant in sales_value:
		if not sale_value is Dictionary:
			continue
		var sale: Dictionary = sale_value
		var recipe_id := String(sale.get("recipe_id", ""))
		var recipe: Dictionary = recipes.get(recipe_id, {})
		var tags := _sanitize_string_array(recipe.get("tags", []))
		if tags.has(tag):
			count += maxi(1, int(sale.get("quantity", 1)))
	return count


static func _select_daily_task_ids(state, day_key: String) -> Array[String]:
	var selected: Array[String] = []
	var definitions := get_task_definitions()
	var eligible: Array[String] = []
	for task_id in _sorted_task_ids(definitions):
		var task: Dictionary = definitions[task_id]
		if String(task.get("type", "")) == "daily" and _is_task_available(state, task):
			eligible.append(task_id)
	if eligible.is_empty():
		return selected
	var start := absi(day_key.hash()) % eligible.size()
	for offset in range(mini(2, eligible.size())):
		selected.append(eligible[(start + offset) % eligible.size()])
	return selected


static func _current_progression_task_id(state, definitions: Dictionary) -> String:
	var task_ids := available_progression_task_ids(state, definitions)
	return task_ids[0] if not task_ids.is_empty() else ""


static func available_progression_task_ids(state, definitions: Dictionary = {}) -> Array[String]:
	var available_ids: Array[String] = []
	if state == null:
		return available_ids
	var source_definitions := definitions if not definitions.is_empty() else get_task_definitions()
	for task_id in _sorted_task_ids(source_definitions):
		var task_value: Variant = source_definitions.get(task_id, {})
		if not task_value is Dictionary:
			continue
		var task: Dictionary = task_value
		if not ["tutorial", "growth"].has(String(task.get("type", ""))):
			continue
		if state.is_task_completed(task_id) or not _is_task_available(state, task):
			continue
		available_ids.append(task_id)
	return available_ids


static func _available_feature_task_ids(state, definitions: Dictionary) -> Array[String]:
	var available_ids: Array[String] = []
	_ensure_route_task_id_caches(definitions)
	for task_id in _feature_task_ids_cache:
		var task: Dictionary = definitions[task_id]
		if state.is_task_completed(task_id):
			continue
		if _is_task_available(state, task):
			available_ids.append(task_id)
	return available_ids


static func _ensure_route_task_id_caches(definitions: Dictionary) -> void:
	if _route_task_ids_cached:
		return
	_progression_task_ids_cache.clear()
	_feature_task_ids_cache.clear()
	for task_id in _sorted_task_ids(definitions):
		var task_value: Variant = definitions.get(task_id, {})
		if not task_value is Dictionary:
			continue
		match String((task_value as Dictionary).get("type", "")):
			"tutorial", "growth":
				_progression_task_ids_cache.append(task_id)
			"feature":
				_feature_task_ids_cache.append(task_id)
	_route_task_ids_cached = true


static func _progression_route_complete(state) -> bool:
	if state == null:
		return false
	for task_value: Variant in get_task_definitions().values():
		if not task_value is Dictionary:
			continue
		var task: Dictionary = task_value
		if ["tutorial", "growth"].has(String(task.get("type", ""))) and not state.is_task_completed(String(task.get("id", ""))):
			return false
	return true


static func _active_entry(task: Dictionary, state) -> Dictionary:
	var entry := task.duplicate(true)
	var task_id := String(task.get("id", ""))
	entry["progress"] = _progress_for_task(state, task_id)
	entry["progress_detail"] = format_task_progress_detail(task, entry["progress"])
	entry["status"] = "active"
	return entry


static func _is_task_available(state, task: Dictionary) -> bool:
	if state == null:
		return false
	var availability: Dictionary = task.get("availability", {})
	if not bool(availability.get("enabled", true)):
		return false
	if int(state.level) < int(availability.get("min_level", task.get("level", 0))):
		return false
	if int(state.recipe_starlight_total) < int(availability.get("min_lifetime_starlight", 0)):
		return false
	for feature_id in _sanitize_string_array(availability.get("automation_unlocks", [])):
		if not state.is_automation_unlocked(feature_id):
			return false
	for prerequisite in _sanitize_string_array(task.get("prerequisites", [])):
		if not state.is_task_completed(prerequisite):
			return false
	return true


static func _task_accepts_event(task: Dictionary, event_name: String) -> bool:
	var objectives_value: Variant = task.get("objectives", [])
	if objectives_value is Array and not (objectives_value as Array).is_empty():
		for objective_value: Variant in objectives_value:
			if objective_value is Dictionary and _definition_accepts_event(objective_value, event_name):
				return true
		return false
	return _definition_accepts_event(task, event_name)


static func _definition_accepts_event(definition: Dictionary, event_name: String) -> bool:
	var events_value: Variant = definition.get("events", [])
	if events_value is Array and not (events_value as Array).is_empty():
		return (events_value as Array).has(event_name)
	return String(definition.get("event", "")) == event_name


static func _progress_for_task(state, task_id: String) -> Dictionary:
	if state == null:
		return {}
	var raw_progress: Variant = state.task_progress.get(task_id, {})
	if raw_progress is Dictionary:
		return (raw_progress as Dictionary).duplicate(true)
	return {}


static func _progress_suffix(progress_value: Variant, goal: int) -> String:
	if not progress_value is Dictionary:
		return "(0/%d)" % maxi(1, goal)
	var progress: Dictionary = progress_value
	return "(%d/%d)" % [maxi(0, int(progress.get("count", 0))), maxi(1, int(progress.get("goal", goal)))]


static func _load_game_data() -> Dictionary:
	var file := FileAccess.open(GAME_DATA_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return parsed
	return {}


static func _sorted_task_ids(definitions: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	for id: Variant in definitions.keys():
		ids.append(String(id))
	ids.sort_custom(func(a: String, b: String) -> bool:
		return int(definitions[a].get("sort_order", 0)) < int(definitions[b].get("sort_order", 0))
	)
	return ids


static func _sanitize_string_array(value: Variant) -> Array[String]:
	var output: Array[String] = []
	if not value is Array:
		return output
	for item: Variant in value:
		output.append(String(item))
	return output
