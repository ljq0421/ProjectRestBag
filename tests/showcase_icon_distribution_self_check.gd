extends SceneTree

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const GAME_STATE := preload("res://scripts/game_state.gd")
const CORE_FEATURE_UNLOCK_SERVICE := preload("res://scripts/core_feature_unlock_service.gd")
const MANIFEST_PATH := "res://resources/recipe_icons_showcase/showcase_icon_manifest.json"

var failed := false


func _init() -> void:
	var root := MAIN_SCENE.instantiate()
	get_root().add_child(root)
	await root.ready
	if root.get_node_or_null("Root/Body/MainArea/StorefrontPanel/ShowcasePanel/ShowcaseScroll") != null:
		_fail("showcase should display the full grid without a scroll viewport")
	var initial_grid := root.get_node("Root/Body/MainArea/StorefrontPanel/ShowcasePanel/ShowcaseGrid") as GridContainer
	if initial_grid.get_theme_constant("h_separation") != 0 or initial_grid.get_theme_constant("v_separation") != 0:
		_fail("showcase grid should have zero separation so neighboring fragments touch")
	if initial_grid.custom_minimum_size != Vector2(1008, 864):
		_fail("showcase grid should be fixed to 1008x864")
	if initial_grid.size_flags_horizontal != Control.SIZE_SHRINK_BEGIN or initial_grid.size_flags_vertical != Control.SIZE_SHRINK_BEGIN:
		_fail("showcase grid should keep its fixed square size")
	if initial_grid.columns != 14:
		_fail("showcase grid scene should use fourteen columns")
	var selections := _select_shape_examples()
	for category in ["single", "horizontal", "vertical", "square", "irregular"]:
		if not selections.has(category):
			_fail("manifest should contain a distinct %s standard recipe" % category)
	if failed:
		quit(1)
		return

	var state = GAME_STATE.new_game()
	state.level = 99
	state.core_feature_unlocks[CORE_FEATURE_UNLOCK_SERVICE.ARRANGE] = true
	state.set_showcase_unlocked_bounds({"min_row": 1, "max_row": 12, "min_column": 1, "max_column": 14})
	var anchors := {
		"horizontal": Vector2i(5, 5),
		"vertical": Vector2i(5, 8),
		"single": Vector2i(5, 10),
		"square": Vector2i(8, 5),
		"irregular": Vector2i(8, 8),
	}
	var now_unix := int(Time.get_unix_time_from_system())
	for category in anchors.keys():
		var entry: Dictionary = selections[category]
		var recipe_id := String(entry.get("recipe_id", ""))
		if not state.is_recipe_unlocked(recipe_id):
			state.add_recipe(recipe_id)
		state.add_product(recipe_id, 2)
		var cells := _translated_cells(entry.get("cells", []), anchors[category])
		if not state.list_display_item(recipe_id, cells, 1, "standard"):
			_fail("should place %s example %s" % [category, recipe_id])

	root.set("state", state)
	for category in anchors.keys():
		var entry: Dictionary = selections[category]
		var recipe_id := String(entry.get("recipe_id", ""))
		var cells: Array = state.get_display_item_cells(recipe_id)
		var anchor_index := int(root.call("_showcase_anchor_slot_index_for_cells", cells))
		root.call("_sync_showcase_slot_from_display_item", anchor_index, recipe_id)
	root.call("_refresh_storefront_showcase")
	await process_frame

	var grid := root.get_node("Root/Body/MainArea/StorefrontPanel/ShowcasePanel/ShowcaseGrid") as GridContainer
	for category in anchors.keys():
		var entry: Dictionary = selections[category]
		var recipe_id := String(entry.get("recipe_id", ""))
		var expected_cells: Array = state.get_display_item_cells(recipe_id)
		var buttons := _buttons_for_recipe(grid, recipe_id)
		if buttons.size() != expected_cells.size():
			_fail("%s should occupy %d visual cells, got %d" % [recipe_id, expected_cells.size(), buttons.size()])
			continue
		var tooltip := ""
		var visible_badges := 0
		for button in buttons:
			var icon := button.get_node("RecipeIcon") as TextureRect
			if not icon.texture is AtlasTexture:
				_fail("%s occupied cell should use AtlasTexture fragment" % recipe_id)
			else:
				var has_crisp_source := FileAccess.file_exists("res://resources/ui/icons_v1/%s_1.png" % recipe_id)
				var expected_region_size := Vector2(72, 72) if has_crisp_source else Vector2(80, 80)
				if (icon.texture as AtlasTexture).region.size != expected_region_size:
					_fail("%s fragment should use %s regions" % [recipe_id, expected_region_size])
			if not button.text.is_empty():
				_fail("%s occupied cells should not repeat recipe text" % recipe_id)
			var badge := button.get_node("StatusBadge") as Label
			if badge.visible:
				visible_badges += 1
			if tooltip.is_empty():
				tooltip = button.tooltip_text
			elif button.tooltip_text != tooltip:
				_fail("%s occupied cells should share one tooltip" % recipe_id)
		if visible_badges != 1:
			_fail("%s should show exactly one anchor badge, got %d" % [recipe_id, visible_badges])

	var vertical_recipe_id := String((selections["vertical"] as Dictionary).get("recipe_id", ""))
	var vertical_buttons := _buttons_for_recipe(grid, vertical_recipe_id)
	if vertical_buttons.size() == 2:
		var top_icon := vertical_buttons[0].get_node("RecipeIcon") as TextureRect
		var bottom_icon := vertical_buttons[1].get_node("RecipeIcon") as TextureRect
		var top_rect := top_icon.get_global_rect()
		var bottom_rect := bottom_icon.get_global_rect()
		if not is_equal_approx(top_rect.end.y, bottom_rect.position.y):
			_fail("vertical fragment rectangles should touch: grid=%s grid_min=%s top_button=%s top_min=%s bottom_button=%s top=%s bottom=%s" % [grid.get_global_rect(), grid.get_combined_minimum_size(), vertical_buttons[0].get_global_rect(), vertical_buttons[0].get_combined_minimum_size(), vertical_buttons[1].get_global_rect(), top_rect, bottom_rect])

	var horizontal_recipe_id := String((selections["horizontal"] as Dictionary).get("recipe_id", ""))
	var horizontal_buttons := _buttons_for_recipe(grid, horizontal_recipe_id)
	if horizontal_buttons.size() == 2:
		var first_outline := horizontal_buttons[0].get_node("GroupOutline") as Panel
		var second_outline := horizontal_buttons[1].get_node("GroupOutline") as Panel
		var first_style := first_outline.get_theme_stylebox("panel") as StyleBoxFlat
		var second_style := second_outline.get_theme_stylebox("panel") as StyleBoxFlat
		if first_style == null or second_style == null or first_style.border_width_right != 0 or second_style.border_width_left != 0:
			_fail("neighbor fragments should hide their shared internal border")
	var horizontal_before: Array = state.get_display_item_cells(horizontal_recipe_id).duplicate()
	if not bool(root.call("_rotate_showcase_product", horizontal_recipe_id)):
		_fail("horizontal example should rotate through the existing runtime path")
	else:
		var horizontal_after: Array = state.get_display_item_cells(horizontal_recipe_id)
		if horizontal_after == horizontal_before:
			_fail("rotating should change the horizontal footprint")
		grid = root.get_node("Root/Body/MainArea/StorefrontPanel/ShowcasePanel/ShowcaseGrid") as GridContainer
		for rotated_button in _buttons_for_recipe(grid, horizontal_recipe_id):
			var rotated_icon := rotated_button.get_node("RecipeIcon") as TextureRect
			if not rotated_icon.texture is AtlasTexture:
				_fail("rotated product should keep AtlasTexture fragments")

	var preview_cells: Array[Vector2i] = [Vector2i(7, 5), Vector2i(7, 6)]
	root.call("_set_showcase_drag_preview", horizontal_recipe_id, preview_cells, "move", "standard")
	for preview_cell in preview_cells:
		var preview_index := (preview_cell.x - 1) * 14 + preview_cell.y - 1
		var preview_button := grid.get_child(preview_index) as Button
		var preview_icon := preview_button.get_node("RecipeIcon") as TextureRect
		if not preview_icon.texture is AtlasTexture or not is_equal_approx(preview_icon.modulate.a, 0.55):
			_fail("valid drag preview should show a translucent fragment")
	root.call("_clear_showcase_drag_preview")
	for preview_cell in preview_cells:
		var preview_index := (preview_cell.x - 1) * 14 + preview_cell.y - 1
		var preview_button := grid.get_child(preview_index) as Button
		if (preview_button.get_node("RecipeIcon") as TextureRect).texture != null:
			_fail("cleared drag preview should leave no fragment residue")

	var irregular: Dictionary = selections["irregular"]
	var irregular_recipe_id := String(irregular.get("recipe_id", ""))
	var irregular_anchor: Vector2i = anchors["irregular"]
	var occupied_local := {}
	for cell_value in irregular.get("cells", []):
		occupied_local["%d:%d" % [int(cell_value[0]), int(cell_value[1])]] = true
	for row in range(1, int(irregular.get("rows", 1)) + 1):
		for col in range(1, int(irregular.get("cols", 1)) + 1):
			if occupied_local.has("%d:%d" % [row, col]):
				continue
			var missing_cell := Vector2i(irregular_anchor.x + row - 1, irregular_anchor.y + col - 1)
			var missing_index := (missing_cell.x - 1) * 14 + missing_cell.y - 1
			var missing_button := grid.get_child(missing_index) as Button
			var missing_icon := missing_button.get_node("RecipeIcon") as TextureRect
			if missing_icon.texture != null or missing_button.has_meta("recipe_id") and String(missing_button.get_meta("recipe_id")) == irregular_recipe_id:
				_fail("irregular missing cell should remain empty")

	if failed:
		quit(1)
	else:
		print("SHOWCASE_ICON_DISTRIBUTION_SELF_CHECK_PASS")
		quit(0)


