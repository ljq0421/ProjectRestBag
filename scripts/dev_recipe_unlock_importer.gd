class_name DevRecipeUnlockImporter
extends RefCounted

const CoreFeatureUnlockService := preload("res://scripts/core_feature_unlock_service.gd")

const SHOWCASE_MANIFEST_PATH := "res://resources/recipe_icons_showcase/showcase_icon_manifest.json"
const GROWTH_SUFFIXES := ["_popular", "_signature"]


static func parse_manifest(path: String, recipes: Dictionary) -> Dictionary:
	if path.is_empty() or not FileAccess.file_exists(path):
		return _parse_failure("Markdown 文件不存在：%s" % path)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _parse_failure("Markdown 文件无法读取：%s" % path)
	var text := file.get_as_text()
	file.close()
	var result := parse_markdown_text(text, recipes)
	result["path"] = path
	return result


static func parse_markdown_text(markdown: String, recipes: Dictionary) -> Dictionary:
	var recipe_ids: Array[String] = []
	var ignored_ids: Array[String] = []
	var bare_id_regex := RegEx.new()
	bare_id_regex.compile("^([a-z0-9_]+)$")
	var path_regex := RegEx.new()
	path_regex.compile("(?:res://)?resources/recipe_icons/([a-z0-9_]+)\\.png")
	var heading_regex := RegEx.new()
	heading_regex.compile("^\\s*#{1,6}\\s+.*[\\(（]([a-z0-9_]+)[\\)）]\\s*$")

	for line_value: Variant in markdown.split("\n"):
		var line := String(line_value).strip_edges()
		var bare_id_match := bare_id_regex.search(line)
		if bare_id_match != null:
			_append_parsed_candidate(bare_id_match.get_string(1), recipes, recipe_ids, ignored_ids)
		for match_value: Variant in path_regex.search_all(line):
			var path_match := match_value as RegExMatch
			_append_parsed_candidate(_base_recipe_id(path_match.get_string(1)), recipes, recipe_ids, ignored_ids)
		var heading_match := heading_regex.search(line)
		if heading_match != null:
			_append_parsed_candidate(_base_recipe_id(heading_match.get_string(1)), recipes, recipe_ids, ignored_ids)

	return {
		"ok": not recipe_ids.is_empty(),
		"recipe_ids": recipe_ids,
		"ignored_ids": ignored_ids,
		"errors": [] if not recipe_ids.is_empty() else ["Markdown 中没有找到合法配方 ID。"],
	}


static func build_plan(parsed: Dictionary, catalog) -> Dictionary:
	var target_ids := _string_array(parsed.get("recipe_ids", []))
	if not bool(parsed.get("ok", false)) or target_ids.is_empty():
		return {
			"ok": false,
			"target_recipe_ids": [],
			"recipe_ids": [],
			"device_ids": [],
			"process_unlock_ids": [],
			"purchase_unlock_ids": [],
			"required_level": 0,
			"invalid_targets": [],
			"missing_assets": [],
			"ignored_ids": _string_array(parsed.get("ignored_ids", [])),
			"errors": (parsed.get("errors", []) as Array).duplicate(true),
		}

	var recipes: Dictionary = catalog.get_recipes()
	var ingredients: Dictionary = catalog.get_ingredients()
	var devices: Dictionary = catalog.get_devices()
	var processes: Dictionary = catalog.get_processing_recipes()
	var production_sites: Dictionary = catalog.get_production_sites()
	var context := {
		"recipes": recipes,
		"ingredients": ingredients,
		"devices": devices,
		"processes_by_output": _processing_by_output(processes),
		"producers_by_output": _producers_by_output(ingredients),
		"site_items": _production_site_items(production_sites),
	}
	var merged := _empty_branch()
	var valid_targets: Array[String] = []
	var invalid_targets: Array[Dictionary] = []
	for target_id in target_ids:
		var branch := _empty_branch()
		var error := _collect_recipe_dependency(target_id, context, branch, {})
		if not error.is_empty():
			invalid_targets.append({"recipe_id": target_id, "reason": error})
			continue
		valid_targets.append(target_id)
		_merge_branch(merged, branch)

	return {
		"ok": not valid_targets.is_empty(),
		"target_recipe_ids": valid_targets,
		"recipe_ids": _string_array(merged.get("recipe_ids", [])),
		"device_ids": _string_array(merged.get("device_ids", [])),
		"process_unlock_ids": _string_array(merged.get("process_unlock_ids", [])),
		"purchase_unlock_ids": _string_array(merged.get("purchase_unlock_ids", [])),
		"required_level": int(merged.get("required_level", 0)),
		"invalid_targets": invalid_targets,
		"missing_assets": audit_icon_assets(valid_targets),
		"ignored_ids": _string_array(parsed.get("ignored_ids", [])),
		"errors": [] if not valid_targets.is_empty() else ["所有目标配方的依赖都无效。"],
	}


