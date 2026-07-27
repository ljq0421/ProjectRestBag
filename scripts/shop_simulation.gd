class_name ShopSimulation
extends RefCounted

const Catalog = preload("res://scripts/catalog.gd")
const RecipeGrowthService = preload("res://scripts/recipe_growth_service.gd")
const ShowcaseRegionService = preload("res://scripts/showcase_region_service.gd")

const GRID_ROWS := 12
const GRID_COLS := 14

# ========== 新增：橱窗加成核心计算方法 ==========
## 预计算所有上架产品的价格、售速总倍率
static func _calculate_all_product_bonuses(state, recipes: Dictionary, rules: Dictionary) -> Dictionary:
	var bonuses := {}
	var product_cells_map := {}

	# 1. 收集所有上架产品的格子信息
	for recipe_id in _display_recipe_ids(state):
		if not recipes.has(recipe_id):
			continue
		var cells: Array = []
		if _has_display_items(state):
			var item_data: Dictionary = _display_items(state).get(recipe_id, {})
			cells = item_data.get("cells", [])
		if cells.is_empty():
			# 兼容旧逻辑：无摆放数据的产品默认无加成
			bonuses[recipe_id] = {
				"price_multiplier": 1.0,
				"speed_multiplier": 1.0,
				"breakdown": {"base": 1.0}
			}
			continue
		product_cells_map[recipe_id] = cells
		# 初始化倍率
		bonuses[recipe_id] = {
			"price_multiplier": 1.0,
			"speed_multiplier": 1.0,
			"breakdown": {}
		}

	if product_cells_map.is_empty():
		return bonuses

	# 2. 计算区域固定加成
	var zone_rules: Dictionary = rules.get("zone_bonuses", {})
	var unlocked_cells: Array = ShowcaseRegionService.cells_for_bounds(ShowcaseRegionService.default_bounds())
	if state != null and state.has_method("get_showcase_unlocked_cells"):
		unlocked_cells = state.get_showcase_unlocked_cells()
	for recipe_id in product_cells_map.keys():
		var cells = product_cells_map[recipe_id]
		var zone_bonus = _calc_zone_bonus(cells, zone_rules, unlocked_cells)
		bonuses[recipe_id].price_multiplier *= 1 + zone_bonus.price_pct / 100.0
		bonuses[recipe_id].speed_multiplier *= 1 + zone_bonus.speed_pct / 100.0
		bonuses[recipe_id].breakdown["zone"] = zone_bonus

	# 3. 计算相邻标签双向加成
	var tag_rules: Dictionary = rules.get("base_tag_bonuses", {})
	var adj_bonuses = _calc_adjacency_tag_bonuses(product_cells_map, recipes, tag_rules)
	for recipe_id in adj_bonuses.keys():
		if not bonuses.has(recipe_id):
			continue
		var bonus = adj_bonuses[recipe_id]
		bonuses[recipe_id].price_multiplier *= 1 + bonus.price_pct / 100.0
		bonuses[recipe_id].speed_multiplier *= 1 + bonus.speed_pct / 100.0
		bonuses[recipe_id].breakdown["adjacency_tag"] = bonus

	# 4. 计算套装组合加成
	var set_rules: Dictionary = rules.get("set_bonuses", {})
	var set_bonuses = _calc_set_bonuses(product_cells_map, recipes, set_rules)
	for recipe_id in set_bonuses.keys():
		if not bonuses.has(recipe_id):
			continue
		var bonus = set_bonuses[recipe_id]
		bonuses[recipe_id].price_multiplier *= 1 + bonus.price_pct / 100.0
		bonuses[recipe_id].speed_multiplier *= 1 + bonus.speed_pct / 100.0
		bonuses[recipe_id].breakdown["set"] = bonus

	# 5. 计算冲突减损
	var conflict_rules: Dictionary = rules.get("conflict_penalties", {})
	var penalties = _calc_conflict_penalties(product_cells_map, recipes, conflict_rules)
	for recipe_id in penalties.keys():
		if not bonuses.has(recipe_id):
			continue
		var penalty = penalties[recipe_id]
		bonuses[recipe_id].price_multiplier *= 1 + penalty.price_pct / 100.0
		bonuses[recipe_id].speed_multiplier *= 1 + penalty.speed_pct / 100.0
		bonuses[recipe_id].breakdown["conflict"] = penalty

	# 6. 黄金C位的相邻加成额外倍率（独立乘区）
	for recipe_id in bonuses.keys():
		var cells = product_cells_map.get(recipe_id, [])
		if _is_in_golden_zone(cells, zone_rules, unlocked_cells):
			var adj_multiplier = rules.get("zone_bonuses", {}).get("zone_002", {}).get("adjacency_multiplier", 1.0)
			# 仅对相邻/套装/冲突部分的加成生效
			var base_price = 1.0 + (bonuses[recipe_id].breakdown.get("zone", {}).get("price_pct", 0) / 100.0)
			var adj_price = (bonuses[recipe_id].price_multiplier / base_price - 1) * adj_multiplier
			bonuses[recipe_id].price_multiplier = base_price + adj_price

			var base_speed = 1.0 + (bonuses[recipe_id].breakdown.get("zone", {}).get("speed_pct", 0) / 100.0)
			var adj_speed = (bonuses[recipe_id].speed_multiplier / base_speed - 1) * adj_multiplier
			bonuses[recipe_id].speed_multiplier = base_speed + adj_speed

	var catalog := Catalog.new()
	var display_config := catalog.get_recipe_display_config()
	for recipe_id in bonuses.keys():
		if not state.has_method("get_recipe_growth"):
			continue
		var recipe: Dictionary = recipes.get(recipe_id, {})
		if recipe.is_empty():
			continue
		var growth: Dictionary = state.get_recipe_growth(String(recipe_id))
		var growth_bonus: Dictionary = RecipeGrowthService.growth_bonus(String(recipe_id), growth, recipe, display_config)
		if float(growth_bonus.get("price_pct", 0.0)) == 0.0 and float(growth_bonus.get("speed_pct", 0.0)) == 0.0:
			continue
		bonuses[recipe_id].price_multiplier *= float(growth_bonus.get("price_multiplier", 1.0))
		bonuses[recipe_id].speed_multiplier *= float(growth_bonus.get("speed_multiplier", 1.0))
		bonuses[recipe_id].breakdown["growth"] = growth_bonus

	return bonuses


