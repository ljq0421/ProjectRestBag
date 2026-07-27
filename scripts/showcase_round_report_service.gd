class_name ShowcaseRoundReportService
extends RefCounted

const ShowcaseRoundSaleService = preload("res://scripts/showcase_round_sale_service.gd")


static func build_report(round_state: Dictionary, clearance: Dictionary = {}) -> Dictionary:
	var initial_item_states: Dictionary = round_state.get("initial_item_states", {})
	var report: Dictionary
	if not bool(round_state.get("live_layout_changed", false)) and not initial_item_states.is_empty():
		report = _build_replayed_report(round_state, clearance, initial_item_states)
	else:
		report = _build_event_report(round_state, clearance)
	return _with_task_contract_fields(report, round_state, clearance)


static func growth_round_flags(events: Array) -> Dictionary:
	var result := {}
	for event_value in events:
		if not event_value is Dictionary:
			continue
		var event: Dictionary = event_value
		var recipe_id := String(event.get("recipe_id", ""))
		var quantity := maxi(0, int(event.get("quantity", 0)))
		var is_clearance := bool(event.get("clearance", false)) or bool(event.get("is_clearance", false)) or bool(event.get("forced_clearance", false))
		if recipe_id.is_empty() or quantity <= 0 or bool(event.get("bonus_only", false)) or is_clearance:
			continue
		var flags: Dictionary = result.get(recipe_id, {
			"growth_effective_round": true,
			"growth_synergy_round": false,
			"real_sale_count": 0,
			"positive_adjacency_sale_count": 0
		})
		flags["real_sale_count"] = int(flags.get("real_sale_count", 0)) + quantity
		if bool(event.get("positive_adjacency", false)):
			flags["growth_synergy_round"] = true
			flags["positive_adjacency_sale_count"] = int(flags.get("positive_adjacency_sale_count", 0)) + quantity
		result[recipe_id] = flags
	return result


static func event_income_breakdown(event: Dictionary) -> Dictionary:
	var earned := maxi(0, int(event.get("earned_coins", 0)))
	var quantity := maxi(0, int(event.get("quantity", 0)))
	var base_income := maxi(0, int(event.get("base_price", 0)))
	var environment_pct := float(event.get("environment_price_pct", 0.0))
	var market_total := maxi(0, int(round(float(base_income) * (1.0 + environment_pct / 100.0))))
	if String(event.get("batch", "fresh")) == "carried":
		base_income = int(floor(float(base_income) * 0.8))
		market_total = int(floor(float(market_total) * 0.8))
	if quantity <= 0:
		base_income = 0
		market_total = 0
	return {
		"total_coins": earned,
		"base_income": base_income,
		"market_income": market_total - base_income,
		"layout_extra_income": earned - market_total
	}


static func _build_replayed_report(round_state: Dictionary, clearance: Dictionary, initial_item_states: Dictionary) -> Dictionary:
	var duration_ms := maxi(0, int(round_state.get("duration_ms", 0)))
	var refills: Array = round_state.get("refill_events", [])
	var base := ShowcaseRoundSaleService.replay_round(initial_item_states, duration_ms, refills, "base")
	var market := ShowcaseRoundSaleService.replay_round(initial_item_states, duration_ms, refills, "market")
	var full := ShowcaseRoundSaleService.replay_round(
		initial_item_states,
		duration_ms,
		refills,
		"full",
		round_state.get("role_snapshot", {}),
		int(round_state.get("chain_max_depth", 4))
	)
	var products := _products_from_events(full.get("events", []), refills)
	_enrich_products(products, round_state, full.get("item_states", {}))
	var top_recipe_id := _top_recipe_id(products)
	var base_income := int(base.get("income", 0))
	var market_total := int(market.get("income", 0))
	var normal_income := int(full.get("income", 0))
	var forced_clearance := maxi(0, int(clearance.get("forced_clearance_coins", 0)))
	var direct_clearance := maxi(0, int(clearance.get("direct_clearance_coins", 0)))
	var clearance_income := forced_clearance + direct_clearance
	return {
		"round_id": int(round_state.get("round_id", 0)),
		"kind": String(round_state.get("kind", "standard")),
		"duration_ms": duration_ms,
		"normal_income": normal_income,
		"base_income": base_income,
		"market_income": market_total - base_income,
		"layout_extra_income": normal_income - market_total,
		"forced_clearance_income": forced_clearance,
		"direct_clearance_income": direct_clearance,
		"clearance_income": clearance_income,
		"total_coins": normal_income + clearance_income,
		"sold_count": int(full.get("sold_count", 0)),
		"top_recipe_id": top_recipe_id,
		"products": products,
		"replay_verified": true
	}


