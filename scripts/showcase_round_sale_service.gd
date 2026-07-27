class_name ShowcaseRoundSaleService
extends RefCounted

const ShowcaseChainService = preload("res://scripts/showcase_chain_service.gd")

static func build_item_states(display_items: Dictionary, sale_terms: Dictionary) -> Dictionary:
	var result := {}
	for recipe_id_value in display_items.keys():
		var recipe_id := String(recipe_id_value)
		var display_item: Dictionary = display_items.get(recipe_id_value, {})
		var term: Dictionary = sale_terms.get(recipe_id, {})
		if recipe_id.is_empty() or display_item.is_empty() or term.is_empty():
			continue
		var fresh_stock := maxi(0, int(display_item.get("fresh_stock", 0)))
		var carried_stock := maxi(0, int(display_item.get("carried_stock", 0)))
		var reasons: Array = []
		if term.get("bonus", {}) is Dictionary:
			for reason_value in (term.get("bonus", {}) as Dictionary).get("reasons", []):
				reasons.append(reason_value)
		for reason_value in term.get("environment_reasons", []):
			reasons.append(reason_value)
		result[recipe_id] = {
			"recipe_id": recipe_id,
			"anchor_cell": _anchor_cell(display_item.get("cells", [])),
			"duration_ms": maxi(1, int(term.get("duration_seconds", 1))) * 1000,
			"cycle_elapsed_ms": 0,
			"fresh_stock": fresh_stock,
			"carried_stock": carried_stock,
			"unit_price": maxi(0, int(term.get("unit_price", 0))),
			"base_unit_price": maxi(0, int(term.get("base_unit_price", term.get("base_price", term.get("unit_price", 0))))),
			"market_unit_price": maxi(0, int(term.get("market_unit_price", term.get("unit_price", 0)))),
			"base_duration_ms": maxi(1, int(term.get("base_duration_seconds", term.get("duration_seconds", 1)))) * 1000,
			"market_duration_ms": maxi(1, int(term.get("market_duration_seconds", term.get("duration_seconds", 1)))) * 1000,
			"reasons": reasons,
			"waiting_for_refill": fresh_stock + carried_stock <= 0
		}
	return result


static func merge_live_layout_states(current_states: Dictionary, rebuilt_states: Dictionary) -> Dictionary:
	var result := rebuilt_states.duplicate(true)
	for recipe_id_value in result.keys():
		var recipe_id := String(recipe_id_value)
		if not current_states.has(recipe_id):
			continue
		var current: Dictionary = current_states.get(recipe_id, {})
		var rebuilt: Dictionary = result.get(recipe_id, {})
		var old_duration := maxi(1, int(current.get("duration_ms", 1)))
		var new_duration := maxi(1, int(rebuilt.get("duration_ms", 1)))
		var old_elapsed := clampi(int(current.get("cycle_elapsed_ms", 0)), 0, old_duration - 1)
		var progress := float(old_elapsed) / float(old_duration)
		rebuilt["cycle_elapsed_ms"] = clampi(int(round(progress * float(new_duration))), 0, new_duration - 1)
		rebuilt["fresh_stock"] = maxi(0, int(current.get("fresh_stock", 0)))
		rebuilt["carried_stock"] = maxi(0, int(current.get("carried_stock", 0)))
		rebuilt["waiting_for_refill"] = bool(current.get("waiting_for_refill", false)) \
			or int(rebuilt.get("fresh_stock", 0)) + int(rebuilt.get("carried_stock", 0)) <= 0
		if bool(rebuilt.get("waiting_for_refill", false)):
			rebuilt["cycle_elapsed_ms"] = 0
		result[recipe_id] = rebuilt
	return result