static func _empty_bonus_part() -> Dictionary:
	return {"price_pct": 0.0, "speed_pct": 0.0, "reasons": []}


static func _append_bonus_reason(target: Dictionary, reason: String) -> void:
	var clean_reason := reason.strip_edges()
	if clean_reason.is_empty():
		return
	var reasons: Array = target.get("reasons", [])
	if not reasons.has(clean_reason):
		reasons.append(clean_reason)
	target["reasons"] = reasons


static func _append_related_recipe(target: Dictionary, recipe_id: String) -> void:
	if recipe_id.is_empty():
		return
	var ids: Array = target.get("related_recipe_ids", [])
	if not ids.has(recipe_id):
		ids.append(recipe_id)
	target["related_recipe_ids"] = ids


static func _append_set_group(target: Dictionary, set_id: String, set_name: String, recipe_ids: Array) -> void:
	var groups: Array = target.get("groups", [])
	for group_value in groups:
		if group_value is Dictionary and String((group_value as Dictionary).get("id", "")) == set_id:
			return
	groups.append({
		"id": set_id,
		"label": set_name,
		"recipe_ids": recipe_ids.duplicate()
	})
	target["groups"] = groups


static func _recipe_display_name(recipes: Dictionary, recipe_id: String) -> String:
	var recipe: Dictionary = recipes.get(recipe_id, {})
	return String(recipe.get("name", recipe_id))


static func _join_values(values: Array, separator: String = "、") -> String:
	var parts: Array[String] = []
	for value in values:
		parts.append(String(value))
	return separator.join(parts)


static func _rule_description(rule: Dictionary) -> String:
	var description := String(rule.get("description", ""))
	if not description.is_empty():
		return description
	return String(rule.get("trigger_condition", ""))


## 计算单个产品的区域加成
static func _calc_zone_bonus(cells: Array, zone_rules: Dictionary, unlocked_layout: Variant = {}) -> Dictionary:
	var result := _empty_bonus_part()
	result["region_id"] = ""
	result["zone_id"] = ""
	result["zone_name"] = ""
	if cells.is_empty():
		return result
	var unlocked_cells := _unlocked_cells_from_layout(unlocked_layout)
	var region_id := ShowcaseRegionService.zone_for_cells_in_cells(cells, unlocked_cells)
	if region_id.is_empty():
		_append_bonus_reason(result, "跨区：商品没有完整位于同一功能区域，因此不获得固定区域效果")
		return result
	result["region_id"] = region_id
	if region_id == "middle":
		result["zone_name"] = "普通中间区"
		return result

	var fallback_region_ids := {"zone_001": "front", "zone_002": "golden", "zone_003": "back"}
	for zone_id in zone_rules.keys():
		var zone: Dictionary = zone_rules[zone_id]
		var configured_region_id := String(zone.get("region_id", fallback_region_ids.get(String(zone_id), "")))
		if configured_region_id != region_id:
			continue
		result.price_pct += zone.get("price_bonus_pct", 0)
		result.speed_pct += zone.get("speed_bonus_pct", 0)
		result["zone_id"] = String(zone_id)
		result["zone_name"] = String(zone.get("zone_name", zone_id))
		var layout := ShowcaseRegionService.resolve_regions_for_cells(unlocked_cells, GRID_ROWS, GRID_COLS)
		var range_text := _dynamic_region_range_text(region_id, layout)
		_append_bonus_reason(result, "受%s影响：商品完整位于%s；%s" % [result.zone_name, range_text, _rule_description(zone)])
		break

	return result


