class_name AutomationService
extends RefCounted

const Catalog = preload("res://scripts/catalog.gd")
const GameState = preload("res://scripts/game_state.gd")
const ProductionSite = preload("res://scripts/production_site.gd")
const RecipeGrowthService = preload("res://scripts/recipe_growth_service.gd")
const StarProgressionService = preload("res://scripts/star_progression_service.gd")


static func set_output_site_managed(state, site_id: String, managed: bool) -> Dictionary:
	if not state.is_automation_unlocked("output"):
		return {"ok": false, "reason": "产地管家尚未解锁"}
	if not Catalog.new().get_production_sites().has(site_id):
		return {"ok": false, "reason": "未知产地"}
	if managed and not state.managed_production_sites.has(site_id):
		var limit := output_site_limit(state)
		if limit >= 0 and state.managed_production_sites.size() >= limit:
			return {"ok": false, "reason": "托管产地已达上限"}
		state.managed_production_sites.append(site_id)
	elif not managed:
		state.managed_production_sites.erase(site_id)
		var released_slots := _release_paused_output_site_slots(state, site_id)
		return {"ok": true, "managed": false, "site_id": site_id, "released_slots": released_slots}
	return {"ok": true, "managed": true, "site_id": site_id, "released_slots": 0}


static func _release_paused_output_site_slots(state, site_id: String) -> int:
	var released := 0
	for index in range(state.production_slots.size() - 1, -1, -1):
		var slot_value: Variant = state.production_slots[index]
		if not slot_value is Dictionary:
			continue
		var slot: Dictionary = slot_value
		if String(slot.get("site_id", "")) != site_id or not bool(slot.get("automation_paused", false)):
			continue
		state.production_slots.remove_at(index)
		released += 1
	if released > 0:
		state.add_log("automation_site_released:%s:%d" % [site_id, released])
	return released


static func set_output_managed(state, site_id: String, _slot_index: int, managed: bool) -> Dictionary:
	return set_output_site_managed(state, site_id, managed)


static func output_site_limit(state) -> int:
	return StarProgressionService.automation_effect_int(state, "managed_output_sites")


static func output_slot_limit(state) -> int:
	return output_site_limit(state)


static func kitchen_rule_limit(state) -> int:
	return StarProgressionService.automation_effect_int(state, "kitchen_rules")


static func kitchen_device_limit(state) -> int:
	return StarProgressionService.automation_effect_int(state, "managed_kitchen_devices")


static func priority_enabled(state) -> bool:
	return StarProgressionService.automation_effect_enabled(state, "priority_enabled")


static func inventory_policy_enabled(state) -> bool:
	return StarProgressionService.automation_effect_enabled(state, "inventory_policy_enabled")


static func offline_seconds_limit(state) -> int:
	return StarProgressionService.automation_effect_int(state, "offline_seconds")


static func save_kitchen_rule(state, rule: Dictionary) -> Dictionary:
	if state == null or not state.is_automation_unlocked("kitchen"):
		return {"ok": false, "reason": "kitchen_locked"}
	var sanitized := _sanitize_rule_for_save(state, rule)
	if sanitized.is_empty():
		return {"ok": false, "reason": "invalid_rule"}
	var rule_id := String(sanitized.get("id", ""))
	var existing_index := _kitchen_rule_index(state, rule_id)
	var created := existing_index < 0
	if created and state.kitchen_automation_rules.size() >= kitchen_rule_limit(state):
		return {"ok": false, "reason": "limit_reached"}
	var prospective: Array[Dictionary] = state.kitchen_automation_rules.duplicate(true)
	if created:
		prospective.append(sanitized)
	else:
		prospective[existing_index] = sanitized
	if not _within_kitchen_device_limit(state, prospective):
		return {"ok": false, "reason": "limit_reached"}
	state.kitchen_automation_rules = prospective
	var saved_sequence := _rule_sequence(rule_id)
	if saved_sequence > 0:
		state.kitchen_rule_next_id = maxi(int(state.kitchen_rule_next_id), saved_sequence + 1)
	return {"ok": true, "rule": sanitized.duplicate(true), "created": created}


