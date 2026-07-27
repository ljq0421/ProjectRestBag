class_name RecipeBook
extends RefCounted

const Catalog = preload("res://scripts/catalog.gd")
const DeviceGrowthService = preload("res://scripts/device_growth_service.gd")
const TutorialProgress = preload("res://scripts/tutorial_progress.gd")

static func research(state, device_id: String, material_ids: Array, notify_unlock: bool = true) -> Dictionary:
	if state == null:
		return _fail("没有可用的游戏状态。")

	var catalog := Catalog.new()
	var devices: Dictionary = catalog.get_devices()
	var recipes: Dictionary = catalog.get_recipes()
	var ingredients: Dictionary = catalog.get_ingredients()
	var selected: Array[String] = _normalize_materials(material_ids)
	var hint_key := _research_key(device_id, selected)
	if selected.size() < 2:
		return _fail_research(state, hint_key, "研发需要至少选择 2 个材料。")
	if state.has_method("record_task_event"):
		state.record_task_event("research_attempt", {
			"device_id": device_id,
			"material_count": selected.size()
		})

	var unknown: Array[String] = []
	for material_id in selected:
		if not ingredients.has(material_id) and not recipes.has(material_id):
			unknown.append(material_id)
	if not unknown.is_empty():
		return _fail_research(state, hint_key, "这些材料没有研发线索：%s。" % ", ".join(unknown))

	var insufficient: Array[String] = _missing_inventory(state, selected, 1, ingredients, recipes)
	if not insufficient.is_empty():
		return _fail_research(state, hint_key, "库存不足，缺少：%s。" % _names_for_ids(insufficient, ingredients, recipes))

	if not devices.has(device_id):
		return _fail_research(state, hint_key, "未知设备，先确认研发设备。", selected, ingredients, recipes, true)

	var selected_lookup := _array_lookup(selected)
	var direct_matches := _matching_recipes(recipes, selected_lookup, device_id, true)
	if not direct_matches.is_empty():
		var recipe := _best_recipe(direct_matches)
		var recipe_id: String = String(recipe.get("id", ""))
		if int(recipe.get("unlock_level", 1)) > _state_level(state):
			return _fail_research(state, hint_key, "%s 需要店铺等级 %d，先升级店铺。" % [
				String(recipe.get("name", recipe_id)),
				int(recipe.get("unlock_level", 1))
			], selected, ingredients, recipes, true)
		if not _research_tool_available(state, device_id, catalog):
			return _fail_research(state, hint_key, "工具尚未解锁，先完成前置任务。", selected, ingredients, recipes, true)

		if state.is_recipe_unlocked(recipe_id):
			return _fail_research(state, hint_key, "%s 已经研发过了。" % String(recipe.get("name", recipe_id)), selected, ingredients, recipes, true)

		var recipe_materials: Array[String] = _normalize_materials(recipe.get("materials", []))
		_consume_materials(state, recipe_materials, 1, ingredients, recipes)
		if not state.add_recipe(recipe_id, notify_unlock):
			return _fail_research(state, hint_key, "研发成功但配方无法解锁，请检查店铺等级。")
		if state.has_method("record_device_research_success"):
			state.record_device_research_success(device_id)

		state.reputation = int(state.reputation) + _research_reputation_reward(recipe)
		_add_log(state, "recipe_research:%s" % recipe_id)
		TutorialProgress.on_recipe_unlocked(state, recipe_id)
		return {
			"ok": true,
			"recipe_id": recipe_id,
			"message": "研发成功：%s。" % String(recipe.get("name", recipe_id))
		}

	var wrong_device_matches := _matching_recipes(recipes, selected_lookup, device_id, false)
	if not wrong_device_matches.is_empty():
		var wrong_device_recipe := _best_recipe(wrong_device_matches)
		var required_device_id: String = String(wrong_device_recipe.get("device", ""))
		var required_device: Dictionary = devices.get(required_device_id, {})
		return _fail_research_with_hint(state, hint_key, "设备不对，%s 更适合用 %s 研发。" % [
			String(wrong_device_recipe.get("name", wrong_device_recipe.get("id", ""))),
			String(required_device.get("name", required_device_id))
		], device_id, selected, ingredients, recipes, devices, true)

	var missing_one := _recipes_missing_one_material(recipes, selected_lookup, device_id)
	if not missing_one.is_empty():
		var missing_recipe := _best_recipe(missing_one)
		var missing_id := _first_missing_material(missing_recipe, selected_lookup)
		return _fail_research_with_hint(state, hint_key, "还缺 1 个材料：%s，可能接近 %s。" % [
			_material_name(missing_id, ingredients, recipes),
			String(missing_recipe.get("name", missing_recipe.get("id", "")))
		], device_id, selected, ingredients, recipes, devices, true)

	return _fail_research_with_hint(
		state,
		hint_key,
		"这个组合暂时没有研发线索，换一组设备或材料试试。",
		device_id,
		selected,
		ingredients,
		recipes,
		devices,
		true
	)


