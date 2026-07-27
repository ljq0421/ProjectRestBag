class_name ShowcaseRoleService
extends RefCounted


static func build_snapshot(display_items: Dictionary, sale_terms: Dictionary) -> Dictionary:
	return build_configured_snapshot(display_items, sale_terms, {})


static func build_configured_snapshot(display_items: Dictionary, sale_terms: Dictionary, role_rules: Dictionary) -> Dictionary:
	var anchors := {}
	for recipe_id_value in display_items.keys():
		anchors[String(recipe_id_value)] = _anchor((display_items.get(recipe_id_value, {}) as Dictionary).get("cells", []))
	var result := {}
	for recipe_id_value in display_items.keys():
		var recipe_id := String(recipe_id_value)
		var anchor: Vector2i = anchors.get(recipe_id, Vector2i(9999, 9999))
		var targets: Array[String] = []
		for other_id_value in display_items.keys():
			var other_id := String(other_id_value)
			if other_id != recipe_id and _items_touch(
				(display_items.get(recipe_id, {}) as Dictionary).get("cells", []),
				(display_items.get(other_id_value, {}) as Dictionary).get("cells", [])
			):
				targets.append(other_id)
		targets.sort_custom(func(left: String, right: String) -> bool:
			var left_anchor: Vector2i = anchors.get(left, Vector2i(9999, 9999))
			var right_anchor: Vector2i = anchors.get(right, Vector2i(9999, 9999))
			var left_distance := absi(left_anchor.x - anchor.x) + absi(left_anchor.y - anchor.y)
			var right_distance := absi(right_anchor.x - anchor.x) + absi(right_anchor.y - anchor.y)
			if left_distance != right_distance:
				return left_distance < right_distance
			if left_anchor.x != right_anchor.x:
				return left_anchor.x < right_anchor.x
			if left_anchor.y != right_anchor.y:
				return left_anchor.y < right_anchor.y
			return left < right
		)
		var term: Dictionary = sale_terms.get(recipe_id, {})
		var resolved := _resolve_role(
			recipe_id,
			String((display_items.get(recipe_id, {}) as Dictionary).get("variant_id", "standard")),
			term,
			role_rules
		)
		result[recipe_id] = {
			"recipe_id": recipe_id,
			"role": String(resolved.get("role", term.get("role", "lure"))),
			"role_source": String(resolved.get("source", "shape")),
			"role_reason": String(resolved.get("reason", "形状模板")),
			"anchor_cell": anchor,
			"targets": targets
		}
	return result


static func _items_touch(left_cells_value: Variant, right_cells_value: Variant) -> bool:
	if not left_cells_value is Array or not right_cells_value is Array:
		return false
	for left_value in left_cells_value as Array:
		if not left_value is Vector2i:
			continue
		var left := left_value as Vector2i
		for right_value in right_cells_value as Array:
			if right_value is Vector2i and absi(left.x - (right_value as Vector2i).x) + absi(left.y - (right_value as Vector2i).y) == 1:
				return true
	return false


static func _resolve_role(recipe_id: String, variant_id: String, term: Dictionary, role_rules: Dictionary) -> Dictionary:
	var base_role := String(term.get("role", "lure"))
	var recipe_overrides: Dictionary = role_rules.get("recipe_overrides", {})
	if recipe_overrides.get(recipe_id) is Dictionary:
		return _role_result(recipe_overrides.get(recipe_id, {}), base_role, "recipe")
	var variant_overrides: Dictionary = role_rules.get("variant_overrides", {})
	if variant_overrides.get(variant_id) is Dictionary:
		return _role_result(variant_overrides.get(variant_id, {}), base_role, "variant")
	var tags: Array[String] = []
	for tag_value in term.get("tags", []):
		tags.append(String(tag_value))
	tags.sort()
	for override_value in role_rules.get("tag_overrides", []):
		if not override_value is Dictionary:
			continue
		var override: Dictionary = override_value
		var matches := true
		for required_value in override.get("all_tags", []):
			if not tags.has(String(required_value)):
				matches = false
				break
		if matches:
			return _role_result(override, base_role, "tag")
	var growth_level := maxi(0, int(term.get("growth_level", 0)))
	var growth_overrides: Array = role_rules.get("growth_overrides", [])
	growth_overrides.sort_custom(func(left: Variant, right: Variant) -> bool:
		return int((left as Dictionary).get("min_level", 0)) > int((right as Dictionary).get("min_level", 0))
	)
	for override_value in growth_overrides:
		if override_value is Dictionary and growth_level >= int((override_value as Dictionary).get("min_level", 9999)):
			return _role_result(override_value, base_role, "growth")
	return {"role": base_role, "source": "shape", "reason": "形状模板"}


static func _role_result(rule: Dictionary, fallback_role: String, source: String) -> Dictionary:
	return {
		"role": String(rule.get("role", fallback_role)),
		"source": source,
		"reason": String(rule.get("reason", source))
	}


static func _anchor(cells_value: Variant) -> Vector2i:
	var result := Vector2i(9999, 9999)
	if not cells_value is Array:
		return result
	for cell_value in cells_value as Array:
		if cell_value is Vector2i:
			var cell: Vector2i = cell_value
			if cell.x < result.x or cell.x == result.x and cell.y < result.y:
				result = cell
	return result
