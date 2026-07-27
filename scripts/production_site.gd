class_name ProductionSite
extends RefCounted

const Catalog = preload("res://scripts/catalog.gd")
const TutorialProgress = preload("res://scripts/tutorial_progress.gd")

static var _harvest_outputs_cache := {}


static func slot_key(site_id: String, slot_index: int) -> String:
	return "%s:%d" % [site_id, slot_index]


static func start_slot(state, site_id: String, item_id: String, slot_index_or_now_unix: int = -1, now_unix: int = -1) -> bool:
	if state == null:
		return false

	var catalog := Catalog.new()
	var sites: Dictionary = catalog.get_production_sites()
	var ingredients: Dictionary = catalog.get_ingredients()
	if not sites.has(site_id) or not ingredients.has(item_id):
		return false

	var site: Dictionary = sites[site_id]
	var ingredient: Dictionary = ingredients[item_id]
	var level: int = _state_level(state)
	if int(site.get("unlock_level", 1)) > level:
		return false
	if int(ingredient.get("unlock_level", 1)) > level:
		return false

	var site_items: Array = site.get("items", [])
	if not site_items.has(item_id):
		return false

	var slot_index := slot_index_or_now_unix
	if now_unix < 0 and slot_index_or_now_unix >= int(site.get("base_slots", 0)):
		now_unix = slot_index_or_now_unix
		slot_index = -1
	if slot_index < 0:
		slot_index = _next_available_site_slot_index(state, site_id)
	if slot_index < 0 or slot_index >= int(site.get("base_slots", 0)):
		return false
	if slot_index >= _unlocked_site_slot_count(state, site_id):
		return false
	if _slot_array_index_for_site_slot(state, site_id, slot_index) != -1:
		return false

	var uses_seed_stock := _uses_seed_stock(ingredient)
	var cost := 0 if uses_seed_stock else _production_cost(site, ingredient)
	if uses_seed_stock and not state.has_ingredient(item_id, 1):
		return false
	if not uses_seed_stock and int(state.coins) < cost:
		return false
	if uses_seed_stock:
		if not state.remove_ingredient(item_id, 1):
			return false
	else:
		state.coins = int(state.coins) - cost

	var started_at_unix: int = _now_unix(now_unix)
	var duration_seconds: int = production_duration_seconds(state, site_id, item_id, slot_index)
	var accelerator_id := _equipped_accelerator_id(state, site_id, slot_index)
	state.production_slots.append({
		"site_id": site_id,
		"slot_index": slot_index,
		"item_id": item_id,
		"started_at_unix": started_at_unix,
		"duration_seconds": duration_seconds,
		"ready_at_unix": started_at_unix + duration_seconds,
		"accelerator_id": accelerator_id
	})
	_add_log(state, "production_start:%s:%s:%d" % [site_id, item_id, cost])
	return true


static func advance_after_business(state) -> void:
	pass


static func evaluate_slots(state, now_unix: int = -1) -> void:
	if state == null:
		return

	var current_time: int = _now_unix(now_unix)
	for index in range(state.production_slots.size()):
		var slot_value: Variant = state.production_slots[index]
		if not slot_value is Dictionary:
			continue

		var slot: Dictionary = slot_value
		slot["ready"] = _valid_ready_slot(slot) and current_time >= int(slot.get("ready_at_unix", 0))
		state.production_slots[index] = slot


static func is_slot_ready(state, index: int, now_unix: int = -1) -> bool:
	if state == null or index < 0 or index >= state.production_slots.size():
		return false

	var slot_value: Variant = state.production_slots[index]
	if not slot_value is Dictionary:
		return false

	var slot: Dictionary = slot_value
	if bool(slot.get("automation_paused", false)):
		return false
	if not _valid_ready_slot(slot):
		return false
	return _now_unix(now_unix) >= int(slot.get("ready_at_unix", 0))