static func research_hint_view(state, device_id: String, material_ids: Array) -> Dictionary:
	if state == null:
		return {}
	var catalog := Catalog.new()
	var ingredients: Dictionary = catalog.get_ingredients()
	var recipes: Dictionary = catalog.get_recipes()
	var devices: Dictionary = catalog.get_devices()
	var selected := _normalize_hint_materials(material_ids)
	var latest_recipe_id := String(state.latest_research_hint_recipe_id) if state != null else ""
	if not latest_recipe_id.is_empty() and int(state.research_hint_level(latest_recipe_id)) > 0:
		var latest := _research_hint_for_target(
			state,
			latest_recipe_id,
			device_id,
			selected,
			ingredients,
			recipes,
			devices,
			int(state.research_hint_level(latest_recipe_id))
		)
		if not latest.is_empty():
			return latest
	return _research_hint_for_attempt(state, device_id, selected, ingredients, recipes, devices, 0)


static func make_product(state, recipe_id: String, batches: int, now_unix: int = -1) -> Dictionary:
	if state == null:
		return _fail("没有可用的游戏状态。")
	if batches != 1:
		return _fail("手动制作每次只能开始 1 批。")

	var catalog := Catalog.new()
	var recipes: Dictionary = catalog.get_recipes()
	var ingredients: Dictionary = catalog.get_ingredients()
	if not recipes.has(recipe_id):
		return _fail("未知配方，无法生产。")
	if not state.is_recipe_unlocked(recipe_id):
		return _fail("配方尚未解锁，先完成研发。")

	var recipe: Dictionary = recipes[recipe_id]
	var device_id := String(recipe.get("device", ""))
	if device_id.is_empty() or not state.is_device_unlocked(device_id):
		var device_name := String(catalog.get_devices().get(device_id, {}).get("name", device_id))
		return _fail("设备%s未解锁，暂时无法制作。" % device_name)
	var materials: Array[String] = _normalize_materials(recipe.get("materials", []))
	var insufficient: Array[String] = _missing_inventory(state, materials, batches, ingredients, recipes)
	if not insufficient.is_empty():
		return _fail("库存不足，缺少：%s。" % _names_for_ids(insufficient, ingredients, recipes))

	var output_count: int = maxi(1, int(recipe.get("output_count", 1))) * batches
	if not state.queue_recipe_production(recipe_id, batches, now_unix, "manual"):
		return _fail("暂时无法开始制作，请检查设备与材料。")
	var duration_seconds := maxi(1, int(recipe.get("production_duration_seconds", 1)))
	_add_log(state, "recipe_make_start:%s:%d:%d" % [recipe_id, batches, output_count])
	return {
		"ok": true,
		"status": "started",
		"recipe_id": recipe_id,
		"output_count": output_count,
		"duration_seconds": duration_seconds,
		"message": "已开始制作：%s，预计 %d 秒。" % [String(recipe.get("name", recipe_id)), duration_seconds]
	}


