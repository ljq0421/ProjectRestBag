extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/Main.tscn"
const SAVE_PATH := "catalog_icon_layout_self_check.json"
const BROKEN_SAVE_PATH := "catalog_icon_layout_self_check.broken.json"

var _failures: Array[String] = []


func _init() -> void:
	_run()
	if _failures.is_empty():
		print("CATALOG_ICON_LAYOUT_SELF_CHECK_PASS")
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
	var root := packed_scene.instantiate()
	root.set("save_path", save_path)
	root.set("broken_save_path", broken_save_path)
	root.call("_ready")
	root.call("_show_catalog_global_popup")

	var catalog_overlay := root.get_node("GlobalOverlayLayer/OverlayFrame/OverlayModeStack/CatalogOverlay")
	var catalog_grid := root.get_node("GlobalOverlayLayer/OverlayFrame/OverlayModeStack/CatalogOverlay/CatalogContent/CatalogGridPanel/CatalogGrid") as GridContainer
	var state = root.get("state")
	if not state.is_recipe_unlocked("rice_milk_drink"):
		if not state.add_recipe("rice_milk_drink"):
			_fail("isolated state should unlock rice_milk_drink")
		catalog_overlay.call("refresh_panel", root)
	var catalog = root.get("catalog")
	var rice_recipe: Dictionary = catalog.get_recipes().get("rice_milk_drink", {})
	for stage_level in range(3):
		var growth: Dictionary = state.get_recipe_growth("rice_milk_drink")
		growth["mastery_level"] = stage_level
		state.recipe_growth["rice_milk_drink"] = growth
		var stage_card := root.call("_make_catalog_cell", "rice_milk_drink", rice_recipe) as Button
		var stage_icon := stage_card.get_node("RecipeIcon") as TextureRect
		var expected_suffix: String = String(["", "_popular", "_signature"][stage_level])
		var expected_path := "res://resources/recipe_icons_catalog/rice_milk_drink%s.png" % expected_suffix
		if stage_icon.texture == null or stage_icon.texture.resource_path != expected_path:
			_fail("catalog stage %d should load %s" % [stage_level, expected_path])
		stage_card.free()
	var trial_growth: Dictionary = state.get_recipe_growth("rice_milk_drink")
	trial_growth["mastery_level"] = 0
	state.recipe_growth["rice_milk_drink"] = trial_growth
	catalog_overlay.call("refresh_panel", root)

	if catalog_grid.columns != 5:
		_fail("catalog grid should use 5 compact columns, got %d" % catalog_grid.columns)
	if catalog_grid.get_child_count() != 15:
		_fail("catalog grid should contain 15 compact page cells, got %d" % catalog_grid.get_child_count())

	var unlocked_cards := 0
	var locked_cards := 0
	for child in catalog_grid.get_children():
		if not child is Button or not child.has_meta("recipe_id"):
			continue
		var card := child as Button
		var recipe_id := String(card.get_meta("recipe_id", ""))
		var icon := card.get_node_or_null("RecipeIcon") as TextureRect
		if card.custom_minimum_size != Vector2(112, 112):
			_fail("catalog card %s should be 112x112" % recipe_id)
		if icon == null:
			_fail("catalog card %s should contain RecipeIcon" % recipe_id)
			continue
		if icon.custom_minimum_size != Vector2(112, 112):
			_fail("catalog icon %s should fill the 112x112 card" % recipe_id)
		if icon.anchor_right != 1.0 or icon.anchor_bottom != 1.0:
			_fail("catalog icon %s should fill its card anchors" % recipe_id)
		if icon.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			_fail("catalog icon %s should ignore mouse input" % recipe_id)
		if state.is_recipe_unlocked(recipe_id):
			unlocked_cards += 1
			if not card.text.is_empty():
				_fail("unlocked card %s should only display its icon" % recipe_id)
			if icon.texture == null:
				_fail("unlocked card %s should load its catalog icon" % recipe_id)
			var has_crisp_source := FileAccess.file_exists("res://resources/ui/icons_v1/%s_1.png" % recipe_id)
			var expected_texture_size := Vector2(112, 112) if has_crisp_source else Vector2(132, 132)
			if icon.texture != null and icon.texture.get_size() != expected_texture_size:
				_fail("catalog texture %s should be %s" % [recipe_id, expected_texture_size])
			if card.tooltip_text.find("食材：") == -1 or card.tooltip_text.find("工具：") == -1:
				_fail("unlocked card %s should keep full hover information" % recipe_id)
		else:
			locked_cards += 1
			if icon.texture != null:
				_fail("locked card %s should not display an icon" % recipe_id)
			if card.text.find("未解锁线索") == -1:
				_fail("locked card %s should preserve locked text" % recipe_id)

	if unlocked_cards <= 0:
		_fail("focused catalog page should include an unlocked card")
	if locked_cards <= 0:
		_fail("focused catalog page should include locked cards")

	root.free()
	_delete_file(save_path)
	_delete_file(broken_save_path)
func _delete_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _fail(message: String) -> void:
	_failures.append(message)
