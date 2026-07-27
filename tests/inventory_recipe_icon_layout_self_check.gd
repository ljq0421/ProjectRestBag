extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/Main.tscn"
const Catalog = preload("res://scripts/catalog.gd")
const SAVE_PATH := "inventory_recipe_icon_layout_self_check.json"
const BROKEN_SAVE_PATH := "inventory_recipe_icon_layout_self_check.broken.json"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _finish() -> void:
	if _failures.is_empty():
		print("INVENTORY_RECIPE_ICON_LAYOUT_SELF_CHECK_PASS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _run() -> void:
	var save_path := OS.get_temp_dir().path_join(SAVE_PATH)
	var broken_save_path := OS.get_temp_dir().path_join(BROKEN_SAVE_PATH)
	_delete_file(save_path)
	_delete_file(broken_save_path)

	var packed_scene := load(MAIN_SCENE_PATH) as PackedScene
	if packed_scene == null:
		_fail("Main scene should load")
		return
	var main := packed_scene.instantiate()
	main.set("save_path", save_path)
	main.set("broken_save_path", broken_save_path)
	root.add_child(main)
	await process_frame
	var state = main.get("state")
	state.add_product("sponge_cake", 2)
	state.add_ingredient("sugar", 5)
	state.add_recipe("rice_milk_drink")
	main.call("_show_inventory_global_popup")
	await process_frame
	var inventory_grid := main.get_node("GlobalOverlayLayer/OverlayFrame/OverlayModeStack/InventoryOverlay/InventoryBody/InventoryMainPanel/InventoryGrid") as GridContainer
	_expect(inventory_grid.columns == 8, "runtime inventory grid should use eight compact columns")
	_expect(inventory_grid.get_child_count() == 48, "runtime inventory grid should use forty-eight cells")
	for child in inventory_grid.get_children():
		if child is Button:
			_expect((child as Button).size == Vector2(80, 80), "runtime inventory cells should stay exactly 80x80, got %s" % (child as Button).size)

	var product_entry := {
		"kind": "product",
		"id": "rice_milk_drink",
		"name": "Rice Milk Drink",
		"count": 12,
	}
	for stage_level in range(3):
		var growth: Dictionary = state.get_recipe_growth("rice_milk_drink")
		growth["mastery_level"] = stage_level
		state.recipe_growth["rice_milk_drink"] = growth
		var stage_cell := main.call("_make_inventory_cell", "", product_entry) as Button
		var stage_icon := stage_cell.get_node("RecipeIcon") as TextureRect
		var expected_suffix: String = String(["", "_popular", "_signature"][stage_level])
		var expected_inventory_path := "res://resources/recipe_icons_inventory/rice_milk_drink%s.png" % expected_suffix
		_expect(stage_icon.texture != null and stage_icon.texture.resource_path == expected_inventory_path, "inventory stage %d should load %s" % [stage_level, expected_inventory_path])
		var action_icon := main.call("_material_icon_texture", "rice_milk_drink") as Texture2D
		var expected_action_path := "res://resources/recipe_icons_action/rice_milk_drink%s.png" % expected_suffix
		_expect(action_icon != null and action_icon.resource_path == expected_action_path, "action stage %d should load %s" % [stage_level, expected_action_path])
		var research_icon := main.call("_research_result_recipe_icon_texture", "rice_milk_drink") as Texture2D
		var expected_research_path := "res://resources/recipe_icons/rice_milk_drink%s.png" % expected_suffix
		_expect(research_icon != null and research_icon.resource_path == expected_research_path, "research stage %d should load %s" % [stage_level, expected_research_path])
		stage_cell.free()
	var trial_growth: Dictionary = state.get_recipe_growth("rice_milk_drink")
	trial_growth["mastery_level"] = 0
	state.recipe_growth["rice_milk_drink"] = trial_growth
	var product_cell := main.call("_make_inventory_cell", "", product_entry) as Button
	_expect(product_cell != null, "product inventory cell should be created")
	if product_cell != null:
		_expect(product_cell.custom_minimum_size == Vector2(80, 80), "product inventory cell should be 80x80")
		_expect(product_cell.text.is_empty(), "product inventory cell should leave text clear for the icon")
		_expect(product_cell.has_method("configure_drag"), "product inventory cell should preserve drag behavior")
		var icon := product_cell.get_node_or_null("RecipeIcon") as TextureRect
		var quantity_badge := product_cell.get_node_or_null("QuantityBadge") as Label
		_expect(icon != null, "product inventory cell should contain RecipeIcon")
		_expect(quantity_badge != null, "product inventory cell should contain QuantityBadge")
		if icon != null:
			_expect(icon.custom_minimum_size == Vector2(80, 80), "product RecipeIcon should be 80x80")
			_expect(icon.mouse_filter == Control.MOUSE_FILTER_IGNORE, "product RecipeIcon should not intercept input")
			_expect(icon.texture != null, "product inventory cell should load its inventory icon")
			if icon.texture != null:
				_expect(icon.texture.get_size() == Vector2(80, 80), "inventory recipe texture should be 80x80")
		if quantity_badge != null:
			_expect(quantity_badge.text == "12", "product quantity badge should show the count")
			_expect(quantity_badge.mouse_filter == Control.MOUSE_FILTER_IGNORE, "quantity badge should not intercept input")
		var drag_data: Dictionary = product_cell.get("drag_data")
		_expect(String(drag_data.get("recipe_id", "")) == "rice_milk_drink", "product drag data should preserve recipe_id")
		_expect(product_cell.get_signal_connection_list("gui_input").size() > 0, "product cell should preserve right-click variant input")
		product_cell.free()

	var ingredient_entry := {
		"kind": "ingredient",
		"id": "rice",
		"name": "Rice",
		"count": 8,
	}
	for ingredient_id_value in Catalog.INGREDIENTS.keys():
		var ingredient_id := String(ingredient_id_value)
		var catalog_texture := main.call("_material_icon_texture", ingredient_id) as Texture2D
		var expected_ingredient_path := "res://resources/ui/ingredient_v1/%s.png" % ingredient_id
		_expect(
			catalog_texture != null and catalog_texture.resource_path == expected_ingredient_path,
			"ingredient %s should load %s" % [ingredient_id, expected_ingredient_path]
		)
	var ingredient_cell := main.call("_make_inventory_cell", "", ingredient_entry) as Button
	_expect(ingredient_cell != null, "ingredient inventory cell should be created")
	if ingredient_cell != null:
		_expect(ingredient_cell.custom_minimum_size == Vector2(80, 80), "ingredient inventory cell should be 80x80")
		_expect(ingredient_cell.text.is_empty(), "ingredient inventory cell should leave text clear for the icon")
		var ingredient_icon := ingredient_cell.get_node_or_null("RecipeIcon") as TextureRect
		var ingredient_badge := ingredient_cell.get_node_or_null("QuantityBadge") as Label
		_expect(ingredient_icon != null, "ingredient inventory cell should contain RecipeIcon")
		_expect(ingredient_badge != null, "ingredient inventory cell should contain QuantityBadge")
		if ingredient_icon != null:
			_expect(ingredient_icon.texture != null, "ingredient inventory cell should load its generated icon")
			_expect(ingredient_icon.mouse_filter == Control.MOUSE_FILTER_IGNORE, "ingredient RecipeIcon should not intercept input")
		if ingredient_badge != null:
			_expect(ingredient_badge.text == "8", "ingredient quantity badge should show the count")
		ingredient_cell.free()

	main.queue_free()
	await process_frame
	_delete_file(save_path)
	_delete_file(broken_save_path)
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _delete_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _fail(message: String) -> void:
	_failures.append(message)
