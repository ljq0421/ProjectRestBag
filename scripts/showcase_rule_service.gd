class_name ShowcaseRuleService
extends RefCounted

const ShopSimulation = preload("res://scripts/shop_simulation.gd")
const ShowcaseRegionService = preload("res://scripts/showcase_region_service.gd")
const Catalog = preload("res://scripts/catalog.gd")

const VARIANT_RULES := {
	"standard": {"id": "standard", "label": "标准", "price_pct": 0.0, "speed_pct": 0.0},
	"small": {"id": "small", "label": "小份", "price_pct": -15.0, "speed_pct": 25.0},
	"gift_box": {"id": "gift_box", "label": "礼盒", "price_pct": 25.0, "speed_pct": -10.0},
	"large": {"id": "large", "label": "大份", "price_pct": 10.0, "speed_pct": -15.0},
	"sample": {"id": "sample", "label": "试吃", "price_pct": -35.0, "speed_pct": 40.0, "reputation_delta": 1}
}

const THEME_RULES := {
	"summer": {"label": "夏日", "tags": ["清爽", "果香", "清凉"], "price_pct": 0.0, "speed_pct": 8.0},
	"retro": {"label": "复古", "tags": ["经典", "茶香", "浓郁"], "price_pct": 6.0, "speed_pct": 0.0},
	"tea": {"label": "茶会", "tags": ["茶香", "苦甜", "甜"], "price_pct": 4.0, "speed_pct": 4.0}
}

const PROP_RULES := {
	"cake_stand": {"label": "蛋糕架", "unlock_level": 2, "effect_text": "相邻商品售价 +4%，售速 +4%"},
	"chilled_case": {"label": "冷藏展示柜", "unlock_level": 3, "effect_text": "相邻清爽/果香/清凉商品售速 +8%"},
	"retro_tray": {"label": "复古托盘", "unlock_level": 4, "effect_text": "相邻经典/茶香/浓郁商品售价 +5%"},
	"sample_sign": {"label": "试吃牌", "unlock_level": 4, "effect_text": "相邻小份/试吃变体售速 +10%"},
	"gift_corner": {"label": "礼盒角", "unlock_level": 5, "effect_text": "相邻礼盒变体售价 +10%"}
}

const MAX_PRICE_MULTIPLIER := 1.8
const MAX_SPEED_MULTIPLIER := 2.0


static func calculate(state, recipes: Dictionary, display_rules: Dictionary) -> Dictionary:
	var raw_bonuses: Dictionary = ShopSimulation._calculate_all_product_bonuses(state, recipes, display_rules)
	var catalog := Catalog.new()
	var display_config := catalog.get_recipe_display_config()
	var round_rules := catalog.get_showcase_round_rules()
	var items := {}
	for recipe_id_value in raw_bonuses.keys():
		var recipe_id := String(recipe_id_value)
		var bonus: Dictionary = raw_bonuses[recipe_id_value]
		_apply_variant_bonus(state, recipe_id, bonus)
		_apply_prop_bonus(state, recipe_id, recipes.get(recipe_id, {}), bonus)
		_apply_theme_bonus(state, recipe_id, recipes.get(recipe_id, {}), bonus)
		_apply_spacing_bonus(state, recipe_id, display_config, round_rules, display_rules, bonus)
		bonus["price_multiplier"] = clampf(float(bonus.get("price_multiplier", 1.0)), 0.25, MAX_PRICE_MULTIPLIER)
		bonus["speed_multiplier"] = clampf(float(bonus.get("speed_multiplier", 1.0)), 0.25, MAX_SPEED_MULTIPLIER)
		var price_multiplier := float(bonus.get("price_multiplier", 1.0))
		var speed_multiplier := float(bonus.get("speed_multiplier", 1.0))
		items[recipe_id] = {
			"recipe_id": recipe_id,
			"price_multiplier": price_multiplier,
			"speed_multiplier": speed_multiplier,
			"reputation_delta": _reputation_delta(price_multiplier) + int(bonus.get("reputation_delta", 0)),
			"demand_weight_delta": speed_multiplier - 1.0,
			"reasons": _reason_entries(bonus),
			"breakdown": bonus.get("breakdown", {})
		}
	return {
		"ok": true,
		"items": items,
		"summary": _summary(items, state)
	}


