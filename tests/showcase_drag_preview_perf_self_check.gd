extends SceneTree

const CATALOG := preload("res://scripts/catalog.gd")
const MAIN_SCENE := preload("res://scenes/Main.tscn")

var failed := false


func _init() -> void:
	var catalog := CATALOG.new()
	if not catalog.has_method("clear_json_cache"):
		_fail("Catalog should expose clear_json_cache for hot-reloadable cached JSON config")
	else:
		catalog.clear_json_cache()
	if not catalog.has_method("cached_json_path_count"):
		_fail("Catalog should expose cached_json_path_count for cache verification")
	else:
		var first_config: Dictionary = catalog.get_recipe_display_config()
		var second_config: Dictionary = catalog.get_recipe_display_config()
		if first_config.is_empty() or second_config.is_empty():
			_fail("recipe display config should load through the cache")
		if catalog.cached_json_path_count() != 1:
			_fail("recipe display config should occupy one cached JSON path, got %d" % catalog.cached_json_path_count())
		first_config["cache_probe"] = true
		var third_config: Dictionary = catalog.get_recipe_display_config()
		if third_config.has("cache_probe"):
			_fail("cached JSON results should be duplicated for callers")

	var root := MAIN_SCENE.instantiate()
	get_root().add_child(root)
	await root.ready
	if not root.has_method("_showcase_preview_slot_indices_for_cells"):
		_fail("Main view should calculate the minimal showcase preview refresh scope")
	else:
		var previous := [Vector2i(3, 3), Vector2i(3, 4)]
		var current := [Vector2i(4, 3)]
		var indices: Array = root.call("_showcase_preview_slot_indices_for_cells", previous, current)
		_expect_has_index(indices, 30)
		_expect_has_index(indices, 31)
		_expect_has_index(indices, 44)
		if indices.size() != 3:
			_fail("preview refresh scope should contain only changed cells, got %s" % [indices])
		if indices.has(0) or indices.has(195):
			_fail("preview refresh scope should not include untouched showcase edges")

	var icon_service: Variant = root.get("showcase_icon_service")
	if icon_service == null:
		_fail("Main view should expose one long-lived showcase icon service")
	else:
		var texture_count_before := int(icon_service.call("texture_cache_size"))
		var fragment_count_before := int(icon_service.call("fragment_cache_size"))
		root.call("_refresh_showcase_countdown_texts", int(Time.get_unix_time_from_system()) + 1)
		if int(icon_service.call("texture_cache_size")) != texture_count_before:
			_fail("countdown refresh should not load showcase textures")
		if int(icon_service.call("fragment_cache_size")) != fragment_count_before:
			_fail("countdown refresh should not create showcase fragments")

	if failed:
		quit(1)
	else:
		print("SHOWCASE_DRAG_PREVIEW_PERF_SELF_CHECK_PASS")
		quit(0)


func _expect_has_index(indices: Array, expected: int) -> void:
	if not indices.has(expected):
		_fail("preview refresh scope should include slot %d, got %s" % [expected, indices])


func _fail(message: String) -> void:
	failed = true
	push_error(message)