static func process_ingredient(state, device_id: String, material_ids: Array, now_unix: int = -1) -> Dictionary:
	if state == null:
		return _fail("没有可用的游戏状态。")

	var catalog := Catalog.new()
	var devices: Dictionary = catalog.get_devices()
	var processes: Dictionary = catalog.get_processing_recipes()
	var ingredients: Dictionary = catalog.get_ingredients()
	var selected: Array[String] = _normalize_materials(material_ids)
	if selected.is_empty():
		return _fail("加工需要至少选择 1 个原料。")

	var unknown: Array[String] = []
	for material_id in selected:
		if not ingredients.has(material_id):
			unknown.append(material_id)
	if not unknown.is_empty():
		return _fail("这些原料无法用于加工：%s。" % ", ".join(unknown))

	var insufficient: Array[String] = _missing_inventory(state, selected, 1, ingredients, {})
	if not insufficient.is_empty():
		return _fail("库存不足，缺少：%s。" % _names_for_ids(insufficient, ingredients, {}))

	if not devices.has(device_id):
		return _fail("未知设备，先确认加工设备。")

	var selected_lookup := _array_lookup(selected)
	var direct_matches := _matching_processes(processes, selected_lookup, device_id, true)
	if not direct_matches.is_empty():
		var process := _best_recipe(direct_matches)
		var process_id := String(process.get("id", ""))
		if int(process.get("unlock_level", 1)) > _state_level(state):
			return _fail("%s 需要店铺等级 %d，先升级店铺。" % [
				String(process.get("name", process_id)),
				int(process.get("unlock_level", 1))
			])
		if not _research_tool_available(state, device_id, catalog):
			return _fail("工具尚未解锁，先完成前置任务。")

		var output_item_id := String(process.get("output_item_id", ""))
		if not ingredients.has(output_item_id):
			return _fail("加工产物不存在，请检查配置。")
		var output_count := maxi(1, int(process.get("output_count", 1)))
		if state.has_method("active_ingredient_processing_count") \
				and int(state.active_ingredient_processing_count(process_id)) > 0:
			return _fail("%s 已在加工中，每种配方同时只能制作 1 批。" % String(process.get("name", process_id)))
		if not state.has_method("queue_ingredient_processing") \
				or not state.queue_ingredient_processing(process_id, now_unix, "manual"):
			return _fail("暂时无法开始加工，请检查设备与材料。")
		var duration_seconds := maxi(1, int(process.get("production_duration_seconds", 1)))
		_add_log(state, "ingredient_process_start:%s:%s:%d" % [process_id, output_item_id, output_count])
		return {
			"ok": true,
			"status": "started",
			"process_id": process_id,
			"ingredient_id": output_item_id,
			"output_count": output_count,
			"duration_seconds": duration_seconds,
			"message": "已开始加工：%s，预计 %d 秒。" % [
				String(ingredients[output_item_id].get("name", output_item_id)),
				duration_seconds
			]
		}

	var wrong_device_matches := _matching_processes(processes, selected_lookup, device_id, false)
	if not wrong_device_matches.is_empty():
		var wrong_device_process := _best_recipe(wrong_device_matches)
		var required_device_id := String(wrong_device_process.get("device", ""))
		var required_device: Dictionary = devices.get(required_device_id, {})
		return _fail("设备不对，%s 更适合用 %s 加工。" % [
			String(wrong_device_process.get("name", wrong_device_process.get("id", ""))),
			String(required_device.get("name", required_device_id))
		])

	return _fail("这个组合暂时没有加工线索，换一组设备或原料试试。")


static func _matching_recipes(recipes: Dictionary, selected_lookup: Dictionary, device_id: String, require_device: bool) -> Array[Dictionary]:
	var matches: Array[Dictionary] = []
	for recipe_id: Variant in recipes.keys():
		var recipe: Dictionary = recipes[recipe_id]
		var device_matches := String(recipe.get("device", "")) == device_id
		if require_device != device_matches:
			continue
		if _materials_contain_all(recipe.get("materials", []), selected_lookup):
			matches.append(recipe)
	return matches


