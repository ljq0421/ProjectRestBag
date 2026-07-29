class_name RunUpgradeService
extends RefCounted

const EFFECT_TYPES := [
	"supply_budget_add",
	"copy_limit_add",
	"cycle_pct",
	"satisfaction_add",
	"virtual_stock_add",
	"relation_bonus_add",
	"tag_add",
	"shape_variant",
	"first_window_guard"
]
const CATEGORIES := ["compatible", "universal", "pivot"]
const REARRANGE_EFFECT_TYPES := [
	"supply_budget_add",
	"copy_limit_add",
	"cycle_pct",
	"relation_bonus_add",
	"tag_add",
	"shape_variant"
]


func validate_definitions(upgrade_defs: Dictionary, known_recipe_defs: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var universal_count := 0
	var structural_count := 0
	var starter_coverage := {
		"butter_cookie": false,
		"strawberry_jelly": false,
		"milk_pudding": false,
		"blueberry_muffin": false,
		"sponge_cake": false,
		"chocolate_lava_cake": false
	}
	var ids: Array[String] = []
	for key in upgrade_defs.keys():
		ids.append(String(key))
	ids.sort()
	if ids.size() < 12:
		errors.append("upgrade pool must contain at least 12 definitions")

	for upgrade_id in ids:
		var value: Variant = upgrade_defs.get(upgrade_id)
		var prefix := upgrade_id if not upgrade_id.is_empty() else "upgrade"
		if not value is Dictionary:
			errors.append("%s: definition must be a dictionary" % prefix)
			continue
		var definition: Dictionary = value
		if String(definition.get("id", "")) != upgrade_id:
			errors.append("%s: id must match its dictionary key" % prefix)
		if String(definition.get("display_name", "")).strip_edges().is_empty():
			errors.append("%s: display_name must be a non-empty string" % prefix)
		if String(definition.get("description", "")).strip_edges().is_empty():
			errors.append("%s: description must be a non-empty string" % prefix)
		var category := String(definition.get("category", ""))
		if not CATEGORIES.has(category):
			errors.append("%s: unknown category %s" % [prefix, category])
		elif category == "universal":
			universal_count += 1
		if _positive_int(definition.get("max_stacks")) <= 0:
			errors.append("%s: max_stacks must be a positive integer" % prefix)
		if not definition.get("mutual_exclusion_group", "") is String:
			errors.append("%s: mutual_exclusion_group must be a string" % prefix)

		var effect_value: Variant = definition.get("effect")
		if not effect_value is Dictionary:
			errors.append("%s: effect must be a dictionary" % prefix)
			continue
		var effect: Dictionary = effect_value
		var effect_type := String(effect.get("type", ""))
		if not EFFECT_TYPES.has(effect_type):
			errors.append("%s: unknown effect type %s" % [prefix, effect_type])
			continue
		if REARRANGE_EFFECT_TYPES.has(effect_type):
			structural_count += 1
		_validate_effect(prefix, category, effect, known_recipe_defs, errors)
		for recipe_id in _string_array(effect.get("target_recipe_ids", [])):
			if starter_coverage.has(recipe_id) and category == "compatible":
				starter_coverage[recipe_id] = true

	if universal_count < 3:
		errors.append("upgrade pool must contain at least three universal fallbacks")
	if structural_count < 6:
		errors.append("upgrade pool must contain at least six structural definitions")
	for recipe_id in starter_coverage:
		if not bool(starter_coverage[recipe_id]):
			errors.append("starter recipe %s needs a compatible upgrade" % recipe_id)
	return {"valid": errors.is_empty(), "errors": errors}


func generate_offer(
	run_state: Dictionary,
	draft_analysis: Dictionary,
	unlocked_recipe_ids: Array,
	upgrade_defs: Dictionary
) -> Dictionary:
	var run_id := String(run_state.get("run_id", "")).strip_edges()
	var stage_index := int(run_state.get("stage_index", -1))
	if run_id.is_empty() or stage_index < 0:
		return {"ok": false, "error": "invalid_run_identity", "offer": {}}
	var used_recipe_ids := _used_recipe_ids(draft_analysis)
	var used_tags := _used_tags(draft_analysis)
	var unlocked_ids := _unique_sorted_strings(unlocked_recipe_ids)
	var eligible: Array[Dictionary] = []
	var ids: Array[String] = []
	for key in upgrade_defs.keys():
		ids.append(String(key))
	ids.sort()
	for upgrade_id in ids:
		var value: Variant = upgrade_defs.get(upgrade_id)
		if not value is Dictionary:
			continue
		var definition: Dictionary = (value as Dictionary).duplicate(true)
		if not _is_eligible(definition, run_state, used_recipe_ids, used_tags, unlocked_ids):
			continue
		eligible.append(definition)

	var compatible := _filter_category(eligible, "compatible")
	var universal := _filter_category(eligible, "universal")
	var pivot := _filter_category(eligible, "pivot")
	if universal.size() < 3:
		return {"ok": false, "error": "universal_fallback_pool_exhausted", "offer": {}}

	var reward_seed := _reward_seed(run_state, stage_index)
	var signature := _offer_signature(
		run_id,
		stage_index,
		reward_seed,
		used_recipe_ids,
		used_tags,
		run_state.get("run_upgrades", [])
	)
	var selected: Array[Dictionary] = []
	if not compatible.is_empty():
		selected.append(_best_candidate(compatible, signature))
	else:
		selected.append(_best_candidate(universal, signature))
	selected.append(_best_candidate(_without_selected(universal, selected), signature + ":universal"))

	var third_pool: Array[Dictionary] = []
	third_pool.append_array(_without_selected(compatible, selected))
	third_pool.append_array(_without_selected(universal, selected))
	third_pool.append_array(_without_selected(pivot, selected))
	if third_pool.is_empty():
		return {"ok": false, "error": "three_upgrade_candidates_unavailable", "offer": {}}
	selected.append(_best_candidate(third_pool, signature + ":third"))

	var pivot_count := 0
	for definition in selected:
		if String(definition.get("category", "")) == "pivot":
			pivot_count += 1
	if selected.size() != 3 or pivot_count > 1:
		return {"ok": false, "error": "offer_constraints_unsatisfied", "offer": {}}

	var offer_id := "%s:upgrade:%d" % [run_id, stage_index]
	var candidates: Array[Dictionary] = []
	var candidate_ids: Array[String] = []
	for definition in selected:
		var upgrade_id := String(definition.get("id", ""))
		var candidate := definition.duplicate(true)
		candidate["upgrade_id"] = upgrade_id
		candidate["reward_transaction_id"] = "%s:%s" % [offer_id, upgrade_id]
		candidates.append(candidate)
		candidate_ids.append(upgrade_id)
	var offer := {
		"offer_id": offer_id,
		"run_id": run_id,
		"mode": String(run_state.get("mode", "standard")),
		"stage_index": stage_index,
		"reward_seed": reward_seed,
		"input_signature": signature,
		"candidate_ids": candidate_ids,
		"candidates": candidates
	}
	return {"ok": true, "offer": offer.duplicate(true)}


func apply_choice(run_state: Dictionary, offer: Dictionary, upgrade_id: String) -> Dictionary:
	var next_run := run_state.duplicate(true)
	var candidate := _candidate_from_offer(offer, upgrade_id)
	if candidate.is_empty():
		return _rejected(next_run, "upgrade_not_offered")
	var reward_transaction_id := String(candidate.get("reward_transaction_id", "")).strip_edges()
	var expected_transaction_id := "%s:%s" % [String(offer.get("offer_id", "")), upgrade_id]
	if reward_transaction_id.is_empty() or reward_transaction_id != expected_transaction_id:
		return _rejected(next_run, "invalid_upgrade_reward_transaction")
	var transactions: Array = next_run.get("applied_run_reward_transaction_ids", [])
	if transactions.has(reward_transaction_id):
		return _rejected(next_run)

	var max_stacks := _positive_int(candidate.get("max_stacks"))
	var existing_index := _upgrade_index(next_run.get("run_upgrades", []), upgrade_id)
	var existing_stacks := _upgrade_stack_count(next_run.get("run_upgrades", []), upgrade_id)
	if max_stacks <= 0 or existing_stacks >= max_stacks:
		return _rejected(next_run, "upgrade_stack_limit_reached")
	var group := String(candidate.get("mutual_exclusion_group", ""))
	if not group.is_empty() and _has_other_exclusion_group(
		next_run.get("run_upgrades", []),
		group,
		upgrade_id
	):
		return _rejected(next_run, "upgrade_mutually_excluded")

	var upgrades: Array = next_run.get("run_upgrades", [])
	if existing_index >= 0:
		var entry: Dictionary = (upgrades[existing_index] as Dictionary).duplicate(true)
		entry["stack_count"] = existing_stacks + 1
		var entry_transactions: Array = entry.get("reward_transaction_ids", [])
		entry_transactions.append(reward_transaction_id)
		entry["reward_transaction_ids"] = entry_transactions
		upgrades[existing_index] = entry
	else:
		upgrades.append({
			"upgrade_id": upgrade_id,
			"stack_count": 1,
			"definition": _definition_from_candidate(candidate),
			"reward_transaction_ids": [reward_transaction_id]
		})
	transactions.append(reward_transaction_id)
	next_run["run_upgrades"] = upgrades
	next_run["applied_run_reward_transaction_ids"] = transactions
	return {
		"applied": true,
		"run": next_run,
		"upgrade_id": upgrade_id,
		"stack_count": existing_stacks + 1,
		"reward_transaction_id": reward_transaction_id
	}


func resolve_context(
	base_recipe_defs: Dictionary,
	base_rules: Dictionary,
	run_upgrades: Array
) -> Dictionary:
	var recipe_defs := base_recipe_defs.duplicate(true)
	var rules := base_rules.duplicate(true)
	if not rules.has("supply_budget"):
		rules["supply_budget"] = 0
	if not rules.has("first_window_guard"):
		rules["first_window_guard"] = 0
	if not rules.has("relation_bonus_add"):
		rules["relation_bonus_add"] = {}
	if not rules.has("upgrade_source_ids"):
		rules["upgrade_source_ids"] = []
	if not rules.has("first_window_guard_source_ids"):
		rules["first_window_guard_source_ids"] = []
	if not rules.has("relation_bonus_source_ids"):
		rules["relation_bonus_source_ids"] = {}
	var applied: Array[Dictionary] = []
	for value in run_upgrades:
		var normalized := _normalize_upgrade_entry(value)
		if normalized.is_empty():
			continue
		var definition: Dictionary = normalized.get("definition", {})
		var stack_count := int(normalized.get("stack_count", 0))
		for _stack_index in range(stack_count):
			_apply_effect(
				recipe_defs,
				rules,
				definition.get("effect", {}),
				String(normalized.get("upgrade_id", ""))
			)
		applied.append({
			"upgrade_id": String(normalized.get("upgrade_id", "")),
			"stack_count": stack_count
		})
	return {
		"recipe_defs": recipe_defs,
		"rules": rules,
		"applied_upgrades": applied
	}


func describe_effect(
	before_context: Dictionary,
	after_context: Dictionary,
	upgrade_id: String
) -> Dictionary:
	var changes: Array[Dictionary] = []
	var affected_recipe_ids: Array[String] = []
	var before_recipes: Dictionary = before_context.get("recipe_defs", {})
	var after_recipes: Dictionary = after_context.get("recipe_defs", {})
	var recipe_ids: Array[String] = []
	for key in before_recipes.keys():
		recipe_ids.append(String(key))
	for key in after_recipes.keys():
		var recipe_id := String(key)
		if not recipe_ids.has(recipe_id):
			recipe_ids.append(recipe_id)
	recipe_ids.sort()
	for recipe_id in recipe_ids:
		var before: Dictionary = before_recipes.get(recipe_id, {})
		var after: Dictionary = after_recipes.get(recipe_id, {})
		for field in [
			"shape_cells",
			"rotatable",
			"copy_limit",
			"cycle_ms",
			"satisfaction",
			"virtual_stock",
			"tags"
		]:
			if not _variants_equal(before.get(field), after.get(field)):
				changes.append({
					"scope": "recipe",
					"target_id": recipe_id,
					"field": field,
					"before": before.get(field),
					"after": after.get(field)
				})
				if not affected_recipe_ids.has(recipe_id):
					affected_recipe_ids.append(recipe_id)
	var before_rules: Dictionary = before_context.get("rules", {})
	var after_rules: Dictionary = after_context.get("rules", {})
	var rule_keys: Array[String] = []
	for key in before_rules.keys():
		rule_keys.append(String(key))
	for key in after_rules.keys():
		var rule_id := String(key)
		if not rule_keys.has(rule_id):
			rule_keys.append(rule_id)
	rule_keys.sort()
	for field in rule_keys:
		if not _variants_equal(before_rules.get(field), after_rules.get(field)):
			changes.append({
				"scope": "rules",
				"target_id": "run",
				"field": field,
				"before": before_rules.get(field),
				"after": after_rules.get(field)
			})
	var rearrange_fields := [
		"shape_cells",
		"rotatable",
		"copy_limit",
		"cycle_ms",
		"tags",
		"supply_budget",
		"relation_bonus_add"
	]
	var recommends_rearrange := false
	for change in changes:
		if rearrange_fields.has(String(change.get("field", ""))):
			recommends_rearrange = true
			break
	return {
		"upgrade_id": upgrade_id,
		"affected_recipe_ids": affected_recipe_ids,
		"changes": changes,
		"recommends_rearrange": recommends_rearrange
	}


func _validate_effect(
	prefix: String,
	category: String,
	effect: Dictionary,
	known_recipe_defs: Dictionary,
	errors: Array[String]
) -> void:
	var effect_type := String(effect.get("type", ""))
	var target_recipe_ids := _string_array(effect.get("target_recipe_ids", []))
	var target_tags := _string_array(effect.get("target_tags", []))
	for recipe_id in target_recipe_ids:
		if not known_recipe_defs.has(recipe_id) or not known_recipe_defs[recipe_id] is Dictionary:
			errors.append("%s: unknown target recipe %s" % [prefix, recipe_id])
	if category == "compatible" and target_recipe_ids.is_empty() and target_tags.is_empty():
		errors.append("%s: compatible upgrade must target a recipe or tag" % prefix)
	if category == "pivot" and target_recipe_ids.is_empty() and target_tags.is_empty():
		errors.append("%s: pivot upgrade must target a recipe or tag" % prefix)
	if effect_type in [
		"supply_budget_add",
		"copy_limit_add",
		"satisfaction_add",
		"virtual_stock_add",
		"relation_bonus_add",
		"first_window_guard"
	] and _positive_int(effect.get("value")) <= 0:
		errors.append("%s: effect value must be a positive integer" % prefix)
	if effect_type == "cycle_pct":
		var value = effect.get("value")
		if not _is_integer_number(value) or int(value) == 0 or int(value) <= -100:
			errors.append("%s: cycle_pct value must be an integer greater than -100 and not zero" % prefix)
		if _positive_int(effect.get("min_cycle_ms")) <= 0:
			errors.append("%s: cycle_pct min_cycle_ms must be a positive integer" % prefix)
	if effect_type == "tag_add" and String(effect.get("tag", "")).strip_edges().is_empty():
		errors.append("%s: tag_add requires a non-empty tag" % prefix)
	if effect_type == "shape_variant":
		var cells = effect.get("shape_cells")
		if not cells is Array or cells.is_empty():
			errors.append("%s: shape_variant requires non-empty shape_cells" % prefix)
		else:
			var seen := {}
			for cell in cells:
				if not cell is Array or cell.size() != 2 or not _is_integer_number(cell[0]) or not _is_integer_number(cell[1]):
					errors.append("%s: shape cells must be integer [row, column] pairs" % prefix)
					continue
				var cell_key := "%d:%d" % [int(cell[0]), int(cell[1])]
				if seen.has(cell_key):
					errors.append("%s: shape cells must be unique" % prefix)
				seen[cell_key] = true


func _is_eligible(
	definition: Dictionary,
	run_state: Dictionary,
	used_recipe_ids: Array[String],
	used_tags: Array[String],
	unlocked_recipe_ids: Array[String]
) -> bool:
	var upgrade_id := String(definition.get("id", ""))
	if upgrade_id.is_empty():
		return false
	if _upgrade_stack_count(run_state.get("run_upgrades", []), upgrade_id) >= int(definition.get("max_stacks", 0)):
		return false
	var group := String(definition.get("mutual_exclusion_group", ""))
	if not group.is_empty() and _has_other_exclusion_group(run_state.get("run_upgrades", []), group, upgrade_id):
		return false
	var effect: Dictionary = definition.get("effect", {})
	var target_recipe_ids := _string_array(effect.get("target_recipe_ids", []))
	var target_tags := _string_array(effect.get("target_tags", []))
	var category := String(definition.get("category", ""))
	if category == "universal":
		return true
	if category == "compatible":
		return _intersects(target_recipe_ids, used_recipe_ids) or _intersects(target_tags, used_tags)
	if category == "pivot":
		for recipe_id in target_recipe_ids:
			if unlocked_recipe_ids.has(recipe_id) and not used_recipe_ids.has(recipe_id):
				return true
		return false
	return false


func _apply_effect(
	recipe_defs: Dictionary,
	rules: Dictionary,
	effect_value: Variant,
	upgrade_id: String
) -> void:
	if not effect_value is Dictionary:
		return
	var effect: Dictionary = effect_value
	var effect_type := String(effect.get("type", ""))
	var value := int(effect.get("value", 0))
	if effect_type == "supply_budget_add":
		rules["supply_budget"] = int(rules.get("supply_budget", 0)) + value
		_append_unique_string(rules, "upgrade_source_ids", upgrade_id)
		return
	if effect_type == "first_window_guard":
		rules["first_window_guard"] = int(rules.get("first_window_guard", 0)) + value
		_append_unique_string(rules, "first_window_guard_source_ids", upgrade_id)
		return
	if effect_type == "relation_bonus_add":
		var bonuses: Dictionary = (rules.get("relation_bonus_add", {}) as Dictionary).duplicate(true)
		var relation_id := String(effect.get("relation_id", "global"))
		bonuses[relation_id] = int(bonuses.get(relation_id, 0)) + value
		rules["relation_bonus_add"] = bonuses
		var sources: Dictionary = (rules.get("relation_bonus_source_ids", {}) as Dictionary).duplicate(true)
		var relation_sources := _string_array(sources.get(relation_id, []))
		if not upgrade_id.is_empty() and not relation_sources.has(upgrade_id):
			relation_sources.append(upgrade_id)
			relation_sources.sort()
		sources[relation_id] = relation_sources
		rules["relation_bonus_source_ids"] = sources
		return
	for recipe_id in _effect_recipe_ids(recipe_defs, effect):
		var recipe: Dictionary = (recipe_defs.get(recipe_id, {}) as Dictionary).duplicate(true)
		match effect_type:
			"copy_limit_add":
				recipe["copy_limit"] = int(recipe.get("copy_limit", 0)) + value
			"cycle_pct":
				var adjusted := roundi(float(recipe.get("cycle_ms", 0)) * (100.0 + float(value)) / 100.0)
				recipe["cycle_ms"] = maxi(int(effect.get("min_cycle_ms", 1)), adjusted)
			"satisfaction_add":
				recipe["satisfaction"] = int(recipe.get("satisfaction", 0)) + value
			"virtual_stock_add":
				recipe["virtual_stock"] = int(recipe.get("virtual_stock", 0)) + value
			"tag_add":
				var tags: Array = (recipe.get("tags", []) as Array).duplicate()
				var tag := String(effect.get("tag", ""))
				if not tag.is_empty() and not tags.has(tag):
					tags.append(tag)
					tags.sort()
				recipe["tags"] = tags
			"shape_variant":
				recipe["shape_cells"] = (effect.get("shape_cells", []) as Array).duplicate(true)
				if effect.has("rotatable"):
					recipe["rotatable"] = bool(effect.get("rotatable", false))
		_append_unique_string(recipe, "_upgrade_source_ids", upgrade_id)
		recipe_defs[recipe_id] = recipe


func _append_unique_string(target: Dictionary, field: String, value: String) -> void:
	if value.is_empty():
		return
	var values := _string_array(target.get(field, []))
	if not values.has(value):
		values.append(value)
		values.sort()
	target[field] = values


func _effect_recipe_ids(recipe_defs: Dictionary, effect: Dictionary) -> Array[String]:
	var explicit_ids := _string_array(effect.get("target_recipe_ids", []))
	var target_tags := _string_array(effect.get("target_tags", []))
	var result: Array[String] = []
	var ids: Array[String] = []
	for key in recipe_defs.keys():
		ids.append(String(key))
	ids.sort()
	for recipe_id in ids:
		if not explicit_ids.is_empty() and not explicit_ids.has(recipe_id):
			continue
		if not target_tags.is_empty():
			var recipe: Dictionary = recipe_defs.get(recipe_id, {})
			var recipe_tags := _string_array(recipe.get("tags", []))
			if not _intersects(target_tags, recipe_tags):
				continue
		result.append(recipe_id)
	return result


func _used_recipe_ids(draft_analysis: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	for value in draft_analysis.get("instances", draft_analysis.get("placements", [])):
		if not value is Dictionary:
			continue
		var recipe_id := String((value as Dictionary).get("recipe_id", "")).strip_edges()
		if not recipe_id.is_empty() and not ids.has(recipe_id):
			ids.append(recipe_id)
	ids.sort()
	return ids


func _used_tags(draft_analysis: Dictionary) -> Array[String]:
	var tags: Array[String] = []
	for value in draft_analysis.get("instances", []):
		if not value is Dictionary:
			continue
		for tag in _string_array((value as Dictionary).get("tags", [])):
			if not tags.has(tag):
				tags.append(tag)
	tags.sort()
	return tags


func _reward_seed(run_state: Dictionary, stage_index: int) -> int:
	if run_state.has("reward_seed"):
		return int(run_state.get("reward_seed", 0))
	var encounters: Array = run_state.get("encounter_instances", [])
	if stage_index >= 0 and stage_index < encounters.size() and encounters[stage_index] is Dictionary:
		return int((encounters[stage_index] as Dictionary).get("reward_seed", run_state.get("seed", 0)))
	return int(run_state.get("seed", 0))


func _offer_signature(
	run_id: String,
	stage_index: int,
	reward_seed: int,
	used_recipe_ids: Array[String],
	used_tags: Array[String],
	run_upgrades: Array
) -> String:
	var layers: Array[String] = []
	for value in run_upgrades:
		var entry := _normalize_upgrade_entry(value)
		if not entry.is_empty():
			layers.append("%s:%d" % [String(entry.get("upgrade_id", "")), int(entry.get("stack_count", 0))])
	layers.sort()
	return "%s|%d|%d|%s|%s|%s" % [
		run_id,
		stage_index,
		reward_seed,
		",".join(used_recipe_ids),
		",".join(used_tags),
		",".join(layers)
	]


func _best_candidate(candidates: Array[Dictionary], signature: String) -> Dictionary:
	var ranked := candidates.duplicate(true)
	ranked.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_id := String(left.get("id", ""))
		var right_id := String(right.get("id", ""))
		var left_score := _stable_hash("%s|%s" % [signature, left_id])
		var right_score := _stable_hash("%s|%s" % [signature, right_id])
		return left_score < right_score or (left_score == right_score and left_id < right_id)
	)
	return ranked[0].duplicate(true) if not ranked.is_empty() else {}


func _stable_hash(value: String) -> int:
	var result := 216613626
	for index in value.length():
		result = int(posmod(result * 16777619 + value.unicode_at(index), 2147483647))
	return result


func _filter_category(definitions: Array[Dictionary], category: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for definition in definitions:
		if String(definition.get("category", "")) == category:
			result.append(definition)
	return result


func _without_selected(
	definitions: Array[Dictionary],
	selected: Array[Dictionary]
) -> Array[Dictionary]:
	var selected_ids: Array[String] = []
	for definition in selected:
		selected_ids.append(String(definition.get("id", "")))
	var result: Array[Dictionary] = []
	for definition in definitions:
		if not selected_ids.has(String(definition.get("id", ""))):
			result.append(definition)
	return result


func _candidate_from_offer(offer: Dictionary, upgrade_id: String) -> Dictionary:
	for value in offer.get("candidates", []):
		if value is Dictionary and String((value as Dictionary).get("upgrade_id", "")) == upgrade_id:
			return (value as Dictionary).duplicate(true)
	return {}


func _definition_from_candidate(candidate: Dictionary) -> Dictionary:
	var definition := candidate.duplicate(true)
	definition.erase("upgrade_id")
	definition.erase("reward_transaction_id")
	return definition


func _upgrade_index(run_upgrades: Array, upgrade_id: String) -> int:
	for index in run_upgrades.size():
		var value: Variant = run_upgrades[index]
		if value is Dictionary and String((value as Dictionary).get("upgrade_id", "")) == upgrade_id:
			return index
	return -1


func _upgrade_stack_count(run_upgrades: Array, upgrade_id: String) -> int:
	var count := 0
	for value in run_upgrades:
		if value is String and String(value) == upgrade_id:
			count += 1
		elif value is Dictionary and String((value as Dictionary).get("upgrade_id", "")) == upgrade_id:
			count += maxi(0, int((value as Dictionary).get("stack_count", 1)))
	return count


func _has_other_exclusion_group(run_upgrades: Array, group: String, upgrade_id: String) -> bool:
	for value in run_upgrades:
		var entry := _normalize_upgrade_entry(value)
		if entry.is_empty() or String(entry.get("upgrade_id", "")) == upgrade_id:
			continue
		var definition: Dictionary = entry.get("definition", {})
		if String(definition.get("mutual_exclusion_group", "")) == group:
			return true
	return false


func _normalize_upgrade_entry(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {}
	var entry: Dictionary = value
	var definition_value: Variant = entry.get("definition")
	if not definition_value is Dictionary:
		return {}
	return {
		"upgrade_id": String(entry.get("upgrade_id", "")),
		"stack_count": maxi(0, int(entry.get("stack_count", 0))),
		"definition": (definition_value as Dictionary).duplicate(true)
	}


func _intersects(left: Array[String], right: Array[String]) -> bool:
	for value in left:
		if right.has(value):
			return true
	return false


func _unique_sorted_strings(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		var text := String(value).strip_edges()
		if not text.is_empty() and not result.has(text):
			result.append(text)
	result.sort()
	return result


func _string_array(value: Variant) -> Array[String]:
	if not value is Array:
		return []
	return _unique_sorted_strings(value)


func _positive_int(value: Variant) -> int:
	if value is int:
		return int(value) if int(value) > 0 else 0
	if value is float and is_equal_approx(value, float(int(value))):
		return int(value) if int(value) > 0 else 0
	return 0


func _is_integer_number(value: Variant) -> bool:
	return value is int or (value is float and is_equal_approx(value, float(int(value))))


func _variants_equal(left: Variant, right: Variant) -> bool:
	return JSON.stringify(left) == JSON.stringify(right)


func _rejected(run_state: Dictionary, error := "") -> Dictionary:
	var result := {"applied": false, "run": run_state}
	if not error.is_empty():
		result["error"] = error
	return result
