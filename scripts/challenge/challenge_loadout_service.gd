class_name ChallengeLoadoutService
extends RefCounted


func analyze(
	draft: Dictionary,
	recipe_defs: Dictionary,
	rows: int,
	columns: int,
	budget: int,
	encounter: Dictionary
) -> Dictionary:
	var errors: Array[String] = []
	var placements_value = draft.get("placements")
	if not placements_value is Array:
		errors.append("draft: placements must be an array")
		placements_value = []
	var placements: Array = placements_value
	if rows <= 0 or columns <= 0:
		errors.append("board: rows and columns must be positive")
	if budget <= 0:
		errors.append("board: supply budget must be positive")

	var instances: Array[Dictionary] = []
	var occupied_cells := {}
	var seen_instance_ids := {}
	var recipe_counts := {}
	var spent_budget := 0

	for index in placements.size():
		var placement_value = placements[index]
		if not placement_value is Dictionary:
			errors.append("placement_%d: placement must be a dictionary" % index)
			continue
		var placement: Dictionary = placement_value
		var instance_id := String(placement.get("instance_id", "")).strip_edges()
		var recipe_id := String(placement.get("recipe_id", "")).strip_edges()
		var prefix := instance_id if not instance_id.is_empty() else "placement_%d" % index

		if instance_id.is_empty():
			errors.append("%s: instance_id must be a non-empty string" % prefix)
		elif seen_instance_ids.has(instance_id):
			errors.append("%s: instance_id must be unique" % prefix)
		seen_instance_ids[instance_id] = true

		if not recipe_defs.has(recipe_id) or not recipe_defs[recipe_id] is Dictionary:
			errors.append("%s: unknown recipe %s" % [prefix, recipe_id])
			continue
		var definition: Dictionary = recipe_defs[recipe_id]
		recipe_counts[recipe_id] = int(recipe_counts.get(recipe_id, 0)) + 1
		var copy_limit := int(definition.get("copy_limit", 0))
		if int(recipe_counts[recipe_id]) > copy_limit:
			errors.append("%s: %s exceeds copy limit %d" % [prefix, recipe_id, copy_limit])

		var supply_cost := int(definition.get("supply_cost", 0))
		spent_budget += supply_cost
		if spent_budget > budget:
			errors.append("%s: supply budget exceeded (%d/%d)" % [prefix, spent_budget, budget])

		var origin_result := _parse_origin(placement.get("origin"), prefix, errors)
		if not bool(origin_result.get("ok", false)):
			continue
		var origin: Vector2i = origin_result["origin"]

		var rotation_result := _parse_rotation(placement.get("rotation", 0), bool(definition.get("rotatable", false)), prefix, errors)
		if not bool(rotation_result.get("ok", false)):
			continue
		var rotation := int(rotation_result["rotation"])
		var shape_value = definition.get("shape_cells", [])
		if not shape_value is Array or shape_value.is_empty():
			errors.append("%s: recipe shape is missing" % prefix)
			continue
		var shape_cells: Array[Vector2i] = rotated_cells(shape_value, rotation)
		var resolved_cells: Array = []
		for relative_cell in shape_cells:
			var cell := origin + relative_cell
			var cell_key := "%d:%d" % [cell.x, cell.y]
			if cell.x < 0 or cell.x >= rows or cell.y < 0 or cell.y >= columns:
				errors.append("%s: cell %s is out of bounds" % [prefix, cell_key])
			elif occupied_cells.has(cell_key):
				errors.append("%s: cell %s overlaps %s" % [prefix, cell_key, String(occupied_cells[cell_key])])
			else:
				occupied_cells[cell_key] = instance_id
			resolved_cells.append([cell.x, cell.y])

		instances.append({
			"instance_id": instance_id,
			"recipe_id": recipe_id,
			"origin": [origin.x, origin.y],
			"rotation": rotation,
			"cells": resolved_cells,
			"supply_cost": supply_cost,
			"virtual_stock": int(definition.get("virtual_stock", 0)),
			"cycle_ms": int(definition.get("cycle_ms", 0)),
			"base_satisfaction": int(definition.get("satisfaction", 0)),
			"tags": (definition.get("tags", []) as Array).duplicate(),
			"upgrade_source_ids": (
				definition.get("_upgrade_source_ids", []) as Array
			).duplicate()
		})

	var relations := _find_relations(instances, encounter)
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"spent_budget": spent_budget,
		"occupied_cells": occupied_cells,
		"relations": relations,
		"instances": instances
	}