static func _build_event_report(round_state: Dictionary, clearance: Dictionary = {}) -> Dictionary:
	var products := {}
	var normal_income := 0
	var base_income := 0
	var market_income := 0
	var layout_extra_income := 0
	for event_value in round_state.get("sale_events", []):
		if not event_value is Dictionary:
			continue
		var event: Dictionary = event_value
		var recipe_id := String(event.get("recipe_id", ""))
		if recipe_id.is_empty():
			continue
		var quantity := maxi(0, int(event.get("quantity", 0)))
		var breakdown := event_income_breakdown(event)
		var earned := int(breakdown.get("total_coins", 0))
		var batch := String(event.get("batch", "fresh"))
		var base_event := int(breakdown.get("base_income", 0))
		normal_income += earned
		base_income += base_event
		market_income += int(breakdown.get("market_income", 0))
		layout_extra_income += int(breakdown.get("layout_extra_income", 0))
		var product: Dictionary = products.get(recipe_id, _empty_product(recipe_id, int(event.get("anchor_slot", 9999))))
		product["sold_count"] = int(product.get("sold_count", 0)) + quantity
		product["fresh_sale_count"] = int(product.get("fresh_sale_count", 0)) + (quantity if batch == "fresh" else 0)
		product["carried_sale_count"] = int(product.get("carried_sale_count", 0)) + (quantity if batch == "carried" else 0)
		product["earned_coins"] = int(product.get("earned_coins", 0)) + earned
		product["highest_single_sale"] = maxi(int(product.get("highest_single_sale", 0)), earned)
		var rules: Array = product.get("triggered_rules", [])
		for reason_value in event.get("reasons", []):
			var reason := String((reason_value as Dictionary).get("text", "")) if reason_value is Dictionary else String(reason_value)
			if not reason.is_empty() and not rules.has(reason):
				rules.append(reason)
		var chain_source := String(event.get("chain_source", ""))
		if not chain_source.is_empty():
			product["chain_count"] = int(product.get("chain_count", 0)) + 1
			var chain_reason := "热度连锁：%s" % chain_source
			if not rules.has(chain_reason):
				rules.append(chain_reason)
		product["triggered_rules"] = rules
		products[recipe_id] = product
	for refill_value in round_state.get("refill_events", []):
		if not refill_value is Dictionary:
			continue
		var refill: Dictionary = refill_value
		var recipe_id := String(refill.get("recipe_id", ""))
		var product: Dictionary = products.get(recipe_id, _empty_product(recipe_id, 9999))
		product["refill_count"] = int(product.get("refill_count", 0)) + maxi(0, int(refill.get("amount", 0)))
		products[recipe_id] = product
	_enrich_products(products, round_state, round_state.get("item_states", {}))
	var top_recipe_id := ""
	for recipe_id_value in products.keys():
		var recipe_id := String(recipe_id_value)
		if top_recipe_id.is_empty() or _product_before(products.get(recipe_id, {}), products.get(top_recipe_id, {})):
			top_recipe_id = recipe_id
	var forced_clearance := maxi(0, int(clearance.get("forced_clearance_coins", 0)))
	var direct_clearance := maxi(0, int(clearance.get("direct_clearance_coins", 0)))
	var clearance_income := forced_clearance + direct_clearance
	return {
		"round_id": int(round_state.get("round_id", 0)),
		"kind": String(round_state.get("kind", "standard")),
		"duration_ms": int(round_state.get("duration_ms", 0)),
		"normal_income": normal_income,
		"base_income": base_income,
		"market_income": market_income,
		"layout_extra_income": layout_extra_income,
		"forced_clearance_income": forced_clearance,
		"direct_clearance_income": direct_clearance,
		"clearance_income": clearance_income,
		"total_coins": normal_income + clearance_income,
		"sold_count": _sold_count(products),
		"top_recipe_id": top_recipe_id,
		"products": products
	}