static func remove_kitchen_rule(state, rule_id: String) -> bool:
	var index := _kitchen_rule_index(state, rule_id)
	if index < 0:
		return false
	state.kitchen_automation_rules.remove_at(index)
	return true


static func kitchen_rule_status(state, rule_id: String) -> Dictionary:
	var index := _kitchen_rule_index(state, rule_id)
	if index < 0:
		return {"running": false, "paused": true, "reason": {"code": "invalid_recipe"}}
	var rule: Dictionary = state.kitchen_automation_rules[index]
	for queued_value: Variant in state.recipe_production_queue:
		if queued_value is Dictionary:
			var queued: Dictionary = queued_value
			if String(queued.get("source", "manual")) == "automation" and String(queued.get("automation_rule_id", "")) == rule_id:
				return {"running": true, "paused": false, "reason": {}}
	var reason: Dictionary = rule.get("pause_reason", {}) if rule.get("pause_reason", {}) is Dictionary else {}
	if not bool(rule.get("enabled", true)) and reason.is_empty():
		reason = {"code": "limit_reached"}
	return {"running": false, "paused": not reason.is_empty(), "reason": reason.duplicate(true)}


static func set_global_paused(state, paused: bool, now_unix: int = -1) -> void:
	var was_paused := bool(state.automation_paused)
	state.automation_paused = paused
	if was_paused and not paused:
		var resume_unix := now_unix if now_unix >= 0 else int(Time.get_unix_time_from_system())
		state.automation_resume_floor_unix = maxi(0, resume_unix)
	state.add_log("automation_global_pause:%s" % str(paused))


static func settle(state, from_unix: int, to_unix: int, offline_limit_seconds: int = -1, event_limit_override: int = -1) -> Dictionary:
	var end_unix := to_unix
	if offline_limit_seconds >= 0:
		end_unix = mini(end_unix, from_unix + offline_limit_seconds)
	var report := _new_report(from_unix, end_unix)
	var event_limit := event_limit_override if event_limit_override > 0 else maxi(1, int(StarProgressionService.get_config().get("event_limit", 10000)))
	if state.automation_paused:
		return report
	var offline_mode := offline_limit_seconds >= 0
	var cursor_unix := from_unix
	_resume_available_output_sites(state, cursor_unix)
	if offline_mode:
		_shift_kitchen_queue_for_offline(state, maxi(0, to_unix - from_unix))
	var event_count := 0
	while event_count < event_limit:
		if not offline_mode:
			_start_available_kitchen_rules(state, cursor_unix, report)
		var event := _next_output_event(state, end_unix) if offline_mode else _next_event(state, end_unix)
		if offline_mode and not event.is_empty():
			event["kind"] = "output_ready"
		if event.is_empty():
			break
		event_count += 1
		cursor_unix = int(event.get("at", cursor_unix))
		match String(event.get("kind", "")):
			"output_ready":
				_accumulate_output_result(report, ProductionSite.settle_ready_slot(state, int(event.get("array_index", -1)), cursor_unix, true))
			"kitchen_ready":
				_accumulate_kitchen_result(report, _complete_kitchen_queue(state, int(event.get("queue_index", -1)), cursor_unix))
	if not offline_mode:
		_start_available_kitchen_rules(state, end_unix, report)
	var remaining_event := _next_output_event(state, end_unix) if offline_mode else _next_event(state, end_unix)
	var has_remaining_event := event_count >= event_limit and not remaining_event.is_empty()
	return _finish_report(report, has_remaining_event)


static func _shift_kitchen_queue_for_offline(state, elapsed_seconds: int) -> void:
	if elapsed_seconds <= 0:
		return
	for index in range(state.recipe_production_queue.size()):
		var queued_value: Variant = state.recipe_production_queue[index]
		if not queued_value is Dictionary:
			continue
		var queued: Dictionary = queued_value
		if String(queued.get("source", "manual")) != "automation":
			continue
		queued["started_at_unix"] = maxi(0, int(queued.get("started_at_unix", 0)) + elapsed_seconds)
		queued["ready_at_unix"] = maxi(0, int(queued.get("ready_at_unix", 0)) + elapsed_seconds)
		state.recipe_production_queue[index] = queued


