class_name ShowcaseFreshnessService
extends RefCounted


static func prepare_settlement(item_states: Dictionary, base_prices: Dictionary, settlement_id: String) -> Dictionary:
	var forced_entries: Array[Dictionary] = []
	var fresh_options: Array[Dictionary] = []
	var recipe_ids: Array = item_states.keys()
	recipe_ids.sort()
	for recipe_id_value in recipe_ids:
		var recipe_id := String(recipe_id_value)
		var item: Dictionary = item_states.get(recipe_id_value, {})
		var base_price := maxi(0, int(base_prices.get(recipe_id, 0)))
		var carried_stock := maxi(0, int(item.get("carried_stock", 0)))
		var fresh_stock := maxi(0, int(item.get("fresh_stock", 0)))
		if carried_stock > 0:
			var forced_unit_price := int(floor(float(base_price) * 0.1))
			forced_entries.append({
				"recipe_id": recipe_id,
				"quantity": carried_stock,
				"unit_price": forced_unit_price,
				"earned_coins": forced_unit_price * carried_stock
			})
		if fresh_stock > 0:
			fresh_options.append({
				"recipe_id": recipe_id,
				"quantity": fresh_stock,
				"clear_unit_price": int(floor(float(base_price) * 0.5)),
				"carry_multiplier": 0.8
			})
	var forced_clearance_coins := 0
	var forced_clearance_count := 0
	for entry in forced_entries:
		forced_clearance_coins += int(entry.get("earned_coins", 0))
		forced_clearance_count += maxi(0, int(entry.get("quantity", 0)))
	return {
		"settlement_id": settlement_id,
		"forced_entries": forced_entries,
		"forced_clearance_coins": forced_clearance_coins,
		"forced_clearance_count": forced_clearance_count,
		"fresh_options": fresh_options
	}


static func apply_decisions(
	item_states: Dictionary,
	quote: Dictionary,
	decisions: Dictionary,
	applied_settlement_ids: Array
) -> Dictionary:
	var settlement_id := String(quote.get("settlement_id", ""))
	if settlement_id.is_empty() or applied_settlement_ids.has(settlement_id):
		return _rejected_result(item_states)
	var fresh_options: Array = quote.get("fresh_options", [])
	for option_value in fresh_options:
		if not option_value is Dictionary:
			return _rejected_result(item_states)
		var recipe_id := String((option_value as Dictionary).get("recipe_id", ""))
		var decision := String(decisions.get(recipe_id, ""))
		if not ["clear_50", "carry_80"].has(decision):
			return _rejected_result(item_states)

	var next_states := item_states.duplicate(true)
	var forced_clearance_coins := maxi(0, int(quote.get("forced_clearance_coins", 0)))
	var forced_clearance_count := maxi(0, int(quote.get("forced_clearance_count", 0)))
	for entry_value in quote.get("forced_entries", []):
		if not entry_value is Dictionary:
			continue
		var recipe_id := String((entry_value as Dictionary).get("recipe_id", ""))
		if not next_states.has(recipe_id):
			continue
		var item: Dictionary = next_states.get(recipe_id, {})
		item["carried_stock"] = 0
		next_states[recipe_id] = item

	var direct_clearance_coins := 0
	var direct_clearance_count := 0
	var carried_leftover_count := 0
	for option_value in fresh_options:
		var option: Dictionary = option_value
		var recipe_id := String(option.get("recipe_id", ""))
		var item: Dictionary = next_states.get(recipe_id, {})
		var quantity := maxi(0, int(option.get("quantity", 0)))
		if String(decisions.get(recipe_id, "")) == "clear_50":
			direct_clearance_coins += maxi(0, int(option.get("clear_unit_price", 0))) * quantity
			direct_clearance_count += quantity
			item["fresh_stock"] = 0
		else:
			item["carried_stock"] = quantity
			carried_leftover_count += quantity
			item["fresh_stock"] = 0
		var remaining_stock := maxi(0, int(item.get("fresh_stock", 0))) + maxi(0, int(item.get("carried_stock", 0)))
		item["waiting_for_refill"] = remaining_stock <= 0
		if remaining_stock <= 0:
			item["cycle_elapsed_ms"] = 0
		next_states[recipe_id] = item

	return {
		"ok": true,
		"settlement_id": settlement_id,
		"applied_settlement_id": settlement_id,
		"item_states": next_states,
		"forced_clearance_coins": forced_clearance_coins,
		"forced_clearance_count": forced_clearance_count,
		"direct_clearance_coins": direct_clearance_coins,
		"direct_clearance_count": direct_clearance_count,
		"carried_leftover_count": carried_leftover_count,
		"earned_coins": forced_clearance_coins + direct_clearance_coins
	}


static func _rejected_result(item_states: Dictionary) -> Dictionary:
	return {
		"ok": false,
		"item_states": item_states.duplicate(true),
		"forced_clearance_coins": 0,
		"forced_clearance_count": 0,
		"direct_clearance_coins": 0,
		"direct_clearance_count": 0,
		"carried_leftover_count": 0,
		"earned_coins": 0
	}