static func _matching_processes(processes: Dictionary, selected_lookup: Dictionary, device_id: String, require_device: bool) -> Array[Dictionary]:
	var matches: Array[Dictionary] = []
	for process_id: Variant in processes.keys():
		var process: Dictionary = processes[process_id]
		var device_matches := String(process.get("device", "")) == device_id
		if require_device != device_matches:
			continue
		if _materials_match_exactly(process.get("materials", []), selected_lookup):
			matches.append(process)
	return matches


static func _recipes_missing_one_material(recipes: Dictionary, selected_lookup: Dictionary, device_id: String) -> Array[Dictionary]:
	var matches: Array[Dictionary] = []
	for recipe_id: Variant in recipes.keys():
		var recipe: Dictionary = recipes[recipe_id]
		if String(recipe.get("device", "")) != device_id:
			continue

		var materials: Array = recipe.get("materials", [])
		var missing_count := 0
		for material_id: Variant in materials:
			if not selected_lookup.has(String(material_id)):
				missing_count += 1
		if missing_count == 1:
			matches.append(recipe)
	return matches


static func _materials_match_exactly(materials_value: Variant, selected_lookup: Dictionary) -> bool:
	if not materials_value is Array:
		return false

	var materials: Array = materials_value
	if materials.size() != selected_lookup.size():
		return false
	for material_id: Variant in materials:
		if not selected_lookup.has(String(material_id)):
			return false
	return true


static func _materials_contain_all(materials_value: Variant, selected_lookup: Dictionary) -> bool:
	if not materials_value is Array:
		return false

	var materials: Array = materials_value
	for material_id: Variant in materials:
		if not selected_lookup.has(String(material_id)):
			return false
	return true


static func _best_recipe(candidates: Array[Dictionary]) -> Dictionary:
	var best: Dictionary = {}
	for recipe in candidates:
		var rank := _recipe_rank(recipe)
		var best_rank := _recipe_rank(best)
		if best.is_empty() or rank > best_rank or (rank == best_rank and _recipe_id(recipe) < _recipe_id(best)):
			best = recipe
	return best


static func _recipe_id(recipe: Dictionary) -> String:
	return String(recipe.get("id", ""))


static func _recipe_rank(recipe: Dictionary) -> int:
	var materials: Array = recipe.get("materials", [])
	return materials.size() * 100 + int(recipe.get("unlock_level", 1))


static func _first_missing_material(recipe: Dictionary, selected_lookup: Dictionary) -> String:
	var materials: Array = recipe.get("materials", [])
	for material_id: Variant in materials:
		var id := String(material_id)
		if not selected_lookup.has(id):
			return id
	return ""


static func _normalize_materials(raw_materials: Variant) -> Array[String]:
	var normalized: Array[String] = []
	if not raw_materials is Array:
		return normalized

	var materials: Array = raw_materials
	for material_id: Variant in materials:
		var id := String(material_id)
		if id.is_empty() or normalized.has(id):
			continue
		normalized.append(id)
	return normalized


static func _normalize_hint_materials(raw_materials: Variant) -> Array[String]:
	var normalized: Array[String] = []
	if not raw_materials is Array:
		return normalized
	for material_value: Variant in (raw_materials as Array):
		var material_id := String(material_value)
		if not material_id.is_empty():
			normalized.append(material_id)
	return normalized


static func _material_counts(material_ids: Array[String]) -> Dictionary:
	var counts := {}
	for material_id in material_ids:
		counts[material_id] = int(counts.get(material_id, 0)) + 1
	return counts