static func _products_from_events(events: Array, refills: Array) -> Dictionary:
	var products := {}
	for event_value in events:
		if not event_value is Dictionary:
			continue
		var event: Dictionary = event_value
		var recipe_id := String(event.get("recipe_id", ""))
		if recipe_id.is_empty():
			continue
		var product: Dictionary = products.get(recipe_id, _empty_product(recipe_id, 9999))
		var quantity := maxi(0, int(event.get("quantity", 0)))
		var earned := maxi(0, int(event.get("earned_coins", 0)))
		var batch := String(event.get("batch", "fresh"))
		product["sold_count"] = int(product.get("sold_count", 0)) + quantity
		product["fresh_sale_count"] = int(product.get("fresh_sale_count", 0)) + (quantity if batch == "fresh" else 0)
		product["carried_sale_count"] = int(product.get("carried_sale_count", 0)) + (quantity if batch == "carried" else 0)
		product["earned_coins"] = int(product.get("earned_coins", 0)) + earned
		product["highest_single_sale"] = maxi(int(product.get("highest_single_sale", 0)), earned)
		var rules: Array = product.get("triggered_rules", [])
		for reason_value in event.get("reasons", []):
			var reason := String((reason_value as Dictionary).get("text", "")) if reason_value is Dictionary else String(reason_value)
			if not reason.is_empty() and not rules.has(reason):
				rules.append(reason)
		var chain_source := String(event.get("chain_source", ""))
		if not chain_source.is_empty():
			product["chain_count"] = int(product.get("chain_count", 0)) + 1
			var chain_reason := "热度连锁：%s" % chain_source
			if not rules.has(chain_reason):
				rules.append(chain_reason)
		product["triggered_rules"] = rules
		products[recipe_id] = product
	for refill_value in refills:
		if not refill_value is Dictionary:
			continue
		var refill: Dictionary = refill_value
		var recipe_id := String(refill.get("recipe_id", ""))
		if recipe_id.is_empty():
			continue
		var product: Dictionary = products.get(recipe_id, _empty_product(recipe_id, 9999))
		product["refill_count"] = int(product.get("refill_count", 0)) + maxi(0, int(refill.get("amount", 0)))
		products[recipe_id] = product
	return products


static func _enrich_products(products: Dictionary, round_state: Dictionary, final_item_states: Dictionary) -> void:
	var role_snapshot: Dictionary = round_state.get("role_snapshot", {})
	for recipe_id_value in products.keys():
		var recipe_id := String(recipe_id_value)
		var product: Dictionary = products.get(recipe_id, {})
		var role_data: Dictionary = role_snapshot.get(recipe_id, {})
		product["role"] = String(role_data.get("role", "—"))
		var role_reason := String(role_data.get("role_reason", ""))
		if not role_reason.is_empty():
			var rules: Array = product.get("triggered_rules", [])
			if not rules.has(role_reason):
				rules.append(role_reason)
			product["triggered_rules"] = rules
		var item: Dictionary = final_item_states.get(recipe_id, {})
		product["anchor_cell"] = _anchor_cell_from_value(item.get("anchor_cell", Vector2i(9999, 9999)))
		product["next_sale_gap_ms"] = -1
		if int(item.get("fresh_stock", 0)) + int(item.get("carried_stock", 0)) > 0:
			product["next_sale_gap_ms"] = maxi(0, int(item.get("duration_ms", 0)) - int(item.get("cycle_elapsed_ms", 0)))
		products[recipe_id] = product


static func _top_recipe_id(products: Dictionary) -> String:
	var result := ""
	for recipe_id_value in products.keys():
		var recipe_id := String(recipe_id_value)
		if result.is_empty() or _product_before(products.get(recipe_id, {}), products.get(result, {})):
			result = recipe_id
	return result


static func _empty_product(recipe_id: String, anchor_slot: int) -> Dictionary:
	return {
		"recipe_id": recipe_id,
		"anchor_slot": anchor_slot,
		"anchor_cell": Vector2i(9999, 9999),
		"sold_count": 0,
		"fresh_sale_count": 0,
		"carried_sale_count": 0,
		"earned_coins": 0,
		"highest_single_sale": 0,
		"refill_count": 0,
		"chain_count": 0,
		"role": "—",
		"next_sale_gap_ms": -1,
		"triggered_rules": []
	}