static func _resume_available_output_sites(state, event_unix: int) -> void:
	for index in range(state.production_slots.size()):
		var slot_value: Variant = state.production_slots[index]
		if not slot_value is Dictionary:
			continue
		var slot: Dictionary = slot_value
		var site_id := String(slot.get("site_id", ""))
		if not state.is_output_site_managed(site_id) or not bool(slot.get("automation_paused", false)):
			continue
		ProductionSite.resume_paused_slot(state, index, event_unix)


static func _new_report(from_unix: int, to_unix: int) -> Dictionary:
	return {
		"from_unix": from_unix,
		"to_unix": to_unix,
		"event_count": 0,
		"output_cycle_count": 0,
		"kitchen_cycle_count": 0,
		"outputs": {},
		"product_outputs": {},
		"completed_recipe_slots": [],
		"growth": {},
		"paused_slots": [],
		"pauses": [],
		"event_limit_reached": false
	}


static func _next_event(state, end_unix: int) -> Dictionary:
	var output := _next_output_event(state, end_unix)
	var kitchen := _next_kitchen_event(state, end_unix)
	if output.is_empty():
		if not kitchen.is_empty():
			kitchen["kind"] = "kitchen_ready"
		return kitchen
	if kitchen.is_empty() or int(output.get("at", end_unix)) <= int(kitchen.get("at", end_unix)):
		output["kind"] = "output_ready"
		return output
	kitchen["kind"] = "kitchen_ready"
	return kitchen


static func _next_output_event(state, end_unix: int) -> Dictionary:
	var next_event: Dictionary = {}
	for array_index in range(state.production_slots.size()):
		var slot_value: Variant = state.production_slots[array_index]
		if not slot_value is Dictionary:
			continue
		var slot: Dictionary = slot_value
		var site_id := String(slot.get("site_id", ""))
		if not state.is_output_site_managed(site_id) or bool(slot.get("automation_paused", false)):
			continue
		var ready_at_unix := int(slot.get("ready_at_unix", 0))
		if ready_at_unix <= 0:
			continue
		var event_at_unix := maxi(ready_at_unix, int(state.automation_resume_floor_unix))
		if event_at_unix > end_unix or not ProductionSite.is_slot_ready(state, array_index, event_at_unix):
			continue
		if next_event.is_empty() or event_at_unix < int(next_event.get("at", end_unix)):
			next_event = {"array_index": array_index, "at": event_at_unix}
	return next_event


static func _next_kitchen_event(state, end_unix: int) -> Dictionary:
	var next_event: Dictionary = {}
	for queue_index in range(state.recipe_production_queue.size()):
		var queued_value: Variant = state.recipe_production_queue[queue_index]
		if not queued_value is Dictionary:
			continue
		var queued: Dictionary = queued_value
		if String(queued.get("source", "manual")) != "automation":
			continue
		var ready_at_unix := int(queued.get("ready_at_unix", 0))
		var event_at_unix := maxi(ready_at_unix, int(state.automation_resume_floor_unix))
		if event_at_unix <= 0 or event_at_unix > end_unix:
			continue
		if next_event.is_empty() or event_at_unix < int(next_event.get("at", end_unix)):
			next_event = {"queue_index": queue_index, "at": event_at_unix}
	return next_event