static func _research_hint_for_attempt(
	state,
	device_id: String,
	selected: Array[String],
	ingredients: Dictionary,
	recipes: Dictionary,
	devices: Dictionary,
	level: int
) -> Dictionary:
	var best_recipe_id := ""
	var best_score: Array[int] = []
	var recipe_ids: Array = recipes.keys()
	recipe_ids.sort()
	for recipe_value: Variant in recipe_ids:
		var recipe_id := String(recipe_value)
		var recipe: Dictionary = recipes.get(recipe_id, {})
		if not _research_hint_recipe_is_eligible(state, recipe_id, recipe, devices):
			continue
		var details := _research_hint_match_details(recipe.get("materials", []), selected)
		var matched_count := int(details.get("matched_count", 0))
		if matched_count <= 0:
			continue
		var score: Array[int] = [
			matched_count,
			1 if String(recipe.get("device", "")) == device_id else 0,
			-_variant_array_size(details.get("extra_material_ids", [])),
			-_variant_array_size(details.get("missing_material_ids", []))
		]
		if best_recipe_id.is_empty() or _research_hint_score_is_better(score, recipe_id, best_score, best_recipe_id):
			best_recipe_id = recipe_id
			best_score = score
	if best_recipe_id.is_empty():
		return {}
	return _research_hint_for_target(state, best_recipe_id, device_id, selected, ingredients, recipes, devices, level)


static func _research_hint_score_is_better(
	score: Array[int],
	recipe_id: String,
	best_score: Array[int],
	best_recipe_id: String
) -> bool:
	for index in range(score.size()):
		if index >= best_score.size():
			return true
		if score[index] != best_score[index]:
			return score[index] > best_score[index]
	return recipe_id < best_recipe_id


static func _research_hint_recipe_is_eligible(state, recipe_id: String, recipe: Dictionary, devices: Dictionary) -> bool:
	if recipe.is_empty() or recipe_id.is_empty():
		return false
	if state.is_recipe_unlocked(recipe_id):
		return false
	if int(recipe.get("unlock_level", 1)) > _state_level(state):
		return false
	var required_device_id := String(recipe.get("device", ""))
	if not devices.has(required_device_id):
		return false
	if state.has_method("is_device_unlocked"):
		return state.is_device_unlocked(required_device_id)
	return int(devices[required_device_id].get("unlock_level", 1)) <= _state_level(state)


static func _research_hint_for_target(
	state,
	recipe_id: String,
	device_id: String,
	selected: Array[String],
	ingredients: Dictionary,
	recipes: Dictionary,
	devices: Dictionary,
	level: int
) -> Dictionary:
	var recipe: Dictionary = recipes.get(recipe_id, {})
	if not _research_hint_recipe_is_eligible(state, recipe_id, recipe, devices):
		return {}
	var details := _research_hint_match_details(recipe.get("materials", []), selected)
	var required_device_id := String(recipe.get("device", ""))
	var missing_material_ids: Array = details.get("missing_material_ids", [])
	var missing_categories: Array[String] = []
	for material_value: Variant in missing_material_ids:
		var category := _material_category(String(material_value), ingredients, recipes)
		if not missing_categories.has(category):
			missing_categories.append(category)
	return {
		"target_recipe_id": recipe_id,
		"level": clampi(level, 0, 3),
		"direction": String(devices.get(required_device_id, {}).get("research_meaning", "研发")),
		"recipe_name": String(recipe.get("name", recipe_id)) if level >= 2 else "",
		"matched_count": int(details.get("matched_count", 0)),
		"required_count": _variant_array_size(recipe.get("materials", [])),
		"correct_device_id": required_device_id if level >= 2 else "",
		"wrong_device": required_device_id != device_id,
		"missing_categories": missing_categories if level >= 2 else [],
		"missing_material_ids": missing_material_ids if level >= 3 else [],
		"extra_material_ids": details.get("extra_material_ids", []) if level >= 3 else [],
		"material_statuses": details.get("material_statuses", []) if level >= 3 else []
	}