static func audit_icon_assets(recipe_ids: Array[String]) -> Array[Dictionary]:
	var missing: Array[Dictionary] = []
	for recipe_id in recipe_ids:
		for surface in [
			["base", "res://resources/recipe_icons/%s.png" % recipe_id],
			["catalog", "res://resources/recipe_icons_catalog/%s.png" % recipe_id],
			["action", "res://resources/recipe_icons_action/%s.png" % recipe_id],
			["inventory", "res://resources/recipe_icons_inventory/%s.png" % recipe_id],
		]:
			var path := String(surface[1])
			if not ResourceLoader.exists(path):
				missing.append({"recipe_id": recipe_id, "surface": String(surface[0]), "path": path})

	var manifest: Dictionary = {}
	if FileAccess.file_exists(SHOWCASE_MANIFEST_PATH):
		var parsed_manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(SHOWCASE_MANIFEST_PATH))
		if parsed_manifest is Dictionary:
			manifest = parsed_manifest
	var entries: Dictionary = manifest.get("entries", {}) if manifest.get("entries", {}) is Dictionary else {}
	for recipe_id in recipe_ids:
		var found_standard := false
		for entry_value: Variant in entries.values():
			if not entry_value is Dictionary:
				continue
			var entry: Dictionary = entry_value
			if String(entry.get("recipe_id", "")) != recipe_id or String(entry.get("variant_id", "standard")) != "standard":
				continue
			found_standard = true
			var texture_path := String(entry.get("texture_path", ""))
			if texture_path.is_empty() or not ResourceLoader.exists(texture_path):
				missing.append({"recipe_id": recipe_id, "surface": "showcase_texture", "path": texture_path})
		if not found_standard:
			missing.append({"recipe_id": recipe_id, "surface": "showcase_manifest", "path": SHOWCASE_MANIFEST_PATH})
	return missing


static func snapshot_state(state) -> Dictionary:
	if state == null:
		return {}
	return {
		"level": int(state.level),
		"core_feature_unlocks": state.core_feature_unlocks.duplicate(true),
		"unlocked_devices": state.unlocked_devices.duplicate(true),
		"device_growth": state.device_growth.duplicate(true),
		"ingredient_purchase_unlocks": state.ingredient_purchase_unlocks.duplicate(true),
		"ingredient_process_unlocks": state.ingredient_process_unlocks.duplicate(true),
		"unlocked_recipes": state.unlocked_recipes.duplicate(true),
		"feedback_log": state.feedback_log.duplicate(true),
	}


static func restore_snapshot(state, snapshot: Dictionary) -> bool:
	if state == null or snapshot.is_empty():
		return false
	state.level = int(snapshot.get("level", state.level))
	state.core_feature_unlocks = (snapshot.get("core_feature_unlocks", {}) as Dictionary).duplicate(true)
	state.unlocked_devices = _string_array(snapshot.get("unlocked_devices", []))
	state.device_growth = (snapshot.get("device_growth", {}) as Dictionary).duplicate(true)
	state.ingredient_purchase_unlocks = _string_array(snapshot.get("ingredient_purchase_unlocks", []))
	state.ingredient_process_unlocks = _string_array(snapshot.get("ingredient_process_unlocks", []))
	state.unlocked_recipes = _string_array(snapshot.get("unlocked_recipes", []))
	state.feedback_log = _string_array(snapshot.get("feedback_log", []))
	return true