static func _start_available_kitchen_rules(state, cursor_unix: int, report: Dictionary) -> void:
	if not state.is_automation_unlocked("kitchen"):
		return
	var rule_indices: Array[int] = []
	for index in range(state.kitchen_automation_rules.size()):
		rule_indices.append(index)
	rule_indices.sort_custom(func(left: int, right: int) -> bool:
		return _rule_precedes(state.kitchen_automation_rules[left], state.kitchen_automation_rules[right])
	)
	for index in rule_indices:
		var rule: Dictionary = state.kitchen_automation_rules[index]
		if not bool(rule.get("enabled", true)):
			continue
		var rule_id := String(rule.get("id", ""))
		if _has_automation_queue_for_rule(state, rule_id):
			continue
		var reason := _rule_start_reason(state, rule, cursor_unix)
		if not reason.is_empty():
			_set_rule_pause(state, index, reason, report)
			continue
		if state.queue_recipe_production(String(rule.get("recipe_id", "")), 1, cursor_unix, "automation", rule_id):
			_clear_rule_pause(state, index)
		else:
			_set_rule_pause(state, index, {"code": "missing_input", "first_stopped_at_unix": cursor_unix}, report)


static func _rule_start_reason(state, rule: Dictionary, now_unix: int) -> Dictionary:
	var catalog := Catalog.new()
	var recipes: Dictionary = catalog.get_recipes()
	var recipe_id := String(rule.get("recipe_id", ""))
	if not recipes.has(recipe_id) or not state.is_recipe_unlocked(recipe_id):
		return {"code": "invalid_recipe", "first_stopped_at_unix": now_unix}
	var recipe: Dictionary = recipes[recipe_id]
	var device_id := String(rule.get("device_id", ""))
	if String(recipe.get("device", "")) != device_id or not state.is_device_unlocked(device_id):
		return {"code": "invalid_device", "first_stopped_at_unix": now_unix}
	if state.get_product_count(recipe_id) >= int(rule.get("target_stock", 0)):
		return {"code": "target_reached", "first_stopped_at_unix": now_unix}
	var batches := 1
	if state.active_recipe_production_batch_count(recipe_id) + batches > GameState.MAX_CONCURRENT_RECIPE_BATCHES:
		return {"code": "capacity_reached", "first_stopped_at_unix": now_unix}
	var reserves: Dictionary = rule.get("material_reserves", {})
	for material_value: Variant in recipe.get("materials", []):
		var material_id := String(material_value)
		var available := _material_count(state, material_id, recipes)
		var reserve := int(reserves.get(material_id, 0))
		if inventory_policy_enabled(state) and available - batches < reserve:
			return {"code": "material_reserve", "item_id": material_id, "required": reserve + batches, "available": available, "first_stopped_at_unix": now_unix}
		if available < batches:
			return {"code": "missing_input", "item_id": material_id, "required": batches, "available": available, "first_stopped_at_unix": now_unix}
	return {}


static func _complete_kitchen_queue(state, queue_index: int, now_unix: int) -> Dictionary:
	if queue_index < 0 or queue_index >= state.recipe_production_queue.size():
		return {"ok": false}
	var queued_value: Variant = state.recipe_production_queue[queue_index]
	if not queued_value is Dictionary:
		return {"ok": false}
	var queued: Dictionary = queued_value
	var recipe_id := String(queued.get("recipe_id", ""))
	var output_count := int(queued.get("output_count", 0))
	var made_batches := maxi(1, int(queued.get("batches", 1)))
	var completed_slot := {
		"recipe_id": recipe_id,
		"queue_sequence": int(queued.get("queue_sequence", 0)),
		"source": "automation",
		"batches": made_batches,
		"output_count": output_count
	}
	var before_growth: Dictionary = state.get_recipe_growth(recipe_id)
	var before_mastery := int(before_growth.get("mastery_level", 0))
	if not state.complete_recipe_production(queue_index, now_unix):
		return {"ok": false}
	var after_growth: Dictionary = state.get_recipe_growth(recipe_id)
	var after_mastery := int(after_growth.get("mastery_level", before_mastery))
	return {
		"ok": true,
		"recipe_id": recipe_id,
		"output_count": output_count,
		"rule_id": String(queued.get("automation_rule_id", "")),
		"completed_slot": completed_slot,
		"growth": {
			"made_count": output_count,
			"made_batches": made_batches,
			"before_mastery": before_mastery,
			"after_mastery": after_mastery,
			"before_stage": RecipeGrowthService.mastery_name(before_mastery),
			"after_stage": RecipeGrowthService.mastery_name(after_mastery)
		}
	}


