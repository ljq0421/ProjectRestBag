class_name ShowcaseIconService
extends RefCounted

const DEFAULT_MANIFEST_PATH := "res://resources/recipe_icons_showcase/showcase_icon_manifest.json"
const DEFAULT_STAGED_MANIFEST_PATH := "res://resources/recipe_icons_showcase_staged/staged_showcase_icon_manifest.json"

var _entries: Dictionary = {}
var _entries_by_recipe_variant: Dictionary = {}
var _staged_entries: Dictionary = {}
var _staged_entries_by_recipe_variant_level: Dictionary = {}
var _texture_cache: Dictionary = {}
var _fragment_cache: Dictionary = {}
var _warned_keys: Dictionary = {}


func load_manifest(path: String = DEFAULT_MANIFEST_PATH, staged_path: String = DEFAULT_STAGED_MANIFEST_PATH) -> bool:
	clear()
	var base_entries: Variant = _manifest_entries(path, true)
	if base_entries == null:
		return false
	_entries = (base_entries as Dictionary).duplicate(true)
	for entry_key_value in _entries.keys():
		var entry_key := String(entry_key_value)
		var entry: Dictionary = _entries[entry_key]
		var lookup_key := _recipe_variant_key(
			String(entry.get("recipe_id", entry_key.get_slice("|", 0))),
			String(entry.get("variant_id", entry_key.get_slice("|", 1)))
		)
		if not _entries_by_recipe_variant.has(lookup_key):
			_entries_by_recipe_variant[lookup_key] = []
		(_entries_by_recipe_variant[lookup_key] as Array).append(entry_key)
	for lookup_key in _entries_by_recipe_variant.keys():
		(_entries_by_recipe_variant[lookup_key] as Array).sort()
	var staged_entries: Variant = _manifest_entries(staged_path, false)
	if staged_entries is Dictionary:
		_staged_entries = (staged_entries as Dictionary).duplicate(true)
		for entry_key_value in _staged_entries.keys():
			var entry_key := String(entry_key_value)
			var entry: Dictionary = _staged_entries[entry_key]
			var lookup_key := _staged_recipe_variant_level_key(
				String(entry.get("recipe_id", "")),
				String(entry.get("variant_id", "standard")),
				int(entry.get("mastery_level", 0))
			)
			if not _staged_entries_by_recipe_variant_level.has(lookup_key):
				_staged_entries_by_recipe_variant_level[lookup_key] = []
			(_staged_entries_by_recipe_variant_level[lookup_key] as Array).append(entry_key)
		for lookup_key in _staged_entries_by_recipe_variant_level.keys():
			(_staged_entries_by_recipe_variant_level[lookup_key] as Array).sort()
	return not _entries.is_empty()


func entry_keys() -> Array:
	var keys := _entries.keys()
	keys.sort()
	return keys


func entry(key: String) -> Dictionary:
	var value: Variant = _entries.get(key, {})
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func layout_for_shape(recipe_id: String, variant_id: String, local_cells: Array[Vector2i], mastery_level: int = 0) -> Dictionary:
	var wanted_keys := _cell_keys(_normalize_cells(local_cells))
	if wanted_keys.is_empty():
		return {}
	var clean_variant_id := _normalized_variant_id(variant_id)
	for level in _stage_fallback_levels(mastery_level):
		var staged_lookup_key := _staged_recipe_variant_level_key(recipe_id, clean_variant_id, level)
		var staged_layout := _layout_from_candidates(
			_staged_entries,
			_staged_entries_by_recipe_variant_level.get(staged_lookup_key, []),
			wanted_keys,
			"staged"
		)
		if not staged_layout.is_empty():
			return staged_layout
	var lookup_key := _recipe_variant_key(recipe_id, clean_variant_id)
	return _layout_from_candidates(
		_entries,
		_entries_by_recipe_variant.get(lookup_key, []),
		wanted_keys,
		"base"
	)


func _layout_from_candidates(entries: Dictionary, candidates: Array, wanted_keys: String, source_kind: String) -> Dictionary:
	for entry_key_value in candidates:
		var entry_key := String(entry_key_value)
		var candidate: Dictionary = entries.get(entry_key, {})
		var raw_cells: Variant = candidate.get("cells", [])
		if not raw_cells is Array:
			continue
		var candidate_cells: Array[Vector2i] = []
		for value in raw_cells:
			if value is Array and value.size() == 2:
				candidate_cells.append(Vector2i(int(value[0]), int(value[1])))
		if _cell_keys(candidate_cells) == wanted_keys:
			var result := candidate.duplicate(true)
			result["entry_key"] = entry_key
			result["source_kind"] = source_kind
			return result
	return {}


