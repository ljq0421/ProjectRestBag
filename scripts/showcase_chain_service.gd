class_name ShowcaseChainService
extends RefCounted

const BASE_HEAT_GAIN := 4
const ADVANCE_HEAT_COST := 10
const AMPLIFY_HEAT_COST := 8
const HARVEST_HEAT_COST := 15


static func resolve_chain(
	natural_event: Dictionary,
	item_states: Dictionary,
	role_snapshot: Dictionary,
	current_heat: int,
	max_depth: int = 4
) -> Dictionary:
	var next_states := item_states.duplicate(true)
	var chain_events: Array[Dictionary] = []
	var effects: Array[Dictionary] = []
	var triggered: Array[String] = []
	var queue: Array[Dictionary] = [natural_event.duplicate(true)]
	var spendable_heat := clampi(current_heat, 0, 100)
	var buffered_heat := BASE_HEAT_GAIN
	var depth_limit := clampi(max_depth, 1, 4)
	while not queue.is_empty() and triggered.size() < depth_limit:
		var source_event: Dictionary = queue.pop_front()
		var source_id := String(source_event.get("recipe_id", ""))
		if source_id.is_empty() or triggered.has(source_id):
			continue
		triggered.append(source_id)
		var role_data: Dictionary = role_snapshot.get(source_id, {})
		match String(role_data.get("role", "lure")):
			"advance":
				var target_id := _first_valid_target(role_data.get("targets", []), next_states, triggered)
				if target_id.is_empty():
					if (role_data.get("targets", []) as Array).is_empty():
						effects.append({"kind": "broken", "source_recipe_id": source_id, "target_recipe_id": "", "heat_cost": 0, "reason": "连锁断开：没有四方向相邻的可售商品"})
					continue
				if spendable_heat < ADVANCE_HEAT_COST:
					continue
				var forced_sale := _consume_one(target_id, next_states, source_event)
				if forced_sale.is_empty():
					continue
				spendable_heat -= ADVANCE_HEAT_COST
				next_states = forced_sale.get("item_states", next_states)
				var event: Dictionary = forced_sale.get("event", {})
				chain_events.append(event)
				effects.append({"kind": "advance", "source_recipe_id": source_id, "target_recipe_id": target_id, "heat_cost": ADVANCE_HEAT_COST})
				buffered_heat += BASE_HEAT_GAIN
				queue.append(event)
			"amplify":
				if spendable_heat < AMPLIFY_HEAT_COST:
					continue
				spendable_heat -= AMPLIFY_HEAT_COST
				var bonus := int(floor(float(source_event.get("earned_coins", 0)) * 0.2))
				if bonus > 0:
					chain_events.append(_bonus_event(source_id, bonus, "amplify", source_event))
					effects.append({"kind": "amplify", "source_recipe_id": source_id, "heat_cost": AMPLIFY_HEAT_COST, "bonus_coins": bonus})
			"harvest":
				if spendable_heat < HARVEST_HEAT_COST:
					continue
				spendable_heat -= HARVEST_HEAT_COST
				var bonus := int(floor(float(source_event.get("earned_coins", 0)) * 0.3))
				if bonus > 0:
					chain_events.append(_bonus_event(source_id, bonus, "harvest", source_event))
					effects.append({"kind": "harvest", "source_recipe_id": source_id, "heat_cost": HARVEST_HEAT_COST, "bonus_coins": bonus})
	return {
		"item_states": next_states,
		"chain_events": chain_events,
		"effects": effects,
		"triggered_recipe_ids": triggered,
		"heat": clampi(spendable_heat + buffered_heat, 0, 100),
		"buffered_heat_gain": buffered_heat
	}


static func _first_valid_target(targets_value: Variant, item_states: Dictionary, triggered: Array[String]) -> String:
	if not targets_value is Array:
		return ""
	for target_value in targets_value as Array:
		var target_id := String(target_value)
		var item: Dictionary = item_states.get(target_id, {})
		if not triggered.has(target_id) and int(item.get("fresh_stock", 0)) + int(item.get("carried_stock", 0)) > 0:
			return target_id
	return ""


static func _consume_one(recipe_id: String, item_states: Dictionary, source_event: Dictionary) -> Dictionary:
	var next_states := item_states.duplicate(true)
	var item: Dictionary = next_states.get(recipe_id, {})
	var carried := maxi(0, int(item.get("carried_stock", 0)))
	var fresh := maxi(0, int(item.get("fresh_stock", 0)))
	if carried + fresh <= 0:
		return {}
	var batch := "fresh"
	var unit_price := maxi(0, int(item.get("unit_price", 0)))
	var earned_coins := unit_price
	if carried > 0:
		batch = "carried"
		carried -= 1
		earned_coins = int(floor(float(unit_price) * 0.8))
	else:
		fresh -= 1
	item["carried_stock"] = carried
	item["fresh_stock"] = fresh
	item["cycle_elapsed_ms"] = 0
	item["waiting_for_refill"] = carried + fresh <= 0
	next_states[recipe_id] = item
	return {
		"item_states": next_states,
		"event": {
			"recipe_id": recipe_id,
			"quantity": 1,
			"batch": batch,
			"unit_price": unit_price,
			"earned_coins": earned_coins,
			"completed_at_ms": int(source_event.get("completed_at_ms", 0)),
			"chain_source": "advance",
			"chain_parent_recipe_id": String(source_event.get("recipe_id", ""))
		}
	}


static func _bonus_event(recipe_id: String, bonus_coins: int, source: String, parent_event: Dictionary) -> Dictionary:
	return {
		"recipe_id": recipe_id,
		"quantity": 0,
		"batch": "bonus",
		"unit_price": 0,
		"earned_coins": maxi(0, bonus_coins),
		"completed_at_ms": int(parent_event.get("completed_at_ms", 0)),
		"chain_source": source,
		"bonus_only": true
	}