static func _accumulate_output_result(report: Dictionary, result: Dictionary) -> void:
	if not bool(result.get("ok", false)):
		return
	report["event_count"] = int(report.get("event_count", 0)) + 1
	report["output_cycle_count"] = int(report.get("output_cycle_count", 0)) + 1
	var totals: Dictionary = report.get("outputs", {})
	var outputs: Dictionary = result.get("outputs", {})
	for item_id_value: Variant in outputs.keys():
		var item_id := String(item_id_value)
		totals[item_id] = int(totals.get(item_id, 0)) + int(outputs[item_id_value])
	report["outputs"] = totals
	var pause_reason: Dictionary = result.get("pause_reason", {})
	if not pause_reason.is_empty():
		var paused_slots: Array = report.get("paused_slots", [])
		paused_slots.append({"slot_key": String(result.get("slot_key", "")), "reason": pause_reason.duplicate(true)})
		report["paused_slots"] = paused_slots


static func _accumulate_kitchen_result(report: Dictionary, result: Dictionary) -> void:
	if not bool(result.get("ok", false)):
		return
	report["event_count"] = int(report.get("event_count", 0)) + 1
	report["kitchen_cycle_count"] = int(report.get("kitchen_cycle_count", 0)) + 1
	var outputs: Dictionary = report.get("product_outputs", {})
	var recipe_id := String(result.get("recipe_id", ""))
	outputs[recipe_id] = int(outputs.get(recipe_id, 0)) + int(result.get("output_count", 0))
	report["product_outputs"] = outputs
	var completed_slot: Dictionary = result.get("completed_slot", {}) if result.get("completed_slot", {}) is Dictionary else {}
	if not completed_slot.is_empty():
		var completed_recipe_slots: Array = report.get("completed_recipe_slots", [])
		completed_recipe_slots.append(completed_slot.duplicate(true))
		report["completed_recipe_slots"] = completed_recipe_slots
	var result_growth: Dictionary = result.get("growth", {}) if result.get("growth", {}) is Dictionary else {}
	if result_growth.is_empty():
		return
	var growth: Dictionary = report.get("growth", {}) if report.get("growth", {}) is Dictionary else {}
	var aggregate: Dictionary = growth.get(recipe_id, {}) if growth.get(recipe_id, {}) is Dictionary else {}
	if aggregate.is_empty():
		aggregate = result_growth.duplicate(true)
	else:
		aggregate["made_count"] = int(aggregate.get("made_count", 0)) + int(result_growth.get("made_count", 0))
		aggregate["made_batches"] = int(aggregate.get("made_batches", 0)) + int(result_growth.get("made_batches", 0))
		aggregate["after_mastery"] = int(result_growth.get("after_mastery", aggregate.get("after_mastery", 0)))
		aggregate["after_stage"] = String(result_growth.get("after_stage", aggregate.get("after_stage", "")))
	growth[recipe_id] = aggregate
	report["growth"] = growth


static func _finish_report(report: Dictionary, has_remaining_event: bool) -> Dictionary:
	report["event_limit_reached"] = has_remaining_event
	return report


static func _sanitize_rule_for_save(state, raw_rule: Dictionary) -> Dictionary:
	var catalog := Catalog.new()
	var recipes: Dictionary = catalog.get_recipes()
	var devices: Dictionary = catalog.get_devices()
	var recipe_id := String(raw_rule.get("recipe_id", ""))
	var device_id := String(raw_rule.get("device_id", ""))
	if not recipes.has(recipe_id) or not devices.has(device_id) or String(recipes[recipe_id].get("device", "")) != device_id:
		return {}
	var batches := 1
	var reserves: Dictionary = {}
	if raw_rule.get("material_reserves", {}) is Dictionary:
		for item_value: Variant in (raw_rule.get("material_reserves", {}) as Dictionary).keys():
			var item_id := String(item_value)
			var reserve := int((raw_rule.get("material_reserves", {}) as Dictionary).get(item_value, 0))
			if item_id.is_empty() or reserve < 0:
				return {}
			if reserve > 0:
				reserves[item_id] = reserve
	var target_stock := int(raw_rule.get("target_stock", 0))
	if target_stock < 0:
		return {}
	var rule_id := String(raw_rule.get("id", ""))
	if rule_id.is_empty():
		rule_id = _next_available_rule_id(state)
	return {
		"id": rule_id,
		"recipe_id": recipe_id,
		"device_id": device_id,
		"batches": batches,
		"target_stock": target_stock,
		"material_reserves": reserves if inventory_policy_enabled(state) else {},
		"priority": int(raw_rule.get("priority", 0)) if priority_enabled(state) else 0,
		"sort_order": maxi(0, int(raw_rule.get("sort_order", 0))),
		"enabled": bool(raw_rule.get("enabled", true))
	}