func build_snapshot(
	draft: Dictionary,
	recipe_defs: Dictionary,
	encounter: Dictionary,
	rows: int,
	columns: int,
	budget: int
) -> Dictionary:
	var analysis := analyze(draft, recipe_defs, rows, columns, budget, encounter)
	if not bool(analysis.get("valid", false)):
		return {
			"ok": false,
			"errors": (analysis.get("errors", []) as Array).duplicate()
		}
	var snapshot := {
		"grid_rows": rows,
		"grid_columns": columns,
		"spent_budget": int(analysis.get("spent_budget", 0)),
		"instances": (analysis.get("instances", []) as Array).duplicate(true),
		"relations": (analysis.get("relations", []) as Array).duplicate(true),
		"encounter_id": String(encounter.get("id", "picky_food_critic"))
	}
	return {
		"ok": true,
		"snapshot": snapshot.duplicate(true)
	}


func analyze_context(
	draft: Dictionary,
	effective_context: Dictionary,
	rows: int,
	columns: int,
	encounter: Dictionary
) -> Dictionary:
	var recipe_defs: Dictionary = effective_context.get("recipe_defs", {})
	var rules: Dictionary = effective_context.get("rules", {})
	var budget := int(rules.get("supply_budget", 0))
	var effective_encounter := _encounter_with_rules(encounter, rules)
	var result := analyze(draft, recipe_defs, rows, columns, budget, effective_encounter)
	result["effective_budget"] = budget
	result["effective_rules"] = rules.duplicate(true)
	result["applied_upgrades"] = (
		effective_context.get("applied_upgrades", []) as Array
	).duplicate(true)
	return result


func build_snapshot_from_context(
	draft: Dictionary,
	effective_context: Dictionary,
	encounter: Dictionary,
	rows: int,
	columns: int
) -> Dictionary:
	var analysis := analyze_context(draft, effective_context, rows, columns, encounter)
	if not bool(analysis.get("valid", false)):
		return {
			"ok": false,
			"errors": (analysis.get("errors", []) as Array).duplicate(),
			"requires_rearrange": true
		}
	var rules: Dictionary = analysis.get("effective_rules", {})
	var snapshot := {
		"grid_rows": rows,
		"grid_columns": columns,
		"spent_budget": int(analysis.get("spent_budget", 0)),
		"supply_budget": int(analysis.get("effective_budget", 0)),
		"instances": (analysis.get("instances", []) as Array).duplicate(true),
		"relations": (analysis.get("relations", []) as Array).duplicate(true),
		"encounter_id": String(encounter.get("id", "picky_food_critic")),
		"effective_rules": rules.duplicate(true),
		"applied_upgrades": (
			analysis.get("applied_upgrades", []) as Array
		).duplicate(true)
	}
	return {
		"ok": true,
		"snapshot": snapshot.duplicate(true),
		"requires_rearrange": false
	}


static func rotated_cells(shape_cells: Array, rotation: int) -> Array[Vector2i]:
	var turns := int(posmod(rotation, 360) / 90)
	var cells: Array[Vector2i] = []
	for value in shape_cells:
		var cell := Vector2i(int(value[0]), int(value[1]))
		for _turn in range(turns):
			cell = Vector2i(cell.y, -cell.x)
		cells.append(cell)
	if cells.is_empty():
		return cells
	var min_row := cells[0].x
	var min_column := cells[0].y
	for cell in cells:
		min_row = mini(min_row, cell.x)
		min_column = mini(min_column, cell.y)
	for index in range(cells.size()):
		cells[index] -= Vector2i(min_row, min_column)
	cells.sort_custom(func(left: Vector2i, right: Vector2i) -> bool:
		return left.x < right.x or (left.x == right.x and left.y < right.y)
	)
	return cells


