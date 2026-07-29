class_name RecipeResearchService
extends RefCounted

const UNLOCK_META_FIELDS := {
	"recipe": "unlocked_recipe_ids",
	"variant": "unlocked_variant_ids",
	"upgrade": "unlocked_upgrade_ids"
}


func validate_tree(
	tree_def: Dictionary,
	recipe_defs: Dictionary,
	upgrade_defs: Dictionary
) -> Dictionary:
	var errors: Array[String] = []
	var tree_id := String(tree_def.get("id", "")).strip_edges()
	if tree_id.is_empty():
		errors.append("tree id must be a non-empty string")
	if String(tree_def.get("display_name", "")).strip_edges().is_empty():
		errors.append("%s: display_name must be a non-empty string" % _label(tree_id))
	if _positive_int(tree_def.get("completion_reward_points")) <= 0:
		errors.append("%s: completion_reward_points must be a positive integer" % _label(tree_id))

	var starter_ids := _string_array(tree_def.get("starter_recipe_ids"), "starter_recipe_ids", errors)
	_validate_unique_strings(starter_ids, "starter_recipe_ids", errors)
	for recipe_id in starter_ids:
		if not recipe_defs.has(recipe_id) or not recipe_defs[recipe_id] is Dictionary:
			errors.append("starter_recipe_ids contains unknown recipe: %s" % recipe_id)

	var nodes_value: Variant = tree_def.get("nodes")
	if not nodes_value is Dictionary or (nodes_value as Dictionary).is_empty():
		errors.append("%s: nodes must be a non-empty dictionary" % _label(tree_id))
		return {"valid": false, "errors": errors}
	var nodes: Dictionary = nodes_value

	var branches_value: Variant = tree_def.get("branches")
	if not branches_value is Array or (branches_value as Array).is_empty():
		errors.append("%s: branches must be a non-empty array" % _label(tree_id))
		return {"valid": false, "errors": errors}
	var branch_ids: Array[String] = []
	var branch_membership := {}
	for branch_index in (branches_value as Array).size():
		var branch_value: Variant = (branches_value as Array)[branch_index]
		var prefix := "branches[%d]" % branch_index
		if not branch_value is Dictionary:
			errors.append("%s must be a dictionary" % prefix)
			continue
		var branch: Dictionary = branch_value
		var branch_id := String(branch.get("id", "")).strip_edges()
		if branch_id.is_empty():
			errors.append("%s.id must be a non-empty string" % prefix)
			continue
		if branch_ids.has(branch_id):
			errors.append("duplicate branch id: %s" % branch_id)
		else:
			branch_ids.append(branch_id)
		if String(branch.get("display_name", "")).strip_edges().is_empty():
			errors.append("%s.display_name must be a non-empty string" % prefix)
		var node_ids := _string_array(branch.get("node_ids"), "%s.node_ids" % prefix, errors)
		if node_ids.is_empty():
			errors.append("%s.node_ids must not be empty" % prefix)
		_validate_unique_strings(node_ids, "%s.node_ids" % prefix, errors)
		for node_id in node_ids:
			if not nodes.has(node_id):
				errors.append("%s contains unknown node: %s" % [prefix, node_id])
				continue
			if branch_membership.has(node_id):
				errors.append("node appears in multiple branches: %s" % node_id)
			else:
				branch_membership[node_id] = branch_id

	var unlock_owners := {}
	var prerequisites_by_node := {}
	for node_key in nodes:
		var node_id := String(node_key).strip_edges()
		var value: Variant = nodes[node_key]
		if node_id.is_empty():
			errors.append("nodes contains an empty node id")
			continue
		if not value is Dictionary:
			errors.append("node %s must be a dictionary" % node_id)
			continue
		var node: Dictionary = value
		if String(node.get("id", "")).strip_edges() != node_id:
			errors.append("node %s id must match its dictionary key" % node_id)
		var branch_id := String(node.get("branch_id", "")).strip_edges()
		if not branch_ids.has(branch_id):
			errors.append("node %s references unknown branch: %s" % [node_id, branch_id])
		elif String(branch_membership.get(node_id, "")) != branch_id:
			errors.append("node %s is disconnected from branch %s" % [node_id, branch_id])
		if _positive_int(node.get("tier")) <= 0:
			errors.append("node %s tier must be a positive integer" % node_id)
		if _positive_int(node.get("cost")) <= 0:
			errors.append("node %s cost must be a positive integer" % node_id)
		if String(node.get("build_purpose", "")).strip_edges().is_empty():
			errors.append("node %s build_purpose must be a non-empty string" % node_id)
		var tags := _string_array(node.get("tags"), "node %s tags" % node_id, errors)
		if tags.is_empty():
			errors.append("node %s tags must not be empty" % node_id)
		_validate_unique_strings(tags, "node %s tags" % node_id, errors)
		var prerequisite_ids := _string_array(
			node.get("prerequisite_ids"),
			"node %s prerequisite_ids" % node_id,
			errors
		)
		_validate_unique_strings(prerequisite_ids, "node %s prerequisite_ids" % node_id, errors)
		prerequisites_by_node[node_id] = prerequisite_ids
		for prerequisite_id in prerequisite_ids:
			if prerequisite_id == node_id:
				errors.append("node %s cannot require itself" % node_id)
			elif not nodes.has(prerequisite_id):
				errors.append("node %s has missing prerequisite: %s" % [node_id, prerequisite_id])
			elif nodes[prerequisite_id] is Dictionary:
				var prerequisite_branch := String((nodes[prerequisite_id] as Dictionary).get("branch_id", ""))
				if prerequisite_branch != branch_id:
					errors.append(
						"node %s prerequisite %s must be in the same branch" %
						[node_id, prerequisite_id]
					)
		_validate_unlocks(
			node_id,
			node.get("unlocks"),
			recipe_defs,
			upgrade_defs,
			unlock_owners,
			errors
		)

	for node_key in nodes:
		var node_id := String(node_key)
		if not branch_membership.has(node_id):
			errors.append("node is not connected to any branch: %s" % node_id)
	_validate_cycles(prerequisites_by_node, errors)
	_validate_boss_reveals(tree_def.get("boss_reveals"), nodes, errors)

	for starter_id in starter_ids:
		var starter_unlock_key := "recipe:%s" % starter_id
		if unlock_owners.has(starter_unlock_key):
			errors.append("starter recipe must not also be a research unlock: %s" % starter_id)
	return {"valid": errors.is_empty(), "errors": errors}