static func _research_hint_match_details(materials_value: Variant, selected: Array[String]) -> Dictionary:
	var required: Array[String] = _normalize_hint_materials(materials_value)
	var selected_counts := _material_counts(selected)
	var remaining_selected: Dictionary = selected_counts.duplicate(true)
	var missing: Array[String] = []
	var statuses: Array[Dictionary] = []
	var matched_count := 0
	for material_id in required:
		var remaining := int(remaining_selected.get(material_id, 0))
		if remaining > 0:
			matched_count += 1
			remaining_selected[material_id] = remaining - 1
			statuses.append({"item_id": material_id, "status": "已有"})
		else:
			missing.append(material_id)
			statuses.append({"item_id": material_id, "status": "缺少"})
	var extra: Array[String] = []
	for material_id in selected:
		var remaining_extra := int(remaining_selected.get(material_id, 0))
		if remaining_extra <= 0:
			continue
		extra.append(material_id)
		statuses.append({"item_id": material_id, "status": "选错"})
		remaining_selected[material_id] = remaining_extra - 1
	return {
		"matched_count": matched_count,
		"missing_material_ids": missing,
		"extra_material_ids": extra,
		"material_statuses": statuses
	}


static func _material_category(material_id: String, ingredients: Dictionary, recipes: Dictionary) -> String:
	if ingredients.has(material_id):
		return String(ingredients[material_id].get("type", "食材"))
	if recipes.has(material_id):
		return "已制作成品"
	return "食材"


static func _variant_array_size(value: Variant) -> int:
	return (value as Array).size() if value is Array else 0


static func _array_lookup(values: Array[String]) -> Dictionary:
	var lookup := {}
	for value in values:
		lookup[value] = true
	return lookup


static func _missing_inventory(state, material_ids: Array[String], amount_per_material: int, ingredients: Dictionary, recipes: Dictionary) -> Array[String]:
	var missing: Array[String] = []
	for material_id in material_ids:
		var required := amount_per_material
		if ingredients.has(material_id):
			if not state.has_ingredient(material_id, required):
				missing.append(material_id)
		elif recipes.has(material_id):
			if not state.has_product(material_id, required):
				missing.append(material_id)
		else:
			missing.append(material_id)
	return missing


static func _consume_materials(state, material_ids: Array[String], amount_per_material: int, ingredients: Dictionary, recipes: Dictionary) -> void:
	for material_id in material_ids:
		if ingredients.has(material_id):
			state.remove_ingredient(material_id, amount_per_material)
		elif recipes.has(material_id):
			state.remove_product(material_id, amount_per_material)


static func _names_for_ids(material_ids: Array[String], ingredients: Dictionary, recipes: Dictionary) -> String:
	var names: Array[String] = []
	for material_id in material_ids:
		names.append(_material_name(material_id, ingredients, recipes))
	return "、".join(names)


static func _material_name(material_id: String, ingredients: Dictionary, recipes: Dictionary) -> String:
	if ingredients.has(material_id):
		return String(ingredients[material_id].get("name", material_id))
	if recipes.has(material_id):
		return String(recipes[material_id].get("name", material_id))
	return material_id


static func _state_level(state) -> int:
	return maxi(0, int(state.shop_level))


static func _research_tool_available(state, device_id: String, catalog) -> bool:
	var devices: Dictionary = catalog.get_devices()
	var device: Dictionary = devices.get(device_id, {})
	if device.is_empty():
		return false
	if state != null and state.has_method("is_device_unlocked"):
		return state.is_device_unlocked(device_id)

	return int(device.get("unlock_level", 1)) <= _state_level(state)


static func _research_reputation_reward(recipe: Dictionary) -> int:
	return clampi(1 + int(recipe.get("unlock_level", 1)), 2, 5)


static func _research_key(device_id: String, selected: Array[String]) -> String:
	var sorted: Array[String] = selected.duplicate()
	sorted.sort()
	return "%s:%s" % [device_id, ",".join(sorted)]


static func _fail_research(
	state,
	hint_key: String,
	message: String,
	selected: Array[String] = [],
	ingredients: Dictionary = {},
	recipes: Dictionary = {},
	consume_selected: bool = false
) -> Dictionary:
	if consume_selected:
		_consume_materials(state, selected, 1, ingredients, recipes)
	_record_research_failure(state, hint_key, message)
	return _fail(message)