func _parse_origin(value: Variant, prefix: String, errors: Array[String]) -> Dictionary:
	if not value is Array or value.size() != 2:
		errors.append("%s: origin must be [row, column]" % prefix)
		return {"ok": false}
	if not _is_integer_number(value[0]) or not _is_integer_number(value[1]):
		errors.append("%s: origin coordinates must be integers" % prefix)
		return {"ok": false}
	return {
		"ok": true,
		"origin": Vector2i(int(value[0]), int(value[1]))
	}


func _parse_rotation(value: Variant, rotatable: bool, prefix: String, errors: Array[String]) -> Dictionary:
	if not _is_integer_number(value):
		errors.append("%s: rotation must be an integer" % prefix)
		return {"ok": false}
	var rotation := int(value)
	if rotation % 90 != 0:
		errors.append("%s: rotation must be divisible by 90" % prefix)
		return {"ok": false}
	var normalized := int(posmod(rotation, 360))
	if not rotatable and normalized != 0:
		errors.append("%s: recipe does not allow rotation" % prefix)
		return {"ok": false}
	return {
		"ok": true,
		"rotation": normalized
	}


func _find_relations(instances: Array[Dictionary], encounter: Dictionary) -> Array[Dictionary]:
	var relation: Dictionary = encounter.get("relation", {})
	var relation_id := String(relation.get("id", ""))
	var left_tag := String(relation.get("left_tag", ""))
	var right_tag := String(relation.get("right_tag", ""))
	if relation_id.is_empty() or left_tag.is_empty() or right_tag.is_empty():
		return []
	var bonus_pct := int(encounter.get("relation_bonus_pct", 0))
	var upgrade_source_ids: Array = encounter.get("_relation_upgrade_source_ids", [])
	var relations: Array[Dictionary] = []
	for left_instance in instances:
		var left_tags: Array = left_instance.get("tags", [])
		if not left_tags.has(left_tag):
			continue
		for right_instance in instances:
			if left_instance.get("instance_id") == right_instance.get("instance_id"):
				continue
			var right_tags: Array = right_instance.get("tags", [])
			if not right_tags.has(right_tag):
				continue
			if not _instances_touch(left_instance, right_instance):
				continue
			relations.append({
				"relation_id": relation_id,
				"left_instance_id": String(left_instance.get("instance_id", "")),
				"right_instance_id": String(right_instance.get("instance_id", "")),
				"bonus_pct": bonus_pct,
				"upgrade_source_ids": upgrade_source_ids.duplicate()
			})
	return relations


func _encounter_with_rules(encounter: Dictionary, rules: Dictionary) -> Dictionary:
	var effective := encounter.duplicate(true)
	var relation: Dictionary = effective.get("relation", {})
	var relation_id := String(relation.get("id", ""))
	var bonuses: Dictionary = rules.get("relation_bonus_add", {})
	var bonus_add := int(bonuses.get("global", 0))
	if not relation_id.is_empty():
		bonus_add += int(bonuses.get(relation_id, 0))
	effective["relation_bonus_pct"] = int(effective.get("relation_bonus_pct", 0)) + bonus_add
	var source_map: Dictionary = rules.get("relation_bonus_source_ids", {})
	var source_ids: Array[String] = []
	for source_value in source_map.get("global", []):
		var source_id := String(source_value)
		if not source_id.is_empty() and not source_ids.has(source_id):
			source_ids.append(source_id)
	for source_value in source_map.get(relation_id, []):
		var source_id := String(source_value)
		if not source_id.is_empty() and not source_ids.has(source_id):
			source_ids.append(source_id)
	source_ids.sort()
	effective["_relation_upgrade_source_ids"] = source_ids
	return effective


func _instances_touch(left_instance: Dictionary, right_instance: Dictionary) -> bool:
	for left_value in left_instance.get("cells", []):
		var left := Vector2i(int(left_value[0]), int(left_value[1]))
		for right_value in right_instance.get("cells", []):
			var right := Vector2i(int(right_value[0]), int(right_value[1]))
			if abs(left.x - right.x) + abs(left.y - right.y) == 1:
				return true
	return false


func _is_integer_number(value: Variant) -> bool:
	if value is int:
		return true
	if value is float:
		return is_equal_approx(value, float(int(value)))
	return false
