class_name ChallengeRouteService
extends RefCounted


func bootstrap_meta(meta: Dictionary, route_defs: Dictionary) -> Dictionary:
	var next_meta := meta.duplicate(true)
	var unlocked := _unique_strings(next_meta.get("unlocked_route_ids", []))
	var first_clears := _unique_strings(next_meta.get("route_first_clear_ids", []))
	for route_id in route_defs:
		var route: Dictionary = route_defs.get(route_id, {})
		var prerequisite := String(route.get("unlock_requirement_route_id", ""))
		if prerequisite.is_empty() or first_clears.has(prerequisite):
			if not unlocked.has(String(route_id)):
				unlocked.append(String(route_id))
	next_meta["unlocked_route_ids"] = unlocked
	next_meta["route_first_clear_ids"] = first_clears
	return next_meta


func route_state(meta: Dictionary, route_id: String, route_defs: Dictionary) -> Dictionary:
	if not route_defs.has(route_id) or not route_defs[route_id] is Dictionary:
		return {"exists": false, "route_id": route_id, "unlocked": false, "lock_reason": "未知路线"}
	var route: Dictionary = route_defs[route_id]
	var unlocked := _unique_strings(meta.get("unlocked_route_ids", []))
	var first_clears := _unique_strings(meta.get("route_first_clear_ids", []))
	var prerequisite := String(route.get("unlock_requirement_route_id", ""))
	var available := unlocked.has(route_id) or prerequisite.is_empty() or first_clears.has(prerequisite)
	var reason := ""
	if not available:
		var prerequisite_name := String(
			(route_defs.get(prerequisite, {}) as Dictionary).get("display_name", prerequisite)
		)
		reason = "完成「%s」后解锁" % prerequisite_name
	return {
		"exists": true,
		"route_id": route_id,
		"display_name": String(route.get("display_name", route_id)),
		"description": String(route.get("description", "")),
		"unlocked": available,
		"first_cleared": first_clears.has(route_id),
		"lock_reason": reason,
		"recommended_build_roles": (route.get("recommended_build_roles", []) as Array).duplicate()
	}


func all_states(meta: Dictionary, route_defs: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for route_id in route_defs:
		result.append(route_state(meta, String(route_id), route_defs))
	return result


func record_first_clear(meta: Dictionary, route_id: String, route_defs: Dictionary) -> Dictionary:
	var next_meta := bootstrap_meta(meta, route_defs)
	if not route_defs.has(route_id):
		return {"applied": false, "meta": next_meta, "error": "unknown_route"}
	var first_clears := _unique_strings(next_meta.get("route_first_clear_ids", []))
	if first_clears.has(route_id):
		return {"applied": false, "meta": next_meta}
	first_clears.append(route_id)
	next_meta["route_first_clear_ids"] = first_clears
	next_meta = bootstrap_meta(next_meta, route_defs)
	return {
		"applied": true,
		"meta": next_meta,
		"route_id": route_id,
		"unlocked_route_ids": (next_meta.get("unlocked_route_ids", []) as Array).duplicate()
	}


func _unique_strings(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item in value:
			if item is String:
				var clean := String(item).strip_edges()
				if not clean.is_empty() and not result.has(clean):
					result.append(clean)
	return result
