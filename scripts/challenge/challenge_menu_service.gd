class_name ChallengeMenuService
extends RefCounted

const MIN_RECIPES := 4
const MAX_RECIPES := 8
const MAX_SAVED_MENUS := 3


func bootstrap_meta(
	meta: Dictionary,
	available_recipe_ids: Array[String],
	starter_recipe_ids: Array[String]
) -> Dictionary:
	var next_meta := meta.duplicate(true)
	var available := _unique_strings(available_recipe_ids)
	var starters := _unique_strings(starter_recipe_ids)
	var active := _filtered_menu(next_meta.get("active_menu_recipe_ids", []), available)
	if active.is_empty():
		active = _filtered_menu(starters, available)
	for recipe_id in starters:
		if active.size() >= MIN_RECIPES:
			break
		if available.has(recipe_id) and not active.has(recipe_id):
			active.append(recipe_id)
	for recipe_id in available:
		if active.size() >= MIN_RECIPES:
			break
		if not active.has(recipe_id):
			active.append(recipe_id)
	if active.size() > MAX_RECIPES:
		active.resize(MAX_RECIPES)
	next_meta["active_menu_recipe_ids"] = active
	if not next_meta.get("saved_menus") is Array:
		next_meta["saved_menus"] = []
	return next_meta


func validate_menu(
	menu_value: Variant,
	available_recipe_ids: Array[String],
	recipe_defs: Dictionary
) -> Dictionary:
	var errors: Array[String] = []
	if not menu_value is Array:
		return {
			"valid": false,
			"errors": ["menu must be an array"],
			"recipe_ids": []
		}
	var menu_ids := _string_array(menu_value)
	if menu_ids.size() != (menu_value as Array).size():
		errors.append("menu contains a non-string or empty recipe id")
	var seen := {}
	for recipe_id in menu_ids:
		if seen.has(recipe_id):
			errors.append("menu contains duplicate recipe: %s" % recipe_id)
		else:
			seen[recipe_id] = true
		if not available_recipe_ids.has(recipe_id):
			errors.append("menu contains locked recipe: %s" % recipe_id)
		elif not recipe_defs.has(recipe_id) or not recipe_defs[recipe_id] is Dictionary:
			errors.append("menu contains unknown recipe: %s" % recipe_id)
	if menu_ids.size() < MIN_RECIPES:
		errors.append("menu requires at least %d recipes" % MIN_RECIPES)
	if menu_ids.size() > MAX_RECIPES:
		errors.append("menu allows at most %d recipes" % MAX_RECIPES)
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"recipe_ids": menu_ids
	}


func set_active_menu(
	meta: Dictionary,
	menu_value: Variant,
	available_recipe_ids: Array[String],
	recipe_defs: Dictionary
) -> Dictionary:
	var validation := validate_menu(menu_value, available_recipe_ids, recipe_defs)
	if not bool(validation.get("valid", false)):
		return {
			"applied": false,
			"meta": meta.duplicate(true),
			"recipe_ids": validation.get("recipe_ids", []),
			"errors": validation.get("errors", [])
		}
	var next_meta := meta.duplicate(true)
	var recipe_ids: Array = validation.get("recipe_ids", [])
	next_meta["active_menu_recipe_ids"] = recipe_ids.duplicate()
	return {
		"applied": true,
		"meta": next_meta,
		"recipe_ids": recipe_ids.duplicate()
	}


func analyze_menu(menu_value: Variant, recipe_defs: Dictionary) -> Dictionary:
	var recipe_ids := _string_array(menu_value)
	var role_counts := {}
	var tag_counts := {}
	var total_cells := 0
	var min_cycle := 0
	var max_cycle := 0
	for recipe_id in recipe_ids:
		if not recipe_defs.has(recipe_id) or not recipe_defs[recipe_id] is Dictionary:
			continue
		var recipe: Dictionary = recipe_defs[recipe_id]
		var cell_count := maxi(1, (recipe.get("shape_cells", []) as Array).size())
		total_cells += cell_count
		var cycle := int(recipe.get("cycle_seconds", 0))
		if cycle > 0:
			min_cycle = cycle if min_cycle == 0 else mini(min_cycle, cycle)
			max_cycle = maxi(max_cycle, cycle)
		for role in _string_array(recipe.get("build_roles", [])):
			role_counts[role] = int(role_counts.get(role, 0)) + 1
		for tag in _string_array(recipe.get("tags", [])):
			tag_counts[tag] = int(tag_counts.get(tag, 0)) + 1
	return {
		"recipe_count": recipe_ids.size(),
		"recipe_ids": recipe_ids,
		"role_counts": role_counts,
		"tag_counts": tag_counts,
		"total_cells": total_cells,
		"cycle_range": [min_cycle, max_cycle]
	}


func save_preset(
	meta: Dictionary,
	preset_id: String,
	display_name: String,
	menu_value: Variant,
	available_recipe_ids: Array[String],
	recipe_defs: Dictionary
) -> Dictionary:
	var validation := validate_menu(menu_value, available_recipe_ids, recipe_defs)
	if not bool(validation.get("valid", false)):
		return {"applied": false, "meta": meta.duplicate(true), "errors": validation.get("errors", [])}
	var clean_id := preset_id.strip_edges()
	if clean_id.is_empty():
		return {"applied": false, "meta": meta.duplicate(true), "errors": ["preset id required"]}
	var next_meta := meta.duplicate(true)
	var presets: Array = (next_meta.get("saved_menus", []) as Array).duplicate(true)
	var existing_index := -1
	for index in range(presets.size()):
		if presets[index] is Dictionary and String(presets[index].get("id", "")) == clean_id:
			existing_index = index
			break
	if existing_index < 0 and presets.size() >= MAX_SAVED_MENUS:
		return {"applied": false, "meta": meta.duplicate(true), "errors": ["at most three saved menus"]}
	var preset := {
		"id": clean_id,
		"display_name": display_name.strip_edges() if not display_name.strip_edges().is_empty() else clean_id,
		"recipe_ids": (validation.get("recipe_ids", []) as Array).duplicate()
	}
	if existing_index >= 0:
		presets[existing_index] = preset
	else:
		presets.append(preset)
	next_meta["saved_menus"] = presets
	return {"applied": true, "meta": next_meta, "preset": preset}


func load_preset(
	meta: Dictionary,
	preset_id: String,
	available_recipe_ids: Array[String],
	recipe_defs: Dictionary
) -> Dictionary:
	for preset_value in meta.get("saved_menus", []):
		if preset_value is Dictionary and String(preset_value.get("id", "")) == preset_id:
			return set_active_menu(
				meta,
				preset_value.get("recipe_ids", []),
				available_recipe_ids,
				recipe_defs
			)
	return {"applied": false, "meta": meta.duplicate(true), "errors": ["unknown menu preset"]}


func primary_role(recipe_def: Dictionary) -> String:
	var roles := _string_array(recipe_def.get("build_roles", []))
	return roles[0] if not roles.is_empty() else "other"


func _filtered_menu(value: Variant, available_recipe_ids: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for recipe_id in _string_array(value):
		if available_recipe_ids.has(recipe_id) and not result.has(recipe_id):
			result.append(recipe_id)
	return result


func _unique_strings(values: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		var clean := value.strip_edges()
		if not clean.is_empty() and not result.has(clean):
			result.append(clean)
	return result


func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if not value is Array:
		return result
	for item in value:
		if item is String:
			var clean := String(item).strip_edges()
			if not clean.is_empty():
				result.append(clean)
	return result
