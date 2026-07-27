extends SceneTree

const SERVICE_PATH := "res://scripts/ui/storefront/showcase_icon_service.gd"

var _failures: Array[String] = []


func _init() -> void:
	_run()
	if _failures.is_empty():
		print("SHOWCASE_ICON_SERVICE_SELF_CHECK_PASS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _run() -> void:
	var service_script := load(SERVICE_PATH) as Script
	if service_script == null:
		_fail("showcase icon service script should exist")
		return
	var service = service_script.new()
	_expect(service.call("load_manifest"), "showcase icon manifest should load")
	_expect(int(service.call("staged_entry_count")) == 5160, "staged showcase manifest should expose 5160 current-source entries")
	_test_staged_recipe_levels(service)

	var horizontal_recipe_id := "chicken_steamed_dumpling"
	var horizontal: Array[Vector2i] = [Vector2i(1, 1), Vector2i(1, 2)]
	var layout: Dictionary = service.call("layout_for_shape", horizontal_recipe_id, "standard", horizontal)
	_expect(not layout.is_empty(), "horizontal layout should resolve")
	if layout.is_empty():
		return
	var rotation := int(layout.get("rotation", -1))
	var first := service.call("fragment", horizontal_recipe_id, "standard", rotation, Vector2i(1, 1)) as AtlasTexture
	var second := service.call("fragment", horizontal_recipe_id, "standard", rotation, Vector2i(1, 2)) as AtlasTexture
	_expect(first != null and second != null, "occupied cells should resolve fragments")
	if first == null or second == null:
		return
	var horizontal_cell_size := int(layout.get("cell_size", 0))
	_expect(String(layout.get("source_kind", "")) == "staged", "horizontal source recipe should use its staged layout")
	_expect(horizontal_cell_size == 72, "selected staged entry should declare a 72px cell size")
	_expect(first.region.size == Vector2(horizontal_cell_size, horizontal_cell_size), "fragment should fill its staged slot")
	_expect(second.region.position != first.region.position, "neighbor cells should use different regions")

	var texture_cache_size := int(service.call("texture_cache_size"))
	var fragment_cache_size := int(service.call("fragment_cache_size"))
	var repeated := service.call("fragment", horizontal_recipe_id, "standard", rotation, Vector2i(1, 1)) as AtlasTexture
	_expect(repeated == first, "fragment lookup should reuse the cached AtlasTexture")
	_expect(int(service.call("texture_cache_size")) == texture_cache_size, "repeated lookup should not grow texture cache")
	_expect(int(service.call("fragment_cache_size")) == fragment_cache_size, "repeated lookup should not grow fragment cache")

	var missing: Variant = service.call("fragment", horizontal_recipe_id, "standard", rotation, Vector2i(2, 2))
	_expect(missing == null, "unoccupied local cell should have no fragment")
	_test_trial_and_legacy_fallback(service)


func _test_staged_recipe_levels(service) -> void:
	var vertical: Array[Vector2i] = [Vector2i(1, 1), Vector2i(2, 1)]
	var expected_stage_ids := ["trial", "popular", "signature"]
	var expected_paths := [
		"res://resources/recipe_icons_showcase_staged/rice_milk_drink__trial__standard__r0.png",
		"res://resources/recipe_icons_showcase_staged/rice_milk_drink__popular__standard__r0.png",
		"res://resources/recipe_icons_showcase_staged/rice_milk_drink__signature__standard__r0.png",
	]
	var stage_fragments: Array[AtlasTexture] = []
	for mastery_level in range(3):
		var layout: Dictionary = service.call("layout_for_shape", "rice_milk_drink", "standard", vertical, mastery_level)
		_expect(String(layout.get("source_kind", "")) == "staged", "stage %d should use staged showcase layout" % mastery_level)
		_expect(int(layout.get("mastery_level", -1)) == mastery_level, "stage %d layout should retain its mastery level" % mastery_level)
		_expect(String(layout.get("stage_id", "")) == expected_stage_ids[mastery_level], "stage %d should use the expected stage id" % mastery_level)
		var fragment := service.call("fragment", "rice_milk_drink", "standard", 0, Vector2i(1, 1), mastery_level) as AtlasTexture
		_expect(fragment != null, "stage %d should resolve a showcase fragment" % mastery_level)
		if fragment == null:
			continue
		_expect(fragment.atlas.resource_path == expected_paths[mastery_level], "stage %d should load %s, got %s" % [mastery_level, expected_paths[mastery_level], fragment.atlas.resource_path])
		_expect(fragment.region.size == Vector2(72, 72), "stage %d rice milk fragment should use its 72x72 entry region" % mastery_level)
		stage_fragments.append(fragment)
	_expect(stage_fragments.size() == 3, "all three stage fragments should load")
	if stage_fragments.size() == 3:
		_expect(stage_fragments[0] != stage_fragments[1] and stage_fragments[1] != stage_fragments[2], "different stages should not reuse one AtlasTexture cache entry")


func _test_trial_and_legacy_fallback(service) -> void:
	var fallback_manifest_path := OS.get_temp_dir().path_join("showcase_stage_fallback_self_check.json")
	var fallback_manifest := {
		"entries": {
			"rice_milk_drink|m0|standard|r0": {
				"texture_path": "res://resources/recipe_icons_showcase_staged/rice_milk_drink__trial__standard__r0.png",
				"recipe_id": "rice_milk_drink",
				"mastery_level": 0,
				"stage_id": "trial",
				"variant_id": "standard",
				"rotation": 0,
				"rows": 2,
				"cols": 1,
				"cells": [[1, 1], [2, 1]],
				"regions": {"1:1": [0, 0, 80, 80], "2:1": [0, 80, 80, 80]},
			}
		}
	}
	var file := FileAccess.open(fallback_manifest_path, FileAccess.WRITE)
	_expect(file != null, "fallback fixture manifest should be writable")
	if file == null:
		return
	file.store_string(JSON.stringify(fallback_manifest))
	file.close()
	_expect(service.call("load_manifest", service.DEFAULT_MANIFEST_PATH, fallback_manifest_path), "base plus partial staged manifest should load")
	var vertical: Array[Vector2i] = [Vector2i(1, 1), Vector2i(2, 1)]
	var fallback_layout: Dictionary = service.call("layout_for_shape", "rice_milk_drink", "standard", vertical, 2)
	_expect(int(fallback_layout.get("mastery_level", -1)) == 0, "missing signature showcase art should fall back to staged trial")
	var fallback_fragment := service.call("fragment", "rice_milk_drink", "standard", 0, Vector2i(1, 1), 2) as AtlasTexture
	_expect(fallback_fragment != null and fallback_fragment.atlas.resource_path.find("__trial__") != -1, "missing signature fragment should use staged trial texture")
	var legacy_cells: Array[Vector2i] = [Vector2i(1, 1)]
	var legacy_layout: Dictionary = service.call("layout_for_shape", "apple_crumble", "small", legacy_cells, 2)
	_expect(String(legacy_layout.get("source_kind", "")) == "base", "non-target recipes should keep the legacy showcase manifest")
	var legacy_rotation := int(legacy_layout.get("rotation", -1))
	var legacy_fragment := service.call("fragment", "apple_crumble", "small", legacy_rotation, Vector2i(1, 1), 2) as AtlasTexture
	_expect(legacy_fragment != null and legacy_fragment.atlas.resource_path.find("recipe_icons_showcase/apple_crumble") != -1, "non-target recipes should keep legacy showcase textures")
	if FileAccess.file_exists(fallback_manifest_path):
		DirAccess.remove_absolute(fallback_manifest_path)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	_failures.append(message)