static func replay_round(
	initial_item_states: Dictionary,
	duration_ms: int,
	refill_events: Array,
	mode: String = "full",
	role_snapshot: Dictionary = {},
	chain_max_depth: int = 4
) -> Dictionary:
	var states := _states_for_replay_mode(initial_item_states, mode)
	var sorted_refills := refill_events.duplicate(true)
	sorted_refills.sort_custom(func(left: Variant, right: Variant) -> bool:
		var left_data: Dictionary = left if left is Dictionary else {}
		var right_data: Dictionary = right if right is Dictionary else {}
		var left_time := int(left_data.get("elapsed_ms", 0))
		var right_time := int(right_data.get("elapsed_ms", 0))
		if left_time != right_time:
			return left_time < right_time
		return String(left_data.get("recipe_id", "")) < String(right_data.get("recipe_id", ""))
	)
	var events: Array[Dictionary] = []
	var current_ms := 0
	var refill_index := 0
	var heat := 0
	var safe_duration := maxi(0, duration_ms)
	while current_ms <= safe_duration:
		var next_sale_ms := _next_natural_sale_ms(states, current_ms, safe_duration)
		var next_refill_ms := safe_duration + 1
		if refill_index < sorted_refills.size() and sorted_refills[refill_index] is Dictionary:
			next_refill_ms = clampi(int((sorted_refills[refill_index] as Dictionary).get("elapsed_ms", 0)), current_ms, safe_duration)
		var boundary_ms := mini(safe_duration, mini(next_sale_ms, next_refill_ms))
		var sale_result := advance(states, current_ms, boundary_ms)
		states = (sale_result.get("item_states", states) as Dictionary).duplicate(true)
		for event_value in sale_result.get("events", []):
			if not event_value is Dictionary:
				continue
			var event: Dictionary = (event_value as Dictionary).duplicate(true)
			event["quantity"] = 1
			events.append(event)
			if mode == "full" and not role_snapshot.is_empty():
				var chain_result := ShowcaseChainService.resolve_chain(event, states, role_snapshot, heat, chain_max_depth)
				states = (chain_result.get("item_states", states) as Dictionary).duplicate(true)
				heat = int(chain_result.get("heat", heat))
				for chain_event_value in chain_result.get("chain_events", []):
					if chain_event_value is Dictionary:
						var chain_event: Dictionary = (chain_event_value as Dictionary).duplicate(true)
						chain_event["quantity"] = int(chain_event.get("quantity", 0))
						events.append(chain_event)
		while refill_index < sorted_refills.size() and sorted_refills[refill_index] is Dictionary \
				and int((sorted_refills[refill_index] as Dictionary).get("elapsed_ms", 0)) <= boundary_ms:
			var refill: Dictionary = sorted_refills[refill_index]
			var refill_result := refill_item(states, String(refill.get("recipe_id", "")), int(refill.get("amount", 0)), boundary_ms)
			states = (refill_result.get("item_states", states) as Dictionary).duplicate(true)
			refill_index += 1
		if boundary_ms >= safe_duration:
			break
		if boundary_ms == current_ms and next_refill_ms > current_ms and next_sale_ms > current_ms:
			break
		current_ms = boundary_ms
	var income := 0
	var sold_count := 0
	for event in events:
		income += maxi(0, int(event.get("earned_coins", 0)))
		sold_count += maxi(0, int(event.get("quantity", 0)))
	return {
		"mode": mode,
		"item_states": states,
		"events": events,
		"income": income,
		"sold_count": sold_count,
		"heat": heat
	}


static func _states_for_replay_mode(initial_item_states: Dictionary, mode: String) -> Dictionary:
	var result := initial_item_states.duplicate(true)
	for recipe_id_value in result.keys():
		var item: Dictionary = result.get(recipe_id_value, {})
		match mode:
			"base":
				item["unit_price"] = maxi(0, int(item.get("base_unit_price", item.get("unit_price", 0))))
				item["duration_ms"] = maxi(1, int(item.get("base_duration_ms", item.get("duration_ms", 1))))
			"market":
				item["unit_price"] = maxi(0, int(item.get("market_unit_price", item.get("unit_price", 0))))
				item["duration_ms"] = maxi(1, int(item.get("market_duration_ms", item.get("duration_ms", 1))))
			_:
				item["unit_price"] = maxi(0, int(item.get("unit_price", 0)))
				item["duration_ms"] = maxi(1, int(item.get("duration_ms", 1)))
		item["cycle_elapsed_ms"] = clampi(int(item.get("cycle_elapsed_ms", 0)), 0, int(item.get("duration_ms", 1)) - 1)
		item["waiting_for_refill"] = int(item.get("fresh_stock", 0)) + int(item.get("carried_stock", 0)) <= 0
		result[recipe_id_value] = item
	return result


static func _next_natural_sale_ms(states: Dictionary, current_ms: int, duration_ms: int) -> int:
	var result := duration_ms + 1
	for item_value in states.values():
		if not item_value is Dictionary:
			continue
		var item: Dictionary = item_value
		if int(item.get("fresh_stock", 0)) + int(item.get("carried_stock", 0)) <= 0:
			continue
		var item_duration := maxi(1, int(item.get("duration_ms", 1)))
		var elapsed := clampi(int(item.get("cycle_elapsed_ms", 0)), 0, item_duration - 1)
		result = mini(result, current_ms + item_duration - elapsed)
	return result