func bootstrap_meta(meta: Dictionary, tree_def: Dictionary) -> Dictionary:
	var next_meta := meta.duplicate(true)
	next_meta["research_points"] = maxi(0, int(next_meta.get("research_points", 0)))
	for field in [
		"unlocked_recipe_ids",
		"unlocked_variant_ids",
		"unlocked_upgrade_ids",
		"revealed_research_node_ids",
		"boss_first_clear_ids",
		"applied_reward_transaction_ids"
	]:
		next_meta[field] = _unique_existing_strings(next_meta.get(field, []))
	var unlocked_recipes: Array = next_meta["unlocked_recipe_ids"]
	for recipe_id in _safe_string_array(tree_def.get("starter_recipe_ids")):
		if not unlocked_recipes.has(recipe_id):
			unlocked_recipes.append(recipe_id)
	next_meta["unlocked_recipe_ids"] = unlocked_recipes
	return next_meta


func reveal_for_boss_clear(
	meta: Dictionary,
	encounter_id: String,
	reveal_ids: Variant,
	reward_tx: String
) -> Dictionary:
	var next_meta := meta.duplicate(true)
	var clean_encounter_id := encounter_id.strip_edges()
	var clean_reward_tx := reward_tx.strip_edges()
	if clean_encounter_id.is_empty():
		return _rejected(next_meta, "encounter_id_required")
	if clean_reward_tx.is_empty():
		return _rejected(next_meta, "reward_transaction_id_required")
	var requested_ids := _safe_string_array(reveal_ids)
	if requested_ids.is_empty():
		return _rejected(next_meta, "reveal_ids_required")

	var transactions := _unique_existing_strings(next_meta.get("applied_reward_transaction_ids", []))
	var first_clears := _unique_existing_strings(next_meta.get("boss_first_clear_ids", []))
	if transactions.has(clean_reward_tx) or first_clears.has(clean_encounter_id):
		return _rejected(next_meta)

	var revealed := _unique_existing_strings(next_meta.get("revealed_research_node_ids", []))
	var newly_revealed: Array[String] = []
	for node_id in requested_ids:
		if not revealed.has(node_id):
			revealed.append(node_id)
			newly_revealed.append(node_id)
	first_clears.append(clean_encounter_id)
	transactions.append(clean_reward_tx)
	next_meta["revealed_research_node_ids"] = revealed
	next_meta["boss_first_clear_ids"] = first_clears
	next_meta["applied_reward_transaction_ids"] = transactions
	return {
		"applied": true,
		"meta": next_meta,
		"revealed_node_ids": newly_revealed
	}