## 判断产品是否完全在黄金C位区
static func _is_in_golden_zone(cells: Array, _zone_rules: Dictionary, unlocked_layout: Variant = {}) -> bool:
	return ShowcaseRegionService.zone_for_cells_in_cells(cells, _unlocked_cells_from_layout(unlocked_layout)) == "golden"


static func _unlocked_cells_from_layout(unlocked_layout: Variant) -> Array[Vector2i]:
	if unlocked_layout is Array:
		return ShowcaseRegionService.normalize_cells(unlocked_layout, GRID_ROWS, GRID_COLS)
	if unlocked_layout is Dictionary and not (unlocked_layout as Dictionary).is_empty():
		return ShowcaseRegionService.cells_for_bounds(unlocked_layout, GRID_ROWS, GRID_COLS)
	return ShowcaseRegionService.cells_for_bounds(ShowcaseRegionService.default_bounds(), GRID_ROWS, GRID_COLS)


static func _dynamic_region_range_text(region_id: String, layout: Dictionary) -> String:
	match region_id:
		"front":
			return "%s（已解锁区域前30%%）" % _axis_values_text(layout.get("front_rows", []), "行")
		"back":
			return "%s（已解锁区域后30%%）" % _axis_values_text(layout.get("back_rows", []), "行")
		"golden":
			return "%s与%s的交集" % [
				_axis_values_text(layout.get("golden_rows", []), "行"),
				_axis_values_text(layout.get("golden_columns", []), "列")
			]
	return "普通中间区"


static func _axis_values_text(values_value: Variant, suffix: String) -> String:
	var values: Array = values_value if values_value is Array else []
	if values.is_empty():
		return "无"
	if values.size() == 1:
		return "第%d%s" % [int(values[0]), suffix]
	return "第%d-%d%s" % [int(values.front()), int(values.back()), suffix]


## 计算相邻标签加成（四方向判定）
static func _calc_adjacency_tag_bonuses(product_cells_map: Dictionary, recipes: Dictionary, tag_rules: Dictionary) -> Dictionary:
	var result := {}
	# 初始化每个产品的加成为0
	for recipe_id in product_cells_map.keys():
		result[recipe_id] = _empty_bonus_part()
	var ordered_rule_ids: Array = tag_rules.keys()
	ordered_rule_ids.sort_custom(func(left, right):
		var left_priority := int((tag_rules.get(left, {}) as Dictionary).get("priority", 0))
		var right_priority := int((tag_rules.get(right, {}) as Dictionary).get("priority", 0))
		if left_priority == right_priority:
			return String(left) < String(right)
		return left_priority > right_priority
	)

	# 构建格子->产品ID的映射
	var cell_to_recipe := {}
	for recipe_id in product_cells_map.keys():
		for cell in product_cells_map[recipe_id]:
			var key = str(cell.x) + "," + str(cell.y)
			cell_to_recipe[key] = recipe_id

	# 遍历所有产品，检查其四邻格的产品
	var checked_pairs: Array = []  # 避免重复计算双向加成
	for recipe_id_a in product_cells_map.keys():
		var neighbors: Dictionary = {}  # 相邻的产品ID->是否相邻

		for cell in product_cells_map[recipe_id_a]:
			# 检查上下左右四个方向
			var directions = [
				Vector2i(cell.x + 1, cell.y),
				Vector2i(cell.x - 1, cell.y),
				Vector2i(cell.x, cell.y + 1),
				Vector2i(cell.x, cell.y - 1)
			]
			for dir_cell in directions:
				var key = str(dir_cell.x) + "," + str(dir_cell.y)
				if cell_to_recipe.has(key):
					var neighbor_id = cell_to_recipe[key]
					if neighbor_id != recipe_id_a:
						neighbors[neighbor_id] = true

		# 对每个相邻产品，匹配标签规则
		for recipe_id_b in neighbors.keys():
			var pair_key := [recipe_id_a, recipe_id_b]
			pair_key.sort()
			if checked_pairs.has(pair_key):
				continue
			checked_pairs.append(pair_key)

			var tags_a: Array = recipes.get(recipe_id_a, {}).get("tags", [])
			var tags_b: Array = recipes.get(recipe_id_b, {}).get("tags", [])

			# 匹配所有标签规则
			for rule_id in ordered_rule_ids:
				var rule = tag_rules[rule_id]
				var tag_a = rule.get("trigger_tag_a", "")
				var tag_b = rule.get("trigger_tag_b", "")

				var match_ab = tags_a.has(tag_a) and tags_b.has(tag_b)
				var match_ba = tags_a.has(tag_b) and tags_b.has(tag_a)

				if match_ab or match_ba:
					var price_pct = rule.get("price_bonus_pct", 0)
					var speed_pct = rule.get("speed_bonus_pct", 0)
					# 双向生效
					result[recipe_id_a].price_pct += price_pct
					result[recipe_id_a].speed_pct += speed_pct
					result[recipe_id_b].price_pct += price_pct
					result[recipe_id_b].speed_pct += speed_pct
					var rule_name := String(rule.get("rule_name", rule_id))
					var reason := "受%s影响：%s 与 %s 四方向相邻，触发「%s+%s」标签组合；%s" % [
						rule_name,
						_recipe_display_name(recipes, recipe_id_a),
						_recipe_display_name(recipes, recipe_id_b),
						String(tag_a),
						String(tag_b),
						_rule_description(rule)
					]
					_append_bonus_reason(result[recipe_id_a], reason)
					_append_bonus_reason(result[recipe_id_b], reason)
					_append_related_recipe(result[recipe_id_a], String(recipe_id_b))
					_append_related_recipe(result[recipe_id_b], String(recipe_id_a))

	return result