static func set_progress(display_items: Dictionary, recipes: Dictionary, set_rules: Dictionary) -> Array[Dictionary]:
	var product_cells_map: Dictionary = {}
	for recipe_id_value in display_items.keys():
		var recipe_id := String(recipe_id_value)
		var item_value: Variant = display_items.get(recipe_id_value, {})
		if recipe_id.is_empty() or not item_value is Dictionary or not recipes.has(recipe_id):
			continue
		var cells_value: Variant = (item_value as Dictionary).get("cells", [])
		if cells_value is Array and not (cells_value as Array).is_empty():
			product_cells_map[recipe_id] = cells_value
	if product_cells_map.is_empty() or set_rules.is_empty():
		return []

	var active_set_ids: Dictionary = {}
	var calculated: Dictionary = ShopSimulation._calc_set_bonuses(product_cells_map, recipes, set_rules)
	for bonus_value in calculated.values():
		if not bonus_value is Dictionary:
			continue
		for group_value in (bonus_value as Dictionary).get("groups", []):
			if group_value is Dictionary:
				var set_id := String((group_value as Dictionary).get("id", ""))
				if not set_id.is_empty():
					active_set_ids[set_id] = true

	var result: Array[Dictionary] = []
	var config_order := 0
	for set_id_value in set_rules.keys():
		var set_id := String(set_id_value)
		var set_rule_value: Variant = set_rules.get(set_id_value, {})
		if not set_rule_value is Dictionary:
			config_order += 1
			continue
		var set_rule: Dictionary = set_rule_value
		var required_tags: Array = set_rule.get("required_tags", [])
		var contributing_ids: Array[String] = []
		for recipe_id_value in product_cells_map.keys():
			var recipe_id := String(recipe_id_value)
			if _set_tag_mask((recipes.get(recipe_id, {}) as Dictionary).get("tags", []), required_tags) != 0:
				contributing_ids.append(recipe_id)
		if contributing_ids.is_empty():
			config_order += 1
			continue

		var missing_count := _minimum_set_additions(contributing_ids, recipes, required_tags, maxi(1, int(set_rule.get("min_item_count", 3))))
		var status := "missing_items"
		if active_set_ids.has(set_id):
			status = "active"
			missing_count = 0
		elif missing_count == 0:
			status = "needs_connection"
		result.append({
			"set_id": set_id,
			"set_name": String(set_rule.get("set_name", set_id)),
			"status": status,
			"missing_count": missing_count,
			"config_order": config_order
		})
		config_order += 1

	result.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_active := String(left.get("status", "")) == "active"
		var right_active := String(right.get("status", "")) == "active"
		if left_active != right_active:
			return left_active
		var left_missing := int(left.get("missing_count", 0))
		var right_missing := int(right.get("missing_count", 0))
		if left_missing != right_missing:
			return left_missing < right_missing
		return int(left.get("config_order", 0)) < int(right.get("config_order", 0))
	)
	return result


static func _minimum_set_additions(
		contributing_ids: Array[String],
		recipes: Dictionary,
		required_tags: Array,
		min_item_count: int
) -> int:
	var full_mask := (1 << required_tags.size()) - 1
	var current_mask := 0
	for recipe_id in contributing_ids:
		current_mask |= _set_tag_mask((recipes.get(recipe_id, {}) as Dictionary).get("tags", []), required_tags)
	var start_count := mini(min_item_count, contributing_ids.size())
	if start_count >= min_item_count and current_mask == full_mask:
		return 0

	var states := {"%d:%d" % [current_mask, start_count]: {"mask": current_mask, "count": start_count, "added": 0}}
	for recipe_id_value in recipes.keys():
		var recipe_id := String(recipe_id_value)
		if contributing_ids.has(recipe_id):
			continue
		var recipe_value: Variant = recipes.get(recipe_id_value, {})
		if not recipe_value is Dictionary:
			continue
		var tag_mask := _set_tag_mask((recipe_value as Dictionary).get("tags", []), required_tags)
		if tag_mask == 0:
			continue
		var next_states: Dictionary = states.duplicate(true)
		for state_value in states.values():
			var state: Dictionary = state_value
			var next_mask := int(state.get("mask", 0)) | tag_mask
			var next_count := mini(min_item_count, int(state.get("count", 0)) + 1)
			var next_added := int(state.get("added", 0)) + 1
			var key := "%d:%d" % [next_mask, next_count]
			if not next_states.has(key) or next_added < int((next_states[key] as Dictionary).get("added", 0)):
				next_states[key] = {"mask": next_mask, "count": next_count, "added": next_added}
		states = next_states

	var best := 1_000_000
	for state_value in states.values():
		var state: Dictionary = state_value
		if int(state.get("mask", 0)) == full_mask and int(state.get("count", 0)) >= min_item_count:
			best = mini(best, int(state.get("added", 0)))
	if best < 1_000_000:
		return best
	var missing_tags := required_tags.size() - _set_bit_count(current_mask)
	return maxi(min_item_count - contributing_ids.size(), missing_tags)


