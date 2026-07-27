class_name ChallengeConfigValidator
extends RefCounted

const KNOWN_METRICS := [
	"sales_count",
	"active_relation_count",
	"window_satisfaction"
]


func validate(recipe_config: Dictionary, encounter_config: Dictionary, catalog_recipes: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var grid_rows := _positive_int(recipe_config, "grid_rows", "recipe_config", errors)
	var grid_columns := _positive_int(recipe_config, "grid_columns", "recipe_config", errors)
	var supply_budget := _positive_int(recipe_config, "supply_budget", "recipe_config", errors)
	var recipe_defs := _dictionary_value(recipe_config, "recipes", "recipe_config", errors)
	var encounters := _dictionary_value(encounter_config, "encounters", "encounter_config", errors)

	for recipe_id_variant in recipe_defs:
		var recipe_id := String(recipe_id_variant)
		var value = recipe_defs[recipe_id_variant]
		if not value is Dictionary:
			errors.append("%s: definition must be a dictionary" % recipe_id)
			continue
		_validate_recipe(recipe_id, value, catalog_recipes, errors)

	for encounter_id_variant in encounters:
		var encounter_id := String(encounter_id_variant)
		var value = encounters[encounter_id_variant]
		if not value is Dictionary:
			errors.append("%s: definition must be a dictionary" % encounter_id)
			continue
		_validate_encounter(encounter_id, value, errors)

	if grid_rows > 0 and grid_columns > 0 and supply_budget > 0 and not recipe_defs.is_empty():
		for encounter_id_variant in encounters:
			var encounter_id := String(encounter_id_variant)
			var encounter_value = encounters[encounter_id_variant]
			if encounter_value is Dictionary and not _has_theoretical_loadout(
				recipe_defs,
				encounter_value,
				supply_budget,
				grid_rows * grid_columns
			):
				errors.append("%s: no theoretical loadout satisfies all demand windows and final pickiness" % encounter_id)

	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"recipe_defs": recipe_defs,
		"encounters": encounters
	}


func _validate_recipe(
	recipe_id: String,
	definition: Dictionary,
	catalog_recipes: Dictionary,
	errors: Array[String]
) -> void:
	if not catalog_recipes.has(recipe_id):
		errors.append("%s: recipe is not present in Catalog" % recipe_id)

	var shape_value = definition.get("shape_cells")
	if not shape_value is Array or shape_value.is_empty():
		errors.append("%s: shape_cells must be a non-empty array" % recipe_id)
	else:
		var occupied := {}
		for cell_value in shape_value:
			if not cell_value is Array or cell_value.size() != 2:
				errors.append("%s: every shape cell must be [row, column]" % recipe_id)
				continue
			var row_value = cell_value[0]
			var column_value = cell_value[1]
			if not _is_integer_number(row_value) or not _is_integer_number(column_value):
				errors.append("%s: shape coordinates must be integers" % recipe_id)
				continue
			var row := int(row_value)
			var column := int(column_value)
			if row < 0 or column < 0:
				errors.append("%s: shape coordinates must be non-negative" % recipe_id)
			var key := "%d:%d" % [row, column]
			if occupied.has(key):
				errors.append("%s: shape cells must be unique" % recipe_id)
			occupied[key] = true

	for key in ["supply_cost", "copy_limit", "virtual_stock", "cycle_ms", "satisfaction"]:
		_positive_int(definition, key, recipe_id, errors)

	var tags_value = definition.get("tags")
	if not tags_value is Array or tags_value.is_empty():
		errors.append("%s: tags must be a non-empty array" % recipe_id)
	else:
		var known_tags := {}
		for tag_value in tags_value:
			var tag := String(tag_value).strip_edges()
			if tag.is_empty():
				errors.append("%s: tags must be non-empty strings" % recipe_id)
			elif known_tags.has(tag):
				errors.append("%s: tags must be unique" % recipe_id)
			known_tags[tag] = true

	if not definition.has("rotatable") or not definition["rotatable"] is bool:
		errors.append("%s: rotatable must be a boolean" % recipe_id)