func grant_run_completion(meta: Dictionary, points: int, reward_tx: String) -> Dictionary:
	var next_meta := meta.duplicate(true)
	var clean_reward_tx := reward_tx.strip_edges()
	if points <= 0:
		return _rejected(next_meta, "positive_points_required")
	if clean_reward_tx.is_empty():
		return _rejected(next_meta, "reward_transaction_id_required")
	var transactions := _unique_existing_strings(next_meta.get("applied_reward_transaction_ids", []))
	if transactions.has(clean_reward_tx):
		return _rejected(next_meta)
	transactions.append(clean_reward_tx)
	next_meta["applied_reward_transaction_ids"] = transactions
	next_meta["research_points"] = maxi(0, int(next_meta.get("research_points", 0))) + points
	return {
		"applied": true,
		"meta": next_meta,
		"points_granted": points
	}


func node_state(meta: Dictionary, node_id: String, tree_def: Dictionary) -> Dictionary:
	var nodes: Dictionary = tree_def.get("nodes", {})
	if not nodes.has(node_id) or not nodes[node_id] is Dictionary:
		return {
			"exists": false,
			"node_id": node_id,
			"status": "unknown"
		}
	var node: Dictionary = nodes[node_id]
	var revealed_ids := _safe_string_array(meta.get("revealed_research_node_ids"))
	var revealed := revealed_ids.has(node_id)
	var unlocked := _node_is_unlocked(meta, node)
	var missing_prerequisites: Array[String] = []
	for prerequisite_id in _safe_string_array(node.get("prerequisite_ids")):
		if not _node_is_unlocked(meta, nodes.get(prerequisite_id, {})):
			missing_prerequisites.append(prerequisite_id)
	var cost := int(node.get("cost", 0))
	var enough_points := int(meta.get("research_points", 0)) >= cost
	var status := "hidden"
	if unlocked:
		status = "unlocked"
	elif revealed and not missing_prerequisites.is_empty():
		status = "prerequisite_locked"
	elif revealed and not enough_points:
		status = "insufficient_points"
	elif revealed:
		status = "available"
	var state := {
		"exists": true,
		"node_id": node_id,
		"status": status,
		"revealed": revealed,
		"unlocked": unlocked,
		"unlockable": status == "available",
		"missing_prerequisite_ids": missing_prerequisites,
		"enough_points": enough_points
	}
	if revealed or unlocked:
		state["branch_id"] = String(node.get("branch_id", ""))
		state["tier"] = int(node.get("tier", 0))
		state["cost"] = cost
		state["prerequisite_ids"] = _safe_string_array(node.get("prerequisite_ids"))
		state["tags"] = _safe_string_array(node.get("tags"))
		state["build_purpose"] = String(node.get("build_purpose", ""))
		state["unlocks"] = (node.get("unlocks", []) as Array).duplicate(true)
	return state