func fragment(recipe_id: String, variant_id: String, rotation: int, local_cell: Vector2i, mastery_level: int = 0) -> AtlasTexture:
	var clean_variant_id := _normalized_variant_id(variant_id)
	var resolved := _fragment_entry(recipe_id, clean_variant_id, rotation, mastery_level)
	var entry_key := String(resolved.get("entry_key", ""))
	var source_kind := String(resolved.get("source_kind", ""))
	var entry_value: Variant = resolved.get("entry", {})
	var local_key := "%d:%d" % [local_cell.x, local_cell.y]
	var cache_key := "%s:%s|%s" % [source_kind, entry_key, local_key]
	if _fragment_cache.has(cache_key):
		return _fragment_cache[cache_key] as AtlasTexture
	if not entry_value is Dictionary or (entry_value as Dictionary).is_empty():
		_warn_once(cache_key, "Missing showcase icon layout: %s|%s|r%d" % [recipe_id, clean_variant_id, rotation])
		return null
	var entry: Dictionary = entry_value
	var regions_value: Variant = entry.get("regions", {})
	if not regions_value is Dictionary or not (regions_value as Dictionary).has(local_key):
		return null
	var region_value: Variant = (regions_value as Dictionary)[local_key]
	if not region_value is Array or region_value.size() != 4:
		_warn_once(cache_key, "Invalid showcase icon region: %s" % cache_key)
		return null
	var texture_path := String(entry.get("texture_path", ""))
	var texture := _texture(texture_path)
	if texture == null:
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(
		float(region_value[0]),
		float(region_value[1]),
		float(region_value[2]),
		float(region_value[3])
	)
	_fragment_cache[cache_key] = atlas
	return atlas


func texture_cache_size() -> int:
	return _texture_cache.size()


func fragment_cache_size() -> int:
	return _fragment_cache.size()


func staged_entry_count() -> int:
	return _staged_entries.size()


func clear() -> void:
	_entries.clear()
	_entries_by_recipe_variant.clear()
	_staged_entries.clear()
	_staged_entries_by_recipe_variant_level.clear()
	_texture_cache.clear()
	_fragment_cache.clear()
	_warned_keys.clear()


func _texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if _texture_cache.has(path):
		return _texture_cache[path] as Texture2D
	if not ResourceLoader.exists(path):
		_warn_once("texture:%s" % path, "Missing showcase icon texture: %s" % path)
		return null
	var loaded := load(path) as Texture2D
	if loaded == null:
		_warn_once("texture:%s" % path, "Could not load showcase icon texture: %s" % path)
		return null
	_texture_cache[path] = loaded
	return loaded


func _normalized_variant_id(variant_id: String) -> String:
	return "standard" if variant_id.is_empty() else variant_id


func _recipe_variant_key(recipe_id: String, variant_id: String) -> String:
	return "%s|%s" % [recipe_id, variant_id]


func _staged_recipe_variant_level_key(recipe_id: String, variant_id: String, mastery_level: int) -> String:
	return "%s|%s|m%d" % [recipe_id, variant_id, clampi(mastery_level, 0, 2)]


func _stage_fallback_levels(mastery_level: int) -> Array[int]:
	var clean_level := clampi(mastery_level, 0, 2)
	var levels: Array[int] = [clean_level]
	if clean_level != 0:
		levels.append(0)
	return levels


func _fragment_entry(recipe_id: String, variant_id: String, rotation: int, mastery_level: int) -> Dictionary:
	for level in _stage_fallback_levels(mastery_level):
		var staged_key := "%s|m%d|%s|r%d" % [recipe_id, level, variant_id, rotation]
		var staged_value: Variant = _staged_entries.get(staged_key, {})
		if staged_value is Dictionary and not (staged_value as Dictionary).is_empty():
			return {"entry_key": staged_key, "source_kind": "staged", "entry": staged_value}
	var base_key := "%s|%s|r%d" % [recipe_id, variant_id, rotation]
	var base_value: Variant = _entries.get(base_key, {})
	return {"entry_key": base_key, "source_kind": "base", "entry": base_value}


func _manifest_entries(path: String, required: bool) -> Variant:
	if not FileAccess.file_exists(path):
		if required:
			_warn_once("manifest:%s" % path, "Missing showcase icon manifest: %s" % path)
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		_warn_once("manifest:%s" % path, "Invalid showcase icon manifest: %s" % path)
		return null
	var raw_entries: Variant = (parsed as Dictionary).get("entries", {})
	if not raw_entries is Dictionary:
		_warn_once("manifest:%s" % path, "Showcase icon manifest has no entries: %s" % path)
		return null
	return raw_entries


func _normalize_cells(cells: Array[Vector2i]) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if cells.is_empty():
		return result
	var min_row := cells[0].x
	var min_col := cells[0].y
	for cell in cells:
		min_row = mini(min_row, cell.x)
		min_col = mini(min_col, cell.y)
	for cell in cells:
		result.append(Vector2i(cell.x - min_row + 1, cell.y - min_col + 1))
	result.sort_custom(func(left: Vector2i, right: Vector2i) -> bool:
		return left.x < right.x or (left.x == right.x and left.y < right.y)
	)
	return result


func _cell_keys(cells: Array[Vector2i]) -> String:
	var keys: Array[String] = []
	for cell in cells:
		keys.append("%d:%d" % [cell.x, cell.y])
	keys.sort()
	return ",".join(keys)


func _warn_once(key: String, message: String) -> void:
	if _warned_keys.has(key):
		return
	_warned_keys[key] = true
	push_warning(message)
