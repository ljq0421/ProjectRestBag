extends SceneTree

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const GAME_STATE := preload("res://scripts/game_state.gd")

const RECIPE_ID := "rice_milk_drink"
const CELLS: Array[Vector2i] = [Vector2i(5, 5), Vector2i(6, 5)]
const EXPECTED_PATHS := [
	"res://resources/recipe_icons_showcase_staged/rice_milk_drink__trial__standard__r0.png",
	"res://resources/recipe_icons_showcase_staged/rice_milk_drink__popular__standard__r0.png",
	"res://resources/recipe_icons_showcase_staged/rice_milk_drink__signature__standard__r0.png",
]

var _failures: Array[String] = []
var _save_path := OS.get_temp_dir().path_join("showcase_stage_icon_main_path_self_check.json")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var view = MAIN_SCENE.instantiate()
	view.set("save_path", _save_path)
	view.set("broken_save_path", _save_path + ".broken")
	root.add_child(view)
	await process_frame
	await process_frame

	var state = GAME_STATE.new_game()
	state.level = 99
	state.add_recipe(RECIPE_ID)
	state.display_items = {
		RECIPE_ID: {
			"cells": CELLS.duplicate(),
			"fresh_stock": 1,
			"carried_stock": 0,
			"stock": 1,
			"variant_id": "standard",
		}
	}
	view.set("state", state)
	view.call("_refresh_showcase_layout_projection")

	var first_index := (CELLS[0].x - 1) * 14 + CELLS[0].y - 1

	for mastery_level in range(3):
		var growth: Dictionary = state.get_recipe_growth(RECIPE_ID)
		growth["mastery_level"] = mastery_level
		state.recipe_growth[RECIPE_ID] = growth
		view.call("_refresh_storefront_showcase")
		await process_frame
		var grid := view.get_node("Root/Body/MainArea/StorefrontPanel/ShowcasePanel/ShowcaseGrid") as GridContainer
		var first_button := grid.get_child(first_index) as Button
		_expect_atlas_path(
			first_button.get_node("RecipeIcon") as TextureRect,
			String(EXPECTED_PATHS[mastery_level]),
			"listed stage %d" % mastery_level
		)

	var signature_growth: Dictionary = state.get_recipe_growth(RECIPE_ID)
	signature_growth["mastery_level"] = 2
	state.recipe_growth[RECIPE_ID] = signature_growth
	view.call("_set_showcase_drag_preview", RECIPE_ID, CELLS, "move", "standard")
	var preview_grid := view.get_node("Root/Body/MainArea/StorefrontPanel/ShowcasePanel/ShowcaseGrid") as GridContainer
	var preview_button := preview_grid.get_child(first_index) as Button
	_expect_atlas_path(
		preview_button.get_node("RecipeIcon") as TextureRect,
		String(EXPECTED_PATHS[2]),
		"signature drag preview"
	)

	_finish(view)


func _expect_atlas_path(icon: TextureRect, expected_path: String, context: String) -> void:
	if icon == null or not icon.texture is AtlasTexture:
		_fail("%s should use an AtlasTexture fragment" % context)
		return
	var fragment := icon.texture as AtlasTexture
	if fragment.atlas == null or fragment.atlas.resource_path != expected_path:
		_fail("%s should use %s, got %s" % [context, expected_path, fragment.atlas.resource_path if fragment.atlas != null else "<null>"])
	if fragment.region.size != Vector2(72, 72):
		_fail("%s should use an exact 72x72 fragment" % context)


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish(view: Node) -> void:
	if is_instance_valid(view):
		view.queue_free()
	for path in [_save_path, _save_path + ".broken"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	if _failures.is_empty():
		print("SHOWCASE_STAGE_ICON_MAIN_PATH_SELF_CHECK_PASS")
		quit(0)
	else:
		for failure in _failures:
			printerr("SHOWCASE_STAGE_ICON_MAIN_PATH_SELF_CHECK_FAIL: %s" % failure)
		quit(1)