func unlock_node(
	meta: Dictionary,
	node_id: String,
	tree_def: Dictionary,
	reward_tx: String
) -> Dictionary:
	var next_meta := meta.duplicate(true)
	var clean_reward_tx := reward_tx.strip_edges()
	if clean_reward_tx.is_empty():
		return _rejected(next_meta, "reward_transaction_id_required")
	var transactions := _unique_existing_strings(next_meta.get("applied_reward_transaction_ids", []))
	if transactions.has(clean_reward_tx):
		return _rejected(next_meta)
	var state := node_state(next_meta, node_id, tree_def)
	if not bool(state.get("exists", false)):
		return _rejected(next_meta, "unknown_research_node")
	if bool(state.get("unlocked", false)):
		return _rejected(next_meta)
	if not bool(state.get("revealed", false)):
		return _rejected(next_meta, "research_node_not_revealed")
	if not (state.get("missing_prerequisite_ids", []) as Array).is_empty():
		return _rejected(next_meta, "research_prerequisites_not_met")
	if not bool(state.get("enough_points", false)):
		return _rejected(next_meta, "insufficient_research_points")

	var node: Dictionary = (tree_def.get("nodes", {}) as Dictionary).get(node_id, {})
	var granted_unlocks: Array[Dictionary] = []
	for unlock_value in node.get("unlocks", []):
		var unlock: Dictionary = unlock_value
		var unlock_type := String(unlock.get("type", ""))
		var unlock_id := String(unlock.get("id", ""))
		var meta_field := String(UNLOCK_META_FIELDS.get(unlock_type, ""))
		var unlocked_ids := _unique_existing_strings(next_meta.get(meta_field, []))
		if not unlocked_ids.has(unlock_id):
			unlocked_ids.append(unlock_id)
			granted_unlocks.append(unlock.duplicate(true))
		next_meta[meta_field] = unlocked_ids
	next_meta["research_points"] = int(next_meta.get("research_points", 0)) - int(node.get("cost", 0))
	var revealed := _unique_existing_strings(next_meta.get("revealed_research_node_ids", []))
	var newly_revealed: Array[String] = []
	var nodes: Dictionary = tree_def.get("nodes", {})
	for successor_key in nodes:
		var successor_id := String(successor_key)
		var successor_value: Variant = nodes[successor_key]
		if not successor_value is Dictionary or revealed.has(successor_id):
			continue
		var successor: Dictionary = successor_value
		if (
			String(successor.get("branch_id", "")) == String(node.get("branch_id", ""))
			and _safe_string_array(successor.get("prerequisite_ids")).has(node_id)
		):
			revealed.append(successor_id)
			newly_revealed.append(successor_id)
	next_meta["revealed_research_node_ids"] = revealed
	transactions.append(clean_reward_tx)
	next_meta["applied_reward_transaction_ids"] = transactions
	return {
		"applied": true,
		"meta": next_meta,
		"node_id": node_id,
		"spent_points": int(node.get("cost", 0)),
		"granted_unlocks": granted_unlocks,
		"revealed_node_ids": newly_revealed
	}