static func _set_tag_mask(tags: Array, required_tags: Array) -> int:
	var mask := 0
	for index in range(required_tags.size()):
		if tags.has(required_tags[index]):
			mask |= 1 << index
	return mask


static func _set_bit_count(value: int) -> int:
	var count := 0
	var remaining := value
	while remaining > 0:
		count += remaining & 1
		remaining >>= 1
	return count


static func variant_definition(recipe_id: String, variant_id: String, display_config: Dictionary) -> Dictionary:
	var clean_variant_id := "standard" if variant_id.is_empty() else variant_id
	var base_rule: Dictionary = VARIANT_RULES.get(clean_variant_id, VARIANT_RULES["standard"])
	var recipe_display: Dictionary = display_config.get("recipes", {}).get(recipe_id, {})
	var base_cells := _shape_cells_from_display(recipe_display)
	var base_count := base_cells.size() if not base_cells.is_empty() else maxi(1, int(recipe_display.get("cell_count", 1)))
	var cell_count := base_count
	match clean_variant_id:
		"small", "sample":
			cell_count = 1
		"gift_box", "large":
			cell_count = base_count + 1
	return {
		"id": clean_variant_id,
		"label": String(base_rule.get("label", clean_variant_id)),
		"cell_count": cell_count,
		"base_cell_count": base_count,
		"price_pct": float(base_rule.get("price_pct", 0.0)),
		"speed_pct": float(base_rule.get("speed_pct", 0.0)),
		"reputation_delta": int(base_rule.get("reputation_delta", 0)),
		"shape_category": String(recipe_display.get("shape_category", ""))
	}


static func sale_attribution(base_price: int, final_price: int, bonus: Dictionary) -> Dictionary:
	var safe_base := maxi(0, base_price)
	var safe_final := maxi(0, final_price)
	var breakdown: Dictionary = bonus.get("breakdown", {})
	var conflict_pct := minf(0.0, _part_price_pct(breakdown.get("conflict", {})))
	var conflict_loss := maxi(0, int(round(float(safe_base) * absf(conflict_pct) / 100.0)))
	var positive_pool := maxi(0, safe_final - safe_base + conflict_loss)
	var position_weight := maxf(0.0, _part_price_pct(breakdown.get("zone", {}))) \
			+ maxf(0.0, _part_price_pct(breakdown.get("adjacency_tag", {})))
	var set_weight := maxf(0.0, _part_price_pct(breakdown.get("set", {}))) \
			+ maxf(0.0, _part_price_pct(breakdown.get("growth", {})))
	var known_weight := position_weight + set_weight
	var position_coins := 0
	var set_coins := 0
	if known_weight > 0.0:
		position_coins = int(round(float(positive_pool) * position_weight / known_weight))
		set_coins = positive_pool - position_coins
	var other_delta := safe_final - safe_base - position_coins - set_coins + conflict_loss
	return {
		"base_coins": safe_base,
		"position_adjacency_coins": position_coins,
		"set_growth_coins": set_coins,
		"other_delta": other_delta,
		"conflict_loss": conflict_loss
	}