static func production_duration_seconds(state, site_id: String, item_id: String, slot_index: int = -1) -> int:
	var catalog := Catalog.new()
	var sites: Dictionary = catalog.get_production_sites()
	var ingredients: Dictionary = catalog.get_ingredients()
	if not sites.has(site_id) or not ingredients.has(item_id):
		return 1

	var site: Dictionary = sites[site_id]
	var ingredient: Dictionary = ingredients[item_id]
	var base_duration: int = _base_duration_seconds(site, ingredient)
	var accelerator_id := _equipped_accelerator_id(state, site_id, slot_index)
	if accelerator_id.is_empty():
		return base_duration

	var tools: Dictionary = catalog.get_tools()
	if not tools.has(accelerator_id):
		return base_duration

	var tool: Dictionary = tools[accelerator_id]
	var multiplier: float = float(tool.get("duration_multiplier", 1.0))
	return maxi(1, int(ceil(float(base_duration) * multiplier)))


static func harvest_outputs_for(site_id: String, item_id: String) -> Dictionary:
	var cache_key := "%s:%s" % [site_id, item_id]
	if _harvest_outputs_cache.has(cache_key):
		return (_harvest_outputs_cache[cache_key] as Dictionary).duplicate(true)
	var catalog := Catalog.new()
	var sites: Dictionary = catalog.get_production_sites()
	var ingredients: Dictionary = catalog.get_ingredients()
	if not sites.has(site_id) or not ingredients.has(item_id):
		return {}
	var site: Dictionary = sites[site_id]
	if not (site.get("items", []) as Array).has(item_id):
		return {}
	var outputs := _harvest_outputs(site, ingredients[item_id], item_id)
	_harvest_outputs_cache[cache_key] = outputs.duplicate(true)
	return outputs


static func harvest_slot(state, index: int, now_unix: int = -1, is_manual_guide_harvest: bool = false) -> bool:
	return bool(settle_ready_slot(state, index, _now_unix(now_unix), false, is_manual_guide_harvest).get("ok", false))


static func settle_ready_slot(
	state,
	index: int,
	event_unix: int,
	keep_paused: bool,
	is_manual_guide_harvest: bool = false
) -> Dictionary:
	if state == null or index < 0 or index >= state.production_slots.size():
		return {"ok": false}

	var slot_value: Variant = state.production_slots[index]
	if not slot_value is Dictionary:
		return {"ok": false}

	var slot: Dictionary = slot_value
	if not _slot_item_belongs_to_site(slot):
		return {"ok": false}
	if not is_slot_ready(state, index, event_unix):
		return {"ok": false}

	var site_id: String = String(slot.get("site_id", ""))
	var item_id: String = String(slot.get("item_id", ""))
	var slot_index := int(slot.get("slot_index", _fallback_slot_index_for_array_index(state, index)))
	var catalog := Catalog.new()
	var sites: Dictionary = catalog.get_production_sites()
	var ingredients: Dictionary = catalog.get_ingredients()
	if not sites.has(site_id):
		return {"ok": false}

	var site: Dictionary = sites[site_id]
	var planted_item: Dictionary = ingredients.get(item_id, {})
	var harvest_outputs := _harvest_outputs(site, planted_item, item_id)
	var harvest_batch_id := "%s:%d:%d" % [site_id, slot_index, int(slot.get("started_at_unix", 0))]
	for harvest_item_id: String in harvest_outputs.keys():
		var yield_amount := int(harvest_outputs[harvest_item_id])
		if not state.add_ingredient(harvest_item_id, yield_amount):
			return {"ok": false}

	for harvest_item_id: String in harvest_outputs.keys():
		var yield_amount := int(harvest_outputs[harvest_item_id])
		_add_log(state, "production_harvest:%s:%s:%d" % [site_id, harvest_item_id, yield_amount])
		TutorialProgress.on_ingredient_harvested(
			state,
			harvest_item_id,
			yield_amount,
			site_id,
			harvest_batch_id,
			is_manual_guide_harvest
		)
	var restart_item_id := _restart_item_id_for_slot(slot, item_id)
	var restart_item: Dictionary = ingredients.get(restart_item_id, {})
	if not _charge_or_consume_production_input(state, site, restart_item_id, restart_item):
		var pause_reason := _restart_pause_reason(state, site, restart_item_id, restart_item, event_unix)
		if keep_paused:
			slot["automation_paused"] = true
			slot["pause_reason"] = pause_reason
			slot["started_at_unix"] = 0
			slot["ready_at_unix"] = 0
			slot["ready"] = false
			state.production_slots[index] = slot
		else:
			state.production_slots.remove_at(index)
		_add_log(state, "production_restart_failed:%s:%s:input" % [site_id, restart_item_id])
		return {
			"ok": true,
			"slot_key": slot_key(site_id, slot_index),
			"site_id": site_id,
			"slot_index": slot_index,
			"outputs": harvest_outputs.duplicate(true),
			"restarted": false,
			"pause_reason": pause_reason if keep_paused else {},
			"next_ready_at_unix": 0
		}

	var duration_seconds: int = production_duration_seconds(state, site_id, restart_item_id, slot_index)
	slot["slot_index"] = slot_index
	slot["item_id"] = restart_item_id
	slot["started_at_unix"] = event_unix
	slot["duration_seconds"] = duration_seconds
	slot["ready_at_unix"] = event_unix + duration_seconds
	slot["accelerator_id"] = _equipped_accelerator_id(state, site_id, slot_index)
	slot["ready"] = false
	slot.erase("queued_item_id")
	slot.erase("automation_paused")
	slot.erase("pause_reason")
	state.production_slots[index] = slot
	_add_log(state, "production_restart:%s:%s:%d" % [site_id, restart_item_id, _production_input_cost(site, restart_item)])
	return {
		"ok": true,
		"slot_key": slot_key(site_id, slot_index),
		"site_id": site_id,
		"slot_index": slot_index,
		"outputs": harvest_outputs.duplicate(true),
		"restarted": true,
		"pause_reason": {},
		"next_ready_at_unix": int(slot.get("ready_at_unix", 0))
	}