func available_recipe_ids(meta: Dictionary, tree_def: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for recipe_id in _safe_string_array(tree_def.get("starter_recipe_ids")):
		if not result.has(recipe_id):
			result.append(recipe_id)
	var unlocked := _safe_string_array(meta.get("unlocked_recipe_ids"))
	var nodes: Dictionary = tree_def.get("nodes", {})
	for branch_value in tree_def.get("branches", []):
		if not branch_value is Dictionary:
			continue
		for node_id in _safe_string_array((branch_value as Dictionary).get("node_ids")):
			var node: Dictionary = nodes.get(node_id, {})
			for unlock_value in node.get("unlocks", []):
				if (
					unlock_value is Dictionary
					and String((unlock_value as Dictionary).get("type", "")) == "recipe"
				):
					var recipe_id := String((unlock_value as Dictionary).get("id", ""))
					if unlocked.has(recipe_id) and not result.has(recipe_id):
						result.append(recipe_id)
	var extras := unlocked.duplicate()
	extras.sort()
	for recipe_id in extras:
		if not result.has(recipe_id):
			result.append(recipe_id)
	return result


func _validate_unlocks(
	node_id: String,
	unlocks_value: Variant,
	recipe_defs: Dictionary,
	upgrade_defs: Dictionary,
	unlock_owners: Dictionary,
	errors: Array[String]
) -> void:
	if not unlocks_value is Array or (unlocks_value as Array).is_empty():
		errors.append("node %s unlocks must be a non-empty array" % node_id)
		return
	for unlock_index in (unlocks_value as Array).size():
		var value: Variant = (unlocks_value as Array)[unlock_index]
		if not value is Dictionary:
			errors.append("node %s unlocks[%d] must be a dictionary" % [node_id, unlock_index])
			continue
		var unlock: Dictionary = value
		var unlock_type := String(unlock.get("type", "")).strip_edges()
		var unlock_id := String(unlock.get("id", "")).strip_edges()
		if not UNLOCK_META_FIELDS.has(unlock_type):
			errors.append("node %s has unknown unlock type: %s" % [node_id, unlock_type])
			continue
		if unlock_id.is_empty():
			errors.append("node %s unlock id must be a non-empty string" % node_id)
			continue
		if unlock_type == "recipe" and (
			not recipe_defs.has(unlock_id) or not recipe_defs[unlock_id] is Dictionary
		):
			errors.append("node %s unlocks unknown recipe: %s" % [node_id, unlock_id])
		if unlock_type == "upgrade" and (
			not upgrade_defs.has(unlock_id) or not upgrade_defs[unlock_id] is Dictionary
		):
			errors.append("node %s unlocks unknown upgrade: %s" % [node_id, unlock_id])
		var unlock_key := "%s:%s" % [unlock_type, unlock_id]
		if unlock_owners.has(unlock_key):
			errors.append(
				"unlock %s is duplicated by nodes %s and %s" %
				[unlock_key, String(unlock_owners[unlock_key]), node_id]
			)
		else:
			unlock_owners[unlock_key] = node_id


func _validate_cycles(prerequisites_by_node: Dictionary, errors: Array[String]) -> void:
	var states := {}
	for node_id in prerequisites_by_node:
		if int(states.get(node_id, 0)) == 0:
			_visit_node(String(node_id), prerequisites_by_node, states, [], errors)


func _visit_node(
	node_id: String,
	prerequisites_by_node: Dictionary,
	states: Dictionary,
	stack: Array[String],
	errors: Array[String]
) -> void:
	var state := int(states.get(node_id, 0))
	if state == 2:
		return
	if state == 1:
		var cycle := stack.duplicate()
		cycle.append(node_id)
		errors.append("research prerequisite cycle: %s" % " -> ".join(cycle))
		return
	states[node_id] = 1
	stack.append(node_id)
	for prerequisite_id in prerequisites_by_node.get(node_id, []):
		if prerequisites_by_node.has(prerequisite_id):
			_visit_node(String(prerequisite_id), prerequisites_by_node, states, stack, errors)
	stack.pop_back()
	states[node_id] = 2


func _validate_boss_reveals(value: Variant, nodes: Dictionary, errors: Array[String]) -> void:
	if not value is Dictionary:
		errors.append("boss_reveals must be a dictionary")
		return
	for encounter_key in value:
		var encounter_id := String(encounter_key).strip_edges()
		if encounter_id.is_empty():
			errors.append("boss_reveals contains an empty encounter id")
			continue
		var reveal_ids := _string_array(
			(value as Dictionary)[encounter_key],
			"boss_reveals.%s" % encounter_id,
			errors
		)
		_validate_unique_strings(reveal_ids, "boss_reveals.%s" % encounter_id, errors)
		for node_id in reveal_ids:
			if not nodes.has(node_id):
				errors.append("boss_reveals.%s contains unknown node: %s" % [encounter_id, node_id])


func _node_is_unlocked(meta: Dictionary, node_value: Variant) -> bool:
	if not node_value is Dictionary:
		return false
	var unlocks_value: Variant = (node_value as Dictionary).get("unlocks")
	if not unlocks_value is Array or (unlocks_value as Array).is_empty():
		return false
	for unlock_value in unlocks_value:
		if not unlock_value is Dictionary:
			return false
		var unlock: Dictionary = unlock_value
		var meta_field := String(UNLOCK_META_FIELDS.get(String(unlock.get("type", "")), ""))
		if meta_field.is_empty():
			return false
		if not _safe_string_array(meta.get(meta_field)).has(String(unlock.get("id", ""))):
			return false
	return true


func _string_array(value: Variant, path: String, errors: Array[String]) -> Array[String]:
	if not value is Array:
		errors.append("%s must be an array of strings" % path)
		return []
	var result: Array[String] = []
	for index in (value as Array).size():
		var item: Variant = (value as Array)[index]
		if not item is String or String(item).strip_edges().is_empty():
			errors.append("%s[%d] must be a non-empty string" % [path, index])
			continue
		result.append(String(item).strip_edges())
	return result


func _safe_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if not value is Array:
		return result
	for item in value:
		if item is String:
			var clean := String(item).strip_edges()
			if not clean.is_empty():
				result.append(clean)
	return result


func _unique_existing_strings(value: Variant) -> Array:
	var result: Array = []
	for item in _safe_string_array(value):
		if not result.has(item):
			result.append(item)
	return result


func _validate_unique_strings(values: Array[String], path: String, errors: Array[String]) -> void:
	var seen := {}
	for value in values:
		if seen.has(value):
			errors.append("%s contains duplicate value: %s" % [path, value])
		else:
			seen[value] = true


func _positive_int(value: Variant) -> int:
	if value is int:
		return int(value)
	if value is float and is_finite(value) and value == floor(value):
		return int(value)
	return -1


func _label(tree_id: String) -> String:
	return tree_id if not tree_id.is_empty() else "research_tree"


func _rejected(meta: Dictionary, error := "") -> Dictionary:
	var result := {
		"applied": false,
		"meta": meta
	}
	if not error.is_empty():
		result["error"] = error
	return result