static func sale_context(bonus: Dictionary) -> Dictionary:
	var breakdown: Dictionary = bonus.get("breakdown", {})
	var set_part: Dictionary = breakdown.get("set", {})
	var groups: Array = set_part.get("groups", [])
	var related: Array[String] = []
	for key in ["adjacency_tag", "set"]:
		var part: Dictionary = breakdown.get(key, {})
		_append_unique_strings(related, part.get("related_recipe_ids", []))
	var conflicts: Array[String] = []
	var conflict_part: Dictionary = breakdown.get("conflict", {})
	_append_unique_strings(conflicts, conflict_part.get("related_recipe_ids", []))
	return {
		"groups": groups.duplicate(true),
		"related_recipe_ids": related,
		"conflict_recipe_ids": conflicts
	}


static func rule_difference(before_bonus: Dictionary, after_bonus: Dictionary) -> Dictionary:
	var before_by_key := _reason_map(before_bonus.get("reasons", []))
	var after_by_key := _reason_map(after_bonus.get("reasons", []))
	var added: Array[String] = []
	var lost: Array[String] = []
	var risks: Array[String] = []
	var after_keys := after_by_key.keys()
	after_keys.sort()
	for key in after_keys:
		var entry: Dictionary = after_by_key[key]
		var text := String(entry.get("text", ""))
		if not before_by_key.has(key) and not text.is_empty():
			added.append(text)
		if _is_risk_reason(entry) and not risks.has(text):
			risks.append(text)
	var before_keys := before_by_key.keys()
	before_keys.sort()
	for key in before_keys:
		if after_by_key.has(key):
			continue
		var text := String((before_by_key[key] as Dictionary).get("text", ""))
		if not text.is_empty():
			lost.append(text)
	return {"added": added, "lost": lost, "risks": risks}


static func spacing_bonus(
		product_cells: Array,
		all_product_cells: Array,
		prop_cells: Array,
		unlocked_layout: Variant,
		eligible_for_boutique: bool,
		rule: Dictionary
) -> Dictionary:
	var result := {"price_pct": 0.0, "speed_pct": 0.0, "reasons": [], "active": false, "empty_perimeter_count": 0}
	var unlocked_cells := _unlocked_cells_from_layout(unlocked_layout)
	var unlocked_count := unlocked_cells.size()
	var unlock_cell_count := maxi(1, int(rule.get("unlock_cell_count", 36)))
	if unlocked_count < unlock_cell_count:
		result.reasons = ["规则预告：橱窗扩张到 %d 个已解锁格后开放精品留白与陈列拥挤" % unlock_cell_count]
		return result
	result.active = true
	var own_keys := _cell_key_set(product_cells)
	var occupied_keys := _cell_key_set(all_product_cells)
	var prop_keys := _cell_key_set(prop_cells)
	var perimeter_keys: Dictionary = {}
	for cell_value in product_cells:
		if not cell_value is Vector2i:
			continue
		var cell := cell_value as Vector2i
		for neighbor in [Vector2i(cell.x - 1, cell.y), Vector2i(cell.x + 1, cell.y), Vector2i(cell.x, cell.y - 1), Vector2i(cell.x, cell.y + 1)]:
			var key := _cell_key(neighbor)
			if not own_keys.has(key) and unlocked_cells.has(neighbor):
				perimeter_keys[key] = neighbor
	var empty_count := 0
	for key in perimeter_keys.keys():
		if not occupied_keys.has(key) and not prop_keys.has(key):
			empty_count += 1
	result.empty_perimeter_count = empty_count
	var required_empty := maxi(1, int(rule.get("required_empty_perimeter", 2)))
	if eligible_for_boutique and empty_count >= required_empty:
		result.price_pct = float(rule.get("boutique_price_pct", 6.0))
		result.reasons = ["受精品留白影响：四方向外沿有 %d 个已解锁空格，售价 %+.0f%%" % [empty_count, float(result.price_pct)]]
	elif empty_count == 0:
		result.speed_pct = float(rule.get("crowded_speed_pct", -6.0))
		result.reasons = ["受陈列拥挤影响：四方向外沿没有已解锁空格，售速 %+.0f%%" % float(result.speed_pct)]
	return result


static func _cell_key_set(cells_value: Variant) -> Dictionary:
	var result := {}
	if not cells_value is Array:
		return result
	for cell_value in cells_value as Array:
		if cell_value is Vector2i:
			result[_cell_key(cell_value as Vector2i)] = true
	return result