static func set_next_item(state, index: int, item_id: String) -> bool:
	if state == null or index < 0 or index >= state.production_slots.size() or item_id.is_empty():
		return false

	var slot_value: Variant = state.production_slots[index]
	if not slot_value is Dictionary:
		return false

	var slot: Dictionary = slot_value
	if not _slot_item_belongs_to_site(slot):
		return false

	var site_id := String(slot.get("site_id", ""))
	var catalog := Catalog.new()
	var sites: Dictionary = catalog.get_production_sites()
	var ingredients: Dictionary = catalog.get_ingredients()
	if not sites.has(site_id) or not ingredients.has(item_id):
		return false

	var site: Dictionary = sites[site_id]
	var ingredient: Dictionary = ingredients[item_id]
	if int(site.get("unlock_level", 1)) > _state_level(state):
		return false
	if int(ingredient.get("unlock_level", 1)) > _state_level(state):
		return false

	var site_items: Array = site.get("items", [])
	if not site_items.has(item_id):
		return false

	slot["queued_item_id"] = item_id
	state.production_slots[index] = slot
	if bool(slot.get("automation_paused", false)):
		resume_paused_slot(state, index)
	_add_log(state, "production_next_set:%s:%s" % [site_id, item_id])
	state.record_task_event("output_next_set", {"site_id": site_id, "slot_index": int(slot.get("slot_index", index)), "item_id": item_id})
	return true