static func _product_before(left: Dictionary, right: Dictionary) -> bool:
	var left_income := int(left.get("earned_coins", 0))
	var right_income := int(right.get("earned_coins", 0))
	if left_income != right_income:
		return left_income > right_income
	var left_count := int(left.get("sold_count", 0))
	var right_count := int(right.get("sold_count", 0))
	if left_count != right_count:
		return left_count > right_count
	var left_cell := _anchor_cell_from_value(left.get("anchor_cell", Vector2i(9999, 9999)))
	var right_cell := _anchor_cell_from_value(right.get("anchor_cell", Vector2i(9999, 9999)))
	if left_cell != right_cell:
		return left_cell.x < right_cell.x or left_cell.x == right_cell.x and left_cell.y < right_cell.y
	var left_anchor := int(left.get("anchor_slot", 9999))
	var right_anchor := int(right.get("anchor_slot", 9999))
	if left_anchor != right_anchor:
		return left_anchor < right_anchor
	return String(left.get("recipe_id", "")) < String(right.get("recipe_id", ""))


static func _anchor_cell_from_value(value: Variant) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Array and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return Vector2i(9999, 9999)


static func _sold_count(products: Dictionary) -> int:
	var result := 0
	for product_value in products.values():
		if product_value is Dictionary:
			result += int((product_value as Dictionary).get("sold_count", 0))
	return result


static func _with_task_contract_fields(report: Dictionary, round_state: Dictionary, clearance: Dictionary) -> Dictionary:
	var result := report.duplicate(true)
	var products: Dictionary = result.get("products", {})
	var growth_flags := growth_round_flags(round_state.get("sale_events", []))
	for recipe_id_value in products.keys():
		var recipe_id := String(recipe_id_value)
		var product: Dictionary = products.get(recipe_id_value, {})
		var flags: Dictionary = growth_flags.get(recipe_id, {})
		product["growth_effective_round"] = bool(flags.get("growth_effective_round", false))
		product["growth_synergy_round"] = bool(flags.get("growth_synergy_round", false))
		product["real_sale_count"] = maxi(0, int(flags.get("real_sale_count", 0)))
		product["positive_adjacency_sale_count"] = maxi(0, int(flags.get("positive_adjacency_sale_count", 0)))
		products[recipe_id_value] = product
	result["products"] = products
	var challenge: Dictionary = round_state.get("challenge", {})
	var environment_value: Variant = round_state.get("environment", {})
	var environment: Dictionary = environment_value.duplicate(true) if environment_value is Dictionary else {}
	result["report_id"] = String(clearance.get("settlement_id", ""))
	result["challenge_id"] = String(challenge.get("id", ""))
	result["challenge_version"] = maxi(0, int(challenge.get("version", 0)))
	result["environment"] = environment
	result["layout_snapshot"] = _serialize_safe_value(round_state.get("layout_snapshot", {}))
	result["layout"] = _layout_summary(round_state)
	var product_totals := _product_task_totals(result.get("products", {}))
	result["max_product_sold"] = int(product_totals.get("max_product_sold", 0))
	result["sold_distinct_recipes"] = int(product_totals.get("sold_distinct_recipes", 0))
	result["counts"] = _task_counts(result, round_state, clearance)
	var missing_fields := _missing_task_contract_fields(result, round_state)
	result["missing_fields"] = missing_fields
	result["is_complete"] = missing_fields.is_empty()
	return _serialize_safe_value(result) as Dictionary


static func _layout_summary(round_state: Dictionary) -> Dictionary:
	var layout_value: Variant = round_state.get("layout_snapshot", {})
	var layout_snapshot: Dictionary = layout_value if layout_value is Dictionary else {}
	var occupied_cells := {}
	var distinct_recipes := 0
	for item_value in layout_snapshot.values():
		if not item_value is Dictionary:
			continue
		distinct_recipes += 1
		for cell_value in (item_value as Dictionary).get("cells", []):
			var cell := _anchor_cell_from_value(cell_value)
			if cell != Vector2i(9999, 9999):
				occupied_cells["%d:%d" % [cell.x, cell.y]] = true

	var role_counts := {}
	var roles_value: Variant = round_state.get("role_snapshot", {})
	if roles_value is Dictionary:
		for role_value in (roles_value as Dictionary).values():
			if not role_value is Dictionary:
				continue
			var role := String((role_value as Dictionary).get("role", ""))
			if not role.is_empty():
				role_counts[role] = int(role_counts.get(role, 0)) + 1

	var tag_counts := {}
	var tags_value: Variant = round_state.get("tag_snapshot", {})
	if tags_value is Dictionary:
		for recipe_tags_value in (tags_value as Dictionary).values():
			if not recipe_tags_value is Array:
				continue
			for tag_value in recipe_tags_value:
				var tag := String(tag_value)
				if not tag.is_empty():
					tag_counts[tag] = int(tag_counts.get(tag, 0)) + 1
	return {
		"occupied_cells": occupied_cells.size(),
		"distinct_recipes": distinct_recipes,
		"distinct_roles": role_counts.size(),
		"max_shared_tag": _maximum_count(tag_counts),
		"role_counts": role_counts,
		"tag_counts": tag_counts
	}


