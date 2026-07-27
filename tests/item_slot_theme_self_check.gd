extends SceneTree

const THEME_PATH := "res://resources/ui/skin/neighborhood_dessert/neighborhood_dessert_theme.tres"
const MAIN_SCENE_PATH := "res://scenes/Main.tscn"
const INVENTORY_CELL_SCENE_PATH := "res://scenes/ui/overlays/inventory_product_cell.tscn"
const CATALOG_CARD_SCENE_PATH := "res://scenes/ui/overlays/catalog_recipe_card.tscn"
const OUTPUT_CELL_SCENE_PATH := "res://scenes/ui/pages/output_cell.tscn"
const RESEARCH_SLOT_SCENE_PATH := "res://scenes/ui/pages/research_input_slot.tscn"
const SHOWCASE_SLOT_SCENE_PATH := "res://scenes/ui/storefront/showcase_slot.tscn"

const ITEM_SLOT := &"DessertItemSlot"
const LOCKED_ITEM_SLOT := &"DessertItemSlotLocked"

const SLOT_TEXTURE_PATHS := {
	"normal": "res://resources/ui/skin/neighborhood_dessert/runtime/slot_item_normal.png",
	"focus": "res://resources/ui/skin/neighborhood_dessert/runtime/slot_item_normal.png",
	"hover": "res://resources/ui/skin/neighborhood_dessert/runtime/slot_item_hover.png",
	"pressed": "res://resources/ui/skin/neighborhood_dessert/runtime/slot_item_selected.png",
	"hover_pressed": "res://resources/ui/skin/neighborhood_dessert/runtime/slot_item_selected.png",
	"disabled": "res://resources/ui/skin/neighborhood_dessert/runtime/slot_item_disabled.png",
}

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _finish() -> void:
	if _failures.is_empty():
		print("ITEM_SLOT_THEME_SELF_CHECK_PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _run() -> void:
	var theme := load(THEME_PATH) as Theme
	if theme == null:
		_fail("neighborhood dessert Theme should load")
		_finish()
		return
	for style_name: String in SLOT_TEXTURE_PATHS:
		_expect_style_path(theme, StringName(style_name), ITEM_SLOT, SLOT_TEXTURE_PATHS[style_name])
		_expect_style_path(
			theme,
			StringName(style_name),
			LOCKED_ITEM_SLOT,
			"res://resources/ui/skin/neighborhood_dessert/runtime/slot_item_locked.png"
		)

	_expect_scene_variation(INVENTORY_CELL_SCENE_PATH, ITEM_SLOT)
	_expect_scene_variation(CATALOG_CARD_SCENE_PATH, ITEM_SLOT)
	_expect_scene_variation(OUTPUT_CELL_SCENE_PATH, ITEM_SLOT)
	_expect_scene_variation(RESEARCH_SLOT_SCENE_PATH, &"DessertContentButton")
	_expect_scene_variation(SHOWCASE_SLOT_SCENE_PATH, &"DessertShowcaseSlot")

	var save_path := OS.get_temp_dir().path_join("item_slot_theme_self_check.json")
	var broken_save_path := OS.get_temp_dir().path_join("item_slot_theme_self_check.broken.json")
	_delete_file(save_path)
	_delete_file(broken_save_path)

	var packed_main := load(MAIN_SCENE_PATH) as PackedScene
	if packed_main == null:
		_fail("Main scene should load")
		_finish()
		return
	var main := packed_main.instantiate()
	main.set("save_path", save_path)
	main.set("broken_save_path", broken_save_path)
	root.add_child(main)
	await process_frame

	for entry: Dictionary in [
		{
			"kind": "product",
			"id": "rice_milk_drink",
			"name": "Rice Milk Drink",
			"count": 2,
		},
		{
			"kind": "ingredient",
			"id": "sugar",
			"name": "Sugar",
			"count": 3,
		},
		{
			"kind": "tool",
			"id": "farm_accelerator",
			"name": "Farm Accelerator",
			"count": 1,
		},
		{},
	]:
		var inventory_cell := main.call("_make_inventory_cell", "", entry) as Button
		_expect_variation(inventory_cell, ITEM_SLOT, "inventory cell")
		if inventory_cell != null:
			inventory_cell.free()

	var state = main.get("state")
	var catalog = main.get("catalog")
	var recipes: Dictionary = catalog.get_recipes()
	if not state.is_recipe_unlocked("rice_milk_drink"):
		state.add_recipe("rice_milk_drink")
	var unlocked_card := main.call(
		"_make_catalog_cell",
		"rice_milk_drink",
		recipes.get("rice_milk_drink", {})
	) as Button
	_expect_variation(unlocked_card, ITEM_SLOT, "unlocked catalog card")
	if unlocked_card != null:
		if unlocked_card.disabled:
			_fail("unlocked catalog card should remain enabled")
		unlocked_card.free()

	var locked_recipe_id := ""
	for recipe_id_value in recipes:
		var recipe_id := String(recipe_id_value)
		if not state.is_recipe_unlocked(recipe_id):
			locked_recipe_id = recipe_id
			break
	if locked_recipe_id.is_empty():
		_fail("isolated catalog should include a locked recipe")
	else:
		var locked_card := main.call(
			"_make_catalog_cell",
			locked_recipe_id,
			recipes.get(locked_recipe_id, {})
		) as Button
		_expect_variation(locked_card, LOCKED_ITEM_SLOT, "locked catalog card")
		if locked_card != null:
			if not locked_card.disabled:
				_fail("locked catalog card should remain disabled")
			locked_card.free()

	var empty_card := main.call("_make_catalog_cell", "", {}) as Button
	_expect_variation(empty_card, ITEM_SLOT, "empty catalog page cell")
	if empty_card != null:
		if not empty_card.disabled:
			_fail("empty catalog page cell should remain disabled")
		empty_card.free()

	main.queue_free()
	await process_frame
	_delete_file(save_path)
	_delete_file(broken_save_path)
	_finish()


func _expect_scene_variation(scene_path: String, expected: StringName) -> void:
	var packed := load(scene_path) as PackedScene
	if packed == null:
		_fail("%s should load" % scene_path)
		return
	var control := packed.instantiate() as Control
	_expect_variation(control, expected, scene_path)
	if control != null:
		control.free()


func _expect_variation(control: Control, expected: StringName, label: String) -> void:
	if control == null:
		_fail("%s should instantiate as Control" % label)
	elif control.theme_type_variation != expected:
		_fail("%s should use %s, got %s" % [label, expected, control.theme_type_variation])


func _expect_style_path(
		theme: Theme,
		style_name: StringName,
		variation: StringName,
		expected_path: String
) -> void:
	var style := theme.get_stylebox(style_name, variation)
	if not style is StyleBoxTexture:
		_fail("%s/%s should be StyleBoxTexture" % [variation, style_name])
		return
	var texture_style := style as StyleBoxTexture
	if texture_style.texture == null:
		_fail("%s/%s should have a texture" % [variation, style_name])
	elif texture_style.texture.resource_path != expected_path:
		_fail(
			"%s/%s should use %s, got %s"
			% [variation, style_name, expected_path, texture_style.texture.resource_path]
		)


func _delete_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _fail(message: String) -> void:
	_failures.append(message)