## 计算套装加成（连通相邻判定）
static func _calc_set_bonuses(product_cells_map: Dictionary, recipes: Dictionary, set_rules: Dictionary) -> Dictionary:
	var result := {}
	for recipe_id in product_cells_map.keys():
		result[recipe_id] = _empty_bonus_part()

	# 构建邻接图
	var adj_graph := {}
	for recipe_id in product_cells_map.keys():
		adj_graph[recipe_id] = []

	# 复用相邻判定逻辑
	var cell_to_recipe := {}
	for recipe_id in product_cells_map.keys():
		for cell in product_cells_map[recipe_id]:
			var key = str(cell.x) + "," + str(cell.y)
			cell_to_recipe[key] = recipe_id

	for recipe_id_a in product_cells_map.keys():
		for cell in product_cells_map[recipe_id_a]:
			var directions = [
				Vector2i(cell.x + 1, cell.y),
				Vector2i(cell.x - 1, cell.y),
				Vector2i(cell.x, cell.y + 1),
				Vector2i(cell.x, cell.y - 1)
			]
			for dir_cell in directions:
				var key = str(dir_cell.x) + "," + str(dir_cell.y)
				if cell_to_recipe.has(key):
					var neighbor_id = cell_to_recipe[key]
					if neighbor_id != recipe_id_a and not adj_graph[recipe_id_a].has(neighbor_id):
						adj_graph[recipe_id_a].append(neighbor_id)

	# 遍历每条套装规则
	for set_id in set_rules.keys():
		var set_rule = set_rules[set_id]
		var required_tags: Array = set_rule.get("required_tags", [])
		var min_count: int = set_rule.get("min_item_count", 3)

		# 找出所有符合标签的产品
		var candidates: Array = []
		for recipe_id in product_cells_map.keys():
			var recipe_tags: Array = recipes.get(recipe_id, {}).get("tags", [])
			var has_any_tag := false
			for tag in required_tags:
				if recipe_tags.has(tag):
					has_any_tag = true
					break
			if has_any_tag:
				candidates.append(recipe_id)

		# 找连通分量
		var visited: Array = []
		for start_id in candidates:
			if visited.has(start_id):
				continue
			# BFS找连通块
			var component: Array = []
			var queue: Array = [start_id]
			visited.append(start_id)

			while not queue.is_empty():
				var current = queue.pop_front()
				component.append(current)
				for neighbor in adj_graph.get(current, []):
					if candidates.has(neighbor) and not visited.has(neighbor):
						visited.append(neighbor)
						queue.append(neighbor)

			var minimal_members := _minimal_set_members(
				_sorted_recipe_ids_by_anchor(component, product_cells_map),
				adj_graph,
				recipes,
				required_tags,
				min_count
			)
			if not minimal_members.is_empty():
				var price_pct = set_rule.get("price_bonus_pct", 0)
				var speed_pct = set_rule.get("speed_bonus_pct", 0)
				var set_name := String(set_rule.get("set_name", set_id))
				var set_reason := "受%s影响：%d件相邻连通商品满足「%s」标签要求；%s" % [
					set_name,
					minimal_members.size(),
					_join_values(required_tags),
					_rule_description(set_rule)
				]
				for recipe_id in minimal_members:
					result[recipe_id].price_pct += price_pct
					result[recipe_id].speed_pct += speed_pct
					_append_bonus_reason(result[recipe_id], set_reason)
					_append_set_group(result[recipe_id], String(set_id), set_name, minimal_members)
					for member_id in minimal_members:
						if String(member_id) != String(recipe_id):
							_append_related_recipe(result[recipe_id], String(member_id))

	return result


static func _minimal_set_members(
		ordered_component: Array,
		adj_graph: Dictionary,
		recipes: Dictionary,
		required_tags: Array,
		min_count: int
) -> Array:
	if ordered_component.size() < min_count or not _members_cover_tags(ordered_component, recipes, required_tags):
		return []
	for target_size in range(maxi(1, min_count), ordered_component.size() + 1):
		var found: Array = []
		_find_set_combination(
			ordered_component,
			adj_graph,
			recipes,
			required_tags,
			target_size,
			0,
			[],
			found
		)
		if not found.is_empty():
			return found
	return []


