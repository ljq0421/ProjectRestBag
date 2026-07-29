class_name ChallengeMasteryService
extends RefCounted


func bootstrap_meta(meta: Dictionary) -> Dictionary:
	var next_meta := meta.duplicate(true)
	next_meta["completed_mastery_ids"] = _unique_strings(
		next_meta.get("completed_mastery_ids", [])
	)
	return next_meta


func evaluate(meta: Dictionary, mastery_defs: Dictionary) -> Dictionary:
	var next_meta := bootstrap_meta(meta)
	var completed := _unique_strings(next_meta.get("completed_mastery_ids", []))
	var revealed := _unique_strings(next_meta.get("revealed_research_node_ids", []))
	var new_masteries: Array[String] = []
	var new_reveals: Array[String] = []
	for mastery_id_value in mastery_defs:
		var mastery_id := String(mastery_id_value)
		var definition: Dictionary = mastery_defs.get(mastery_id, {})
		if completed.has(mastery_id) or not _condition_met(next_meta, definition.get("condition", {})):
			continue
		completed.append(mastery_id)
		new_masteries.append(mastery_id)
		for node_id in _unique_strings(definition.get("reveal_node_ids", [])):
			if not revealed.has(node_id):
				revealed.append(node_id)
				new_reveals.append(node_id)
	next_meta["completed_mastery_ids"] = completed
	next_meta["revealed_research_node_ids"] = revealed
	return {
		"applied": not new_masteries.is_empty(),
		"meta": next_meta,
		"completed_mastery_ids": new_masteries,
		"revealed_node_ids": new_reveals
	}


func states(meta: Dictionary, mastery_defs: Dictionary) -> Array[Dictionary]:
	var completed := _unique_strings(meta.get("completed_mastery_ids", []))
	var result: Array[Dictionary] = []
	for mastery_id_value in mastery_defs:
		var mastery_id := String(mastery_id_value)
		var definition: Dictionary = mastery_defs.get(mastery_id, {})
		result.append({
			"id": mastery_id,
			"display_name": String(definition.get("display_name", mastery_id)),
			"description": String(definition.get("description", "")),
			"completed": completed.has(mastery_id),
			"condition_met": _condition_met(meta, definition.get("condition", {}))
		})
	return result


func _condition_met(meta: Dictionary, condition_value: Variant) -> bool:
	if not condition_value is Dictionary:
		return false
	var condition: Dictionary = condition_value
	var condition_type := String(condition.get("type", ""))
	var first_clears := _unique_strings(meta.get("route_first_clear_ids", []))
	match condition_type:
		"route_first_clear":
			return first_clears.has(String(condition.get("route_id", "")))
		"all_route_first_clears":
			for route_id in _unique_strings(condition.get("route_ids", [])):
				if not first_clears.has(route_id):
					return false
			return true
		"endless_best_floor":
			return int((meta.get("endless_records", {}) as Dictionary).get("best_floor", 0)) >= int(
				condition.get("floor", 0)
			)
	return false


func _unique_strings(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item in value:
			if item is String:
				var clean := String(item).strip_edges()
				if not clean.is_empty() and not result.has(clean):
					result.append(clean)
	return result