func _validate_encounter(encounter_id: String, encounter: Dictionary, errors: Array[String]) -> void:
	var duration_ms := _positive_int(encounter, "duration_ms", encounter_id, errors)
	_positive_int(encounter, "initial_pickiness", encounter_id, errors)
	_positive_int(encounter, "initial_reputation", encounter_id, errors)
	var relation_bonus_pct := _positive_int(encounter, "relation_bonus_pct", encounter_id, errors)
	if relation_bonus_pct > 1000:
		errors.append("%s: relation_bonus_pct is unreasonably large" % encounter_id)

	var relation := _dictionary_value(encounter, "relation", encounter_id, errors)
	for key in ["id", "left_tag", "right_tag"]:
		if String(relation.get(key, "")).strip_edges().is_empty():
			errors.append("%s: relation.%s must be a non-empty string" % [encounter_id, key])

	var windows_value = encounter.get("windows")
	if not windows_value is Array or windows_value.is_empty():
		errors.append("%s: windows must be a non-empty array" % encounter_id)
		return

	var previous_at := -1
	var known_ids := {}
	for index in windows_value.size():
		var window_value = windows_value[index]
		if not window_value is Dictionary:
			errors.append("%s: window %d must be a dictionary" % [encounter_id, index])
			continue
		var window: Dictionary = window_value
		var window_id := String(window.get("id", "")).strip_edges()
		var prefix := "%s.%s" % [encounter_id, window_id if not window_id.is_empty() else "window_%d" % index]
		if window_id.is_empty():
			errors.append("%s: id must be a non-empty string" % prefix)
		elif known_ids.has(window_id):
			errors.append("%s: window IDs must be unique" % prefix)
		known_ids[window_id] = true
		var at_ms := _positive_int(window, "at_ms", prefix, errors)
		_positive_int(window, "target", prefix, errors, true)
		_positive_int(window, "reputation_damage", prefix, errors)
		var metric := String(window.get("metric", ""))
		if not KNOWN_METRICS.has(metric):
			errors.append("%s: unknown metric %s" % [prefix, metric])
		if at_ms <= previous_at:
			errors.append("%s: demand windows must be strictly ordered" % prefix)
		if duration_ms > 0 and at_ms >= duration_ms:
			errors.append("%s: demand window must occur before duration" % prefix)
		previous_at = at_ms
		if metric == "window_satisfaction":
			var from_ms := _positive_int(window, "from_ms", prefix, errors, true)
			if from_ms >= at_ms:
				errors.append("%s: from_ms must be earlier than at_ms" % prefix)


func _has_theoretical_loadout(
	recipe_defs: Dictionary,
	encounter: Dictionary,
	supply_budget: int,
	cell_budget: int
) -> bool:
	var recipe_ids: Array[String] = []
	for recipe_id in recipe_defs:
		if recipe_defs[recipe_id] is Dictionary and _recipe_is_simulatable(recipe_defs[recipe_id]):
			recipe_ids.append(String(recipe_id))
	if recipe_ids.is_empty():
		return false
	recipe_ids.sort()
	return _enumerate_loadouts(recipe_ids, recipe_defs, encounter, supply_budget, cell_budget, 0, {})


func _enumerate_loadouts(
	recipe_ids: Array[String],
	recipe_defs: Dictionary,
	encounter: Dictionary,
	supply_budget: int,
	cell_budget: int,
	index: int,
	counts: Dictionary
) -> bool:
	if index >= recipe_ids.size():
		return _loadout_satisfies(recipe_ids, recipe_defs, encounter, counts)

	var recipe_id := recipe_ids[index]
	var definition: Dictionary = recipe_defs[recipe_id]
	var cost := int(definition["supply_cost"])
	var cells: int = definition["shape_cells"].size()
	var copy_limit := int(definition["copy_limit"])
	for count in copy_limit + 1:
		var used_cost := count * cost
		var used_cells: int = count * cells
		if used_cost > supply_budget or used_cells > cell_budget:
			break
		counts[recipe_id] = count
		if _enumerate_loadouts(
			recipe_ids,
			recipe_defs,
			encounter,
			supply_budget - used_cost,
			cell_budget - used_cells,
			index + 1,
			counts
		):
			return true
	counts.erase(recipe_id)
	return false