static func _within_kitchen_device_limit(state, rules: Array[Dictionary]) -> bool:
	var limit := kitchen_device_limit(state)
	if limit < 0:
		return true
	var devices: Dictionary = {}
	for rule: Dictionary in rules:
		devices[String(rule.get("device_id", ""))] = true
	return devices.size() <= limit


static func _kitchen_rule_index(state, rule_id: String) -> int:
	if rule_id.is_empty():
		return -1
	for index in range(state.kitchen_automation_rules.size()):
		if String(state.kitchen_automation_rules[index].get("id", "")) == rule_id:
			return index
	return -1


static func _rule_sequence(rule_id: String) -> int:
	if not rule_id.begins_with("rule_"):
		return 0
	var suffix := rule_id.trim_prefix("rule_")
	if not suffix.is_valid_int():
		return 0
	return maxi(0, int(suffix))


static func _next_available_rule_id(state) -> String:
	var sequence := maxi(1, int(state.kitchen_rule_next_id))
	var candidate := "rule_%d" % sequence
	while _kitchen_rule_index(state, candidate) >= 0:
		sequence += 1
		candidate = "rule_%d" % sequence
	return candidate


static func _has_automation_queue_for_rule(state, rule_id: String) -> bool:
	for queued_value: Variant in state.recipe_production_queue:
		if not queued_value is Dictionary:
			continue
		var queued: Dictionary = queued_value
		if String(queued.get("source", "manual")) == "automation" and String(queued.get("automation_rule_id", "")) == rule_id:
			return true
	return false


static func _rule_precedes(candidate: Dictionary, current: Dictionary) -> bool:
	var candidate_priority := int(candidate.get("priority", 0))
	var current_priority := int(current.get("priority", 0))
	if candidate_priority != current_priority:
		return candidate_priority > current_priority
	return int(candidate.get("sort_order", 0)) < int(current.get("sort_order", 0))


static func _material_count(state, material_id: String, recipes: Dictionary) -> int:
	return state.get_product_count(material_id) if recipes.has(material_id) else state.get_ingredient_count(material_id)


static func _set_rule_pause(state, index: int, reason: Dictionary, report: Dictionary) -> void:
	if index < 0 or index >= state.kitchen_automation_rules.size():
		return
	var rule: Dictionary = state.kitchen_automation_rules[index]
	var previous: Dictionary = rule.get("pause_reason", {}) if rule.get("pause_reason", {}) is Dictionary else {}
	if previous.has("first_stopped_at_unix"):
		reason["first_stopped_at_unix"] = int(previous.get("first_stopped_at_unix", 0))
	var changed := previous != reason
	rule["pause_reason"] = reason.duplicate(true)
	state.kitchen_automation_rules[index] = rule
	if changed:
		var pauses: Array = report.get("pauses", [])
		pauses.append({"rule_id": String(rule.get("id", "")), "reason": reason.duplicate(true)})
		report["pauses"] = pauses


static func _clear_rule_pause(state, index: int) -> void:
	if index < 0 or index >= state.kitchen_automation_rules.size():
		return
	var rule: Dictionary = state.kitchen_automation_rules[index]
	rule.erase("pause_reason")
	state.kitchen_automation_rules[index] = rule