static func apply_plan(state, plan: Dictionary) -> Dictionary:
	if state == null or not bool(plan.get("ok", false)):
		return {"ok": false, "errors": ["没有可应用的游戏状态或导入计划。"]}
	var before_level := int(state.level)
	state.level = maxi(before_level, int(plan.get("required_level", before_level)))
	var added_core_count := 0
	for feature_id in CoreFeatureUnlockService.ORDER:
		if not state.is_core_feature_unlocked(feature_id) and state.unlock_core_feature(feature_id):
			added_core_count += 1
		if feature_id == CoreFeatureUnlockService.LIST:
			break

	var added_device_count := 0
	var existing_device_count := 0
	for device_id in _string_array(plan.get("device_ids", [])):
		if state.unlocked_devices.has(device_id):
			existing_device_count += 1
		elif state.unlock_device(device_id):
			added_device_count += 1

	var added_process_count := 0
	var existing_process_count := 0
	for item_id in _string_array(plan.get("process_unlock_ids", [])):
		if state.is_ingredient_process_unlocked(item_id):
			existing_process_count += 1
		elif state.unlock_ingredient_process(item_id):
			added_process_count += 1

	var added_purchase_count := 0
	var existing_purchase_count := 0
	for item_id in _string_array(plan.get("purchase_unlock_ids", [])):
		if state.is_ingredient_purchase_unlocked(item_id):
			existing_purchase_count += 1
		elif state.unlock_ingredient_purchase(item_id):
			added_purchase_count += 1

	var target_lookup := {}
	for recipe_id in _string_array(plan.get("target_recipe_ids", [])):
		target_lookup[recipe_id] = true
	var added_recipe_count := 0
	var existing_recipe_count := 0
	var rejected_recipe_ids: Array[String] = []
	var added_prerequisite_count := 0
	for recipe_id in _string_array(plan.get("recipe_ids", [])):
		if state.is_recipe_unlocked(recipe_id):
			existing_recipe_count += 1
		elif state.add_recipe(recipe_id, false):
			added_recipe_count += 1
			if not target_lookup.has(recipe_id):
				added_prerequisite_count += 1
		else:
			rejected_recipe_ids.append(recipe_id)

	return {
		"ok": rejected_recipe_ids.is_empty(),
		"before_level": before_level,
		"after_level": int(state.level),
		"added_core_count": added_core_count,
		"added_device_count": added_device_count,
		"existing_device_count": existing_device_count,
		"added_process_count": added_process_count,
		"existing_process_count": existing_process_count,
		"added_purchase_count": added_purchase_count,
		"existing_purchase_count": existing_purchase_count,
		"added_recipe_count": added_recipe_count,
		"existing_recipe_count": existing_recipe_count,
		"added_prerequisite_count": added_prerequisite_count,
		"rejected_recipe_ids": rejected_recipe_ids,
		"errors": [] if rejected_recipe_ids.is_empty() else ["部分配方未能写入解锁列表。"],
	}


static func _collect_recipe_dependency(recipe_id: String, context: Dictionary, branch: Dictionary, visiting: Dictionary) -> String:
	var recipes: Dictionary = context.get("recipes", {})
	if not recipes.has(recipe_id):
		return "配方不存在：%s" % recipe_id
	if (_string_array(branch.get("recipe_ids", []))).has(recipe_id):
		return ""
	if bool(visiting.get(recipe_id, false)):
		return "配方依赖形成循环：%s" % recipe_id
	visiting[recipe_id] = true
	var recipe: Dictionary = recipes[recipe_id]
	_update_required_level(branch, int(recipe.get("unlock_level", 0)))
	var device_error := _collect_device(String(recipe.get("device", "")), context, branch)
	if not device_error.is_empty():
		visiting.erase(recipe_id)
		return device_error
	for material_value: Variant in recipe.get("materials", []):
		var material_id := String(material_value)
		var error := ""
		if recipes.has(material_id):
			error = _collect_recipe_dependency(material_id, context, branch, visiting)
		else:
			error = _collect_ingredient_dependency(material_id, context, branch, {})
		if not error.is_empty():
			visiting.erase(recipe_id)
			return "%s 依赖无效：%s" % [recipe_id, error]
	visiting.erase(recipe_id)
	_append_unique(branch["recipe_ids"], recipe_id)
	return ""


static func _collect_ingredient_dependency(item_id: String, context: Dictionary, branch: Dictionary, visiting: Dictionary) -> String:
	var ingredients: Dictionary = context.get("ingredients", {})
	if not ingredients.has(item_id):
		return "原料不存在：%s" % item_id
	if bool(visiting.get(item_id, false)):
		return "原料依赖形成循环：%s" % item_id
	visiting[item_id] = true
	var ingredient: Dictionary = ingredients[item_id]
	_update_required_level(branch, int(ingredient.get("unlock_level", 0)))

	var processes_by_output: Dictionary = context.get("processes_by_output", {})
	if processes_by_output.has(item_id):
		var process: Dictionary = processes_by_output[item_id]
		_update_required_level(branch, int(process.get("unlock_level", 0)))
		var device_error := _collect_device(String(process.get("device", "")), context, branch)
		if not device_error.is_empty():
			visiting.erase(item_id)
			return device_error
		_append_unique(branch["process_unlock_ids"], item_id)
		if not String(ingredient.get("purchase_unlock_condition", "")).is_empty():
			_append_unique(branch["purchase_unlock_ids"], item_id)
		for input_value: Variant in process.get("materials", []):
			var error := _collect_ingredient_dependency(String(input_value), context, branch, visiting)
			if not error.is_empty():
				visiting.erase(item_id)
				return "%s 加工依赖无效：%s" % [item_id, error]
		visiting.erase(item_id)
		return ""

	if not bool(ingredient.get("purchasable", true)):
		var producers_by_output: Dictionary = context.get("producers_by_output", {})
		if producers_by_output.has(item_id):
			var producer_ids := _string_array(producers_by_output[item_id])
			if not producer_ids.is_empty():
				var producer_error := _collect_ingredient_dependency(producer_ids[0], context, branch, visiting)
				if not producer_error.is_empty():
					visiting.erase(item_id)
					return "%s 生产来源无效：%s" % [item_id, producer_error]
		elif not bool((context.get("site_items", {}) as Dictionary).get(item_id, false)):
			visiting.erase(item_id)
			return "原料没有可用采购、加工或生产来源：%s" % item_id
	visiting.erase(item_id)
	return ""