static func _find_set_combination(
		ordered_component: Array,
		adj_graph: Dictionary,
		recipes: Dictionary,
		required_tags: Array,
		target_size: int,
		start_index: int,
		current: Array,
		found: Array
) -> void:
	if not found.is_empty():
		return
	if current.size() == target_size:
		if _members_cover_tags(current, recipes, required_tags) and _members_are_connected(current, adj_graph):
			found.append_array(current)
		return
	var remaining_needed := target_size - current.size()
	var last_start := ordered_component.size() - remaining_needed
	for index in range(start_index, last_start + 1):
		current.append(ordered_component[index])
		_find_set_combination(ordered_component, adj_graph, recipes, required_tags, target_size, index + 1, current, found)
		current.pop_back()
		if not found.is_empty():
			return


static func _members_cover_tags(members: Array, recipes: Dictionary, required_tags: Array) -> bool:
	for required_tag in required_tags:
		var covered := false
		for recipe_id in members:
			var tags: Array = recipes.get(recipe_id, {}).get("tags", [])
			if tags.has(required_tag):
				covered = true
				break
		if not covered:
			return false
	return true


static func _members_are_connected(members: Array, adj_graph: Dictionary) -> bool:
	if members.is_empty():
		return false
	var visited: Dictionary = {members[0]: true}
	var queue: Array = [members[0]]
	while not queue.is_empty():
		var current = queue.pop_front()
		for neighbor in adj_graph.get(current, []):
			if members.has(neighbor) and not visited.has(neighbor):
				visited[neighbor] = true
				queue.append(neighbor)
	return visited.size() == members.size()


static func _sorted_recipe_ids_by_anchor(recipe_ids: Array, product_cells_map: Dictionary) -> Array:
	var ordered := recipe_ids.duplicate()
	ordered.sort_custom(func(left, right):
		var left_anchor := _recipe_anchor_cell(product_cells_map.get(left, []))
		var right_anchor := _recipe_anchor_cell(product_cells_map.get(right, []))
		if left_anchor.x != right_anchor.x:
			return left_anchor.x < right_anchor.x
		if left_anchor.y != right_anchor.y:
			return left_anchor.y < right_anchor.y
		return String(left) < String(right)
	)
	return ordered


static func _recipe_anchor_cell(cells_value: Variant) -> Vector2i:
	var cells: Array = cells_value if cells_value is Array else []
	var anchor := Vector2i(999999, 999999)
	for cell_value in cells:
		if not cell_value is Vector2i:
			continue
		var cell := cell_value as Vector2i
		if cell.x < anchor.x or (cell.x == anchor.x and cell.y < anchor.y):
			anchor = cell
	return anchor


