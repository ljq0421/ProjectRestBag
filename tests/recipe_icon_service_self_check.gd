extends SceneTree

const RecipeIconService := preload("res://scripts/recipe_icon_service.gd")

var failures: Array[String] = []


func _init() -> void:
	_run()
	if failures.is_empty():
		print("RECIPE_ICON_SERVICE_SELF_CHECK_PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _run() -> void:
	_expect(RecipeIconService.stage_suffix(0) == "", "trial should use the base filename")
	_expect(RecipeIconService.stage_suffix(1) == "_popular", "popular should use the popular suffix")
	_expect(RecipeIconService.stage_suffix(2) == "_signature", "signature should use the signature suffix")
	_expect(RecipeIconService.stage_suffix(-5) == "", "negative stages should clamp to trial")
	_expect(RecipeIconService.stage_suffix(99) == "_signature", "high stages should clamp to signature")

	var catalog_paths := RecipeIconService.candidate_paths("rice_milk_drink", 1, "catalog")
	_expect(catalog_paths == [
		"res://resources/recipe_icons_catalog/rice_milk_drink_popular.png",
		"res://resources/recipe_icons_catalog/rice_milk_drink.png",
		"res://resources/recipe_icons/rice_milk_drink_popular.png",
		"res://resources/recipe_icons/rice_milk_drink.png",
	], "catalog candidates should preserve stage-aware fallback order")

	var base_paths := RecipeIconService.candidate_paths("rice_milk_drink", 2, "base")
	_expect(base_paths == [
		"res://resources/recipe_icons/rice_milk_drink_signature.png",
		"res://resources/recipe_icons/rice_milk_drink.png",
	], "base candidates should not contain duplicates")
	_expect(RecipeIconService.candidate_paths("", 0, "catalog").is_empty(), "empty recipe ids should have no candidates")
	_expect(RecipeIconService.candidate_paths("rice_milk_drink", 0, "unknown").is_empty(), "unknown surfaces should have no candidates")

	for stage_level in range(3):
		for surface in ["base", "catalog", "inventory", "action"]:
			var texture := RecipeIconService.texture("rice_milk_drink", stage_level, surface)
			_expect(texture != null, "rice_milk_drink stage %d %s texture should load" % [stage_level, surface])
			if texture == null:
				continue
			var expected_suffix := RecipeIconService.stage_suffix(stage_level)
			var expected_path := "%s/rice_milk_drink%s.png" % [
				String(RecipeIconService.SURFACE_DIRECTORIES[surface]),
				expected_suffix,
			]
			_expect(texture.resource_path == expected_path, "stage %d %s should load %s, got %s" % [stage_level, surface, expected_path, texture.resource_path])
			var expected_size: Vector2 = {
				"base": Vector2(128, 128),
				"catalog": Vector2(112, 112),
				"inventory": Vector2(80, 80),
				"action": Vector2(32, 32),
			}[surface]
			_expect(texture.get_size() == expected_size, "stage %d %s should be %s, got %s" % [stage_level, surface, expected_size, texture.get_size()])

	var sponge_signature := RecipeIconService.texture("sponge_cake", 2, "catalog")
	_expect(sponge_signature != null, "newly staged recipes should load their requested stage")
	if sponge_signature != null:
		_expect(sponge_signature.resource_path == "res://resources/recipe_icons_catalog/sponge_cake_signature.png", "newly staged recipes should use signature art")

	var final_batch_signature := RecipeIconService.texture("apple_crumble", 2, "catalog")
	_expect(final_batch_signature != null, "final staged batch recipes should load their requested stage")
	if final_batch_signature != null:
		_expect(final_batch_signature.resource_path == "res://resources/recipe_icons_catalog/apple_crumble_signature.png", "final staged batch recipes should use signature art")
	_expect(RecipeIconService.texture("not_a_recipe", 2, "catalog") == null, "missing recipes should return null")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