func _loadout_satisfies(
	recipe_ids: Array[String],
	recipe_defs: Dictionary,
	encounter: Dictionary,
	counts: Dictionary
) -> bool:
	var relation: Dictionary = encounter.get("relation", {})
	var left_tag := String(relation.get("left_tag", ""))
	var right_tag := String(relation.get("right_tag", ""))
	var left_count := _tagged_instance_count(recipe_ids, recipe_defs, counts, left_tag)
	var right_count := _tagged_instance_count(recipe_ids, recipe_defs, counts, right_tag)
	var relation_count := mini(left_count, right_count)
	var bonus_pct := int(encounter.get("relation_bonus_pct", 0))

	for window_value in encounter.get("windows", []):
		if not window_value is Dictionary:
			return false
		var window: Dictionary = window_value
		var metric := String(window.get("metric", ""))
		var target := int(window.get("target", 0))
		var actual := 0
		match metric:
			"sales_count":
				actual = _sales_count_at(recipe_ids, recipe_defs, counts, int(window.get("at_ms", 0)))
			"active_relation_count":
				actual = relation_count
			"window_satisfaction":
				actual = _satisfaction_between(
					recipe_ids,
					recipe_defs,
					counts,
					int(window.get("from_ms", 0)),
					int(window.get("at_ms", 0)),
					left_tag,
					right_tag,
					relation_count > 0,
					bonus_pct
				)
			_:
				return false
		if actual < target:
			return false

	var duration_ms := int(encounter.get("duration_ms", 0))
	var total_satisfaction := _satisfaction_between(
		recipe_ids,
		recipe_defs,
		counts,
		0,
		duration_ms,
		left_tag,
		right_tag,
		relation_count > 0,
		bonus_pct
	)
	return total_satisfaction >= int(encounter.get("initial_pickiness", 0))


func _sales_count_at(
	recipe_ids: Array[String],
	recipe_defs: Dictionary,
	counts: Dictionary,
	at_ms: int
) -> int:
	var total := 0
	for recipe_id in recipe_ids:
		var count := int(counts.get(recipe_id, 0))
		if count <= 0:
			continue
		var definition: Dictionary = recipe_defs[recipe_id]
		var sales_per_instance := mini(int(definition["virtual_stock"]), at_ms / int(definition["cycle_ms"]))
		total += count * sales_per_instance
	return total


func _satisfaction_between(
	recipe_ids: Array[String],
	recipe_defs: Dictionary,
	counts: Dictionary,
	from_ms: int,
	to_ms: int,
	left_tag: String,
	right_tag: String,
	relation_active: bool,
	bonus_pct: int
) -> int:
	var total := 0
	for recipe_id in recipe_ids:
		var count := int(counts.get(recipe_id, 0))
		if count <= 0:
			continue
		var definition: Dictionary = recipe_defs[recipe_id]
		var cycle_ms := int(definition["cycle_ms"])
		var stock := int(definition["virtual_stock"])
		var sales_to := mini(stock, to_ms / cycle_ms)
		var sales_from := mini(stock, from_ms / cycle_ms)
		var sales := maxi(0, sales_to - sales_from)
		var satisfaction := int(definition["satisfaction"])
		var tags: Array = definition["tags"]
		if relation_active and (tags.has(left_tag) or tags.has(right_tag)):
			satisfaction = satisfaction * (100 + bonus_pct) / 100
		total += count * sales * satisfaction
	return total


func _tagged_instance_count(
	recipe_ids: Array[String],
	recipe_defs: Dictionary,
	counts: Dictionary,
	tag: String
) -> int:
	if tag.is_empty():
		return 0
	var total := 0
	for recipe_id in recipe_ids:
		var definition: Dictionary = recipe_defs[recipe_id]
		var tags: Array = definition.get("tags", [])
		if tags.has(tag):
			total += int(counts.get(recipe_id, 0))
	return total


func _recipe_is_simulatable(definition: Dictionary) -> bool:
	if not definition.get("shape_cells") is Array or definition.get("shape_cells", []).is_empty():
		return false
	for key in ["supply_cost", "copy_limit", "virtual_stock", "cycle_ms", "satisfaction"]:
		if not _is_positive_int(definition.get(key)):
			return false
	return definition.get("tags") is Array


func _dictionary_value(
	source: Dictionary,
	key: String,
	prefix: String,
	errors: Array[String]
) -> Dictionary:
	var value = source.get(key)
	if not value is Dictionary:
		errors.append("%s: %s must be a dictionary" % [prefix, key])
		return {}
	return value


func _positive_int(
	source: Dictionary,
	key: String,
	prefix: String,
	errors: Array[String],
	allow_zero: bool = false
) -> int:
	var value = source.get(key)
	if not _is_integer_number(value):
		errors.append("%s: %s must be an integer" % [prefix, key])
		return 0
	var number := int(value)
	if number < 0 or (number == 0 and not allow_zero):
		errors.append("%s: %s must be %s" % [prefix, key, "zero or positive" if allow_zero else "positive"])
	return number


func _is_positive_int(value: Variant) -> bool:
	return _is_integer_number(value) and int(value) > 0


func _is_integer_number(value: Variant) -> bool:
	if value is int:
		return true
	if value is float:
		return is_equal_approx(value, float(int(value)))
	return false