## 计算冲突减损
static func _calc_conflict_penalties(product_cells_map: Dictionary, recipes: Dictionary, conflict_rules: Dictionary) -> Dictionary:
	var result := {}
	for recipe_id in product_cells_map.keys():
		result[recipe_id] = _empty_bonus_part()

	# 1. 同类扎堆惩罚
	var cell_to_recipe := {}
	for recipe_id in product_cells_map.keys():
		for cell in product_cells_map[recipe_id]:
			var key = str(cell.x) + "," + str(cell.y)
			cell_to_recipe[key] = recipe_id

	# 按相同标签的四方向连通分量分别计算，分量前两件安全。
	var tag_groups := {}
	for recipe_id in product_cells_map.keys():
		var tags: Array = recipes.get(recipe_id, {}).get("tags", [])
		for tag in tags:
			if not tag_groups.has(tag):
				tag_groups[tag] = []
			tag_groups[tag].append(recipe_id)

	for tag in tag_groups.keys():
		var group: Array = _sorted_recipe_ids_by_anchor(tag_groups[tag], product_cells_map)
		var visited: Dictionary = {}
		for start_id in group:
			if visited.has(start_id):
				continue
			var component: Array = []
			var queue: Array = [start_id]
			visited[start_id] = true
			while not queue.is_empty():
				var current_id = queue.pop_front()
				component.append(current_id)
				for neighbor_id in _get_product_neighbors(String(current_id), product_cells_map):
					if group.has(neighbor_id) and not visited.has(neighbor_id):
						visited[neighbor_id] = true
						queue.append(neighbor_id)
			component = _sorted_recipe_ids_by_anchor(component, product_cells_map)
			if component.size() < 3:
				continue
			var penalty_rule: Dictionary = conflict_rules.get("penalty_001", {})
			var price_penalty = penalty_rule.get("price_penalty_pct", 0)
			var speed_penalty = penalty_rule.get("speed_penalty_pct", 0)
			var penalty_name := String(penalty_rule.get("penalty_name", "同类扎堆惩罚"))
			var penalty_description := _rule_description(penalty_rule)
			for i in range(2, component.size()):
				var recipe_id = component[i]
				result[recipe_id].price_pct += price_penalty
				result[recipe_id].speed_pct += speed_penalty
				_append_bonus_reason(result[recipe_id], "受%s影响：同标签「%s」连通商品达到%d件，超出第2件后降低收益；%s" % [
					penalty_name,
					String(tag),
					component.size(),
					penalty_description
				])
				for related_id in component:
					if String(related_id) != String(recipe_id):
						_append_related_recipe(result[recipe_id], String(related_id))

	# 2. 口感冲突惩罚（清凉+浓郁）
	var penalty_002 = conflict_rules.get("penalty_002", {})
	var conflict_tags = penalty_002.get("conflict_tags", ["清凉", "浓郁"])
	# 遍历所有相邻对
	var adj_pairs = _get_all_adjacent_pairs(product_cells_map)
	for pair in adj_pairs:
		var id_a = pair[0]
		var id_b = pair[1]
		var tags_a: Array = recipes.get(id_a, {}).get("tags", [])
		var tags_b: Array = recipes.get(id_b, {}).get("tags", [])

		var conflict := (tags_a.has(conflict_tags[0]) and tags_b.has(conflict_tags[1])) \
			or (tags_a.has(conflict_tags[1]) and tags_b.has(conflict_tags[0]))
		if conflict:
			result[id_a].price_pct += penalty_002.get("price_penalty_pct", 0)
			result[id_b].price_pct += penalty_002.get("price_penalty_pct", 0)
			var penalty_name := String(penalty_002.get("penalty_name", "口感冲突惩罚"))
			var conflict_reason := "受%s影响：%s 与 %s 四方向相邻，触发「%s+%s」冲突；%s" % [
				penalty_name,
				_recipe_display_name(recipes, id_a),
				_recipe_display_name(recipes, id_b),
				String(conflict_tags[0]),
				String(conflict_tags[1]),
				_rule_description(penalty_002)
			]
			_append_bonus_reason(result[id_a], conflict_reason)
			_append_bonus_reason(result[id_b], conflict_reason)
			_append_related_recipe(result[id_a], String(id_b))
			_append_related_recipe(result[id_b], String(id_a))

	# 3. 饱腹压制惩罚（咸香主餐周围≥3甜品）
	var penalty_003 = conflict_rules.get("penalty_003", {})
	for recipe_id in product_cells_map.keys():
		var tags: Array = recipes.get(recipe_id, {}).get("tags", [])
		if tags.has("咸香") or tags.has("饱腹"):
			# 统计周围甜口甜品数量
			var sweet_count := 0
			var neighbors = _get_product_neighbors(recipe_id, product_cells_map)
			for neighbor_id in neighbors:
				var neighbor_tags: Array = recipes.get(neighbor_id, {}).get("tags", [])
				if neighbor_tags.has("甜"):
					sweet_count += 1
			if sweet_count >= 3:
				var penalty_name := String(penalty_003.get("penalty_name", "饱腹压制惩罚"))
				var penalty_description := _rule_description(penalty_003)
				for neighbor_id in neighbors:
					var neighbor_tags: Array = recipes.get(neighbor_id, {}).get("tags", [])
					if neighbor_tags.has("甜"):
						result[neighbor_id].speed_pct += penalty_003.get("speed_penalty_pct", 0)
						_append_bonus_reason(result[neighbor_id], "受%s影响：周围有%s等咸香饱腹主餐，且相邻甜口商品达到%d件；%s" % [
							penalty_name,
							_recipe_display_name(recipes, recipe_id),
							sweet_count,
							penalty_description
						])
						_append_related_recipe(result[neighbor_id], String(recipe_id))

	return result


## 辅助：获取所有相邻产品对
static func _get_all_adjacent_pairs(product_cells_map: Dictionary) -> Array:
	var pairs: Array = []
	var cell_to_recipe := {}
	for recipe_id in product_cells_map.keys():
		for cell in product_cells_map[recipe_id]:
			var key = str(cell.x) + "," + str(cell.y)
			cell_to_recipe[key] = recipe_id

	var checked: Array = []
	for recipe_id_a in product_cells_map.keys():
		for cell in product_cells_map[recipe_id_a]:
			var directions = [
				Vector2i(cell.x + 1, cell.y),
				Vector2i(cell.x - 1, cell.y),
				Vector2i(cell.x, cell.y + 1),
				Vector2i(cell.x, cell.y - 1)
			]
			for dir_cell in directions:
				var key = str(dir_cell.x) + "," + str(dir_cell.y)
				if cell_to_recipe.has(key):
					var recipe_id_b = cell_to_recipe[key]
					if recipe_id_a != recipe_id_b:
						var pair := [recipe_id_a, recipe_id_b]
						pair.sort()
						if not checked.has(pair):
							checked.append(pair)
							pairs.append(pair)
	return pairs