static func _product_task_totals(products_value: Variant) -> Dictionary:
	var max_product_sold := 0
	var sold_distinct_recipes := 0
	if products_value is Dictionary:
		for product_value in (products_value as Dictionary).values():
			if not product_value is Dictionary:
				continue
			var sold_count := maxi(0, int((product_value as Dictionary).get("sold_count", 0)))
			max_product_sold = maxi(max_product_sold, sold_count)
			if sold_count > 0:
				sold_distinct_recipes += 1
	return {
		"max_product_sold": max_product_sold,
		"sold_distinct_recipes": sold_distinct_recipes
	}


static func _maximum_count(counts: Dictionary) -> int:
	var result := 0
	for count_value in counts.values():
		result = maxi(result, int(count_value))
	return result


static func _task_counts(report: Dictionary, round_state: Dictionary, clearance: Dictionary) -> Dictionary:
	var chain_triggers := 0
	var products_value: Variant = report.get("products", {})
	if products_value is Dictionary:
		for product_value in (products_value as Dictionary).values():
			if product_value is Dictionary:
				chain_triggers += maxi(0, int((product_value as Dictionary).get("chain_count", 0)))
	var refill_actions := 0
	var refilled_items := 0
	for refill_value in round_state.get("refill_events", []):
		if not refill_value is Dictionary:
			continue
		refill_actions += 1
		refilled_items += maxi(0, int((refill_value as Dictionary).get("amount", 0)))
	var waiting_for_refill := 0
	var states_value: Variant = round_state.get("item_states", {})
	if states_value is Dictionary:
		for item_value in (states_value as Dictionary).values():
			if item_value is Dictionary and bool((item_value as Dictionary).get("waiting_for_refill", false)):
				waiting_for_refill += 1
	return {
		"sold": maxi(0, int(report.get("sold_count", 0))),
		"chain_triggers": chain_triggers,
		"refill_actions": refill_actions,
		"refilled_items": refilled_items,
		"waiting_for_refill": waiting_for_refill,
		"forced_clearance": maxi(0, int(clearance.get("forced_clearance_count", 0))),
		"direct_clearance": maxi(0, int(clearance.get("direct_clearance_count", 0))),
		"carried_leftovers": maxi(0, int(clearance.get("carried_leftover_count", 0)))
	}


static func _missing_task_contract_fields(report: Dictionary, round_state: Dictionary) -> Array[String]:
	var result: Array[String] = []
	if String(report.get("report_id", "")).is_empty():
		result.append("report_id")
	if int(report.get("round_id", 0)) <= 0:
		result.append("round_id")
	if int(report.get("duration_ms", 0)) <= 0:
		result.append("duration_ms")
	if not round_state.get("layout_snapshot", null) is Dictionary:
		result.append("layout_snapshot")
	if not round_state.get("item_states", null) is Dictionary:
		result.append("item_states")
	if not round_state.get("environment", null) is Dictionary:
		result.append("environment")
	return result


static func _serialize_safe_value(value: Variant) -> Variant:
	if value is Vector2i:
		return [value.x, value.y]
	if value is Vector2:
		return [value.x, value.y]
	if value is Dictionary:
		var result := {}
		for key_value in (value as Dictionary).keys():
			result[key_value] = _serialize_safe_value((value as Dictionary).get(key_value))
		return result
	if value is Array:
		var result: Array = []
		for child in value as Array:
			result.append(_serialize_safe_value(child))
		return result
	return value