static func _cell_key(cell: Vector2i) -> String:
	return "%d:%d" % [cell.x, cell.y]


static func _reason_map(values_value: Variant) -> Dictionary:
	var result := {}
	if not values_value is Array:
		return result
	for value in values_value as Array:
		if not value is Dictionary:
			continue
		var entry: Dictionary = value
		var text := String(entry.get("text", "")).strip_edges()
		if text.is_empty():
			continue
		var key := "%s|%s" % [String(entry.get("source", "")), text]
		result[key] = entry.duplicate(true)
	return result


static func _is_risk_reason(entry: Dictionary) -> bool:
	var source := String(entry.get("source", ""))
	var text := String(entry.get("text", ""))
	return source == "conflict" \
		or float(entry.get("price_pct", 0.0)) < 0.0 \
		or float(entry.get("speed_pct", 0.0)) < 0.0 \
		or text.contains("跨区") \
		or text.contains("拥挤") \
		or text.contains("断链") \
		or text.contains("未解锁")


static func _part_price_pct(part_value: Variant) -> float:
	if not part_value is Dictionary:
		return 0.0
	return float((part_value as Dictionary).get("price_pct", 0.0))


static func _append_unique_strings(target: Array[String], values: Variant) -> void:
	if not values is Array:
		return
	for value in values as Array:
		var value_text := String(value)
		if not value_text.is_empty() and not target.has(value_text):
			target.append(value_text)


static func _reputation_delta(price_multiplier: float) -> int:
	var price_pct := (price_multiplier - 1.0) * 100.0
	return int(round(clampf(price_pct / 10.0, -3.0, 5.0)))


static func _apply_variant_bonus(state, recipe_id: String, bonus: Dictionary) -> void:
	var item: Dictionary = _display_items(state).get(recipe_id, {})
	var variant_id := String(item.get("variant_id", "standard"))
	var rule: Dictionary = VARIANT_RULES.get(variant_id, VARIANT_RULES["standard"])
	var price_pct := float(rule.get("price_pct", 0.0))
	var speed_pct := float(rule.get("speed_pct", 0.0))
	var reputation_delta := int(rule.get("reputation_delta", 0))
	if absf(price_pct) < 0.01 and absf(speed_pct) < 0.01 and reputation_delta == 0:
		return
	bonus["price_multiplier"] = float(bonus.get("price_multiplier", 1.0)) * (1.0 + price_pct / 100.0)
	bonus["speed_multiplier"] = float(bonus.get("speed_multiplier", 1.0)) * (1.0 + speed_pct / 100.0)
	bonus["reputation_delta"] = int(bonus.get("reputation_delta", 0)) + reputation_delta
	var breakdown: Dictionary = bonus.get("breakdown", {})
	var reason := "%s变体：售价 %+.0f%%，售速 %+.0f%%" % [String(rule.get("label", variant_id)), price_pct, speed_pct]
	if reputation_delta != 0:
		reason += "，真实成交额外口碑 %+.0f" % reputation_delta
	breakdown["variant"] = {
		"price_pct": price_pct,
		"speed_pct": speed_pct,
		"reputation_delta": reputation_delta,
		"variant_id": variant_id,
		"reasons": [reason]
	}
	bonus["breakdown"] = breakdown