## 辅助：获取单个产品的所有相邻产品
static func _get_product_neighbors(recipe_id: String, product_cells_map: Dictionary) -> Array:
	var neighbors: Array = []
	var cell_to_recipe := {}
	for rid in product_cells_map.keys():
		for cell in product_cells_map[rid]:
			var key = str(cell.x) + "," + str(cell.y)
			cell_to_recipe[key] = rid

	for cell in product_cells_map.get(recipe_id, []):
		var directions = [
			Vector2i(cell.x + 1, cell.y),
			Vector2i(cell.x - 1, cell.y),
			Vector2i(cell.x, cell.y + 1),
			Vector2i(cell.x, cell.y - 1)
		]
		for dir_cell in directions:
			var key = str(dir_cell.x) + "," + str(dir_cell.y)
			if cell_to_recipe.has(key):
				var neighbor_id = cell_to_recipe[key]
				if neighbor_id != recipe_id and not neighbors.has(neighbor_id):
					neighbors.append(neighbor_id)
	return neighbors


# ========== 修改原有选品方法，加入加成 ==========

static func _best_available_choice(state, customer: Dictionary, recipes: Dictionary, product_bonuses: Dictionary = {}) -> Dictionary:
	var best_choice := {}
	var best_score := -999999

	for recipe_id in _display_recipe_ids(state):
		if not recipes.has(recipe_id):
			continue
		# 库存判定：改为读取橱窗在售库存
		var stock: int = 0
		if _has_display_items(state):
			stock = state.get_display_item_stock(String(recipe_id))
		else:
			stock = state.get_product_count(String(recipe_id))
		if stock <= 0:
			continue

		var recipe: Dictionary = recipes[recipe_id]
		var tag_matches: int = _tag_match_count(customer, recipe)
		var base_score: int = _score_product(customer, recipe, tag_matches)

		# 应用售速加成到得分
		var bonus = product_bonuses.get(recipe_id, {})
		var speed_mult: float = bonus.get("speed_multiplier", 1.0)
		var final_score: int = int(round(base_score * speed_mult))

		if final_score <= 0:
			continue

		# 计算最终价格
		var base_price: int = int(recipe.get("price", 0))
		var price_mult: float = bonus.get("price_multiplier", 1.0)
		var final_price: int = int(round(base_price * price_mult))

		if best_choice.is_empty() or final_score > best_score or (final_score == best_score and recipe_id < String(best_choice.get("recipe_id", ""))):
			best_score = final_score
			best_choice = {
				"recipe_id": recipe_id,
				"recipe": recipe,
				"score": final_score,
				"tag_matches": tag_matches,
				"final_price": final_price
			}
	return best_choice


# ========== 以下原有方法保持不变 ==========

static func _build_customer_pool(catalog, shop_level: int, rng_seed: int = -1) -> Array:
	var customers: Dictionary = catalog.get_customers()
	var upgrade: Dictionary = catalog.get_upgrade_definition(maxi(1, shop_level))
	var customer_count: int = maxi(0, int(upgrade.get("customer_count", 0)))
	var current_level_customers: Array = []
	var older_customers: Array = []

	for customer_id: Variant in customers.keys():
		var customer_value: Variant = customers[customer_id]
		if not customer_value is Dictionary:
			continue
		var customer: Dictionary = customer_value as Dictionary
		var unlock_level: int = int(customer.get("unlock_level", 1))
		if unlock_level > shop_level:
			continue
		if unlock_level == shop_level:
			current_level_customers.append(customer.duplicate(true))
		else:
			older_customers.append(customer.duplicate(true))

	var pool: Array = []
	var weighted_customers: Array = []

	for customer: Dictionary in current_level_customers:
		weighted_customers.append(customer)
	for customer: Dictionary in current_level_customers:
		weighted_customers.append(customer)
	for customer: Dictionary in older_customers:
		weighted_customers.append(customer)

	if weighted_customers.is_empty():
		return pool

	var rng := RandomNumberGenerator.new()
	if rng_seed >= 0:
		rng.seed = rng_seed
	else:
		rng.randomize()

	for index in range(customer_count):
		var selected_index: int = rng.randi_range(0, weighted_customers.size() - 1)
		var selected: Dictionary = weighted_customers[selected_index]
		pool.append(selected.duplicate(true))

	if shop_level == 1:
		var student: Dictionary = _find_customer(weighted_customers, "student")
		while not student.is_empty() and _customer_count(pool, "student") < 3:
			_replace_random_customer(pool, student, rng)

	if shop_level >= 5 and _customer_count(pool, "blogger") < 1:
		var blogger: Dictionary = _find_customer(weighted_customers, "blogger")
		if not blogger.is_empty():
			_replace_random_customer(pool, blogger, rng)

	return pool


