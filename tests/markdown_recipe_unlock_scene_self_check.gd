extends SceneTree

const CoreFeatureUnlockService := preload("res://scripts/core_feature_unlock_service.gd")
const MainScene := preload("res://scenes/Main.tscn")
const RecipeBook := preload("res://scripts/recipe_book.gd")

var failures: Array[String] = []
var save_path := ""
var broken_save_path := ""
var manifest_path := ""


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var temp_root := OS.get_temp_dir()
	save_path = temp_root.path_join("markdown_recipe_unlock_scene_self_check.json")
	broken_save_path = save_path + ".broken"
	manifest_path = temp_root.path_join("markdown_recipe_unlock_scene_manifest.md")
	_cleanup()
	_write_manifest("rice_milk_drink\n")

	var view := MainScene.instantiate()
	view.set("save_path", save_path)
	view.set("broken_save_path", broken_save_path)
	view.set("recipe_qa_manifest_path", manifest_path)
	root.add_child(view)
	await process_frame
	await process_frame

	var old_f8_event := InputEventKey.new()
	old_f8_event.pressed = true
	old_f8_event.keycode = KEY_F8
	_expect(not bool(view.call("_handle_recipe_qa_unlock_shortcut", old_f8_event)), "F8 should not be captured because the Godot editor uses it to stop the game")
	var key_event := InputEventKey.new()
	key_event.pressed = true
	key_event.keycode = KEY_U
	key_event.ctrl_pressed = true
	key_event.alt_pressed = true
	_expect(bool(view.call("_handle_recipe_qa_unlock_shortcut", key_event)), "Ctrl+Alt+U should be handled in a debug build")
	await process_frame
	var state = view.get("state")
	_expect(state.is_recipe_unlocked("rice_milk_drink"), "Ctrl+Alt+U should unlock the manifest recipe")
	_expect(state.unlocked_devices.has("round_pot"), "Ctrl+Alt+U should explicitly unlock the recipe device")
	_expect(state.is_core_feature_unlocked(CoreFeatureUnlockService.LIST), "Ctrl+Alt+U should unlock through listing")
	_expect(not state.is_core_feature_unlocked(CoreFeatureUnlockService.RULEBOOK), "Ctrl+Alt+U should leave post-list features locked")
	_expect(FileAccess.file_exists(save_path), "Ctrl+Alt+U should persist the imported state")
	var status_label := view.get_node("Root/StatusBar/StatusLabel") as Label
	_expect(status_label.text.contains("配方验收导入完成"), "Ctrl+Alt+U should show a visible success summary")

	var recipe_rows := view.get("recipe_rows") as VBoxContainer
	_expect(_find_child_with_meta(recipe_rows, "recipe_id", "rice_milk_drink") != null, "normal production page should contain the imported recipe")
	view.call("_show_catalog_global_popup")
	await process_frame
	var catalog_grid := view.get("catalog_grid") as GridContainer
	var catalog_card := _find_child_with_meta(catalog_grid, "recipe_id", "rice_milk_drink") as Button
	_expect(catalog_card != null and not catalog_card.disabled, "normal catalog should render the imported recipe as unlocked")

	state.ingredient_inventory = {"rice": 1, "spring_water": 1}
	var make_result: Dictionary = RecipeBook.make_product(state, "rice_milk_drink", 1, 1000)
	_expect(bool(make_result.get("ok", false)), "imported recipe should start through the normal crafting service")
	var completion: Dictionary = view.call("_process_online_recipe_production", 1002)
	_expect(int(completion.get("completed_batches", 0)) == 1, "normal production queue should complete the imported recipe")
	_expect(state.get_product_count("rice_milk_drink") == 3, "completed product should enter product inventory")

	var product_cell := view.call("_make_inventory_cell", "", {
		"kind": "product",
		"id": "rice_milk_drink",
		"name": "米浆饮",
		"count": state.get_product_count("rice_milk_drink"),
	}) as Button
	_expect(product_cell != null, "normal inventory should build a product cell")
	var drag_data: Dictionary = product_cell.get("drag_data") if product_cell != null else {}
	_expect_equal(String(drag_data.get("kind", "")), "inventory_product", "inventory cell should expose the normal drag kind")
	_expect_equal(String(drag_data.get("recipe_id", "")), "rice_milk_drink", "inventory drag should preserve recipe id")
	var placement: Dictionary = view.call("_first_available_showcase_placement", "rice_milk_drink", "standard")
	_expect(not placement.is_empty(), "imported product should have an available showcase placement")
	if not placement.is_empty():
		drag_data["target_slot_index"] = int(placement.get("slot_index", -1))
		_expect(bool(view.call("_can_drop_showcase_data", "showcase", drag_data)), "normal showcase should accept the inventory drag")
		_expect(bool(view.call("_drop_showcase_data", "showcase", drag_data)), "normal drop path should list the imported product")
		_expect(state.is_display_item_placed("rice_milk_drink"), "listed product should appear in showcase state")
		_expect(state.get_product_count("rice_milk_drink") == 2, "listing should consume one product from inventory")
	if product_cell != null:
		product_cell.free()

	var recipes_before: Array = state.unlocked_recipes.duplicate(true)
	var devices_before: Array = state.unlocked_devices.duplicate(true)
	var level_before: int = state.level
	_write_manifest("matcha_pudding\n")
	view.set("save_path", temp_root.path_join("missing_recipe_qa_save_directory/save.json"))
	var failed_result: Dictionary = view.call("_run_recipe_qa_unlock_import", manifest_path)
	_expect(not bool(failed_result.get("ok", true)) and String(failed_result.get("stage", "")) == "save", "save failure should be reported")
	_expect_equal(state.level, level_before, "save failure should roll back level")
	_expect_equal(state.unlocked_recipes, recipes_before, "save failure should roll back recipes")
	_expect_equal(state.unlocked_devices, devices_before, "save failure should roll back devices")
	_expect(not state.is_recipe_unlocked("matcha_pudding"), "failed import should not remain in memory")

	view.queue_free()
	await process_frame
	_cleanup()
	_finish()


func _find_child_with_meta(parent: Node, key: StringName, expected: Variant) -> Node:
	for child: Node in parent.get_children():
		if child.has_meta(key) and child.get_meta(key) == expected:
			return child
	return null


func _write_manifest(text: String) -> void:
	var file := FileAccess.open(manifest_path, FileAccess.WRITE)
	if file == null:
		failures.append("test manifest should be writable")
		return
	file.store_string(text)
	file.close()


func _cleanup() -> void:
	for path in [save_path, broken_save_path, manifest_path]:
		if not path.is_empty() and FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		failures.append("%s: expected %s, got %s" % [message, str(expected), str(actual)])


func _finish() -> void:
	if failures.is_empty():
		print("MARKDOWN_RECIPE_UNLOCK_SCENE_SELF_CHECK_PASS")
		quit(0)
		return
	for failure in failures:
		printerr("MARKDOWN_RECIPE_UNLOCK_SCENE_SELF_CHECK_FAIL: %s" % failure)
	quit(1)