static func resume_paused_slot(state, index: int, event_unix: int = -1) -> bool:
	if state == null or index < 0 or index >= state.production_slots.size():
		return false
	var slot_value: Variant = state.production_slots[index]
	if not slot_value is Dictionary:
		return false
	var slot: Dictionary = slot_value
	if not bool(slot.get("automation_paused", false)) or not _slot_item_belongs_to_site(slot):
		return false

	var site_id := String(slot.get("site_id", ""))
	var item_id := _restart_item_id_for_slot(slot, String(slot.get("item_id", "")))
	var catalog := Catalog.new()
	var sites: Dictionary = catalog.get_production_sites()
	var ingredients: Dictionary = catalog.get_ingredients()
	if not sites.has(site_id) or not ingredients.has(item_id):
		return false
	var site: Dictionary = sites[site_id]
	var ingredient: Dictionary = ingredients[item_id]
	var resume_unix := _now_unix(event_unix)
	if not _charge_or_consume_production_input(state, site, item_id, ingredient):
		slot["pause_reason"] = _restart_pause_reason(state, site, item_id, ingredient, resume_unix)
		state.production_slots[index] = slot
		return false

	var slot_index := int(slot.get("slot_index", _fallback_slot_index_for_array_index(state, index)))
	var duration_seconds := production_duration_seconds(state, site_id, item_id, slot_index)
	slot["item_id"] = item_id
	slot["started_at_unix"] = resume_unix
	slot["duration_seconds"] = duration_seconds
	slot["ready_at_unix"] = resume_unix + duration_seconds
	slot["accelerator_id"] = _equipped_accelerator_id(state, site_id, slot_index)
	slot["ready"] = false
	slot.erase("queued_item_id")
	slot.erase("automation_paused")
	slot.erase("pause_reason")
	state.production_slots[index] = slot
	_add_log(state, "production_restart:%s:%s:%d" % [site_id, item_id, _production_input_cost(site, ingredient)])
	return true


static func cancel_slot(state, index: int) -> bool:
	if state == null or index < 0 or index >= state.production_slots.size():
		return false

	var slot_value: Variant = state.production_slots[index]
	if not slot_value is Dictionary:
		return false

	var slot: Dictionary = slot_value
	var site_id: String = String(slot.get("site_id", ""))
	var item_id: String = String(slot.get("item_id", ""))
	state.production_slots.remove_at(index)
	_add_log(state, "production_cancel:%s:%s" % [site_id, item_id])
	return true


static func unlock_site_slot(state, site_id: String, slot_index: int) -> bool:
	if state == null:
		return false
	var catalog := Catalog.new()
	var sites: Dictionary = catalog.get_production_sites()
	if not sites.has(site_id):
		return false
	var site: Dictionary = sites[site_id]
	var max_slots := int(site.get("base_slots", 0))
	if slot_index < 1 or slot_index >= max_slots:
		return false
	var current := _unlocked_site_slot_count(state, site_id)
	if slot_index != current:
		return false
	var costs := catalog.get_production_slot_unlock_costs()
	var cost_index := slot_index - 1
	var cost := int(costs[cost_index]) if cost_index >= 0 and cost_index < costs.size() else int(costs.back())
	if int(state.coins) < cost:
		return false
	state.coins = int(state.coins) - cost
	state.production_slot_unlocks[site_id] = current + 1
	_add_log(state, "production_slot_unlock:%s:%d:%d" % [site_id, slot_index, cost])
	return true


static func unlock_bag_page(state, site_id: String, page_index: int) -> bool:
	if state == null:
		return false
	var catalog := Catalog.new()
	if not catalog.get_production_sites().has(site_id):
		return false
	if page_index < 1 or page_index >= 5:
		return false
	var current := _unlocked_bag_page_count(state, site_id)
	if page_index != current:
		return false
	var costs := catalog.get_production_bag_page_unlock_costs()
	var cost := int(costs[page_index - 1])
	if int(state.coins) < cost:
		return false
	state.coins = int(state.coins) - cost
	state.production_bag_page_unlocks[site_id] = current + 1
	_add_log(state, "production_bag_page_unlock:%s:%d:%d" % [site_id, page_index, cost])
	return true


static func _state_level(state) -> int:
	return maxi(0, int(state.shop_level))


static func _active_site_slot_count(state, site_id: String) -> int:
	var count := 0
	for slot_value: Variant in state.production_slots:
		if not slot_value is Dictionary:
			continue

		var slot: Dictionary = slot_value
		if String(slot.get("site_id", "")) == site_id and _valid_slot(slot) and _slot_item_belongs_to_site(slot):
			count += 1
	return count