static func _score_product(customer: Dictionary, recipe: Dictionary, tag_matches: int) -> int:
	var preference_tags: Array = customer.get("preference_tags", [])
	var recipe_tags: Array = recipe.get("tags", [])
	var budget: int = maxi(0, int(customer.get("budget", 0)))
	var price: int = maxi(0, int(recipe.get("price", 0)))
	var base_score: int = tag_matches * 10
	var low_price_bonus := 0
	var low_price_threshold := maxi(0, int(customer.get("low_price_threshold", 0)))
	if low_price_threshold > 0 and price <= low_price_threshold:
		low_price_bonus = 8
	var signature_bonus := 0
	if recipe_tags.has("招牌") and preference_tags.has("招牌"):
		signature_bonus = 12
	var price_penalty: int = maxi(0, price - budget)
	return base_score + low_price_bonus + signature_bonus - price_penalty


static func _no_choice_feedback(state, customer: Dictionary, recipes: Dictionary) -> String:
	var customer_name: String = String(customer.get("name", "顾客"))
	var has_displayed_product := false
	var has_stocked_product := false
	var has_out_of_stock_product := false

	var use_display_items = _has_display_items(state)

	for recipe_id in _display_recipe_ids(state):
		if not recipes.has(recipe_id):
			continue
		has_displayed_product = true
		var stock: int = 0
		if use_display_items:
			stock = state.get_display_item_stock(String(recipe_id))
		else:
			stock = state.get_product_count(String(recipe_id))
		if stock > 0:
			has_stocked_product = true
		else:
			has_out_of_stock_product = true

	if has_displayed_product and not has_stocked_product and has_out_of_stock_product:
		return "%s 看中了橱窗商品，但已经缺货。" % customer_name
	if has_stocked_product:
		return "%s 觉得口味或预算不匹配，没有找到合适的甜品。" % customer_name
	return "%s 没有找到合适的橱窗商品。" % customer_name

static func _display_recipe_ids(state) -> Array[String]:
	var recipe_ids: Array[String] = []
	if state == null:
		return recipe_ids

	# 优先读取自由摆放橱窗
	var display_items := _display_items(state)
	if not display_items.is_empty():
		for recipe_id in display_items.keys():
			var recipe_id_str = String(recipe_id)
			if not recipe_id_str.is_empty() and not recipe_ids.has(recipe_id_str):
				recipe_ids.append(recipe_id_str)
		return recipe_ids

	# 向下兼容旧版槽位
	for slot_value: Variant in state.display_slots:
		if slot_value == null:
			continue
		var recipe_id := ""
		if slot_value is Dictionary:
			var slot: Dictionary = slot_value
			recipe_id = String(slot.get("recipe_id", ""))
		else:
			recipe_id = String(slot_value)
		if not recipe_id.is_empty() and not recipe_ids.has(recipe_id):
			recipe_ids.append(recipe_id)
	return recipe_ids

static func _tag_match_count(customer: Dictionary, recipe: Dictionary) -> int:
	var count := 0
	var preference_tags: Array = customer.get("preference_tags", [])
	var recipe_tags: Array = recipe.get("tags", [])
	for tag: Variant in preference_tags:
		if recipe_tags.has(tag):
			count += 1
	return count


static func _reputation_for_sale(customer: Dictionary, recipe: Dictionary, tag_matches: int) -> int:
	var reputation: int = 1 + tag_matches
	var recipe_tags: Array = recipe.get("tags", [])
	if String(customer.get("id", "")) == "blogger" and recipe_tags.has("招牌"):
		reputation += 3
	return reputation


static func _find_customer(customers: Array, customer_id: String) -> Dictionary:
	for customer_value: Variant in customers:
		if not customer_value is Dictionary:
			continue
		var customer: Dictionary = customer_value as Dictionary
		if String(customer.get("id", "")) == customer_id:
			return customer
	return {}


static func _customer_count(customers: Array, customer_id: String) -> int:
	var count := 0
	for customer_value: Variant in customers:
		if not customer_value is Dictionary:
			continue
		var customer: Dictionary = customer_value as Dictionary
		if String(customer.get("id", "")) == customer_id:
			count += 1
	return count


static func _replace_random_customer(pool: Array, customer: Dictionary, rng: RandomNumberGenerator) -> void:
	if pool.is_empty():
		return
	var index: int = rng.randi_range(0, pool.size() - 1)
	pool[index] = customer.duplicate(true)


static func _state_level(state) -> int:
	return maxi(1, int(state.shop_level))


static func _add_log(state, message: String) -> void:
	if state != null and state.has_method("add_log"):
		state.add_log(message)


static func _display_items(state) -> Dictionary:
	if state == null:
		return {}
	var value: Variant = state.get("display_items")
	if value is Dictionary:
		var items: Dictionary = value
		return items
	return {}


static func _has_display_items(state) -> bool:
	if state == null:
		return false
	if not state.has_method("get_display_item_stock") or not state.has_method("remove_display_item_stock"):
		return false
	return not _display_items(state).is_empty()