static func _apply_prop_bonus(state, recipe_id: String, recipe: Dictionary, bonus: Dictionary) -> void:
	var item: Dictionary = _display_items(state).get(recipe_id, {})
	var product_cells: Array = item.get("cells", [])
	if product_cells.is_empty():
		return
	var display_props := _display_props(state)
	if display_props.is_empty():
		return
	var tags: Array = recipe.get("tags", [])
	var variant_id := String(item.get("variant_id", "standard"))
	var part := {"price_pct": 0.0, "speed_pct": 0.0, "reasons": []}
	for prop_id_value in display_props.keys():
		var prop_id := String(prop_id_value)
		var prop: Dictionary = display_props[prop_id_value]
		if not _cells_touch(product_cells, prop.get("cells", [])):
			continue
		match prop_id:
			"cake_stand":
				part.price_pct += 4.0
				part.speed_pct += 4.0
				_append_reason(part, "蛋糕架强化相邻陈列商品")
			"chilled_case":
				if tags.has("清爽") or tags.has("果香") or tags.has("清凉"):
					part.speed_pct += 8.0
					_append_reason(part, "冷藏展示柜强化清爽/果香/清凉商品售速")
			"retro_tray":
				if tags.has("经典") or tags.has("茶香") or tags.has("浓郁"):
					part.price_pct += 5.0
					_append_reason(part, "复古托盘强化经典和香气路线")
			"sample_sign":
				if variant_id == "small" or variant_id == "sample":
					part.speed_pct += 10.0
					_append_reason(part, "试吃牌强化小份和试吃变体")
			"gift_corner":
				if variant_id == "gift_box":
					part.price_pct += 10.0
					_append_reason(part, "礼盒角强化礼盒变体")
	if absf(float(part.price_pct)) < 0.01 and absf(float(part.speed_pct)) < 0.01:
		return
	bonus["price_multiplier"] = float(bonus.get("price_multiplier", 1.0)) * (1.0 + float(part.price_pct) / 100.0)
	bonus["speed_multiplier"] = float(bonus.get("speed_multiplier", 1.0)) * (1.0 + float(part.speed_pct) / 100.0)
	var breakdown: Dictionary = bonus.get("breakdown", {})
	breakdown["prop"] = part
	bonus["breakdown"] = breakdown


static func _apply_theme_bonus(state, _recipe_id: String, recipe: Dictionary, bonus: Dictionary) -> void:
	var theme_id := _showcase_theme_id(state)
	if theme_id.is_empty() or not THEME_RULES.has(theme_id):
		return
	var theme: Dictionary = THEME_RULES[theme_id]
	var required_tags: Array = theme.get("tags", [])
	var tags: Array = recipe.get("tags", [])
	var matched := false
	for tag in required_tags:
		if tags.has(tag):
			matched = true
			break
	if not matched:
		return
	var price_pct := float(theme.get("price_pct", 0.0))
	var speed_pct := float(theme.get("speed_pct", 0.0))
	bonus["price_multiplier"] = float(bonus.get("price_multiplier", 1.0)) * (1.0 + price_pct / 100.0)
	bonus["speed_multiplier"] = float(bonus.get("speed_multiplier", 1.0)) * (1.0 + speed_pct / 100.0)
	var breakdown: Dictionary = bonus.get("breakdown", {})
	breakdown["theme"] = {
		"price_pct": price_pct,
		"speed_pct": speed_pct,
		"theme_id": theme_id,
		"reasons": ["%s主题强化匹配标签商品" % String(theme.get("label", theme_id))]
	}
	bonus["breakdown"] = breakdown


static func _apply_spacing_bonus(
		state,
		recipe_id: String,
		display_config: Dictionary,
		round_rules: Dictionary,
		display_rules: Dictionary,
		bonus: Dictionary
) -> void:
	var rule: Dictionary = display_rules.get("spacing_rules", {})
	if rule.is_empty():
		return
	var item: Dictionary = _display_items(state).get(recipe_id, {})
	var product_cells: Array = item.get("cells", [])
	if product_cells.is_empty():
		return
	var all_product_cells: Array = []
	for display_item_value in _display_items(state).values():
		if display_item_value is Dictionary:
			all_product_cells.append_array((display_item_value as Dictionary).get("cells", []))
	var prop_cells: Array = []
	for prop_value in _display_props(state).values():
		if prop_value is Dictionary:
			prop_cells.append_array((prop_value as Dictionary).get("cells", []))
	var recipe_display: Dictionary = display_config.get("recipes", {}).get(recipe_id, {})
	var shape_category := String(recipe_display.get("shape_category", ""))
	var template: Dictionary = round_rules.get("shape_templates", {}).get(shape_category, {})
	var role := String(template.get("role", ""))
	var eligible_shapes: Array = rule.get("eligible_shape_categories", [])
	var eligible_roles: Array = rule.get("eligible_roles", [])
	var eligible := eligible_shapes.has(shape_category) or eligible_roles.has(role)
	var unlocked_cells: Array = ShowcaseRegionService.cells_for_bounds(ShowcaseRegionService.default_bounds())
	if state != null and state.has_method("get_showcase_unlocked_cells"):
		unlocked_cells = state.get_showcase_unlocked_cells()
	var part := spacing_bonus(product_cells, all_product_cells, prop_cells, unlocked_cells, eligible, rule)
	if not bool(part.get("active", false)):
		return
	if absf(float(part.get("price_pct", 0.0))) < 0.01 and absf(float(part.get("speed_pct", 0.0))) < 0.01:
		return
	bonus["price_multiplier"] = float(bonus.get("price_multiplier", 1.0)) * (1.0 + float(part.get("price_pct", 0.0)) / 100.0)
	bonus["speed_multiplier"] = float(bonus.get("speed_multiplier", 1.0)) * (1.0 + float(part.get("speed_pct", 0.0)) / 100.0)
	var breakdown: Dictionary = bonus.get("breakdown", {})
	breakdown["spacing"] = part
	bonus["breakdown"] = breakdown