static func _fail_research_with_hint(
	state,
	hint_key: String,
	message: String,
	device_id: String,
	selected: Array[String],
	ingredients: Dictionary,
	recipes: Dictionary,
	devices: Dictionary,
	consume_selected: bool = false
) -> Dictionary:
	var hint := _research_hint_for_attempt(state, device_id, selected, ingredients, recipes, devices, 0)
	var final_message := message
	if not hint.is_empty():
		var target_recipe_id := String(hint.get("target_recipe_id", ""))
		var increment := 1
		if state.has_method("get_device_growth"):
			var device_growth: Dictionary = state.get_device_growth(device_id)
			increment = DeviceGrowthService.research_hint_increment(int(device_growth.get("level", 1)))
		var level := _upgrade_research_hint(state, target_recipe_id, increment)
		hint = _research_hint_for_target(
			state,
			target_recipe_id,
			device_id,
			selected,
			ingredients,
			recipes,
			devices,
			level
		)
		final_message = _research_hint_message(hint, ingredients, recipes, devices, message)
	if consume_selected:
		_consume_materials(state, selected, 1, ingredients, recipes)
	_record_research_failure(state, hint_key, final_message)
	var result := _fail(final_message)
	if not hint.is_empty():
		result["hint"] = hint
	return result


static func _upgrade_research_hint(state, target_recipe_id: String, increment: int = 1) -> int:
	var previous := int(state.research_hint_progress.get(target_recipe_id, 0))
	var next_level := clampi(previous + maxi(1, increment), 1, 3)
	state.research_hint_progress[target_recipe_id] = next_level
	state.latest_research_hint_recipe_id = target_recipe_id
	return next_level


static func _research_hint_message(
	hint: Dictionary,
	ingredients: Dictionary,
	recipes: Dictionary,
	devices: Dictionary,
	base_message: String
) -> String:
	var level := int(hint.get("level", 0))
	if level <= 1:
		var direction_kind := "设备" if base_message.find("设备") != -1 else "材料"
		return "研发失败：%s方向接近，已记录第 1 级线索。" % direction_kind
	if level == 2:
		var correct_device_id := String(hint.get("correct_device_id", ""))
		var device: Dictionary = devices.get(correct_device_id, {})
		var categories: Array = hint.get("missing_categories", [])
		var material_summary := "材料已齐" if categories.is_empty() else "缺少类别：%s" % "、".join(categories)
		return "研发失败：可能接近%s，正确设备为%s，%s。研发线索提升至 2 级。" % [
			String(hint.get("recipe_name", "未知配方")),
			String(device.get("name", correct_device_id)),
			material_summary
		]
	var missing: Array[String] = _string_array(hint.get("missing_material_ids", []))
	var extra: Array[String] = _string_array(hint.get("extra_material_ids", []))
	var missing_text := _names_for_ids(missing, ingredients, recipes) if not missing.is_empty() else "无"
	var extra_text := _names_for_ids(extra, ingredients, recipes) if not extra.is_empty() else "无"
	return "完整线索已记录：%s；缺少%s；选错%s。" % [
		String(hint.get("recipe_name", "未知配方")),
		missing_text,
		extra_text
	]


static func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if not value is Array:
		return result
	for item_value: Variant in value as Array:
		result.append(String(item_value))
	return result


static func _record_research_failure(state, hint_key: String, message: String) -> void:
	if state == null:
		return

	if state.discovered_hints is Dictionary:
		state.discovered_hints[hint_key] = message
	_add_log(state, "recipe_research_failed:%s:%s" % [hint_key, message])


static func _add_log(state, message: String) -> void:
	if state != null and state.has_method("add_log"):
		state.add_log(message)


static func _fail(message: String) -> Dictionary:
	return {
		"ok": false,
		"message": message
	}