static func _unlocked_site_slot_count(state, site_id: String) -> int:
	if state != null:
		var unlocks: Variant = state.get("production_slot_unlocks")
		if unlocks is Dictionary:
			var values: Dictionary = unlocks
			return clampi(int(values.get(site_id, 1)), 1, 8)
	return 1


static func _unlocked_bag_page_count(state, site_id: String) -> int:
	if state != null:
		var unlocks: Variant = state.get("production_bag_page_unlocks")
		if unlocks is Dictionary:
			var values: Dictionary = unlocks
			return clampi(int(values.get(site_id, 1)), 1, 5)
	return 1


static func _next_available_site_slot_index(state, site_id: String) -> int:
	var unlocked_count := _unlocked_site_slot_count(state, site_id)
	for slot_index in range(unlocked_count):
		if _slot_array_index_for_site_slot(state, site_id, slot_index) == -1:
			return slot_index
	return -1


static func _slot_array_index_for_site_slot(state, site_id: String, slot_index: int) -> int:
	if state == null:
		return -1
	for index in range(state.production_slots.size()):
		var slot_value: Variant = state.production_slots[index]
		if not slot_value is Dictionary:
			continue
		var slot: Dictionary = slot_value
		if String(slot.get("site_id", "")) == site_id and int(slot.get("slot_index", index)) == slot_index and _valid_slot(slot):
			return index
	return -1


static func _fallback_slot_index_for_array_index(state, array_index: int) -> int:
	if state == null or array_index < 0 or array_index >= state.production_slots.size():
		return array_index
	var slot_value: Variant = state.production_slots[array_index]
	if slot_value is Dictionary:
		var slot: Dictionary = slot_value
		if slot.has("slot_index"):
			return int(slot.get("slot_index", array_index))
	return array_index


static func _production_cost(site: Dictionary, ingredient: Dictionary) -> int:
	var cost: int = int(ceil(float(ingredient.get("price", 0)) * float(site.get("cost_rate", 0.0))))
	return maxi(0, cost)


static func _production_input_cost(site: Dictionary, ingredient: Dictionary) -> int:
	if _uses_seed_stock(ingredient):
		return 0
	return _production_cost(site, ingredient)


static func _charge_or_consume_production_input(state, site: Dictionary, item_id: String, ingredient: Dictionary) -> bool:
	if _uses_seed_stock(ingredient):
		return state.remove_ingredient(item_id, 1)

	var cost := _production_cost(site, ingredient)
	if int(state.coins) < cost:
		return false
	state.coins = int(state.coins) - cost
	return true


static func _restart_pause_reason(state, site: Dictionary, item_id: String, ingredient: Dictionary, event_unix: int) -> Dictionary:
	if not _uses_seed_stock(ingredient):
		var cost := _production_cost(site, ingredient)
		if int(state.coins) < cost:
			return {"code": "insufficient_coins", "item_id": item_id, "required": cost, "available": int(state.coins), "first_stopped_at_unix": event_unix}
	return {"code": "missing_input", "item_id": item_id, "first_stopped_at_unix": event_unix}


static func _uses_seed_stock(ingredient: Dictionary) -> bool:
	var type := String(ingredient.get("type", ""))
	var harvest_outputs_value: Variant = ingredient.get("harvest_outputs", {})
	var has_harvest_outputs := harvest_outputs_value is Dictionary and not (harvest_outputs_value as Dictionary).is_empty()
	var has_harvest_output := not String(ingredient.get("harvest_item_id", "")).is_empty() or has_harvest_outputs
	if bool(ingredient.get("consumes_stock_for_production", false)) and has_harvest_output:
		return true
	return (type == "种子" or type == "幼畜") and has_harvest_output