static func _summary(items: Dictionary, state) -> Dictionary:
	var positive_count := 0
	var conflict_count := 0
	var listed_count := items.size()
	var total_price_delta := 0.0
	var total_speed_delta := 0.0
	var set_ids: Dictionary = {}
	var strongest_by_key: Dictionary = {}
	for item in items.values():
		if not item is Dictionary:
			continue
		var item_data: Dictionary = item
		total_price_delta += (float(item_data.get("price_multiplier", 1.0)) - 1.0) * 100.0
		total_speed_delta += (float(item_data.get("speed_multiplier", 1.0)) - 1.0) * 100.0
		for reason in item_data.get("reasons", []):
			if not reason is Dictionary:
				continue
			var source := String((reason as Dictionary).get("source", ""))
			if source == "conflict":
				conflict_count += 1
			elif source != "":
				positive_count += 1
			var reason_data: Dictionary = reason
			var text := String(reason_data.get("text", ""))
			var key := "%s|%s" % [source, text]
			var magnitude := absf(float(reason_data.get("price_pct", 0.0))) + absf(float(reason_data.get("speed_pct", 0.0)))
			if not text.is_empty() and (not strongest_by_key.has(key) or magnitude > float((strongest_by_key[key] as Dictionary).get("magnitude", 0.0))):
				strongest_by_key[key] = {"text": text, "magnitude": magnitude}
		var breakdown: Dictionary = item_data.get("breakdown", {})
		var set_part: Dictionary = breakdown.get("set", {})
		for group_value in set_part.get("groups", []):
			if group_value is Dictionary:
				var set_id := String((group_value as Dictionary).get("id", ""))
				if not set_id.is_empty():
					set_ids[set_id] = true
	var strongest: Array = strongest_by_key.values()
	strongest.sort_custom(func(left, right):
		var left_magnitude := float((left as Dictionary).get("magnitude", 0.0))
		var right_magnitude := float((right as Dictionary).get("magnitude", 0.0))
		if not is_equal_approx(left_magnitude, right_magnitude):
			return left_magnitude > right_magnitude
		return String((left as Dictionary).get("text", "")) < String((right as Dictionary).get("text", ""))
	)
	var strongest_effects: Array[String] = []
	for index in range(mini(3, strongest.size())):
		strongest_effects.append(String((strongest[index] as Dictionary).get("text", "")))
	var unlocked_cells: Array = ShowcaseRegionService.cells_for_bounds(ShowcaseRegionService.default_bounds())
	if state != null and state.has_method("get_showcase_unlocked_cells"):
		unlocked_cells = state.get_showcase_unlocked_cells()
	var region_cell_counts := {"front": 0, "golden": 0, "middle": 0, "back": 0}
	for cell_value in unlocked_cells:
		if not cell_value is Vector2i:
			continue
		var region_id := ShowcaseRegionService.zone_for_cell_in_cells(cell_value, unlocked_cells)
		region_cell_counts[region_id] = int(region_cell_counts.get(region_id, 0)) + 1
	return {
		"listed_count": listed_count,
		"prop_count": _display_props(state).size(),
		"theme_id": _showcase_theme_id(state),
		"positive_rule_count": positive_count,
		"conflict_count": conflict_count,
		"set_count": set_ids.size(),
		"total_price_delta_pct": total_price_delta,
		"total_speed_delta_pct": total_speed_delta,
		"unlocked_count": unlocked_cells.size(),
		"region_cell_counts": region_cell_counts,
		"strongest_effects": strongest_effects
	}