static func _collect_device(device_id: String, context: Dictionary, branch: Dictionary) -> String:
	if device_id.is_empty():
		return "缺少设备 ID"
	var devices: Dictionary = context.get("devices", {})
	if not devices.has(device_id):
		return "设备不存在：%s" % device_id
	_append_unique(branch["device_ids"], device_id)
	return ""


static func _processing_by_output(processes: Dictionary) -> Dictionary:
	var result := {}
	var process_ids: Array = processes.keys()
	process_ids.sort()
	for process_id_value: Variant in process_ids:
		var process: Dictionary = processes[process_id_value]
		var output_id := String(process.get("output_item_id", ""))
		if not output_id.is_empty() and not result.has(output_id):
			result[output_id] = process
	return result


static func _producers_by_output(ingredients: Dictionary) -> Dictionary:
	var result := {}
	var item_ids: Array = ingredients.keys()
	item_ids.sort()
	for item_id_value: Variant in item_ids:
		var item_id := String(item_id_value)
		var ingredient: Dictionary = ingredients[item_id_value]
		var output_ids: Array[String] = []
		var single_output_id := String(ingredient.get("harvest_item_id", ""))
		if not single_output_id.is_empty():
			output_ids.append(single_output_id)
		var harvest_outputs: Dictionary = ingredient.get("harvest_outputs", {}) if ingredient.get("harvest_outputs", {}) is Dictionary else {}
		var harvest_output_ids: Array = harvest_outputs.keys()
		harvest_output_ids.sort()
		for output_id_value: Variant in harvest_output_ids:
			var output_id := String(output_id_value)
			if not output_ids.has(output_id):
				output_ids.append(output_id)
		for output_id in output_ids:
			if not result.has(output_id):
				result[output_id] = []
			_append_unique(result[output_id], item_id)
	return result


static func _production_site_items(production_sites: Dictionary) -> Dictionary:
	var result := {}
	for site_value: Variant in production_sites.values():
		if not site_value is Dictionary:
			continue
		for item_value: Variant in (site_value as Dictionary).get("items", []):
			result[String(item_value)] = true
	return result


static func _empty_branch() -> Dictionary:
	return {
		"recipe_ids": [],
		"device_ids": [],
		"process_unlock_ids": [],
		"purchase_unlock_ids": [],
		"required_level": 0,
	}


static func _merge_branch(target: Dictionary, source: Dictionary) -> void:
	for key in ["recipe_ids", "device_ids", "process_unlock_ids", "purchase_unlock_ids"]:
		for value: Variant in source.get(key, []):
			_append_unique(target[key], String(value))
	_update_required_level(target, int(source.get("required_level", 0)))


static func _update_required_level(branch: Dictionary, level: int) -> void:
	branch["required_level"] = maxi(int(branch.get("required_level", 0)), maxi(0, level))


static func _append_parsed_candidate(candidate: String, recipes: Dictionary, recipe_ids: Array[String], ignored_ids: Array[String]) -> void:
	if candidate.is_empty():
		return
	if recipes.has(candidate):
		if not recipe_ids.has(candidate):
			recipe_ids.append(candidate)
	elif not ignored_ids.has(candidate):
		ignored_ids.append(candidate)


static func _base_recipe_id(candidate: String) -> String:
	var result := candidate
	for suffix in GROWTH_SUFFIXES:
		if result.ends_with(suffix):
			return result.trim_suffix(suffix)
	return result


static func _append_unique(target: Array, value: String) -> void:
	if not value.is_empty() and not target.has(value):
		target.append(value)


static func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if not value is Array:
		return result
	for entry: Variant in value:
		var text := String(entry)
		if not text.is_empty() and not result.has(text):
			result.append(text)
	return result


static func _parse_failure(message: String) -> Dictionary:
	return {"ok": false, "recipe_ids": [], "ignored_ids": [], "errors": [message]}