static func advance(item_states: Dictionary, from_elapsed_ms: int, to_elapsed_ms: int) -> Dictionary:
	var next_states := item_states.duplicate(true)
	var events: Array[Dictionary] = []
	var window_start := maxi(0, from_elapsed_ms)
	var window_end := maxi(window_start, to_elapsed_ms)
	for recipe_id_value in next_states.keys():
		var recipe_id := String(recipe_id_value)
		var item: Dictionary = next_states.get(recipe_id_value, {})
		var fresh_stock := maxi(0, int(item.get("fresh_stock", 0)))
		var carried_stock := maxi(0, int(item.get("carried_stock", 0)))
		if fresh_stock + carried_stock <= 0:
			item["waiting_for_refill"] = true
			next_states[recipe_id_value] = item
			continue
		var duration_ms := maxi(1, int(item.get("duration_ms", 1)))
		var cycle_elapsed_ms := clampi(int(item.get("cycle_elapsed_ms", 0)), 0, duration_ms - 1)
		var remaining_window := window_end - window_start
		var cursor_ms := window_start
		while fresh_stock + carried_stock > 0:
			var needed_ms := duration_ms - cycle_elapsed_ms
			if remaining_window < needed_ms:
				break
			cursor_ms += needed_ms
			remaining_window -= needed_ms
			cycle_elapsed_ms = 0
			var unit_price := maxi(0, int(item.get("unit_price", 0)))
			var batch := "fresh"
			var earned_coins := unit_price
			if carried_stock > 0:
				batch = "carried"
				carried_stock -= 1
				earned_coins = int(floor(float(unit_price) * 0.8))
			else:
				fresh_stock -= 1
			events.append({
				"recipe_id": recipe_id,
				"completed_at_ms": cursor_ms,
				"batch": batch,
				"unit_price": unit_price,
				"earned_coins": earned_coins,
				"anchor_cell": item.get("anchor_cell", Vector2i(9999, 9999)),
				"reasons": (item.get("reasons", []) as Array).duplicate(true)
			})
		if fresh_stock + carried_stock > 0:
			cycle_elapsed_ms += remaining_window
		item["fresh_stock"] = fresh_stock
		item["carried_stock"] = carried_stock
		item["cycle_elapsed_ms"] = cycle_elapsed_ms
		item["waiting_for_refill"] = fresh_stock + carried_stock <= 0
		next_states[recipe_id_value] = item
	events.sort_custom(_event_before)
	return {
		"item_states": next_states,
		"events": events
	}


static func refill_item(item_states: Dictionary, recipe_id: String, amount: int, elapsed_ms: int) -> Dictionary:
	var next_states := item_states.duplicate(true)
	if recipe_id.is_empty() or amount <= 0 or not next_states.has(recipe_id):
		return {
			"ok": false,
			"item_states": next_states,
			"refill_event": {},
			"accepted_amount": 0,
			"rejected_amount": maxi(0, amount)
		}
	var item: Dictionary = next_states.get(recipe_id, {})
	var was_waiting := bool(item.get("waiting_for_refill", false)) \
			or int(item.get("fresh_stock", 0)) + int(item.get("carried_stock", 0)) <= 0
	item["fresh_stock"] = maxi(0, int(item.get("fresh_stock", 0))) + amount
	item["waiting_for_refill"] = false
	if was_waiting:
		item["cycle_elapsed_ms"] = 0
	next_states[recipe_id] = item
	return {
		"ok": true,
		"item_states": next_states,
		"accepted_amount": amount,
		"rejected_amount": 0,
		"refill_event": {
			"recipe_id": recipe_id,
			"amount": amount,
			"elapsed_ms": maxi(0, elapsed_ms)
		}
	}


static func _event_before(left: Dictionary, right: Dictionary) -> bool:
	var left_time := int(left.get("completed_at_ms", 0))
	var right_time := int(right.get("completed_at_ms", 0))
	if left_time != right_time:
		return left_time < right_time
	var left_anchor: Vector2i = left.get("anchor_cell", Vector2i(9999, 9999))
	var right_anchor: Vector2i = right.get("anchor_cell", Vector2i(9999, 9999))
	if left_anchor.x != right_anchor.x:
		return left_anchor.x < right_anchor.x
	if left_anchor.y != right_anchor.y:
		return left_anchor.y < right_anchor.y
	return String(left.get("recipe_id", "")) < String(right.get("recipe_id", ""))


static func _anchor_cell(cells_value: Variant) -> Vector2i:
	var result := Vector2i(9999, 9999)
	if not cells_value is Array:
		return result
	for cell_value in cells_value as Array:
		if not cell_value is Vector2i:
			continue
		var cell: Vector2i = cell_value
		if cell.x < result.x or cell.x == result.x and cell.y < result.y:
			result = cell
	return result