static func _unlocked_cells_from_layout(unlocked_layout: Variant) -> Array[Vector2i]:
	if unlocked_layout is Array:
		return ShowcaseRegionService.normalize_cells(unlocked_layout)
	if unlocked_layout is Dictionary and not (unlocked_layout as Dictionary).is_empty():
		return ShowcaseRegionService.cells_for_bounds(unlocked_layout)
	return ShowcaseRegionService.cells_for_bounds(ShowcaseRegionService.default_bounds())


static func _reason_entries(bonus: Dictionary) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var breakdown: Dictionary = bonus.get("breakdown", {})
	var source_map := {
		"zone": "position",
		"adjacency_tag": "adjacency",
		"set": "set",
		"conflict": "conflict",
		"growth": "growth",
		"variant": "variant",
		"theme": "theme",
		"prop": "prop",
		"spacing": "spacing"
	}
	for key in ["zone", "adjacency_tag", "set", "conflict", "spacing", "growth", "variant", "theme", "prop"]:
		var part: Dictionary = breakdown.get(key, {})
		if part.is_empty():
			continue
		var source := String(source_map.get(key, key))
		var raw_reasons: Array = part.get("reasons", [])
		if raw_reasons.is_empty() and _has_numeric_effect(part):
			entries.append({
				"source": source,
				"text": _fallback_reason(source, part),
				"price_pct": float(part.get("price_pct", 0.0)),
				"speed_pct": float(part.get("speed_pct", 0.0))
			})
			continue
		for reason_value in raw_reasons:
			var text := String(reason_value).strip_edges()
			if text.is_empty():
				continue
			entries.append({
				"source": source,
				"text": text,
				"price_pct": float(part.get("price_pct", 0.0)),
				"speed_pct": float(part.get("speed_pct", 0.0))
			})
	return entries


static func _display_items(state) -> Dictionary:
	if state == null:
		return {}
	var value: Variant = state.get("display_items")
	return value if value is Dictionary else {}


static func _display_props(state) -> Dictionary:
	if state == null:
		return {}
	var value: Variant = state.get("display_props")
	return value if value is Dictionary else {}


static func _showcase_theme_id(state) -> String:
	if state == null:
		return ""
	return String(state.get("showcase_theme_id"))


static func _shape_cells_from_display(recipe_display: Dictionary) -> Array:
	var cells: Array = []
	var raw: Variant = recipe_display.get("shape_cells", [])
	if not raw is Array:
		return cells
	for cell_value in raw:
		if cell_value is Array and cell_value.size() == 2:
			cells.append(Vector2i(int(cell_value[0]), int(cell_value[1])))
		elif cell_value is Vector2i:
			cells.append(cell_value)
	return cells


static func _cells_touch(product_cells: Array, prop_cells: Array) -> bool:
	for product_cell_value in product_cells:
		if not product_cell_value is Vector2i:
			continue
		var product_cell := product_cell_value as Vector2i
		for prop_cell_value in prop_cells:
			if not prop_cell_value is Vector2i:
				continue
			var prop_cell := prop_cell_value as Vector2i
			var distance := absi(product_cell.x - prop_cell.x) + absi(product_cell.y - prop_cell.y)
			if distance == 1:
				return true
	return false


static func _append_reason(part: Dictionary, reason: String) -> void:
	var reasons: Array = part.get("reasons", [])
	if not reasons.has(reason):
		reasons.append(reason)
	part["reasons"] = reasons


static func _has_numeric_effect(part: Dictionary) -> bool:
	return absf(float(part.get("price_pct", 0.0))) >= 0.01 or absf(float(part.get("speed_pct", 0.0))) >= 0.01


static func _fallback_reason(source: String, part: Dictionary) -> String:
	return "%s rule: price %.0f%%, speed %.0f%%" % [
		source,
		float(part.get("price_pct", 0.0)),
		float(part.get("speed_pct", 0.0))
	]