func _select_shape_examples() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	var entries: Dictionary = (parsed as Dictionary).get("entries", {}) if parsed is Dictionary else {}
	var selected := {}
	var used := {}
	var keys := entries.keys()
	keys.sort()
	for entry_key_value in keys:
		var entry: Dictionary = entries[entry_key_value]
		if String(entry.get("variant_id", "")) != "standard" or int(entry.get("rotation", -1)) != 0:
			continue
		var recipe_id := String(entry.get("recipe_id", ""))
		if used.has(recipe_id):
			continue
		var rows := int(entry.get("rows", 0))
		var cols := int(entry.get("cols", 0))
		var cell_count := (entry.get("cells", []) as Array).size()
		var category := ""
		if cell_count < rows * cols:
			category = "irregular"
		elif rows == 1 and cols == 1:
			category = "single"
		elif rows == 1 and cols == 2:
			category = "horizontal"
		elif rows == 2 and cols == 1:
			category = "vertical"
		elif rows == 2 and cols == 2:
			category = "square"
		if not category.is_empty() and not selected.has(category):
			selected[category] = entry
			used[recipe_id] = true
	var rice_milk_entry: Variant = entries.get("rice_milk_drink|standard|r0", {})
	if rice_milk_entry is Dictionary and not (rice_milk_entry as Dictionary).is_empty():
		selected["vertical"] = rice_milk_entry
	var staged_horizontal_entry: Variant = entries.get("chicken_steamed_dumpling|standard|r0", {})
	if staged_horizontal_entry is Dictionary and not (staged_horizontal_entry as Dictionary).is_empty():
		selected["horizontal"] = staged_horizontal_entry
	return selected


func _translated_cells(raw_cells: Variant, anchor: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if not raw_cells is Array:
		return cells
	for cell_value in raw_cells:
		if cell_value is Array and cell_value.size() == 2:
			cells.append(Vector2i(anchor.x + int(cell_value[0]) - 1, anchor.y + int(cell_value[1]) - 1))
	return cells


func _buttons_for_recipe(grid: GridContainer, recipe_id: String) -> Array[Button]:
	var buttons: Array[Button] = []
	for child in grid.get_children():
		if child is Button and child.has_meta("recipe_id") and String(child.get_meta("recipe_id")) == recipe_id:
			buttons.append(child as Button)
	return buttons


func _fail(message: String) -> void:
	failed = true
	push_error(message)