static func _harvest_outputs(site: Dictionary, ingredient: Dictionary, item_id: String) -> Dictionary:
	var explicit_outputs: Variant = ingredient.get("harvest_outputs", {})
	if explicit_outputs is Dictionary:
		var explicit_output_dict: Dictionary = explicit_outputs
		var outputs: Dictionary = {}
		for output_id_value: Variant in explicit_output_dict.keys():
			var output_id := String(output_id_value)
			var amount := int(explicit_output_dict[output_id_value])
			if not output_id.is_empty() and amount > 0:
				outputs[output_id] = amount
		if not outputs.is_empty():
			return outputs

	var harvest_item_id := String(ingredient.get("harvest_item_id", item_id))
	var yield_amount: int = maxi(1, int(site.get("yield_amount", 1)))
	return {harvest_item_id: yield_amount}


static func _restart_item_id_for_slot(slot: Dictionary, fallback_item_id: String) -> String:
	var queued_item_id := String(slot.get("queued_item_id", ""))
	if queued_item_id.is_empty():
		return fallback_item_id

	var site_id := String(slot.get("site_id", ""))
	var catalog := Catalog.new()
	var sites: Dictionary = catalog.get_production_sites()
	var ingredients: Dictionary = catalog.get_ingredients()
	if not sites.has(site_id) or not ingredients.has(queued_item_id):
		return fallback_item_id

	var site: Dictionary = sites[site_id]
	var site_items: Array = site.get("items", [])
	if not site_items.has(queued_item_id):
		return fallback_item_id
	return queued_item_id


static func _base_duration_seconds(site: Dictionary, ingredient: Dictionary) -> int:
	if ingredient.has("production_duration_seconds"):
		return maxi(1, int(ingredient.get("production_duration_seconds", 1)))
	return maxi(1, int(site.get("duration_seconds", 1)))


static func _valid_ready_slot(slot: Dictionary) -> bool:
	return _valid_slot(slot) and _slot_item_belongs_to_site(slot)


static func _valid_slot(slot: Dictionary) -> bool:
	if not slot.has("site_id") or not slot.has("item_id"):
		return false
	if not slot.has("started_at_unix") or not slot.has("duration_seconds") or not slot.has("ready_at_unix"):
		return false
	if not _is_number(slot.get("started_at_unix")):
		return false
	if not _is_number(slot.get("duration_seconds")):
		return false
	if not _is_number(slot.get("ready_at_unix")):
		return false

	var duration_seconds: int = int(slot.get("duration_seconds", 0))
	if duration_seconds < 1:
		return false

	var started_at_unix: int = int(slot.get("started_at_unix", 0))
	var ready_at_unix: int = int(slot.get("ready_at_unix", 0))
	return ready_at_unix >= started_at_unix + duration_seconds


static func _slot_item_belongs_to_site(slot: Dictionary) -> bool:
	var site_id := String(slot.get("site_id", ""))
	var item_id := String(slot.get("item_id", ""))
	var catalog := Catalog.new()
	var sites: Dictionary = catalog.get_production_sites()
	var ingredients: Dictionary = catalog.get_ingredients()
	if not sites.has(site_id) or not ingredients.has(item_id):
		return false

	var site: Dictionary = sites[site_id]
	var site_items: Array = site.get("items", [])
	return site_items.has(item_id)


static func _is_number(value: Variant) -> bool:
	return value is int or value is float


static func _equipped_accelerator_id(state, site_id: String, slot_index: int) -> String:
	if state == null or not state.has_method("get_equipped_accelerator"):
		return ""

	if slot_index < 0:
		return ""

	var accelerator_id := String(state.get_equipped_accelerator("%s:%d" % [site_id, slot_index]))
	if accelerator_id.is_empty():
		return ""

	var tools: Dictionary = Catalog.new().get_tools()
	if not tools.has(accelerator_id):
		return ""

	var tool: Dictionary = tools[accelerator_id]
	if String(tool.get("compatible_site", "")) != site_id:
		return ""
	return accelerator_id


static func _now_unix(now_unix: int) -> int:
	if now_unix >= 0:
		return now_unix
	return int(Time.get_unix_time_from_system())


static func _add_log(state, message: String) -> void:
	if state != null and state.has_method("add_log"):
		state.add_log(message)
